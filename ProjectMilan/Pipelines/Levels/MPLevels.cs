using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using LegendaryExplorerCore.GameFilesystem;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Packages.CloningImportingAndRelinking;
using LegendaryExplorerCore.Unreal;
using LegendaryExplorerCore.Unreal.BinaryConverters;
using ProjectMilan.Pipelines.Levels.MPLobby;
using ProjectMilan.Pipelines.Shared;
using ProjectMilan.Pipelines.Startups;
using ProjectMilan.Utility;

namespace ProjectMilan.Pipelines.Levels
{
    /// <summary>
    /// Pipeline for porting levels across from OT to LE (must be made for multiplayer mode!)
    /// </summary>
    internal class MPLevels
    {
        private const string LOG_CATEGORY = "MILAN-Level";

        class MPLevelsVars
        {
            /// <summary>
            /// Map of DLC map names and if they should be ported across
            /// </summary>
            public readonly List<LevelSpecificPipeline> LevelPipelines = new()
            {
                // MP1 Resurgence
                new LevelSpecificPipeline() { BioP="BioP_MPMoon", Enabled= true, SpecialPortingDelegate = null}, // Condor
                new LevelSpecificPipeline() { BioP="BioP_MPGeth", Enabled = false, SpecialPortingDelegate = null}, // Hydra

                // MP2 Rebellion
                new LevelSpecificPipeline() { BioP="BioP_MPJngl", Enabled= false, SpecialPortingDelegate = null}, // Jade
                new LevelSpecificPipeline() { BioP="BioP_MPThes", Enabled= false, SpecialPortingDelegate = null}, // Goddess

                // MP3 Earth
                new LevelSpecificPipeline() { BioP="BioP_MPOcean", Enabled=false, SpecialPortingDelegate = null}, // Rio
                new LevelSpecificPipeline() { BioP="BioP_MPHosp", Enabled=false, SpecialPortingDelegate = null}, // Vancouver
                new LevelSpecificPipeline() { BioP="BioP_MPRoad", Enabled=false, SpecialPortingDelegate = null}, // London

                // MP4 Retalition
                new LevelSpecificPipeline() { BioP="BioP_MPCer2", Enabled=false, SpecialPortingDelegate = null}, // Glacier - Hazard
                new LevelSpecificPipeline() { BioP="BioP_MPCer3", Enabled=false, SpecialPortingDelegate = null}, // Glacier - Rework (replaces MPCer in ME3)
                new LevelSpecificPipeline() { BioP="BioP_MPDish2", Enabled=false, SpecialPortingDelegate = null}, // Dagger - Hazard
                new LevelSpecificPipeline() { BioP="BioP_MPNov2", Enabled=false, SpecialPortingDelegate = null}, // White - Hazard
                new LevelSpecificPipeline() { BioP="BioP_MPNov3", Enabled=false, SpecialPortingDelegate = null}, // White - Rework (replaces MPNov in ME3)
                new LevelSpecificPipeline() { BioP="BioP_MPRctr2", Enabled=false, SpecialPortingDelegate = null}, // Reactor - Hazard
                new LevelSpecificPipeline() { BioP="BioP_MPSlum2", Enabled=false, SpecialPortingDelegate = null}, // Ghost - Hazard
                new LevelSpecificPipeline() { BioP="BioP_MPTowr2", Enabled=false, SpecialPortingDelegate = null}, // Giant - Hazard
                new LevelSpecificPipeline() { BioP="BioP_MPTowr3", Enabled=false, SpecialPortingDelegate = null}, // Giant - Rework (replaces MPTowr in ME3) - this is a spawn bugfix. MPTowr will be broken in vanilla, we should only use this version.

                // MP5 Reckoning
                // No maps
                // We use MPLobby.pcc level from here
                new LevelSpecificPipeline() { BioP="MPLobby", Enabled=true, SpecialPrePortingDelegate = MPLobbySpecific.PreCorrect}, 

                // Prototype and unused maps
                // These are named that were assigned to the maps for ModMaker
                // There are technically 2 additional variations of MPSub if you swap to a different unused BioD
                new LevelSpecificPipeline() { BioP="BioP_MPThes2", Enabled=false, SpecialPortingDelegate = null}, // Athena (prototype)
                new LevelSpecificPipeline() { BioP="BioP_MPBrdg", Enabled=false, SpecialPortingDelegate = null}, // Gauntlet (prototype)
                new LevelSpecificPipeline() { BioP="BioP_MPFoun", Enabled=false, SpecialPortingDelegate = null}, // Dragon (prototype)
                new LevelSpecificPipeline() { BioP="BioP_MPPump", Enabled=false, SpecialPortingDelegate = null}, // Forge (prototype)
                new LevelSpecificPipeline() { BioP="BioP_MPRays", Enabled=false, SpecialPortingDelegate = null}, // Maelstrom (prototype)
                new LevelSpecificPipeline() { BioP="BioP_MPSub", Enabled=false, SpecialPortingDelegate = null}, // Neptune (prototype)
                new LevelSpecificPipeline() { BioP="BioP_MPTest", Enabled=false, SpecialPortingDelegate = null}, // Scorpion (prototype)
            };
        }

