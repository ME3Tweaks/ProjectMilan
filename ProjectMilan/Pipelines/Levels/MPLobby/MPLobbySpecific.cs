using LegendaryExplorerCore.Gammtek.Extensions;
using LegendaryExplorerCore.Unreal;
using LegendaryExplorerCore.Packages;

namespace ProjectMilan.Pipelines.Levels.MPLobby
{ 
    internal class MPLobbySpecific : LevelSpecificFixesBase
    {
        public override void PreCorrect(LevelSpecificPipeline pipeline)
        {
            var biop = pipeline.ME3BioP;
            var bin = biop.GetLevelBinary();

            for (int i = 0; i < bin.Actors.Count; i++)
            {
                if (biop.TryGetUExport(bin.Actors[i], out var actor))
                {
                    if (actor.ClassName == "PrefabInstance")
                        bin.Actors[i] = 0; // Do not port PrefabInstance currently
                }
            }

            biop.GetLevel().WriteBinary(bin);

            // 10/17/2026 - Force weapon bench weapons to always update their light enviornment so it doesn't spawn black on race conditions.
            // Likely makes worse perf but it's only for one weapon on the bench.
            // There is only one copy of the weapon bench in LMP so this is fine to edit directly without renames.
            biop.FindExport("GUI_SF_WeaponBench.Prefab.WeaponBench.WeaponBench_Arc11.BioLightEnv0").WriteProperty(new BoolProperty(true, "bRequiresNonLatentUpdates"));
        }
    }
}
