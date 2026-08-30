using LegendaryExplorerCore.GameFilesystem;
using LegendaryExplorerCore.Misc;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Packages.CloningImportingAndRelinking;
using LegendaryExplorerCore.Unreal.BinaryConverters;
using LegendaryExplorerCore.Unreal.ObjectInfo;
using LegendaryExplorerCore.Unreal;
using LegendaryExplorerCore.UnrealScript.Compiling.Errors;
using LegendaryExplorerCore.UnrealScript;
using ProjectMilan;
using System.Diagnostics;
using System.Threading;
using LegendaryExplorerCore.Gammtek.Extensions;
using LegendaryExplorerCore.Helpers;
using LegendaryExplorerCore.Pathing;
using ProjectMilan.Utility;

namespace ProjectMilanCore
{
    /// <summary>
    /// Shared methods for Project Milan projects.
    /// </summary>
    public static class MilanShared
    {
        /// <summary>
        /// Name of the DLC folder to output for Project Milan.
        /// </summary>
        public static string DLC_NAME { get; } = @"DLC_MOD_ProjectMilan";

        // DEV MODE ONLY!!!
        public static string REJECTS_DLC_NAME { get; } = @"DLC_MOD_PMR2";

        // DEV MODE ONLY!!!
        public static string REDEMPTION_DLC_NAME { get; } = @"DLC_MOD_PMR3";

        private const string ROOT_FOLDER_NAME = @"ProjectMilan";
        public static ObjectInstanceDB LE3ObjectDB { get; set; }
        public static ObjectInstanceDB ME3ObjectDB { get; set; }

        /// <summary>
        /// Shared lock used to synchronize package disk I/O across the whole app. Pipelines build many packages in parallel (e.g. one thread per kit); a package being saved on one thread can be
        /// concurrently opened for reading on another (e.g. as an import donor), which throws "file in use by another process". Every package cache defaults to this lock via
        /// <see cref="PackageCache.DefaultDiskIOSyncLock"/>, and every <c>Save()</c> call in the pipelines should pass it as well.
        /// </summary>
        public static readonly Lock DiskIOSyncLock = new();

        static MilanShared()
        {
            PackageCache.DefaultDiskIOSyncLock = DiskIOSyncLock;
        }

        private static string _pipelineRoot;

        /// <summary>
        /// This is the list of all packages that were registered/inventoried for donors.
        /// </summary>
        private static SortedSet<string> RegisteredObjectDBPackages { get; } = new SortedSet<string>();

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


        /// <summary>
        /// Maps files in a DLC to their respective DLC, using the TOC file of the DLC
        /// </summary>
        public static CaseInsensitiveDictionary<DLCPackage> ME3DLCFileMap;

        private static object syncObj = new();

        /// <summary>
        /// Fetches an ME3 package - from disk or SFAR
        /// </summary>
        /// <param name="sourceFileName"></param>
        public static IMEPackage GetME3Package(string sourceFileName, Func<ExportEntry, bool> unsafePredicate = null, bool logIfNotFound = true)
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

                    if (logIfNotFound)
                    {
                        MilanLog.Warning($"Could not locate ME3 package file: {sourceFileName}");
                    }
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

