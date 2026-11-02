using LegendaryExplorerCore.Gammtek.Extensions;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Packages.CloningImportingAndRelinking;
using LegendaryExplorerCore.Unreal;
using ProjectMilan.Pipelines.StaticLighting;
using ProjectMilanCore;

namespace ProjectMilan.Pipelines.Levels.BioP_MPTowr2
{
    /// <summary>
    /// Map-specific lighting and volumetric-plane corrections for Hazard Giant.
    /// </summary>
    internal class MPTowr2Specific : LevelSpecificFixesBase
    {
        // Independent absolute brightness values for the broad outdoor lighting.
        // Original ME3 values: directional = 1, PointLight_LC_105 = 0.1, PointLight_LC_33 = 0.03.
        private const float DirectionalLightBrightness = 0.05f;
        private const float PointLight105Brightness = 0.02f;
        private const float PointLight33Brightness = 0.006f;

        // A dark map for flashlights (tested 2026-10-17). The point/spot lights are dimmed and shrunk by the same factor in
        // the bake and on the light components that light characters, so characters don't stand out from the lightmaps
        private const float LocalLightScale = 0.65f;

        /// <summary>
        /// Reduce lighting bounce and reduce light radius/brightness so the level gets significantly darker
        /// </summary>
        public static UE4LightmassSettings BakeTuning => new()
        {
            DiffuseBoostScale = 0.2f,
            IndirectLightingBounces = 1,
            LocalLightBrightnessScale = LocalLightScale,
            LocalLightRadiusScale = LocalLightScale,
        };

        /// <summary>
        /// How brightly lights light characters, to match <see cref="BakeTuning"/>: point/spot lights as in the bake, their
        /// light-environment bounce cut like the bake's (x0.2), and the six character-only directional fill lights halved.
        /// </summary>
        private static readonly CharacterLightingTuning CharacterLighting = new(LocalLightScale: LocalLightScale, BouncedLightScale: 0.2f, CharacterLightScale: 0.5f);

        private const string LightingPackageName = "BioA_MPTowr2_200";
        private const string LightCollectionPath = "TheWorld.PersistentLevel.StaticLightCollectionActor_44";
        private static readonly (string Name, string ClassName, float Brightness)[] LightingTargets =
        [
            ("DirectionalLight_LC_1", "DirectionalLightComponent", DirectionalLightBrightness),
            ("PointLight_LC_105", "PointLightComponent", PointLight105Brightness),
            ("PointLight_LC_33", "PointLightComponent", PointLight33Brightness)
        ];

