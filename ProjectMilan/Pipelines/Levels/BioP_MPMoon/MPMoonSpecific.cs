using LegendaryExplorerCore.Gammtek.Extensions;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Textures;
using LegendaryExplorerCore.Unreal;
using LegendaryExplorerCore.Unreal.BinaryConverters;
using LegendaryExplorerCore.Unreal.Classes;
using ProjectMilan.Pipelines.Texture;
using ProjectMilanCore;
using System.Numerics;
using Image = LegendaryExplorerCore.Textures.Image;

namespace ProjectMilan.Pipelines.Levels.BioP_MPMoon
{
    internal class MPMoonSpecific : LevelSpecificFixesBase
    {
        // Map has some extra levels we don't want to include in the lighting bake.
        public override string[] IgnoredLightingLevels => [
            "BioA_MPMoon_Bas1",
            "BioA_MPMoon_bsp",
        ];


        // Extra blocking volumes that bioware seems to have left in and need removed
        private static readonly (string Package, string ActorIFP)[] StrippedActors =
        [
            ("BioD_MPMoon_Bas1", "TheWorld.PersistentLevel.BlockingVolume_41"),
        ];

        // Condor ammo boxes don't have the correct respawn time set which makes it SUCK to get ammo
        public override void PreCorrect(LevelSpecificPipeline pipeline)
        {
            foreach (var package in pipeline.ME3Packages.Values)
            {
                var bin = package.GetLevelBinary();

                for (int i = bin.Actors.Count - 1; i >= 0; i--)
                {
                    if (package.TryGetUExport(bin.Actors[i], out var actor))
                    {
                        if (StrippedActors.Contains((package.FileNameNoExtension, actor.InstancedFullPath)))
                        {
                            MilanLog.Information($"Stripping actor {actor.InstancedFullPath} from {package.FileNameNoExtension}", customPrefix: pipeline.LogCategory);
                            bin.Actors.RemoveAt(i);
                            continue;
                        }

                        if (actor.ClassName == "SFXAmmoContainer")
                        {
                            actor.WriteProperty(new FloatProperty(3.0f, "RespawnTime"));
                        }
                    }
                }

                package.GetLevel().WriteBinary(bin);

            }
        }

        // DebrisShip01_C's 4th material is empty after porting and needs to be set to the same as the third slot
        private const string DebrisShipMeshIFP = "BioApl_Ind_DebrisShip01.Meshes.DebrisShip01_C";

        /// <summary>
        /// List of meshes to change position data of
        /// </summary>
        private static readonly (string ComponentIFP, Vector3 Corrected)[] MeshPositionFixes =
        [
            ("TheWorld.PersistentLevel.StaticMeshCollectionActor_28.StaticMeshActor_SMC_208",  new Vector3(-11796.001f, -299.98242f, -2200f)),
        ];

