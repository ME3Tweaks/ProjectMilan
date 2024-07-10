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
using LegendaryExplorerCore.Gammtek.Extensions;
using LegendaryExplorerCore.Helpers;
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
        public static string REDEMPTION_DLC_NAME { get; } = @"DLC_MOD_PMR3";
#endif

        private const string ROOT_FOLDER_NAME = @"ProjectMilan";
        public static ObjectInstanceDB LE3ObjectDB { get; set; }
        public static ObjectInstanceDB ME3ObjectDB { get; set; }

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
            return Path.Combine(MilanShared.PipelineRoot, @"Shared", @"Compiling", @"LooseFunctions", className);
        }

        public static IMEPackage GetLE3Package(string packageFileName)
        {
            var gp = GetLE3GlobalCachedPackage(packageFileName);
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
        public static bool EnsureMPCommonInGame()
        {
            var biopMPCommon = Path.Combine(BaseBuildSettings.OutputModPath, @"CookedPCConsole", MP_STARTUP_FILENAME);
            if (!File.Exists(biopMPCommon))
            {
                var files = MELoadedFiles.GetFilesLoadedInGame(MEGame.LE3);
                if (!files.TryGetValue(MP_STARTUP_FILENAME, out _))
                {
                    MilanLog.Error($"{MP_STARTUP_FILENAME} was not found - content pipelines cannot run, they depend on BIOP_MP_COMMON. Install Project Milan or build the MP startup pipeline if this is the Project Milan project.");
                    return false;
                }
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
            var package = MEPackageHandler.OpenMEPackage(packagePath);
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
            };

            // We have to fake a dlc dir for AFC's  'get files loaded in game'
            var fakePath = Directory.CreateDirectory(Path.Combine(ME3Directory.DLCPath, "DLC_Milan")).FullName;
            var fakeCooked = Directory.CreateDirectory(Path.Combine(fakePath, "CookedPCConsole")).FullName;
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
                    var milanLocPath = Path.Combine(BaseBuildSettings.OutputModPath, @"CookedPCConsole", locF);

                    if (loadedFiles.TryGetValue(locF, out var locOnDisk))
                    {
                        MilanLog.Information($"{locF} already exists in game - skipping extraction");
                        if (!File.Exists(milanLocPath))
                        {
                            MilanLog.Information($"Copying {locF} to Milan.");
                            File.Copy(locOnDisk, milanLocPath);
                        }
                        continue; // Already exists
                    }

                    var data = GetME3SFARFile(locF);
                    if (data == null)
                        continue; // On disk already

                    MilanLog.Information($"{locF} is being copied to the direct access cache");

                    if (loadedFiles.ContainsKey(locF))
                    {
                        MilanLog.Information($"{locF} already exists in game - skipping extraction");
                        continue; // Already exists
                    }
                    using var outF = File.OpenWrite(Path.Combine(fakeCooked, locF));
                    data.CopyTo(outF);

                    if (!File.Exists(milanLocPath))
                    {
                        MilanLog.Information($"Extracting {locF} to Milan.");
                        using var outLe = File.OpenWrite(milanLocPath);
                        data.CopyTo(outLe);
                    }
                }
            }
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
        /// Ports localized files 
        /// </summary>
        /// <param name="basePackageName"></param>
        /// <param name="outputFolder"></param>
        /// <param name="cache"></param>
        /// <param name="logCategory"></param>
        public static void PortLocalizations(string basePackageName, string outputFolder, PackageCache cache, string logCategory)
        {
            MilanLog.Information($"Porting localized files for {basePackageName}", customPrefix: logCategory);
            foreach (var lang in BaseBuildSettings.SupportedVOLanguages)
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
                locDestPackage.LECLTagData.ImportHintFiles.Add(MilanShared.MP_STARTUP_FILENAME); // Hint this for importing.
                locDestPackage.LECLTagData.IsPostLoadFile = false;

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

        // This is a hack. These classes have some named functions that need updated in a second pass
        // due to class compilation ordering.
        public static string[] ClassesToDoubleRecompile = new[]
        {
            "SFXGameMPContent.SFXCustomAction_DisarmObject",
            "SFXGameContentDLC_CON_MP3.SFXObjective_MobileAnnex",
            "SFXGameContentDLC_CON_MP5.SFXProjectile_Adas_MP",
            "SFXGameContentDLC_CON_MP5.SFXProjectile_SalarianBlastSplitter_MP"
        };

        private static readonly string PostPortingClassOverrideFolder = Path.Combine(MilanShared.PipelineRoot, "Shared", "Compiling", "ClassOverride", "PostPorting");

        private static CaseInsensitiveConcurrentDictionary<string> PostPortingClassOverrides { get; } = new();

        /// <summary>
        /// Ports an object referencer across games.
        /// </summary>
        /// <param name="sourcePackage"></param>
        /// <param name="destPackage"></param>
        /// <param name="cache"></param>
        /// <param name="logCategory"></param>
        public static void PortObjectReferencer(IMEPackage sourcePackage, IMEPackage destPackage, PackageCache cache, string logCategory)
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
                SourceCustomImportFileResolver = ME3PackageResolver
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

            // NEW CODE - Loose Class Compiler
            if (false)
            {
                MilanLog.Information("Preparing for class recompilation", customPrefix: logCategory);
                var classes = new List<UnrealScriptCompiler.LooseClass>();
                FileLib lib = new FileLib(destPackage);
                UnrealScriptOptionsPackage usop = new UnrealScriptOptionsPackage()
                {
                    Cache = cache,
                    CustomFileResolver = MilanShared.LE3PackageResolver,
                    GetVTableFromDonor = MilanShared.GetVTableFromDonor,
                    MissingObjectResolver = MilanShared.MissingObjectResolver,
                };
                lib.Initialize(usop);
                //foreach (var cls in rop.CrossPackageMap.Values.OfType<ExportEntry>().Where(x => x.IsClass))
                foreach (var cls in destPackage.Exports.Where(x => x.IsClass))
                {
                    // Decompile all classes
                    (_, string text) = UnrealScriptCompiler.DecompileExport(cls, lib, usop);
                    classes.Add(
                        new UnrealScriptCompiler.LooseClass(cls.ObjectName, text,
                            cls.ParentName)); // Always use ucFilePath as it will be in the proper package folder, even if it goes unused.
                }

                // SourceFilePath variable is used to store parent of class, which is the containing package.
                var looseClassPackages = new List<UnrealScriptCompiler.LooseClassPackage>();
                foreach (var classEx in classes)
                {
                    var packageFile = classEx.SourceFilePath;
                    var classList = looseClassPackages.Find(x => x.PackageName == packageFile);
                    if (classList == null)
                    {
                        classList = new UnrealScriptCompiler.LooseClassPackage(packageFile,
                            new List<UnrealScriptCompiler.LooseClass>());
                        looseClassPackages.Add(classList);
                    }

                    classList.Classes.Add(classEx);
                }

                MilanLog.Information(@"Compiling loose classes...", customPrefix: logCategory);
                //MessageLog log = UnrealScriptCompiler.CompileLooseClasses(destPackage, looseClassPackages,
                //    MPCommon.MissingObjectResolver, vtableDonorGetter: MPCommon.VTableDonorGetter, cache: cache);
            }

            // Original implementation
            if (true)
            {
                // destPackage.Save();
                MilanLog.Information("Recompiling ported classes", customPrefix: logCategory);
                UnrealScriptOptionsPackage usop = new UnrealScriptOptionsPackage()
                {
                    Cache = cache,
                    CustomFileResolver = MilanShared.LE3PackageResolver,
                    MissingObjectResolver = MilanShared.MissingObjectResolver
                };
                FileLib lib = new FileLib(destPackage);
                if (!lib.Initialize(usop))
                {
                    MilanShared.LogFailedFileLibInit(lib, $"Failed to initialize FileLib for recompilation of classes in {destPackage.FileNameNoExtension}", logCategory);
                }
                foreach (var f in rop.CrossPackageMap.Values.OfType<ExportEntry>().Where(x => x.IsClass))
                {
                    // Recompile all ported classes so vtables are updated
                    try
                    {
                        //var sourceObj = rop.CrossPackageMap.FirstOrDefault(x => x.Value == f).Key as ExportEntry;
                        //(_, string text) = UnrealScriptCompiler.DecompileExport(sourceObj, lib, cache);
                        if (!PostPortingClassOverrides.TryGetValue(f.ObjectName, out var text))
                        {
                            // Does it exist on disk?
                            lock (PostPortingClassOverrides)
                            {
                                if (File.Exists(Path.Combine(PostPortingClassOverrideFolder, $"{f.ObjectName}.uc")))
                                {
                                    MilanLog.Information($"  Recompiling {f.ObjectName} with Milan override", customPrefix: logCategory);
                                    text = File.ReadAllText(Path.Combine(PostPortingClassOverrideFolder, $"{f.ObjectName}.uc"));
                                    PostPortingClassOverrides[f.ObjectName] = text;
                                }
                                else
                                {
                                    MilanLog.Information($"  Recompiling {f.ObjectName}", customPrefix: logCategory);
                                }
                            }

                            // Use decomp
                            (_, text) = UnrealScriptCompiler.DecompileExport(f, lib, usop);
                        }
                        UnrealScriptCompiler.CompileClass(destPackage, text, lib, usop, f);
                    }
                    catch (Exception e)
                    {
                        MilanLog.Exception(e, "  Error recompiling function:");
                    }
                }

                foreach (var clsIFP in ClassesToDoubleRecompile)
                {
                    var classX = destPackage.FindExport(clsIFP);
                    if (classX == null)
                        continue;

                    MilanLog.Information($"  Double recompiling {classX.ObjectName}", customPrefix: logCategory);
                    (_, string text) = UnrealScriptCompiler.DecompileExport(classX, lib, usop);
                    UnrealScriptCompiler.CompileClass(destPackage, text, lib, usop, classX);
                }
            }

            MilanLog.Information("Saving package", customPrefix: logCategory);
            destPackage.Save();
            MilanShared.RefreshMilanFiles = true;
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

        public static void AddGlobalCachedPackage(IMEPackage package)
        {
            if (package.Game == MEGame.LE3)
            {
                if (le3GlobalCache == null) InitGlobalPackages(MEGame.LE3);
                le3GlobalCache.InsertIntoCache(package);
            }
            else
            {
                if (me3GlobalCache == null) InitGlobalPackages(MEGame.ME3);
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
            lock (_globalDirEnumerator)
            {
                if (RefreshMilanFiles)
                {
                    MilanFiles = Directory.GetFiles(BaseBuildSettings.OutputModPath, "*", SearchOption.AllDirectories);
                    RefreshMilanFiles = false;
                }

                matching = MilanFiles.FirstOrDefault(x => Path.GetFileName(x).CaseInsensitiveEquals(filename));
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

                    var package = MEPackageHandler.OpenMEPackage(matching);
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
            // We should 
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
            MilanPackageCache cache = new MilanPackageCache();
            if (game == MEGame.ME3)
            {
                cache.InsertIntoCache(MEPackageHandler.OpenMEPackages(EntryImporter
                    .FilesSafeToImportFrom(MEGame.ME3)
                    .Select(x => Path.Combine(MEDirectories.GetCookedPath(MEGame.ME3), x))));
                cache.InsertIntoCache(GetME3Package("Startup_DLC_CON_MP2_INT.pcc")); // Add DLC startups
                cache.InsertIntoCache(GetME3Package("Startup_DLC_CON_MP3_INT.pcc"));
                cache.InsertIntoCache(GetME3Package("Startup_DLC_CON_MP4_INT.pcc"));
            }
            else
            {
                cache.InsertIntoCache(MEPackageHandler.OpenMEPackages(EntryImporter.FilesSafeToImportFrom(MEGame.LE3).Select(x => Path.Combine(MEDirectories.GetCookedPath(MEGame.LE3), x))));
            }

            return cache;
        }

        private const string LOG_CATEGORY_MOR = @"MILAN-MissingObjectResolver";

        public static PackageCache LE3MissingObjectCache = TieredPackageCache.GetGlobalPackageCache(MEGame.LE3).ChainNewCache();
        public static PackageCache ME3MissingObjectCache = TieredPackageCache.GetGlobalPackageCache(MEGame.ME3).ChainNewCache();

        public static IEntry MissingObjectResolverExportsAsImports(IMEPackage package, string ifp)
        {
            return MissingObjectResolver(package, ifp, true);
        }

        public static IEntry MissingObjectResolver(IMEPackage package, string ifp)
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
                            MilanLog.Warning($"  Using ME3 donor object {ifp} from {possibleDonor}", customPrefix: LOG_CATEGORY_MOR);
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
                        MilanLog.Information($"  Using donor object {ifp} from {possibleDonor}", customPrefix: LOG_CATEGORY_MOR);
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


        private static IEntry PortDonorIntoPackage(PackageCache globalCache, IEntry donorEntry, IMEPackage package, string logCategory, bool portExportsAsImports)
        {
            if (donorEntry is ImportEntry donorImport)
            {
                // uh
                Debug.WriteLine("Uh oh");
            }
            else if (donorEntry is ExportEntry donorExport)
            {
                if (EntryImporter.IsSafeToImportFrom(donorEntry.FileRef.FilePath, MEGame.LE3, package.FilePath))
                {
                    var existingImport = package.FindImport(donorEntry.MemoryFullPath, donorEntry.ClassName);
                    if (existingImport != null)
                    {
                        // Use existing import to prevent duplicates.
                        return existingImport;
                    }

                    // Create parents
                    MilanLog.Information($"    Porting as import", customPrefix: logCategory);
                    var parent = EntryExporter.PortParents(donorEntry, package, true);
                    ImportEntry imp = new ImportEntry(donorExport, parent.UIndex, package);
                    package.AddImport(imp);
                    return imp; // Adding as import
                }
                if (donorExport.FileRef.FileNameNoExtension == "SFXGame")
                    Debugger.Break();
                MilanLog.Information($"    Porting from {donorExport.FileRef.FileNameNoExtension}", customPrefix: logCategory);
                var rop = new RelinkerOptionsPackage()
                {
                    Cache = globalCache,
                    TargetGameDonorDB = MilanShared.LE3ObjectDB,
                    DestinationCustomImportFileResolver = MilanShared.LE3PackageResolver,
                    PortImportsMemorySafe = true, // MPCommon might try to reference BIO_COMMON which we do not want.
                    PortExportsAsImportsWhenPossible = portExportsAsImports
                };
                var errors = EntryExporter.ExportExportToPackage(donorExport, package, out var newExp, globalCache, customROP: rop);
                return newExp;
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
            MilanLog.Error("COMPILATION OF ENEMY PAWN FAILED: ", customPrefix: logCategory);
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
    }
}
