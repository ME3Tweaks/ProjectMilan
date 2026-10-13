using System.Security.Cryptography;
using System.Text;
using LegendaryExplorerCore.GameFilesystem;
using LegendaryExplorerCore.Misc;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Packages.CloningImportingAndRelinking;
using LegendaryExplorerCore.Packages.NetIndexing;
using LegendaryExplorerCore.Unreal;
using LegendaryExplorerCore.Unreal.BinaryConverters;
using LegendaryExplorerCore.Unreal.Collections;
using Newtonsoft.Json;
using ProjectMilan.Pipelines.Mod.BaseDelta;
using ProjectMilanCore;

namespace ProjectMilan.Pipelines.Finalize
{
    /// <summary>
    /// Conforms the mod for networking by doing things such as net object counting and building the guid map
    /// </summary>
    internal class Conformance
    {
        private const string LOG_CATEGORY = @"MILAN-Conformance";
        public static void RunPipeline()
        {
            InternalRunPipeline();
        }

        private static void InternalRunPipeline()
        {
            // Fails with a regenerate message if the cache is missing or doesn't match the LE3 install.
            var run = new ConformanceRun(VanillaNetIndexCache.Shared);
            run.Run();

            // Ensure SFXGame is patched.
            //MPCommon.HackPatchParents(); // No longer needed.
        }

        /// <summary>
        /// Checks if the given object is a child of another object
        /// </summary>
        /// <param name="child"></param>
        /// <param name="parent"></param>
        /// <returns></returns>
        /// <exception cref="NotImplementedException"></exception>
        private static bool IsChildObjectOf(IEntry child, IEntry parent)
        {
            if (child == parent)
                return false; // it is not a child of itself

            while (child != null && child != parent)
            {
                child = child.Parent;
                if (child == parent)
                    return true;
            }

            return false;
        }

        /// <summary>
        /// A linker's numbering: the canonical vanilla indexes (read from the cache on demand), plus everything
        /// BaseDelta and the DLC have added past it.
        /// </summary>
        private sealed class LinkerNumbering(VanillaLinkerInfo? vanilla)
        {
            public VanillaLinkerInfo? Vanilla { get; } = vanilla;

            /// <summary>Keys numbered by BaseDelta or by this run that vanilla doesn't have.</summary>
            public Dictionary<string, int> Added { get; } = new(StringComparer.OrdinalIgnoreCase);

            /// <summary>Highest index taken, vanilla's included; -1 if none.</summary>
            public int Max { get; set; } = vanilla?.MaxNetIndex ?? -1;
        }

        /// <summary>
        /// One Conformance pass over the DLC output. Everything is deterministic: files are processed in relative path order
        /// and exports in UIndex order, and no guid is random, so two builds produce identical packages.
        /// </summary>
        private sealed class ConformanceRun
        {
            private readonly VanillaNetIndexCache cache;
            private readonly CaseInsensitiveDictionary<Guid> masterGuidMap;
            private readonly List<string> files;
            private readonly HashSet<string> localizedLinkers;

            /// <summary>Our localization files' own linkers (by file name).</summary>
            private readonly HashSet<string> localizationFileLinkers;
            private readonly Dictionary<string, LinkerNumbering> numbering = new(StringComparer.OrdinalIgnoreCase);
            private readonly Dictionary<string, Guid> guids = new(StringComparer.OrdinalIgnoreCase);

            /// <summary>What the BaseDelta-patched packages declare, by linker: (guid, count) per declaration.</summary>
            private readonly Dictionary<string, List<(Guid Guid, int Count)>> patchedDeclarations = new(StringComparer.OrdinalIgnoreCase);

            private int numberedExisting, numberedNew, networkOff, createdPackages;

            public ConformanceRun(VanillaNetIndexCache cache)
            {
                this.cache = cache;

                // This is the list of all known Guids in vanilla LE3
                masterGuidMap = JsonConvert.DeserializeObject<CaseInsensitiveDictionary<Guid>>(File.ReadAllText(Path.Combine(MilanShared.PipelineRoot, "Finalize", "GuidMap.json")))
                                ?? throw new InvalidDataException("GuidMap.json is empty.");

                // GuidCache files are the guid map, not content; they are never inventoried or conformed.
                var root = Program.Settings.OutputModPath;
                files = Directory.GetFiles(root, "*.pcc", SearchOption.AllDirectories)
                    .Where(p => !Path.GetFileNameWithoutExtension(p).StartsWith("GuidCache", StringComparison.OrdinalIgnoreCase))
                    .OrderBy(p => Path.GetRelativePath(root, p), StringComparer.OrdinalIgnoreCase)
                    .ToList();

                localizedLinkers = new HashSet<string>(cache.LocalizedLinkers, StringComparer.OrdinalIgnoreCase);
                localizationFileLinkers = files.Select(Path.GetFileNameWithoutExtension).Where(x => NetIndexKeys.IsLocalizationFile(x!))
                    .ToHashSet(StringComparer.OrdinalIgnoreCase)!;
            }