        public static void RunPipeline()
        {
            var vars = new MPLevelsVars();
            InternalRunPipeline(vars);
        }

        private static void InternalRunPipeline(MPLevelsVars levelVars)
        {
            foreach (var level in levelVars.LevelPipelines)
            {
                if (!level.Enabled)
                {
                    // This level is not marked for porting currently.
                    MilanLog.Information($"Skipping level {level.BioP}, pipeline is not enabled");
                    continue;
                }

                BeginPorting(level);
            }
        }

        private static void BeginPorting(LevelSpecificPipeline levelPipeline)
        {
            levelPipeline.LogCategory = $"{LOG_CATEGORY}-{levelPipeline.BioP}";
            MilanLog.Information($@"Beginning generic level port: {levelPipeline.BioP}", customPrefix: levelPipeline.LogCategory);

            // Initialize cache
            levelPipeline.Cache = new PackageCache();

            var outputPath = Path.Combine(Program.Settings.OutputModPath, @"CookedPCConsole", @"Levels", levelPipeline.BioP);
            Directory.CreateDirectory(outputPath);

            // Register donors
            SharedMaterialDonor.RegisterLocalDonors(levelPipeline.GetTemporaryDonorPath());

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
                LevelTools.RebuildPersistentLevelChildren(le3Package.GetLevel());
            }

            ConfigureBioP(levelPipeline);

            // Save BioP
            levelPipeline.LE3BioP.Save();

            // Unregister donors
            SharedMaterialDonor.UnregisterLocalDonors(levelPipeline.GetTemporaryDonorPath());

            // Delete cache
            levelPipeline.Cache.Dispose();
            levelPipeline.Cache = null;
        }

        private static void ConfigureBioP(LevelSpecificPipeline levelPipeline)
        {
            MilanLog.Information($@"Configuring LE3 BioP", customPrefix: levelPipeline.LogCategory);

            // Add SP start location for testing.
            if (levelPipeline.IsSP)
            {
                LevelShared.CreateSPStartLocation(levelPipeline.LE3BioP, levelPipeline.SPStartLocation);
            }

            int lskIndex = 1;
            var destPersistentLevel = levelPipeline.LE3BioP.GetLevel();
            foreach (var ol in levelPipeline.ME3Packages.Where(x => x.Value != levelPipeline.ME3BioP))
            {
                var itemToClone = levelPipeline.ME3BioP.Exports.FirstOrDefault(x => x.ClassName == @"LevelStreamingKismet");
                EntryImporter.ImportAndRelinkEntries(EntryImporter.PortingOption.CloneAllDependencies, itemToClone, levelPipeline.LE3BioP, destPersistentLevel, true, new RelinkerOptionsPackage(), out var portedLSK);
                portedLSK.indexValue += 1 + lskIndex++;
                (portedLSK as ExportEntry).WriteProperty(new NameProperty(LevelTools.GetLevelFileName(ol.Key), "PackageName"));
            }
            LevelTools.RebuildStreamingLevels(levelPipeline.LE3BioP, levelPipeline);

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
                var mpContent = levelPipeline.LE3BioP.FindEntry("SFXGameMPContent") ?? ExportCreator.CreatePackageExport(levelPipeline.LE3BioP, "SFXGameMPContent");
                ImportEntry infoMP = new ImportEntry(levelPipeline.LE3BioP) { ObjectName = "SFXGameInfoMP", idxLink = mpContent.UIndex, ClassName = "Class", PackageFile = "Core" };
                ImportEntry gameTypeHorde = new ImportEntry(levelPipeline.LE3BioP) { ObjectName = "SFXGameType_Horde_Operation", idxLink = mpContent.UIndex, ClassName = "Class", PackageFile = "Core" };
                levelPipeline.LE3BioP.AddImport(infoMP);
                levelPipeline.LE3BioP.AddImport(gameTypeHorde);
                levelPipeline.LE3BioP.FindExport(@"TheWorld.PersistentLevel.BioWorldInfo_2").WriteProperty(
                    new ArrayProperty<ObjectProperty>("GameTypesSupportedOnThisMap")
                    {
                        new ObjectProperty(infoMP),
                        new ObjectProperty(gameTypeHorde)
                    });
            }

            // Default post processing
            var ppStruct = levelPipeline.ME3BioP.GetBioWorldInfo().GetProperty<StructProperty>("DefaultPostProcessSettings");
            if (ppStruct != null)
            {
                levelPipeline.LE3BioP.GetBioWorldInfo().WriteProperty(ppStruct);
            }



            LevelTools.RebuildPersistentLevelChildren(destPersistentLevel);
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

                    // Todo: once MPCommon is functional, this will no longer be necessary.
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
    }
}
