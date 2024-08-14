using System.Diagnostics;
using System.Drawing.Interop;
using System.Numerics;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Helpers;
using LegendaryExplorerCore.Packages.CloningImportingAndRelinking;
using LegendaryExplorerCore.Shaders;
using LegendaryExplorerCore.Unreal;
using LegendaryExplorerCore.Unreal.BinaryConverters;
using LegendaryExplorerCore.Unreal.Classes;
using LegendaryExplorerCore.Unreal.Collections;
using LegendaryExplorerCore.Unreal.ObjectInfo;
using ProjectMilan.Pipelines.Materials;
using ProjectMilan.Pipelines.Shared;
using ProjectMilan.Utility;
using ProjectMilanCore;

namespace ProjectMilan.Pipelines.Levels
{
    public static class LevelShared
    {
        public static List<string> GetSublevelPackages(IMEPackage package)
        {
            if (package is MEPackage mePackage)
            {
                return mePackage.AdditionalPackagesToCook;
            }

            MilanLog.Error(@"Unsupported package type!");
            return null;
        }

        public static ExportEntry CreateSPStartLocation(IMEPackage package, Point3D startLocation)
        {
            var pl = package.FindExport("TheWorld.PersistentLevel");
            var startLoc = ExportCreator.CreateExport(package, "BioStartLocation", "BioStartLocation", pl);
            startLoc.WriteProperty(new StructProperty("Vector", new PropertyCollection()
            {
                new FloatProperty(startLocation.X, "X"),
                new FloatProperty(startLocation.Y, "Y"),
                new FloatProperty(startLocation.Z, "Z"),
            }, "location", true));


            var collisionCylinder =
                ExportCreator.CreateExport(package, "CylinderComponent", "CylinderComponent", startLoc);
            collisionCylinder.WritePrePropsAndProperties(new byte[4],
                collisionCylinder.GetProperties()); // Set up pre-prop binary

            collisionCylinder.WriteProperty(new ObjectProperty(0, "ReplacementPrimitive"));
            // Technically should do lighting channels.

            startLoc.WriteProperty(new ObjectProperty(collisionCylinder, "CollisionComponent"));
            startLoc.WriteProperty(new NameProperty("start_milanSP", "Tag"));



            return startLoc;
        }