        public override void PostCorrect(LevelSpecificPipeline pipeline)
        {
            // BioP's PlayerStart_4 is NetworkID 143, but the BioD_MPMoon_Bas1 network it links to is 142, pawns can get stuck on it
            FixPlayerStartNetworkIDs(pipeline, 142);

            foreach (var package in pipeline.LE3Packages.Values)
            {
                FixContainerMaterialOverrides(package);
                FixMeshPositions(package, pipeline.LogCategory);

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

        private static void FixMeshPositions(IMEPackage package, string logCategory)
        {
            if (package.FileNameNoExtension != "BioA_MPMoon_100")
            {
                return;
            }

            foreach (var (componentIFP, corrected) in MeshPositionFixes)
            {
                var component = package.FindExport(componentIFP, "StaticMeshComponent");
                if (component?.Parent is not ExportEntry collectionActor || !StaticCollectionActor.TryGetStaticCollectionActorAndIndex(component, out var sca, out int index))
                {
                    MilanLog.Warning($"Mesh position fix: couldn't find {componentIFP} in a collection actor in {package.FileNameNoExtension}", customPrefix: logCategory);
                    continue;
                }

                var transform = sca.LocalToWorldTransforms[index];
                transform.Translation = corrected;
                sca.LocalToWorldTransforms[index] = transform;
                collectionActor.WriteBinary(sca);
                MilanLog.Information($"Moved {componentIFP} to {corrected}", customPrefix: logCategory);
            }
        }

        public override void PostLightingCorrect(LevelSpecificPipeline pipeline)
        {
            // This is done here because if done before lighting bake UDK export will fail as this asset isn't in decook
            FixMistTexture(pipeline);
        }

        private void FixMistTexture(LevelSpecificPipeline pipeline)
        {
            var mistTextureIFP = @"BioT_RedRock_Ter.Textures.Diff.SkyCloud_DIFF";
            var newTextureName = "SkyCloud_DIFF_Milan";

            var levelPackages = Directory.GetFiles(pipeline.LevelOutputDir, "*.pcc");
            var artMasterF = levelPackages.FirstOrDefault(x => Path.GetFileNameWithoutExtension(x) == @"BioA_MPMoon");
            using (var artMasterP = MEPackageHandler.OpenMEPackage(artMasterF, diskIOSyncLock: MilanShared.DiskIOSyncLock))
            {
                // Replace texture in the art master
                // Package stored will make it externalize in TFC build
                var texture = artMasterP.FindExport(mistTextureIFP, "Texture2D");
                var image = Image.LoadFromFile(Path.Combine(MilanShared.PipelineRoot, "Levels", "BioP_MPMoon", $"{mistTextureIFP}.png"), PixelFormat.ARGB);
                new Texture2D(texture).Replace(image, texture.GetProperties(), isPackageStored: true);
                TFCBuild.ClearNeverStreamForExternalization(texture);

                // Change name for clarity this asset has changed
                texture.ObjectName = new NameReference(newTextureName);
                artMasterP.Save(diskIOSyncLock: MilanShared.DiskIOSyncLock);
                MilanLog.Information($"Updated Mist texture object", customPrefix: pipeline.LogCategory);
            }

            // Other levels import it by path, so we have to make sure names are updated too
            foreach (var packagePath in levelPackages.Where(x => x != artMasterF))
            {
                using var package = MEPackageHandler.OpenMEPackage(packagePath, diskIOSyncLock: MilanShared.DiskIOSyncLock);
                var import = package.FindImport(mistTextureIFP);
                if (import == null)
                {
                    // Not in this file
                    continue;
                }

                import.ObjectName = new NameReference(newTextureName);
                package.Save(diskIOSyncLock: MilanShared.DiskIOSyncLock);
                MilanLog.Information($"Renamed {mistTextureIFP} import in {package.FileNameNoExtension}", customPrefix: pipeline.LogCategory);
            }

            MilanShared.RefreshMilanFiles = true;
        }

        // LE asset for the supply tank/crate thing
        // changes UVs and mesh but our override uses old ME3
        // version, so we take that instead
        private static void FixContainerMaterialOverrides(IMEPackage package)
        {
            if (package.FileNameNoExtension != "BioA_MPMoon_100")
            {
                return;
            }

            var material = package.FindExport("bioapl_con_container03.Container03_MatInst");
            foreach (var component in package.Exports.Where(x => x.ClassName == "StaticMeshComponent"))
            {
                if (component.GetProperty<ObjectProperty>("StaticMesh")?.ResolveToEntry(package)?.InstancedFullPath != "bioapl_con_container03.Container03")
                {
                    // Not our mesh
                    continue;
                }

                var materials = component.GetProperty<ArrayProperty<ObjectProperty>>("Materials");
                if (materials == null || materials.Count == 0 || materials[0].ResolveToEntry(package)?.InstancedFullPath != "BioT_MPMoon.Materials.Container03_MatInst")
                {
                    continue;
                }

                // Correct the material to the version that works with LE3
                materials[0].Value = material.UIndex;
                component.WriteProperty(materials);
            }
        }
    }
}
