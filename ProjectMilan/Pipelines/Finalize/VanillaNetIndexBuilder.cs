using System.Diagnostics;
using System.Text;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Packages.NetIndexing;
using ProjectMilanCore;
using static ProjectMilan.Pipelines.Finalize.VanillaNetIndexCache;

namespace ProjectMilan.Pipelines.Finalize
{
    internal sealed class ResolvedLinker
    {
        public required string Name { get; init; }
        public required int MaxNetIndex { get; init; }
        public required int MaxDeclaredCount { get; init; }
        public required List<(Guid Guid, int Count, DeclarationSource Source)> Declarations { get; init; }
        public required bool HasObjectMap { get; init; }

        /// <summary>Canonical (key, net index) pairs sorted by key; only filled when <see cref="HasObjectMap"/>.</summary>
        public required List<(string Key, int NetIndex)> Objects { get; init; }
    }

    /// <param name="Reason">"mismatch" (files disagreed), "collision" (another object owns the canonical index, so this one was moved) or "unassigned" (the differing files only have -1).</param>
    /// <param name="Detail">The values the vanilla files have, for the review file only; not stored in the cache.</param>
    internal sealed record ResolvedOverride(string Linker, string Key, int NetIndex, string Reason, string Detail);

    internal sealed class VanillaNetIndexResolution
    {
        /// <summary>Non-localized linkers, sorted by name.</summary>
        public required List<ResolvedLinker> Linkers { get; init; }
        public required List<string> LocalizedLinkers { get; init; }
        public required List<string> LocalizationFileLinkers { get; init; }
        /// <summary>Sorted by linker, then key.</summary>
        public required List<ResolvedOverride> Overrides { get; init; }
        public int TotalLinkerCount { get; init; }
    }

    /// <summary>
    /// Generates <c>Pipelines/Finalize/VanillaNetIndex.bin</c> (and the reviewable <c>VanillaNetIndexOverrides.txt</c>): scans every
    /// package LE3 loads and resolves the vanilla files' disagreements about net indexes into one canonical index per object.
    /// A one-off job, like <see cref="Conformance.BuildGuidMap"/>; LE3 gets no more updates.
    /// </summary>
    internal static class VanillaNetIndexBuilder
    {
        private const string LOG_CATEGORY = "MILAN-VanillaNetIndex";

        /// <summary>Packages scanned in parallel before being merged in order; bounds how many scans are alive at once.</summary>
        private const int ScanBatchSize = 128;

