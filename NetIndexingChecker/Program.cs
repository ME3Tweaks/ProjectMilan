using System.Collections.Concurrent;
using System.Text;
using LegendaryExplorerCore;
using LegendaryExplorerCore.GameFilesystem;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Packages.NetIndexing;

namespace NetIndexingChecker;

internal static class Program
{
    private static readonly HashSet<string> PackageExtensions = new(StringComparer.OrdinalIgnoreCase)
        { ".pcc", ".upk", ".u" };

    private const int DefaultLimit = 25;
    private const int MaxConsoleDetail = 400;

    private static int Main(string[] args)
    {
        string? root = null, csv = null, dump = null;
        var game = MEGame.LMP;
        string[] includes = [];
        int limit = DefaultLimit;
        int threads = Math.Max(1, Environment.ProcessorCount / 2);
        for (int i = 0; i < args.Length; i++)
        {
            switch (args[i])
            {
                case "--help" or "-h" or "/?":
                    PrintUsage();
                    return 0;
                case "--csv" when i + 1 < args.Length:
                    csv = args[++i];
                    break;
                case "--dump" when i + 1 < args.Length:
                    dump = args[++i];
                    break;
                case "--game" when i + 1 < args.Length && Enum.TryParse(args[i + 1], true, out MEGame g) && g is MEGame.LMP or MEGame.LE3 or MEGame.ME3:
                    game = g;
                    i++;
                    break;
                case "--include" when i + 1 < args.Length:
                    includes = args[++i].Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
                    break;
                case "--limit" when i + 1 < args.Length && int.TryParse(args[i + 1], out int l) && l >= 0:
                    limit = l;
                    i++;
                    break;
                case "--threads" when i + 1 < args.Length && int.TryParse(args[i + 1], out int t) && t > 0:
                    threads = t;
                    i++;
                    break;
                case { } s when s.StartsWith("--", StringComparison.Ordinal):
                    return Fail($"Unknown or incomplete option: {s}");
                default:
                    if (root != null) return Fail($"Unexpected argument: {args[i]}");
                    root = args[i];
                    break;
            }
        }

        root ??= game == MEGame.LMP ? LMPDirectory.DefaultGamePath : null;
        if (string.IsNullOrWhiteSpace(root)) return Fail($"No {game} game path given or configured. Pass the game root.");
        root = Path.GetFullPath(root);
        if (!Directory.Exists(root)) return Fail($"{game} game root does not exist: {root}");

        LegendaryExplorerCoreLib.InitLib(TaskScheduler.Default, message => Console.Error.WriteLine($"LEC: {message}"),
            objectDBsToLoad: [game]);
        MEPackageHandler.GlobalSharedCacheEnabled = false;

        var paths = Directory.EnumerateFiles(root, "*", SearchOption.AllDirectories)
            .Where(p => PackageExtensions.Contains(Path.GetExtension(p)))
            .Where(p => includes.Length == 0 || includes.Any(x => Path.GetRelativePath(root, p).Contains(x, StringComparison.OrdinalIgnoreCase)))
            .OrderBy(p => p, StringComparer.OrdinalIgnoreCase).ToArray();
        Console.WriteLine($"{game} target: {root}");
        Console.WriteLine($"Packages: {paths.Length}");

        var scans = new ConcurrentBag<PackageNetScan>();
        int done = 0;
        Parallel.ForEach(paths, new ParallelOptions { MaxDegreeOfParallelism = threads }, path =>
        {
            scans.Add(PackageNetScan.Read(path, game));
            int n = Interlocked.Increment(ref done);
            if (n % 500 == 0) Console.Error.WriteLine($"Scanned {n}/{paths.Length}");
        });

        // Merge in path order so the report is deterministic.
        var inventory = new LinkerInventory();
        int skipped = 0, unreadable = 0, exportErrors = 0;
        foreach (var scan in scans.OrderBy(s => s.Path, StringComparer.OrdinalIgnoreCase))
        {
            var relative = Path.GetRelativePath(root, scan.Path);
            if (scan.Error != null)
            {
                unreadable++;
                Console.WriteLine($"PACKAGE_ERROR | {relative} | {scan.Error}");
                continue;
            }
            if (scan.SkipReason != null)
            {
                skipped++;
                if (scan.SkipReason != "GuidCache")
                    Console.WriteLine($"SKIPPED | {relative} | package game is {scan.SkipReason}, not {game}");
                continue;
            }
            exportErrors += scan.ExportErrors;
            inventory.Add(scan, relative, OriginOf(relative));
        }

        var findings = inventory.Analyze();
        Report(inventory, findings, limit, skipped, unreadable, exportErrors);
        if (csv != null) WriteCsv(csv, inventory, findings);
        if (dump != null)
        {
            var output = Path.GetFullPath(dump);
            Directory.CreateDirectory(Path.GetDirectoryName(output)!);
            File.WriteAllLines(output, new[] { Csv("Linker", "File", "Origin", "Loc", "DeclaredBy", "Guid", "Count", "Objects", "Unassigned", "LocalizedResources", "MinNetIndex", "MaxNetIndex") }
                .Concat(inventory.DumpLinkerFiles().Select(Csv)), new UTF8Encoding(false));
            Console.WriteLine($"Linker dump: {output}");
        }
        return findings.Count == 0 && unreadable == 0 ? 0 : 1;
    }

