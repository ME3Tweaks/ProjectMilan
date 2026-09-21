using LegendaryExplorerCore.Compression;
using LegendaryExplorerCore.GameFilesystem;
using LegendaryExplorerCore.Helpers;
using LegendaryExplorerCore.Misc;
using LegendaryExplorerCore.Misc.ME3Tweaks;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Packages.CloningImportingAndRelinking;
using LegendaryExplorerCore.Unreal;
using LegendaryExplorerCore.Unreal.ObjectInfo;
using Newtonsoft.Json;
using System.IO.Compression;

namespace LEDecooker
{
    /// <summary>
    /// Builds the support databases that LEDecooker embeds as supportdbs.zip.
    ///
    /// Every database is produced by a SINGLE walk over the game's packages. Each database used to
    /// walk the game itself, so a full ME3 run opened and decompressed all 18 DLC SFARs six times
    /// over. Decompressing and parsing packages dominates the runtime -- the indexing on top of it is
    /// nearly free -- so the number of walks, not the number of databases, was the cost.
    /// </summary>
    internal class SupportGenerators
    {
#if DEBUG
        /// <summary>
        /// Which databases a run should produce. All of them come from the same walk; this only
        /// decides what gets inventoried and written, so asking for one is not much cheaper than
        /// asking for all of them.
        /// </summary>
        [Flags]
        public enum SupportDatabase
        {
            None = 0,
            /// <summary>texturedb_&lt;game&gt;.json</summary>
            Textures = 1 << 0,
            /// <summary>&lt;type&gt;db_&lt;game&gt;.json, one per object type</summary>
            ObjectTypes = 1 << 1,
            /// <summary>materialifps_&lt;game&gt;.json</summary>
            MaterialNesting = 1 << 2,
            /// <summary>&lt;game&gt;.bin, the ObjectInstanceDB</summary>
            ObjectInstances = 1 << 3,
            All = Textures | ObjectTypes | MaterialNesting | ObjectInstances
        }

        /// <summary>
        /// Object types given their own lookup database. All are matched on exact class name.
        /// </summary>
        private static readonly (string ObjectType, bool IsA)[] DefaultObjectTypes =
        [
            ("MaterialInstanceConstant", false),
            ("StaticMesh", false),
            ("RvrEffectsMaterialUser", false),
            // TerrainMaterial is just a thin wrapper (UV mapping params + a MaterialInterface reference +
            // a displacement texture) authored at package root right alongside its owning
            // TerrainLayerSetup, same as a Material or MaterialInstanceConstant -- not nested under
            // TheWorld, so the existing "skip TheWorld" filter in InventoryObjectTypes doesn't exclude it.
            // Needed so MilanShaderHost can find and compile terrain materials the same way it does
            // regular ones (see MilanShaderPackageBuilder.AddTerrainActorForMaterial).
            ("TerrainMaterial", false)
        ];

        /// <summary>
        /// DO NOT CHANGE!
        /// </summary>
        class TexInfo
        {
            public string packagefile { get; set; }
            public string memoryfullpath { get; set; }
            public string classname { get; set; }
        }

        /// <summary>
        /// One package to inventory, plus the path every database should record for it.
        /// </summary>
        private sealed class PackageSource
        {
            /// <summary>
            /// The path written into the databases. Relative to the game root for loose files, and
            /// the archive's own "/BIOGame/DLC/.../file.pcc" form for SFAR entries.
            /// DecookerShared.OpenPackage trims the leading separator and combines this with the
            /// backup root, and SFARPackageCache matches on forward slashes, so the SFAR form is
            /// stored verbatim rather than normalised.
            /// </summary>
            public string StoredPath;

            /// <summary>Full path on disk. Null for packages that live inside an SFAR.</summary>
            public string DiskPath;

            /// <summary>Owning archive, or null for a loose file.</summary>
            public DLCPackage Archive;

            /// <summary>Index into the archive's file list. Only meaningful with an archive.</summary>
            public int ArchiveEntry = -1;

            /// <summary>
            /// True when this file is part of the game's actual load order. The material nesting and
            /// object instance databases only index those; the texture and object type databases
            /// have always indexed the raw directory tree, which also picks up packages shadowed by
            /// a higher-mount DLC.
            /// </summary>
            public bool LoadedInGame;

