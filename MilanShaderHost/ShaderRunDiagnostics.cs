using Serilog;
using Serilog.Events;
using System.Runtime.CompilerServices;
using System.Text;
using System.Text.Json;
using System.Text.RegularExpressions;

[assembly: InternalsVisibleTo("MilanShaderHost.Test")]

namespace MilanShaderHost;

internal sealed class ShaderRunDiagnostics : IDisposable
{
    private readonly TextWriter originalOut = Console.Out;
    private readonly TextWriter originalError = Console.Error;
    private readonly Serilog.Core.Logger logger;
    private readonly ILogger previousLogger = Log.Logger;
    private readonly TeeWriter outputWriter;
    private readonly TeeWriter errorWriter;
    private int disposed;
    internal const int RetainedLogCount = 3;
    private readonly object writeLock = new();
    private int captureSequence;
    internal static ShaderRunDiagnostics? Current { get; private set; }
    internal string DirectoryPath { get; }
    internal string LogFilePath { get; }

    internal ShaderRunDiagnostics(string logDirectory, string? sessionId = null)
    {
        sessionId ??= $"{DateTime.UtcNow:yyyyMMddTHHmmssfffffffZ}-{Environment.ProcessId}";
        Directory.CreateDirectory(logDirectory);
        DirectoryPath = Path.Combine(logDirectory, sessionId);
        Directory.CreateDirectory(DirectoryPath);
        LogFilePath = Path.Combine(logDirectory, $"ShaderHost-{sessionId}.log");
        logger = new LoggerConfiguration()
            .WriteTo.File(LogFilePath, shared: true, buffered: false, fileSizeLimitBytes: null,
                outputTemplate: "[{Timestamp:HH:mm:ss.fff} {Level:u3}] {Message:lj}{NewLine}{Exception}")
            .CreateLogger();
        Log.Logger = logger;
        outputWriter = new TeeWriter(originalOut, logger, LogEventLevel.Information, writeLock);
        errorWriter = new TeeWriter(originalError, logger, LogEventLevel.Error, writeLock);
        Console.SetOut(outputWriter);
        Console.SetError(errorWriter);
        Current = this;
        AppDomain.CurrentDomain.ProcessExit += OnProcessExit;
        PruneOldLogs(logDirectory);
        Console.WriteLine($"ShaderHost session log: {LogFilePath}");
    }

    internal static ShaderRunDiagnostics Start() => new(Path.Combine(AppContext.BaseDirectory, "Logs", "ShaderHost"));

    private static void PruneOldLogs(string directory)
    {
        // Unique run filenames require explicit retention rather than rolling-file retention.
        var files = Directory.GetFiles(directory, "ShaderHost-*.log")
            .OrderBy(x => x, StringComparer.OrdinalIgnoreCase).ToArray();
        foreach (var file in files.Take(Math.Max(0, files.Length - RetainedLogCount)))
        {
            try
            {
                File.Delete(file);
                var sessionId = Path.GetFileNameWithoutExtension(file)["ShaderHost-".Length..];
                var archive = Path.GetFullPath(Path.Combine(directory, sessionId));
                var root = Path.GetFullPath(directory).TrimEnd(Path.DirectorySeparatorChar) + Path.DirectorySeparatorChar;
                if (archive.StartsWith(root, StringComparison.OrdinalIgnoreCase) && Directory.Exists(archive)
                    && (File.GetAttributes(archive) & FileAttributes.ReparsePoint) == 0)
                    Directory.Delete(archive, recursive: true);
            }
            catch (IOException ex) { Console.Error.WriteLine($"Could not prune ShaderHost log {file}: {ex.Message}"); }
            catch (UnauthorizedAccessException ex) { Console.Error.WriteLine($"Could not prune ShaderHost log {file}: {ex.Message}"); }
        }
    }

    internal ClientLogResult ArchiveClientLog(string source, string package, string mode, int gamePid, DateTime launchedUtc)
    {
        return ArchiveClientLog(DirectoryPath, ++captureSequence, source, package, mode, gamePid, launchedUtc, Console.Out, Console.Error);
    }