    /// <summary>Which content a file belongs to: a DLC folder name, or BaseGame for everything else.</summary>
    private static string OriginOf(string relativePath)
    {
        var parts = relativePath.Split(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);
        for (int i = 0; i < parts.Length - 1; i++)
        {
            if (parts[i].Equals("DLC", StringComparison.OrdinalIgnoreCase) && i + 1 < parts.Length - 1)
                return parts[i + 1];
        }

        return "BaseGame";
    }

    private static string OriginsOf(LinkerInventory inventory, Finding finding) =>
        string.Join(";", finding.Files.Select(f => inventory.Files[f].Origin).Distinct(StringComparer.OrdinalIgnoreCase).Order(StringComparer.OrdinalIgnoreCase));

    private static void Report(LinkerInventory inventory, List<Finding> findings, int limit, int skipped, int unreadable, int exportErrors)
    {
        Console.WriteLine();
        foreach (var issue in Issues.All)
        {
            var group = findings.Where(f => f.Issue == issue).ToList();
            if (group.Count == 0) continue;
            Console.WriteLine($"=== {issue}: {group.Count} ===");
            foreach (var finding in group.Take(limit))
            {
                var subject = finding.Object.Length == 0 ? finding.Linker : $"{finding.Linker} :: {finding.Object}";
                Console.WriteLine($"{subject} [{OriginsOf(inventory, finding)}]");
                Console.WriteLine($"    {Truncate(finding.Detail, MaxConsoleDetail)}");
            }
            if (group.Count > limit)
                Console.WriteLine($"... {group.Count - limit} more (raise --limit or use --csv for the full list)");
            Console.WriteLine();
        }

        Console.WriteLine("--- Summary ---");
        Console.WriteLine($"Packages read: {inventory.Files.Count} ({skipped} skipped, {unreadable} unreadable); linkers: {inventory.LinkerCount}; exports checked: {inventory.ExportCount} ({exportErrors} unreadable, {inventory.UnassignedExportCount} with NetIndex < 0)");
        foreach (var issue in Issues.All)
            Console.WriteLine($"{issue,-20} {findings.Count(f => f.Issue == issue)}");

        if (findings.Count == 0) return;
        Console.WriteLine();
        Console.WriteLine("Findings by origin (a finding spanning several origins counts for each):");
        var byOrigin = findings
            .SelectMany(f => f.Files.Select(file => inventory.Files[file].Origin).Distinct(StringComparer.OrdinalIgnoreCase).Select(o => (Origin: o, f.Issue)))
            .GroupBy(x => x.Origin, StringComparer.OrdinalIgnoreCase)
            .OrderByDescending(g => g.Count());
        foreach (var origin in byOrigin)
            Console.WriteLine($"  {origin.Key,-40} {origin.Count()}");
    }

    private static void WriteCsv(string csvPath, LinkerInventory inventory, List<Finding> findings)
    {
        var output = Path.GetFullPath(csvPath);
        Directory.CreateDirectory(Path.GetDirectoryName(output)!);
        File.WriteAllLines(output, new[] { Csv("Issue", "Linker", "Object", "Origins", "Detail", "Files") }
            .Concat(findings.Select(f => Csv(f.Issue, f.Linker, f.Object, OriginsOf(inventory, f), f.Detail,
                string.Join(";", f.Files.Select(file => inventory.Files[file].Path))))), new UTF8Encoding(false));
        Console.WriteLine($"Report: {output}");
    }

    private static string Truncate(string text, int max) =>
        text.Length <= max ? text : $"{text[..max]}... (+{text.Length - max} chars, see --csv)";

    private static string Csv(params string[] fields) =>
        string.Join(",", fields.Select(f => f.IndexOfAny([',', '"', '\r', '\n']) >= 0 ? $"\"{f.Replace("\"", "\"\"")}\"" : f));

    private static int Fail(string message)
    {
        Console.Error.WriteLine(message);
        return 2;
    }

    private static void PrintUsage()
    {
        Console.WriteLine("Usage: NetIndexingChecker [LMP game root] [--csv <report.csv>] [--dump <linkers.csv>] [--limit <n>] [--threads <n>]");
        Console.WriteLine("--dump writes one row per (linker, file): declaration, guid, count, and that file's net index range for the linker.");
        Console.WriteLine("--game LMP|LE3|ME3 checks another game's packages (default LMP; others need the root). --include a,b only scans packages whose relative path contains one of the substrings.");
        Console.WriteLine("Checks every package under the LMP game directory (basegame and DLC) for net-indexing conformance:");
        Console.WriteLine("  - every linker has a guid, and all of its declarations agree on it");
        Console.WriteLine("  - every object has the same NetIndex in every file that contains it");
        Console.WriteLine("  - no two objects in a linker share a NetIndex, and each linker's count covers its highest NetIndex");
        Console.WriteLine("  - localized content (RF_LocalizedResource linkers, localized files' own linkers) is never networked: LOCALIZED_NETWORKED");
        Console.WriteLine("The game root defaults to the LMP install configured in LEC. Exit code: 0 clean, 1 findings, 2 bad arguments.");
        Console.WriteLine($"--limit caps findings printed per category (default {DefaultLimit}); --csv always writes all of them.");
    }
}
