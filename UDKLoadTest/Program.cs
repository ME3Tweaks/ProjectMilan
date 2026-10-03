using System.Diagnostics;
using System.Text;
using System.Text.RegularExpressions;
using ProjectMilan.Pipelines.StaticLighting;
using Serilog;

namespace UDKLoadTest;

/// <summary>
/// Loads each level under ProjectMilan/Pipelines/StaticLighting/Levels in the Milan UDK and reports
/// every material whose shader map failed to compile, with UDK's compile errors. A failed material
/// renders as the default material, which throws off lightmap baking.
///
/// Per level: copy its maps into UDK (wiping any other maps), boot the editor, inject UDKAgent, load
/// the persistent map through the agent (loading compiles any uncached shader maps), wait for
/// compiling to settle, then kill UDK. Nothing is built or saved.
///
/// UDK only logs why a material failed under the DevShaders category, which UDKEngine.ini suppresses,
/// so the run unsuppresses it for the session and puts the ini back afterwards.
///
/// Caveats:
/// - Load time only. A lighting build sets bUsedWithStaticLighting on some materials and recompiles
///   them then; a failure that only happens with that usage flag needs a bake to show up.
/// - With DevShaders unsuppressed, a non-optional shader parameter bind failure becomes a message box
///   instead of an appErrorf crash. That stalls the load until the LoadMap timeout, whose error names
///   UDK's open windows.
/// </summary>
internal static class Program
{
    private const string UdkPathEnvVar = "MILAN_UDK_PATH";

    // Where the Milan pipelines keep the UDK install on the dev machines, tried when nothing else is given.
    private static readonly string[] KnownUdkPaths = [@"S:\Milan\UDK", @"E:\Milan\UDK"];

    private static readonly TimeSpan LoadMapTimeout = TimeSpan.FromMinutes(30);

    /// <summary>How long Launch.log has to go without shader compile activity before the load counts as settled.</summary>
    private static readonly TimeSpan SettleQuietPeriod = TimeSpan.FromSeconds(10);
    private static readonly TimeSpan SettleTimeout = TimeSpan.FromMinutes(3);

    private static readonly Regex CompileActivityRegex = new(
        @"cached shader map for material|Failed to compile|\] DevShaders:", RegexOptions.Compiled);

    private sealed record Options(string UdkPath, string AgentPath, string OutDir, List<string> Levels, string ParseLog);

    private sealed record LevelResult(string Level, ShaderLogScan Scan, string Error, TimeSpan Elapsed);

