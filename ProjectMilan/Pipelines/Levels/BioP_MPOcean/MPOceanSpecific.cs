using LegendaryExplorerCore.Gammtek.Extensions;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Unreal;

namespace ProjectMilan.Pipelines.Levels.BioP_MPOcean
{
    internal class MPOceanSpecific
    {
        // Map has some extra levels we don't want to include in the lighting bake.
        public static string[] IgnoredLightingLevels => [
            "BioA_MPOcean_100"
        ];


        // Condor ammo boxes don't have the correct respawn time set which makes it SUCK to get ammo
        public static void PreCorrect(LevelSpecificPipeline pipeline)
        {

        }
    }
}