        public static void Run()
        {
            var timer = Stopwatch.StartNew();
            var source = ResolveSource();
            MilanLog.Information($"Reading vanilla LE3 from the {(source.IsBackup ? "ME3Tweaks backup" : "live install (no backup found)")}: {source.Root} ({source.Files.Count} packages)", customPrefix: LOG_CATEGORY);

            var inventory = Scan(source);
            double scanSeconds = timer.Elapsed.TotalSeconds;
            long peakWorkingSet = Process.GetCurrentProcess().PeakWorkingSet64;

            var resolution = Resolve(inventory);
            byte[] bytes = Serialize(resolution, source);

            string directory = Path.Combine(MilanShared.PipelineRoot, "Finalize");
            File.WriteAllBytes(Path.Combine(directory, FileName), bytes);
            File.WriteAllText(Path.Combine(directory, OverridesFileName), BuildOverridesReport(resolution, source), new UTF8Encoding(false));

            var overrides = resolution.Overrides;
            int collisions = overrides.Count(o => o.Reason == "collision");
            MilanLog.Information($"Source: {(source.IsBackup ? "backup" : "live install")} {source.Root}", customPrefix: LOG_CATEGORY);
            MilanLog.Information($"Packages: {source.Files.Count}, scan {scanSeconds:F1}s, peak working set {peakWorkingSet / (1024 * 1024)} MB", customPrefix: LOG_CATEGORY);
            MilanLog.Information($"Linkers: {resolution.TotalLinkerCount} total, {resolution.Linkers.Count} kept ({resolution.Linkers.Count(l => l.HasObjectMap)} with object map), " +
                                 $"{resolution.LocalizedLinkers.Count} localized, {resolution.LocalizationFileLinkers.Count} localization file linkers", customPrefix: LOG_CATEGORY);
            MilanLog.Information($"Stored keys: {resolution.Linkers.Sum(l => (long)l.Objects.Count)} ({resolution.Linkers.Sum(l => (long)l.Objects.Count(x => x.NetIndex < 0))} canonical -1)", customPrefix: LOG_CATEGORY);
            int unassigned = overrides.Count(o => o.Reason == "unassigned");
            MilanLog.Information($"Overrides: {overrides.Count} ({overrides.Count - collisions - unassigned} mismatch, {collisions} collision, {unassigned} unassigned)", customPrefix: LOG_CATEGORY);
            foreach (var top in overrides.GroupBy(o => o.Linker, StringComparer.OrdinalIgnoreCase).OrderByDescending(g => g.Count()).ThenBy(g => g.Key, StringComparer.OrdinalIgnoreCase).Take(5))
                MilanLog.Information($"  {top.Key}: {top.Count()} overrides ({top.Count(o => o.Reason == "collision")} collision, {top.Count(o => o.Reason == "unassigned")} unassigned)", customPrefix: LOG_CATEGORY);

            // What patching vanilla costs: every file holding a value that differs from a canonical one needs those objects patched.
            var perFile = OverridesPerFile(inventory, overrides);
            MilanLog.Information($"Vanilla files needing at least one override: {perFile.Count} of {source.Files.Count}", customPrefix: LOG_CATEGORY);
            foreach (var top in perFile.OrderByDescending(x => x.Value).ThenBy(x => x.Key, StringComparer.OrdinalIgnoreCase).Take(10))
                MilanLog.Information($"  {top.Key}: {top.Value} overrides", customPrefix: LOG_CATEGORY);
            MilanLog.Information($"Overrides naming Incisor: {overrides.Count(o => o.Key.Contains("Incisor", StringComparison.OrdinalIgnoreCase))}, Indra: {overrides.Count(o => o.Key.Contains("Indra", StringComparison.OrdinalIgnoreCase))}", customPrefix: LOG_CATEGORY);
            MilanLog.Information($"Wrote {Path.Combine(directory, FileName)}: {bytes.Length} bytes. Total {timer.Elapsed.TotalSeconds:F1}s", customPrefix: LOG_CATEGORY);
        }

        /// <summary>Loads the cache and reports how long it took and what it holds, for a quick sanity check.</summary>
        public static void Check()
        {
            var timer = Stopwatch.StartNew();
            long before = GC.GetTotalMemory(forceFullCollection: true);
            var cache = VanillaNetIndexCache.Load();
            double loadMs = timer.Elapsed.TotalMilliseconds;
            long after = GC.GetTotalMemory(forceFullCollection: true);
            MilanLog.Information($"Loaded in {loadMs:F0} ms, retained heap {(after - before) / 1024} KB; {cache.LinkerNames.Count} linkers, {cache.Overrides.Count} overrides, " +
                                 $"generated from {cache.SourceFileCount} packages ({(cache.SourceWasBackup ? "backup" : "live install")})", customPrefix: LOG_CATEGORY);

            timer.Restart();
            var source = ResolveSource();
            ComputeFingerprint(source.Files);
            MilanLog.Information($"Of which resolving the LE3 file set and fingerprinting it (warm) takes {timer.Elapsed.TotalMilliseconds:F0} ms", customPrefix: LOG_CATEGORY);

            timer.Restart();
            int keys = 0;
            if (cache.TryGetLinker("SFXGameContent", out var content))
                keys = content.Objects.Count();
            double firstAccessMs = timer.Elapsed.TotalMilliseconds;
            if (cache.TryGetLinker("SFXGameContent", out content))
            {
                MilanLog.Information($"SFXGameContent: max index {content.MaxNetIndex}, max declared count {content.MaxDeclaredCount}, {keys} keys, first access {firstAccessMs:F0} ms, " +
                                     $"declarations: {string.Join(", ", content.Declarations.Select(d => $"{d.Count} ({d.Source})"))}; retained heap now {(GC.GetTotalMemory(true) - before) / 1024} KB", customPrefix: LOG_CATEGORY);
            }
        }

