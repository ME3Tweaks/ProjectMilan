using System.Diagnostics;
using System.Linq;
using LegendaryExplorerCore.GameFilesystem;
using LegendaryExplorerCore.Helpers;
using LegendaryExplorerCore.Misc;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Packages.CloningImportingAndRelinking;
using LegendaryExplorerCore.Unreal;
using LegendaryExplorerCore.Unreal.ObjectInfo;
using LegendaryExplorerCore.UnrealScript;
using ProjectMilan.Pipelines.Audio.Extension;
using ProjectMilan.Pipelines.Kits;
using ProjectMilan.Utility;

namespace ProjectMilan.Pipelines
{
    /// <summary>
    /// Shared data for Milan Pipelines
    /// </summary>
    internal class MilanShared
    {
        private const string ROOT_FOLDER_NAME = @"ProjectMilan";
        public static ObjectInstanceDB LE3ObjectDB { get; set; }
        public static ObjectInstanceDB ME3ObjectDB { get; set; }

        private static string _pipelineRoot;

        /// <summary>
        /// Root path for Milan Pipelines - will be named 'Pipelines' under folder 'ProjectMilan'
        /// </summary>
        public static string PipelineRoot
        {
            get
            {
                if (_pipelineRoot != null) return _pipelineRoot;
                var dir = Directory.GetCurrentDirectory();
                while (Path.GetFileName(dir) != ROOT_FOLDER_NAME)
                {
                    dir = Directory.GetParent(dir).FullName;
                }

                _pipelineRoot = Path.Combine(dir, "Pipelines");
                return _pipelineRoot;
            }
        }

        public static string DLC_NAME { get; } = @"DLC_MOD_ProjectMilan";

        /// <summary>
        /// Maps files in a DLC to their respective DLC, using the TOC file of the DLC
        /// </summary>
        internal static CaseInsensitiveDictionary<DLCPackage> ME3DLCFileMap;

        private static object syncObj = new();

        /// <summary>
        /// Fetches an ME3 package - from disk or SFAR
        /// </summary>
        /// <param name="sourceFileName"></param>
        public static IMEPackage GetME3Package(string sourceFileName, Func<ExportEntry, bool> unsafePredicate = null)
        {
            bool forceUseDLC = sourceFileName == "MPLobby.pcc"; // Do not use basegame version.

            lock (syncObj)
            {

                if (!forceUseDLC &&
                    MELoadedFiles.TryGetHighestMountedFile(MEGame.ME3, sourceFileName, out var filePath))
                {
                    if (unsafePredicate != null)
                    {
                        return MEPackageHandler.UnsafePartialLoad(filePath, unsafePredicate);
                    }
                    return MEPackageHandler.OpenMEPackage(filePath);
                }
                else
                {
                    // May be in SFAR
                    if (ME3DLCFileMap == null)
                        LoadME3DLCTOCs();
                    if (ME3DLCFileMap.TryGetValue(sourceFileName, out var dlcPackage))
                    {
                        if (unsafePredicate != null)
                        {
                            return MEPackageHandler.UnsafePartialLoadFromStream(dlcPackage.DecompressEntry(dlcPackage.FindFileEntry(sourceFileName)), sourceFileName, unsafePredicate);
                        }
                        return MEPackageHandler.OpenMEPackageFromStream(dlcPackage.DecompressEntry(dlcPackage.FindFileEntry(sourceFileName)), sourceFileName);
                    }

                    if (MELoadedFiles.TryGetHighestMountedFile(MEGame.ME3, sourceFileName, out var filePath2) &&
                        filePath2.Contains("\\DLC_"))
                    {
                        // Unpacked DLC
                        if (unsafePredicate != null)
                        {
                            return MEPackageHandler.UnsafePartialLoad(filePath2, unsafePredicate);
                        }
                        return MEPackageHandler.OpenMEPackage(filePath2);
                    }

                    MilanLog.Warning($"Could not locate ME3 package file: {sourceFileName}");
                }

                // Donors will have full path
                if (File.Exists(sourceFileName))
                {
                    if (unsafePredicate != null)
                    {
                        return MEPackageHandler.UnsafePartialLoad(sourceFileName, unsafePredicate);
                    }
                    return MEPackageHandler.OpenMEPackage(sourceFileName);
                }
            }
            return null;
        }