    private static int Main(string[] args)
    {
        try
        {
            var options = ParseArgs(args);
            if (options == null)
                return 2;

            if (options.ParseLog != null)
                return ParseExistingLog(options.ParseLog);

            var levelsRoot = FindLevelsRoot();
            if (levelsRoot == null)
                return Fail("Could not find ProjectMilan\\Pipelines\\StaticLighting\\Levels above the executable.");

            var udkRoot = ResolveUdkRoot(options.UdkPath);
            if (udkRoot == null)
                return Fail($"Could not find the Milan UDK. Pass --udk <path> or set {UdkPathEnvVar}.");

            var agent = ResolveAgent(options.AgentPath);
            if (agent == null)
                return Fail(@"Could not find UDKAgent.asi. Build UdkInj\UDKAgent or pass --agent <path>.");

            var levels = Directory.GetDirectories(levelsRoot)
                .Select(d => new DirectoryInfo(d).Name)
                .Where(name => File.Exists(Path.Combine(levelsRoot, name, name + ".udk")))
                .OrderBy(name => name, StringComparer.OrdinalIgnoreCase)
                .ToList();
            if (levels.Count == 0)
                return Fail($"No levels with a master .udk found in {levelsRoot}");

            if (options.Levels.Count > 0)
            {
                var selected = new List<string>();
                foreach (var requested in options.Levels)
                {
                    var match = levels.FirstOrDefault(l => l.Equals(requested, StringComparison.OrdinalIgnoreCase)
                                                           || l.Equals("BioP_" + requested, StringComparison.OrdinalIgnoreCase));
                    if (match == null)
                        return Fail($"Unknown level '{requested}'. Levels: {string.Join(", ", levels)}");
                    if (!selected.Contains(match))
                        selected.Add(match);
                }
                levels = selected;
            }

            var runDir = Directory.CreateDirectory(Path.Combine(options.OutDir, DateTime.Now.ToString("yyyyMMdd_HHmmss"))).FullName;
            Log.Logger = new LoggerConfiguration()
                .WriteTo.Console()
                .WriteTo.File(Path.Combine(runDir, "UDKLoadTest.log"))
                .CreateLogger();

            Log.Information("UDK: {Udk}", udkRoot);
            Log.Information("Agent: {Agent}", agent.FullName);
            Log.Information("Output: {Out}", runDir);
            Log.Information("Testing {Count} level(s): {Levels}", levels.Count, string.Join(", ", levels));

            var results = new List<LevelResult>();
            for (int i = 0; i < levels.Count; i++)
            {
                Log.Information("===== [{Index}/{Count}] {Level} =====", i + 1, levels.Count, levels[i]);
                var result = TestLevel(levelsRoot, udkRoot, agent, levels[i], runDir);
                results.Add(result);
                LogLevelSummary(result);
            }

            WriteTextReport(results, Path.Combine(runDir, "UDKLoadTest_Report.txt"));
            WriteCsvReport(results, Path.Combine(runDir, "UDKLoadTest_Report.csv"));

            var failedLevels = results.Count(r => r.Scan?.Failures.Count > 0);
            var erroredLevels = results.Count(r => r.Error != null);
            Log.Information("Done: {Levels} level(s), {Failed} with shader map failures, {Errored} errored. Report: {Report}",
                results.Count, failedLevels, erroredLevels, Path.Combine(runDir, "UDKLoadTest_Report.txt"));

            return failedLevels > 0 || erroredLevels > 0 ? 1 : 0;
        }
        catch (ArgumentException ex)
        {
            return Fail(ex.Message);
        }
        catch (Exception ex)
        {
            return Fail(ex.ToString());
        }
        finally
        {
            Log.CloseAndFlush();
        }
    }

    private static int Fail(string message)
    {
        Console.Error.WriteLine($"Error: {message}");
        return 2;
    }

    private static Options ParseArgs(string[] args)
    {
        string udk = null, agent = null, outDir = null, parseLog = null;
        var levels = new List<string>();

        for (int i = 0; i < args.Length; i++)
        {
            string NextValue()
            {
                if (i + 1 >= args.Length)
                    throw new ArgumentException($"{args[i]} needs a value");
                return args[++i];
            }

            switch (args[i].ToLowerInvariant())
            {
                case "--udk": udk = NextValue(); break;
                case "--agent": agent = NextValue(); break;
                case "--out": outDir = NextValue(); break;
                case "--parse": parseLog = NextValue(); break;
                case "-h":
                case "--help":
                case "/?":
                    Console.WriteLine("Usage: UDKLoadTest [--udk <UDK root>] [--agent <UDKAgent.asi>] [--out <dir>] [level ...]");
                    Console.WriteLine("       UDKLoadTest --parse <Launch.log>");
                    Console.WriteLine("Loads each level (default: all) in UDK and reports materials whose shader maps fail to compile.");
                    Console.WriteLine("--parse only lists the shader map failures in an existing UDK log.");
                    return null;
                default:
                    if (args[i].StartsWith("--"))
                        throw new ArgumentException($"Unknown option {args[i]}");
                    levels.Add(args[i]);
                    break;
            }
        }

        return new Options(udk, agent, outDir ?? Path.Combine(AppContext.BaseDirectory, "Reports"), levels, parseLog);
    }

    /// <summary>--parse: lists the shader map failures in an existing log, e.g. one copied by an earlier run.</summary>
    private static int ParseExistingLog(string logPath)
    {
        if (!File.Exists(logPath))
            return Fail($"No such log: {logPath}");

        var scan = ShaderFailureLogParser.Parse(ShaderFailureLogParser.ReadLogFrom(logPath, 0));
        Console.WriteLine($"{scan.ShaderMapCompiles} shader map compile(s), {scan.Failures.Count} failure(s)");
        foreach (var failure in scan.Failures)
        {
            Console.WriteLine($"FAILED  {DescribeFailure(failure)}");
            var sb = new StringBuilder();
            AppendErrors(sb, failure.Errors, "        ");
            Console.Write(sb);
        }
        foreach (var other in scan.OtherFailures)
            Console.WriteLine($"OTHER   {other}");

        return scan.Failures.Count > 0 ? 1 : 0;
    }