            public string Extension => Path.GetExtension(DiskPath ?? StoredPath);
        }

        /// <summary>
        /// Builds every support database for a game in one pass.
        /// </summary>
        /// <param name="game">Game to inventory.</param>
        /// <param name="databases">Which databases to produce.</param>
        /// <param name="objectTypes">Object types to build lookup databases for; defaults to the standard three.</param>
        public static void GenerateSupportFiles(MEGame game, SupportDatabase databases = SupportDatabase.All,
            (string ObjectType, bool IsA)[] objectTypes = null)
        {
            objectTypes ??= DefaultObjectTypes;
            if (!databases.HasFlag(SupportDatabase.ObjectTypes))
            {
                objectTypes = [];
            }

            var gameRoot = ResolveGameRoot(game);
            if (gameRoot == null)
            {
                return;
            }

            // LE packages are Oodle compressed. Without the DLL every single package fails to open
            // and the run would otherwise complete "successfully" having inventoried nothing.
            if (game.IsLEGame() && !OodleHelper.EnsureOodleDll(gameRoot))
            {
                Console.Error.WriteLine($"Could not load the oodle DLL from {gameRoot}; no {game} package can be read. Aborting.");
                return;
            }

            var sources = BuildPackageList(game, gameRoot);
            Console.WriteLine($"  {sources.Count} packages to inventory");

            // Accumulators. The three JSON databases are filled during the parallel phase and are
            // therefore lock-guarded; the ObjectInstanceDB is filled in file order afterwards.
            var textureDb = new CaseInsensitiveDictionary<TexInfo>();
            var objectTypeDbs = objectTypes.ToDictionary(
                t => t.ObjectType,
                _ => new CaseInsensitiveDictionary<CaseInsensitiveDictionary<string>>(),
                StringComparer.OrdinalIgnoreCase);
            var nestingDb = new CaseInsensitiveDictionary<CaseInsensitiveDictionary<string>>();
            ObjectInstanceDB objectDb = databases.HasFlag(SupportDatabase.ObjectInstances)
                ? ObjectInstanceDB.CreateEmpty(game)
                : null;

            string textureExtension = game == MEGame.ME1 ? ".upk" : ".pcc";
            // Only the ObjectInstanceDB needs export data; when it is not being built, every package
            // can be opened with its tables alone, which is substantially faster.
            bool needsExportData = objectDb != null;
            int done = 0;
            int failed = 0;

            // Packages are loaded in parallel, then handed to the ObjectInstanceDB strictly in list
            // order. ObjectInstanceDB is not thread safe, and more importantly its file order decides
            // which package wins when several contain the same object -- building it out of order
            // would silently change what the decooker resolves to from one run to the next.
            const int BatchSize = 64;
            for (int start = 0; start < sources.Count; start += BatchSize)
            {
                int count = Math.Min(BatchSize, sources.Count - start);
                var batch = sources.GetRange(start, count);
                var loaded = new IMEPackage[count];

                Parallel.For(0, count, i =>
                {
                    var src = batch[i];
                    try
                    {
                        var package = OpenForInventory(src, needsExportData);
                        loaded[i] = package;

                        if (databases.HasFlag(SupportDatabase.Textures)
                            && src.Extension.CaseInsensitiveEquals(textureExtension))
                        {
                            InventoryTextures(package, src, textureDb);
                        }

                        if (objectTypes.Length > 0 && IsObjectTypeCandidate(game, src))
                        {
                            InventoryObjectTypes(package, src, objectTypes, objectTypeDbs);
                        }

                        if (databases.HasFlag(SupportDatabase.MaterialNesting) && src.LoadedInGame)
                        {
                            InventoryMaterialNesting(package, nestingDb);
                        }
                    }
                    catch (Exception e)
                    {
                        Interlocked.Increment(ref failed);
                        DecookerLog.Warning($"Could not inventory {src.StoredPath}: {e.Message}");
                    }

                    int n = Interlocked.Increment(ref done);
                    if (n % 100 == 0 || n == sources.Count)
                    {
                        Console.Write($"\r  [{n}/{sources.Count}]");
                    }
                });

                if (objectDb != null)
                {
                    for (int i = 0; i < count; i++)
                    {
                        var package = loaded[i];
                        if (package == null || !batch[i].LoadedInGame) continue;

                        // SFAR content is inserted at the front so DLC outranks the basegame copy of
                        // an object, which is what the game itself does.
                        objectDb.AddFileToDB(package, batch[i].StoredPath, insertAtStart: batch[i].Archive != null,
                            gamePathOverride: gameRoot);
                    }
                }

                foreach (var package in loaded)
                {
                    package?.Dispose();
                }
            }

            Console.WriteLine();
            if (failed > 0)
            {
                Console.WriteLine($"  {failed} of {sources.Count} packages could not be read");
            }

            // Refuse to publish a database built from a game that largely would not open. These
            // files are overwritten in place, and a run that failed wholesale -- a missing
            // decompression DLL, a half-copied backup -- would otherwise replace good databases with
            // empty ones and only be noticed later, at decook time.
            if (failed * 20 > sources.Count)
            {
                Console.Error.WriteLine($"Aborting: {failed} of {sources.Count} packages failed to open, so these databases would be incomplete. Nothing was written.");
                return;
            }

            var supportFiles = LocateSupportFiles();
            if (databases.HasFlag(SupportDatabase.Textures))
            {
                WriteJson(Path.Combine(supportFiles, $"texturedb_{game}.json"), textureDb);
            }

            foreach (var (type, db) in objectTypeDbs)
            {
                WriteJson(Path.Combine(supportFiles, $"{type.ToLower()}db_{game}.json"), db);
            }

            if (databases.HasFlag(SupportDatabase.MaterialNesting))
            {
                WriteJson(Path.Combine(supportFiles, $"materialifps_{game}.json"), nestingDb);
            }

            if (objectDb != null)
            {
                var outPath = Path.Combine(supportFiles, $"{game}.bin");
                using (var fs = File.Create(outPath))
                {
                    objectDb.Serialize(fs);
                }
                Console.WriteLine($"  wrote {Path.GetFileName(outPath)} ({new FileInfo(outPath).Length / 1024 / 1024} MB)");
            }

            Console.WriteLine($"Done with {game}. Re-zip supportfiles into supportdbs.zip for the decooker to pick these up.");
        }

