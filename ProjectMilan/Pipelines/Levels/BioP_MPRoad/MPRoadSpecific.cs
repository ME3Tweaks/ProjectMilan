using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Unreal;
using ProjectMilanCore;

namespace ProjectMilan.Pipelines.Levels.BioP_MPRoad
{
    internal class MPRoadSpecific : LevelSpecificFixesBase
    {
        // London's two sky domes are the only ones in the mod left casting shadows. UE3 Lightmass culled their
        // inward-facing triangles from sun shadow rays, UE4 Lightmass doesn't: the domes shadow the whole map from
        // its directional light, and the streets (the spawn area most of all) bake at about an eighth of ME3's light.
        private const string SkyDomeMesh = "Matte_Dome_02";

        public override void PostCorrect(LevelSpecificPipeline pipeline)
        {
            foreach (var package in pipeline.LE3Packages.Values)
            {
                foreach (var component in package.Exports.Where(x => !x.IsDefaultObject && x.ClassName == "StaticMeshComponent"))
                {
                    if (component.GetProperty<ObjectProperty>("StaticMesh")?.ResolveToEntry(package)?.ObjectName.Instanced != SkyDomeMesh)
                    {
                        continue;
                    }

                    component.WriteProperty(new BoolProperty(false, "CastShadow"));
                    MilanLog.Information($"  Disabled shadow casting on sky dome {component.InstancedFullPath} in {package.FileNameNoExtension}", customPrefix: pipeline.LogCategory);
                }
            }
        }
    }
}
