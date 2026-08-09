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

            // NavRefs, CoverRefs
            // CrossLevelActors
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
            if (!Program.Settings.IsStaticLightingBuild)
            {
                var staticLightingPath = Path.Combine(MilanShared.PipelineRoot, "StaticLighting", "Levels", levelPipeline.BioP, $"{destPackage.FileNameNoExtension}.udk");
                if (File.Exists(staticLightingPath))
                {
                    // Import static lighting
                    LightingImportSetup setup = new LightingImportSetup()
                    {
                        IncludeSubLevels = false,
                        UDKMapsBasePath = Directory.GetParent(staticLightingPath).FullName
                    };

                    StaticLightingImporter.ImportStaticLighting(destPackage, setup);
                }
            }

            // Calculate a very basic texture to instances map
            LevelTools.CalculateTextureToInstancesMap(destPackage, levelPipeline.Cache);

            // Install shaders we have compiled
            MilanShaders.InstallCompiledShadersToPackage(destPackage, levelPipeline.LogCategory);

            MilanLog.Information($"  Saving ported package {packageBaseName}.pcc", customPrefix: levelPipeline.LogCategory);
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
    }
}
