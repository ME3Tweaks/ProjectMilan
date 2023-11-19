using System.Diagnostics;
using LegendaryExplorerCore.GameFilesystem;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Packages.CloningImportingAndRelinking;
using LegendaryExplorerCore.Unreal;

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
                else
                {
                    MilanLog.Warning($"Could not locate ME3 package file: {sourceFileName}");
                }

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

        public static string GetSharedLooseClassesPath()
        {
            return Path.Combine(MilanShared.PipelineRoot, @"Shared", @"ExtraClasses", @"Loose");
        }
    }
}
