using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Packages.NetIndexing;
using LegendaryExplorerCore.Unreal;
using ProjectMilan.Pipelines.Finalize;
using ProjectMilanCore;

namespace ProjectMilan.Pipelines.Mod.BaseDelta
{
    /// <summary>
    /// Keeps net indexes append-only in the vanilla packages BaseDelta patches: an object vanilla LE3 already numbers keeps
    /// (or is moved to) its canonical index, and anything BaseDelta adds is numbered after the linker's highest index, so
    /// patched files and the DLC never disagree about who owns an index. Conformance reads the resulting indexes back from
    /// <see cref="PatchedScans"/>.
    /// </summary>
    internal static class BaseDeltaNetIndexing
    {
        private const string LOG_CATEGORY = "Milan-BaseDeltaNetIndexing";

        /// <summary>How many appended keys a per-file log line names.</summary>
        private const int LoggedAppendedKeys = 5;

        /// <summary>
        /// Net index scan of each patched package's final bytes, by game file name. Filled by
        /// <see cref="Observe"/> for fresh builds and checkpoint restores alike, since both go through the patched bytes.
        /// </summary>
        internal static readonly Dictionary<string, PackageNetScan> PatchedScans = new(StringComparer.OrdinalIgnoreCase);

        /// <summary>Scans a patched package's serialized bytes so Conformance knows what BaseDelta numbered.</summary>
        internal static void Observe(string gameFile, byte[] patched)
        {
            using var package = MEPackageHandler.OpenMEPackageFromStream(new MemoryStream(patched), gameFile);
            var scan = PackageNetScan.FromPackage(package, gameFile);
            if (scan.Error != null)
            {
                MilanLog.Fatal($"Unable to net index scan patched {gameFile}: {scan.Error} - this is a fatal error.", customPrefix: LOG_CATEGORY);
                Environment.Exit(1);
            }

            PatchedScans[gameFile] = scan;
        }