        public static IMEPackage PortLevel(LevelSpecificPipeline levelPipeline, IMEPackage sourcePackage)
        {
            var packageBaseName = Path.GetFileNameWithoutExtension(sourcePackage.FileNameNoExtension);
            MilanLog.Information($"Porting level file {packageBaseName}.pcc", customPrefix: levelPipeline.LogCategory);

            Directory.CreateDirectory(levelPipeline.LevelOutputDir);

            // The current level set file
            var destPackagePath = Path.Combine(levelPipeline.LevelOutputDir, $"{packageBaseName}.pcc");
            MEPackageHandler.CreateEmptyLevel(destPackagePath, MEGame.LE3);

            var destPackage = MEPackageHandler.OpenMEPackage(destPackagePath);
            destPackage.LECLTagData.ImportHintFiles.Add(MilanShared.MP_STARTUP_FILENAME); // Hint this file
            levelPipeline.LE3Packages[Path.GetFileNameWithoutExtension(destPackagePath)] = destPackage;
            if (sourcePackage == levelPipeline.ME3BioP)
            {
                // Mark the LE3 BioP
                levelPipeline.LE3BioP = destPackage;
            }

            var destLevel = PackageExtensions.GetLevel(destPackage);
            var sourcePersistentLevel = PackageExtensions.GetLevelBinary(sourcePackage);
            var actors = sourcePersistentLevel.Actors.Where(x =>
            {
                if (sourcePackage.TryGetUExport(x, out var exp))
                {
                    // Will be brought in automatically
                    if (exp.ClassName == "Model") return false;
                    if (exp.ClassName == "Polys") return false;

                    // Already in the file
                    if (exp.ClassName == "BioWorldInfo") return false;
                    return true;
                }

                return false;
            }).Select(x => sourcePackage.GetUExport(x));

            foreach (var sm in actors)
            {
                // Ensure it's unique to the dest

                if (destPackage.FindExport(sm.InstancedFullPath) != null)
                {
                    // Console.WriteLine($@" > Already exists: {sm.InstancedFullPath}");
                }
                else
                {
                    MilanLog.Information($"  Porting {sm.InstancedFullPath}", customPrefix: levelPipeline.LogCategory);
                    var badLinks = EntryImporter.ImportAndRelinkEntries(
                        EntryImporter.PortingOption.CloneAllDependencies,
                        sm, destPackage, destLevel, true,
                        new RelinkerOptionsPackage()
                        {
                            IsCrossGame = true,
                            TargetGameDonorDB = MilanShared.LE3ObjectDB,
                            Cache = levelPipeline.Cache,
                            PortExportsAsImportsWhenPossible = true,
                            PortImportsMemorySafe = true,
                            DestinationCustomImportFileResolver = MilanShared.LE3PackageResolver,
                            SourceCustomImportFileResolver = MilanShared.ME3PackageResolver,
                            CustomDonorImporter = DonorBuilderPipeline.MaterialDonorImporter
                        }, out var _);
                    if (badLinks.Any())
                    {
                        // uh oh
                    }
                }
            }

            // Sequencing needs ported over eventually. This controls the shuttle flying away. Requires MP classes though.
            foreach (var export in destPackage.Exports)
            {
                var ifp = export.InstancedFullPath;
                if (export.HasStack)
                {
                    // Copy stack data. Not sure if this does anything useful.
                    var orig = sourcePackage.FindExport(ifp);
                    if (orig == null)
                        continue;
                    var binPreOrig = orig.GetPrePropBinary();
                    var binPost = export.GetPrePropBinary();
                    binPost[0x10] = binPreOrig[0x10];
                    binPost[0x11] = binPreOrig[0x11];
                    export.WritePrePropsAndProperties(binPost, export.GetProperties());
                }

                var cachedDataVer = export.GetProperty<IntProperty>("CachedPhysBrushDataVersion") ??
                                    export.GetProperty<IntProperty>("PreCachedPhysDataVersion");
                if (cachedDataVer != null && cachedDataVer == 34079634) // OT version
                {
                    MilanLog.Information($"  Fixing collision data for {ifp}", customPrefix: levelPipeline.LogCategory);

                    // Get rid of it
                    // This doesn't fix anything
                    //export.RemoveProperty(cachedDataVer.Name);
                    //export.WriteBinary(levelPipeline.donorBrush);

                    // Change version
                    // This partially fixes collision
                    cachedDataVer.Value = 34079762; // Newer version of PhysX?
                    export.WriteProperty(cachedDataVer);

                    // Todo: Static mesh Rigid Body?
                    // Level BioP

                    if (export.IsA("BrushComponent"))
                    {
                        BrushComponent bc = ObjectBinary.From(export, levelPipeline.Cache) as BrushComponent;

                        foreach (var ch in bc.CachedPhysBrushData.CachedConvexElements)
                        {
                            ch.ConvexElementData = ch.ConvexElementData.Skip(0x10).ToArray(); // Trim off first 16 bytes
                        }

                        export.WriteBinary(bc);
                    }

                    // export.WriteProperty(new BoolProperty(true, "BlockRigidBody"));
                    // export.WriteProperty(new BoolProperty(true, "BlockZeroExtent"));
                    // export.WriteProperty(new BoolProperty(true, "BlockNonZeroExtent"));
                    // export.WriteProperty(new BoolProperty(true, "BlockActors"));
                }


            }

            // Map the stuff in PersistentLevel
            var destLevelBin = PackageExtensions.GetLevelBinary(destPackage);

            // Bring over models
            var oModelIdx = sourcePersistentLevel.Model;
            var destModelIdx = destLevelBin.Model;

            // MODEL =============
            if (oModelIdx > 0)
            {
                var sourcemodel = sourcePackage.GetUExport(oModelIdx);
                var destmodel = destPackage.GetUExport(destModelIdx);
                MilanLog.Information($"  Porting level model {sourcemodel.InstancedFullPath}",
                    customPrefix: levelPipeline.LogCategory);
                EntryImporter.ImportAndRelinkEntries(EntryImporter.PortingOption.ReplaceSingularWithRelink, sourcemodel,
                    destPackage, destmodel, true, new RelinkerOptionsPackage()
                    {
                        Cache = levelPipeline.Cache,
                        DestinationCustomImportFileResolver = MilanShared.LE3PackageResolver,
                        SourceCustomImportFileResolver = MilanShared.ME3PackageResolver,
                        TargetGameDonorDB = MilanShared.LE3ObjectDB,
                        PortExportsAsImportsWhenPossible = true,
                    }, out _);
            }
            else
            {
                destLevelBin.Model = 0;
            }

            // MODEL COMPONENTS ===============
            var oModelComponentsIdxs = sourcePersistentLevel.ModelComponents;
            if (oModelComponentsIdxs.Length > 0)
            {
                List<ExportEntry> modelComponents = new List<ExportEntry>();
                foreach (var oModelCompIdx in oModelComponentsIdxs)
                {
                    var sModelComp = sourcePackage.GetUExport(oModelCompIdx);
                    MilanLog.Information($"  Porting level model component {sModelComp.InstancedFullPath}",
                        customPrefix: levelPipeline.LogCategory);
                    EntryImporter.ImportAndRelinkEntries(EntryImporter.PortingOption.CloneAllDependencies, sModelComp,
                        destPackage, destLevel, true, new RelinkerOptionsPackage()
                        {
                            Cache = levelPipeline.Cache,
                            DestinationCustomImportFileResolver = MilanShared.LE3PackageResolver,
                            TargetGameDonorDB = MilanShared.LE3ObjectDB,
                            PortExportsAsImportsWhenPossible = true,
                        }, out var newModelComp);
                    var newModelExp = newModelComp as ExportEntry;
                    modelComponents.Add(newModelExp);
                    var mc = ObjectBinary.From<ModelComponent>(newModelExp);
                    mc.Model = destLevelBin.Model;
                    newModelExp.WriteBinary(mc);
                }

                destLevelBin.ModelComponents = modelComponents.Select(x => x.UIndex).ToArray();
            }

            // Bring over cover
            if (sourcePersistentLevel.CoverListStart > 0)
            {
                destLevelBin.CoverListStart =
                    destPackage.FindExport(sourcePackage.GetUExport(sourcePersistentLevel.CoverListStart)
                        .InstancedFullPath).UIndex;
                destLevelBin.CoverListEnd = destPackage
                    .FindExport(sourcePackage.GetUExport(sourcePersistentLevel.CoverListEnd).InstancedFullPath).UIndex;

                // Don't know if these matter
                // Don't copy version - use LE version
                //destLevelBin.CachedPhysSMDataStore = sourcePersistentLevel.CachedPhysSMDataStore;
                //destLevelBin.CachedPhysBSPData = sourcePersistentLevel.CachedPhysBSPData;
                //destLevelBin.CachedPhysPerTriSMDataMap = sourcePersistentLevel.CachedPhysPerTriSMDataMap;
                //destLevelBin.CachedPhysSMDataStore = sourcePersistentLevel.CachedPhysSMDataStore;
                //destLevelBin.CachedPhysSMDataMap = sourcePersistentLevel.CachedPhysSMDataMap;
            }

            if (sourcePersistentLevel.NavListStart > 0)
            {
                var sStart = sourcePackage.GetUExport(sourcePersistentLevel.NavListStart);
                var sEnd = sourcePackage.GetUExport(sourcePersistentLevel.NavListEnd);

                var dStart = destPackage.FindExport(sStart.InstancedFullPath);
                var dEnd = destPackage.FindExport(sEnd.InstancedFullPath);
                destLevelBin.NavListStart = dStart.UIndex;
                destLevelBin.NavListEnd = dEnd.UIndex;
            }

            // NavRefs, CoverRefs
            // CrossLevelActors
            PackageExtensions.GetLevel(destPackage).WriteBinary(destLevelBin);

            // Port sequence
            var srcSeq = sourcePackage.FindExport("TheWorld.PersistentLevel.Main_Sequence");
            var destSeq = destPackage.FindExport("TheWorld.PersistentLevel.Main_Sequence");

            if (srcSeq != null && destSeq != null)
            {
                MilanLog.Information("  Porting Main_Sequence", customPrefix: levelPipeline.LogCategory);
                var badLinks = EntryImporter.ImportAndRelinkEntries(
                    EntryImporter.PortingOption.ReplaceSingularWithRelink, srcSeq, destPackage, destSeq
                    , true, new RelinkerOptionsPackage()
                    {
                        IsCrossGame = true,
                        TargetGameDonorDB = MilanShared.LE3ObjectDB,
                        Cache = levelPipeline.Cache,
                        PortExportsAsImportsWhenPossible = true,
                        DestinationCustomImportFileResolver = MilanShared.LE3PackageResolver,
                        SourceCustomImportFileResolver = MilanShared.ME3PackageResolver,
                    }, out var _);

            }

            LevelTools.RebuildPersistentLevelChildren(destLevel);

            if (levelPipeline.StripShadowMaps)
            {
                foreach (var exp in destPackage.Exports.Where(x => x.ClassName == "StaticMeshComponent"))
                {
                    var b = ObjectBinary.From<StaticMeshComponent>(exp);
                    foreach (var lod in b.LODData)
                    {
                        lod.ShadowMaps = Array.Empty<int>();
                    }

                    exp.WriteBinary(b);
                }
            }

            // Calculate a very basic texture to instances map
            LevelShared.CalculateTextureToInstancesMap(destPackage, levelPipeline.Cache);

            MilanLog.Information($"  Saving ported package {packageBaseName}.pcc",
                customPrefix: levelPipeline.LogCategory);
            destPackage.Save();
            MilanShared.RefreshMilanFiles = true;

            // Detect remaining shaders
            var brokenMaterials = ShaderCacheManipulator.GetBrokenMaterials(destPackage);
            foreach (var v in brokenMaterials)
            {
                var matchingME3 = sourcePackage.FindExport(v.InstancedFullPath);
                if (matchingME3 != null)
                {
                    if (levelPipeline.MaterialsNeedingDonors.All(x => x.InstancedFullPath != matchingME3.InstancedFullPath))
                    {
                        levelPipeline.MaterialsNeedingDonors.Add(matchingME3);
                    }
                }
            }

            return destPackage;
        }