        // These need StaticLighting channels enabled or flashlights don't affect them
        // Why does dynamic lights need static? No idea
        private static readonly string[] StructuralLightingTargets =
        [
            "TheWorld.PersistentLevel.StaticMeshActor_495.StaticMeshComponent_317",
            "TheWorld.PersistentLevel.StaticMeshActor_513.StaticMeshComponent_317",
            "TheWorld.PersistentLevel.StaticMeshActor_550.StaticMeshComponent_317",
            "TheWorld.PersistentLevel.StaticMeshActor_898.StaticMeshComponent_317",
            "TheWorld.PersistentLevel.StaticMeshCollectionActor_183.StaticMeshActor_SMC_470",
            "TheWorld.PersistentLevel.StaticMeshCollectionActor_183.StaticMeshActor_SMC_511",
            "TheWorld.PersistentLevel.StaticMeshCollectionActor_184.StaticMeshActor_SMC_1229",
            "TheWorld.PersistentLevel.StaticMeshCollectionActor_184.StaticMeshActor_SMC_518",
            "TheWorld.PersistentLevel.StaticMeshCollectionActor_184.StaticMeshActor_SMC_908",
            "TheWorld.PersistentLevel.StaticMeshCollectionActor_186.StaticMeshActor_SMC_1076",
            "TheWorld.PersistentLevel.StaticMeshCollectionActor_186.StaticMeshActor_SMC_1214",
            "TheWorld.PersistentLevel.StaticMeshCollectionActor_186.StaticMeshActor_SMC_1275",
            "TheWorld.PersistentLevel.StaticMeshCollectionActor_186.StaticMeshActor_SMC_1277",
            "TheWorld.PersistentLevel.StaticMeshCollectionActor_186.StaticMeshActor_SMC_1668",
            "TheWorld.PersistentLevel.StaticMeshCollectionActor_186.StaticMeshActor_SMC_1670",
            "TheWorld.PersistentLevel.StaticMeshCollectionActor_186.StaticMeshActor_SMC_1856",
            "TheWorld.PersistentLevel.StaticMeshCollectionActor_186.StaticMeshActor_SMC_358",
            "TheWorld.PersistentLevel.StaticMeshCollectionActor_186.StaticMeshActor_SMC_368",
            "TheWorld.PersistentLevel.StaticMeshCollectionActor_186.StaticMeshActor_SMC_432",
            "TheWorld.PersistentLevel.StaticMeshCollectionActor_186.StaticMeshActor_SMC_458",
            "TheWorld.PersistentLevel.StaticMeshCollectionActor_186.StaticMeshActor_SMC_472",
            "TheWorld.PersistentLevel.StaticMeshCollectionActor_186.StaticMeshActor_SMC_474",
            "TheWorld.PersistentLevel.StaticMeshCollectionActor_186.StaticMeshActor_SMC_508",
            "TheWorld.PersistentLevel.StaticMeshCollectionActor_188.StaticMeshActor_SMC_1227",
            "TheWorld.PersistentLevel.StaticMeshCollectionActor_188.StaticMeshActor_SMC_1503",
            "TheWorld.PersistentLevel.StaticMeshCollectionActor_188.StaticMeshActor_SMC_1673",
            "TheWorld.PersistentLevel.StaticMeshCollectionActor_189.StaticMeshActor_SMC_1026",
            "TheWorld.PersistentLevel.StaticMeshCollectionActor_189.StaticMeshActor_SMC_1223",
            "TheWorld.PersistentLevel.StaticMeshCollectionActor_189.StaticMeshActor_SMC_1235",
            "TheWorld.PersistentLevel.StaticMeshCollectionActor_189.StaticMeshActor_SMC_1286",
            "TheWorld.PersistentLevel.StaticMeshCollectionActor_189.StaticMeshActor_SMC_1904",
            "TheWorld.PersistentLevel.StaticMeshCollectionActor_189.StaticMeshActor_SMC_617",
            "TheWorld.PersistentLevel.StaticMeshCollectionActor_191.StaticMeshActor_SMC_1875",
            "TheWorld.PersistentLevel.StaticMeshCollectionActor_191.StaticMeshActor_SMC_656",
            "TheWorld.PersistentLevel.StaticMeshCollectionActor_191.StaticMeshActor_SMC_925",
            "TheWorld.PersistentLevel.StaticMeshCollectionActor_192.StaticMeshActor_SMC_1049",
            "TheWorld.PersistentLevel.StaticMeshCollectionActor_192.StaticMeshActor_SMC_1375",
            "TheWorld.PersistentLevel.StaticMeshCollectionActor_192.StaticMeshActor_SMC_1408",
            "TheWorld.PersistentLevel.StaticMeshCollectionActor_192.StaticMeshActor_SMC_1413",
            "TheWorld.PersistentLevel.StaticMeshCollectionActor_192.StaticMeshActor_SMC_1414",
            "TheWorld.PersistentLevel.StaticMeshCollectionActor_192.StaticMeshActor_SMC_1415",
            "TheWorld.PersistentLevel.StaticMeshCollectionActor_192.StaticMeshActor_SMC_1416",
            "TheWorld.PersistentLevel.StaticMeshCollectionActor_192.StaticMeshActor_SMC_1417",
            "TheWorld.PersistentLevel.StaticMeshCollectionActor_192.StaticMeshActor_SMC_501",
            "TheWorld.PersistentLevel.StaticMeshCollectionActor_192.StaticMeshActor_SMC_963",
            "TheWorld.PersistentLevel.StaticMeshCollectionActor_196.StaticMeshActor_SMC_1151",
            "TheWorld.PersistentLevel.StaticMeshCollectionActor_196.StaticMeshActor_SMC_1492",
            "TheWorld.PersistentLevel.StaticMeshCollectionActor_196.StaticMeshActor_SMC_1833",
            "TheWorld.PersistentLevel.StaticMeshCollectionActor_196.StaticMeshActor_SMC_1850",
            "TheWorld.PersistentLevel.StaticMeshCollectionActor_196.StaticMeshActor_SMC_1885",
            "TheWorld.PersistentLevel.StaticMeshCollectionActor_196.StaticMeshActor_SMC_1941",
            "TheWorld.PersistentLevel.StaticMeshCollectionActor_196.StaticMeshActor_SMC_49",
            "TheWorld.PersistentLevel.StaticMeshCollectionActor_196.StaticMeshActor_SMC_533",
            "TheWorld.PersistentLevel.StaticMeshCollectionActor_196.StaticMeshActor_SMC_763",
            "TheWorld.PersistentLevel.StaticMeshCollectionActor_196.StaticMeshActor_SMC_775",
            "TheWorld.PersistentLevel.StaticMeshCollectionActor_197.StaticMeshActor_SMC_1677",
            "TheWorld.PersistentLevel.StaticMeshCollectionActor_197.StaticMeshActor_SMC_1791",
            "TheWorld.PersistentLevel.StaticMeshCollectionActor_197.StaticMeshActor_SMC_1832",
            "TheWorld.PersistentLevel.StaticMeshCollectionActor_197.StaticMeshActor_SMC_1909",
            "TheWorld.PersistentLevel.StaticMeshCollectionActor_197.StaticMeshActor_SMC_1910",
            "TheWorld.PersistentLevel.StaticMeshCollectionActor_197.StaticMeshActor_SMC_1911",
            "TheWorld.PersistentLevel.StaticMeshCollectionActor_197.StaticMeshActor_SMC_48",
            "TheWorld.PersistentLevel.StaticMeshCollectionActor_197.StaticMeshActor_SMC_650",
            "TheWorld.PersistentLevel.StaticMeshCollectionActor_197.StaticMeshActor_SMC_747",
            "TheWorld.PersistentLevel.StaticMeshCollectionActor_198.StaticMeshActor_SMC_578",
            "TheWorld.PersistentLevel.StaticMeshCollectionActor_198.StaticMeshActor_SMC_651",
            "TheWorld.PersistentLevel.StaticMeshCollectionActor_198.StaticMeshActor_SMC_746",
            "TheWorld.PersistentLevel.StaticMeshCollectionActor_199.StaticMeshActor_SMC_461",
            "TheWorld.PersistentLevel.StaticMeshCollectionActor_199.StaticMeshActor_SMC_473",
            "TheWorld.PersistentLevel.StaticMeshCollectionActor_199.StaticMeshActor_SMC_838",
            "TheWorld.PersistentLevel.StaticMeshCollectionActor_201.StaticMeshActor_SMC_1045",
            "TheWorld.PersistentLevel.StaticMeshCollectionActor_201.StaticMeshActor_SMC_1089",
            "TheWorld.PersistentLevel.StaticMeshCollectionActor_201.StaticMeshActor_SMC_1150",
            "TheWorld.PersistentLevel.StaticMeshCollectionActor_201.StaticMeshActor_SMC_1236",
            "TheWorld.PersistentLevel.StaticMeshCollectionActor_201.StaticMeshActor_SMC_125",
            "TheWorld.PersistentLevel.StaticMeshCollectionActor_201.StaticMeshActor_SMC_1364",
            "TheWorld.PersistentLevel.StaticMeshCollectionActor_201.StaticMeshActor_SMC_1372",
            "TheWorld.PersistentLevel.StaticMeshCollectionActor_201.StaticMeshActor_SMC_1391",
            "TheWorld.PersistentLevel.StaticMeshCollectionActor_201.StaticMeshActor_SMC_1746",
            "TheWorld.PersistentLevel.StaticMeshCollectionActor_201.StaticMeshActor_SMC_1748",
            "TheWorld.PersistentLevel.StaticMeshCollectionActor_201.StaticMeshActor_SMC_1757",
            "TheWorld.PersistentLevel.StaticMeshCollectionActor_201.StaticMeshActor_SMC_1779",
            "TheWorld.PersistentLevel.StaticMeshCollectionActor_201.StaticMeshActor_SMC_1792",
            "TheWorld.PersistentLevel.StaticMeshCollectionActor_201.StaticMeshActor_SMC_1806",
            "TheWorld.PersistentLevel.StaticMeshCollectionActor_201.StaticMeshActor_SMC_1808",
            "TheWorld.PersistentLevel.StaticMeshCollectionActor_201.StaticMeshActor_SMC_1817",
            "TheWorld.PersistentLevel.StaticMeshCollectionActor_201.StaticMeshActor_SMC_1820",
            "TheWorld.PersistentLevel.StaticMeshCollectionActor_201.StaticMeshActor_SMC_1821",
            "TheWorld.PersistentLevel.StaticMeshCollectionActor_201.StaticMeshActor_SMC_1827",
            "TheWorld.PersistentLevel.StaticMeshCollectionActor_201.StaticMeshActor_SMC_1876",
            "TheWorld.PersistentLevel.StaticMeshCollectionActor_201.StaticMeshActor_SMC_1924",
            "TheWorld.PersistentLevel.StaticMeshCollectionActor_201.StaticMeshActor_SMC_545",
            "TheWorld.PersistentLevel.StaticMeshCollectionActor_201.StaticMeshActor_SMC_632",
            "TheWorld.PersistentLevel.StaticMeshCollectionActor_201.StaticMeshActor_SMC_65",
            "TheWorld.PersistentLevel.StaticMeshCollectionActor_202.StaticMeshActor_SMC_1437",
            "TheWorld.PersistentLevel.StaticMeshCollectionActor_202.StaticMeshActor_SMC_1809",
            "TheWorld.PersistentLevel.StaticMeshCollectionActor_202.StaticMeshActor_SMC_1886",
            "TheWorld.PersistentLevel.StaticMeshCollectionActor_202.StaticMeshActor_SMC_1902",
            "TheWorld.PersistentLevel.StaticMeshCollectionActor_202.StaticMeshActor_SMC_1917",
            "TheWorld.PersistentLevel.StaticMeshCollectionActor_202.StaticMeshActor_SMC_1918",
            "TheWorld.PersistentLevel.StaticMeshCollectionActor_202.StaticMeshActor_SMC_1919",
            "TheWorld.PersistentLevel.StaticMeshCollectionActor_202.StaticMeshActor_SMC_1942",
            "TheWorld.PersistentLevel.StaticMeshCollectionActor_202.StaticMeshActor_SMC_1943",
            "TheWorld.PersistentLevel.StaticMeshCollectionActor_202.StaticMeshActor_SMC_1951",
            "TheWorld.PersistentLevel.StaticMeshCollectionActor_202.StaticMeshActor_SMC_242",
            "TheWorld.PersistentLevel.StaticMeshCollectionActor_202.StaticMeshActor_SMC_782",
        ];