        /// <summary>
        /// Numbers every networked object of <paramref name="patched"/> and raises the counts of the linkers it declares.
        /// Call right before the patched package is serialized.
        /// </summary>
        /// <param name="patched">The patched package, modified in place.</param>
        /// <param name="gameFile">File name of the vanilla file it was built from (e.g. SFXGame.pcc).</param>
        internal static void Apply(IMEPackage patched, string gameFile)
        {
            var cache = VanillaNetIndexCache.Shared;
            var vanillaIndexes = ReadVanillaIndexes(gameFile);
            string fileName = patched.FileNameNoExtension;
            bool localizationFile = NetIndexKeys.IsLocalizationFile(fileName);

            // Highest index in use per linker in this package, to allocate past.
            var maxIndex = new Dictionary<string, int>(StringComparer.OrdinalIgnoreCase);
            var forcedRoots = new List<ExportEntry>();
            var appended = new List<(ExportEntry Export, string Linker, string Key)>();
            int canonical = 0, kept = 0;

            // Pass 1: everything that already has an answer, so pass 2 knows where each linker's numbering ends.
            foreach (var export in patched.Exports)
            {
                if (NetIndexKeys.IsForcedExportRoot(export))
                {
                    export.NetIndex = -1;
                    forcedRoots.Add(export);
                    continue;
                }

                string linker = export.GetLinker();
                if (IsLocalized(cache, export, linker, fileName, localizationFile))
                    continue; // Never networked, and vanilla's own handling of it is left as is.

                string key = NetIndexKeys.GetLinkerQualifiedPath(export);
                int netIndex;
                if (cache.TryGetLinker(linker, out var info) && info.TryGetNetIndex(key, out netIndex))
                {
                    canonical++;
                }
                else if (vanillaIndexes.TryGetValue(key, out netIndex))
                {
                    kept++;
                }
                else
                {
                    appended.Add((export, linker, key));
                    continue;
                }

                export.NetIndex = netIndex;
                if (netIndex >= 0)
                    RaiseMax(maxIndex, linker, netIndex);
            }

            // Pass 2: new objects, in export order, past the highest index vanilla or this package uses.
            foreach (var (export, linker, key) in appended)
            {
                if (!maxIndex.TryGetValue(linker, out int max))
                    max = -1;
                if (cache.TryGetLinker(linker, out var info))
                    max = Math.Max(max, info.MaxNetIndex);

                export.NetIndex = max + 1;
                maxIndex[linker] = max + 1;
            }

            // Declarations: a count must cover every index of its linker, and never shrinks.
            var package = (MEPackage)patched;
            if (maxIndex.TryGetValue(fileName, out int fileMax) && !cache.IsLocalizedLinker(fileName) && !localizationFile)
                package.Gen0NetworkedObjectCount = Math.Max(package.Gen0NetworkedObjectCount, fileMax + 1);

            foreach (var root in forcedRoots)
            {
                string linker = root.InstancedFullPath;
                if (cache.IsLocalizedLinker(linker) || cache.IsLocalizationFileLinker(linker) || !maxIndex.TryGetValue(linker, out int rootMax))
                    continue;

                var counts = root.GenerationNetObjectCount;
                int existing = counts.Length > 0 ? counts[^1] : -1;
                if (rootMax + 1 > existing)
                {
                    var updated = counts.Length > 0 ? (int[])counts.Clone() : new int[1];
                    updated[^1] = rootMax + 1;
                    root.GenerationNetObjectCount = updated;
                }
            }

            string appendedKeys = appended.Count == 0
                ? ""
                : $" ({string.Join(", ", appended.Take(LoggedAppendedKeys).Select(a => a.Key))}{(appended.Count > LoggedAppendedKeys ? ", ..." : "")})";
            MilanLog.Information($"Net-indexed {gameFile}: {canonical} set to canonical, {kept} kept from vanilla, {appended.Count} appended{appendedKeys}; " +
                                 $"{fileName} header count {package.Gen0NetworkedObjectCount}", customPrefix: LOG_CATEGORY);
        }

        private static bool IsLocalized(VanillaNetIndexCache cache, ExportEntry export, string linker, string fileName, bool localizationFile) =>
            cache.IsLocalizedLinker(linker)
            || cache.IsLocalizationFileLinker(linker)
            || (localizationFile && linker.Equals(fileName, StringComparison.OrdinalIgnoreCase))
            || export.ObjectFlags.Has(UnrealFlags.EObjectFlags.LocalizedResource);

        private static void RaiseMax(Dictionary<string, int> maxIndex, string linker, int netIndex)
        {
            if (!maxIndex.TryGetValue(linker, out int max) || netIndex > max)
                maxIndex[linker] = netIndex;
        }

        /// <summary>
        /// The indexes the original vanilla file gives its objects, by linker-qualified key, for objects the canonical map
        /// doesn't cover. Includes the objects vanilla leaves unnumbered (-1): those exist already, so they aren't new and stay as they are.
        /// </summary>
        private static Dictionary<string, int> ReadVanillaIndexes(string gameFile)
        {
            var scan = PackageNetScan.Read(BaseDeltaHandler.GetVanillaCookedFilePath(gameFile), MEGame.LE3);
            if (scan.Error != null || scan.SkipReason != null)
            {
                MilanLog.Fatal($"Unable to net index scan vanilla {gameFile}: {scan.Error ?? scan.SkipReason} - this is a fatal error.", customPrefix: LOG_CATEGORY);
                Environment.Exit(1);
            }

            var indexes = new Dictionary<string, int>(StringComparer.OrdinalIgnoreCase);
            foreach (var observation in scan.Exports)
            {
                // First observation wins, but a real index beats an unnumbered duplicate.
                if (!indexes.TryAdd(observation.Key, observation.NetIndex) && indexes[observation.Key] < 0)
                    indexes[observation.Key] = observation.NetIndex;
            }

            return indexes;
        }
    }
}