        private static LinkerInventory Scan(VanillaSource source)
        {
            var inventory = new LinkerInventory();
            int threads = Math.Max(1, Environment.ProcessorCount / 2);
            int exportErrors = 0;
            var problems = new List<string>();

            for (int start = 0; start < source.Files.Count; start += ScanBatchSize)
            {
                int count = Math.Min(ScanBatchSize, source.Files.Count - start);
                var batch = new PackageNetScan[count];
                Parallel.For(0, count, new ParallelOptions { MaxDegreeOfParallelism = threads },
                    i => batch[i] = PackageNetScan.Read(source.Files[start + i].FullPath, MEGame.LE3));

                // Merge in sorted path order so file indexes, and with them the cache, are deterministic.
                for (int i = 0; i < count; i++)
                {
                    var scan = batch[i];
                    string relative = source.Files[start + i].RelativePath;
                    if (scan.Error != null)
                    {
                        problems.Add($"{relative}: {scan.Error}");
                        continue;
                    }

                    if (scan.SkipReason != null)
                    {
                        if (scan.SkipReason != "GuidCache") // GuidCache is the guid map, not content
                            problems.Add($"{relative}: package game is {scan.SkipReason}, not LE3");
                        continue;
                    }

                    exportErrors += scan.ExportErrors;
                    inventory.Add(scan, relative, OriginOf(relative));
                }

                MilanLog.Information($"Scanned {Math.Min(start + count, source.Files.Count)}/{source.Files.Count}", customPrefix: LOG_CATEGORY);
            }

            if (exportErrors > 0)
                problems.Add($"{exportErrors} export(s) could not be read");
            if (problems.Count > 0)
                throw new InvalidDataException($"Not writing an incomplete cache; {problems.Count} problem(s):{Environment.NewLine}{string.Join(Environment.NewLine, problems.Take(25))}");

            return inventory;
        }

        private static string OriginOf(string relativePath)
        {
            foreach (string part in relativePath.Split('\\', '/'))
            {
                if (part.StartsWith("DLC_", StringComparison.OrdinalIgnoreCase))
                    return part;
            }

            return "BaseGame";
        }

        private struct KeyEntry
        {
            public string Key;
            public int Index;
            public int Files;
            public bool Moved;
        }