        /// <summary>
        /// Sets the game modes on BioWorldInfo
        /// </summary>
        /// <param name="bioP"></param>
        public static void SetupHordeModes(IMEPackage bioP, bool isLobby)
        {
            if (isLobby)
            {
                var mpContent = bioP.FindEntry("SFXGameMPContentDLC_Shared_MP") ??
                                ExportCreator.CreatePackageExport(bioP, "SFXGameMPContentDLC_Shared_MP");
                ImportEntry lobbyMode = new ImportEntry(bioP)
                {
                    ObjectName = "SFXGameInfoMP_Lobby_DLC",
                    idxLink = mpContent.UIndex,
                    ClassName = "Class",
                    PackageFile = "Core"
                };
                bioP.AddImport(lobbyMode);
                bioP.GetBioWorldInfo().WriteProperty(
                    new ArrayProperty<ObjectProperty>("GameTypesSupportedOnThisMap")
                    {
                        new ObjectProperty(lobbyMode),
                    });
            }
            else
            {
                var mpContent = bioP.FindEntry("SFXGameMPContent") ??
                                ExportCreator.CreatePackageExport(bioP, "SFXGameMPContent");

                ImportEntry infoMP = new ImportEntry(bioP)
                {
                    ObjectName = "SFXGameInfoMP",
                    idxLink = mpContent.UIndex,
                    ClassName = "Class",
                    PackageFile = "Core"
                };
                ImportEntry gameTypeHorde = new ImportEntry(bioP)
                {
                    ObjectName = "SFXGameType_Horde_Operation",
                    idxLink = mpContent.UIndex,
                    ClassName = "Class",
                    PackageFile = "Core"
                };
                bioP.AddImport(infoMP);
                bioP.AddImport(gameTypeHorde);
                bioP.GetBioWorldInfo().WriteProperty(
                    new ArrayProperty<ObjectProperty>("GameTypesSupportedOnThisMap")
                    {
                        new ObjectProperty(infoMP),
                        new ObjectProperty(gameTypeHorde)
                    });
            }
        }

