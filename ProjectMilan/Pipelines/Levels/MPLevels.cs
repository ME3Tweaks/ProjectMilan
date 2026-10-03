using LegendaryExplorerCore.GameFilesystem;
using LegendaryExplorerCore.Gammtek.Extensions;
using LegendaryExplorerCore.Gammtek.Extensions.Collections.Generic;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Packages.CloningImportingAndRelinking;
using LegendaryExplorerCore.Pathing;
using LegendaryExplorerCore.Unreal;
using ProjectMilan.Pipelines.Levels.BioP_MPGeth;
using ProjectMilan.Pipelines.Levels.BioP_MPHosp;
using ProjectMilan.Pipelines.Levels.BioP_MPMoon;
using ProjectMilan.Pipelines.Levels.BioP_MPOcean;
using ProjectMilan.Pipelines.Levels.MPLobby;
using ProjectMilan.Pipelines.Shared;
using ProjectMilan.Pipelines.StaticLighting;
using ProjectMilan.Utility;
using ProjectMilanCore;
using ProjectMilanCore.Config;
using ProjectMilanCore.Utility;

namespace ProjectMilan.Pipelines.Levels
{
    /// <summary>
    /// Pipeline for porting levels across from OT to LE (must be made for multiplayer mode!)
    /// </summary>
    internal class MPLevels
    {
        private const string LOG_CATEGORY = "MILAN-Level";

        /// <summary>
        /// Lightmap resolution multiplier for production builds, applied on top of the per-component resolutions
        /// restored from BioWare's bakes. 2x is roughly 4x the lightmap texels (and bake time) of a dev build.
        /// </summary>
        private const float ProductionLightmapResolutionMultiplier = 2f;

        // Only "Random waves"/"Mixed" need fresh TLK strings - the rest reuse their existing vanilla StrRef IDs.
        private static readonly LocalizedString RandomWaveName = new() { [MELocalization.INT] = "Coalition" }; // Random Wave
        private static readonly LocalizedString RandomWaveAllCapsName = new() { [MELocalization.INT] = "COALITION" };
        private static readonly LocalizedString MixedName = new() { [MELocalization.INT] = "Unified" }; // Mixed
        private static readonly LocalizedString MixedAllCapsName = new() { [MELocalization.INT] = "UNIFIED" };

        private static readonly LocalizedString DiamondDifficultyName = new() { [MELocalization.INT] = "Diamond" };
        private static readonly LocalizedString DiamondDifficultyAllCapsName = new() { [MELocalization.INT] = "DIAMOND" };
        class MPLevelsVars
        {
            /// <summary>
            /// The multiplayer Horde "Enemy" (faction) select list - was previously static XML
            /// (MergedConfig\BioGame.xml's enemytypes), moved here so it builds through the same dynamic
            /// TLK-backed system as the map list.
            /// </summary>
            public readonly List<EnemyTypeEntry> EnemyTypes = new()
            {
                // Random (Faction)
                new EnemyTypeEntry { ID = 0, NameStrRefId = 701523, AllCapsNameStrRefId = 701523, Image = "GUI_MPImages.MatchSettings.OptEmyRandom", WaveClass = "", IsRandomOption = true },
                // Random (Wave) - MUST STAY AT INDEX 1! Logic depends on it being here
                new EnemyTypeEntry { ID = 1, NameStrRefId = MilanPipelinesShared.AssignTLK(RandomWaveName), AllCapsNameStrRefId = MilanPipelinesShared.AssignTLK(RandomWaveAllCapsName), Image = "GUI_MPImages.MatchSettings.OptEmyRandomWave", WaveClass = "", IsRandomOption = true },
                // Random (Enemy)
                new EnemyTypeEntry { ID = 2, NameStrRefId = MilanPipelinesShared.AssignTLK(MixedName), AllCapsNameStrRefId = MilanPipelinesShared.AssignTLK(MixedAllCapsName), Image = "GUI_MPImages.MatchSettings.OptEmyRandomEnemy", WaveClass = "SFXGameContent_Milan.SFXWave_Horde_RandomEnemies", IsRandomOption = true },

                // MP4 Wavelists
                new EnemyTypeEntry { ID = 3, NameStrRefId = 683914, AllCapsNameStrRefId = 683908, Image = "GUI_MPImages_MP4.OptEmyCerberus", WaveClass = "SFXGameContentDLC_CON_MP4_Horde.SFXWave_Horde_Cerberus2" },
                new EnemyTypeEntry { ID = 4, NameStrRefId = 683915, AllCapsNameStrRefId = 683909, Image = "GUI_MPImages_MP4.OptEmyGeth", WaveClass = "SFXGameContentDLC_CON_MP4_Horde.SFXWave_Horde_Geth2" },
                new EnemyTypeEntry { ID = 5, NameStrRefId = 683916, AllCapsNameStrRefId = 683910, Image = "GUI_MPImages.MatchSettings.OptEmyReapers", WaveClass = "SFXGameContentDLC_CON_MP4_Horde.SFXWave_Horde_Reaper2" },
                new EnemyTypeEntry { ID = 6, NameStrRefId = 746075, AllCapsNameStrRefId = 746076, Image = "GUI_MPImages_MP4.OptEmyCollector", WaveClass = "SFXGameContentDLC_CON_MP4_Horde.SFXWave_Horde_Collector" },
            
                // Classic Wavelists?
            };

