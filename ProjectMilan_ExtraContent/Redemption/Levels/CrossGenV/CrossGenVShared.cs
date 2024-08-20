using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;
using System.Numerics;
using System.Text;
using System.Threading.Channels;
using System.Threading.Tasks;
using LegendaryExplorerCore.GameFilesystem;
using LegendaryExplorerCore.Gammtek.Extensions;
using LegendaryExplorerCore.Gammtek.Extensions.Collections.Generic;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Packages.CloningImportingAndRelinking;
using LegendaryExplorerCore.Pathing;
using LegendaryExplorerCore.Shaders;
using LegendaryExplorerCore.Unreal;
using LegendaryExplorerCore.Unreal.BinaryConverters;
using LegendaryExplorerCore.Unreal.ObjectInfo;
using LegendaryExplorerCore.UnrealScript.Language.Tree;
using ProjectMilan;
using ProjectMilan_ExtraContent.Shared;
using ProjectMilanCore;
using NameProperty = LegendaryExplorerCore.Unreal.NameProperty;

namespace ProjectMilan_ExtraContent.Redemption.Levels.CrossGenV
{
    internal class CrossGenVShared
    {
        public static ECLevelInfo[] CrossgenLevels =
        [
            new ECLevelInfo()
            {
                MapName = "BioP_MPPSTropical",
                Enabled = true,
                LevelNameString = new()
                {
                    { MELocalization.INT, "Pinnacle Station: Tropical"},
                },
                LevelDescriptionString = new()
                {
                    { MELocalization.INT , "Tropical Map in Pinnacle Station Simulator"},
                },
                GAWMapPosition = new Vector2(515, 200), // Placeholder
                GAWMapSubtitle = new()
                {
                    { MELocalization.INT, "Pinnacle Station"}
                },
                LevelFilesMap = new()
                {
                    {"BIOA_PRC2_CCTHAI", "BioA_PSTropical"},
                    {"BIOA_PRC2_CCTHAI_L", "BioA_PSTropical_Lighting"},
                    {"BIOA_PRC2_CCTHAI_DSG", "BioD_PSTropical"},
                    {"BIOA_PRC2_CCTHAI01_LAY","BioD_PSTropical_LAY1"},
                    {"BIOA_PRC2_CCTHAI02_LAY","BioD_PSTropical_LAY2"},
                    {"BIOA_PRC2_CCTHAI03_LAY","BioD_PSTropical_LAY3"},
                    {"BIOA_PRC2_CCTHAI04_LAY","BioD_PSTropical_LAY4"},
                    {"BIOA_PRC2_CCTHAI05_LAY","BioD_PSTropical_LAY5"},
                    {"BIOA_PRC2_CCTHAI06_LAY","BioD_PSTropical_LAY6"}
                    // "BIOA_PRC2_CCTHAI06_SND", // Don't know how this can be ported across games
                },
                StartLocation = new Vector3(879,-22803,-2541),
                KillZ = -2900,
            },
            new ECLevelInfo()
            {
                MapName = "BioP_MPPSSub",
                Enabled = false,
                LevelNameString = new()
                {
                    { MELocalization.INT, "Pinnacle Station: Subterranean"}, // Todo: Learn how to spell
                },
                LevelDescriptionString = new()
                {
                    { MELocalization.INT , "Subterranean Map in Pinnacle Station Simulator"},
                },
                GAWMapPosition = new Vector2(515, 200), // Placeholder
                GAWMapSubtitle = new()
                {
                    { MELocalization.INT, "Pinnacle Station"}
                },
                LevelFilesMap = new()
                {
                    {"BIOA_PRC2_CCCAVE", "BioA_PSSub"},
                    {"BIOA_PRC2_CCCAVE_L", "BioA_PSSub_Lighting"},
                    {"BIOA_PRC2_CCCAVE_DSG", "BioD_PSSub"},
                    {"BIOA_PRC2_CCCAVE01_LAY","BioD_PSSub_LAY1"},
                    {"BIOA_PRC2_CCCAVE02_LAY","BioD_PSSub_LAY2"},
                    {"BIOA_PRC2_CCCAVE03_LAY","BioD_PSSub_LAY3"},
                    {"BIOA_PRC2_CCCAVE04_LAY","BioD_PSSub_LAY4"},
                },
                StartLocation = new Vector3(879,-22803,-2541),
                KillZ = -2900,
            },
            new ECLevelInfo()
            {
                MapName = "BioP_MPPSWarehouse",
                Enabled = false,
                LevelNameString = new()
                {
                    { MELocalization.INT, "Pinnacle Station: Warehouse"}, // Todo: Learn how to spell
                },
                LevelDescriptionString = new()
                {
                    { MELocalization.INT , "Warehouse Map in Pinnacle Station Simulator"},
                },
                GAWMapPosition = new Vector2(515, 200), // Placeholder
                GAWMapSubtitle = new()
                {
                    { MELocalization.INT, "Pinnacle Station"}
                },
                LevelFilesMap = new()
                {
                    {"BIOA_PRC2_CCCRATE", "BioA_PSWarehouse"},
                    {"BIOA_PRC2_CCCRATE_L", "BioA_PSWarehouse_Lighting"},
                    {"BIOA_PRC2_CCCRATE_DSG", "BioD_PSWarehouse"},
                    {"BIOA_PRC2_CCCRATE01_LAY","BioD_PSWarehouse_LAY1"},
                    {"BIOA_PRC2_CCCRATE02_LAY","BioD_PSWarehouse_LAY2"},
                },
                StartLocation = new Vector3(15041,-26485,-2899),
                KillZ = -6000,
            }
        ];