    internal sealed record ClientLogResult(string? Path, int Warnings, int Errors, bool MaterialCompileFailed);

    internal static ClientLogResult ArchiveClientLog(string directory, int sequence, string source, string package,
        string mode, int gamePid, DateTime launchedUtc, TextWriter output, TextWriter error)
    {
        if (!File.Exists(source) || File.GetLastWriteTimeUtc(source) < launchedUtc)
        {
            error.WriteLine($"[ShaderClient][{package}][{mode}][PID {gamePid}] No fresh client log; previous launch diagnostics were not reused.");
            return new(null, 0, 0, false);
        }
        var invalid = Path.GetInvalidFileNameChars();
        var safePackage = string.Concat(package.Select(c => invalid.Contains(c) ? '_' : c));
        var archive = Path.Combine(directory, $"{sequence:D4}-{safePackage}-{mode}-{gamePid}-ShaderClient.log");
        File.Copy(source, archive, overwrite: false);
        int warnings = 0, errors = 0;
        bool materialCompileFailed = false;
        foreach (var line in File.ReadLines(archive))
        {
            var match = Regex.Match(line, @"^\[[^\]]+ (?<level>warning|error|critical)\]");
            if (!match.Success) continue;
            var level = match.Groups["level"].Value;
            var writer = level == "warning" ? output : error;
            writer.WriteLine($"[ShaderClient][{package}][{mode}][PID {gamePid}] {line}");
            if (level == "warning") warnings++; else errors++;
            materialCompileFailed |= line.Contains("Material failed to compile:", StringComparison.Ordinal);
        }
        output.WriteLine($"[ShaderClient][{package}][{mode}][PID {gamePid}] Archived client log: {archive}; {errors} error(s), {warnings} warning(s).");
        File.AppendAllText(Path.Combine(directory, "client-captures.jsonl"), JsonSerializer.Serialize(new
        {
            Package = package, Mode = mode, GamePID = gamePid, LaunchedUTC = launchedUtc,
            Archive = archive, Errors = errors, Warnings = warnings, MaterialCompileFailed = materialCompileFailed
        }) + Environment.NewLine);
        return new(archive, warnings, errors, materialCompileFailed);
    }

    private void OnProcessExit(object? sender, EventArgs e) => Dispose();

    public void Dispose()
    {
        if (Interlocked.Exchange(ref disposed, 1) != 0) return;
        AppDomain.CurrentDomain.ProcessExit -= OnProcessExit;
        lock (writeLock)
        {
            outputWriter.Flush();
            errorWriter.Flush();
            Console.SetOut(originalOut);
            Console.SetError(originalError);
            Log.Logger = previousLogger;
            logger.Dispose();
        }
        if (ReferenceEquals(Current, this)) Current = null;
    }

    private sealed class TeeWriter(TextWriter console, ILogger log, LogEventLevel defaultLevel, object gate) : TextWriter
    {
        private readonly StringBuilder pending = new();
        public override Encoding Encoding => console.Encoding;
        public override void Write(char value) { lock (gate) { console.Write(value); Append(value.ToString()); } }
        public override void Write(string? value) { lock (gate) { console.Write(value); Append(value); } }
        public override void WriteLine(string? value) { lock (gate) { console.WriteLine(value); Append(value); Emit(); } }
        public override void Flush() { lock (gate) { console.Flush(); if (pending.Length > 0) Emit(); } }

        private void Append(string? value)
        {
            if (value == null) return;
            foreach (var c in value)
            {
                if (c == '\n') Emit();
                else if (c != '\r') pending.Append(c);
            }
        }

        private void Emit()
        {
            var message = pending.ToString();
            pending.Clear();
            var level = message.Contains(" critical]", StringComparison.Ordinal) ? LogEventLevel.Fatal
                : message.Contains(" error]", StringComparison.Ordinal) ? LogEventLevel.Error
                : message.Contains(" warning]", StringComparison.Ordinal) ? LogEventLevel.Warning : defaultLevel;
            log.Write(level, "{Message:l}", message);
        }
    }
}