        /// <summary>
        /// Builds the ObjectInstanceDB (&lt;game&gt;.bin) only. Kept as its own entry point because
        /// the format changes independently of the JSON databases -- version 3 added the class name
        /// table, and a version 2 database carries no class information, which forces the decooker's
        /// texture resolver onto a slow per-object fallback.
        /// </summary>
        public static void GenerateObjectInstanceDB(MEGame game)
        {
            GenerateSupportFiles(game, SupportDatabase.ObjectInstances);
        }

        /// <summary>
        /// Resolves the game directory to inventory, preferring the ME3Tweaks backup.
        ///
        /// The backup is preferred deliberately: these databases store paths relative to a game root
        /// and the decooker resolves them against the BACKUP at runtime (DecookerShared.OpenPackage),
        /// so indexing an installed copy would produce paths that do not resolve -- and a modded
        /// install would poison the databases with non-vanilla content.
        /// </summary>
        private static string ResolveGameRoot(MEGame game)
        {
            Console.WriteLine($"Building support databases for {game}...");
            var backup = ME3TweaksBackups.GetGameBackupPath(game);
            if (!string.IsNullOrEmpty(backup) && Directory.Exists(backup))
            {
                Console.WriteLine($"  using backup at {backup}");
                return backup;
            }

            var installed = MEDirectories.GetDefaultGamePath(game);
            if (!string.IsNullOrEmpty(installed) && Directory.Exists(installed))
            {
                Console.WriteLine($"  WARNING: no backup for {game}; using the installed copy at {installed}. " +
                                  "Paths are resolved against the backup at decook time, and an installed game may not be vanilla.");
                return installed;
            }

            Console.Error.WriteLine($"No backup or installed copy found for {game}; cannot build databases.");
            return null;
        }

        /// <summary>
        /// Enumerates every package to inventory, in the order it must be indexed.
        ///
        /// Order matters for the ObjectInstanceDB: loose files are appended, so for a given object
        /// the first file listed is the one the decooker resolves to. The game's own load order comes
        /// first, then anything else on disk, then SFAR content (which is inserted at the front when
        /// indexed, so it outranks everything regardless of its position here).
        /// </summary>
        private static List<PackageSource> BuildPackageList(MEGame game, string gameRoot)
        {
            var sources = new List<PackageSource>();
            var seen = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            var rootPrefix = gameRoot.TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);