            public void Run()
            {
                MilanLog.Information($"Conforming {files.Count} packages", customPrefix: LOG_CATEGORY);

                if (BaseDeltaNetIndexing.PatchedScans.Count == 0)
                    MilanLog.Warning("BaseDelta recorded no patched packages; their net indexes can't be taken into account.", customPrefix: LOG_CATEGORY);

                ReadBaseDeltaDeclarations();
                FindLocalizedLinkers();
                SeedFromBaseDelta();
                AssignNetIndexes();
                var guidCacheEntries = WriteDeclarations();
                WriteGuidCache(guidCacheEntries);
                WriteLinkerTable();
            }

            /// <summary>True if the linker is never networked: localized by flag, or a localization file's own linker.</summary>
            /// <remarks>
            /// Localization files are matched by the files that exist (ours and vanilla's), never by testing a linker name for a
            /// language suffix: plenty of networked linkers end in one (BioDpl_Int, BioT_Citadel_Int).
            /// </remarks>
            private bool IsServerSideOnly(string linker) => localizedLinkers.Contains(linker) || localizationFileLinkers.Contains(linker) || cache.IsLocalizationFileLinker(linker);

            /// <summary>A root Package export that declares a linker: a forced-export root, or the package named after the file.</summary>
            private static bool IsDeclarationRoot(ExportEntry export, string fileName) =>
                NetIndexKeys.IsForcedExportRoot(export)
                || (export.idxLink == 0 && export.ClassName == "Package" && export.ObjectName.Instanced.Equals(fileName, StringComparison.OrdinalIgnoreCase));

            private LinkerNumbering GetNumbering(string linker)
            {
                if (!numbering.TryGetValue(linker, out var state))
                {
                    cache.TryGetLinker(linker, out var info);
                    state = new LinkerNumbering(info);
                    numbering[linker] = state;
                }

                return state;
            }

            private int GetOrAllocate(string linker, string key)
            {
                var state = GetNumbering(linker);
                if (state.Vanilla != null && state.Vanilla.TryGetNetIndex(key, out int netIndex))
                    return netIndex;
                if (state.Added.TryGetValue(key, out netIndex))
                    return netIndex;

                netIndex = ++state.Max;
                state.Added[key] = netIndex;
                numberedNew++;
                return netIndex;
            }

            /// <summary>Net object count every declaration of the linker carries: covers its highest index and never drops below vanilla's.</summary>
            private int CountOf(string linker)
            {
                var state = GetNumbering(linker);
                return Math.Max(Math.Max(state.Max + 1, state.Vanilla?.MaxDeclaredCount ?? -1), 0);
            }

            /// <summary>
            /// The guid every declaration of the linker carries: GuidMap.json (the vanilla guid map) first, else the guid most
            /// vanilla declarations agree on (ties to the lowest), else what BaseDelta gave a package it added, else one derived from the name.
            /// </summary>
            private Guid GuidOf(string linker)
            {
                if (guids.TryGetValue(linker, out var guid))
                    return guid;

                if (!masterGuidMap.TryGetValue(linker, out guid) || guid == Guid.Empty)
                {
                    var vanillaGuids = cache.TryGetLinker(linker, out var info)
                        ? info.Declarations.Where(d => d.Guid != Guid.Empty).Select(d => d.Guid).ToList()
                        : [];
                    if (vanillaGuids.Count > 0)
                    {
                        guid = vanillaGuids.GroupBy(g => g).OrderByDescending(g => g.Count()).ThenBy(g => g.Key).First().Key;
                    }
                    else if (patchedDeclarations.TryGetValue(linker, out var patched) && patched.Any(d => d.Guid != Guid.Empty))
                    {
                        guid = patched.First(d => d.Guid != Guid.Empty).Guid;
                    }
                    else
                    {
                        guid = new Guid(MD5.HashData(Encoding.UTF8.GetBytes($"ProjectMilan.Linker.{linker.ToUpperInvariant()}")));
                    }
                }

                guids[linker] = guid;
                return guid;
            }