        static string[] CoverNeedingLightGuidFixes = [
            "TheWorld.PersistentLevel.StaticMeshCollectionActor_186.StaticMeshActor_SMC_1691",
            "TheWorld.PersistentLevel.StaticMeshCollectionActor_191.StaticMeshActor_SMC_1389",
            "TheWorld.PersistentLevel.StaticMeshCollectionActor_191.StaticMeshActor_SMC_149",
            "TheWorld.PersistentLevel.StaticMeshCollectionActor_191.StaticMeshActor_SMC_16",
            "TheWorld.PersistentLevel.StaticMeshCollectionActor_191.StaticMeshActor_SMC_164",
            "TheWorld.PersistentLevel.StaticMeshCollectionActor_191.StaticMeshActor_SMC_1728",
            "TheWorld.PersistentLevel.StaticMeshCollectionActor_191.StaticMeshActor_SMC_18",
            "TheWorld.PersistentLevel.StaticMeshCollectionActor_191.StaticMeshActor_SMC_190",
            "TheWorld.PersistentLevel.StaticMeshCollectionActor_191.StaticMeshActor_SMC_53",
            "TheWorld.PersistentLevel.StaticMeshCollectionActor_191.StaticMeshActor_SMC_56",
            "TheWorld.PersistentLevel.StaticMeshCollectionActor_191.StaticMeshActor_SMC_887",
            "TheWorld.PersistentLevel.StaticMeshCollectionActor_191.StaticMeshActor_SMC_974",
            "TheWorld.PersistentLevel.StaticMeshCollectionActor_191.StaticMeshActor_SMC_981",
            "TheWorld.PersistentLevel.StaticMeshCollectionActor_199.StaticMeshActor_SMC_1385",
            "TheWorld.PersistentLevel.StaticMeshCollectionActor_201.StaticMeshActor_SMC_90",
        ];