            void AddLoose(string diskPath, bool loadedInGame)
            {
                if (!seen.Add(diskPath)) return;
                var stored = diskPath.StartsWith(rootPrefix, StringComparison.OrdinalIgnoreCase)
                    ? diskPath.Substring(rootPrefix.Length + 1)
                    : diskPath;
                sources.Add(new PackageSource { StoredPath = stored, DiskPath = diskPath, LoadedInGame = loadedInGame });
            }

            // 1. What the game actually loads, in mount priority order.
            foreach (var f in MELoadedFiles.GetFilesLoadedInGame(game, gameRootOverride: gameRoot).Values)
            {
                AddLoose(f, true);
            }

            // 2. Everything else on disk. The texture and object type databases have always covered
            //    the raw directory tree, which includes packages the load order shadows. Only the
            //    extensions those two databases consume are collected, since nothing else would look
            //    at them.
            var extraExtensions = game == MEGame.ME1
                ? new[] { ".upk", ".sfm" }
                : new[] { ".pcc" };
            foreach (var f in Directory.EnumerateFiles(gameRoot, "*", SearchOption.AllDirectories))
            {
                if (!extraExtensions.Contains(Path.GetExtension(f), StringComparer.OrdinalIgnoreCase)) continue;
                AddLoose(f, false);
            }

            // 3. SFAR content. ME3 ships all DLC -- including every multiplayer package -- inside
            //    Default.sfar archives, so without this the databases cover basegame alone.
            if (game == MEGame.ME3)
            {
                var dlcPath = Path.Combine(gameRoot, "BIOGame", "DLC");
                if (!Directory.Exists(dlcPath))
                {
                    Console.WriteLine($"  WARNING: no DLC directory at {dlcPath}; DLC and multiplayer objects will be missing");
                }
                else
                {
                    var sfars = Directory.GetFiles(dlcPath, "Default.sfar", SearchOption.AllDirectories);
                    Console.WriteLine($"  {sfars.Length} SFAR archives");
                    if (sfars.Length == 0)
                    {
                        Console.WriteLine("  WARNING: no Default.sfar archives found; DLC and multiplayer objects will be missing unless the DLC is unpacked");
                    }

                    foreach (var sfarPath in sfars)
                    {
                        var dlcName = Path.GetFileName(Path.GetDirectoryName(Path.GetDirectoryName(sfarPath)));
                        var archive = new DLCPackage(sfarPath);
                        int added = 0;
                        for (int i = 0; i < archive.Files.Count; i++)
                        {
                            var entry = archive.Files[i];
                            if (!entry.isActualFile || entry.FileName == null || !entry.FileName.RepresentsPackageFilePath()) continue;
                            sources.Add(new PackageSource
                            {
                                StoredPath = entry.FileName,
                                Archive = archive,
                                ArchiveEntry = i,
                                LoadedInGame = true
                            });
                            added++;
                        }
                        Console.WriteLine($"    {dlcName}: {added} packages");
                    }
                }
            }

            return sources;
        }

        /// <summary>
        /// Opens a package for inventorying, outside the shared package cache so it is safe to do in
        /// parallel.
        ///
        /// The JSON databases need nothing but the export table -- class names and instanced paths
        /// are header fields -- so export data is skipped for them. The ObjectInstanceDB is the
        /// exception: it records each object's NetIndex, which is read from the object's serialized
        /// data rather than its header, so building it forces a full load.
        /// </summary>
        private static IMEPackage OpenForInventory(PackageSource src, bool needsExportData)
        {
            Func<ExportEntry, bool> predicate = needsExportData ? (_ => true) : (_ => false);
            if (src.Archive != null)
            {
                using var decompressed = src.Archive.DecompressEntry(src.ArchiveEntry);
                return MEPackageHandler.UnsafePartialLoadFromStream(decompressed, src.StoredPath, predicate);
            }
            return MEPackageHandler.UnsafePartialLoad(src.DiskPath, predicate);
        }