            /// <summary>What the BaseDelta-patched packages declare, for <see cref="GuidOf"/> and the linker table.</summary>
            private void ReadBaseDeltaDeclarations()
            {
                foreach (var scan in BaseDeltaNetIndexing.PatchedScans.OrderBy(x => x.Key, StringComparer.OrdinalIgnoreCase).Select(x => x.Value))
                {
                    foreach (var declaration in scan.Declarations)
                    {
                        if (!patchedDeclarations.TryGetValue(declaration.Linker, out var list))
                            patchedDeclarations[declaration.Linker] = list = [];
                        list.Add((declaration.Guid, declaration.NetObjectCount));
                    }
                }
            }

            /// <summary>
            /// A linker is localized if any object in it carries RF_LocalizedResource, in a vanilla file (the cache already
            /// knows) or in anything we ship. Done before any numbering so localized linkers never reach the allocator.
            /// </summary>
            private void FindLocalizedLinkers()
            {
                int found = 0;
                foreach (var scan in BaseDeltaNetIndexing.PatchedScans.OrderBy(x => x.Key, StringComparer.OrdinalIgnoreCase).Select(x => x.Value))
                {
                    foreach (var observation in scan.Exports.Where(x => x.LocalizedResource))
                    {
                        if (localizedLinkers.Add(observation.Linker))
                            found++;
                    }
                }

                foreach (var path in files)
                {
                    using var package = MEPackageHandler.UnsafePartialLoad(path, x => false);
                    string fileName = package.FileNameNoExtension;
                    foreach (var export in package.Exports)
                    {
                        if (IsDeclarationRoot(export, fileName) || !export.ObjectFlags.Has(UnrealFlags.EObjectFlags.LocalizedResource))
                            continue;

                        if (localizedLinkers.Add(export.GetLinker()))
                            found++;
                    }
                }

                MilanLog.Information($"{localizedLinkers.Count} localized linkers ({cache.LocalizedLinkers.Count} from vanilla, {found} more from our packages)", customPrefix: LOG_CATEGORY);
            }

            /// <summary>
            /// Takes in what BaseDelta numbered. Those packages ship as patches to the game files, so Conformance can't change
            /// them: what they hold is taken, and the DLC numbers around it.
            /// </summary>
            private void SeedFromBaseDelta()
            {
                foreach (var scan in BaseDeltaNetIndexing.PatchedScans.OrderBy(x => x.Key, StringComparer.OrdinalIgnoreCase).Select(x => x.Value))
                {
                    foreach (var observation in scan.Exports)
                    {
                        if (observation.NetIndex < 0 || observation.LocalizedResource || IsServerSideOnly(observation.Linker))
                            continue;

                        var state = GetNumbering(observation.Linker);
                        if (state.Vanilla != null && state.Vanilla.TryGetNetIndex(observation.Key, out _))
                            continue; // Canonical, which BaseDelta already wrote.

                        state.Added.TryAdd(observation.Key, observation.NetIndex);
                        state.Max = Math.Max(state.Max, observation.NetIndex);
                    }
                }
            }

            /// <summary>
            /// Pass over every file: creates the same-named package export (so declarations exist before they're counted),
            /// takes localized objects off the network, and numbers the rest append-only.
            /// </summary>
            private void AssignNetIndexes()
            {
                MilanLog.Information("Assigning NetIndexes", customPrefix: LOG_CATEGORY);
                foreach (var path in files)
                {
                    using var package = (MEPackage)MEPackageHandler.OpenMEPackage(path);
                    string fileName = package.FileNameNoExtension;
                    bool localizationFile = NetIndexKeys.IsLocalizationFile(fileName);

                    if (!localizationFile && package.FindExport(fileName, "Package") == null)
                    {
                        // Generate same-named package export. Unsure if this matters really.
                        // Count and guid are written once every linker is counted.
                        ExportCreator.CreatePackageExport(package, NameReference.FromInstancedString(fileName));
                        createdPackages++;
                    }

                    foreach (var export in package.Exports)
                    {
                        if (IsDeclarationRoot(export, fileName))
                        {
                            // A declaration, not a net object. A localized linker's has no count at all.
                            export.NetIndex = -1;
                            if (IsServerSideOnly(export.InstancedFullPath))
                                export.GenerationNetObjectCount = [];
                            continue;
                        }

                        string linker = export.GetLinker();
                        if (IsServerSideOnly(linker) || (localizationFile && linker.Equals(fileName, StringComparison.OrdinalIgnoreCase)))
                        {
                            export.NetIndex = -1;
                            networkOff++;
                            continue;
                        }

                        int before = numberedNew;
                        export.NetIndex = GetOrAllocate(linker, NetIndexKeys.GetLinkerQualifiedPath(export));
                        if (numberedNew == before)
                            numberedExisting++;
                    }

                    if (package.IsModified)
                    {
                        package.Save(diskIOSyncLock: MilanShared.DiskIOSyncLock);
                    }
                }

                MilanLog.Information($"NetIndexes: {numberedExisting} objects took an existing index, {numberedNew} new, {networkOff} localized objects off the network, {createdPackages} same-named packages created", customPrefix: LOG_CATEGORY);
            }