        // This technically doesn't need done here as we have this all computed already and could just be ported over
        // but it would be good to try to code something up here to do it for us for other devs
        /// <summary>
        /// Computes a texture to instances map for a level package
        /// </summary>
        /// <param name="package"></param>
        public static void CalculateTextureToInstancesMap(IMEPackage package, TieredPackageCache cache)
        {
            MilanLog.Information($"Calculating TextureToInstancesMap for {package.FileNameNoExtension}", customPrefix: @"MILAN-StreamingTextures");
            var textureToInstancesMap = new Dictionary<IEntry, List<StreamableTextureInstance>>();

            // Look at all components
            foreach (var component in package.Exports.Where(x => x.IsA("Component")))
            {
                // Only do ones in the world
                if (!component.GetRootName().CaseInsensitiveEquals("TheWorld"))
                    continue;

                ObjectProperty meshProp = component.GetProperty<ObjectProperty>("StaticMesh");
                meshProp ??= component.GetProperty<ObjectProperty>("SkeletalMesh");

                if (meshProp == null)
                    continue; // Not supported by this code.

                // List of materials this mesh uses
                List<IEntry> texturesOnMesh = new List<IEntry>();
                List<ExportEntry> materials = new List<ExportEntry>();
                var matList = component.GetProperty<ArrayProperty<ObjectProperty>>("Materials");
                if (matList != null)
                {
                    foreach (var mat in matList)
                    {
                        if (mat.TryResolveExport(package, cache, out var matExp))
                        {
                            materials.Add(matExp);
                        }
                    }
                }

                // if we don't have any materials set on component, we have to pull it off the mesh.
                // resolve the mesh export
                if (materials.Count == 0 && meshProp.TryResolveExport(package, cache, out var mdl))
                {
                    switch (mdl.ClassName)
                    {
                        case "StaticMesh":
                            {
                                var bin = ObjectBinary.From<StaticMesh>(mdl);
                                foreach (var mat in bin.GetMaterials())
                                {
                                    if (mdl.FileRef.TryGetEntry(mat, out var matEntry))
                                    {
                                        if (matEntry is ExportEntry exp)
                                            materials.Add(exp);
                                        else if (matEntry is ImportEntry imp &&
                                                 EntryImporter.TryResolveImport(imp, out var resolvedExp, cache))
                                            materials.Add(resolvedExp);
                                    }
                                }

                                break;
                            }
                        case "SkeletalMesh":
                            {
                                var bin = ObjectBinary.From<SkeletalMesh>(mdl);
                                foreach (var mat in bin.Materials)
                                {
                                    if (mdl.FileRef.TryGetEntry(mat, out var matEntry))
                                    {
                                        if (matEntry is ExportEntry exp)
                                            materials.Add(exp);
                                        else if (matEntry is ImportEntry imp &&
                                                 EntryImporter.TryResolveImport(imp, out var resolvedExp, cache))
                                            materials.Add(resolvedExp);
                                    }
                                }

                                break;
                            }
                    }
                }

                // We now have the list of materials.
                // Get actor location.
                var actorLocation = GetActorLocationFromComponent(component);

                if (actorLocation is { X: 0, Y: 0, Z: 0 })
                    continue;

                // Get list of textures on the materials.
                foreach (var mat in materials.Distinct())
                {
                    var parsedMat = new MaterialInstanceConstant(mat, cache, true);
                    texturesOnMesh.AddRange(parsedMat.Textures);
                }

                // Jiminy crickets this is complicated
                // Add imports for all materials so we can reference them if they are in higher tier packages.
                foreach (var tex in texturesOnMesh.ToList())
                {
                    //if (tex.UIndex == 53054)
                    //    //&& package.FileNameNoExtension != "BioA_MPMoon")
                    //    Debugger.Break();
                    if (tex.ClassName.CaseInsensitiveEquals("TextureCube"))
                    {
                        // Texture cubes are not streamable
                        texturesOnMesh.Remove(tex);
                        continue;
                    }

                    if (tex is ExportEntry tExp)
                    {
                        bool validatePackage = true;
                        if (tExp.GetProperty<BoolProperty>("NeverStream")?.Value == true)
                        {
                            // This texture is not streamed
                            texturesOnMesh.Remove(tex);
                            continue;
                        }
                        var t2d = ObjectBinary.From<UTexture2D>(tExp, cache);
                        if (t2d.Mips.Count <= 6)
                        {
                            // This texture is not streamed.
                            texturesOnMesh.Remove(tex);
                            continue;
                        }

                        if (tex.FileRef != package)
                        {
                            // We must resolve this to local object
                            var existingEntry = package.FindEntry(tex.InstancedFullPath, tex.ClassName);
                            if (existingEntry != null)
                            {
                                texturesOnMesh.Remove(tex);
                                texturesOnMesh.Add(existingEntry);
                                validatePackage = false;
                            }
                            else
                            {
                                // Not found, and in another package
                                var parent = EntryExporter.PortParents(tex, package, true); // Really dicey. This method needs improved
                                ImportEntry imp = new ImportEntry(tExp, parent.UIndex, package);
                                package.AddImport(imp);

                                // Replace the mesh 
                                texturesOnMesh.Remove(tex);
                                texturesOnMesh.Add(imp);
                                validatePackage = false;
                            }
                        }

                        // We're gonna crash game if we use this
                        if (tex.FileRef != package && validatePackage)
                            Debugger.Break();
                    }
                    else if (tex is ImportEntry tImp)
                    {
                        if (tImp.FileRef != package)
                        {
                            // This is an import in another package. We must copy it over.
                            var newImp = EntryExporter.PortParents(tImp, package, true);
                            texturesOnMesh.Remove(tex);
                            texturesOnMesh.Add(newImp);
                        }
                    }
                }

                // Add streaming instances.
                foreach (var tex in texturesOnMesh)
                {
                    // Final validation
                    if (tex.FileRef != package)
                        Debugger.Break();

                    if (!textureToInstancesMap.TryGetValue(tex, out var stil))
                    {
                        stil = new List<StreamableTextureInstance>();
                        textureToInstancesMap[tex] = stil;
                    }

                    stil.Add(new StreamableTextureInstance()
                    {
                        BoundingSphere = new Sphere()
                        {
                            Center = new Vector3(actorLocation.X, actorLocation.Y, actorLocation.Z),
                            W = 50 // Radius. I guess we could technically take the size of the mesh. But do I care that much?
                        },
                        TexelFactor = 50 // I have no ideal how to calcluate this
                    });
                }
            }
            // We now have location and list of textures
            // Build the map.

            var levelExp = package.GetLevel();
            var level = package.GetLevelBinary();

            level.TextureToInstancesMap = new UMultiMap<int, StreamableTextureInstanceList>(textureToInstancesMap.Count);
            foreach (var tex in textureToInstancesMap)
            {
                level.TextureToInstancesMap[tex.Key.UIndex] = new StreamableTextureInstanceList()
                {
                    Instances = tex.Value.ToArray()
                };
            }

            levelExp.WriteBinary(level);

        }

        private static Point3D GetActorLocationFromComponent(ExportEntry exportEntry)
        {
            // I don't like working with structs.
            // So we use Point3D instead.
            if (exportEntry.HasParent && (exportEntry.IsA("StaticMeshComponent")
                                          && exportEntry.Parent.IsA("StaticMeshCollectionActor")
                                          || exportEntry.IsA("LightComponent") &&
                                          exportEntry.Parent.IsA("StaticLightCollectionActor")))
            {
                // collection actor
                if (StaticCollectionActor.TryGetStaticCollectionActorAndIndex(exportEntry,
                        out StaticCollectionActor sca, out int index))
                {
                    float PosX;
                    float PosY;
                    float PosZ;
                    ((PosX, PosY, PosZ), (_, _, _), (_, _, _)) = sca.GetDecomposedTransformationForIndex(index);
                    return new Point3D(PosX, PosY, PosZ);
                }
            }
            else
            {
                return LevelTools.GetLocation(exportEntry);
            }

            // Unknown location...
            Debugger.Break();
            return new Point3D();
        }
    }
}