        public static void LoadME3DLCTOCs()
        {
            if (ME3DLCFileMap != null)
                return;

            MilanLog.Information(@"Loading ME3 DLC SFARs for lookups");
            ME3DLCFileMap = new CaseInsensitiveDictionary<DLCPackage>();
            foreach (var f in MEDirectories.OfficialDLC(MEGame.ME3))
            {
                // This will go from MP1->MP5 so we can override entries in the map.

                if (!f.StartsWith(@"DLC_CON_MP"))
                    continue; // We don't care about SP

                var sfarPath = Path.Combine(ME3Directory.DLCPath, f, MEGame.ME3.CookedDirName(), @"Default.sfar");
                var sfar = new DLCPackage(sfarPath);
                foreach (var fe in sfar.Files)
                {
                    if (fe.isActualFile)
                    {
                        ME3DLCFileMap[Path.GetFileName(fe.FileName)] = sfar;
                    }
                }
            }
        }

        public static string GetAutoDonorClassesPath()
        {
            return Directory.CreateDirectory(Path.Combine(MilanShared.PipelineRoot, @"Shared", @"Compiling", @"AutoDonor")).FullName;
        }

        public static string GetInjectedFunctionsPath(string className)
        {
            return Path.Combine(MilanShared.PipelineRoot, @"Shared", @"Compiling", @"Functions", className);
        }

        public static IMEPackage GetLE3Package(string packageFileName)
        {
            var gp = GetGlobalCachedPackage(packageFileName);
            if (gp != null)
                return gp;

            if (MELoadedFiles.TryGetHighestMountedFile(MEGame.LE3, packageFileName, out var filePath))
            {
                return MEPackageHandler.OpenMEPackage(filePath);
            }

            // Donors will have full path
            if (File.Exists(packageFileName))
            {
                return MEPackageHandler.OpenMEPackage(packageFileName);
            }

            return null;
        }


        private static CaseInsensitiveDictionary<IMEPackage> TestPatchPackageMap;

        public static ExportEntry GetTestPatchClass(ExportEntry classExp)
        {
            if (TestPatchPackageMap == null)
            {
                MilanLog.Information(@"Reading ME3 DLC_TestPatch");
                var sfarPath = Path.Combine(ME3Directory.BioGamePath, @"Patches", @"PCConsole", @"Patch_001.sfar");
                var sfar = new DLCPackage(sfarPath);
                TestPatchPackageMap = new(sfar.Files.Count);

                foreach (var fe in sfar.Files)
                {
                    if (fe.isActualFile && fe.FileName.RepresentsPackageFilePath())
                    {
                        var package = MEPackageHandler.OpenMEPackageFromStream(sfar.DecompressEntry(fe), fe.FileName);
                        var inventoryClass = package.Exports.FirstOrDefault(x => x.IsClass);
                        if (inventoryClass != null)
                        {
                            // Some TP things are not classes like GuidCache.
                            TestPatchPackageMap[inventoryClass.ObjectName] = package;
                        }
                    }
                }
            }

            if (TestPatchPackageMap.TryGetValue(classExp.ObjectName, out var tpClass))
            {
                return tpClass.Exports.FirstOrDefault(x => x.IsClass && x.ObjectName == classExp.ObjectName);
            }

            return null;
        }

        public static string GetClassOverride(string className)
        {
            var path = Path.Combine(MilanShared.PipelineRoot, @"Shared", @"Compiling", @"ClassOverride", $"{className}.uc");
            if (File.Exists(path))
                return path;
            return null;
        }

        public static MemoryStream GetME3SFARFile(string sourceFileName)
        {
            if (MELoadedFiles.GetFilesLoadedInGame(MEGame.ME3, false,
                    Path.GetExtension(sourceFileName) == ".tfc", Path.GetExtension(sourceFileName) == ".afc")
                .TryGetValue(sourceFileName, out var filePath))
            {
                return null; // Found on disk
            }

            // May be in SFAR
            LoadME3DLCTOCs();
            if (ME3DLCFileMap.TryGetValue(sourceFileName, out var dlcPackage))
            {
                MilanLog.Information($"Extracting {sourceFileName} from {dlcPackage.FileName}");
                return dlcPackage.DecompressEntry(dlcPackage.FindFileEntry(sourceFileName));
            }

            MilanLog.Warning($"Could not locate ME3 DLC file: {sourceFileName}");
            return null;
        }