            /// <summary>
            /// Writes the final count and guid into every declaration of every linker (the file summary and the root package
            /// exports) so the whole install agrees. Returns the guid cache contents: each declared linker that has net objects.
            /// </summary>
            private SortedDictionary<string, Guid> WriteDeclarations()
            {
                MilanLog.Information("Writing linker declarations", customPrefix: LOG_CATEGORY);
                var guidCacheEntries = new SortedDictionary<string, Guid>(StringComparer.OrdinalIgnoreCase);

                foreach (var path in files)
                {
                    using var package = (MEPackage)MEPackageHandler.OpenMEPackage(path);
                    string fileName = package.FileNameNoExtension;
                    bool localizationFile = NetIndexKeys.IsLocalizationFile(fileName);
                    ExportEntry? sameNamedExp = null;

                    foreach (var export in package.Exports)
                    {
                        if (!IsDeclarationRoot(export, fileName))
                            continue;

                        export.NetIndex = -1;
                        if (!localizationFile)
                        {
                            export.PackageFlags = UnrealFlags.EPackageFlags.AllowDownload |
                                                  UnrealFlags.EPackageFlags.NoExportsData;
                        }

                        string linker = export.InstancedFullPath;
                        if (linker.Equals(fileName, StringComparison.OrdinalIgnoreCase))
                            sameNamedExp = export;
                        if (IsServerSideOnly(linker))
                            continue; // Left with no count and no guid.

                        int count = CountOf(linker);
                        var guid = GuidOf(linker);
                        export.GenerationNetObjectCount = [count];
                        export.PackageGUID = guid;
                        if (count > 0)
                            guidCacheEntries[linker] = guid;
                    }

                    if (sameNamedExp != null && EntryExporter.IsLevelFile(fileName))
                    {
                        // Set package flags
                        sameNamedExp.PackageFlags = UnrealFlags.EPackageFlags.AllowDownload |
                                                    UnrealFlags.EPackageFlags.NoExportsData |
                                                    UnrealFlags.EPackageFlags.Cooked |
                                                    UnrealFlags.EPackageFlags.Map |
                                                    UnrealFlags.EPackageFlags.DisallowLazyLoading |
                                                    UnrealFlags.EPackageFlags.RequireImportsAlreadyLoaded |
                                                    UnrealFlags.EPackageFlags.Protected;
                        package.setFlags(sameNamedExp.PackageFlags);
                    }

                    // The file's own linker: a localization file is its own server-side only linker.
                    if (localizationFile)
                    {
                        package.Gen0NetworkedObjectCount = 0;
                    }
                    else if (!IsServerSideOnly(fileName))
                    {
                        int count = CountOf(fileName);
                        var guid = GuidOf(fileName);
                        package.Gen0NetworkedObjectCount = count;
                        package.PackageGuid = guid;
                        if (count > 0)
                            guidCacheEntries[fileName] = guid;
                    }

                    package.Gen0NameCount = package.Names.Count;
                    package.Gen0ExportCount = package.Exports.Count;

                    if (package.IsModified)
                    {
                        MilanLog.Information($"Saving conformed package {package.FileNameNoExtension}.pcc", customPrefix: LOG_CATEGORY);
                        package.Save(diskIOSyncLock: MilanShared.DiskIOSyncLock);
                        MilanShared.RefreshMilanFiles = true;
                    }
                }

                return guidCacheEntries;
            }