    /// <summary>Walks up from the executable until the repo's StaticLighting/Levels folder turns up.</summary>
    private static string FindLevelsRoot()
    {
        for (var dir = new DirectoryInfo(AppContext.BaseDirectory); dir != null; dir = dir.Parent)
        {
            var candidate = Path.Combine(dir.FullName, "ProjectMilan", "Pipelines", "StaticLighting", "Levels");
            if (Directory.Exists(candidate))
                return candidate;
        }
        return null;
    }

    private static string ResolveUdkRoot(string explicitPath)
    {
        var candidates = new List<string> { explicitPath, Environment.GetEnvironmentVariable(UdkPathEnvVar) };
        candidates.AddRange(KnownUdkPaths);
        return candidates.FirstOrDefault(c => !string.IsNullOrWhiteSpace(c) && IsUdkRoot(c));
    }

    private static bool IsUdkRoot(string path) => File.Exists(GetUdkExePath(path));

    private static string GetUdkExePath(string udkRoot) => Path.Combine(udkRoot, "Binaries", "Win64", "UDK.exe");

    /// <summary>The given agent, else the newest build of the UdkInj submodule's UDKAgent.</summary>
    private static FileInfo ResolveAgent(string explicitPath)
    {
        if (!string.IsNullOrWhiteSpace(explicitPath))
            return File.Exists(explicitPath) ? new FileInfo(explicitPath) : null;

        for (var dir = new DirectoryInfo(AppContext.BaseDirectory); dir != null; dir = dir.Parent)
        {
            var builds = Path.Combine(dir.FullName, "UdkInj", "x64");
            if (!Directory.Exists(builds))
                continue;

            return new[] { "Debug", "Release" }
                .Select(config => new FileInfo(Path.Combine(builds, config, "UDKAgent.asi")))
                .Where(f => f.Exists)
                .OrderByDescending(f => f.LastWriteTimeUtc)
                .FirstOrDefault();
        }
        return null;
    }

    private static LevelResult TestLevel(string levelsRoot, string udkRoot, FileInfo agent, string level, string runDir)
    {
        var sw = Stopwatch.StartNew();
        var udkGame = Path.Combine(udkRoot, "UDKGame");
        var logPath = Path.Combine(udkGame, "Logs", "Launch.log");

        string error = null;
        ShaderLogScan scan = null;
        long? baseline = null;

        try
        {
            KillRunningUdk();
            var mapPath = CopyLevelIntoUdk(levelsRoot, udkRoot, level);

            using (new EditorConfigOverride(Path.Combine(udkGame, "Config", "UDKEditorUserSettings.ini"), EditorConfigOverride.AutomationProfile))
            // DevShaders carries the compile errors (see the class comment). The retry prompt is a modal
            // "Shader compiler errors compiling X ... Retry compilation?" box on every HLSL failure, which
            // blocks the load; declining it is what the log-and-continue path does anyway.
            using (new EditorConfigOverride(Path.Combine(udkGame, "Config", "UDKEngine.ini"),
                       [("DevOptions.Shaders", "bPromptToRetryFailedShaderCompiles", "False")],
                       [("Core.System", $"Suppress={ShaderFailureLogParser.DevShadersCategory}")]))
            {
                try
                {
                    // -forcelogflush: Launch.log is otherwise buffered, and UDK gets killed at the end.
                    using var session = UdkAgentSession.Start(GetUdkExePath(udkRoot), "editor -log -forcelogflush", agent);

                    // Only what the map load causes - not the editor's own startup content.
                    baseline = ShaderFailureLogParser.GetLogLength(logPath);

                    session.LoadMap(mapPath, LoadMapTimeout);
                    WaitForCompilesToSettle(session, logPath, baseline.Value);
                }
                catch (Exception ex)
                {
                    error = ex.Message;
                    Log.Error("{Level} failed: {Error}", level, ex.Message);
                }
            }

            // Read even after a failure: whatever compiled before a timeout or crash is still worth reporting.
            if (baseline != null && File.Exists(logPath))
            {
                scan = ShaderFailureLogParser.Parse(ShaderFailureLogParser.ReadLogFrom(logPath, baseline.Value));

                var logsDir = Directory.CreateDirectory(Path.Combine(runDir, "logs")).FullName;
                File.Copy(logPath, Path.Combine(logsDir, $"{level}_Launch.log"), overwrite: true);
            }
        }
        catch (Exception ex)
        {
            error ??= ex.Message;
            Log.Error("{Level} failed: {Error}", level, ex.Message);
        }

        return new LevelResult(level, scan, error, sw.Elapsed);
    }