        public static string GetAutoDonorClassPath(string package, string className)
        {
            return Path.Combine(GetAutoDonorClassesPath(), package, className + ".uc");
        }

        public const string MP_STARTUP_NAME = "BIOP_MP_COMMON";
        public const string MP_STARTUP_FILENAME = MP_STARTUP_NAME + ".pcc";


        /// <summary>
        /// Ensures the MPCommon package is in the game so tooling can use it
        /// </summary>
        public static bool EnsureMPCommonInGame()
        {
            if (!MELoadedFiles.TryGetHighestMountedFile(MEGame.LE3, MP_STARTUP_FILENAME, out var foundF))
            {
                var versions = Directory.GetFiles(Program.Settings.OutputModPath, MP_STARTUP_FILENAME, SearchOption.AllDirectories);
                if (!versions.Any())
                {
                    MilanLog.Error($"{MP_STARTUP_FILENAME} was not found - content pipelines cannot run, they depend on BIOP_MP_COMMON. Turn on MPCommon pipeline");
                    return false;
                }

                // Copy to basegame. Eventually move to DLC only
                foundF = versions[0];
                File.Copy(versions[0], Path.Combine(ME3Directory.CookedPCPath, MP_STARTUP_FILENAME), true);
            }

            EntryImporter.AddUserSafeToImportFromFile(MEGame.LE3, MP_STARTUP_FILENAME);

            // Inventory package
            MilanLog.Information($"Inventorying classes in {MP_STARTUP_FILENAME}");
            var cache = new PackageCache();
            var mpCommon = MEPackageHandler.OpenMEPackage(foundF);
            foreach (var exp in mpCommon.Exports.Where(x => x.IsClass))
            {
                MilanLog.Information($"  Inventorying {exp.InstancedFullPath}");
                GlobalUnrealObjectInfo.generateClassInfo(exp, packageCache: cache);
            }

            // Add to object database for porting
            MilanShared.LE3ObjectDB.AddFileToDB(mpCommon, foundF);

            return true;
        }

        internal static void EnsureTFCsAvailable()
        {
            var tfcs = new[]
            {
                "Textures_DLC_CON_MP1.tfc",
                "Textures_DLC_CON_MP2.tfc",
                "Textures_DLC_CON_MP3.tfc",
                "Textures_DLC_CON_MP4.tfc",
                "Textures_DLC_CON_MP5.tfc",
            };

            // We have to fake a dlc dir for Texture2D's  'get files loaded in game'
            var fakePath = Directory.CreateDirectory(Path.Combine(ME3Directory.DLCPath, "DLC_Milan")).FullName;
            var fakeCooked = Directory.CreateDirectory(Path.Combine(fakePath, "CookedPCConsole")).FullName;
            MountFile mf = new MountFile() { Game = MEGame.LE3, MountPriority = 50000, MountFlags = new MountFlag(EME3MountFileFlag.LoadsInMultiplayer) };
            mf.WriteMountFile(Path.Combine(fakeCooked, "mount.dlc"));

            var loadedFiles = MELoadedFiles.GetFilesLoadedInGame(MEGame.ME3, includeTFCs: true);
            foreach (var tfcN in tfcs)
            {
                if (loadedFiles.ContainsKey(tfcN))
                {
                    MilanLog.Information($"{tfcN} already exists in game - skipping extraction");
                    continue; // Already exists
                }
                var data = MilanShared.GetME3SFARFile(tfcN);
                if (data == null)
                    continue; // On disk already

                MilanLog.Information($"{tfcN} is being copied to the direct access cache");
                using var outF = File.OpenWrite(Path.Combine(fakeCooked, tfcN));
                data.CopyTo(outF);
            }
        }