            /// <summary>
            /// Writes the package guid cache which is used with replication. All packages that had a 'source' file in
            /// source need to be in GuidCache, as long as they have at least one net object, so clients know they are in sync with server.
            /// </summary>
            private void WriteGuidCache(SortedDictionary<string, Guid> entries)
            {
                var guidCacheP = MEPackageHandler.CreateAndOpenPackage(Path.Combine(Program.Settings.OutputModPath, "CookedPCConsole", $"GuidCache_{MilanShared.DLC_NAME}.pcc"), MEGame.LE3);
                var guidCache = ExportCreator.CreateExport(guidCacheP, "GuidCache", "GuidCache", indexed: false);

                var map = new UMultiMap<NameReference, Guid>();
                foreach (var entry in entries)
                {
                    map.TryAddUnique(NameReference.FromInstancedString(entry.Key), entry.Value);
                }

                GuidCache gc = new GuidCache();
                gc.PackageGuidMap = map;

                guidCache.WriteBinary(gc);
                guidCacheP.Save(diskIOSyncLock: MilanShared.DiskIOSyncLock);
                MilanShared.RefreshMilanFiles = true;
                MilanLog.Information($"GuidCache_{MilanShared.DLC_NAME} lists {entries.Count} linkers", customPrefix: LOG_CATEGORY);
            }

            /// <summary>
            /// Writes MilanDelta/linkers.json: what Mod Manager has to apply to the basegame files it copies so they agree
            /// with the DLC. Dev-time input for the slash generator only; clients never read it.
            /// </summary>
            private void WriteLinkerTable()
            {
                // Every non-localized linker a vanilla file or a patched package declares, kept if its final guid or count
                // differs from at least one of those declarations. A declaration with no guid always differs; no count and 0
                // both mean server-side only, so they only differ from a nonzero count.
                var listed = new SortedDictionary<string, (Guid Guid, int Count)>(StringComparer.OrdinalIgnoreCase);
                foreach (var name in cache.LinkerNames.Concat(patchedDeclarations.Keys).Distinct(StringComparer.OrdinalIgnoreCase))
                {
                    if (IsServerSideOnly(name))
                        continue;

                    var declared = new List<(Guid Guid, int Count)>();
                    if (cache.TryGetLinker(name, out var info))
                        declared.AddRange(info.Declarations.Select(d => (d.Guid, d.Count)));
                    if (patchedDeclarations.TryGetValue(name, out var patched))
                        declared.AddRange(patched);
                    if (declared.Count == 0)
                        continue;

                    int count = CountOf(name);
                    var guid = GuidOf(name);
                    if (declared.Any(d => d.Guid != guid || Math.Max(0, d.Count) != count))
                        listed[name] = (guid, count);
                }

                var overrides = cache.Overrides
                    .OrderBy(o => o.Linker, StringComparer.OrdinalIgnoreCase)
                    .ThenBy(o => o.Key, StringComparer.OrdinalIgnoreCase)
                    .ToList();
                var serverSideOnly = cache.LocalizedLinkers.Order(StringComparer.OrdinalIgnoreCase).ToList();

                using var stream = new MemoryStream();
                using (var writer = new System.Text.Json.Utf8JsonWriter(stream, new System.Text.Json.JsonWriterOptions
                       {
                           Indented = true,
                           NewLine = "\n",
                           Encoder = System.Text.Encodings.Web.JavaScriptEncoder.UnsafeRelaxedJsonEscaping
                       }))
                {
                    writer.WriteStartObject();
                    writer.WriteNumber("version", 1);

                    writer.WriteStartObject("linkers");
                    foreach (var (name, linker) in listed)
                    {
                        writer.WriteStartObject(name);
                        writer.WriteString("guid", linker.Guid.ToString("D"));
                        writer.WriteNumber("count", linker.Count);
                        writer.WriteEndObject();
                    }
                    writer.WriteEndObject();

                    writer.WriteStartArray("overrides");
                    foreach (var (linker, key, netIndex) in overrides)
                    {
                        writer.WriteStartObject();
                        writer.WriteString("linker", linker);
                        writer.WriteString("key", key);
                        writer.WriteNumber("netindex", netIndex);
                        writer.WriteEndObject();
                    }
                    writer.WriteEndArray();

                    writer.WriteStartArray("serverSideOnly");
                    foreach (var linker in serverSideOnly)
                        writer.WriteStringValue(linker);
                    writer.WriteEndArray();

                    writer.WriteEndObject();
                }

                // MilanDelta is cleaned at the start of a build, and WriteMilanDeltaOutput only adds to it.
                Directory.CreateDirectory(BaseDeltaHandler.MilanDeltaFolder);
                var outPath = Path.Combine(BaseDeltaHandler.MilanDeltaFolder, "linkers.json");
                File.WriteAllBytes(outPath, stream.ToArray());

                MilanLog.Information($"Wrote {outPath}: {listed.Count} linkers, {overrides.Count} overrides, {serverSideOnly.Count} serverSideOnly. " +
                                     $"Final counts: SFXGameContent {CountOf("SFXGameContent")}, SFXGame {CountOf("SFXGame")}", customPrefix: LOG_CATEGORY);
            }
        }

