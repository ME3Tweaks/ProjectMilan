using System.Text;
using System.Text.RegularExpressions;

namespace UDKLoadTest;

/// <summary>A material (or material instance) whose shader map failed to compile.</summary>
internal sealed record ShaderMapFailure(
    string Material,
    string BaseMaterial, // Only for material instances; null for a plain material.
    string Platform,
    string LogLine,
    List<string> Errors,
    // How many times it failed identically. A material is often compiled more than once during a
    // load, e.g. again once UDK sets bUsedWithStaticLighting on it.
    int Occurrences = 1)
{
    public bool IsInstance => BaseMaterial != null;
}

internal sealed class ShaderLogScan
{
    public List<ShaderMapFailure> Failures { get; } = [];

    /// <summary>Other "Failed to compile ..." lines (global shaders, default materials, raw shader
    /// compiles) that aren't tied to one material's shader map.</summary>
    public List<string> OtherFailures { get; } = [];

    /// <summary>"Missing/Incomplete cached shader map for material X, quality N, compiling." lines.</summary>
    public int ShaderMapCompiles { get; set; }
}

/// <summary>
/// Pulls shader map compile failures out of a UDK Launch.log.
///
/// UDK logs a failure as a Warning:
///   [0024.87] Warning: Failed to compile Material Pkg.Mat for platform PC-D3D-SM5, Default Material will be used in game.
///   [0024.87] Warning: Failed to compile Material Instance Pkg.MIC with Base Mat for platform PC-D3D-SM5, Default Material will be used in game.
/// and then immediately logs each of FMaterial::CompileErrors as "\t%s" under DevShaders - which
/// UDKEngine.ini suppresses by default, so the reasons only show up when the run unsuppresses it.
/// An error string can span several lines; the continuation lines carry no "[time] Category:" prefix.
/// </summary>
internal static class ShaderFailureLogParser
{
    // "[0024.87] Warning: message" - the timestamp is missing on the first few lines of the log.
    private static readonly Regex LinePrefixRegex = new(@"^(?:\[\s*[\d.]+\]\s+)?([A-Za-z][A-Za-z0-9_]*):\s?(.*)$", RegexOptions.Compiled);

    private static readonly Regex InstanceFailureRegex = new(
        @"^Failed to compile Material Instance (\S+) with Base (\S+) for platform ([^,\s]+)", RegexOptions.Compiled);

    private static readonly Regex MaterialFailureRegex = new(
        @"^Failed to compile Material (\S+) for platform ([^,\s.]+)", RegexOptions.Compiled);

    private static readonly Regex ShaderMapCompileRegex = new(
        @"^(?:Missing|Incomplete) cached shader map for material ", RegexOptions.Compiled);

    public const string DevShadersCategory = "DevShaders";

    /// <summary>Reads <paramref name="logPath"/> from <paramref name="startOffset"/> without
    /// blocking UDK, which keeps the file open for writing.</summary>
    public static string ReadLogFrom(string logPath, long startOffset)
    {
        using var stream = new FileStream(logPath, FileMode.Open, FileAccess.Read, FileShare.ReadWrite | FileShare.Delete);
        if (startOffset > stream.Length)
            startOffset = 0; // A new log was started underneath us; take all of it.
        stream.Seek(startOffset, SeekOrigin.Begin);
        using var reader = new StreamReader(stream, Encoding.Latin1);
        return reader.ReadToEnd();
    }

    public static long GetLogLength(string logPath)
    {
        try
        {
            return new FileInfo(logPath).Length;
        }
        catch (IOException)
        {
            return 0;
        }
    }

    /// <summary>
    /// Compile errors are DevShaders "\t%s" lines, but so is DevShaders' own progress output, which
    /// can land right after a failure: "\tCompiling Mat for PC-D3D-SM5: ...", "\t\tN Shaders among
    /// M VertexFactories" and the deferred-compile "\tFinishDeferredCompilation ..." summary.
    /// </summary>
    private static bool IsCompileError(string message) =>
        message.StartsWith('\t')
        && !message.StartsWith("\t\t", StringComparison.Ordinal)
        && !message.StartsWith("\tCompiling ", StringComparison.Ordinal)
        && !message.StartsWith("\tFinishDeferredCompilation", StringComparison.Ordinal);

    public static ShaderLogScan Parse(string logText)
    {
        var scan = new ShaderLogScan();

        // The failure whose DevShaders error lines are being collected, if any.
        ShaderMapFailure collecting = null;
        // The error a prefix-less continuation line belongs to.
        bool lastLineWasError = false;

        foreach (var rawLine in logText.Split('\n'))
        {
            var line = rawLine.TrimEnd('\r');
            var match = LinePrefixRegex.Match(line);

            if (!match.Success)
            {
                // A continuation of a multi-line message. Only matters when it continues an error.
                if (collecting != null && lastLineWasError && line.Length > 0)
                    collecting.Errors[^1] += Environment.NewLine + line;
                continue;
            }

            var category = match.Groups[1].Value;
            var message = match.Groups[2].Value;

            if (category.Equals(DevShadersCategory, StringComparison.OrdinalIgnoreCase) && collecting != null && IsCompileError(message))
            {
                collecting.Errors.Add(message.Trim());
                lastLineWasError = true;
                continue;
            }

            collecting = null;
            lastLineWasError = false;

            if (ShaderMapCompileRegex.IsMatch(message))
            {
                scan.ShaderMapCompiles++;
                continue;
            }

            if (!message.StartsWith("Failed to compile", StringComparison.Ordinal))
                continue;

            var instance = InstanceFailureRegex.Match(message);
            if (instance.Success)
            {
                collecting = new ShaderMapFailure(instance.Groups[1].Value, instance.Groups[2].Value, instance.Groups[3].Value, line.Trim(), []);
                scan.Failures.Add(collecting);
                continue;
            }

            var material = MaterialFailureRegex.Match(message);
            if (material.Success)
            {
                collecting = new ShaderMapFailure(material.Groups[1].Value, null, material.Groups[2].Value, line.Trim(), []);
                scan.Failures.Add(collecting);
                continue;
            }

            scan.OtherFailures.Add(line.Trim());
        }

        var merged = scan.Failures
            .GroupBy(f => (f.Material, f.BaseMaterial, f.Platform, Errors: string.Join("\n", f.Errors)))
            .Select(g => g.First() with { Occurrences = g.Count() })
            .ToList();
        scan.Failures.Clear();
        scan.Failures.AddRange(merged);

        return scan;
    }
}