            /// <summary>
            /// New difficulty options, appended on top of the existing static challengetypes list
            /// (Bronze/Silver/Gold/Platinum - original ME3-ported values that never change and stay as XML).
            /// </summary>
            public readonly List<DifficultyEntry> Difficulties = new()
            {
                new DifficultyEntry { ID = 4, NameStrRefId = MilanPipelinesShared.AssignTLK(DiamondDifficultyName), AllCapsNameStrRefId = MilanPipelinesShared.AssignTLK(DiamondDifficultyAllCapsName), Image = "GUI_MPImages.MatchSettings.OptChallgDiamond" },
            };

            /// <summary>
            /// Map of DLC map names and if they should be ported across
            /// </summary>
            public readonly List<LevelSpecificPipeline> LevelPipelines = new()
            {
                // Maps here are laid out in the order they will appear in the map list
                // Vanilla
                new LevelSpecificPipeline() { BioP="BioP_MPDish", Enabled = true, SpecialPortingDelegate = BasegameMapPorting, BuildLighting = false, // Dagger
                    MapListInfo = new MapListEntry { PackageName="BioP_MPDish", PrettyNameStrRefId=618041, DescriptionStrRefId=618050, GAWMapPositionX=424, GAWMapPositionY=216, GAWMapSubtitleStrRefId=706337, ImageObjectPath="GUI_MPImages.MatchSettings.OptMapDish", ImageSeekFreePackageName="SFXMPImagesMatchSettings" } },
                new LevelSpecificPipeline() { BioP="BioP_MPSlum", Enabled = true, SpecialPortingDelegate = BasegameMapPorting, BuildLighting = false, // Ghost
                    MapListInfo = new MapListEntry { PackageName="BioP_MPSlum", PrettyNameStrRefId=618042, DescriptionStrRefId=618051, GAWMapPositionX=310, GAWMapPositionY=403, GAWMapSubtitleStrRefId=706335, ImageObjectPath="GUI_MPImages.MatchSettings.OptMapSlum", ImageSeekFreePackageName="SFXMPImagesMatchSettings" } },
                new LevelSpecificPipeline() { BioP="BioP_MPTowr3", Enabled = true, SpecialPortingDelegate = null, // Giant - MP4 version
                    MapListInfo = new MapListEntry { PackageName="BioP_MPTowr3", PrettyNameStrRefId=618043, DescriptionStrRefId=618052, GAWMapPositionX=195, GAWMapPositionY=358, GAWMapSubtitleStrRefId=706332, ImageObjectPath="GUI_MPImages.MatchSettings.OptMapTowr", ImageSeekFreePackageName="SFXMPImagesMatchSettings" } },
                new LevelSpecificPipeline() { BioP="BioP_MPCer3", Enabled = true, SpecialPortingDelegate = null, // Glacier - MP4 version
                    MapListInfo = new MapListEntry { PackageName="BioP_MPCer3", PrettyNameStrRefId=618047, DescriptionStrRefId=618056, GAWMapPositionX=280, GAWMapPositionY=97, GAWMapSubtitleStrRefId=706333, ImageObjectPath="GUI_MPImages.MatchSettings.OptMapCer", ImageSeekFreePackageName="SFXMPImagesMatchSettings" } },
                new LevelSpecificPipeline() { BioP="BioP_MPRctr", Enabled = true, SpecialPortingDelegate = BasegameMapPorting, BuildLighting = false, // Reactor
                    MapListInfo = new MapListEntry { PackageName="BioP_MPRctr", PrettyNameStrRefId=618044, DescriptionStrRefId=618053, GAWMapPositionX=111, GAWMapPositionY=333, GAWMapSubtitleStrRefId=706336, ImageObjectPath="GUI_MPImages.MatchSettings.OptMapRctr", ImageSeekFreePackageName="SFXMPImagesMatchSettings" } },
                new LevelSpecificPipeline() { BioP="BioP_MPNov3", Enabled = true, SpecialPortingDelegate = null, // White - MP4 version
                    MapListInfo = new MapListEntry { PackageName="BioP_MPNov3", PrettyNameStrRefId=618048, DescriptionStrRefId=618057, GAWMapPositionX=352, GAWMapPositionY=352, GAWMapSubtitleStrRefId=706334, ImageObjectPath="GUI_MPImages.MatchSettings.OptMapNoveria", ImageSeekFreePackageName="SFXMPImagesMatchSettings" } },

                // The original MPTowr had problems with spawns outside the map; we don't want to use this as a classic map
                // new LevelSpecificPipeline() { BioP="BioP_MPTowr", Enabled = true, SpecialPortingDelegate = BasegameMapPorting, BuildLighting = false}, // Giant

                // MP1 Resurgence
                new LevelSpecificPipeline() { BioP="BioP_MPMoon", Enabled = true, SpecialPrePortingDelegate = MPMoonSpecific.PreCorrect, IgnoredLightingLevels = MPMoonSpecific.IgnoredLightingLevels, // Condor
                    MapListInfo = new MapListEntry { PackageName="BioP_MPMoon", PrettyNameStrRefId=727479, DescriptionStrRefId=null, GAWMapPositionX=170, GAWMapPositionY=420, GAWMapSubtitleStrRefId=506972, ImageObjectPath="DLC_MPImages.Map.OptMapMoon", ImageSeekFreePackageName="MP1Images" } },
                new LevelSpecificPipeline() { BioP="BioP_MPGeth", Enabled = true, SpecialPrePortingDelegate = MPGethSpecific.PreCorrect, IgnoredLightingLevels = MPGethSpecific.IgnoredLightingLevels, // Hydra
                    MapListInfo = new MapListEntry { PackageName="BioP_MPGeth", PrettyNameStrRefId=728069, DescriptionStrRefId=null, GAWMapPositionX=435, GAWMapPositionY=211, GAWMapSubtitleStrRefId=326824, ImageObjectPath="DLC_MPImages.Map.OptMapGeth", ImageSeekFreePackageName="MP1Images" } },

                // MP2 Rebellion
                new LevelSpecificPipeline() { BioP="BioP_MPJngl", Enabled = true, SpecialPortingDelegate = null, // Jade
                    MapListInfo = new MapListEntry { PackageName="BioP_MPJngl", PrettyNameStrRefId=728030, DescriptionStrRefId=null, GAWMapPositionX=231, GAWMapPositionY=362, GAWMapSubtitleStrRefId=500264, ImageObjectPath="GUI_MPImages_MP2.OptMapJade", ImageSeekFreePackageName="MP2Images" } },
                new LevelSpecificPipeline() { BioP="BioP_MPThes", Enabled = true, SpecialPortingDelegate = null, IgnoredLightingLevels = MPThesSpecific.IgnoredLightingLevels, // Goddess
                    MapListInfo = new MapListEntry { PackageName="BioP_MPThes", PrettyNameStrRefId=728031, DescriptionStrRefId=null, GAWMapPositionX=105, GAWMapPositionY=278, GAWMapSubtitleStrRefId=500427, ImageObjectPath="GUI_MPImages_MP2.OptMapGoddess", ImageSeekFreePackageName="MP2Images" } },

                // MP3 Earth
                new LevelSpecificPipeline() { BioP="BioP_MPOcean", Enabled = true, SpecialPortingDelegate = null, IgnoredLightingLevels = MPOceanSpecific.IgnoredLightingLevels, // Rio
                    MapListInfo = new MapListEntry { PackageName="BioP_MPOcean", PrettyNameStrRefId=731650, DescriptionStrRefId=618054, GAWMapPositionX=290, GAWMapPositionY=410, GAWMapSubtitleStrRefId=345696, ImageObjectPath="GUI_MPImages_MP3.OptMapRio", ImageSeekFreePackageName="MP3Images" } },
                new LevelSpecificPipeline() { BioP="BioP_MPHosp", Enabled = true, SpecialPortingDelegate = null, IgnoredLightingLevels = MPHospSpecific.IgnoredLightingLevels, // Vancouver
                    MapListInfo = new MapListEntry { PackageName="BioP_MPHosp", PrettyNameStrRefId=728032, DescriptionStrRefId=618054, GAWMapPositionX=290, GAWMapPositionY=410, GAWMapSubtitleStrRefId=345696, ImageObjectPath="GUI_MPImages_MP3.OptMapHosp", ImageSeekFreePackageName="MP3Images" } },
                new LevelSpecificPipeline() { BioP="BioP_MPRoad", Enabled = true, SpecialPortingDelegate = null, // London
                    MapListInfo = new MapListEntry { PackageName="BioP_MPRoad", PrettyNameStrRefId=731651, DescriptionStrRefId=618054, GAWMapPositionX=290, GAWMapPositionY=410, GAWMapSubtitleStrRefId=345696, ImageObjectPath="GUI_MPImages_MP3.OptMapLondon", ImageSeekFreePackageName="MP3Images" } },

                // MP4 Retaliation
                new LevelSpecificPipeline() { BioP="BioP_MPCer2", Enabled = true, SpecialPortingDelegate = null, // Glacier - Hazard
                    MapListInfo = new MapListEntry { PackageName="BioP_MPCer2", PrettyNameStrRefId=772398, DescriptionStrRefId=618047, GAWMapPositionX=280, GAWMapPositionY=97, GAWMapSubtitleStrRefId=706333, ImageObjectPath="GUI_MPImages_MP4.OptMapSwarm", ImageSeekFreePackageName="SFXHazardMapImages" } },
                new LevelSpecificPipeline() { BioP="BioP_MPDish2", Enabled = true, SpecialPortingDelegate = null, // Dagger - Hazard
                    MapListInfo = new MapListEntry { PackageName="BioP_MPDish2", PrettyNameStrRefId=772393, DescriptionStrRefId=618041, GAWMapPositionX=424, GAWMapPositionY=216, GAWMapSubtitleStrRefId=706337, ImageObjectPath="GUI_MPImages_MP4.OptMapSandstorm", ImageSeekFreePackageName="SFXHazardMapImages" } },
                new LevelSpecificPipeline() { BioP="BioP_MPNov2", Enabled = true, SpecialPortingDelegate = null, // White - Hazard
                    MapListInfo = new MapListEntry { PackageName="BioP_MPNov2", PrettyNameStrRefId=772316, DescriptionStrRefId=618048, GAWMapPositionX=352, GAWMapPositionY=352, GAWMapSubtitleStrRefId=706334, ImageObjectPath="GUI_MPImages_MP4.OptMapSnowstorm", ImageSeekFreePackageName="SFXHazardMapImages" } },
                new LevelSpecificPipeline() { BioP="BioP_MPRctr2", Enabled = true, SpecialPortingDelegate = null, // Reactor - Hazard
                    MapListInfo = new MapListEntry { PackageName="BioP_MPRctr2", PrettyNameStrRefId=772396, DescriptionStrRefId=618044, GAWMapPositionX=111, GAWMapPositionY=333, GAWMapSubtitleStrRefId=706336, ImageObjectPath="GUI_MPImages_MP4.OptMapMeltdown", ImageSeekFreePackageName="SFXHazardMapImages" } },
                new LevelSpecificPipeline() { BioP="BioP_MPSlum2", Enabled = true, SpecialPortingDelegate = null, // Ghost - Hazard
                    MapListInfo = new MapListEntry { PackageName="BioP_MPSlum2", PrettyNameStrRefId=772394, DescriptionStrRefId=618042, GAWMapPositionX=310, GAWMapPositionY=403, GAWMapSubtitleStrRefId=706335, ImageObjectPath="GUI_MPImages_MP4.OptMapAcid", ImageSeekFreePackageName="SFXHazardMapImages" } },
                new LevelSpecificPipeline() { BioP="BioP_MPTowr2", Enabled = true, SpecialPortingDelegate = null, // Giant - Hazard
                    MapListInfo = new MapListEntry { PackageName="BioP_MPTowr2", PrettyNameStrRefId=772399, DescriptionStrRefId=618043, GAWMapPositionX=195, GAWMapPositionY=358, GAWMapSubtitleStrRefId=706332, ImageObjectPath="GUI_MPImages_MP4.OptMapTower", ImageSeekFreePackageName="SFXHazardMapImages" } },
                
                // MP5 Reckoning
                // No maps

                
                // Classic maps
                // We need the dynamic TLK system up and running for these since we need to rename the maps.
                /*
                 new LevelSpecificPipeline() { BioP="BioP_MPCer", Enabled = true, SpecialPortingDelegate = BasegameMapPorting, BuildLighting = false, // Glacier
                    MapListInfo = new MapListEntry { PackageName="BioP_MPCer", PrettyNameStrRefId=618047, DescriptionStrRefId=618056, GAWMapPositionX=280, GAWMapPositionY=97, GAWMapSubtitleStrRefId=706333, ImageObjectPath="GUI_MPImages.MatchSettings.OptMapCer", ImageSeekFreePackageName="SFXMPImagesMatchSettings" } },
                new LevelSpecificPipeline() { BioP="BioP_MPNov", Enabled = true, SpecialPortingDelegate = BasegameMapPorting, BuildLighting = false, // White
                    MapListInfo = new MapListEntry { PackageName="BioP_MPNov", PrettyNameStrRefId=618048, DescriptionStrRefId=618057, GAWMapPositionX=352, GAWMapPositionY=352, GAWMapSubtitleStrRefId=706334, ImageObjectPath="GUI_MPImages.MatchSettings.OptMapNoveria", ImageSeekFreePackageName="SFXMPImagesMatchSettings" } },
                */

                // Prototype and unused maps
                // These are named that were assigned to the maps for ModMaker
                // There are technically 2 additional variations of MPSub if you swap to a different unused BioD
                new LevelSpecificPipeline() { BioP="BioP_MPThes2", Enabled =false, SpecialPortingDelegate = null, ExcludeFromProduction = true}, // Athena (prototype)
                new LevelSpecificPipeline() { BioP="BioP_MPBrdg", Enabled =false, SpecialPortingDelegate = null, ExcludeFromProduction = true}, // Gauntlet (prototype)
                new LevelSpecificPipeline() { BioP="BioP_MPFoun", Enabled =false, SpecialPortingDelegate = null, ExcludeFromProduction = true}, // Dragon (prototype)
                new LevelSpecificPipeline() { BioP="BioP_MPPump", Enabled = false, SpecialPortingDelegate = null, ExcludeFromProduction = true}, // Forge (prototype)
                new LevelSpecificPipeline() { BioP="BioP_MPRays", Enabled =false, SpecialPortingDelegate = null, ExcludeFromProduction = true}, // Maelstrom (prototype)
                new LevelSpecificPipeline() { BioP="BioP_MPSub", Enabled = false, SpecialPortingDelegate = null, ExcludeFromProduction = true}, // Neptune (prototype)
                new LevelSpecificPipeline() { BioP="BioP_MPTest", Enabled = false, SpecialPortingDelegate = null, ExcludeFromProduction = true}, // Scorpion (prototype)



                // We use MPLobby.pcc level from here
                new LevelSpecificPipeline() { BioP="MPLobby", SpecialPrePortingDelegate = MPLobbySpecific.PreCorrect, BuildLighting = false}, // This level is always ported and has no map registration since it's not really a map
            };


        }

