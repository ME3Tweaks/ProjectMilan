using LegendaryExplorerCore.Gammtek.Extensions;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Helpers;
using LegendaryExplorerCore.Packages.CloningImportingAndRelinking;
using LegendaryExplorerCore.Pathing;
using LegendaryExplorerCore.Shaders;
using LegendaryExplorerCore.UDK;
using LegendaryExplorerCore.Unreal;
using LegendaryExplorerCore.Unreal.BinaryConverters;
using LegendaryExplorerCore.Unreal.ObjectInfo;
using ProjectMilanCore;
using LegendaryExplorerCore.Kismet;

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

        /// <summary>
        /// Multiplies explicitly-authored culling distances on populated StaticMeshComponents and CullDistanceVolumes
        /// in one package. Components without a serialized distance keep their class/archetype default. Cull-distance
        /// volume size thresholds and class defaults are left unchanged.
        /// </summary>
        /// <param name="package">Level package to adjust. Call once for each level/sublevel package being built.</param>
        /// <param name="multiplier">Factor applied to explicit component and volume culling distances; must be finite and non-negative.</param>
        /// <returns>Number of component and volume exports changed.</returns>
        public static int MultiplyStaticMeshComponentCullingDistances(IMEPackage package, float multiplier)
        {
            ArgumentNullException.ThrowIfNull(package);
            if (!float.IsFinite(multiplier) || multiplier < 0)
            {
                throw new ArgumentOutOfRangeException(nameof(multiplier), "Culling distance multiplier must be a finite, non-negative value.");
            }

            var updatedComponentCount = 0;
            var updatedVolumeCount = 0;
            var updatedVolumeEntryCount = 0;
            foreach (var export in package.Exports)
            {
                if (export.IsA("CullDistanceVolume"))
                {
                    var cullDistances = export.GetProperty<ArrayProperty<StructProperty>>("CullDistances");
                    if (cullDistances == null)
                    {
                        continue;
                    }

                    var changedEntries = 0;
                    foreach (var entry in cullDistances)
                    {
                        var cullDistance = entry.GetProp<FloatProperty>("CullDistance");
                        if (cullDistance == null)
                        {
                            continue;
                        }

                        var scaledDistance = cullDistance.Value * multiplier;
                        if (scaledDistance != cullDistance.Value)
                        {
                            cullDistance.Value = scaledDistance;
                            changedEntries++;
                        }
                    }

                    if (changedEntries > 0)
                    {
                        export.WriteProperty(cullDistances);
                        updatedVolumeCount++;
                        updatedVolumeEntryCount += changedEntries;
                    }
                    continue;
                }

                if (!export.IsA("StaticMeshComponent") || export.GetProperty<ObjectProperty>("StaticMesh")?.Value is not > 0)
                {
                    continue;
                }

                var maxDrawDistance = export.GetProperty<FloatProperty>("MaxDrawDistance");
                var cachedMaxDrawDistance = export.GetProperty<FloatProperty>("CachedMaxDrawDistance");
                if (maxDrawDistance == null && cachedMaxDrawDistance == null)
                {
                    continue;
                }

                // Update the authored value and its serialized runtime/cache counterpart, but don't create an
                // override when both are absent: those components inherit the class/archetype default.
                var componentUpdated = false;
                if (maxDrawDistance != null)
                {
                    var scaledDistance = maxDrawDistance.Value * multiplier;
                    if (scaledDistance != maxDrawDistance.Value)
                    {
                        export.WriteProperty(new FloatProperty(scaledDistance, "MaxDrawDistance"));
                        componentUpdated = true;
                    }
                }
                if (cachedMaxDrawDistance != null)
                {
                    var scaledDistance = cachedMaxDrawDistance.Value * multiplier;
                    if (scaledDistance != cachedMaxDrawDistance.Value)
                    {
                        export.WriteProperty(new FloatProperty(scaledDistance, "CachedMaxDrawDistance"));
                        componentUpdated = true;
                    }
                }

                if (componentUpdated)
                {
                    updatedComponentCount++;
                }
            }

            MilanLog.Information($"Multiplied culling distances by {multiplier:0.##} on {updatedComponentCount} mesh component(s) and {updatedVolumeEntryCount} CullDistanceVolume table entries across {updatedVolumeCount} volume(s) in {package.FileNameNoExtension}");
            return updatedComponentCount + updatedVolumeCount;
        }

        /// <summary>
        /// Keeps the ported (ME3) lighting on StaticMeshComponents authored with bAcceptsLights=False instead of installing
        /// the UDK bake. ME3 shipped these with no static lighting (volumetric beams, sky domes, mattes), but the UDK export
        /// strips bAcceptsLights so Lightmass lights them anyway. In LE3 a lit LOD makes FStaticMeshSceneProxy require
        /// MATUSAGE_StaticLighting and, for LMET_Vector, MATUSAGE_VectorLightMaps; their materials lack the latter, so the
        /// engine silently swaps in DefaultMaterial. They are still exported, so any that cast shadows still occlude.
        /// </summary>
        private static bool KeepPortedLighting(ExportEntry component) =>
            component.IsA("StaticMeshComponent") && component.GetProperty<BoolProperty>("bAcceptsLights") is { Value: false };

        /// <summary>
        /// Warns about StaticMeshComponents still carrying their ported ME3 lighting on a mesh whose geometry is no longer
        /// ME3's. That happens when porting picks the LE3 (remastered) version of a mesh from the donor DB but the component
        /// was not relit - its package has no UDK bake, is in IgnoredLightingLevels, or had no UDK match. ME3 vertex
        /// lightmaps are per-vertex and ME3 texture lightmaps follow ME3's lightmap UVs, so on the new geometry either one
        /// shows up in game as a scrambled lightmap pattern (e.g. the small cover crates in BioA_MPOcean_100).
        /// </summary>
        private static void WarnOnMismatchedPortedLighting(LevelSpecificPipeline levelPipeline, IMEPackage sourcePackage, IMEPackage destPackage, HashSet<ExportEntry> relitComponents)
        {
            var vertexCounts = new Dictionary<IEntry, uint?>();
            uint? GetVertexCount(IEntry meshEntry, Func<string, PackageCache, IMEPackage> resolver)
            {
                if (vertexCounts.TryGetValue(meshEntry, out var cached))
                    return cached;

                ExportEntry mesh = meshEntry as ExportEntry;
                if (meshEntry is ImportEntry import && !EntryImporter.TryResolveImport(import, out mesh, levelPipeline.Cache, fileResolver: resolver))
                {
                    mesh = null;
                }

                uint? count = mesh == null ? null : ObjectBinary.From<StaticMesh>(mesh).LODModels.FirstOrDefault()?.NumVertices;
                vertexCounts[meshEntry] = count;
                return count;
            }

            // Mesh path -> (components affected, ME3 vertex count, LE3 vertex count)
            var mismatches = new Dictionary<string, (int Count, uint Me3Vertices, uint Le3Vertices)>();
            foreach (var destSmc in destPackage.Exports.Where(x => x.IsA("StaticMeshComponent")))
            {
                if (relitComponents.Contains(destSmc))
                    continue;

                var lod = ObjectBinary.From<StaticMeshComponent>(destSmc).LODData.FirstOrDefault();
                if (lod?.LightMap == null || lod.LightMap.LightMapType == ELightMapType.LMT_None)
                    continue;

                var sourceSmc = sourcePackage.FindExport(destSmc.InstancedFullPath);
                var sourceMesh = sourceSmc?.GetProperty<ObjectProperty>("StaticMesh");
                var destMesh = destSmc.GetProperty<ObjectProperty>("StaticMesh");
                if (sourceMesh == null || destMesh == null || sourceMesh.Value == 0 || destMesh.Value == 0)
                    continue;

                var me3Vertices = GetVertexCount(sourcePackage.GetEntry(sourceMesh.Value), MilanShared.ME3PackageResolver);
                var le3Vertices = GetVertexCount(destPackage.GetEntry(destMesh.Value), MilanShared.LE3PackageResolver);
                if (me3Vertices == null || le3Vertices == null || me3Vertices == le3Vertices)
                    continue;

                var meshPath = destPackage.GetEntry(destMesh.Value).InstancedFullPath;
                mismatches.TryGetValue(meshPath, out var existing);
                mismatches[meshPath] = (existing.Count + 1, me3Vertices.Value, le3Vertices.Value);
            }

            foreach (var (meshPath, (count, me3Vertices, le3Vertices)) in mismatches.OrderByDescending(x => x.Value.Count))
            {
                MilanLog.Warning($"  {destPackage.FileNameNoExtension}: {count} component(s) of {meshPath} kept ME3 lighting, but the mesh is now LE3's ({me3Vertices} -> {le3Vertices} vertices). The lightmap will render scrambled; relight this package or keep the ME3 mesh.",
                    customPrefix: levelPipeline.LogCategory);
            }
        }

        /// <summary>
        /// Imports static lighting for a BioP and its sublevels
        /// </summary>
        public static void ImportStaticLighting(LevelSpecificPipeline level, bool includeSublevels = false)
        {
            var staticLightingPath = Path.Combine(MilanShared.PipelineRoot, "StaticLighting", "Levels", level.BioP, $"{level.BioP}.udk");
            if (File.Exists(staticLightingPath))
            {
                // Import static lighting
                LightingImportSetup setup = new LightingImportSetup()
                {
                    IncludeSubLevels = includeSublevels,
                    UDKMapsBasePath = Directory.GetParent(staticLightingPath).FullName,
                    IgnoredSublevelNames = level.IgnoredLightingLevels,
                    ShouldKeepLightMap = KeepPortedLighting
                };

                StaticLightingImporter.ImportStaticLighting(level.LE3BioP, setup);
            }
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

            var destLevel = destPackage.GetLevel();
            var sourcePersistentLevel = sourcePackage.GetLevelBinary();
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
                        }, out var _);
                    if (badLinks.Any())
                    {
                        // uh oh
                    }
                }
            }

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
            var destLevelBin = destPackage.GetLevelBinary();

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

            // NavRefs, CoverRefs, CrossLevelActors
            // CoverSlot/FireLink packed properties (TurnTarget, CoverTurnTarget, Exposed, Danger, FireLinks) are
            // indices into CoverIndexPairs -> CoverLinkRefs. The slot structs are ported verbatim, so the tables
            // must be ported in the same order or every packed reference dangles (e.g. cover turns fail).
            int RemapLevelRef(int sourceUIndex)
            {
                if (sourceUIndex == 0)
                    return 0; // Cross-level placeholder; resolved through the CrossLevel*GuidRefs maps
                var sourceEntry = sourcePackage.GetEntry(sourceUIndex);
                var destEntry = sourceEntry == null ? null : destPackage.FindEntry(sourceEntry.InstancedFullPath);
                if (destEntry == null)
                {
                    MilanLog.Warning($"  Could not remap level nav/cover reference {sourceEntry?.InstancedFullPath ?? sourceUIndex.ToString()}",
                        customPrefix: levelPipeline.LogCategory);
                    return 0;
                }
                return destEntry.UIndex;
            }

            destLevelBin.CoverLinkRefs = sourcePersistentLevel.CoverLinkRefs.Select(x => RemapLevelRef(x)).ToList();
            destLevelBin.CoverIndexPairs = sourcePersistentLevel.CoverIndexPairs.ToList();
            destLevelBin.CrossLevelCoverGuidRefs = sourcePersistentLevel.CrossLevelCoverGuidRefs;
            destLevelBin.NavRefs = sourcePersistentLevel.NavRefs.Select(x => RemapLevelRef(x)).ToList();
            destLevelBin.NavRefIndicies = sourcePersistentLevel.NavRefIndicies.ToList();
            destLevelBin.CrossLevelNavGuidRefs = sourcePersistentLevel.CrossLevelNavGuidRefs;
            destLevelBin.CrossLevelActors = sourcePersistentLevel.CrossLevelActors.Select(x => RemapLevelRef(x)).ToList();

            destPackage.GetLevel().WriteBinary(destLevelBin);

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
                FixSequencing(destSeq, levelPipeline);
            }

            MilanLevelTools.RebuildPersistentLevelChildren(destLevel);

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

            // If not static lighting build, see if we have static lighting to import
            if (!Program.BuildStaticLighting)
            {
                var relitComponents = new HashSet<ExportEntry>();
                var staticLightingPath = Path.Combine(MilanShared.PipelineRoot, "StaticLighting", "Levels", levelPipeline.BioP, $"{destPackage.FileNameNoExtension}.udk");
                if (File.Exists(staticLightingPath))
                {
                    // Import static lighting
                    LightingImportSetup setup = new LightingImportSetup()
                    {
                        IncludeSubLevels = false,
                        UDKMapsBasePath = Directory.GetParent(staticLightingPath).FullName,
                        IgnoredSublevelNames = levelPipeline.IgnoredLightingLevels,
                        ShouldKeepLightMap = KeepPortedLighting
                    };

                    StaticLightingImporter.ImportStaticLighting(destPackage, setup);
                    relitComponents = setup.RelitComponents;
                }

                // Only here: a -BuildStaticLighting run imports later, from MPLevels, after this package is saved.
                WarnOnMismatchedPortedLighting(levelPipeline, sourcePackage, destPackage, relitComponents);
            }

            // Calculate a very basic texture to instances map
            LevelTools.CalculateTextureToInstancesMap(destPackage, levelPipeline.Cache);

            // Shaders are installed in the shader pipeline now

            MilanLog.Information($"  Saving ported package {packageBaseName}.pcc", customPrefix: levelPipeline.LogCategory);
            destPackage.Save(diskIOSyncLock: MilanShared.DiskIOSyncLock);
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
        /// Fixes sequencing in a level package after porting. This is necessary because the port was done in LE3 and once in LMP those classes no longer exist
        /// </summary>
        /// <param name="main_seq">File main sequence</param>
        /// <param name="levelPipeline">Level pipeline this level is part of</param>
        private static void FixSequencing(ExportEntry main_seq, LevelSpecificPipeline levelPipeline)
        {
            // Find SeqCond_IsGameInfo objects
            // They look for SFXGameInfo_SP which no longer exists.
            var isGameInfos = main_seq.FileRef.Exports.Where(x => !x.IsDefaultObject && x.ClassName == "SFXSeqCond_IsGameInfo").ToList();
            foreach (var igi in isGameInfos)
            {
                var gameType = igi.GetProperty<ObjectProperty>("GameType").ResolveToEntry(main_seq.FileRef);
                var res = "No";
                if (gameType.ObjectName == "SFXGameInfoSP")
                {
                    res = levelPipeline.IsSP ? "Yes" : "No";
                } else
                {
                    MilanLog.Information($"    Assuming game type for {gameType.ObjectName} is MP game type");
                    res = levelPipeline.IsSP ? "No" : "Yes";
                }
                MilanLog.Information($"    Force-branching SeqCond_IsGameInfo {igi.InstancedFullPath}", customPrefix: levelPipeline.LogCategory);
                KismetHelper.SkipSequenceElement(igi, res);
                KismetHelper.RemoveFromSequence(igi, true);
            }
        }
    }
}
