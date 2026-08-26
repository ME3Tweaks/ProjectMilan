using LegendaryExplorerCore.Gammtek.Extensions;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Unreal;

namespace ProjectMilan.Pipelines.Levels.BioP_MPMoon
{
    internal class MPMoonSpecific
    {
        // Map has some extra levels we don't want to include in the lighting bake.
        public static string[] IgnoredLightingLevels => [
            "BioA_MPMoon_Bas1",
            "BioA_MPMoon_bsp",
        ];


        // Condor ammo boxes don't have the correct respawn time set which makes it SUCK to get ammo
        public static void PreCorrect(LevelSpecificPipeline pipeline)
        {
            foreach (var package in pipeline.ME3Packages.Values)
            {
                var bin = package.GetLevelBinary();

                for (int i = 0; i < bin.Actors.Count; i++)
                {
                    if (package.TryGetUExport(bin.Actors[i], out var actor))
                    {
                        if (actor.ClassName == "SFXAmmoContainer")
                        {
                            actor.WriteProperty(new FloatProperty(3.0f, "RespawnTime"));
                        }
                    }
                }

                package.GetLevel().WriteBinary(bin);
            }
        }
    }
}