        /// <summary>
        /// GUID of the cannon light effect
        /// </summary>
        private static readonly Guid CannonLightGuid = new("37f105aa-cfa9-4b2b-9114-8148cfa495b5");

        /// <summary>
        /// Fixes the thin cover not getting lit by the cannon lighting which is much more noticable on dark lighting for Towr2
        /// </summary>
        /// <param name="pipeline"></param>
        /// <param name="package"></param>
        private static void FixCoverPiecesLighting(LevelSpecificPipeline pipeline, IMEPackage package)
        {
            if (package.FileNameNoExtension != "BioA_MPTowr2_200")
            {
                return; // Not this level
            }

            foreach (var cover in CoverNeedingLightGuidFixes)
            {
                var exp = package.FindExport(cover);
                var irrelevantLights = exp.GetProperty<ArrayProperty<StructProperty>>("IrrelevantLights");

                var newIrrelevantLights = irrelevantLights.Where(x => CommonStructs.GetGuid(x) != CannonLightGuid).ToArray();

                if (newIrrelevantLights.Length == 0)
                {
                    // Nuke whole property
                    exp.RemoveProperty("IrrelevantLights");
                }
                else
                {
                    // Write them back
                    exp.WriteProperty(new ArrayProperty<StructProperty>(newIrrelevantLights, "IrrelevantLights"));
                }
            }
        }

