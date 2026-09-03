using LegendaryExplorerCore.Coalesced.Config;
using LegendaryExplorerCore.Packages;
using ProjectMilan;
using ProjectMilan.Utility;
using ProjectMilan_ExtraContent.Redemption.Levels;
using ProjectMilan_ExtraContent.Redemption.Levels.CrossGenV;
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
        /// </summary>
        public static void RunPipeline()
        {
            var vars = new RedemptionVars();
            Directory.CreateDirectory(CookedPCFolder); // Ensure it exists.
            InternalRunPipeline(vars);
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

            using TieredPackageCache cache = TieredPackageCache.GetGlobalPackageCache(MEGame.LE3, debugName: "Redemption BuildCrossgenLevel global LE3 root");
            foreach (var level in CrossGenVShared.CrossgenLevels.Where(x => x.Enabled))
            {
                CrossGenVShared.BuildLevel(level, cache);
            }
        }
    }

    internal class RedemptionVars
    {
    }
}
