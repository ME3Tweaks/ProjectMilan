using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.GameFilesystem;
using LegendaryExplorerCore.Pathing;
using LegendaryExplorerCore.Unreal.BinaryConverters;
using LegendaryExplorerCore.Helpers;
using LegendaryExplorerCore.Misc;
using LegendaryExplorerCore.Misc.ME3Tweaks;
using LegendaryExplorerCore.Unreal.ObjectInfo;
using Newtonsoft.Json;
using ProjectMilan.MilanUDK;
using ProjectMilan.Pipelines.StaticLighting;

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
                LevelTools.CalculateTextureToInstancesMap(package, TieredPackageCache.GetGlobalPackageCache(MEGame.LE3));
                //package.Save();
            }
        }

        public static void DumpRefShaderNames()
        {
            var shaderCacheF = @"S:\SteamLibrary\steamapps\common\Mass Effect Legendary Edition\Game\ME3\BioGame\CookedPCConsole\RefShaderCache-PC-D3D-SM5.upk";
            MilanLog.Information("Loading RefShaderCache");
            var shaderCacheP = MEPackageHandler.OpenMEPackage(shaderCacheF);
            MilanLog.Information("Parsing RefShaderCache");
            var shaderCache = ObjectBinary.From<ShaderCache>(shaderCacheP.Exports.FirstOrDefault());
            MilanLog.Information("Dumping materials");
            SortedSet<string> matNames = new SortedSet<string>();
            foreach (var sm in shaderCache.MaterialShaderMaps)
            {
                matNames.Add($"{sm.Value.FriendlyName} {sm.Value.ID}");
            }

            var outP = @"C:\users\public\refshadermaterials.txt";
            File.WriteAllLines(outP, matNames);
        }

        public static void LightingBake()
        {
            UDKSetup.SetupUDK();
            using var master = MEPackageHandler.OpenMEPackage(@"Z:\ModLibrary\LE3\Project Milan\DLC_MOD_ProjectMilan\CookedPCConsole\Levels\BioP_MPMoon\BioP_MPMoon.pcc");
            StaticLightingExport.ExportLevelToUDK(master);
        }

        private static IMEPackage GenerateLevelMaster(string basePath, string level)
        {
            var path = Path.Combine(basePath, $"BioP_UDKLighting_{level.UpperFirst()}.pcc");
            MEPackageHandler.CreateEmptyLevel(path, MEGame.LE3);
            using var destPackage = (MEPackage)MEPackageHandler.OpenMEPackage(path);

            destPackage.AdditionalPackagesToCook.AddRange(new List<string>([
                "BioP_CitHub",
                "BioA_CitHub",
                "BioA_CitHub_Temple",
                "BioA_CitHub_Temple_Vista",
            ]));

            destPackage.Save();
            return destPackage;
        }
#endif
    }
}
