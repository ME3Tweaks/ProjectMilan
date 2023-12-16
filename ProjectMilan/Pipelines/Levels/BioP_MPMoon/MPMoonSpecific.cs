using ProjectMilan.Utility;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Unreal;

namespace ProjectMilan.Pipelines.Levels.BioP_MPMoon
{
    internal class MPMoonSpecific
    {
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
