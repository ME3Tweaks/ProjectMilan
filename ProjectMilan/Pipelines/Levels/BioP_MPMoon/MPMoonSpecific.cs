using LegendaryExplorerCore.Gammtek.Extensions;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Unreal;
using LegendaryExplorerCore.Unreal.BinaryConverters;
using ProjectMilanCore;

namespace ProjectMilan.Pipelines.Levels.BioP_MPMoon
{
    internal class MPMoonSpecific : LevelSpecificFixesBase
    {
        // Map has some extra levels we don't want to include in the lighting bake.
        public override string[] IgnoredLightingLevels => [
            "BioA_MPMoon_Bas1",
            "BioA_MPMoon_bsp",
        ];


        // Condor ammo boxes don't have the correct respawn time set which makes it SUCK to get ammo
        // Fix crate UV
        public override void PreCorrect(LevelSpecificPipeline pipeline)
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

                if (package.FileNameNoExtension == "BioA_MPMoon_100")
                {
                    // Rename crate mesh so it doens't take LE3's donor, it has totally different UV
                    // and we don't want to have to remap the atlas
                    package.FindExport("bioapl_cra_crate01.Crate01_M.Crate01_M").ObjectName = "Crate01_M_ME3";
                }
            }
        }

        // DebrisShip01_C's 4th material is empty after porting and needs to be set to the same as the third slot
        private const string DebrisShipMeshIFP = "BioApl_Ind_DebrisShip01.Meshes.DebrisShip01_C";

        public override void PostCorrect(LevelSpecificPipeline pipeline)
        {
            foreach (var package in pipeline.LE3Packages.Values)
            {
                foreach (var export in package.Exports)
                {
                    if (export.ClassName != "StaticMesh" || export.InstancedFullPath != DebrisShipMeshIFP)
                        continue;

                    var mesh = ObjectBinary.From<StaticMesh>(export);
                    bool changed = false;
                    foreach (var lod in mesh.LODModels)
                    {
                        if (lod.Elements.Length < 4)
                            continue;

                        if (lod.Elements[3].Material == 0 && lod.Elements[2].Material != 0)
                        {
                            lod.Elements[3].Material = lod.Elements[2].Material;
                            changed = true;
                        }
                    }

                    if (changed)
                    {
                        MilanLog.Information($"Fixing empty 4th material slot on {export.InstancedFullPath} in {package.FileNameNoExtension}", customPrefix: pipeline.LogCategory);
                        export.WriteBinary(mesh);
                    }
                }
            }
        }
    }
}