        private static bool IsObjectTypeCandidate(MEGame game, PackageSource src)
        {
            var ext = src.Extension;
            if (game == MEGame.ME1)
            {
                return ext.CaseInsensitiveEquals(".upk") || ext.CaseInsensitiveEquals(".sfm");
            }
            return ext.CaseInsensitiveEquals(".pcc");
        }

        private static void InventoryTextures(IMEPackage package, PackageSource src, CaseInsensitiveDictionary<TexInfo> textureDb)
        {
            foreach (var tex in package.Exports)
            {
                if (tex.IsDefaultObject || !tex.IsA("Texture")) continue;
                if (tex.ClassName is "LightMapTexture2D" or "ShadowMapTexture2D")
                    continue; // Do not care.

                var candidate = new TexInfo
                {
                    packagefile = src.StoredPath,
                    memoryfullpath = tex.MemoryFullPath,
                    classname = tex.ClassName
                };

                // Keyed by instanced full path, so every texture in the game gets an entry.
                //
                // This used to be keyed by tex.ObjectName.Instanced -- one slot per bare name,
                // game-wide -- which silently dropped every texture that shared a name with another.
                // In LE3 that is 2,141 of 11,119 Texture2Ds (1,236 names are used more than once).
                // The loss is not academic: the layering pass hands a package the entries whose path
                // starts with that package's name (Decooker.AddTextures), so a texture whose slot was
                // taken by a same-named one in a different package can never be layered into anything.
                // BioVFX_Z_TEXTURES.Fractals.Wave was the reported case -- BioVFX_Env_Gthleg.Textures.Wave
                // sorted first and took "Wave", so the Z_TEXTURES copy was absent from the decook.
                //
                // The bare-name index the T3D fallback resolver needs is derived at load time instead
                // (Decooker.BuildNameIndex), using the same tie-break, so that path is unchanged.
                // The same texture path lives in many packages (fx_Distort_3 is in 804 files), so the
                // key still collides -- just between copies of one object rather than between
                // different objects. Break that tie on the containing file so the chosen copy does not
                // depend on thread scheduling. The old code kept whichever copy arrived first here,
                // which was genuinely nondeterministic: its path tie-break could not separate two
                // entries whose paths were equal.
                lock (textureDb)
                {
                    if (!textureDb.TryGetValue(tex.MemoryFullPath, out var existing)
                        || string.Compare(candidate.packagefile, existing.packagefile, StringComparison.OrdinalIgnoreCase) < 0)
                    {
                        textureDb[tex.MemoryFullPath] = candidate;
                    }
                }
            }
        }

        /// <summary>
        /// Maps objects of the requested types to the package holding them, grouped by the object's
        /// own linker (its source package name).
        /// </summary>
        private static void InventoryObjectTypes(IMEPackage package, PackageSource src,
            (string ObjectType, bool IsA)[] objectTypes,
            Dictionary<string, CaseInsensitiveDictionary<CaseInsensitiveDictionary<string>>> objectTypeDbs)
        {
            foreach (var obj in package.Exports)
            {
                if (obj.IsDefaultObject || obj.IsArchetype) continue;

                foreach (var (objectType, isA) in objectTypes)
                {
                    bool matches = isA
                        ? (obj.Parent == null || obj.Parent.ClassName == "Package") && obj.IsA(objectType)
                        : obj.ClassName == objectType;
                    if (!matches) continue;
                    if (obj.GetRoot().ObjectName == "TheWorld") continue;

                    var db = objectTypeDbs[objectType];
                    var linker = obj.GetLinker();
                    lock (db)
                    {
                        if (!db.TryGetValue(linker, out var objs))
                        {
                            objs = db[linker] = new CaseInsensitiveDictionary<string>();
                        }

                        // Deterministic tie-break rather than first-writer-wins, which used to make
                        // the recorded package depend on thread scheduling.
                        if (!objs.TryGetValue(obj.MemoryFullPath, out var existing)
                            || string.Compare(src.StoredPath, existing, StringComparison.OrdinalIgnoreCase) < 0)
                        {
                            objs[obj.MemoryFullPath] = src.StoredPath;
                        }
                    }
                }
            }
        }

