using LegendaryExplorerCore.GameFilesystem;
using LegendaryExplorerCore.Gammtek.Extensions;
using LegendaryExplorerCore.Gammtek.Extensions.Collections.Generic;
using LegendaryExplorerCore.Helpers;
using LegendaryExplorerCore.Misc;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Packages.CloningImportingAndRelinking;
using LegendaryExplorerCore.Pathing;
using LegendaryExplorerCore.Shaders;
using LegendaryExplorerCore.Unreal;
using LegendaryExplorerCore.Unreal.BinaryConverters;
using LegendaryExplorerCore.Unreal.ObjectInfo;
using LegendaryExplorerCore.UnrealScript;
using ProjectMilan;
using ProjectMilan.Utility;
using ProjectMilan_ExtraContent.Classes;
using ProjectMilan_ExtraContent.Shared;
using ProjectMilanCore;
using System.Diagnostics;
using System.Numerics;
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
                    {"BIOA_PRC2_CCTHAI", "BioA_MPPSTropical"},
                    {"BIOA_PRC2_CCTHAI_L", "BioA_MPPSTropical_Lighting"},
                    {"BIOA_PRC2_CCTHAI_DSG", "BioD_MPPSTropical"},
                    {"BIOA_PRC2_CCTHAI01_LAY","BioD_MPPSTropical_LAY1"},
                    {"BIOA_PRC2_CCTHAI02_LAY","BioD_MPPSTropical_LAY2"},
                    {"BIOA_PRC2_CCTHAI03_LAY","BioD_MPPSTropical_LAY3"},
                    {"BIOA_PRC2_CCTHAI04_LAY","BioD_MPPSTropical_LAY4"},
                    {"BIOA_PRC2_CCTHAI05_LAY","BioD_MPPSTropical_LAY5"},
                    {"BIOA_PRC2_CCTHAI06_LAY","BioD_MPPSTropical_LAY6"}
                    // "BIOA_PRC2_CCTHAI06_SND", // Don't know how this can be ported across games
                },
                StartLocation = new Vector3(879,-22803,-2541),
                KillZ = -27000,
            },
            new ECLevelInfo()
            {
                MapName = "BioP_MPPSSub",
                Enabled = true,
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
                    {"BIOA_PRC2_CCCAVE", "BioA_MPPSSub"},
                    {"BIOA_PRC2_CCCAVE_L", "BioA_MPPSSub_Lighting"},
                    {"BIOA_PRC2_CCCAVE_DSG", "BioD_MPPSSub"},
                    {"BIOA_PRC2_CCCAVE01_LAY","BioD_MPPSSub_LAY1"},
                    {"BIOA_PRC2_CCCAVE02_LAY","BioD_MPPSSub_LAY2"},
                    {"BIOA_PRC2_CCCAVE03_LAY","BioD_MPPSSub_LAY3"},
                    {"BIOA_PRC2_CCCAVE04_LAY","BioD_MPPSSub_LAY4"},
                },
                StartLocation = new Vector3(-16365, -25733,-2742),
                KillZ = -27000,
            },
            new ECLevelInfo()
            {
                MapName = "BioP_MPPSWarehouse",
                Enabled = true,
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
                    {"BIOA_PRC2_CCCRATE", "BioA_MPPSWarehouse"},
                    {"BIOA_PRC2_CCCRATE_L", "BioA_MPPSWarehouse_Lighting"},
                    {"BIOA_PRC2_CCCRATE_DSG", "BioD_MPPSWarehouse"},
                    {"BIOA_PRC2_CCCRATE01_LAY","BioD_MPPSWarehouse_LAY1"},
                    {"BIOA_PRC2_CCCRATE02_LAY","BioD_MPPSWarehouse_LAY2"},
                },
                ExtraBioPObjects = [
                    "BIOG_APL_MASTER_MATERIAL.APL__MASTER__Mat" // Required for the portable stairs meshes
                ],
                StartLocation = new Vector3(15872,-23390,-5493),
                KillZ = -27000,
            },
            new ECLevelInfo()
            {
                MapName = "BioP_MPPSLava",
                Enabled = true,
                LevelNameString = new()
                {
                    { MELocalization.INT, "Pinnacle Station: Volcano"},
                },
                LevelDescriptionString = new()
                {
                    { MELocalization.INT , "Volcano Map in Pinnacle Station Simulator"},
                },
                GAWMapPosition = new Vector2(515, 200), // Placeholder
                GAWMapSubtitle = new()
                {
                    { MELocalization.INT, "Pinnacle Station"}
                },
                LevelFilesMap = new()
                {
                    {"BIOA_PRC2_CCLAVA", "BioA_MPPSLava"},
                    {"BIOA_PRC2_CCLAVA_CROSSGEN", "BioA_MPPSLava_CrossGen"},
                    {"BIOA_PRC2_CCLAVA_L", "BioA_MPPSLava_Lighting"},
                    {"BIOA_PRC2_CCLAVA_DSG", "BioD_MPPSLava"},
                },
                StartLocation = new Vector3(27220,-23510,-25845),
                KillZ = -27500,
            },
            new ECLevelInfo()
            {
                MapName = "BioP_MPPSAhern",
                Enabled = true,
                LevelNameString = new()
                {
                    { MELocalization.INT, "Pinnacle Station: Ahern"},
                },
                LevelDescriptionString = new()
                {
                    { MELocalization.INT , "Ahern's Mission Map in Pinnacle Station Simulator"},
                },
                GAWMapPosition = new Vector2(515, 200), // Placeholder
                GAWMapSubtitle = new()
                {
                    { MELocalization.INT, "Pinnacle Station"}
                },
                LevelFilesMap = new()
                {
                    {"BIOA_PRC2_CCAHERN", "BioA_MPPSAhern"},
                    {"BIOA_PRC2_CCAHERN_ART", "BioA_MPPSAhern2"},
                    {"BIOA_PRC2_CCAHERN_DSG", "BioD_MPPSAhern"},
                },
                StartLocation = new Vector3(-39749,-23403,-2472),
                KillZ = -3493,
            }
        ];

        private static string _sourceFilesFolder;
        public static string SourceFilesFolder
        {
            get
            {
                if (_sourceFilesFolder == null)
                {
                    var modLibrary = Utilities.GetModManagerLibraryPath();
                    if (modLibrary == null || !Directory.Exists(modLibrary))
                    {
                        throw new Exception("Unable to determine location of your Mod Manager library");
                    }
                    var psPath = Path.Combine(modLibrary, "LE1", "Pinnacle Station DLC");
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
            info.Cache = parent.ChainNewCache(debugName: $"CrossGenV level cache (NEVER DISPOSED) ({info.MapName})");

            info.OutputPath = Path.Combine(MilanPipelinesShared.OutputModPath, @"CookedPCConsole", @"Levels", info.MapName);
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

            PortAmbientAudio(info);


            RedemptionShared.AddNewLevelBannerImage(RedemptionShared.GetMapBaseName(info.MapName), info.LogCategory);
            ConfigureBioP(info);
            info.BioP.Save(); // Commit the file

            RedemptionShared.AddLevelToConfig(info);
            info.Cleanup();
        }

        /// <summary>
        /// Recreates the level's LE1 ambient audio as LE3 WwiseAmbientSound actors, playing events out of a local
        /// Wwise_Vegas export tree embedded in the destination BioD (see <see cref="Audio.VegasAudioPipeline"/> for
        /// how that bank is built from LE1's ISACT audio). The LE1 sound level - BIOA_PRC2_CCxxxx_SND - is
        /// deliberately not in LevelFilesMap: its ISACT objects do not survive the trip across engines, so the point
        /// sounds are rebuilt and its audio volumes are selectively converted rather than porting the package wholesale.
        /// </summary>
        private static void PortAmbientAudio(ECLevelInfo info)
        {
            // The sound level sits alongside the design level under the same BIOA_PRC2_CCxxxx prefix.
            var designFile = info.LevelFilesMap.Keys.FirstOrDefault(x => x.EndsWith("_DSG", StringComparison.OrdinalIgnoreCase));
            if (designFile == null)
            {
                MilanLog.Warning($"No _DSG level found for {info.MapName} - skipping ambient audio", customPrefix: info.LogCategory);
                return;
            }

            var soundFile = designFile[..^4] + "_SND";
            var soundPath = Path.Combine(SourceFilesFolder, soundFile + ".pcc");
            if (!File.Exists(soundPath))
            {
                MilanLog.Warning($"No sound level at {soundPath} - {info.MapName} will have no ambient audio", customPrefix: info.LogCategory);
                return;
            }

            // The ambient sounds are positioned in the same world space as the design level, so that is where they go.
            var destPackage = info.CrossPackageMapping.First(x => x.Key.FileNameNoExtension.CaseInsensitiveEquals(designFile)).Value;

            MilanLog.Information($"Porting ambient audio from {soundFile}", customPrefix: info.LogCategory);
            Audio.VegasAudioPipeline.EmbedBankIntoLevel(destPackage, info.Cache, info.LogCategory);
            using var soundPackage = MEPackageHandler.OpenMEPackage(soundPath);
            var created = Audio.VegasAudioActors.PortAmbientSounds(soundPackage, destPackage, Audio.VegasAudioPipeline.SharedModel, info, info.LogCategory);
            MilanLog.Information($"Created {created.AmbientSounds} WwiseAmbientSound actor(s) and {created.AudioVolumes} WwiseAudioVolume actor(s) in {destPackage.FileNameNoExtension}", customPrefix: info.LogCategory);

            // PortCrossgenLevel saved this package before the separate audio pass ran. Persist these late additions
            // explicitly; ECLevelInfo.Cleanup only disposes the packages and does not save them.
            destPackage.Save();
            MilanShared.RefreshMilanFiles = true;
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

            if (info.ExtraBioPObjects != null)
            {
                var theWorld = info.BioP.FindExport("TheWorld");
                ObjectBinary.EditBinary<World>(theWorld, bin =>
                {
                    var list = bin.ExtraReferencedObjects.ToList();

                    // Port in extra items.
                    foreach (var item in info.ExtraBioPObjects)
                    {
                        var sources = MilanShared.LE3ObjectDB.GetFilesContainingObject(item);
                        if (sources == null)
                        {
                            throw new Exception($"Unable to find extra BioP object {item} in MilanShared.LE3ObjectDB");
                        }

                        using var p = MilanShared.GetLE3Package(Path.GetFileName(sources[0]));
                        var sourceExport = p.FindExport(item);
                        EntryExporter.ExportExportToPackage(sourceExport, info.BioP, out var newItem);
                        list.Add(newItem.UIndex);
                    }

                    bin.ExtraReferencedObjects = list.ToArray();
                });
            }

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
                    if (exp.ClassName.CaseInsensitiveEquals("Model")) return false;
                    if (exp.ClassName.CaseInsensitiveEquals("Polys")) return false;

                    // Already in the file
                    if (exp.ClassName.CaseInsensitiveEquals("BioWorldInfo")) return false;

                    // Game1 Specific Stuff.
                    if (exp.ClassName.CaseInsensitiveEquals("BioSquadCombat")) return false;
                    //if (exp.ClassName == "BioInert") return false; // We need this :)
                    if (exp.ClassName.CaseInsensitiveEquals("AmbientSound")) return false;
                    if (exp.ClassName.CaseInsensitiveEquals("BioPawn")) return false;
                    if (exp.ClassName.CaseInsensitiveEquals("BioSunActor")) return false;
                    if (exp.ClassName.CaseInsensitiveEquals("InterpActor")) return CheckPSInterpActor(exp, info.LogCategory);
                    if (exp.ClassName.CaseInsensitiveEquals("BioUseable")) return false;
                    if (exp.ClassName.CaseInsensitiveEquals("BioSquadSitAndShoot")) return false;
                    if (exp.ClassName.CaseInsensitiveEquals("BioWaypointSet")) return false;
                    if (exp.IsA("NavigationPoint")) return false;
                    return true;
                }

                return false;
            }).Select(x => sourcePackage.GetUExport(x)).ToList();

            // Pre-porting corrections
            foreach (var exp in actors)
            {
                switch (exp.ClassName)
                {
                    case "BioLedgeMeshActor":
                        ConvertBioLedgeMeshActor(exp, info.LogCategory);
                        break;
                    case "BioInert":
                        MilanLog.Information($"  Converting BioInert to StaticMeshActor: {exp.InstancedFullPath}", customPrefix: info.LogCategory);
                        // BioInert is a subclass of ArtPlaceable (subclass of Actor) - doesn't exist in LE3. So we must convert this
                        // It looks like most of these can be static meshes, as long as it is bStatic: True.
                        // So we're just going to convert these to a StaticMeshActor and pull them across as that.

                        var smClass = EntryImporter.EnsureClassIsInFile(exp.FileRef, "StaticMeshActor", new RelinkerOptionsPackage());

                        var props = exp.GetProperties();
                        var newProps = new PropertyCollection();
                        if (props.TryGetProp<ObjectProperty>("CollisionComponent", out var cc)) { newProps.Add(cc); }
                        if (props.TryGetProp<FloatProperty>("DrawScale", out var ds)) { newProps.Add(ds); }
                        if (props.TryGetProp<StructProperty>("DrawScale3D", out var ds3d)) { newProps.Add(ds3d); }
                        if (props.TryGetProp<StructProperty>("Location", out var location)) { newProps.Add(location); }
                        if (props.TryGetProp<StructProperty>("Rotation", out var rotation)) { newProps.Add(rotation); }
                        if (props.TryGetProp<NameProperty>("Tag", out var tag)) { newProps.Add(tag); }
                        if (props.TryGetProp<ObjectProperty>("PlaceableMesh", out var placeableMesh))
                        {
                            placeableMesh.Name = "StaticMeshComponent"; // Rename property
                            newProps.Add(placeableMesh);
                        }

                        var pStack = new PrePropStack(exp);
                        pStack.StateNode = pStack.Node = smClass;
                        exp.WritePrePropsAndPropertiesAndBinary(pStack.GeneratePreProps(), newProps, new byte[0]); // Trim off old binary


                        exp.Class = smClass;
                        exp.ObjectName = exp.FileRef.GetNextIndexedName("StaticMeshActor");

                        var smcProp = exp.GetProperty<ObjectProperty>("StaticMeshComponent")?.Value ?? 0;
                        if (smcProp != 0)
                        {
                            var smc = exp.FileRef.GetEntry(smcProp) as ExportEntry;
                            smc.RemoveProperty("LightEnvironment");
                            smc.RemoveProperty("RBCollidWithChannels");
                            smc.WriteProperty(new ObjectProperty(0, "ReplacementPrimitive"));
                            // Needs archetype set to Engine.Default__StaticMeshActor.StaticMeshComponent0
                            var smcDefault = exp.FileRef.GetEntryOrAddImport("Engine.Default__StaticMeshActor", "StaticMeshActor", "Engine");
                            IEntry staticMeshComponentArchetype = exp.FileRef.GetEntryOrAddImport("Engine.Default__StaticMeshActor.StaticMeshComponent0", "StaticMeshComponent", "Engine");
                            smc.Archetype = staticMeshComponentArchetype;
                        }

                        break;
                    case "Terrain":
                        exp.RemoveProperty("Layers"); // Don't bring this over; we will replace it manually for Redemption port.
                        break;
                }
            }

            foreach (var sm in actors)
            {
                PortCrossgenActor(info, sm, destPackage);
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
            var portNav = false;
            if (portNav)
            {
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
            }
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

            // Link in the pathing
            //CorrectPathfindingNetwork(sourcePackage, destPackage);

            // Add back missing bUsedWithStaticLighting
            foreach (var mat in destPackage.Exports.Where(x => x.ClassName == "Material"))
            {
                // LE1 had this on by default, and ShaderHost forces it on, I think.
                // If we port directly from LE1 and then install shaders, this flag will be 
                // missing, so we set it here
                mat.WriteProperty(new BoolProperty(true, "bUsedWithStaticLighting"));
            }

            // Apply ShaderCache
            RevertLE1SpecificMaterialChanges(destPackage, info);
            MilanShaders.InstallCompiledShadersToPackage(destPackage, info.LogCategory);

            // Terrain shaders are tied to the specific terrain; we cache a built version here
            var terrainDonorPath = Path.Combine(SharedECPipelines.ECPipelineRoot, "Redemption", "Assets", "Terrain");
            MilanShaders.InstallTerrainShadersToPackage(destPackage, terrainDonorPath, info.LogCategory);

            // Test only - strip lightmaps
            if (false)
            {
                foreach (var smcx in destPackage.Exports.Where(x => x.ClassName == "StaticMeshComponent"))
                {

                    var smc = ObjectBinary.From<StaticMeshComponent>(smcx);
                    foreach (var lod in smc.LODData)
                    {
                        lod.LightMap = new LightMap(); // This means no lightmap.
                    }

                    smcx.WriteBinary(smc);
                }
            }

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
        /// Converts LE1's native BioLedgeMeshActor to its LE3-compatible base class.
        /// BioLedgeMeshActor only changes defaults on StaticMeshActor and its component, so materialize
        /// those defaults before replacing its class and component archetypes. Source properties take
        /// precedence because their presence represents an instance-level override.
        /// </summary>
        private static void ConvertBioLedgeMeshActor(ExportEntry actor, string logCategory)
        {
            MilanLog.Information($"  Converting BioLedgeMeshActor to StaticMeshActor: {actor.InstancedFullPath}", customPrefix: logCategory);

            var staticMeshActorClass = EntryImporter.EnsureClassIsInFile(actor.FileRef, "StaticMeshActor", new RelinkerOptionsPackage());
            var staticMeshActorDefault = actor.FileRef.GetEntryOrAddImport("Engine.Default__StaticMeshActor", "StaticMeshActor", "Engine");

            // These values are inherited from Default__BioLedgeMeshActor in LE1 and otherwise disappear
            // when the actor begins inheriting from Default__StaticMeshActor in LE3.
            if (actor.GetProperty<BoolProperty>("bHidden") == null)
                actor.WriteProperty(new BoolProperty(true, "bHidden"));
            if (actor.GetProperty<BoolProperty>("BlockRigidBody") == null)
                actor.WriteProperty(new BoolProperty(false, "BlockRigidBody"));
            if (actor.GetProperty<EnumProperty>("CollisionType") == null)
                actor.WriteProperty(new EnumProperty("COLLIDE_NoCollision", "ECollisionType", actor.FileRef.Game, "CollisionType"));

            var staticMeshComponentProperty = actor.GetProperty<ObjectProperty>("StaticMeshComponent");
            if (staticMeshComponentProperty != null && actor.FileRef.TryGetUExport(staticMeshComponentProperty.Value, out var component))
            {
                var staticMeshComponentDefault = actor.FileRef.GetEntryOrAddImport(
                    "Engine.Default__StaticMeshActor.StaticMeshComponent0", "StaticMeshComponent", "Engine");
                component.Archetype = staticMeshComponentDefault;

                // These defaults come from BioLedgeMeshActor's StaticMeshComponent0 template.
                if (component.GetProperty<ObjectProperty>("ReplacementPrimitive") == null)
                    component.WriteProperty(new ObjectProperty(0, "ReplacementPrimitive"));
                if (component.GetProperty<EnumProperty>("RBChannel") == null)
                    component.WriteProperty(new EnumProperty("RBCC_Untitled1", "ERBCollisionChannel", actor.FileRef.Game, "RBChannel"));
                if (component.GetProperty<BoolProperty>("CastShadow") == null)
                    component.WriteProperty(new BoolProperty(false, "CastShadow"));
                if (component.GetProperty<BoolProperty>("bCastDynamicShadow") == null)
                    component.WriteProperty(new BoolProperty(false, "bCastDynamicShadow"));
                if (component.GetProperty<BoolProperty>("bAcceptsLights") == null)
                    component.WriteProperty(new BoolProperty(false, "bAcceptsLights"));
                if (component.GetProperty<BoolProperty>("bAcceptsDynamicLights") == null)
                    component.WriteProperty(new BoolProperty(false, "bAcceptsDynamicLights"));
            }

            actor.Class = staticMeshActorClass;
            actor.Archetype = staticMeshActorDefault;
            actor.ObjectName = actor.FileRef.GetNextIndexedName("StaticMeshActor");

            if (actor.HasStack)
            {
                var stack = new PrePropStack(actor)
                {
                    Node = staticMeshActorClass,
                    StateNode = staticMeshActorClass,
                };
                actor.WritePrePropsAndPropertiesAndBinary(stack.GeneratePreProps(), actor.GetProperties(), actor.GetBinaryData());
            }
        }

        /// <summary>
        /// Ports one actor through the same cross-game dependency/relink path used by the normal level actor pass.
        /// The Pinnacle Station audio pass also uses this for BioAudioVolumes after changing their source-side class
        /// to WwiseAudioVolume; keeping the operation here ensures their brush/model/component hierarchy is treated
        /// exactly like the rest of the level's actors without importing the obsolete contents of the whole _SND level.
        /// </summary>
        internal static ExportEntry PortCrossgenActor(ECLevelInfo info, ExportEntry sourceActor, IMEPackage destPackage)
        {
            if (destPackage.FindExport(sourceActor.InstancedFullPath) is { } existing)
            {
                return existing;
            }

            var destLevel = destPackage.GetLevel();
            MilanLog.Information($"  Porting {sourceActor.InstancedFullPath}", customPrefix: info.LogCategory);
            var badLinks = EntryImporter.ImportAndRelinkEntries(
                EntryImporter.PortingOption.CloneAllDependencies,
                sourceActor, destPackage, destLevel, true,
                new RelinkerOptionsPackage()
                {
                    IsCrossGame = true,
                    TargetGameDonorDB = MilanShared.LE3ObjectDB,
                    Cache = info.Cache,
                    PortExportsAsImportsWhenPossible = true,
                    PortImportsMemorySafe = true,
                    DestinationCustomImportFileResolver = MilanShared.LE3PackageResolver,
                    // SourceCustomImportFileResolver = MilanShared.ME3PackageResolver, // We are not porting from ME3.
                }, out var newEntry);

            if (badLinks.Any())
            {
                Debug.WriteLine("oi vey");
            }

            return newEntry as ExportEntry;
        }

        /// <summary>
        /// Pinnacle Station has some InterpActors for strategic ring - we don't care at all about those so we will chop those out
        /// </summary>
        /// <param name="exp"></param>
        /// <returns>True if it should port, false if it shouldn't</returns>
        private static bool CheckPSInterpActor(ExportEntry interpActor, string logCategory)
        {
            var smc = interpActor.GetProperty<ObjectProperty>("StaticMeshComponent")?.ResolveToExport(interpActor.FileRef, null);
            if (smc != null)
            {
                var sm = smc.GetProperty<ObjectProperty>("StaticMesh")?.ResolveToExport(interpActor.FileRef, null);
                if (sm != null)
                {
                    switch (sm.ObjectName)
                    {
                        // These are related to crossgen capture points
                        case "Player_Pos__old":
                        case "StrategicRing_S":
                            MilanLog.Information($"Not porting {sm.ObjectName} as it won't be used by multiplayer", customPrefix: logCategory);
                            return false;
                    }
                }
            }
            return true;
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

        /// <summary>
        /// When we ported ME1->LE1 there were some materials that we had to change, they got renamed.
        /// When porting to LMP it won't find shaders cause name is different. Since we can compile shaders now,
        /// we should undo our name changes.
        /// </summary>
        /// <param name="package"></param>
        internal static void RevertLE1SpecificMaterialChanges(IMEPackage package, ECLevelInfo info)
        {
            if (package.FindExport("BIOA_Jug20_T.CROSSGEN_Jug20_2waywetsandB", "Material") is ExportEntry sandBar)
            {
                sandBar.ObjectName = "Jug20_2waywetsandB";
            }
        }


        private static void CorrectPathfindingNetwork(IMEPackage le1File, IMEPackage le3File)
        {
            var le3PL = le3File.FindExport("TheWorld.PersistentLevel");
            if (le3PL == null)
                return; // This file doesn't have a level
            Level le1L = ObjectBinary.From<Level>(le1File.FindExport("TheWorld.PersistentLevel"));
            Level le3L = ObjectBinary.From<Level>(le3PL);

            // NavList Chain start and end
            if (le1L.NavListEnd != 0 && le3File.FindExport(le1File.GetUExport(le1L.NavListEnd).InstancedFullPath) is { } matchingNavEnd)
            {
                le1L.NavListEnd = matchingNavEnd.UIndex;

                if (le1L.NavListStart != 0 && le3File.FindExport(le1File.GetUExport(le1L.NavListStart).InstancedFullPath) is { } matchingNavStart)
                {
                    le1L.NavListStart = matchingNavStart.UIndex;
                    while (matchingNavStart != null)
                    {
                        int uindex = matchingNavStart.UIndex;
                        var props = matchingNavStart.GetProperties();
                        //props.AddOrReplaceProp(maxPathSize);
                        var next = props.GetProp<ObjectProperty>("nextNavigationPoint");
                        //matchingNavStart.WriteProperties(props);
                        matchingNavStart = next?.ResolveToEntry(le3File) as ExportEntry;
                        if (matchingNavStart == null && uindex != matchingNavEnd.UIndex)
                        {
                            Debugger.Break();
                        }
                    }
                }
            }

            // CoverList Chain start and end
            if (le1L.CoverListEnd != 0 && le3File.FindExport(le1File.GetUExport(le1L.CoverListEnd).InstancedFullPath) is { } matchingCoverEnd)
            {
                le3L.CoverListEnd = matchingCoverEnd.UIndex;

                if (le1L.CoverListStart != 0 && le3File.FindExport(le1File.GetUExport(le1L.CoverListStart).InstancedFullPath) is { } matchingCoverStart)
                {
                    le3L.CoverListStart = matchingCoverStart.UIndex;
                    while (matchingCoverStart != null)
                    {
                        int uindex = matchingCoverStart.UIndex;
                        var props = matchingCoverStart.GetProperties();
                        //props.AddOrReplaceProp(maxPathSize);
                        var next = props.GetProp<ObjectProperty>("NextCoverLink");
                        //matchingNavStart.WriteProperties(props);
                        matchingCoverStart = next?.ResolveToEntry(le3File) as ExportEntry;
                        if (matchingCoverStart == null && uindex != matchingCoverEnd.UIndex)
                        {
                            Debugger.Break();
                        }
                    }
                }
            }

            // Cross level actors
            foreach (var exportIdx in le1L.CrossLevelActors)
            {
                var me1E = le1File.GetUExport(exportIdx);
                if (le3File.FindExport(me1E.InstancedFullPath) is { } crossLevelActor)
                {
                    le3L.CrossLevelActors.Add(crossLevelActor.UIndex);
                }
            }

            // Regenerate the 'End' struct cause it will have ported wrong
            //CorrectReachSpecs(me1File, le1File);
            //CorrectBioWaypointSet(me1File, le1File, vTestOptions); // Has NavReference -> ActorReference
            le3PL.WriteBinary(le3L);
        }

        // FROM LEX
        internal static IEntry GetImportArchetype(IMEPackage package, string packageFile, string ifp)
        {
            IEntry result = package.FindEntry($"{packageFile}.{ifp}");
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
            IEntry packageExport = null;
            if (packageFile == "Engine")
            {
                packageExport = (IEntry)ExportCreator.CreatePackageImport(package, packageFile);
            }
            else
            {
                packageExport = (IEntry)ExportCreator.CreatePackageExport(package, packageFile);
            }

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
