using System.Collections.Concurrent;
using LegendaryExplorerCore.GameFilesystem;
using LegendaryExplorerCore.Misc;
using LegendaryExplorerCore.Misc.ME3Tweaks;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Unreal;

namespace ShaderResearchTool;

/// <summary>
/// Finds packages where two or more Materials share an object name.
///
/// BioWare's T3D export is a flat "&lt;package&gt;/&lt;materialname&gt;.t3d" tree, but packages have
/// hierarchy: `Users.ParentA.CombinedEffect_Gore` and `Users.ParentB.CombinedEffect_Gore` are
/// different materials with the same object name, and only one file per name survives. Every such
/// name is a material the rebuild cannot reconstruct, so this enumerates exactly which packages
/// need a hierarchy-preserving re-export and how many materials each one loses.
///
/// Scans package files directly rather than the ObjectInstanceDB, because the DB does not record
/// class names and the count must cover Materials only.
/// </summary>
public static class CollisionsCommand
{
    /// <summary>
    /// Unreal package names are case insensitive -- "BioG_Glass" and "biog_glass" are the same
    /// package -- but the export table text that supplies this key is whatever casing the object
    /// happened to be cooked with, which is not guaranteed consistent across every file it was
    /// forced into. The default tuple comparer is ordinal, so without this a single package could
    /// silently split into two buckets here and its real collisions would go undetected.
    /// </summary>
    private sealed class GamePackageComparer : IEqualityComparer<(string game, string pkg)>
    {
        public bool Equals((string game, string pkg) x, (string game, string pkg) y) =>
            string.Equals(x.game, y.game, StringComparison.OrdinalIgnoreCase)
            && string.Equals(x.pkg, y.pkg, StringComparison.OrdinalIgnoreCase);

        public int GetHashCode((string game, string pkg) obj) =>
            HashCode.Combine(
                StringComparer.OrdinalIgnoreCase.GetHashCode(obj.game),
                StringComparer.OrdinalIgnoreCase.GetHashCode(obj.pkg));
    }

    private sealed class PackageResult
    {
        public string Game = "";
        public string Package = "";
        public string Source = "";
        public int Materials;
        public int DistinctNames;
        public int CollidingNames;
        public int Unrecoverable;
        public List<string> Examples = [];
        public bool Exported;
    }