        /// <summary>
        /// The resolution rules (bump <see cref="RULES_VERSION"/> when they change). Per non-localized linker:
        /// <list type="number">
        /// <item>Each key's canonical index is its most common index among vanilla observations at index &gt;= 0, ties to the lowest. A key that vanilla only ever has at -1 is canonical -1 (stored, so a copy of it is never renumbered).</item>
        /// <item>Keys sharing a canonical index &gt;= 0: the key present in the most files keeps it (ties to the lowest key). The others move to max + 1, +2, ... in sorted key order, where max is the highest canonical index after step 1. -1 is ignored here and by the maximum.</item>
        /// <item>An override is every (linker, key, index &gt;= 0) where at least one vanilla file has a different index, -1 included (that file gets the canonical index). Keys with canonical -1 never produce overrides.</item>
        /// </list>
        /// Localized linkers and localization files' own linkers are skipped entirely. Keys and linkers compare ordinal ignore case.
        /// </summary>
        internal static VanillaNetIndexResolution Resolve(LinkerInventory inventory)
        {
            var linkerNames = inventory.LinkerNames.Order(StringComparer.OrdinalIgnoreCase).ToList();
            var localizationFileLinkers = new List<string>();
            var resolved = new List<ResolvedLinker>();
            var overrides = new List<ResolvedOverride>();
            var observed = new List<int>();

            foreach (string name in linkerNames)
            {
                inventory.TryGetLinker(name, out var linker);
                if (linker.IsLocalizationFileLinker)
                    localizationFileLinkers.Add(name);
                if (linker.IsLocalized || linker.IsLocalizationFileLinker)
                    continue;

                // Step 1: canonical index per key.
                var entries = new List<KeyEntry>(linker.ObjectCount);
                foreach (var (key, observations) in linker.Objects)
                {
                    observed.Clear();
                    int files = 0, lastFile = -1;
                    for (int i = 0; i < observations.Count; i++)
                    {
                        var o = observations[i];
                        if (o.File != lastFile)
                        {
                            files++;
                            lastFile = o.File;
                        }

                        if (o.NetIndex >= 0)
                            observed.Add(o.NetIndex);
                    }

                    // Vanilla only ever leaves this key unnumbered: that is its canonical value too (-1).
                    int best = -1;
                    if (observed.Count > 0)
                    {
                        observed.Sort();
                        best = observed[0];
                        int bestRun = 0;
                        for (int i = 0, run = 0; i < observed.Count; i++)
                        {
                            run = i > 0 && observed[i] == observed[i - 1] ? run + 1 : 1;
                            if (run > bestRun) // strictly greater: the earlier (lower) value wins ties
                            {
                                bestRun = run;
                                best = observed[i];
                            }
                        }
                    }

                    entries.Add(new KeyEntry { Key = key, Index = best, Files = files });
                }

                entries.Sort((a, b) => StringComparer.OrdinalIgnoreCase.Compare(a.Key, b.Key));
                int vanillaMax = entries.Count == 0 ? -1 : entries.Max(e => e.Index);

                // Step 2: different objects at the same index.
                var losers = new List<int>();
                foreach (var group in Enumerable.Range(0, entries.Count).Where(i => entries[i].Index >= 0).GroupBy(i => entries[i].Index).Where(g => g.Count() > 1))
                {
                    int winner = group
                        .OrderByDescending(i => entries[i].Files)
                        .ThenBy(i => entries[i].Key, StringComparer.OrdinalIgnoreCase)
                        .First();
                    losers.AddRange(group.Where(i => i != winner));
                }

                // entries is already key sorted, so sorting the positions sorts the keys.
                losers.Sort();
                int next = vanillaMax;
                foreach (int position in losers)
                {
                    var entry = entries[position];
                    entry.Index = ++next;
                    entry.Moved = true;
                    entries[position] = entry;
                }

                // Step 3: overrides.
                foreach (var entry in entries)
                {
                    if (entry.Index < 0)
                        continue; // Canonical -1: every vanilla file already agrees.

                    linker.TryGetObject(entry.Key, out var observations);
                    bool differs = false, differsToIndex = false;
                    for (int i = 0; i < observations.Count; i++)
                    {
                        if (observations[i].NetIndex == entry.Index)
                            continue;
                        differs = true;
                        differsToIndex |= observations[i].NetIndex >= 0;
                    }

                    if (differs)
                    {
                        // "unassigned": the only files that differ have no index at all (-1) and get the canonical one.
                        string reason = entry.Moved ? "collision" : differsToIndex ? "mismatch" : "unassigned";
                        overrides.Add(new ResolvedOverride(name, entry.Key, entry.Index, reason, DescribeVanillaValues(inventory, observations)));
                    }
                }

                var declarations = linker.Declarations
                    .Select(d => (d.Declaration.Guid, Count: d.Declaration.NetObjectCount, d.Declaration.Source))
                    .Distinct()
                    .OrderBy(d => d.Source).ThenBy(d => d.Guid).ThenBy(d => d.Count)
                    .ToList();
                bool hasObjectMap = declarations.Any(d => d.Source == DeclarationSource.ForcedExportPackage);

                resolved.Add(new ResolvedLinker
                {
                    Name = name,
                    MaxNetIndex = entries.Count == 0 ? -1 : entries.Max(e => e.Index),
                    MaxDeclaredCount = declarations.Count == 0 ? -1 : declarations.Max(d => d.Count),
                    Declarations = declarations,
                    HasObjectMap = hasObjectMap,
                    Objects = hasObjectMap ? entries.Select(e => (e.Key, e.Index)).ToList() : []
                });
            }

            return new VanillaNetIndexResolution
            {
                Linkers = resolved,
                LocalizedLinkers = inventory.LocalizedLinkers.Order(StringComparer.OrdinalIgnoreCase).ToList(),
                LocalizationFileLinkers = localizationFileLinkers,
                Overrides = overrides,
                TotalLinkerCount = linkerNames.Count
            };
        }

