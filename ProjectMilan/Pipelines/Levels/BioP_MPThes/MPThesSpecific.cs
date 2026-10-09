using LegendaryExplorerCore.Gammtek.Extensions;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Unreal;

namespace ProjectMilan.Pipelines.Levels.BioP_MPOcean
{
    internal class MPThesSpecific
    {
        // Map has some extra levels we don't want to include in the lighting bake.
        public static string[] IgnoredLightingLevels => [
            "BioA_MPThes_100",
            "BioA_MPThes_101"
        ];


        // Condor ammo boxes don't have the correct respawn time set which makes it SUCK to get ammo
        public static void PreCorrect(LevelSpecificPipeline pipeline)
        {

        }

        // The waving banners (BioT_MPThes.Waving_Flag/Waving_Flag2) amplify this normal map 5x; ME3 only ever had its
        // 32x32 mips, and LE3's 2048x2048 copy turns the banners into dark streaks. See TextureMipCap.
        private const string BannerNormalIFP = "BioT_Thessia.Env_Textures.Gravel_Norm";

        public static void PostCorrect(LevelSpecificPipeline pipeline)
        {
            foreach (var package in pipeline.LE3Packages.Values)
            {
                TextureMipCap.Apply(package, BannerNormalIFP, 32, pipeline.LogCategory);
            }
        }
    }
}