        private static string _sourceFilesFolder;
        public static string SourceFilesFolder
        {
            get
            {
                if (_sourceFilesFolder == null)
                {
                    var modLibrary = Directory.GetParent(BaseBuildSettings.OutputModPath).Parent.Parent;
                    var psPath = Path.Combine(modLibrary.FullName, "LE1", "Pinnacle Station DLC");
                    if (!Directory.Exists(psPath))
                    {
                        throw new Exception("Pinnacle Station DLC must be imported into your Mod Manager library for build");
                    }

                    _sourceFilesFolder = Path.Combine(psPath, "DLC_MOD_Vegas", "CookedPCConsole");
                }

                return _sourceFilesFolder;
            }
        }

        public static void BuildLevel(ECLevelInfo info, TieredPackageCache parent)
        {
            // 1. Make BioP
            MilanLog.Information($@"Beginning crossgen level port: {info.MapName}", customPrefix: info.LogCategory);
            info.Cache = parent.ChainNewCache();

            info.OutputPath = Path.Combine(BaseBuildSettings.OutputModPath, @"CookedPCConsole", @"Levels", info.MapName);
            Directory.CreateDirectory(info.OutputPath);

            // Create BioP
            var templateBioP = Path.Combine(SharedECPipelines.ECPipelineRoot, "Redemption", "Assets", "Templates", "MPLevel.pcc");
            var biopPath = Path.Combine(info.OutputPath, info.MapName + ".pcc");
            File.Copy(templateBioP, biopPath, true);
            info.BioP = MEPackageHandler.OpenMEPackage(biopPath);
            info.BioP.LECLTagData.ImportHintFiles.Add(MilanShared.MP_STARTUP_FILENAME); // Hint this for importing.
            info.BioP.LECLTagData.IsPostLoadFile = false;

            info.BioP.replaceName(info.BioP.FindNameOrAdd("MPTemplate"), info.MapName);

            // Load cross package map
            // This could be done in one step possibly, but might be useful to preload everything.
            info.CrossPackageMapping = new Dictionary<IMEPackage, IMEPackage>();
            foreach (var level in info.LevelFilesMap)
            {
                // Open source
                var srcPath = Path.Combine(SourceFilesFolder, level.Key + ".pcc");
                var src = MEPackageHandler.OpenMEPackage(srcPath);

                // Open dest
                var destPath = Path.Combine(info.OutputPath, level.Value + ".pcc");
                MEPackageHandler.CreateEmptyLevel(destPath, MEGame.LE3);
                var dest = MEPackageHandler.OpenMEPackage(destPath);
                dest.LECLTagData.ImportHintFiles.Add(MilanShared.MP_STARTUP_FILENAME); // Hint this for importing.
                dest.LECLTagData.IsPostLoadFile = false;

                info.CrossPackageMapping[src] = dest;
            }

            // Port assets across
            foreach (var level in info.CrossPackageMapping)
            {
                // Open source
                var src = level.Key;
                var dest = level.Value;
                PortCrossgenLevel(info, src, dest);
            }

            ConfigureBioP(info);
            info.BioP.Save(); // Commit the file

            RedemptionShared.AddLevelToConfig(info);
            info.Cleanup();
        }