        /// <summary>How many overrides each vanilla file has a differing value for, by file path; files with none are absent.</summary>
        private static Dictionary<string, int> OverridesPerFile(LinkerInventory inventory, List<ResolvedOverride> overrides)
        {
            var perFile = new Dictionary<string, int>(StringComparer.OrdinalIgnoreCase);
            var differing = new HashSet<int>();
            foreach (var o in overrides)
            {
                if (!inventory.TryGetLinker(o.Linker, out var linker) || !linker.TryGetObject(o.Key, out var observations))
                    continue;

                differing.Clear();
                for (int i = 0; i < observations.Count; i++)
                {
                    if (observations[i].NetIndex != o.NetIndex)
                        differing.Add(observations[i].File);
                }

                foreach (int file in differing)
                {
                    string path = inventory.Files[file].Path;
                    perFile[path] = perFile.GetValueOrDefault(path) + 1;
                }
            }

            return perFile;
        }

        /// <summary>"21731 x3 (A.pcc, B.pcc, C.pcc, ...); 21732 x120 (...)" - what each distinct index looks like in the vanilla files.</summary>
        private static string DescribeVanillaValues(LinkerInventory inventory, ObjectObservations observations)
        {
            return string.Join("; ", observations
                .GroupBy(o => o.NetIndex)
                .OrderBy(g => g.Key)
                .Select(g =>
                {
                    var paths = g.Select(o => inventory.Files[o.File].Path).Distinct().ToList();
                    string sample = string.Join(", ", paths.Take(3)) + (paths.Count > 3 ? ", ..." : "");
                    return $"{(g.Key < 0 ? "unassigned" : g.Key.ToString())} x{paths.Count} ({sample})";
                }));
        }

        private static string BuildOverridesReport(VanillaNetIndexResolution resolution, VanillaSource source)
        {
            var sb = new StringBuilder();
            sb.Append("# Vanilla LE3 objects whose net index is forced to a canonical value. Generated by --build-vanilla-netindex-cache; do not edit.\n");
            sb.Append($"# Rules version {RULES_VERSION}, {source.Files.Count} packages. {resolution.Overrides.Count} overrides.\n");
            sb.Append("# mismatch: vanilla files disagree; the index used by the most files wins (ties to the lowest).\n");
            sb.Append("# unassigned: some vanilla files have the object unnumbered (-1) and the rest agree on one index; the unnumbered files get it.\n");
            sb.Append("# collision: another object owns this index in vanilla (most files wins, ties to the lowest key); this one moved past the linker's maximum.\n");
            sb.Append("# Columns: linker | object key | canonical index | reason | vanilla values (index xFileCount (sample files))\n");
            foreach (var o in resolution.Overrides)
                sb.Append($"{o.Linker} | {o.Key} | {o.NetIndex} | {o.Reason} | {o.Detail}\n");
            return sb.ToString();
        }
    }
}