        public static void RunPipeline()
        {
            var vars = new MPLevelsVars();
            InternalRunPipeline(vars);
        }

        private static void InternalRunPipeline(MPLevelsVars levelVars)
        {
            // Chained to the long-lived MPCommon tier so files hit repeatedly across levels (but not globally
            // hot enough to be in MPCommon) get promoted here instead of reopened per-level. Disposed once
            // every level is done, so nothing here outlives the Levels pipeline (which runs last).
            using var parent = MilanShared.GetMPCommonTieredPackageCache().ChainNewCache(canPromoteInto: true, debugName: "MPLevels pipeline cache");
            foreach (var level in levelVars.LevelPipelines)
            {
#if DEBUG
                // Uncomment to build a specific level
                //if (level.BioP != "BioP_MPOcean")
                //{
                //    continue;
                //}
#endif
                if (!level.ShouldBuild)
                {
                    // This level is not marked for porting currently.
                    MilanLog.Information($"Skipping level {level.BioP}, pipeline is not enabled");
                    continue;
                }

                if (level.SpecialPortingDelegate != null)
                {
                    level.SpecialPortingDelegate?.Invoke(level, parent);
                }
                else
                {
                    BeginPortingGeneric(level, parent);
                }
                
                // Static lighting does not save the source package, so we are now free to modify it now that the final save has occurred
                if (Program.BuildStaticLighting && level.BuildLighting)
                {
                    // This significantly delay build time - it runs UDK and imports lighting after bake!
                    // Lightmap texel count - and so bake time and lightmap memory - scales with the square of this.
                    var lightmapResolutionMultiplier = Program.Settings.ProductionBuild ? ProductionLightmapResolutionMultiplier : 1f;
                    var defaultStaticMeshLightingRes = (int)(128 * lightmapResolutionMultiplier); // BioWare default is 32
                    if (StaticLightingExport.ExportLevelToUDK(level, lightmapResolutionMultiplier, defaultStaticMeshLightingRes))
                    {
                        StaticLightingCompute.ComputeLighting(level.LE3BioP.FileNameNoExtension, allowLightmapCompression: false, defaultStaticMeshLightingRes: defaultStaticMeshLightingRes, keepPreBakeMaps: Program.KeepPreBakeMaps, ue4Lightmass: level.UE4Lightmass);
                        LevelShared.ImportStaticLighting(level, true);
                    }
                    else
                    {
                        MilanLog.Error($"Skipping static lighting build and import for {level.LE3BioP.FileNameNoExtension} due to unresolved UDK imports.", customPrefix: LOG_CATEGORY);
                    }
                }

                if (level.MapListInfo != null)
                {
                    MapListConfigWriter.RegisterMap(level.MapListInfo);
                }

                level.ClearReferences();
            }

            foreach (var enemyType in levelVars.EnemyTypes)
            {
                EnemyTypeConfigWriter.RegisterEnemyType(enemyType);
            }

            foreach (var difficulty in levelVars.Difficulties)
            {
                DifficultyRegistration.RegisterDifficulty(difficulty);
            }

            // Flush every map/enemy type/difficulty registered above into Default_<DLC_NAME>.bin. Rejection/
            // Redemption (if enabled) run after this stage and may still add their own maps to the same
            // bundle - see their own commit calls.
            MilanPipelinesShared.CommitConfigBundle();
        }


