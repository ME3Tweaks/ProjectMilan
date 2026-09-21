using LegendaryExplorerCore.Coalesced.Config;
using LegendaryExplorerCore.Packages;
using ProjectMilan;
using ProjectMilan.Utility;
using ProjectMilan_ExtraContent.Redemption.Levels;
using ProjectMilan_ExtraContent.Redemption.Levels.CrossGenV;
using ProjectMilan_ExtraContent.Redemption.Levels.CrossGenV.Audio;
using ProjectMilan_ExtraContent.Redemption.Levels.MapPack;
using ProjectMilan_ExtraContent.Shared;
using ProjectMilanCore;

namespace ProjectMilan_ExtraContent.Redemption
{
    public static class RedemptionPipeline
    {
        private static string CookedPCFolder => Path.Combine(MilanPipelinesShared.OutputModPath, "CookedPCConsole");
        internal static string PipelineRoot => Path.Combine(SharedECPipelines.ECPipelineRoot, "Redemption");


        /// <summary>
        /// Prepares the mod folder and then runs the pipeline. Runs when you are only building EC.
        /// </summary>
        public static void RunPipelineEC()
        {
            ExtraContentStorage.PrepareContent(EExtraContent.Redemption);
            RunPipeline();
            // In EC we should move textures to TFC as well as compact them
            MilanShared.MoveTexturesToTFC("Textures", MilanShared.REDEMPTION_DLC_NAME, false, @"MILANEC-TFC");
            MilanShared.MoveTexturesToTFC("Lighting", MilanShared.REDEMPTION_DLC_NAME, true, @"MILANEC-TFC");
            ExtraContentStorage.CompactTFC(EExtraContent.Redemption, false); // Pull textures
            ExtraContentStorage.CompactTFC(EExtraContent.Redemption, true); // Pull lighting
            ExtraContentStorage.CompactAFC(EExtraContent.Redemption);

            // Convert the licensee version on packages.
            MilanLicensee.RunPipeline(MilanPipelinesShared.OutputModPath);
  
            ExtraContentStorage.SaveContent();
        }

        /// <summary>
        /// Runs the pipeline, assuming folder is already prepared for mod use. This is what is called by Project Milan's main project.
        ///
        /// TODO: 09/20/2026
        /// KNOWN GAP: when called this way (in-process from ProjectMilan's own Program.cs, as opposed to
        /// standalone via RunPipelineEC()), MilanPipelinesShared.TLKSet/TLKStartIndex are never initialized by
        /// the main mod. BuildCrossgenLevel() -> RedemptionShared.AddLevelToConfig() -> AssignTLK() will throw
        /// if ECLevelBuild.CrossGenVMaps is enabled for a run like that. ConfigBundle/OutputModPath are fine
        /// (ModBuilder sets those up for the main mod before this stage runs), it's specifically the TLK side
        /// that's unaddressed - not fixed here, flagged so it isn't forgotten.
        /// </summary>
        public static void RunPipeline()
        {
            var vars = new RedemptionVars();
            Directory.CreateDirectory(CookedPCFolder); // Ensure it exists.
            InternalRunPipeline(vars);

            // Flush whatever maps were just registered (CrossGenV, via AddLevelToConfig) into whichever
            // config bundle is currently active - the main mod's own Default_<DLC_NAME>.bin when called
            // in-process, or Redemption's own separate bin when called standalone via RunPipelineEC() below
            // (a harmless redundant flush there, ahead of ExtraContentStorage.SaveContent()'s own commit).
            MilanPipelinesShared.CommitConfigBundle();
        }

        private static void InternalRunPipeline(RedemptionVars vars)
        {
            BuildLevels(vars);

            // Content saving is done in the EC wrapper for EC runs.

            // Save the redemption map images
            RedemptionShared.SaveMapImagesPackage();
        }

        private static void BuildLevels(RedemptionVars vars)
        {
            BuildCrossgenLevel();
            BuildRedemptionLevels();
        }

        private static void BuildRedemptionLevels()
        {
            if (!ECLevelBuild.RedemptionMaps)
            {
                MilanLog.Information("Redemption DLC mod levels are not enabled for build, skipping.");
                return;
            }

            MPMapPackBuild.BuildLevels();
        }

        private static void BuildCrossgenLevel()
        {
            // Causes failure if it doesn't exist.
            if (!ECLevelBuild.CrossGenVMaps)
            {
                MilanLog.Information("CrossGenV mod levels are not enabled for build, skipping.");
                return;

            }
            var test = CrossGenVShared.SourceFilesFolder;

            // Built once for all the Pinnacle Station levels. BioSnd_Vegas is the staging package: each BioD gets a
            // local copy of its Wwise_Vegas export tree, while all of those WwiseStreams point at the one shared AFC.
            // The levels below also need the scan it produces to map LE1 cues to their generated event names.
            VegasAudioPipeline.BuildAndImport(
                Path.Combine(Path.GetTempPath(), "MilanVegasAudio"),
                Path.Combine(MilanPipelinesShared.OutputModPath, "CookedPCConsole"));

            using TieredPackageCache cache = TieredPackageCache.GetGlobalPackageCache(MEGame.LE3, debugName: "Redemption BuildCrossgenLevel global LE3 root");
            var audioLevelPaths = new List<string>();
            foreach (var level in CrossGenVShared.CrossgenLevels.Where(x => x.Enabled))
            {
                CrossGenVShared.BuildLevel(level, cache);

                var designSource = level.LevelFilesMap.Keys.FirstOrDefault(x => x.EndsWith("_DSG", StringComparison.OrdinalIgnoreCase));
                if (designSource != null)
                {
                    audioLevelPaths.Add(Path.Combine(level.OutputPath, level.LevelFilesMap[designSource] + ".pcc"));
                }
            }

            // Run only after all level files exist, so local and cross-level imports have their complete search set.
            VegasAudioPipeline.ValidateBuiltLevelImports(audioLevelPaths, cache);
        }
    }

    internal class RedemptionVars
    {
    }
}