        internal static void EnsureAFCsAvailable()
        {
            var afcBaseNames = new[]
            {
                "DLC_CON_MP1",
                "DLC_CON_MP2",
                "DLC_CON_MP3",
                "DLC_CON_MP4",
                "DLC_CON_MP5",
            };

            // We have to fake a dlc dir for AFC's  'get files loaded in game'
            var fakePath = Directory.CreateDirectory(Path.Combine(ME3Directory.DLCPath, "DLC_Milan")).FullName;
            var fakeCooked = Directory.CreateDirectory(Path.Combine(fakePath, "CookedPCConsole")).FullName;
            MountFile mf = new MountFile() { Game = MEGame.LE3, MountPriority = 50000, MountFlags = new MountFlag(EME3MountFileFlag.LoadsInMultiplayer) };
            mf.WriteMountFile(Path.Combine(fakeCooked, "mount.dlc"));

            // List of all suffixes to ensure
            var audioSuffixes = Program.SupportedVOLanguages.Select(x => x.ToString()).Concat(new[] { "SFX" });

            var loadedFiles = MELoadedFiles.GetFilesLoadedInGame(MEGame.ME3, includeAFCs: true); // This will also force reload the list of files.
            foreach (var afcN in afcBaseNames)
            {
                foreach (var loc in audioSuffixes)
                {
                    var locF = $"{afcN}_{loc}.afc";
                    if (loadedFiles.ContainsKey(locF))
                    {
                        MilanLog.Information($"{locF} already exists in game - skipping extraction");
                        continue; // Already exists
                    }

                    var data = MilanShared.GetME3SFARFile(locF);
                    if (data == null)
                        continue; // On disk already

                    MilanLog.Information($"{locF} is being copied to the direct access cache");
                    using var outF = File.OpenWrite(Path.Combine(fakeCooked, locF));
                    data.CopyTo(outF);
                }
            }
        }

        public static void EnsureVGMStreamAvailable()
        {
            if (!VGMAudioStreamHelper.EnsureVGMStream())
            {
                MilanLog.Fatal("Could not ensure VGMStream is available. This should be automatically corrected by MilanSync from the ME3Tweaks server.");
                Environment.Exit(1);
            }
        }

        /// <summary>
        /// Ports localized files 
        /// </summary>
        /// <param name="basePackageName"></param>
        /// <param name="outputFolder"></param>
        /// <param name="cache"></param>
        /// <param name="logCategory"></param>
        internal static void PortLocalizations(string basePackageName, string outputFolder, PackageCache cache, string logCategory)
        {
            MilanLog.Information($"Porting localized files for {basePackageName}", customPrefix: logCategory);
            foreach (var lang in Program.SupportedVOLanguages)
            {
                var packageName = $"{basePackageName}_LOC_{lang}.pcc";
                var me3Package = MilanShared.GetME3Package(packageName);
                if (me3Package == null)
                {
                    MilanLog.Warning($"Could not find localized package {packageName}", customPrefix: logCategory);
                    continue;
                }

                var finalPackagePath = Path.Combine(outputFolder, packageName);
                var locDestPackage = MEPackageHandler.CreateAndOpenPackage(finalPackagePath, MEGame.LE3);

                MilanLog.Information($"Porting localized file {me3Package.FileNameNoExtension}", customPrefix: logCategory);
                PortObjectReferencer(me3Package, locDestPackage, cache, logCategory);
                //var objReferencer = me3Package.Exports.FirstOrDefault(x => x.ClassName == "ObjectReferencer");

                ////DotTrace.StartCollectingData(); // Start profiling
                //var sw = new Stopwatch();
                //sw.Start();
                //var rop = new RelinkerOptionsPackage()
                //{
                //    Cache = cache,
                //    TargetGameDonorDB = MilanShared.LE3ObjectDB,
                //    PortExportsAsImportsWhenPossible = true,
                //    GenerateImportsForGlobalFiles = true
                //};
                //var results = EntryImporter.ImportAndRelinkEntries(EntryImporter.PortingOption.CloneAllDependencies, objReferencer,
                //    locDestPackage, null, true,
                //    rop,
                //    out var newEntry);

                //locDestPackage.Save();
            }
        }