        /// <summary>
        /// Fixes up the 5 usable basegame MP maps that ship with LE
        /// </summary>
        /// <param name="levelPipeline"></param>
        private static void BasegameMapPorting(LevelSpecificPipeline levelPipeline, TieredPackageCache parent)
        {
            levelPipeline.LogCategory = $"{LOG_CATEGORY}-{levelPipeline.BioP}";
            MilanLog.Information($@"Beginning generic level port: {levelPipeline.BioP}", customPrefix: levelPipeline.LogCategory);

            // Initialize cache
            levelPipeline.Cache = parent.ChainNewCache(debugName: $"MPLevels basegame level cache ({levelPipeline.BioP})");

            var outputPath = Path.Combine(Program.Settings.OutputModPath, @"CookedPCConsole", @"Levels", levelPipeline.BioP);
            Directory.CreateDirectory(outputPath);

            // Get BioP package
            MilanLog.Information($"Loading ME3 BioP", customPrefix: levelPipeline.LogCategory);
            var me3BioP = MilanShared.GetME3Package($"{levelPipeline.BioP}.pcc");
            levelPipeline.ME3BioP = me3BioP;
            levelPipeline.ME3Packages[levelPipeline.BioP] = me3BioP;
            levelPipeline.LE3BioP = MEPackageHandler.OpenMEPackage(Path.Combine(LE3Directory.CookedPCPath, $@"{levelPipeline.BioP}.pcc")); // This file is not patched in METR
            levelPipeline.LE3BioP.LECLTagData.ImportHintFiles.Add(MilanShared.MP_STARTUP_FILENAME); // Hint this file

            // Add start locations
            var level = levelPipeline.LE3BioP.GetLevel();
            foreach (var startLoc in me3BioP.Exports.Where(x => !x.IsDefaultObject && x.ClassName == "BioStartLocationMP"))
            {
                var badLinks = EntryImporter.ImportAndRelinkEntries(EntryImporter.PortingOption.CloneAllDependencies,
                    startLoc, level.FileRef, level, true,
                    new RelinkerOptionsPackage()
                    {
                        IsCrossGame = true,
                        TargetGameDonorDB = MilanShared.LE3ObjectDB,
                        Cache = levelPipeline.Cache,
                        PortExportsAsImportsWhenPossible = true,
                        DestinationCustomImportFileResolver = MilanShared.LE3PackageResolver,
                    }, out var _);
            }

            PortSPAutoPersistentObjects(levelPipeline);

            MilanLevelTools.RebuildPersistentLevelChildren(level);
            MilanLevelTools.SetupHordeModes(levelPipeline.LE3BioP, false);


            // Save BioP into folder
            levelPipeline.LE3BioP.Save(Path.Combine(outputPath, Path.GetFileName(levelPipeline.LE3BioP.FilePath)), diskIOSyncLock: MilanShared.DiskIOSyncLock);
            MilanShared.RefreshMilanFiles = true;
        }