        private static void ConfigureBioP(ECLevelInfo info)
        {
            MilanLog.Information($@"Configuring LE3 BioP", customPrefix: info.LogCategory);

            // Add SP start location for testing.
            //if (info.IsSP)
            //{
            //    MilanShared.CreateSPStartLocation(info.LE3BioP, info.SPStartLocation);
            //}
            //else
            //{
            MilanLevelTools.SetMPStartLocations(info.BioP, info.StartLocation);
            //}

            int lskIndex = 1;
            var destPersistentLevel = info.BioP.GetLevel();

            // Add all LSKs for items that are in our level cache
            foreach (var ol in info.CrossPackageMapping.Values)
            {
                var lsk = ExportCreator.CreateExport(info.BioP, "LevelStreamingKismet", "LevelStreamingKismet", destPersistentLevel, cache: info.Cache);
                lsk.WriteProperty(new NameProperty(MilanLevelTools.GetLevelFileName(ol.FileNameNoExtension), "PackageName"));
            }
            MilanLevelTools.RebuildStreamingLevels(info.BioP, info.LogCategory);

            // Create global biotriggerstream
            var bts = info.BioP.FindExport("TheWorld.PersistentLevel.BioTriggerStream_0");
            var ss = bts.GetProperty<ArrayProperty<StructProperty>>("StreamingStates");
            var chunks = ss[0].GetProp<ArrayProperty<NameProperty>>("VisibleChunkNames");
            foreach (var ol in info.CrossPackageMapping.Values)
            {
                chunks.Add(new NameProperty(ol.FileNameNoExtension));
            }
            bts.WriteProperty(ss);

            // Set the KillZ
            info.BioP.FindExport(@"TheWorld.PersistentLevel.BioWorldInfo_0").WriteProperty(new FloatProperty(info.KillZ, "KillZ"));

            // Set game modes
            MilanLevelTools.SetupHordeModes(info.BioP, info.MapName == "MPLobby");

            // Default post processing
            //var ppStruct = info.ME3BioP.GetBioWorldInfo().GetProperty<StructProperty>("DefaultPostProcessSettings");
            //if (ppStruct != null)
            //{
            //    info.BioP.GetBioWorldInfo().WriteProperty(ppStruct);
            //}

            // Set AdditionalPackagesToCook
            (info.BioP as MEPackage).AdditionalPackagesToCook.ReplaceAll(info.CrossPackageMapping.Select(x => x.Value.FileNameNoExtension));

            MilanLevelTools.RebuildPersistentLevelChildren(destPersistentLevel);
        }

