using System.Diagnostics;
using LegendaryExplorerCore.GameFilesystem;
using LegendaryExplorerCore.Helpers;
using LegendaryExplorerCore.Misc;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Packages.CloningImportingAndRelinking;
using LegendaryExplorerCore.Unreal;
using LegendaryExplorerCore.Unreal.ObjectInfo;

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

        /// <summary>
        /// Maps files in a DLC to their respective DLC, using the TOC file of the DLC
        /// </summary>
        private static Dictionary<string, DLCPackage> ME3DLCFileMap;

        /// <summary>
        /// Fetches an ME3 package - from disk or SFAR
        /// </summary>
        /// <param name="sourceFileName"></param>
        public static IMEPackage GetME3Package(string sourceFileName)
        {
            bool forceUseDLC = sourceFileName == "MPLobby.pcc"; // Do not use basegame version.

            if (!forceUseDLC && MELoadedFiles.TryGetHighestMountedFile(MEGame.ME3, sourceFileName, out var filePath))
            {
                return MEPackageHandler.OpenMEPackage(filePath);
            }
            else
            {
                // May be in SFAR
                if (ME3DLCFileMap == null)
                    LoadME3DLCTOCs();
                if (ME3DLCFileMap.TryGetValue(sourceFileName, out var dlcPackage))
                {
                    return MEPackageHandler.OpenMEPackageFromStream(dlcPackage.DecompressEntry(dlcPackage.FindFileEntry(sourceFileName)), sourceFileName);
                }
                if (MELoadedFiles.TryGetHighestMountedFile(MEGame.ME3, sourceFileName, out var filePath2) && filePath2.Contains("\\DLC_"))
                {
                    // Unpacked DLC
                    return MEPackageHandler.OpenMEPackage(filePath2);
                }

                MilanLog.Warning($"Could not locate ME3 package file: {sourceFileName}");
            }

            return null;
        }

        private static void LoadME3DLCTOCs()
        {
            MilanLog.Information(@"Loading ME3 DLC TOC files for lookups");
            ME3DLCFileMap = new Dictionary<string, DLCPackage>();
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
            if (MELoadedFiles.TryGetHighestMountedFile(MEGame.LE3, packageFileName, out var filePath))
            {
                return MEPackageHandler.OpenMEPackage(filePath);
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
            if (MELoadedFiles.TryGetHighestMountedFile(MEGame.ME3, sourceFileName, out var filePath))
            {
                return null; // Found on disk
            }
            else
            {
                // May be in SFAR
                if (ME3DLCFileMap == null)
                    LoadME3DLCTOCs();
                if (ME3DLCFileMap.TryGetValue(sourceFileName, out var dlcPackage))
                {
                    MilanLog.Information($"Extracting {sourceFileName} from {dlcPackage.FileName}");
                    return dlcPackage.DecompressEntry(dlcPackage.FindFileEntry(sourceFileName));
                }

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

                using var outF = File.OpenWrite(Path.Combine(fakeCooked, tfcN));
                data.CopyTo(outF);
            }
        }
    }
}