        /// <summary>
        /// The basegame MP maps are our own copies with nothing in them, they are missing content from their SP counterparts.
        /// the SP map's m_AutoPersistentObjects (textures, materials, etc that must always be loaded with
        /// the level). Ports the local content (skipping imports) from BioP_SP[mapname] into the MP BioP.
        /// </summary>
        private static void PortSPAutoPersistentObjects(LevelSpecificPipeline levelPipeline)
        {
            var spBioPName = levelPipeline.BioP.Replace("BioP_MP", "BioP_SP");
            using var spBioP = MilanShared.GetLE3Package($"{spBioPName}.pcc");
            if (spBioP == null)
            {
                MilanLog.Warning($"Could not find {spBioPName}.pcc to port m_AutoPersistentObjects from", customPrefix: levelPipeline.LogCategory);
                return;
            }

            var sourceObjects = spBioP.GetBioWorldInfo()?.GetProperty<ArrayProperty<ObjectProperty>>("m_AutoPersistentObjects");
            if (sourceObjects == null)
                return;

            var target = levelPipeline.LE3BioP;
            var targetBwi = target.GetBioWorldInfo();
            var targetObjects = targetBwi.GetProperty<ArrayProperty<ObjectProperty>>("m_AutoPersistentObjects") ?? new ArrayProperty<ObjectProperty>("m_AutoPersistentObjects");

            foreach (var objProp in sourceObjects)
            {
                // Only bring across the map's own content (textures, materials, material instances, decals, etc) -
                // imports are shared assets that don't need to be explicitly re-added.
                if (objProp.ResolveToEntry(spBioP) is not ExportEntry sourceExport)
                    continue;

                MilanLog.Information($"Porting persistent object {sourceExport.InstancedFullPath} from {spBioPName}", customPrefix: levelPipeline.LogCategory);
                EntryExporter.ExportExportToPackage(sourceExport, target, out var newObj, levelPipeline.Cache);
                if (targetObjects.All(x => x.Value != newObj.UIndex))
                {
                    targetObjects.Add(new ObjectProperty(newObj));
                }
            }

            targetBwi.WriteProperty(targetObjects);
        }