        public static IMEPackage PortCrossgenLevel(ECLevelInfo info, IMEPackage sourcePackage, IMEPackage destPackage)
        {
            var packageBaseName = Path.GetFileNameWithoutExtension(sourcePackage.FileNameNoExtension);
            MilanLog.Information($"Porting level file {packageBaseName}.pcc", customPrefix: info.LogCategory);


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

                    // Game1 Specific Stuff.
                    if (exp.ClassName == "BioSquadCombat") return false;
                    if (exp.ClassName == "BioInert") return false;
                    if (exp.ClassName == "AmbientSound") return false;
                    if (exp.ClassName == "BioPawn") return false;
                    if (exp.ClassName == "BioSunActor") return false;
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
                    MilanLog.Information($"  Porting {sm.InstancedFullPath}", customPrefix: info.LogCategory);
                    var badLinks = EntryImporter.ImportAndRelinkEntries(
                        EntryImporter.PortingOption.CloneAllDependencies,
                        sm, destPackage, destLevel, true,
                        new RelinkerOptionsPackage()
                        {
                            IsCrossGame = true,
                            TargetGameDonorDB = MilanShared.LE3ObjectDB,
                            Cache = info.Cache,
                            PortExportsAsImportsWhenPossible = true,
                            PortImportsMemorySafe = true,
                            DestinationCustomImportFileResolver = MilanShared.LE3PackageResolver,
                            SourceCustomImportFileResolver = MilanShared.ME3PackageResolver,
                            // Not supported in EC right now
                            // CustomDonorImporter = DonorBuilderPipeline.MaterialDonorImporter
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
                    MilanLog.Information($"  Fixing collision data for {ifp}", customPrefix: info.LogCategory);

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
                        BrushComponent bc = ObjectBinary.From(export, info.Cache) as BrushComponent;

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
                    customPrefix: info.LogCategory);
                EntryImporter.ImportAndRelinkEntries(EntryImporter.PortingOption.ReplaceSingularWithRelink, sourcemodel,
                    destPackage, destmodel, true, new RelinkerOptionsPackage()
                    {
                        Cache = info.Cache,
                        DestinationCustomImportFileResolver = MilanShared.LE3PackageResolver,
                        // SourceCustomImportFileResolver = MilanShared.ME3PackageResolver,
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
                        customPrefix: info.LogCategory);
                    EntryImporter.ImportAndRelinkEntries(EntryImporter.PortingOption.CloneAllDependencies, sModelComp,
                        destPackage, destLevel, true, new RelinkerOptionsPackage()
                        {
                            Cache = info.Cache,
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

            // Torture! Pure torture.
            // Bring over cover
            if (sourcePersistentLevel.CoverListStart > 0)
            {
                destLevelBin.CoverListStart = destPackage.FindExport(sourcePackage.GetUExport(sourcePersistentLevel.CoverListStart).InstancedFullPath).UIndex;
                destLevelBin.CoverListEnd = destPackage.FindExport(sourcePackage.GetUExport(sourcePersistentLevel.CoverListEnd).InstancedFullPath).UIndex;

                GenerateCoverSlots(destPackage.FindExport(sourcePackage.GetUExport(sourcePersistentLevel.CoverListStart).InstancedFullPath), destLevelBin, info.Cache);

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
            //var srcSeq = sourcePackage.FindExport("TheWorld.PersistentLevel.Main_Sequence");
            //var destSeq = destPackage.FindExport("TheWorld.PersistentLevel.Main_Sequence");

            //if (srcSeq != null && destSeq != null)
            //{
            //    MilanLog.Information("  Porting Main_Sequence", customPrefix: info.LogCategory);
            //    var badLinks = EntryImporter.ImportAndRelinkEntries(
            //        EntryImporter.PortingOption.ReplaceSingularWithRelink, srcSeq, destPackage, destSeq
            //        , true, new RelinkerOptionsPackage()
            //        {
            //            IsCrossGame = true,
            //            TargetGameDonorDB = MilanShared.LE3ObjectDB,
            //            Cache = info.Cache,
            //            PortExportsAsImportsWhenPossible = true,
            //            DestinationCustomImportFileResolver = MilanShared.LE3PackageResolver,
            //            SourceCustomImportFileResolver = MilanShared.ME3PackageResolver,
            //        }, out var _);
            //}

            MilanLevelTools.RebuildPersistentLevelChildren(destLevel);

            /*
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
            }*/

            // Calculate a very basic texture to instances map
            LevelTools.CalculateTextureToInstancesMap(destPackage, info.Cache);

            MilanLog.Information($"  Saving ported package {destPackage.FileNameNoExtension}.pcc", customPrefix: info.LogCategory);
            destPackage.Save();
            MilanShared.RefreshMilanFiles = true;

            // Detect remaining shaders
            //var brokenMaterials = ShaderCacheManipulator.GetBrokenMaterials(destPackage);
            //foreach (var v in brokenMaterials)
            //{
            //    var matchingME3 = sourcePackage.FindExport(v.InstancedFullPath);
            //    if (matchingME3 != null)
            //    {
            //        if (levelPipeline.MaterialsNeedingDonors.All(x => x.InstancedFullPath != matchingME3.InstancedFullPath))
            //        {
            //            levelPipeline.MaterialsNeedingDonors.Add(matchingME3);
            //        }
            //    }
            //}

            return destPackage;
        }

        /// <summary>
        /// LE1 doesn't use CoverSlotMarker, but we have enough information to generate them from the slots.
        /// </summary>
        /// <param name="coverlink"></param>
        /// <param name="destLevelBin"></param>
        /// <exception cref="NotImplementedException"></exception>
        private static void GenerateCoverSlots(ExportEntry coverlink, Level destLevelBin, PackageCache cache)
        {
            while (coverlink != null)
            {
                var slots = coverlink.GetProperty<ArrayProperty<StructProperty>>("Slots");
                int slotIdx = 0;

                List<ExportEntry> slotChain = new List<ExportEntry>();
                foreach (var slot in slots)
                {
                    var sm = slot.GetProp<ObjectProperty>("SlotMarker");
                    if (sm.Value != 0)
                        continue; // Already set, maybe from something else.

                    var csm = GenerateCoverSlotMarker(coverlink, slotIdx, slot, cache);
                    sm.Value = csm.UIndex;
                    slotChain.Add(csm);
                    destLevelBin.Actors.Add(sm.Value);
                    PathTools.CreateReachSpec(coverlink, true, csm, "ReachSpec", 40, 95, cache: cache);
                    slotIdx++;
                }

                // Generate reachspecs between slots. There must have at least 2 nodes in the chain
                if (slotChain.Count > 1)
                {
                    for (int i = 0; i < slotChain.Count - 1; i++)
                    {
                        PathTools.CreateReachSpec(slotChain[i], true, slotChain[i + 1], "SlotToSlotReachSpec", 40, 95,
                            cache: cache);
                    }
                }


                coverlink.WriteProperty(slots);
                coverlink = coverlink.GetProperty<ObjectProperty>("NextCoverLink")?.ResolveToExport(coverlink.FileRef, null);
            }
        }

        /// <summary>
        /// Generates a new CoverSlotMarker actor using the given info info
        /// </summary>
        /// <param name="owningCoverlink"></param>
        /// <param name="info"></param>
        /// <returns></returns>
        private static ExportEntry GenerateCoverSlotMarker(ExportEntry owningCoverlink, int slotIdx, StructProperty info, PackageCache cache)
        {
            // CoverSlotMarker
            var csm = ExportCreator.CreateExport(owningCoverlink.FileRef, "CoverSlotMarker", "CoverSlotMarker", owningCoverlink.Parent, createWithStack: true, cache: cache);
            var csmProps = csm.GetProperties();

            // Cylinder Component
            var cylinderComp = ExportCreator.CreateExport(owningCoverlink.FileRef, "CylinderComponent", "CylinderComponent", csm, prePropBinary: new byte[8], cache: cache);
            cylinderComp.ObjectFlags |= UnrealFlags.EObjectFlags.Transactional;
            cylinderComp.Archetype = GetImportArchetype(owningCoverlink.FileRef, "Engine", $"Default__CoverSlotMarker.CollisionCylinder");
            cylinderComp.WriteProperty(new ObjectProperty(0, "ReplacementPrimitive"));
            PropertyCollection channels = new PropertyCollection();
            channels.Add(new BoolProperty(true, "bInitialized"));
            channels.Add(new BoolProperty(true, "Dynamic"));
            cylinderComp.WriteProperty(new StructProperty("LightingChannelContainer", channels, "LightingChannels"));

            // Set CSM properties.
            var coverlinkProps = owningCoverlink.GetProperties();

            csmProps.AddOrReplaceProp(CreateCoverInfo(owningCoverlink, slotIdx, "OwningSlot"));
            csmProps.AddOrReplaceProp(new ArrayProperty<ObjectProperty>("PathList")); // Empty list initially... not sure how we can compute this 

            csmProps.AddOrReplaceProp(CommonStructs.GuidProp(Guid.NewGuid(), "NavGuid"));
            csmProps.AddOrReplaceProp(new ObjectProperty(cylinderComp, "CylinderComponent"));
            csmProps.AddOrReplaceProp(CreateCylinder(40, 95, "MaxPathSize"));

            if (coverlinkProps.GetProp<IntProperty>("visitedWeight") is IntProperty ip2)
                csmProps.AddOrReplaceProp(ip2);
            if (coverlinkProps.GetProp<IntProperty>("NetworkID") is IntProperty ip1)
                csmProps.AddOrReplaceProp(ip1);

            // ApproximateLineOfFire must be computed... someday

            if (coverlinkProps.GetProp<BoolProperty>("bHasCrossLevelPaths") is BoolProperty bp1)
                csmProps.AddOrReplaceProp(bp1);

            var locOffset = info.GetProp<StructProperty>("LocationOffset");
            if (owningCoverlink.GetProperty<StructProperty>("Location") is var lsp)
            {
                var loc = CommonStructs.Vector3Prop(locOffset.GetProp<FloatProperty>("X"), locOffset.GetProp<FloatProperty>("Y"), locOffset.GetProp<FloatProperty>("Z"), "Location");

                // We have to do this to return clone or we will edit the original and that will get written back
                loc.GetProp<FloatProperty>("X").Value += lsp.GetProp<FloatProperty>("X");
                loc.GetProp<FloatProperty>("Y").Value += lsp.GetProp<FloatProperty>("Y");
                loc.GetProp<FloatProperty>("Z").Value += lsp.GetProp<FloatProperty>("Z");
                csmProps.AddOrReplaceProp(loc);
            }


            //var rotOffset = info.GetProp<StructProperty>("RotationOffset");
            //var rot = CommonStructs.RotatorProp(rotOffset.GetProp<IntProperty>("Pitch"), rotOffset.GetProp<IntProperty>("Yaw"), rotOffset.GetProp<IntProperty>("Roll"), "Rotation");
            //if (owningCoverlink.GetProperty<StructProperty>("Rotation") is var rsp)
            //{
            //    // We have to do this to return clone or we will edit the original and that will get written back
            //    rot.GetProp<IntProperty>("Pitch").Value += rsp.GetProp<IntProperty>("Pitch");
            //    rot.GetProp<IntProperty>("Yaw").Value += rsp.GetProp<IntProperty>("Yaw");
            //    rot.GetProp<IntProperty>("Roll").Value += rsp.GetProp<IntProperty>("Roll");
            //}

            //csmProps.AddOrReplaceProp(rot); // Might need to set offset from the original rotation rather than 0

            csmProps.AddOrReplaceProp(new ObjectProperty(owningCoverlink, "Owner"));
            csmProps.AddOrReplaceProp(new NameProperty("CoverSlotMarker", "Tag"));
            csmProps.AddOrReplaceProp(new ObjectProperty(cylinderComp, "CollisionComponent"));
            csm.WriteProperties(csmProps);
            return csm;
        }

        internal static StructProperty CreateCoverInfo(ExportEntry link, int slot, NameReference name)
        {
            PropertyCollection pc = new PropertyCollection();
            pc.AddOrReplaceProp(new ObjectProperty(link, "Link"));
            pc.AddOrReplaceProp(new IntProperty(slot, "SlotIdx"));
            return new StructProperty("CoverInfo", pc, name, true);
        }

        internal static StructProperty CreateCylinder(float radius, float height, NameReference name)
        {
            PropertyCollection pc = new PropertyCollection();
            pc.AddOrReplaceProp(new FloatProperty(radius, "Radius"));
            pc.AddOrReplaceProp(new FloatProperty(height, "Height"));
            return new StructProperty("Cylinder", pc, name, false);
        }

        // FROM LEX
        internal static IEntry GetImportArchetype(IMEPackage package, string packageFile, string ifp)
        {
            IEntry result = package.FindExport($"{packageFile}.{ifp}");
            if (result != null)
                return result;

            var file = $"{packageFile}.pcc";
            var fullPath = Path.Combine(MEDirectories.GetCookedPath(package.Game), file);
            using var lookupPackage = MEPackageHandler.UnsafePartialLoad(fullPath, x => false);
            var entry = lookupPackage.FindExport(ifp) as IEntry;
            if (entry == null)
                Debugger.Break();

            Stack<IEntry> children = new Stack<IEntry>();
            children.Push(entry); // Must port at least the found IFP.
            while (entry.Parent != null && package.FindEntry(entry.ParentInstancedFullPath) == null)
            {
                children.Push(entry.Parent);
                entry = entry.Parent;
            }

            // Create imports from top down.
            var packageExport = (IEntry)ExportCreator.CreatePackageExport(package, packageFile);

            // This doesn't work if the part of the parents already exist.
            var attachParent = packageExport;
            foreach (var item in children)
            {
                ImportEntry imp = new ImportEntry(item as ExportEntry, packageExport.UIndex, package);
                imp.idxLink = attachParent.UIndex;
                package.AddImport(imp);
                attachParent = imp;
                result = imp;
            }

            return result;
        }
    }
}