    private static void KillRunningUdk()
    {
        // Files in Maps are locked while UDK is running, and a stray instance can confuse injection.
        foreach (var running in Process.GetProcessesByName("UDK"))
        {
            Log.Warning("Killing running UDK (pid {Pid})", running.Id);
            running.Kill();
            running.WaitForExit(10_000);
        }
    }

    /// <summary>Copies the level's maps into UDK's Maps folder and returns the persistent map's path there.</summary>
    private static string CopyLevelIntoUdk(string levelsRoot, string udkRoot, string level)
    {
        // Wipe the whole Maps folder, not just this level's subfolder - a leftover level sitting
        // alongside it is what trips UDK's "ambiguous packages" error.
        var mapsPath = Path.Combine(udkRoot, "UDKGame", "Content", "Maps");
        Directory.CreateDirectory(mapsPath);
        foreach (var file in Directory.GetFiles(mapsPath))
            File.Delete(file);
        foreach (var dir in Directory.GetDirectories(mapsPath))
            Directory.Delete(dir, recursive: true);

        var destination = Directory.CreateDirectory(Path.Combine(mapsPath, level)).FullName;
        foreach (var map in Directory.GetFiles(Path.Combine(levelsRoot, level), "*.udk"))
            File.Copy(map, Path.Combine(destination, Path.GetFileName(map)), overwrite: true);

        return Path.Combine(destination, level + ".udk");
    }

    /// <summary>
    /// Shader compiles on load are synchronous, but a few happen just after LoadMap returns (a
    /// usage flag set on first render recompiles the material). Waits until Launch.log has gone
    /// <see cref="SettleQuietPeriod"/> without compile activity and no slow task is running.
    /// </summary>
    private static void WaitForCompilesToSettle(UdkAgentSession session, string logPath, long baseline)
    {
        var deadline = DateTime.UtcNow + SettleTimeout;
        var lastActivity = DateTime.UtcNow;
        var scannedTo = baseline;

        while (DateTime.UtcNow < deadline)
        {
            var status = session.ReadStatus("waiting for shader compiles to settle");

            if (ShaderFailureLogParser.GetLogLength(logPath) > scannedTo)
            {
                var text = ShaderFailureLogParser.ReadLogFrom(logPath, scannedTo);
                // Only up to the last complete line, so a line being written isn't half-matched.
                var complete = text.LastIndexOf('\n') + 1;
                if (CompileActivityRegex.IsMatch(text.AsSpan(0, complete)))
                    lastActivity = DateTime.UtcNow;
                scannedTo += complete; // Latin1: one char per byte.
            }

            if (status.SlowTaskDepth == 0 && DateTime.UtcNow - lastActivity >= SettleQuietPeriod)
                return;

            Thread.Sleep(TimeSpan.FromSeconds(1));
        }

        Log.Warning("Shader compile activity did not settle within {Timeout}; reporting what was logged so far", SettleTimeout);
    }

    private static void LogLevelSummary(LevelResult result)
    {
        if (result.Scan != null)
        {
            Log.Information("{Level}: {Compiled} shader map compile(s), {Failed} failure(s) ({Elapsed:mm\\:ss})",
                result.Level, result.Scan.ShaderMapCompiles, result.Scan.Failures.Count, result.Elapsed);
            foreach (var failure in result.Scan.Failures)
                Log.Warning("  FAILED {Material}{Base}: {Reason}", failure.Material,
                    failure.IsInstance ? $" (base {failure.BaseMaterial})" : "", FirstLine(failure));
        }
        if (result.Error != null)
            Log.Error("{Level}: did not finish: {Error}", result.Level, result.Error);
    }

    private static string DescribeFailure(ShaderMapFailure failure) =>
        failure.Material
        + (failure.IsInstance ? $"  (instance of {failure.BaseMaterial}, {failure.Platform})" : $"  ({failure.Platform})")
        + (failure.Occurrences > 1 ? $"  x{failure.Occurrences}" : "");