        private static void BeginPortingGeneric(LevelSpecificPipeline levelPipeline, TieredPackageCache parent)
        {
            levelPipeline.LogCategory = $"{LOG_CATEGORY}-{levelPipeline.BioP}";
            MilanLog.Information($@"Beginning generic level port: {levelPipeline.BioP}", customPrefix: levelPipeline.LogCategory);

            // Initialize cache
            levelPipeline.Cache = parent.ChainNewCache(debugName: $"MPLevels level cache ({levelPipeline.BioP})");

            var outputPath = Path.Combine(Program.Settings.OutputModPath, @"CookedPCConsole", @"Levels", levelPipeline.BioP);
            Directory.CreateDirectory(outputPath);

            // Register donors
            // SharedMaterialDonor.RegisterLocalDonors(levelPipeline.GetDonorsPath());

            // Get BioP package
            MilanLog.Information($"Loading ME3 BioP", customPrefix: levelPipeline.LogCategory);
            var me3BioP = MilanShared.GetME3Package($"{levelPipeline.BioP}.pcc");
            levelPipeline.ME3BioP = me3BioP;
            levelPipeline.ME3Packages[levelPipeline.BioP] = me3BioP;

            // Get list of subpackages
            var subLevels = LevelShared.GetSublevelPackages(me3BioP);
            if (subLevels != null)
            {
                foreach (var level in subLevels)
                {
                    MilanLog.Information($"Loading sublevel package {level}", customPrefix: levelPipeline.LogCategory);
                    levelPipeline.ME3Packages[level] = MilanShared.GetME3Package($"{level}.pcc");
                }
            }

            PrecorrectPackages(levelPipeline);

            // Port levels
            foreach (var level in levelPipeline.ME3Packages)
            {
                var le3Package = LevelShared.PortLevel(levelPipeline, level.Value);
                MilanLevelTools.RebuildPersistentLevelChildren(le3Package.GetLevel());
            }

            ConfigureBioP(levelPipeline);

            // Save BioP
            levelPipeline.LE3BioP.Save(diskIOSyncLock: MilanShared.DiskIOSyncLock);
            MilanShared.RefreshMilanFiles = true;

            PostcorrectPackages(levelPipeline);

            // Unregister donors
            // SharedMaterialDonor.UnregisterLocalDonors(levelPipeline.GetDonorsPath());

            // Print donors for global shader converter.
            // MilanLog.Information("Material donors required: ", customPrefix: levelPipeline.LogCategory);
            //List<string> shadersListed = new List<string>();
            //foreach (var me3BrokenMat in levelPipeline.MaterialsNeedingDonors)
            //{
            //    ////MilanLog.Warning(me3BrokenMat.InstancedFullPath, customPrefix: levelPipeline.LogCategory);
            //    //var shaderId = SharedMaterialDonor.GetShaderIdString(me3BrokenMat);
            //    //if (!shadersListed.Contains(shaderId))
            //    //{
            //    //    // Seems some materials share shaders...?
            //    //    shadersListed.Add(shaderId);
            //    //    Debug.WriteLine($"// {me3BrokenMat.InstancedFullPath} -> ??? (??)");
            //    //    Debug.WriteLine($"{{\"{shaderId}\", null}},");
            //    //}
            //    DonorTooling.TryMakeDonor(me3BrokenMat, levelPipeline.GetStagingTemporaryDonorPath(), levelPipeline.Cache);
            //}
            // levelPipeline.MaterialsNeedingDonors.Clear();
        }