        /// <summary>
        /// Fetches an ME3 file stream - from disk or SFAR. Callers will need to close the returned stream.
        /// </summary>
        public static Stream GetME3File(string sourceFileName, bool logIfNotFound = true)
        {
            bool forceUseDLC = sourceFileName == "MPLobby.pcc"; // Do not use basegame version.

            lock (syncObj)
            {
                if (!forceUseDLC &&
                    MELoadedFiles.TryGetHighestMountedFile(MEGame.ME3, sourceFileName, out var filePath))
                {
                    return new FileStream(filePath, FileMode.Open, FileAccess.Read, FileShare.Read);
                }

                // May be in SFAR
                if (ME3DLCFileMap == null)
                    LoadME3DLCTOCs();

                if (ME3DLCFileMap.TryGetValue(sourceFileName, out var dlcPackage))
                {
                    var decompressed = dlcPackage.DecompressEntry(dlcPackage.FindFileEntry(sourceFileName));
                    if (decompressed is MemoryStream memoryStream)
                    {
                        memoryStream.Position = 0;
                        return memoryStream;
                    }

                    var copy = new MemoryStream();
                    decompressed.CopyTo(copy);
                    decompressed.Dispose();
                    copy.Position = 0;
                    return copy;
                }

                if (MELoadedFiles.TryGetHighestMountedFile(MEGame.ME3, sourceFileName, out var filePath2) &&
                    filePath2.Contains("\\DLC_"))
                {
                    // Unpacked DLC
                    return new FileStream(filePath2, FileMode.Open, FileAccess.Read, FileShare.Read);
                }

                // Donors will have full path
                if (File.Exists(sourceFileName))
                {
                    return new FileStream(sourceFileName, FileMode.Open, FileAccess.Read, FileShare.Read);
                }

                if (logIfNotFound)
                {
                    MilanLog.Warning($"Could not locate ME3 file: {sourceFileName}");
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
            return Path.Combine(MilanShared.PipelineRoot, @"Shared", @"Compiling", @"InjectedFunctions", className);
        }

        public static IMEPackage GetLE3Package(string packageFileName)
        {
            var gp = GetLE3GlobalCachedPackage(packageFileName);
            if (gp != null)
                return gp;

            if (MELoadedFiles.TryGetHighestMountedFile(MEGame.LE3, packageFileName, out var filePath))
            {
                return MEPackageHandler.OpenMEPackage(filePath, diskIOSyncLock: DiskIOSyncLock);
            }

            // Donors will have full path
            if (File.Exists(packageFileName))
            {
                return MEPackageHandler.OpenMEPackage(packageFileName, diskIOSyncLock: DiskIOSyncLock);
            }

            return null;
        }


        private static CaseInsensitiveDictionary<IMEPackage> TestPatchPackageMap;
        private static readonly object testPatchPackageMapSyncObj = new();

        public static ExportEntry GetTestPatchClass(ExportEntry classExp)
        {
            lock (testPatchPackageMapSyncObj)
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
        }

        public static string GetClassOverride(string className)
        {
            var path = Path.Combine(MilanShared.PipelineRoot, @"Shared", @"Compiling", @"ClassOverride", $"{className}.uc");
            if (File.Exists(path))
                return path;
            return null;
        }

        public static string GetFunctionOverrideFolder()
        {
            return Directory.CreateDirectory(Path.Combine(MilanShared.PipelineRoot, @"Shared", @"Compiling", @"FunctionOverride")).FullName;
        }

        private static Dictionary<string, List<string>> _functionOverrideIndex;
        private static readonly object FunctionOverrideIndexLock = new();
        private static readonly List<string> EmptyFunctionOverrideList = new();

        /// <summary>
        /// Table-of-contents index of function override files (className -> override files), built once on first
        /// access by scanning the FunctionOverride folder, and reused afterward. This lookup is checked once per
        /// ported function during cross-game porting, so re-scanning the folder from disk on every call would be
        /// very costly across the thousands of functions a typical port touches.
        /// </summary>
        private static Dictionary<string, List<string>> GetFunctionOverrideIndex()
        {
            if (_functionOverrideIndex != null)
                return _functionOverrideIndex;

            lock (FunctionOverrideIndexLock)
            {
                if (_functionOverrideIndex == null)
                {
                    var index = new Dictionary<string, List<string>>();
                    foreach (var file in Directory.GetFiles(GetFunctionOverrideFolder(), "*.uc", SearchOption.AllDirectories))
                    {
                        var className = Directory.GetParent(file).Name;
                        if (!index.TryGetValue(className, out var files))
                        {
                            files = new List<string>();
                            index[className] = files;
                        }
                        files.Add(file);
                    }
                    _functionOverrideIndex = index;
                }
            }

            return _functionOverrideIndex;
        }

        /// <summary>
        /// Finds function override .uc files for the given class, matched by immediate parent folder name.
        /// Backed by an in-memory index built once from disk - see <see cref="GetFunctionOverrideIndex"/>.
        /// </summary>
        public static List<string> GetFunctionOverridesForClass(string className)
        {
            return GetFunctionOverrideIndex().TryGetValue(className, out var files) ? files : EmptyFunctionOverrideList;
        }

        /// <summary>
        /// All function override .uc files, across all classes. Backed by the same in-memory index as
        /// <see cref="GetFunctionOverridesForClass"/>, so this doesn't re-scan disk either.
        /// </summary>
        public static IEnumerable<string> GetAllFunctionOverrides()
        {
            return GetFunctionOverrideIndex().Values.SelectMany(x => x);
        }

        /// <summary>
        /// Compiles a single function override file into the given class export. Dotted filenames
        /// (e.g. State.Function.uc) target a sub-function inside a state.
        /// </summary>
        public static void CompileFunctionOverride(IMEPackage pcc, ExportEntry classExport, string overrideFile, FileLib fl, UnrealScriptOptionsPackage usop, string logCategory)
        {
            var funcName = Path.GetFileNameWithoutExtension(overrideFile);
            MilanLog.Information($"Overriding function {funcName} in class {classExport.ObjectName} with override", customPrefix: logCategory);
            var ucText = File.ReadAllText(overrideFile);

            if (funcName.Contains('.'))
            {
                // It's a sub function like a in a state
                var function = pcc.FindExport($"{classExport.InstancedFullPath}.{funcName}");
                UnrealScriptCompiler.CompileFunction(function, ucText, fl, usop);
            }
            else
            {
                // Add or replace to class
                UnrealScriptCompiler.AddOrReplaceInClass(classExport, ucText, fl, usop);
            }
        }

        /// <summary>
        /// Looks up a function override for the given (source-game) function export, deriving its owning class name
        /// and function name (dotted with the state name for a sub-function inside a state) from its parent chain.
        /// Returns the override text, or null if no override exists for this function.
        /// </summary>
        public static string GetFunctionOverrideText(ExportEntry sourceFunc, out string className, out string funcName)
        {
            if (sourceFunc.Parent is ExportEntry stateExp && stateExp.ClassName == "State")
            {
                className = (stateExp.Parent as ExportEntry)?.ObjectName;
                funcName = $"{stateExp.ObjectName}.{sourceFunc.ObjectName}";
            }
            else
            {
                className = (sourceFunc.Parent as ExportEntry)?.ObjectName;
                funcName = sourceFunc.ObjectName;
            }

            if (className == null)
                return null;

            var targetFuncName = funcName;
            var overrideFile = GetFunctionOverridesForClass(className).FirstOrDefault(f => Path.GetFileNameWithoutExtension(f) == targetFuncName);
            return overrideFile != null ? File.ReadAllText(overrideFile) : null;
        }

        public static MemoryStream GetME3SFARFile(string sourceFileName, bool returnOnDisk = false)
        {
            var includeTfcs = Path.GetExtension(sourceFileName) == ".tfc";
            var includeAfcs = Path.GetExtension(sourceFileName) == ".afc";
            var additionalExtensions = Array.Empty<string>();
            if (!includeTfcs && !includeAfcs && Path.GetExtension(sourceFileName) != ".pcc")
            {
                // Other extensions like .tlk that are not usually supported by GetFilesLoadedInGame
                additionalExtensions = new[] { Path.GetExtension(sourceFileName) };
            }
            if (MELoadedFiles.GetFilesLoadedInGame(MEGame.ME3, false, includeTfcs, includeAfcs, additionalExtensions: additionalExtensions).TryGetValue(sourceFileName, out var filePath))
            {
                if (returnOnDisk)
                {
                    return new MemoryStream(File.ReadAllBytes(filePath));
                }
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
        public static bool EnsureMPCommonInGame(out string foundPath)
        {
            foundPath = null;
            var biopMPCommon = Path.Combine(BaseBuildSettings.OutputModPath, @"CookedPCConsole", MP_STARTUP_FILENAME);
            if (!File.Exists(biopMPCommon))
            {
                var lmpPath = MEDirectories.GetDefaultGamePath(MEGame.LE3);
                lmpPath = Path.Combine(Directory.GetParent(lmpPath).FullName, "LMP");
                var files = MELoadedFiles.GetFilesLoadedInGame(MEGame.LE3, gameRootOverride: lmpPath);
                if (!files.TryGetValue(MP_STARTUP_FILENAME, out foundPath))
                {
                    MilanLog.Error($"{MP_STARTUP_FILENAME} was not found - content pipelines cannot run, they depend on BIOP_MP_COMMON. Install Project Milan or build the MP startup pipeline if this is the Project Milan project.");
                    return false;
                }
            }
            else
            {
                foundPath = biopMPCommon;
            }

            EntryImporter.AddUserSafeToImportFromFile(MEGame.LE3, MP_STARTUP_FILENAME);

            // Inventory package
            //MilanShared.AddDonorPackage(biopMPCommon);

            return true;
        }

        public static void AddDonorPackage(string packagePath, PackageCache cache = null)
        {
            MilanLog.Information($"Inventorying classes in {Path.GetFileName(packagePath)}");
            cache ??= new PackageCache();
            var package = MEPackageHandler.OpenMEPackage(packagePath, diskIOSyncLock: DiskIOSyncLock);
            foreach (var exp in package.Exports.Where(x => x.IsClass))
            {
                MilanLog.Information($"  Inventorying {exp.InstancedFullPath}");
                GlobalUnrealObjectInfo.generateClassInfo(exp, packageCache: cache);
            }

            // Add to object database for porting
            // The predicate here is to prevent root level packages from being pulled in with incorrect netindexing data. We will generate that later.
            RegisterObjectDBPackage(package, objectsToAddPredicate: x => x.idxLink != 0 || x.ClassName != "Package" || !x.IsForcedExport);
        }

        public static void EnsureTFCsAvailable()
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

        public static void EnsureAFCsAvailable()
        {
            var afcBaseNames = new[]
            {
                "DLC_CON_MP1",
                "DLC_CON_MP2",
                "DLC_CON_MP3",
                "DLC_CON_MP4",
                "DLC_CON_MP5",
                "ss_mp_horde_narr_v1_D",
                "ss_mp_annex_hack_narr_v1_D",
                "ss_mp_annex_upload_narr_v1_D",
                "ss_mp_disarm_dsble_narr_v1_D",
                "ss_mp_disarm_enble_narr_v1_D",
                "ss_mp_extraction_narr_v1_D",
                "VocalizationBanks"
            };

            // We have to fake a dlc dir for AFC's  'get files loaded in game'
            var fakeCooked = GetME3DirectAccessCache();
            MountFile mf = new MountFile() { Game = MEGame.LE3, MountPriority = 50000, MountFlags = new MountFlag(EME3MountFileFlag.LoadsInMultiplayer) };
            mf.WriteMountFile(Path.Combine(fakeCooked, "mount.dlc"));

            // List of all suffixes to ensure
            var audioSuffixes = BaseBuildSettings.SupportedVOLanguages.Select(x => x.ToString()).Concat(new[] { "SFX" });

            var loadedFiles = MELoadedFiles.GetFilesLoadedInGame(MEGame.ME3, includeAFCs: true); // This will also force reload the list of files.
            foreach (var afcN in afcBaseNames)
            {
                foreach (var loc in audioSuffixes)
                {
                    var locF = $"{afcN}_{loc}.afc";
                    var data = GetME3SFARFile(locF);
                    if (data == null)
                        continue; // On disk already


                    if (loadedFiles.ContainsKey(locF))
                    {
                        MilanLog.Information($"{locF} already accessible directly - skipping extraction");
                        continue; // Already exists
                    }
                    MilanLog.Information($"{locF} is being copied to the direct access cache");
                    using var outF = File.OpenWrite(Path.Combine(fakeCooked, locF));
                    data.CopyTo(outF);
                }
            }
        }

        /// <summary>
        /// Gets fodler where some file are cached to help make less complicated lookup in ME3
        /// </summary>
        /// <returns></returns>
        public static string GetME3DirectAccessCache()
        {
            var fakePath = Directory.CreateDirectory(Path.Combine(ME3Directory.DLCPath, "DLC_Milan")).FullName;
            return Directory.CreateDirectory(Path.Combine(fakePath, "CookedPCConsole")).FullName;
        }

        //public static void EnsureVGMStreamAvailable()
        //{
        //    if (!VGMAudioStreamHelper.EnsureVGMStream())
        //    {
        //        MilanLog.Fatal("Could not ensure VGMStream is available. This should be automatically corrected by MilanSync from the ME3Tweaks server.");
        //        Environment.Exit(1);
        //    }
        //}

        /// <summary>
        /// Ports localized versions of the given basePackageName 
        /// </summary>
        /// <param name="basePackageName"></param>
        /// <param name="outputFolder"></param>
        /// <param name="cache"></param>
        /// <param name="logCategory"></param>
        public static void PortLocalizations(string basePackageName, string outputFolder, PackageCache cache, string logCategory)
        {
            MilanLog.Information($"Porting localized files for {basePackageName}", customPrefix: logCategory);
            bool foundInt = false;
            foreach (var lang in BaseBuildSettings.SupportedVOLanguages)
            {
                var packageName = $"{basePackageName}_LOC_{lang}.pcc";
                var me3Package = MilanShared.GetME3Package(packageName, logIfNotFound: foundInt);
                if (me3Package == null)
                {
                    if (foundInt)
                    {
                        // If Int hasn't been found (it's first in list) we can skip logging as there shouldn't be other localizations
                        MilanLog.Warning($"Could not find localized package {packageName}", customPrefix: logCategory);
                    }
                    continue;
                }

                if (lang == MELocalization.INT)
                {
                    foundInt = true;
                }

                var finalPackagePath = Path.Combine(outputFolder, packageName);
                var locDestPackage = MEPackageHandler.CreateAndOpenPackage(finalPackagePath, MEGame.LE3);
                locDestPackage.LECLTagData.ImportHintFiles.Add(MilanShared.MP_STARTUP_FILENAME); // Hint this for importing.
                locDestPackage.LECLTagData.IsPostLoadFile = false;

                MilanLog.Information($"Porting localized file {me3Package.FileNameNoExtension}", customPrefix: logCategory);
                PortObjectReferencer(me3Package, locDestPackage, cache, logCategory, null);
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

        // This is a hack. These classes have some named functions that need updated in a second pass
        // due to class compilation ordering.
        public static string[] ClassesToDoubleRecompile = new[]
        {
            "SFXGameMPContent.SFXCustomAction_DisarmObject",
            "SFXGameContentDLC_CON_MP3.SFXObjective_MobileAnnex",
            "SFXGameContentDLC_CON_MP5.SFXProjectile_Adas_MP",
            "SFXGameContentDLC_CON_MP5.SFXProjectile_SalarianBlastSplitter_MP"
        };

        /// <summary>
        /// LE3-Specific fixes (such as three stage melee) - installed once porting has initially completed
        /// </summary>
        private static readonly string PostPortingClassOverrideFolder = Path.Combine(MilanShared.PipelineRoot, "Shared", "Compiling", "ClassOverride", "PostPorting");

        /// <summary>
        /// List of classes to override after porting
        /// </summary>
        private static CaseInsensitiveConcurrentDictionary<string> PostPortingClassOverrides { get; } = new();


        private record CompilationCompletion(ExportEntry classExp, string SuperClassName)
        {
            public bool Completed;
        }

        private static object globalDumpObj = new object();

        /// <summary>
        /// Ports an object referencer across games.
        /// </summary>
        /// <param name="sourcePackage"></param>
        /// <param name="destPackage"></param>
        /// <param name="cache"></param>
        /// <param name="logCategory"></param>
        public static void PortObjectReferencer(IMEPackage sourcePackage, IMEPackage destPackage, PackageCache cache, string logCategory, Func<IMEPackage, ExportEntry, RelinkerOptionsPackage, IEntry> customDonorImporter = null)
        {
            var objReferencer = sourcePackage.Exports.FirstOrDefault(x => x.ClassName == "ObjectReferencer");

            MilanLog.Information($"Porting object referencer in {sourcePackage.FileNameNoExtension}", customPrefix: logCategory);
            //DotTrace.StartCollectingData(); // Start profiling
            var sw = new Stopwatch();
            sw.Start();
            var rop = new RelinkerOptionsPackage()
            {
                Cache = cache,
                TargetGameDonorDB = MilanShared.LE3ObjectDB,
                PortExportsAsImportsWhenPossible = true,
                GenerateImportsForGlobalFiles = true,
                DestinationCustomImportFileResolver = LE3PackageResolver,
                SourceCustomImportFileResolver = ME3PackageResolver,
                CustomDonorImporter = customDonorImporter,
                CrossGameFunctionSourceOverride = (sourceFunc, decompiledText) =>
                {
                    var overrideText = GetFunctionOverrideText(sourceFunc, out var overrideClassName, out var overrideFuncName);
                    if (overrideText != null)
                    {
                        MilanLog.Information($"Overriding function {overrideFuncName} in class {overrideClassName} with override during cross-game port", customPrefix: logCategory);
                        return overrideText;
                    }
                    return decompiledText;
                }
            };
            try
            {
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

            // destPackage.Save();

            MilanLog.Information("Recompiling ported classes (if necessary)", customPrefix: logCategory);
            UnrealScriptOptionsPackage usop = new UnrealScriptOptionsPackage()
            {
                Cache = cache,
                CustomFileResolver = MilanShared.LE3PackageResolver,
                MissingObjectResolver = MilanShared.MissingObjectResolver,
                BaseFilesFileLib = LE3FileLibCache.GetBaseFilesFileLibFor(destPackage),
            };
            FileLib lib = new FileLib(destPackage);
            if (!lib.Initialize(usop))
            {
                MilanShared.LogFailedFileLibInit(lib, $"Failed to initialize FileLib for recompilation of classes in {destPackage.FileNameNoExtension}", logCategory);
            }

            var classes = rop.CrossPackageMap.Values.OfType<ExportEntry>().Where(x => x.IsClass).ToList();
            var completions = new Dictionary<string, CompilationCompletion>();
            foreach (var c in classes)
            {
                completions.Add(c.ObjectName, new CompilationCompletion(c, c.SuperClassName));
            }

            foreach (CompilationCompletion completion in completions.Values)
            {
                try
                {
                    if (completion.Completed)
                    {
                        continue;
                    }
                    PerformRecompile(completion);
                    void PerformRecompile(CompilationCompletion cc)
                    {
                        if (cc.SuperClassName is not null
                            && completions.TryGetValue(cc.SuperClassName, out CompilationCompletion superCompletion)
                            && !superCompletion.Completed)
                        {
                            // Compile parent first.
                            PerformRecompile(superCompletion);
                        }

                        // Recompile class if necessary
                        try
                        {
                            bool useOverride = false;
                            var className = cc.classExp.ObjectName;

                            // Check if we have an override already loaded
                            if (!PostPortingClassOverrides.TryGetValue(className, out var text))
                            {
                                // No loaded override - does it exist on disk?
                                lock (PostPortingClassOverrides)
                                {
                                    if (File.Exists(Path.Combine(PostPortingClassOverrideFolder, $"{className}.uc")))
                                    {
                                        // It exists - load and cache it
                                        MilanLog.Information($"  Recompiling {className} with Milan override", customPrefix: logCategory);
                                        text = File.ReadAllText(Path.Combine(PostPortingClassOverrideFolder, $"{className}.uc"));
                                        PostPortingClassOverrides[className] = text;
                                        useOverride = true;
                                    }
                                }

                                if (!useOverride)
                                {
                                    // Check if we need to do this at all
                                    var isValid = VTables.VerifyVTable(cc.classExp, cache, false);
                                    if (isValid)
                                    {
                                        cc.Completed = true;
                                        return;
                                    }

                                    // Use decomp
                                    MilanLog.Information($"  Recompiling {className}", customPrefix: logCategory);
                                    (_, text) = UnrealScriptCompiler.DecompileExport(cc.classExp, lib, usop);
                                    Debug.WriteLine(text);
                                }
                            }
                            UnrealScriptCompiler.CompileClass(destPackage, text, lib, usop, cc.classExp);
                        }
                        catch (Exception e)
                        {
                            // destPackage.Save(@"C:\users\public\fail.pcc");
                            MilanLog.Exception(e, "  Error recompiling function:");
                        }

                        cc.Completed = true;
                    }
                }
                catch (Exception e)
                {
                    var log = new MessageLog();
                    log.LogError($"Exception while compiling '{completion.classExp.ObjectName}': {e}");
                    MilanLog.LogUSCErrors(log);
                }
            }

#if DEBUG
            // Dump classes out to loose classes folder
            foreach (var cls in destPackage.Exports.Where(x => x.IsClass))
            {
                var linker = cls.GetLinker();
                if (linker.CaseInsensitiveEquals("SFXGame"))
                {
                    continue;
                }
                if (linker.CaseInsensitiveEquals("SFXGameContent"))
                {
                    continue;
                }
                var outFolder = Directory.CreateDirectory(Path.Combine(MilanShared.PipelineRoot, "Shared", "ClassLibrary", "LooseClasses", cls.GetLinker())).FullName;
                var existingUC = Path.Combine(outFolder, cls.ObjectName + ".uc");
                lock (globalDumpObj)
                {
                    if (!File.Exists(existingUC))
                    {
                        MilanShared.DecompileClassToFile(cls, lib, cache, existingUC);
                    }
                }
            }
#endif

            MilanLog.Information("Saving package", customPrefix: logCategory);
            destPackage.Save(diskIOSyncLock: DiskIOSyncLock);
            MilanShared.RefreshMilanFiles = true;
            }
            finally
            {
                rop.Dispose();
            }
        }

        /// <summary>
        /// Decompiles a class to the file path specified, prepending milan autogen information
        /// </summary>
        /// <param name="classExp"></param>
        /// <param name="fileLib"></param>
        /// <param name="cache"></param>
        /// <param name="outputPath"></param>
        public static void DecompileClassToFile(ExportEntry classExp, FileLib fileLib, PackageCache cache, string outputPath)
        {
            var usingTestPatch = false;
            if (classExp.Game == MEGame.ME3)
            {
                // We must first see if this is in testpatch!!
                var testPatchClass = MilanShared.GetTestPatchClass(classExp);
                if (testPatchClass != null)
                {
                    usingTestPatch = true;
                    classExp = testPatchClass;
                    fileLib = null; // Must re-init
                }
            }

            MilanLog.Information($"     Decompiling {classExp.FileRef.Game} {classExp.InstancedFullPath}", customPrefix: @"MILAN-Decompiler");
            if (usingTestPatch)
            {
                MilanLog.Information($@"  Using DLC_TestPatch version of {classExp.InstancedFullPath}", customPrefix: @"MILAN-Decompiler");
            }
            UnrealScriptOptionsPackage usop = new UnrealScriptOptionsPackage()
            {
                Cache = cache,
                BaseFilesFileLib = classExp.Game == MEGame.LE3 ? LE3FileLibCache.GetBaseFilesFileLibFor(classExp.FileRef) : null,
            };

            if (fileLib == null)
            {
                // Initialize filelib if it wasn't.
                try
                {

                    fileLib = new FileLib(classExp.FileRef);
                    if (!fileLib.Initialize(usop))
                    {
                        MilanShared.LogFailedFileLibInit(fileLib);
                    }
                }
                catch
                {
                    //we're not checking if it failed to initialize because we don't really care, since decompilation doesn't actually need an initialized filelib,
                    //it just makes the output a bit nicer (at the time of this writing all it does is resolve some integer literals into enum values)
                }
            }

            (_, string functionText) = UnrealScriptCompiler.DecompileExport(classExp, fileLib, usop);

            var newClassText = functionText.Split('\n').ToList();

            // Insert metadata about autogen
            newClassText.Insert(0, $"// Source: {classExp.FileRef.Game}, {classExp.FileRef.FileNameNoExtension}");
            newClassText.Insert(1, $"// Initial decompilation: {DateTime.Now}");
            File.WriteAllLines(outputPath, newClassText);
        }

        private static IMEPackage GetME3Package(string arg)
        {
            return GetME3Package(arg, null);
        }

        private static readonly object _globalDirEnumerator = new object();

        /// <summary>
        /// Set to true to force the LE3PackageResolver to enumerate the source files directory again.
        /// </summary>
        public static bool RefreshMilanFiles = true;

        /// <summary>
        /// The list of files in the Milan DLC folder
        /// </summary>
        private static string[] MilanFiles;

        private static MilanPackageCache le3GlobalCache;

        /// <summary>
        /// Cache that holds the common ME3 packages - including MP startups
        /// </summary>
        private static MilanPackageCache me3GlobalCache;

        /// <summary>
        /// Optional hook so a higher layer (BaseDeltaHandler) can supply a patched replacement for a
        /// vanilla LE3 file while the global package cache is being built. Consulted once per filename
        /// as <see cref="InitGlobalPackages"/> loads the "safe to import from" list, so a patched file
        /// lands in the cache in the correct build order (and any donor lookups a patch target makes
        /// while it's being built can already see earlier patched files) instead of being inserted
        /// after the fact. Return null to fall back to loading vanilla for that file.
        /// </summary>
        public static Func<string, IMEPackage> LE3PatchedPackageProvider;

        public static void AddGlobalCachedPackage(IMEPackage package)
        {
            if (package.Game == MEGame.LE3)
            {
                if (le3GlobalCache == null) le3GlobalCache = InitGlobalPackages(MEGame.LE3);
                le3GlobalCache.InsertIntoCache(package);
            }
            else
            {
                if (me3GlobalCache == null) me3GlobalCache = InitGlobalPackages(MEGame.ME3);
                me3GlobalCache.InsertIntoCache(package);
            }
        }

        /// <summary>
        /// Resolves a package name to package in the Milan DLC
        /// </summary>
        /// <param name="filename"></param>
        /// <returns></returns>
        public static IMEPackage LE3PackageResolver(string filename, PackageCache cache)
        {
            string matching = null;
            if (BaseBuildSettings.OutputModPath != null)
            {
                lock (_globalDirEnumerator)
                {
                    if (RefreshMilanFiles)
                    {
                        MilanFiles = Directory.GetFiles(BaseBuildSettings.OutputModPath, "*",
                            SearchOption.AllDirectories);
                        RefreshMilanFiles = false;
                    }

                    matching = MilanFiles.FirstOrDefault(x => Path.GetFileName(x).CaseInsensitiveEquals(filename));
                }
            }

            if (matching != null)
            {
                // See if this package is already loaded
                var global = GetLE3GlobalCachedPackage(matching);
                if (global != null)
                    return global;

                // Multi thread file read can cause issues.
                lock (_globalDirEnumerator)
                {
                    if (cache != null)
                    {
                        return cache.GetCachedPackage(matching, openPackageMethod: GetLE3Package);
                    }

                    var package = MEPackageHandler.OpenMEPackage(matching, diskIOSyncLock: DiskIOSyncLock);
                    return package;
                }
            }

            return GetLE3GlobalCachedPackage(filename); // Try with full filename - Core, SFXGame, etc.
        }

        public static IMEPackage ME3PackageResolver(string filename, PackageCache cache)
        {
            // Lookup in ME3 global. We don't force to use specific packages
            return GetME3GlobalCachedPackage(filename);
        }

        /// <summary>
        /// Returns a package from the global cache if found. Searched based on the filename
        /// </summary>
        /// <param name="filename"></param>
        /// <returns></returns>
        private static IMEPackage GetLE3GlobalCachedPackage(string filename)
        {
            // If build is being done on NAS looking for local files will be slow
            if (le3GlobalCache == null)
            {
                le3GlobalCache = InitGlobalPackages(MEGame.LE3);
            }

            // Return cache or empty if not in the global cache.
            return le3GlobalCache.GetCachedPackage(filename, false);
        }

        private static object _me3CacheSync = new Object();
        private static IMEPackage GetME3GlobalCachedPackage(string filename)
        {
            lock (_me3CacheSync)
            {
                if (me3GlobalCache == null)
                {
                    me3GlobalCache = InitGlobalPackages(MEGame.ME3);
                }
            }

            // Return cache or empty if not in the global cache.
            return me3GlobalCache.GetCachedPackage(filename, false);
        }

        public static string GetMilanNewMPCommonClassesPath()
        {
            return Directory.CreateDirectory(Path.Combine(MilanShared.PipelineRoot, @"Shared", @"Compiling", @"MPCommonAdditionalClasses")).FullName;
        }

        public static void MergeObjectReferencers(IMEPackage source, IMEPackage target)
        {
            var sourceRef = source.Exports.FirstOrDefault(x => x.idxLink == 0 && x.ObjectName == "ObjectReferencer" && x.ClassName == "ObjectReferencer");
            var destRef = target.Exports.FirstOrDefault(x => x.idxLink == 0 && x.ObjectName == "ObjectReferencer" && x.ClassName == "ObjectReferencer");

            // We are going to do a replace with relink to pull in all referenced content. We don't want to trash 
            // anything if possible, so we will use the existing referencer
            // First we must cache the contents.
            var originalReferences = destRef.GetProperty<ArrayProperty<ObjectProperty>>("ReferencedObjects").Select(x => target.GetEntry(x.Value)).ToList();

            EntryImporter.ImportAndRelinkEntries(EntryImporter.PortingOption.ReplaceSingularWithRelink, sourceRef,
                target, destRef, true, new RelinkerOptionsPackage()
                {
                    SourceCustomImportFileResolver = MilanShared.LE3PackageResolver, // Optimized file lookup
                    DestinationCustomImportFileResolver = MilanShared.LE3PackageResolver,
                    // PortExportsAsImportsWhenPossible = true, // Object referencer merge should have packages already set up properly
                    Cache = new PackageCache(),

                }, out _);

            var newReferences = destRef.GetProperty<ArrayProperty<ObjectProperty>>("ReferencedObjects").Select(x => target.GetEntry(x.Value)).ToList();

            var allReferences = originalReferences.Concat(newReferences).Distinct();
            destRef.WriteProperty(new ArrayProperty<ObjectProperty>(allReferences.Select(x => new ObjectProperty(x)), "ReferencedObjects"));

        }

        public static IEnumerable<IMEPackage> GetLE3GlobalPackages()
        {
            if (le3GlobalCache == null)
                le3GlobalCache = InitGlobalPackages(MEGame.LE3);
            return le3GlobalCache.GetPackages();
        }

        private static MilanPackageCache InitGlobalPackages(MEGame game)
        {
            MilanLog.Information($"Loading {game} global cache...");

            // Todo: Make these use backup paths instead of live paths if available.
            // This will make it more consistent
            MilanPackageCache cache = new MilanPackageCache { DebugName = $"{game} global cache (process lifetime)" };

            // Assign the static field to this (still-empty) cache before populating it, rather than
            // after this method returns. A patch target built via LE3PatchedPackageProvider below may
            // itself trigger a donor lookup back through GetLE3GlobalCachedPackage/LE3PackageResolver
            // while this method is still running; assigning early means that re-entrant lookup sees the
            // cache as it's being built instead of null (which would otherwise start a second, overlapping
            // initialization).
            if (game == MEGame.ME3) me3GlobalCache = cache;
            else le3GlobalCache = cache;

            if (game == MEGame.ME3)
            {
                cache.InsertIntoCache(MEPackageHandler.OpenMEPackages(EntryImporter
                    .FilesSafeToImportFrom(MEGame.ME3)
                    .Select(x => Path.Combine(MEDirectories.GetCookedPath(MEGame.ME3), x))));
                cache.InsertIntoCache(GetME3Package("Startup_DLC_CON_MP2_INT.pcc")); // Add DLC startups
                cache.InsertIntoCache(GetME3Package("Startup_DLC_CON_MP3_INT.pcc"));
                cache.InsertIntoCache(GetME3Package("Startup_DLC_CON_MP4_INT.pcc"));
                cache.InsertIntoCache(GetME3Package(MP_STARTUP_FILENAME)); // Used as a cross-game relink source constantly; keep it cached so it isn't reopened from disk on every port.
                cache.InsertIntoCache(GetME3Package("BIO_COMMON.pcc")); // Postload base file for nearly everything; ME3PackageResolver only checks this cache, not the warm TieredPackageCache, so it needs to be here too.
            }
            else
            {
                // Loaded one file at a time (rather than one bulk OpenMEPackages call) so
                // LE3PatchedPackageProvider gets a chance to substitute a patched version - e.g.
                // BaseDeltaHandler supplying a compiled SFXGame.pcc - in the correct build order.
                foreach (var file in EntryImporter.FilesSafeToImportFrom(MEGame.LE3))
                {
                    var package = LE3PatchedPackageProvider?.Invoke(file)
                        ?? MEPackageHandler.OpenMEPackage(Path.Combine(MEDirectories.GetCookedPath(MEGame.LE3), file));
                    cache.InsertIntoCache(package);
                }

                // SFXGame is the last file in FileLib.BaseFileNames(LE3) - build the shared base FileLib
                // other LE3 FileLib construction can tier off of, now that it's cached (and, if patched,
                // patched) above.
                LE3FileLibCache.InitializeLE3BaseFileLib(cache.GetCachedPackage("SFXGame.pcc", false));

                // Extra loaded common packages
                var le3LoadedFiles = MELoadedFiles.GetFilesLoadedInGame(MEGame.LE3);
                cache.InsertIntoCache(MEPackageHandler.OpenMEPackage(le3LoadedFiles["BIO_COMMON.pcc"])); // Postload base file for nearly everything; LE3PackageResolver only checks this cache, not the warm TieredPackageCache, so it needs to be here too.
            }

            MilanLog.Information($"{game} global cache loaded ({cache.GetPackages().Count()} packages)");
            return cache;
        }

        private const string LOG_CATEGORY_MOR = @"MILAN-MissingObjectResolver";

        public static PackageCache LE3MissingObjectCache = TieredPackageCache.GetGlobalPackageCache(MEGame.LE3, debugName: "LE3 missing-object resolver root").ChainNewCache(debugName: "LE3 missing-object resolver cache (cleared after each pipeline)");
        public static PackageCache ME3MissingObjectCache = TieredPackageCache.GetGlobalPackageCache(MEGame.ME3, debugName: "ME3 missing-object resolver root").ChainNewCache(debugName: "ME3 missing-object resolver cache (cleared after each pipeline)");

        /// <summary>
        /// Releases the packages held by <see cref="LE3MissingObjectCache"/> and <see cref="ME3MissingObjectCache"/>.
        /// These have no size cap, so left alone they grow for the entire process lifetime as every donor lookup
        /// across the whole build adds to them, which can meaningfully add up over a full run. Call this between
        /// pipelines to keep them from accumulating unboundedly - the cache objects themselves are unaffected and
        /// will simply reopen packages from disk on the next lookup that needs them.
        /// </summary>
        public static void DropMissingObjectCaches()
        {
            LE3MissingObjectCache.ReleasePackages();
            ME3MissingObjectCache.ReleasePackages();
        }

        public static IEntry MissingObjectResolverExportsAsImports(IMEPackage package, string ifp, string classname)
        {
            return MissingObjectResolver(package, ifp, true);
        }

        public static IEntry MissingObjectResolver(IMEPackage package, string ifp, string className)
        {
            return MissingObjectResolver(package, ifp, false);
        }

        private static IEntry MissingObjectResolver(IMEPackage package, string ifp, bool portExportsAsImports)
        {
            // Redirect base GUI assets to DLC assets so we don't port unused GUI assets
            if (ifp == "GUI_SF_MPNewLobby.MPNewLobby")
                ifp = "GUI_SF_MPNewLobby_DLC.MPNewLobby";

            if (ifp == "GUI_SF_MPSelectKit.MPSelectKit")
                ifp = "GUI_SF_MPSelectKit_DLC.MPSelectKit";

            // redirect to a new UI based on the LE version that includes better textures and all _DLC changes, but with dynamic input support
            if (ifp == "GUI_SF_Leaderboard.Leaderboard" || ifp == "GUI_SF_Leaderboard_DLC.Leaderboard")
                ifp = "GUI_SF_Leaderboard_Milan.Leaderboard";

            if (ifp == "GUI_SF_MPMatchConsumables.MPMatchConsumables")
                ifp = "GUI_SF_MPMatchConsum_DLC.MPMatchConsumables";

            if (ifp == "GUI_SF_MPStore.MPStore")
                ifp = "GUI_SF_MPStore_DLC.MPStore";

            if (ifp == "GUI_SF_MPPromotion.MPPromotion")
                ifp = "GUI_SF_MPPromotion_DLC.MPPromotion";

            if (ifp == "GUI_SF_MPReinforcementsReveal.MPReinforcementsReveal")
                ifp = "GUI_SF_MPReinforcements_DLC.MPReinforcementsReveal";

            // we actually want to redirect to the basegame weapon select in this case; it includes all the _DLC updates, plus better textures and LE dynamic input support
            if (ifp == "GUI_SF_WeaponSelect_DLC.WeaponSelect")
                ifp = "GUI_SF_WeaponSelect.WeaponSelect";

            var possibleDonors = MilanShared.LE3ObjectDB.GetFilesContainingObject(ifp, package.Localization);
            if (possibleDonors == null)
            {
                // ME3 port
                MilanLog.Error($"Object '{ifp}' does not exist in LE3! We need to make a donor for this.", customPrefix: LOG_CATEGORY_MOR);
                var originalGameDonors = MilanShared.ME3ObjectDB.GetFilesContainingObject(ifp, package.Localization);
                originalGameDonors = originalGameDonors.Select(x => Path.GetFileName(x)).ToList(); // we don't care about paths.
                originalGameDonors.Sort(new ObjectSourceTierComparer(MEGame.ME3, package.FilePath));
                foreach (var possibleDonor in originalGameDonors)
                {
                    var donorP = MilanShared.GetME3Package(possibleDonor);
                    if (donorP != null)
                    {
                        var donorEntry = donorP.FindEntry(ifp);
                        if (donorEntry != null)
                        {
                            MilanLog.Warning($"  Using ME3 donor object {ifp} from {possibleDonor}", shouldLog: MilanLog.LogDonorMessages, customPrefix: LOG_CATEGORY_MOR);
                            return PortDonorIntoPackage(ME3MissingObjectCache, donorEntry, package, LOG_CATEGORY_MOR, true);
                        }
                    }
                }

                MilanLog.Error($"  No donor! Returning null!!", customPrefix: LOG_CATEGORY_MOR);
                return null;
            }

            // Sort by higher tier first
            possibleDonors.Sort(new ObjectSourceTierComparer(MEGame.LE3, package.FilePath));

            foreach (var possibleDonor in possibleDonors)
            {
                var donorP = LE3MissingObjectCache.GetCachedPackage(Path.Combine(LE3Directory.DefaultGamePath, possibleDonor), openPackageMethod: MilanShared.GetLE3Package);
                if (donorP != null)
                {
                    var donorEntry = donorP.FindEntry(ifp);
                    if (donorEntry != null)
                    {
                        MilanLog.Information($"  Using donor object {ifp} from {possibleDonor}", shouldLog: MilanLog.LogDonorMessages, customPrefix: LOG_CATEGORY_MOR);
                        return PortDonorIntoPackage(LE3MissingObjectCache, donorEntry, package, LOG_CATEGORY_MOR, portExportsAsImports);
                    }
                    else
                    {
                        MilanLog.Warning($"  LE3 donor package {possibleDonor} does not contain {ifp}", customPrefix: LOG_CATEGORY_MOR);
                    }
                }
            }
            MilanLog.Error($"Unable to find object {ifp} in {possibleDonors.Count} packages!", customPrefix: LOG_CATEGORY_MOR);
            return null;
        }


        public static IEntry PortDonorIntoPackage(PackageCache globalCache, IEntry donorEntry, IMEPackage package, string logCategory, bool portExportsAsImports)
        {
            if (donorEntry is ImportEntry donorImport)
            {
                // uh
                Debug.WriteLine("Uh oh");
            }
            else if (donorEntry is ExportEntry donorExport)
            {
                //if (donorEntry.InstancedFullPath == "BioVFX_Exp3_CitCas.Materials.HotTubFoam")
                //    Debugger.Break();
                if (EntryImporter.IsSafeToImportFrom(donorEntry.FileRef.FilePath, MEGame.LE3, package.FilePath))
                {
                    var existingImport = package.FindImport(donorEntry.MemoryFullPath, donorEntry.ClassName);
                    if (existingImport != null)
                    {
                        // Use existing import to prevent duplicates.
                        return existingImport;
                    }

                    // Create parents
                    MilanLog.Information($"    Porting as import", shouldLog: MilanLog.LogDonorMessages, customPrefix: logCategory);
                    var parent = EntryExporter.PortParents(donorEntry, package, true);
                    ImportEntry imp = new ImportEntry(donorExport, parent.UIndex, package);
                    package.AddImport(imp);
                    return imp; // Adding as import
                }
                if (donorExport.FileRef.FileNameNoExtension == "SFXGame")
                    Debugger.Break();
                MilanLog.Information($"    Porting from {donorExport.FileRef.FileNameNoExtension}", shouldLog: MilanLog.LogDonorMessages, customPrefix: logCategory);
                var rop = new RelinkerOptionsPackage()
                {
                    Cache = globalCache,
                    TargetGameDonorDB = MilanShared.LE3ObjectDB,
                    DestinationCustomImportFileResolver = MilanShared.LE3PackageResolver,
                    PortImportsMemorySafe = true, // MPCommon might try to reference BIO_COMMON which we do not want.
                    PortExportsAsImportsWhenPossible = portExportsAsImports
                };
                try
                {
                    var errors = EntryExporter.ExportExportToPackage(donorExport, package, out var newExp, globalCache, customROP: rop);
                    return newExp;
                }
                finally
                {
                    rop.Dispose();
                }
            }

            return null;
        }

        //terrible function, there are better ways of implementing it.
        /// <summary>
        /// Gets a VTable for the given class by looking it up from an export of it in LE3
        /// </summary>
        /// <param name="className"></param>
        /// <returns></returns>
        public static List<string> GetVTableFromDonor(string className)
        {

            var classInfo = GlobalUnrealObjectInfo.GetClassOrStructInfo(MEGame.LE3, className);
            if (classInfo is not null)
            {
                string path = Path.Combine(MEDirectories.GetBioGamePath(MEGame.LE3), classInfo.pccPath);
                if (File.Exists(path))
                {
                    IMEPackage partialLoad = MEPackageHandler.UnsafePartialLoad(path, exp => exp.IsClass && exp.ObjectName == className);
                    foreach (ExportEntry export in partialLoad.Exports)
                    {
                        if (export.IsClass && export.ObjectName == className)
                        {
                            var obj = export.GetBinaryData<UClass>();
                            var list = obj.VirtualFunctionTable.Select(uIdx => partialLoad.GetEntry(uIdx).ObjectName.Name).ToList();
                            if (className == "SFXProjectile_PowerCustomAction_SuperSeeking")
                            {
                                // Debugger.Break();
                            }

                            return list;
                        }
                    }
                }
            }

            return null;
        }

        public static void LogFailedFileLibInit(FileLib fl, string firstMessage = "Compilation errors occurred", string logCategory = "Milan-Shared")
        {
            LogCompilerMessages(fl.InitializationLog, firstMessage, logCategory);
        }

        public static void LogCompilerMessages(MessageLog log, string firstMessage = "Compilation errors occurred", string logCategory = "Milan-Shared")
        {
            MilanLog.Error(firstMessage);
            foreach (var error in log.AllErrors)
            {
                MilanLog.Error($"  {error}", customPrefix: logCategory);
            }
        }

        /// <summary>
        /// Used to track custom registered packages so they can be unregistered at a later time
        /// </summary>
        /// <param name="package">Package to register in the ObjectInstanceDB</param>
        /// <param name="objectsToAddPredicate">Predicate used to determine which objects to add to the database</param>
        public static void RegisterObjectDBPackage(IMEPackage package, Func<ExportEntry, bool> objectsToAddPredicate = null)
        {
            if (package.Game == MEGame.LE3)
            {
                RegisteredObjectDBPackages.Add(package.FilePath);
                MilanShared.LE3ObjectDB.AddFileToDB(package, package.FilePath, objectsToAddPredicate: objectsToAddPredicate);
            }
            else
            {
                MilanShared.ME3ObjectDB.AddFileToDB(package, package.FilePath, objectsToAddPredicate: objectsToAddPredicate);
            }
        }

        /// <summary>
        /// Unregisters all packages from LE3's ObjectDB that were added after the vanilla database loaded
        /// </summary>
        public static void UnregisterObjectDBPackages()
        {
            foreach (var file in RegisteredObjectDBPackages)
            {
                MilanLog.Information($"Unregistering ObjectInstanceDB package {file}", customPrefix: @"MILAN-Shared");
                var package = MEPackageHandler.UnsafePartialLoad(file, x => false);
                MilanShared.LE3ObjectDB.RemoveFileFromDB(package);
            }

            RegisteredObjectDBPackages.Clear();
        }

        public static void RegisterObjectDBObject(ExportEntry export)
        {
            if (export.Game == MEGame.LE3)
            {
                RegisteredObjectDBPackages.Add(export.FileRef.FilePath);
                MilanShared.LE3ObjectDB.AddObjectToDB(export);
            }
            else
            {
                MilanShared.ME3ObjectDB.AddObjectToDB(export);
            }
        }

        /// <summary>
        /// Moves the object with the given IFP underneath the given parent, or root if null.
        /// </summary>
        /// <param name="sourcePackage"></param>
        /// <param name="ifp"></param>
        /// <param name="parent"></param>
        public static ExportEntry MoveExport(IMEPackage sourcePackage, string ifp, ExportEntry parent, NameReference newName = default)
        {
            var exp = sourcePackage.FindExport(ifp);
            exp.idxLink = parent?.UIndex ?? 0;

            if (exp.ClassName == "Class")
                exp.GetDefaults().idxLink = parent?.UIndex ?? 0;

            if (newName.Name != null)
            {
                RenameObject(exp.FileRef, exp.InstancedFullPath, newName);
            }

            return exp;
        }

        /// <summary>
        /// Renames an object, including defaults if it is a class.
        /// </summary>
        /// <param name="package"></param>
        /// <param name="ifp"></param>
        /// <param name="newName"></param>
        /// <returns></returns>
        public static ExportEntry RenameObject(IMEPackage package, string ifp, NameReference newName)
        {
            var exp = package.FindExport(ifp);
            exp.ObjectName = newName;
            if (exp.ClassName == "Class")
            {
                exp.GetDefaults().ObjectName = "Default__" + newName.Name; // Will not be indexed.
            }

            return exp;
        }

        private static object commonCacheSyncObj = new object();

        /// <summary>
        /// Root tier: global safe-to-import files (Core, Engine, etc). Shared by every other Milan cache tier below.
        /// </summary>
        private static TieredPackageCache globalCache;

        /// <summary>
        /// Holds only BIOP_MP_COMMON, chained to <see cref="globalCache"/>. Stays null until <see cref="PromoteMPCommonIntoCacheChain"/>
        /// is called - the file doesn't exist until the MPCommon pipeline has actually built it. Once created, it is
        /// needed by every pipeline that runs after MPCommon - including ones that run after Levels - so this tier
        /// is never dropped mid-run.
        /// </summary>
        private static TieredPackageCache mpCommonPackageCache;

        /// <summary>
        /// Holds other files that are hot across many pipelines. Chained to <see cref="mpCommonPackageCache"/> once
        /// that tier exists, or directly to <see cref="globalCache"/> before then (e.g. while the MPCommon pipeline
        /// itself is still building BIOP_MP_COMMON and wants the benefit of this tier too). Dropped once Levels (the
        /// last content-porting pipeline) completes, leaving the chain as Global -&gt; MPCommon for the rest of the run.
        /// </summary>
        private static TieredPackageCache warmCache;

        /// <summary>
        /// Returns the tiered cache chain content pipelines should chain their own cache onto: global safe-to-import
        /// -&gt; BIOP_MP_COMMON (once built; persistent for the rest of the run) -&gt; warm cache of other hot files
        /// (dropped after Levels).
        /// </summary>
        /// <returns></returns>
        public static TieredPackageCache GetMPCommonTieredPackageCache()
        {
            lock (commonCacheSyncObj)
            {
                globalCache ??= TieredPackageCache.GetGlobalPackageCache(MEGame.LE3, debugName: "Global LE3 safe-to-import cache (process lifetime)");

                if (warmCache == null)
                {
                    MilanLog.Information("Loading Milan warm TieredPackageCache");
                    // Chain onto MPCommon if it's already been built; otherwise onto global directly - PromoteMPCommonIntoCacheChain
                    // will splice MPCommon in above us later if it wasn't ready yet.
                    warmCache = (mpCommonPackageCache ?? globalCache).ChainNewCache(debugName: "MPCommon warm cache (dropped after Levels)");

                    var loadedFiles = MELoadedFiles.GetFilesLoadedInGame(MEGame.LE3);
                    // According to TieredPackageCache heatmap these are hot files - loading more than 10 times in MilanMain
                    warmCache.GetCachedPackage(loadedFiles["BIO_COMMON.pcc"]);
                    warmCache.GetCachedPackage(loadedFiles["BioP_Char.pcc"]);
                    warmCache.GetCachedPackage(loadedFiles["BioD_Cat002.pcc"]);
                    warmCache.GetCachedPackage(loadedFiles["BioP_Cat002.pcc"]);
                    warmCache.GetCachedPackage(loadedFiles["BioP_ProEar.pcc"]);
                    warmCache.GetCachedPackage(loadedFiles["BioD_CitHub_Prothean.pcc"]);
                    warmCache.GetCachedPackage(loadedFiles["BioP_Gth002.pcc"]);
                    warmCache.GetCachedPackage(loadedFiles["BioD_MPCer_100SP.pcc"]);
                    warmCache.GetCachedPackage(loadedFiles["BioA_ProEar_100.pcc"]);
                    warmCache.GetCachedPackage(loadedFiles["SFXCharacterClass_Adept.pcc"]);

                    // Per the TieredPackageCache call-stack heatmap (TieredCacheHeatMapCallStacks.json), these were loading more than 20 times in a single MilanMain run.
                    warmCache.GetCachedPackage(loadedFiles["BioD_ProEar_200.pcc"]);
                    warmCache.GetCachedPackage(loadedFiles["BioD_Gth001_300GARDIAN.pcc"]);
                    warmCache.GetCachedPackage(loadedFiles["BioD_MPRctr_050SPEntry.pcc"]);
                    warmCache.GetCachedPackage(loadedFiles["BioA_Kro002_000LevelTrans_LOC_DEU.pcc"]);
                    warmCache.GetCachedPackage(loadedFiles["BioD_ProEar.pcc"]);
                    warmCache.GetCachedPackage(loadedFiles["BioP_Kro002.pcc"]);
                    warmCache.GetCachedPackage(loadedFiles["BioA_Kro002.pcc"]);
                    warmCache.GetCachedPackage(loadedFiles["BioD_Cat003_780FinalConvos_LOC_DEU.pcc"]);
                    warmCache.GetCachedPackage(loadedFiles["BioD_Cat002_100Intro.pcc"]);
                    warmCache.GetCachedPackage(loadedFiles["BioH_Ashley_00.pcc"]);
                    warmCache.GetCachedPackage(loadedFiles["BioD_Kro001_90OpeningConvo_LOC_DEU.pcc"]);
                    warmCache.GetCachedPackage(loadedFiles["BioD_ProEar_300.pcc"]);
                    warmCache.GetCachedPackage(loadedFiles["BioD_KroGar_100Landing.pcc"]);
                    warmCache.GetCachedPackage(loadedFiles["BioD_Cat003_000LevelTrans.pcc"]);
                    warmCache.GetCachedPackage(loadedFiles["BioD_Cat002_600KLFight.pcc"]);
                    warmCache.GetCachedPackage(loadedFiles["BioD_Gth002.pcc"]);

                    MilanLog.Information("Loaded Milan warm TieredPackageCache");
                }
            }

            return warmCache;
        }

        /// <summary>
        /// Returns the base tiered cache chain (global safe-to-import -&gt; BIOP_MP_COMMON once built) WITHOUT the
        /// warm tier of extra hot files. Use this instead of <see cref="GetMPCommonTieredPackageCache"/> for
        /// callers that only need the core global/MPCommon files (e.g. verification passes) and shouldn't pull in
        /// - or trigger creation of - the warm cache. Any additional packages such a caller happens to need (e.g.
        /// direct parents of what it's checking) will simply be opened into its own chained cache as normal.
        /// </summary>
        public static TieredPackageCache GetMPCommonBaseTieredPackageCache()
        {
            lock (commonCacheSyncObj)
            {
                globalCache ??= TieredPackageCache.GetGlobalPackageCache(MEGame.LE3, debugName: "Global LE3 safe-to-import cache (process lifetime)");
                return mpCommonPackageCache ?? globalCache;
            }
        }

        /// <summary>
        /// Splices a tier holding just BIOP_MP_COMMON in between the global tier and the warm cache. Call this once
        /// the MPCommon pipeline has finished building BIOP_MP_COMMON.pcc - before that, the file doesn't exist, so
        /// this tier can't be populated. If the warm cache was already built (e.g. the MPCommon pipeline itself used
        /// <see cref="GetMPCommonTieredPackageCache"/> while it was running), it is re-parented onto the new MPCommon
        /// tier here; otherwise <see cref="GetMPCommonTieredPackageCache"/> will chain onto it directly the first
        /// time the warm cache is built.
        /// </summary>
        public static void PromoteMPCommonIntoCacheChain()
        {
            lock (commonCacheSyncObj)
            {
                globalCache ??= TieredPackageCache.GetGlobalPackageCache(MEGame.LE3, debugName: "Global LE3 safe-to-import cache (process lifetime)");

                mpCommonPackageCache = globalCache.ChainNewCache(debugName: "MPCommon BIOP_MP_COMMON cache (process lifetime)");
                var mpCommonPkg = mpCommonPackageCache.GetCachedPackage(Path.Combine(BaseBuildSettings.OutputModPath, "CookedPCConsole", "BIOP_MP_COMMON.pcc")); // Cache MPCommon as it will be used by every later pipeline.

                // Safety net: MPCommon.CompileMPCommonPackage and the checkpoint-restore path in
                // Program.cs both already do this earlier (so NonStartupPipeline, which runs before
                // this method on the fresh-build path, can benefit too) - this is a no-op then. It only
                // does real work if neither of those ran (e.g. RunMPCommonPipeline is false and no
                // checkpoint was used, because BIOP_MP_COMMON already existed from a prior run).
                LE3FileLibCache.InitializeMPCommonFileLib(mpCommonPkg);

                if (warmCache != null)
                {
                    // Warm cache already exists - re-parent it onto the newly-built MPCommon tier instead of global.
                    warmCache.ParentCache = mpCommonPackageCache;
                }
            }
        }

        /// <summary>
        /// Drops the warm cache tier (see <see cref="warmCache"/>) once porting is done - call this after Levels,
        /// the last content-porting pipeline. Does not touch the BIOP_MP_COMMON tier, which stays alive for the
        /// rest of the run since later stages (Verify, Conformance, etc.) still need to resolve against it.
        /// </summary>
        public static void DropWarmTieredPackageCache()
        {
            lock (commonCacheSyncObj)
            {
                warmCache?.Dispose();
                warmCache = null;
            }
        }

        public static ExportEntry CreateSPStartLocation(IMEPackage package, Point3D startLocation)
        {
            var pl = package.FindExport("TheWorld.PersistentLevel");
            var startLoc = ExportCreator.CreateExport(package, "BioStartLocation", "BioStartLocation", pl);
            startLoc.WriteProperty(new StructProperty("Vector", new PropertyCollection()
            {
                new FloatProperty(startLocation.X, "X"),
                new FloatProperty(startLocation.Y, "Y"),
                new FloatProperty(startLocation.Z, "Z"),
            }, "location", true));


            var collisionCylinder =
                ExportCreator.CreateExport(package, "CylinderComponent", "CylinderComponent", startLoc);
            collisionCylinder.WritePrePropsAndProperties(new byte[4],
                collisionCylinder.GetProperties()); // Set up pre-prop binary

            collisionCylinder.WriteProperty(new ObjectProperty(0, "ReplacementPrimitive"));
            // Technically should do lighting channels.

            startLoc.WriteProperty(new ObjectProperty(collisionCylinder, "CollisionComponent"));
            startLoc.WriteProperty(new NameProperty("start_milanSP", "Tag"));

            return startLoc;
        }

        private static bool InstalledMPCommonInfo = false;

        public static void InstallMPCommonClassInfo(string mpCommonPath)
        {
            if (InstalledMPCommonInfo)
                return;
            InstalledMPCommonInfo = true;
            MilanLog.Information($"Inventorying BIOP_MP_COMMON package");
            var p = MEPackageHandler.OpenMEPackage(mpCommonPath, diskIOSyncLock: DiskIOSyncLock);
            foreach (var ex in p.Exports.Where(x => x.IsClass))
            {
                var classInfo = GlobalUnrealObjectInfo.generateClassInfo(ex);
                MilanLog.Information($@"  Inventorying class {ex.InstancedFullPath}");
                GlobalUnrealObjectInfo.InstallCustomClassInfo(ex.ObjectName, classInfo, ex.Game);

                if (ex.InheritsFrom("SequenceObject"))
                {
                    var defaults = p.GetUExport(ObjectBinary.From<UClass>(ex).Defaults);
                    GlobalUnrealObjectInfo.GenerateSequenceObjectInfoForClassDefaults(defaults);
                }
            }
        }

        /// <summary>
        /// If a texture should be externalized
        /// </summary>
        /// <param name="rootTexture"></param>
        /// <param name="idxLink"></param>
        /// <returns></returns>
        private static bool ShouldExternalize(bool rootTexture, int idxLink)
        {
            // Exetrnalize if rootTexture is true with no link, otherwise only if it has one.
            return rootTexture ? idxLink == 0 : idxLink != 0;
        }

        /// <summary>
        /// Moves textures that can be TFC stored out of a package and into a TFC for performance. This creates a new TFC file, it will wipe out existing!!
        /// </summary>
        /// <param name="tfcType">TFC name prefix, e.g. Textures, Lighting</param>
        /// <param name="dlcName">Name of the DLC for TFC naming.</param>
        /// <param name="rootTextures">if we should externalize root textures (lighting) only or non-root textures (everything else)</param>
        /// <param name="logCategoryBase"></param>
        public static void MoveTexturesToTFC(string tfcType, string dlcName, bool rootTextures, string logCategoryBase)
        {
            string category = logCategoryBase + "-" + tfcType;
            var inputFolder = Path.Combine(BaseBuildSettings.OutputModPath, @"CookedPCConsole");
            const long MaxTFCSize = 2L * 1024 * 1024 * 1024; // 2 GiB
            int tfcIndex = 1; // Increments every 2GiB
            var tfcName = $"{tfcType}_{dlcName}";
            var tfcPath = Path.Combine(inputFolder, $"{tfcName}.tfc");
            var tfcStream = File.Open(tfcPath, FileMode.CreateNew, FileAccess.ReadWrite);
            var guid = Guid.NewGuid();
            tfcStream.WriteGuid(guid);

            foreach (var package in Directory.GetFiles(inputFolder, "*.pcc", SearchOption.AllDirectories))
            {
                MilanLog.Information($"Checking package {Path.GetFileName(package)}", customPrefix: category);
                //var me3File = MilanShared.GetME3Package(Path.GetFileName(package));
                using var le3File = MEPackageHandler.OpenMEPackage(package, diskIOSyncLock: DiskIOSyncLock);

                foreach (var tex in le3File.Exports.Where(x => x.IsTexture() && ShouldExternalize(rootTextures, x.idxLink)))
                {
                    if (tex.ObjectName.Name.StartsWith("Cubemap", StringComparison.OrdinalIgnoreCase))
                        continue; // These are never moved to TFC as far as I know...

                    var bin = (UTexture2D)ObjectBinary.From(tex); // Cast since we want it to make the lowest-tier class but we only need the upper one.

                    var startedMovingTexture = false;
                    var changedMips = bin.Mips.RemoveAll(x => x.StorageType == StorageTypes.empty);

                    if (bin.Mips.Count <= 6 && changedMips == 0)
                        continue;

                    bool updateTFCName = false;
                    for (int i = 0; i < bin.Mips.Count - 6; i++)
                    {
                        // Move data to external
                        var mip = bin.Mips[i];
                        if (mip.StorageType == StorageTypes.pccUnc)
                        {
                            var compressed = TextureCompression.CompressTexture(mip.Mip, StorageTypes.extOodle);

                            if (!startedMovingTexture && tfcStream.Position + compressed.Length > MaxTFCSize)
                            {
                                tfcStream.Dispose();
                                tfcIndex++;
                                tfcName = tfcIndex >= 2 ? $"{tfcType}_{dlcName}{tfcIndex}" : $"{tfcType}_{dlcName}";
                                tfcPath = Path.Combine(inputFolder, $"{tfcName}.tfc");
                                tfcStream = File.Open(tfcPath, FileMode.CreateNew, FileAccess.ReadWrite);
                                guid = Guid.NewGuid();
                                tfcStream.WriteGuid(guid);
                                MilanLog.Information($"TFC size limit reached, switching to {tfcName}.tfc", customPrefix: category);
                            }

                            MilanLog.Information($"  Moving texture to external TFC: {tex.InstancedFullPath}",
                                !startedMovingTexture, customPrefix: category);
                            startedMovingTexture = true;

                            var offset = tfcStream.Position;
                            tfcStream.Write(compressed);
                            mip.StorageType = StorageTypes.extOodle;
                            mip.DataOffset = (int)offset;
                            mip.CompressedSize = compressed.Length;
                            mip.Mip = Array.Empty<byte>();
                            changedMips++;
                            updateTFCName = true;
                        }
                    }

                    if (updateTFCName)
                    {
                        // Update TFC properties
                        var properties = tex.GetProperties();
                        properties.AddOrReplaceProp(new FGuid(guid).ToStructProperty("TFCFileGuid"));
                        properties.AddOrReplaceProp(new NameProperty(tfcName, "TextureFileCacheName"));
                        properties.RemoveNamedProperty("NeverStream");
                        tex.WriteProperties(properties);
                    }

                    if (changedMips > 0)
                    {
                        tex.WriteBinary(bin);
                    }

                    //var me3Tex = me3File.FindExport(tex.InstancedFullPath);
                    //if (me3Tex != null)
                    //{
                    //    var le3Bin = 
                    //}

                }

                if (le3File.IsModified)
                {
                    MilanLog.Information("  Saving package", customPrefix: category);
                    le3File.Save(diskIOSyncLock: DiskIOSyncLock);
                    MilanShared.RefreshMilanFiles = true;
                }
            }

            tfcStream.Dispose();
        }

        /// <summary>
        /// Maps a class name to preloaded source text for use when compiling classes out of the class library
        /// </summary>
        private static CaseInsensitiveConcurrentDictionary<string> _classLibraryToSourceMap = new();

        /// <summary>
        /// Uses LooseClassCompiler to compile classes from source out of the ClassLibrary, for classes in the source package into the destination package.
        /// </summary>
        /// <param name="me3Package"></param>
        /// <param name="le3Package"></param>
        /// <param name="cache"></param>
        /// <param name="logCategory"></param>
        /// <param name="materialDonorImporter"></param>
        public static bool PrePortClasses(IMEPackage me3Package, IMEPackage le3Package, PackageCache cache, string logCategory)
        {
            // Load classes from the class library

            UnrealScriptOptionsPackage usop = new UnrealScriptOptionsPackage()
            {
                Cache = cache,
                MissingObjectResolver = MilanShared.MissingObjectResolverExportsAsImports,
                CustomFileResolver = MilanShared.LE3PackageResolver,
                GetVTableFromDonor = MilanShared.GetVTableFromDonor
            };

            MilanLog.Information(@"Compiling LE3 class package", customPrefix: logCategory);
            return true;

            //MessageLog log = UnrealScriptCompiler.CompileLooseClasses(le3Package, classes, usop);

            //if (log.HasErrors)
            //{
            //    //if (AttemptToFindMissingClasses(log, pipeline, out var containingPackage, out var lClass))
            //    //{
            //    //    AddClassToCompilation(classes, containingPackage, lClass);
            //    //    return false; // False - forces recomp
            //    //}
            //    MilanLog.Error($"PRE-PORTING OF CLASSES FAILED IN PACKAGE {le3Package.FileNameNoExtension}", customPrefix: logCategory);
            //    foreach (var error in log.AllErrors)
            //    {
            //        MilanLog.Error($"  {error}", customPrefix: logCategory);
            //    }

            //    return false;
            //}

            //return true;
        }

        /// <summary>
        /// Strips error comments for function recompilation. Only use if you're going to be compiling
        /// </summary>
        /// <param name="originalString"></param>
        /// <returns></returns>
        public static string CleanErrorComments(string originalString, out bool hadErrors)
        {
            var lines = originalString.Split(new[] { "\r\n", "\r", "\n" }, StringSplitOptions.None);
            var cleanedLines = lines
                .Where(line => !line.Contains("Recompilation of this function is required"))
                .ToArray();

            hadErrors = cleanedLines.Length != lines.Length;

            var cleanedStr = string.Join(Environment.NewLine, cleanedLines);
            return cleanedStr;
        }

        /// <summary>
        /// Drops loaded objects that are for ME3->LE3 porting
        /// </summary>
        public static void DropPortingCaches()
        {
            MilanLog.Information("Dropping porting cache objects");
            DropWarmTieredPackageCache(); // Release the warm-file cache; BIOP_MP_COMMON itself stays cached for the rest of the run
            ME3ObjectDB = null;
            ME3DLCFileMap = null;
            me3GlobalCache?.Dispose();
            me3GlobalCache = null;
        }
    }
}