        /// <summary>
        /// Maps package name to material object name to the material's path within that package, for
        /// materials that are nested rather than sitting at the package root.
        /// </summary>
        private static void InventoryMaterialNesting(IMEPackage package,
            CaseInsensitiveDictionary<CaseInsensitiveDictionary<string>> nestingDb)
        {
            foreach (var mat in package.Exports)
            {
                if (!mat.IsA("Material")) continue;

                var linker = mat.GetLinker();
                var subPath = mat.MemoryFullPath.Substring(linker.Length + 1);
                if (!subPath.Contains('.')) continue;

                lock (nestingDb)
                {
                    if (!nestingDb.TryGetValue(linker, out var subMapping))
                    {
                        subMapping = nestingDb[linker] = new CaseInsensitiveDictionary<string>();
                    }

                    // Several materials in one package can share an object name under different
                    // parents; only one path can be recorded, so pick it deterministically instead of
                    // letting the last thread to arrive decide.
                    if (!subMapping.TryGetValue(mat.ObjectName.Instanced, out var existing)
                        || string.Compare(subPath, existing, StringComparison.OrdinalIgnoreCase) < 0)
                    {
                        subMapping[mat.ObjectName.Instanced] = subPath;
                    }
                }
            }
        }

        private static void WriteJson(string path, object contents)
        {
            File.WriteAllText(path, JsonConvert.SerializeObject(contents, Formatting.Indented));
            Console.WriteLine($"  wrote {Path.GetFileName(path)} ({new FileInfo(path).Length / 1024} KB)");
        }

        /// <summary>
        /// Rebuilds supportfiles/supportdbs.zip from the loose support files.
        ///
        /// The zip is an EmbeddedResource, so LEDecooker must be recompiled afterwards before the
        /// decooker will actually read the new databases.
        /// </summary>
        public static void ZipSupportFiles()
        {
            var folder = LocateSupportFiles();
            var zipPath = Path.Combine(folder, "supportdbs.zip");
            if (File.Exists(zipPath))
            {
                File.Delete(zipPath);
            }

            // Built entry by entry rather than from the directory, so that the zip itself and any
            // hand-made backups sitting alongside the databases are not swept into it.
            var files = Directory.GetFiles(folder)
                .Where(f => !f.EndsWith(".zip", StringComparison.OrdinalIgnoreCase)
                            && !f.EndsWith("backup", StringComparison.OrdinalIgnoreCase))
                .OrderBy(f => f, StringComparer.OrdinalIgnoreCase)
                .ToList();

            Console.WriteLine($"Compressing {files.Count} support files from {folder}");
            using (var zipStream = new FileStream(zipPath, FileMode.Create))
            using (var archive = new ZipArchive(zipStream, ZipArchiveMode.Create))
            {
                foreach (var file in files)
                {
                    Console.WriteLine($"  {Path.GetFileName(file)} ({new FileInfo(file).Length / 1024 / 1024} MB)");
                    archive.CreateEntryFromFile(file, Path.GetFileName(file), CompressionLevel.SmallestSize);
                }
            }

            Console.WriteLine($"Wrote {zipPath} ({new FileInfo(zipPath).Length / 1024 / 1024} MB)");
            Console.WriteLine("Rebuild LEDecooker now -- the zip is an embedded resource.");
        }

        /// <summary>
        /// Finds the supportfiles directory by walking up from the binary.
        ///
        /// The generators used to hardcode "../../../supportfiles", which only resolves correctly
        /// when the output directory is exactly three levels below the project (bin/Debug/net10.0).
        /// An x64 platform build is four levels down and would silently write databases into
        /// bin/supportfiles instead.
        /// </summary>
        private static string LocateSupportFiles()
        {
            var dir = new DirectoryInfo(AppContext.BaseDirectory);
            while (dir != null)
            {
                var candidate = Path.Combine(dir.FullName, "supportfiles");
                if (Directory.Exists(candidate)) return candidate;
                dir = dir.Parent;
            }

            // Nothing found; fall back to the historical relative path so behaviour is at worst what
            // it was before.
            var fallback = Path.GetFullPath(Path.Combine("..", "..", "..", "supportfiles"));
            Directory.CreateDirectory(fallback);
            Console.WriteLine($"  WARNING: could not locate supportfiles; using {fallback}");
            return fallback;
        }
#endif
    }
}