        private static void ConfigureBioP(LevelSpecificPipeline levelPipeline)
        {
            MilanLog.Information($@"Configuring LE3 BioP", customPrefix: levelPipeline.LogCategory);

            // Add SP start location for testing.
            if (levelPipeline.IsSP)
            {
                MilanShared.CreateSPStartLocation(levelPipeline.LE3BioP, levelPipeline.SPStartLocation);
            }

            int lskIndex = 1;
            var destPersistentLevel = levelPipeline.LE3BioP.GetLevel();

            // Add all LSKs for items that are in our level cache
            foreach (var ol in levelPipeline.ME3Packages.Where(x => x.Value != levelPipeline.ME3BioP))
            {
                var itemToClone = levelPipeline.ME3BioP.Exports.FirstOrDefault(x => x.ClassName == @"LevelStreamingKismet");
                EntryImporter.ImportAndRelinkEntries(EntryImporter.PortingOption.CloneAllDependencies,
                    itemToClone,
                    levelPipeline.LE3BioP, destPersistentLevel, true, new RelinkerOptionsPackage(),
                    out var portedLSK);
                portedLSK.indexValue += 1 + lskIndex++;
                (portedLSK as ExportEntry).WriteProperty(new NameProperty(MilanLevelTools.GetLevelFileName(ol.Key), "PackageName"));
            }
            MilanLevelTools.RebuildStreamingLevels(levelPipeline.LE3BioP, levelPipeline.LogCategory);

            // Port over the BioTriggerStream
            var bts = levelPipeline.ME3BioP.Exports.FirstOrDefault(x => x.ClassName == @"BioTriggerStream");
            if (bts != null)
            {
                EntryImporter.ImportAndRelinkEntries(EntryImporter.PortingOption.CloneAllDependencies, bts,
                    levelPipeline.LE3BioP, destPersistentLevel, true, new RelinkerOptionsPackage(), out var portedBts);
            }

            // Set the KillZ
            var sourceKillZ = levelPipeline.ME3BioP.GetBioWorldInfo().GetProperty<FloatProperty>("KillZ");
            if (sourceKillZ != null)
            {
                levelPipeline.LE3BioP.FindExport(@"TheWorld.PersistentLevel.BioWorldInfo_2").WriteProperty(sourceKillZ);
            }

            // Set game modes
            if (!levelPipeline.IsSP)
            {
                MilanLevelTools.SetupHordeModes(levelPipeline.LE3BioP, levelPipeline.BioP == "MPLobby");
            }

            // Default post processing
            var ppStruct = levelPipeline.ME3BioP.GetBioWorldInfo().GetProperty<StructProperty>("DefaultPostProcessSettings");
            if (ppStruct != null)
            {
                levelPipeline.LE3BioP.GetBioWorldInfo().WriteProperty(ppStruct);
            }

            // Set AdditionalPackagesToCook
            (levelPipeline.LE3BioP as MEPackage).AdditionalPackagesToCook.ReplaceAll(levelPipeline.LE3Packages.Where(x => x.Value != levelPipeline.ME3BioP).Select(x => x.Value.FileNameNoExtension));
            
            MilanLevelTools.RebuildPersistentLevelChildren(destPersistentLevel);
        }