        public static void BuildGuidMap()
        {

            var outPath = Path.Combine(MilanShared.PipelineRoot, "Finalize", "GuidMap.json");
            var guidMap = new CaseInsensitiveDictionary<Guid>();

            // Basegame guid map is completely wrong. we must calculate our own.

            // LE - inventory all packages
            foreach (var file in MELoadedFiles.GetFilesLoadedInGame(MEGame.LE3))
            {
                if (file.Value == "GuidCache.pcc")
                    continue; // Self
                if (file.Value.GetUnrealLocalization() != MELocalization.None)
                    continue;

                MilanLog.Information($"Inventorying {file.Key}", customPrefix: LOG_CATEGORY);
                var package = MEPackageHandler.UnsafePartialLoad(file.Value, x => x.ClassName == "Package");
                if (!guidMap.ContainsKey(NameReference.FromInstancedString(package.FileNameNoExtension)) && package.PackageGuid != Guid.Empty)
                {
                    guidMap[NameReference.FromInstancedString(package.FileNameNoExtension)] = package.PackageGuid;
                }

                foreach (var packageExport in package.Exports.Where(x => x.ClassName == "Package"))
                {
                    if (packageExport.PackageGUID == Guid.Empty)
                        continue;
                    if (!guidMap.ContainsKey(packageExport.ObjectName.Instanced)) // Do we need to use instanced? For things like BioD_ProEar_440. how does that work for guids
                    {
                        guidMap[packageExport.ObjectName.Instanced] = packageExport.PackageGUID;
                    }
                }
            }

            MilanLog.Information("Reading OT GUIDCaches", customPrefix: LOG_CATEGORY);
            // Now inventory MP from OT. We will use it's guids
            var me3GuidCache = MilanShared.GetME3Package($"GuidCache.pcc");
            var cache = ObjectBinary.From<GuidCache>(me3GuidCache.Exports[0]);
            foreach (var map in cache.PackageGuidMap)
            {
                if (!guidMap.ContainsKey(map.Key))
                {
                    guidMap[map.Key.Instanced] = map.Value;
                }
            }

            var i = 1;
            while (i <= 5)
            {
                var dlcName = $"DLC_CON_MP{i}";
                me3GuidCache = MilanShared.GetME3Package($"GuidCache_{dlcName}.pcc");
                cache = ObjectBinary.From<GuidCache>(me3GuidCache.Exports[0]);
                foreach (var map in cache.PackageGuidMap)
                {
                    if (!guidMap.ContainsKey(map.Key))
                    {
                        guidMap[map.Key.Instanced] = map.Value;
                    }
                }

                i++;
            }

            // Save cached guidmap.
            File.WriteAllText(outPath, JsonConvert.SerializeObject(guidMap, Formatting.Indented));

            // Save base GuidCache.pcc
            var guidCache = MEPackageHandler.CreateAndOpenPackage(Path.Combine(MilanShared.PipelineRoot, "Mod", "PrecomputedBASEGAME", "GuidCache.pcc"), MEGame.LE3);
            var gc = new GuidCache
            {
                PackageGuidMap = new UMultiMap<NameReference, Guid>(
                    guidMap.Where(x=>
                    {
                        var info =  MilanShared.LE3ObjectDB.GetInfo(x.Key);
                        return info != null && info.GenerationNetObjCount > 0;
                    }).Select(x => new KeyValuePair<NameReference, Guid>(NameReference.FromInstancedString(x.Key), x.Value)))
            };
            var exp = ExportCreator.CreateExport(guidCache, "GuidCache", "GuidCache", indexed: false);
            exp.WriteBinary(gc);
            guidCache.Save(diskIOSyncLock: MilanShared.DiskIOSyncLock);

        }
    }
}