        /// <summary>
        /// Ports an object referencer across games.
        /// </summary>
        /// <param name="kitSourcePackage"></param>
        /// <param name="destPackage"></param>
        /// <param name="cache"></param>
        /// <param name="logCategory"></param>
        public static void PortObjectReferencer(IMEPackage kitSourcePackage, IMEPackage destPackage, PackageCache cache, string logCategory)
        {
            var objReferencer = kitSourcePackage.Exports.FirstOrDefault(x => x.ClassName == "ObjectReferencer");

            MilanLog.Information("Porting object referencer", customPrefix: logCategory);
            //DotTrace.StartCollectingData(); // Start profiling
            var sw = new Stopwatch();
            sw.Start();
            var rop = new RelinkerOptionsPackage()
            {
                Cache = cache,
                TargetGameDonorDB = MilanShared.LE3ObjectDB,
                PortExportsAsImportsWhenPossible = true,
                GenerateImportsForGlobalFiles = true,
                CustomImportFileResolver = ImportResolver
            };
            var results = EntryImporter.ImportAndRelinkEntries(EntryImporter.PortingOption.CloneAllDependencies, objReferencer,
                destPackage, null, true,
                rop,
                out var newEntry);

            sw.Stop();
            foreach (var r in results)
            {
                MilanLog.Warning($"Relink result: {r.Message} for {r.Entry?.InstancedFullPath}", customPrefix: logCategory);
            }

            //DotTrace.SaveData();

            // Not sure - do we need to make sure this needs done recursively in order? Topmost to bottommost
            if (true)
            {
                MilanLog.Information("Recompiling ported classes", customPrefix: logCategory);
                FileLib lib = new FileLib(destPackage);
                lib.Initialize(cache, customFileResolver: MilanShared.ImportResolver);

                foreach (var f in rop.CrossPackageMap.Values.OfType<ExportEntry>().Where(x => x.IsClass))
                {
                    // Recompile all ported classes so vtables are updated
                    MilanLog.Information($"  Recompiling {f.ObjectName}", customPrefix: logCategory);
                    // This is broken!!
                    try
                    {
                        //var sourceObj = rop.CrossPackageMap.FirstOrDefault(x => x.Value == f).Key as ExportEntry;
                        //(_, string text) = UnrealScriptCompiler.DecompileExport(sourceObj, lib, cache);
                        (_, string text) = UnrealScriptCompiler.DecompileExport(f, lib, cache);
                        UnrealScriptCompiler.CompileClass(destPackage, text, lib, f, packageCache: cache);
                    }
                    catch (Exception e)
                    {
                        MilanLog.Exception(e, "  Error recompiling function:");
                    }
                }
            }

            MilanLog.Information("Saving package", customPrefix: logCategory);
            destPackage.Save();
            MilanShared.RefreshMilanFiles = true;
        }

        private static readonly object _globalDirEnumerator = new object();

        /// <summary>
        /// Set to true to force the ImportResolver to enumerate the source files directory again.
        /// </summary>
        public static bool RefreshMilanFiles = true;

        /// <summary>
        /// The list of files in the Milan DLC folder
        /// </summary>
        private static string[] MilanFiles;

        private static MilanPackageCache globalCache;

        /// <summary>
        /// Resolves a package name to package in the Milan DLC
        /// </summary>
        /// <param name="filename"></param>
        /// <returns></returns>
        internal static IMEPackage ImportResolver(string filename, PackageCache cache)
        {
            string matching = null;
            lock (_globalDirEnumerator)
            {
                if (RefreshMilanFiles)
                {
                    MilanFiles = Directory.GetFiles(Program.Settings.OutputModPath, "*", SearchOption.AllDirectories);
                    RefreshMilanFiles = false;
                }

                matching = MilanFiles.FirstOrDefault(x => Path.GetFileName(x).CaseInsensitiveEquals(filename));
            }
            if (matching != null)
            {
                // Multi thread file read can cause issues.
                lock (_globalDirEnumerator)
                {
                    if (cache != null)
                    {
                        return cache.GetCachedPackage(matching, openPackageMethod: GetLE3Package);
                    }

                    var package = MEPackageHandler.OpenMEPackage(matching);
                    return package;
                }
            }

            return GetGlobalCachedPackage(filename);
        }

        /// <summary>
        /// Returns a package from the global cache if found. Searched based on the filename
        /// </summary>
        /// <param name="filename"></param>
        /// <returns></returns>
        private static IMEPackage GetGlobalCachedPackage(string filename)
        {
            // If build is being done on NAS looking for local files will be slow
            // We should 
            if (globalCache == null)
            {
                globalCache = new MilanPackageCache();
                globalCache.InsertIntoCache(MEPackageHandler.OpenMEPackages(EntryImporter.FilesSafeToImportFrom(MEGame.LE3).Select(x => Path.Combine(MEDirectories.GetCookedPath(MEGame.LE3), x))));
            }

            // Return cache or empty if not in the global cache.
            return globalCache.GetCachedPackage(filename, false);
        }
    }
}
