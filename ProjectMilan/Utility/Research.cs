using LegendaryExplorerCore.Packages;
using ProjectMilan.Pipelines.Levels;
using LegendaryExplorerCore.GameFilesystem;

namespace ProjectMilan.Utility
{
    /// <summary>
    /// Contains utility research methods. It's going to be LEX experiments all over again.
    /// </summary>
    internal static class Research
    {
#if DEBUG
        /// <summary>
        /// Calculates texture to instances map for a folder
        /// </summary>
        public static void TestTextureToInstancesMap()
        {
            // Runs on BioP_MPGeth folder in game.
            var dir = Path.Combine(LE3Directory.DLCPath, @"DLC_MOD_ProjectMilan\CookedPCConsole\Levels\BioP_MPMoon");
            foreach (var pcc in Directory.GetFiles(dir))
            {
                var package = MEPackageHandler.OpenMEPackage(pcc);
                LevelShared.CalculateTextureToInstancesMap(package, TieredPackageCache.GetGlobalPackageCache(MEGame.LE3));
                //package.Save();
            }
        }
#endif
    }
}