        private static void EnableStructuralStaticLighting(LevelSpecificPipeline pipeline, IMEPackage package)
        {
            // Validate the entire list before modifying any component
            var components = StructuralLightingTargets.Select(path =>
            {
                var component = package.FindExport(path);
                if (component?.ClassName != "StaticMeshComponent" || component.GetProperty<StructProperty>("LightingChannels") == null)
                {
                    throw new InvalidOperationException($"MPTowr2 lighting: expected StaticMeshComponent with LightingChannels at {package.FileNameNoExtension}.{path}.");
                }
                return component;
            }).ToArray();

            var changed = 0;
            foreach (var component in components)
            {
                var channels = component.GetProperty<StructProperty>("LightingChannels");
                if (channels.Properties.GetProp<BoolProperty>("Static")?.Value == true)
                {
                    continue;
                }
                channels.Properties.AddOrReplaceProp(new BoolProperty(true, "Static"));
                component.WriteProperty(channels);
                changed++;
            }
            MilanLog.Information($"MPTowr2 structural lighting: enabled Static on {changed} of {components.Length} components", customPrefix: pipeline.LogCategory);
        }

        public override void PreCorrect(LevelSpecificPipeline pipeline)
        {
            if (!pipeline.ME3Packages.TryGetValue(LightingPackageName, out var package))
            {
                throw new InvalidOperationException($"MPTowr2 lighting: required package {LightingPackageName} was not loaded.");
            }

            ApplyLightBrightness(pipeline, path => package.FindExport(path));

            // Makes flashlights work on other parts of the level
            EnableStructuralStaticLighting(pipeline, package);

            // Fixes light flashing on the thin cover pieces that are supposed to be lit by the cannon light
            FixCoverPiecesLighting(pipeline, package);
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

        public override void PostLightingCorrect(LevelSpecificPipeline pipeline)
        {
            // The *_UI_Lights sublevel's lights are left as they are; every other light is in this package
            var packagePath = Path.Combine(pipeline.LevelOutputDir, $"{LightingPackageName}.pcc");
            using var package = MEPackageHandler.OpenMEPackage(packagePath);
            var (local, character) = CharacterLighting.Apply(package);
            if (package.IsModified)
                package.Save(diskIOSyncLock: MilanShared.DiskIOSyncLock);
            MilanLog.Information($"MPTowr2 character lighting: scaled {local} point/spot lights and {character} character-only lights " +
                $"({CharacterLighting})", customPrefix: pipeline.LogCategory);
        }
    }
}