        /// <summary>
        /// Makes changes in ME3 packages before attempting to port them over
        /// </summary>
        /// <param name="levelPipeline"></param>
        private static void PrecorrectPackages(LevelSpecificPipeline levelPipeline)
        {
            if (levelPipeline.IsSP)
            {
                foreach (var package in levelPipeline.ME3Packages)
                {
                    MilanLog.Information($@"Precorrecting {package.Key}", customPrefix: levelPipeline.LogCategory);

                    // SP maps should not set this property.
                    package.Value.GetBioWorldInfo().RemoveProperty("GameTypesSupportedOnThisMap");

                    if (BioTier.IsPersistentPackage(package.Value.FileNameNoExtension + ".pcc"))
                    {
                        // Change to SP for testing
                        var startLoc1 = package.Value.Exports.FirstOrDefault(x => !x.IsDefaultObject && x.ClassName == "BioStartLocationMP");
                        if (startLoc1 == null) startLoc1 = package.Value.Exports.FirstOrDefault(x => !x.IsDefaultObject && x.ClassName == "PlayerStart"); // Hydra uses this. idk why
                        levelPipeline.SPStartLocation = LevelTools.GetLocation(startLoc1);

                        var level = package.Value.GetLevelBinary();
                        for (int i = level.Actors.Count - 1; i > 0; i--)
                        {
                            if (level.Actors[i] == 0)
                                continue; // Skip.
                            var entry = package.Value.GetUExport(level.Actors[i]);
                            if (entry.ClassName == "BioStartLocationMP")
                            {
                                MilanLog.Information($"Stripping BioStartLocationMP {entry.InstancedFullPath}", customPrefix: levelPipeline.LogCategory);
                                level.Actors.RemoveAt(i);
                            }
                        }
                    }
                }
            }
            else
            {
                // MP mode

                // 08/31/2026 - is this still necessary?

                // Convert game modes to imports as that's how they will be in the target game
                var biop = levelPipeline.ME3BioP;
                var bwi = biop.GetBioWorldInfo();
                var gameTypes = bwi.GetProperty<ArrayProperty<ObjectProperty>>("GameTypesSupportedOnThisMap");
                if (gameTypes != null)
                {
                    List<IEntry> newTypes = new List<IEntry>();
                    foreach (var gameType in gameTypes)
                    {
                        var entry = gameType.ResolveToEntry(biop);
                        if (entry is ImportEntry)
                            continue; // Don't care
                        if (entry is ExportEntry exp)
                        {
                            newTypes.Add(EntryImporter.ConvertExportToImport(exp));
                        }
                    }

                    // Write it back
                    bwi.WriteProperty(new ArrayProperty<ObjectProperty>("GameTypesSupportedOnThisMap")
                    { Values = newTypes.Select(x => new ObjectProperty(x)).ToList() });
                }
            }

            levelPipeline.SpecialPrePortingDelegate?.Invoke(levelPipeline);
        }

        /// <summary>
        /// Makes changes to the ported LE3 packages after the level has been ported and saved, then saves any that were modified
        /// </summary>
        /// <param name="levelPipeline"></param>
        private static void PostcorrectPackages(LevelSpecificPipeline levelPipeline)
        {
            if (levelPipeline.SpecialPostPortingDelegate == null)
                return;

            levelPipeline.SpecialPostPortingDelegate.Invoke(levelPipeline);

            foreach (var package in levelPipeline.LE3Packages.Values)
            {
                if (package.IsModified)
                {
                    MilanLog.Information($"  Saving postcorrected package {package.FileNameNoExtension}.pcc", customPrefix: levelPipeline.LogCategory);
                    package.Save(diskIOSyncLock: MilanShared.DiskIOSyncLock);
                    MilanShared.RefreshMilanFiles = true;
                }
            }
        }
    }
}