    public static int Run(ToolPaths paths, string? le3Dir, string? me3Dir, string? t3dDir)
    {
        var store = new ConcurrentDictionary<(string game, string pkg), ConcurrentDictionary<string, byte>>(new GamePackageComparer());

        le3Dir ??= LE3Directory.CookedPCPath ?? Path.Combine(paths.GameRoot, "BioGame", "CookedPCConsole");
        if (Directory.Exists(le3Dir))
        {
            ScanLoose(le3Dir, "LE3", store);
        }
        else
        {
            Console.Error.WriteLine($"[LE3] not found: {le3Dir}");
        }

        me3Dir ??= TryGetMe3Path();
        if (me3Dir != null && Directory.Exists(me3Dir))
        {
            ScanLoose(me3Dir, "ME3", store);
            ScanSfars(me3Dir, store);
        }
        else
        {
            Console.Error.WriteLine($"[ME3] not found{(me3Dir != null ? $": {me3Dir}" : "; pass --me3 <dir>")}");
        }

        // Only packages BioWare actually exported matter: a collision in a package with no T3D
        // costs nothing today. Marking them keeps the ask to the developers minimal.
        var exported = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        if (t3dDir != null && Directory.Exists(t3dDir))
        {
            foreach (var d in Directory.GetDirectories(t3dDir)) exported.Add(Path.GetFileName(d));
            Console.WriteLine($"  {exported.Count} packages present in the T3D export at {t3dDir}");
        }

        var all = store.Select(kv => Summarise(kv.Key.game, kv.Key.pkg, kv.Value.Keys)).ToList();
        foreach (var r in all) r.Exported = exported.Count == 0 || exported.Contains(Path.GetFileNameWithoutExtension(r.Package));
        var colliding = all.Where(r => r.CollidingNames > 0)
            .OrderByDescending(r => r.Unrecoverable)
            .ToList();

        Directory.CreateDirectory(paths.OutputDir);
        var outPath = Path.Combine(paths.OutputDir, "material-name-collisions.tsv");
        using (var w = new StreamWriter(outPath))
        {
            w.WriteLine("game\tpackage\thasT3D\tmaterials\tdistinctNames\tcollidingNames\tmaterialsLost\texamples");
            foreach (var r in colliding)
            {
                w.WriteLine($"{r.Game}\t{r.Package}\t{r.Exported}\t{r.Materials}\t{r.DistinctNames}\t{r.CollidingNames}\t{r.Unrecoverable}\t{string.Join(", ", r.Examples.Take(5))}");
            }
        }

        Console.WriteLine();
        Console.WriteLine("=== material name collisions ===");
        foreach (var game in new[] { "LE3", "ME3" })
        {
            var g = all.Where(r => r.Game == game).ToList();
            if (g.Count == 0) continue;
            var gc = g.Where(r => r.CollidingNames > 0).ToList();
            Console.WriteLine($"  {game}: {g.Count} source packages, {g.Sum(r => r.Materials)} distinct materials");
            Console.WriteLine($"    packages with colliding material names : {gc.Count}");
            Console.WriteLine($"    materials unreachable by a flat export : {gc.Sum(r => r.Unrecoverable)}");
            var ex = gc.Where(r => r.Exported).ToList();
            Console.WriteLine($"    ...restricted to packages that WERE exported : {ex.Count} packages, {ex.Sum(r => r.Unrecoverable)} materials");
        }

        Console.WriteLine();
        Console.WriteLine("  worst packages (materials lost to a flat export):");
        Console.WriteLine($"    {"game",-5} {"materials lost",14}  {"materials",9}  package");
        foreach (var r in colliding.Where(r => r.Exported).Take(30))
        {
            Console.WriteLine($"    {r.Game,-5} {r.Unrecoverable,14}  {r.Materials,9}  {r.Package}");
        }

        Console.WriteLine();
        Console.WriteLine($"  full list written to {outPath}");
        return 0;
    }

    private static string? TryGetMe3Path()
    {
        try
        {
            var backup = ME3TweaksBackups.GetGameBackupPath(MEGame.ME3);
            if (backup != null) return backup;
        }
        catch
        {
            // Backup service unavailable; caller can pass --me3.
        }
        try
        {
            return ME3Directory.DefaultGamePath;
        }
        catch
        {
            return null;
        }
    }

    private static void ScanLoose(string dir, string game,
        ConcurrentDictionary<(string game, string pkg), ConcurrentDictionary<string, byte>> store)
    {
        var files = Directory.GetFiles(dir, "*.pcc", SearchOption.AllDirectories);
        Console.WriteLine($"[{game}] scanning {files.Length} packages in {dir}");
        int done = 0;

        Parallel.ForEach(files, file =>
        {
            try
            {
                using var pkg = MEPackageHandler.UnsafePartialLoad(file, _ => false);
                Accumulate(pkg, game, Path.GetFileName(file), store);
            }
            catch
            {
                // Unreadable package; nothing to report for it.
            }
            var n = Interlocked.Increment(ref done);
            if (n % 500 == 0) Console.WriteLine($"[{game}]   {n}/{files.Length}");
        });
    }

