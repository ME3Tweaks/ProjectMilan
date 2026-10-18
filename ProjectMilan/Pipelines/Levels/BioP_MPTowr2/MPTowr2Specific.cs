using LegendaryExplorerCore.Gammtek.Extensions;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Packages.CloningImportingAndRelinking;
using LegendaryExplorerCore.Unreal;
using ProjectMilanCore;

namespace ProjectMilan.Pipelines.Levels.BioP_MPTowr2
{
    /// <summary>
    /// Map-specific lighting and volumetric-plane corrections for Hazard Giant.
    /// </summary>
    internal class MPTowr2Specific : LevelSpecificFixesBase
    {
        // Independent absolute brightness values for the broad outdoor lighting. Rebuild and rebake
        // MPTowr2 after tuning these; cached lightmaps retain the previous lighting.
        // Original ME3 values: directional = 1, PointLight_LC_105 = 0.1, PointLight_LC_33 = 0.03.
        private const float DirectionalLightBrightness = 0.05f;
        private const float PointLight105Brightness = 0.02f;
        private const float PointLight33Brightness = 0.006f;

        private const string LightingPackageName = "BioA_MPTowr2_200";
        private const string LightCollectionPath = "TheWorld.PersistentLevel.StaticLightCollectionActor_44";
        private static readonly (string Name, string ClassName, float Brightness)[] LightingTargets =
        [
            ("DirectionalLight_LC_1", "DirectionalLightComponent", DirectionalLightBrightness),
            ("PointLight_LC_105", "PointLightComponent", PointLight105Brightness),
            ("PointLight_LC_33", "PointLightComponent", PointLight33Brightness)
        ];

        public override void PreCorrect(LevelSpecificPipeline pipeline)
        {
            if (!pipeline.ME3Packages.TryGetValue(LightingPackageName, out var package))
                throw new InvalidOperationException($"MPTowr2 lighting: required package {LightingPackageName} was not loaded.");

            ApplyLightBrightness(pipeline, path => package.FindExport(path));
        }

        public override void CorrectUDKExport(LevelSpecificPipeline pipeline, IMEPackage udk)
        {
            if (!udk.FileNameNoExtension.Equals(LightingPackageName, StringComparison.OrdinalIgnoreCase))
                return;

            // Standalone bakes start from preserved UDK maps, bypassing the ME3 PreCorrect.
            // Exported light actors retain their original component paths in Tag.Name.
            var placedActors = udk.GetLevelBinary().Actors.ToHashSet();
            var actors = udk.Exports.Where(actor => placedActors.Contains(actor.UIndex)).ToArray();
            ApplyLightBrightness(pipeline, path =>
            {
                var matches = actors.Where(actor => actor.GetProperty<NameProperty>("Tag")?.Value.Name == path).ToArray();
                if (matches.Length != 1)
                    throw new InvalidOperationException($"MPTowr2 lighting: expected one UDK light tagged {path}, found {matches.Length}.");
                var componentIndex = matches[0].GetProperty<ObjectProperty>("LightComponent")?.Value ?? 0;
                return componentIndex > 0 ? udk.GetUExport(componentIndex) : null;
            });
        }

        private void ApplyLightBrightness(LevelSpecificPipeline pipeline, Func<string, ExportEntry?> resolveComponent)
        {
            // Exact paths preserve fixture lights, bloom directionals, and the animated blast light.
            // Resolve and validate all three targets before making any changes.
            var lights = new List<(ExportEntry Component, float Brightness)>();
            foreach (var target in LightingTargets)
            {
                var path = $"{LightCollectionPath}.{target.Name}";
                var component = resolveComponent(path);
                if (component == null || component.ClassName != target.ClassName)
                    throw new InvalidOperationException($"MPTowr2 lighting: expected {target.ClassName} for {LightingPackageName}.{path}.");
                if (!float.IsFinite(target.Brightness) || target.Brightness < 0f)
                    throw new InvalidOperationException($"MPTowr2 lighting: brightness for {target.Name} must be finite and nonnegative.");
                lights.Add((component, target.Brightness));
            }

            foreach (var (component, brightness) in lights)
            {
                component.WriteProperty(new FloatProperty(brightness, "Brightness"));
                MilanLog.Information($"MPTowr2 lighting: {component.InstancedFullPath} Brightness={brightness}", customPrefix: pipeline.LogCategory);
            }
        }

        // Replace the volumetric plane whose original ME3 geometry has a visible box corner.
        public override void PostCorrect(LevelSpecificPipeline pipeline)
        {
            var bioa_200 = pipeline.LE3Packages["BioA_MPTowr2_200"];
            var volumetrixFixF = Path.Combine(MilanShared.PipelineRoot, "Levels", "BioP_MPTowr2", "VolumetricPlaneFix.pcc");
            using var volumetricFixP = MEPackageHandler.OpenMEPackage(volumetrixFixF);

            EntryExporter.ExportExportToPackage(volumetricFixP.FindExport("BioG_Volumetric.Meshes.Volumetric_Plane_45Deg_Towr2"), bioa_200, out var newVolumetricFog, pipeline.Cache);

            var smcToFix = bioa_200.FindExport("TheWorld.PersistentLevel.StaticMeshCollectionActor_188.StaticMeshActor_SMC_1407");
            smcToFix.WriteProperty(new ObjectProperty(newVolumetricFog, "StaticMesh"));

            UseFlashlightsForLevel(pipeline);
        }
    }
}
