using System;
using System.Collections.Generic;
using System.Linq;
using System.Reflection;
using System.Text;
using System.Threading.Tasks;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Packages.CloningImportingAndRelinking;
using LegendaryExplorerCore.Shaders;
using LegendaryExplorerCore.Unreal;
using LegendaryExplorerCore.Unreal.BinaryConverters;
using LegendaryExplorerCore.Unreal.ObjectInfo;
using ProjectMilan.Pipelines.Shared;
using ProjectMilan.Utility;

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


            var collisionCylinder = ExportCreator.CreateExport(package, "CylinderComponent", "CylinderComponent", startLoc);
            collisionCylinder.WritePrePropsAndProperties(new byte[4], collisionCylinder.GetProperties()); // Set up pre-prop binary

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
                    var badLinks = EntryImporter.ImportAndRelinkEntries(EntryImporter.PortingOption.CloneAllDependencies,
                        sm, destPackage, destLevel, true,
                        new RelinkerOptionsPackage()
                        {
                            IsCrossGame = true,
                            TargetGameDonorDB = MilanShared.LE3ObjectDB,
                            Cache = levelPipeline.Cache,
                            PortExportsAsImportsWhenPossible = true,
                            CustomImportFileResolver = MilanShared.ImportResolver,
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
                if (export.HasStack)
                {
                    // Copy stack data. Not sure if this does anything useful.
                    var orig = sourcePackage.FindExport(export.InstancedFullPath);
                    if (orig == null)
                        continue;
                    var binPreOrig = orig.GetPrePropBinary();
                    var binPost = export.GetPrePropBinary();
                    binPost[0x10] = binPreOrig[0x10];
                    binPost[0x11] = binPreOrig[0x11];
                    export.WritePrePropsAndProperties(binPost, export.GetProperties());
                }

                var cachedDataVer = export.GetProperty<IntProperty>("CachedPhysBrushDataVersion") ?? export.GetProperty<IntProperty>("PreCachedPhysDataVersion");
                if (cachedDataVer != null && cachedDataVer == 34079634) // OT version
                {
                    MilanLog.Information($"  Fixing collision data for {export.InstancedFullPath}", customPrefix: levelPipeline.LogCategory);

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
                MilanLog.Information($"  Porting level model {sourcemodel.InstancedFullPath}", customPrefix: levelPipeline.LogCategory);
                EntryImporter.ImportAndRelinkEntries(EntryImporter.PortingOption.ReplaceSingularWithRelink, sourcemodel,
                    destPackage, destmodel, true, new RelinkerOptionsPackage()
                    {
                        Cache = levelPipeline.Cache,
                        CustomImportFileResolver = MilanShared.ImportResolver,
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
                    MilanLog.Information($"  Porting level model component {sModelComp.InstancedFullPath}", customPrefix: levelPipeline.LogCategory);
                    EntryImporter.ImportAndRelinkEntries(EntryImporter.PortingOption.CloneAllDependencies, sModelComp, 
                        destPackage, destLevel, true, new RelinkerOptionsPackage()
                        {
                            Cache = levelPipeline.Cache,
                            CustomImportFileResolver = MilanShared.ImportResolver,
                            TargetGameDonorDB = MilanShared.LE3ObjectDB,
                            PortExportsAsImportsWhenPossible = true,
                        }, out var newModelComp);
                    modelComponents.Add(newModelComp as ExportEntry);
                }

                destLevelBin.ModelComponents = modelComponents.Select(x => x.UIndex).ToArray();
            }
            else
            {
                destLevelBin.Model = 0;
            }

            // Bring over cover
            if (sourcePersistentLevel.CoverListStart > 0)
            {
                destLevelBin.CoverListStart =
                    destPackage.FindExport(sourcePackage.GetUExport(sourcePersistentLevel.CoverListStart).InstancedFullPath).UIndex;
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
                destLevelBin.NavListStart = destPackage
                    .FindExport(sourcePackage.GetUExport(sourcePersistentLevel.NavListStart).InstancedFullPath).UIndex;
                destLevelBin.NavListEnd = destPackage
                    .FindExport(sourcePackage.GetUExport(sourcePersistentLevel.NavListEnd).InstancedFullPath).UIndex;
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
                var badLinks = EntryImporter.ImportAndRelinkEntries(EntryImporter.PortingOption.ReplaceSingularWithRelink, srcSeq, destPackage, destSeq
                    , true, new RelinkerOptionsPackage()
                    {
                        IsCrossGame = true,
                        TargetGameDonorDB = MilanShared.LE3ObjectDB,
                        Cache = levelPipeline.Cache,
                        PortExportsAsImportsWhenPossible = true,
                        CustomImportFileResolver = MilanShared.ImportResolver,
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

            // Correct shaders
            SharedMaterialDonor.UpdateMaterialShaders(destPackage);

            MilanLog.Information($"  Saving ported package {packageBaseName}.pcc", customPrefix: levelPipeline.LogCategory);
            destPackage.Save();
            MilanShared.RefreshMilanFiles = true;

            // Detect remaining shaders
            var brokenMaterials = ShaderCacheManipulator.GetBrokenMaterials(destPackage);
            foreach (var v in brokenMaterials)
            {
                var matchingME3 = sourcePackage.FindExport(v.InstancedFullPath);
                if (levelPipeline.MaterialsNeedingDonors.All(x => x.InstancedFullPath != matchingME3.InstancedFullPath))
                {
                    levelPipeline.MaterialsNeedingDonors.Add(matchingME3);
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
                var mpContent = bioP.FindEntry("SFXGameMPContentDLC_Shared_MP") ?? ExportCreator.CreatePackageExport(bioP, "SFXGameMPContentDLC_Shared_MP");
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
                var mpContent = bioP.FindEntry("SFXGameMPContent") ?? ExportCreator.CreatePackageExport(bioP, "SFXGameMPContent");

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
    }
}
