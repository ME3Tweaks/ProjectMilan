using LegendaryExplorerCore.Gammtek.Extensions;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Packages.CloningImportingAndRelinking;
using LegendaryExplorerCore.Unreal;
using LegendaryExplorerCore.Unreal.ObjectInfo;
using ProjectMilan.Pipelines.StaticLighting;
using System.Drawing;

namespace ProjectMilan.Pipelines.Levels.BioP_MPThes
{
    internal class MPThesSpecific : LevelSpecificFixesBase
    {
        // Map has some extra levels we don't want to include in the lighting bake.
        public override string[] IgnoredLightingLevels => [
            "BioA_MPThes_100",
            "BioA_MPThes_101",
            // Second stage bake
            "BioA_MPThes_Vista2"
        ];

        /// <summary>
        /// Use a custom environment color so areas don't just turn black.
        /// </summary>
        public static WorldLightmassSettings WorldLighting => new()
        {
            EnvironmentColor = Color.FromArgb(255, 70, 85, 105),
            EnvironmentIntensity = 0.25f,
        };

        // The waving banners (BioT_MPThes.Waving_Flag/Waving_Flag2) amplify this normal map 5x; ME3 only ever had its
        // 32x32 mips, and LE3's 2048x2048 copy turns the banners into dark streaks. See TextureMipCap.
        private const string BannerNormalIFP = "BioT_Thessia.Env_Textures.Gravel_Norm";

        // The tall atrium glass panes. Glass_Master feeds its cubemap into DiffuseColor at ~46x (Cubemap_Color_Tint), so
        // any light on them shows as a bright cube pattern. ME3's bake listed the dynamic sun (DirectionalLightToggleable_1)
        // in IrrelevantLights on every pane; the UDK bake gives four of them sunlit slivers and a shadow map instead.
        private const string AtriumGlassMeshIFP = "bios_thessia_monastery.WindowEnd_Window01";

        public override bool KeepPortedLighting(ExportEntry component) =>
            component.IsA("StaticMeshComponent") &&
            component.GetProperty<ObjectProperty>("StaticMesh") is { Value: not 0 } mesh &&
            component.FileRef.GetEntry(mesh.Value).InstancedFullPath == AtriumGlassMeshIFP;

        public override void PreCorrect(LevelSpecificPipeline pipeline)
        {
            FixCrackedGlassUV(pipeline);
        }

        private void FixCrackedGlassUV(LevelSpecificPipeline pipeline)
        {
            // Clone the wall mesh, UVFix pass will chnage its UVs to look proper
            var ptf = pipeline.ME3Packages["BioA_MPThes_110"];

            var originalMesh = ptf.FindExport("bios_thessia_monastery.Walls.Wall01_6m", "StaticMesh");
            var newTree = EntryCloner.CloneTree(originalMesh);
            newTree.ObjectName = "Wall01_6m_MPThesGlass";

            // Fix the usages. There are 4 windows, each window seems to have 2 meshes, probably one for each side
            string[] smcs = [
                "TheWorld.PersistentLevel.StaticMeshCollectionActor_45.StaticMeshActor_SMC_1506", // W1
                "TheWorld.PersistentLevel.StaticMeshCollectionActor_45.StaticMeshActor_SMC_1601",
                "TheWorld.PersistentLevel.StaticMeshCollectionActor_45.StaticMeshActor_SMC_1730", // W2
                "TheWorld.PersistentLevel.StaticMeshCollectionActor_45.StaticMeshActor_SMC_1731",
                "TheWorld.PersistentLevel.StaticMeshCollectionActor_45.StaticMeshActor_SMC_104", // W3
                "TheWorld.PersistentLevel.StaticMeshCollectionActor_45.StaticMeshActor_SMC_1461",
                "TheWorld.PersistentLevel.StaticMeshCollectionActor_45.StaticMeshActor_SMC_1723", // W4
                "TheWorld.PersistentLevel.StaticMeshCollectionActor_45.StaticMeshActor_SMC_1729"
            ];


            // Change meshes to point to the clone
            foreach (var smcp in smcs)
            {
                var smc = ptf.FindExport(smcp, "StaticMeshComponent");
                smc.WriteProperty(new ObjectProperty(newTree, "StaticMesh"));
            }
        }

        public override void PostCorrect(LevelSpecificPipeline pipeline)
        {
            foreach (var package in pipeline.LE3Packages.Values)
            {
                TextureMipCap.Apply(package, BannerNormalIFP, 32, pipeline.LogCategory);
            }
        }
    }
}
