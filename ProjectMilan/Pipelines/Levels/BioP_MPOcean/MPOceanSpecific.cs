using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Unreal;

namespace ProjectMilan.Pipelines.Levels.BioP_MPOcean
{
    internal class MPOceanSpecific : LevelSpecificFixesBase
    {
        // Map has some extra levels we don't want to include in the lighting bake.
        public override string[] IgnoredLightingLevels => [

        ];

        public override void PostCorrect(LevelSpecificPipeline pipeline)
        {
            foreach (var package in pipeline.LE3Packages.Values)
            {
                if (package.FileNameNoExtension != "BioA_MPOcean_100")
                {
                    continue;
                }

                // Look for crates where the material order has changed on the mesh
                foreach (var exp in package.Exports)
                {
                    if (exp.ClassName != "StaticMeshComponent")
                    {
                        continue;
                    }
                    var sm = exp.GetProperty<ObjectProperty>("StaticMesh")?.ResolveToEntry(package);
                    if (sm == null)
                    {
                        continue;
                    }
                    if (sm.InstancedFullPath != "bioapl_cra_cratecargo01_xl.CrateCargo01_XL")
                    {
                        // Don't care
                        continue;
                    }

                    // Get material overrides
                    var materials = exp.GetProperty<ArrayProperty<ObjectProperty>>("Materials");
                    if (materials == null || materials.Count != 2 ||
                        materials[0].ResolveToEntry(package)?.InstancedFullPath != "BioT_MPOcean.CrateCargo01_Main_INST2" ||
                        materials[1].ResolveToEntry(package)?.InstancedFullPath != "BioT_MPOcean.CrateCargo02_Side_INST2")
                    {
                        // Doesn't use the overrides we need to fix
                        continue;
                    }

                    // Fix material orders changing between ME3 and LE3 for this mesh
                    var matList = new ArrayProperty<ObjectProperty>("Materials");
                    matList.Add(new ObjectProperty(0)); // Null
                    matList.Add(new ObjectProperty(materials[0].Value)); // Main
                    matList.Add(new ObjectProperty(materials[1].Value)); // Side
                    exp.WriteProperty(matList);
                }
            }
        }
    }
}