    private static string FirstLine(ShaderMapFailure failure) =>
        failure.Errors.Count == 0 ? "(none logged)" : failure.Errors[0].Split('\n')[0].TrimEnd('\r');

    private static void WriteTextReport(List<LevelResult> results, string path)
    {
        var sb = new StringBuilder();
        sb.AppendLine($"UDK load test - {DateTime.Now:yyyy-MM-dd HH:mm}");
        sb.AppendLine($"{results.Count} level(s), {results.Count(r => r.Scan?.Failures.Count > 0)} with shader map failures, {results.Count(r => r.Error != null)} errored");
        sb.AppendLine();

        foreach (var result in results)
        {
            sb.AppendLine($"== {result.Level} ({result.Elapsed:mm\\:ss})");
            if (result.Error != null)
                sb.AppendLine($"   DID NOT FINISH: {result.Error}");
            if (result.Scan == null)
            {
                sb.AppendLine("   (no log captured)");
                sb.AppendLine();
                continue;
            }

            sb.AppendLine($"   {result.Scan.ShaderMapCompiles} shader map compile(s), {result.Scan.Failures.Count} failure(s)");
            foreach (var failure in result.Scan.Failures)
            {
                sb.AppendLine($"   FAILED  {DescribeFailure(failure)}");
                AppendErrors(sb, failure.Errors, "           ");
            }
            foreach (var other in result.Scan.OtherFailures)
                sb.AppendLine($"   OTHER   {other}");
            sb.AppendLine();
        }

        // The same material usually fails the same way everywhere it's used.
        var byMaterial = results
            .Where(r => r.Scan != null)
            .SelectMany(r => r.Scan.Failures.Select(f => (r.Level, Failure: f)))
            .GroupBy(x => x.Failure.Material, StringComparer.OrdinalIgnoreCase)
            .OrderBy(g => g.Key, StringComparer.OrdinalIgnoreCase)
            .ToList();

        sb.AppendLine($"===== Unique failing materials: {byMaterial.Count}");
        foreach (var group in byMaterial)
        {
            var first = group.First().Failure;
            var levels = group.Select(x => x.Level).Distinct(StringComparer.OrdinalIgnoreCase);
            sb.AppendLine(first.IsInstance ? $"{group.Key}  (instance of {first.BaseMaterial})" : group.Key);
            sb.AppendLine($"   levels: {string.Join(", ", levels)}");
            AppendErrors(sb, group.SelectMany(x => x.Failure.Errors).Distinct().ToList(), "   ");
        }

        File.WriteAllText(path, sb.ToString());
    }

    private static void AppendErrors(StringBuilder sb, List<string> errors, string indent)
    {
        if (errors.Count == 0)
        {
            sb.AppendLine($"{indent}(no compile errors logged)");
            return;
        }

        foreach (var error in errors)
        foreach (var line in error.Split('\n'))
            sb.AppendLine($"{indent}{line.TrimEnd('\r')}");
    }

    private static void WriteCsvReport(List<LevelResult> results, string path)
    {
        var sb = new StringBuilder();
        sb.AppendLine("Level,Kind,Material,BaseMaterial,Platform,Errors");
        foreach (var result in results)
        {
            if (result.Error != null)
                sb.AppendLine(string.Join(',', Csv(result.Level), "LevelError", "", "", "", Csv(result.Error)));
            if (result.Scan == null)
                continue;

            foreach (var failure in result.Scan.Failures)
            {
                sb.AppendLine(string.Join(',',
                    Csv(result.Level),
                    failure.IsInstance ? "MaterialInstance" : "Material",
                    Csv(failure.Material),
                    Csv(failure.BaseMaterial ?? ""),
                    Csv(failure.Platform),
                    Csv(string.Join(" | ", failure.Errors.Select(e => e.Replace("\r", "").Replace('\n', ' '))))));
            }
            foreach (var other in result.Scan.OtherFailures)
                sb.AppendLine(string.Join(',', Csv(result.Level), "Other", "", "", "", Csv(other)));
        }

        File.WriteAllText(path, sb.ToString());
    }

    private static string Csv(string value) =>
        value.IndexOfAny([',', '"', '\n', '\r']) >= 0 ? $"\"{value.Replace("\"", "\"\"")}\"" : value;
}