    /// <summary>
    /// ME3 keeps DLC (including all multiplayer content) inside SFAR archives, which is exactly
    /// where the MP-only materials live.
    /// </summary>
    private static void ScanSfars(string me3Dir,
        ConcurrentDictionary<(string game, string pkg), ConcurrentDictionary<string, byte>> store)
    {
        var dlcPath = Path.Combine(me3Dir, "BIOGame", "DLC");
        if (!Directory.Exists(dlcPath)) return;

        foreach (var dlcFolder in Directory.GetDirectories(dlcPath))
        {
            var sfarPath = Path.Combine(dlcFolder, "CookedPCConsole", "Default.sfar");
            if (!File.Exists(sfarPath)) continue;

            var dlcName = Path.GetFileName(dlcFolder);
            try
            {
                var dlc = new DLCPackage(sfarPath);
                var pccs = dlc.Files
                    .Where(f => f.isActualFile && f.FileName != null
                                && f.FileName.EndsWith(".pcc", StringComparison.OrdinalIgnoreCase))
                    .ToList();
                Console.WriteLine($"[ME3] scanning {pccs.Count} packages in {dlcName}");

                foreach (var entry in pccs)
                {
                    try
                    {
                        using var stream = dlc.DecompressEntry(entry);
                        using var pkg = MEPackageHandler.UnsafePartialLoadFromStream(stream, entry.FileName, _ => false);
                        Accumulate(pkg, "ME3", Path.GetFileName(entry.FileName), store);
                    }
                    catch
                    {
                        // Skip entries that will not decompress or parse.
                    }
                }
            }
            catch (Exception e)
            {
                Console.Error.WriteLine($"[ME3] could not read {dlcName}: {e.Message}");
            }
        }
    }

    /// <summary>
    /// Records every Material against its SOURCE package rather than the cooked file it was found
    /// in. Seekfree cooking scatters a source package's objects as forced exports across many level
    /// files -- EffectsMaterials has no cooked file of its own at all -- but the T3D export is
    /// organised one folder per source package, so that is the unit a collision has to be counted
    /// in. Paths are deduplicated because the same forced export appears in dozens of files.
    /// </summary>
    private static void Accumulate(IMEPackage pkg, string game, string fileName,
        ConcurrentDictionary<(string game, string pkg), ConcurrentDictionary<string, byte>> store)
    {
        var fileStem = Path.GetFileNameWithoutExtension(fileName);
        foreach (var export in pkg.Exports)
        {
            if (export.IsDefaultObject) continue;
            if (!export.ClassName.Equals("Material", StringComparison.OrdinalIgnoreCase)) continue;

            var ifp = export.InstancedFullPath;
            string sourcePackage, pathWithin;
            if (export.IsForcedExport && ifp.Contains('.'))
            {
                // A forced export carries its originating package as the root of its path.
                int dot = ifp.IndexOf('.');
                sourcePackage = ifp[..dot];
                pathWithin = ifp[(dot + 1)..];
            }
            else
            {
                sourcePackage = fileStem;
                pathWithin = ifp;
            }

            var bucket = store.GetOrAdd((game, sourcePackage), _ => new ConcurrentDictionary<string, byte>(StringComparer.OrdinalIgnoreCase));
            bucket.TryAdd(pathWithin, 0);
        }
    }

    private static PackageResult Summarise(string game, string sourcePackage, ICollection<string> paths)
    {
        var byName = new CaseInsensitiveDictionary<List<string>>();
        foreach (var path in paths)
        {
            int dot = path.LastIndexOf('.');
            var name = dot < 0 ? path : path[(dot + 1)..];
            if (!byName.TryGetValue(name, out var list)) byName[name] = list = [];
            list.Add(path);
        }

        var collisions = byName.Where(kv => kv.Value.Count > 1).ToList();
        return new PackageResult
        {
            Game = game,
            Package = sourcePackage,
            Materials = paths.Count,
            DistinctNames = byName.Count,
            CollidingNames = collisions.Count,
            // One file survives per name, so everything beyond the first copy is unrecoverable.
            Unrecoverable = collisions.Sum(kv => kv.Value.Count - 1),
            Examples = collisions.OrderByDescending(kv => kv.Value.Count)
                .Take(5).Select(kv => $"{kv.Key} x{kv.Value.Count}").ToList()
        };
    }
}
