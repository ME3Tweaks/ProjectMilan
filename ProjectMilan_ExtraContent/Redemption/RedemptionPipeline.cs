using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using LegendaryExplorerCore.Coalesced.Config;
using LegendaryExplorerCore.Packages;
using ProjectMilan_ExtraContent.Redemption.Levels.CrossGenV;
using ProjectMilan_ExtraContent.Shared;
using ProjectMilanCore;

namespace ProjectMilan_ExtraContent.Redemption
{
    public static class RedemptionPipeline
    {
        public static ConfigAssetBundle CurrentConfig { get; set; }
        private static string CookedPCFolder => Path.Combine(BaseBuildSettings.OutputModPath, "CookedPCConsole");


        /// <summary>
        /// Prepares the mod folder and then runs the pipeline. Runs when you are only building EC.
        /// </summary>
        public static void RunPipelineEC()
        {
            ExtraContentInit.PrepareContent(EExtraContent.Redemption);
            RunPipeline();
            MilanShared.MoveTexturesToTFC("Textures", MilanShared.REDEMPTION_DLC_NAME, false, @"MILANEC-TFC");
            MilanShared.MoveTexturesToTFC("Lighting", MilanShared.REDEMPTION_DLC_NAME, true, @"MILANEC-TFC");
            // ExtraContentInit.CompactTFC(EExtraContent.Redemption, false); // Milan main will handle this when it pulls everything together
            ExtraContentInit.CompactAFC(EExtraContent.Redemption); // Milan main will handle this when it pulls everything together
        }

        /// <summary>
        /// Runs the pipeline, assuming folder is already prepared for mod use.
        /// </summary>
        public static void RunPipeline()
        {
            var vars = new RedemptionVars();
            Directory.CreateDirectory(CookedPCFolder); // Ensure it exists.
            InternalRunPipeline(vars);
        }

        private static void InternalRunPipeline(RedemptionVars vars)
        {
            CurrentConfig = SharedECPipelines.MergeConfig(EExtraContent.Redemption);
            SharedECPipelines.MergeTLK(EExtraContent.Redemption);

            BuildLevels(vars);

            // Finalize

            // Write config bundle.
            var configDest = Path.Combine(BaseBuildSettings.OutputModPath, "CookedPCConsole", $"Default_{Path.GetFileName(BaseBuildSettings.OutputModPath)}.bin"); // Points to output directory .bin, could be milan or R2
            CurrentConfig.CommitAssets(configDest, MELocalization.None);
            
            // Write TLK data.
            RedemptionShared.SaveTlks();
        }

        private static void BuildLevels(RedemptionVars vars)
        {
            BuildArmaxLevels();
            BuildCrossgenLevel();
            BuildRedemptionLevels();
        }

        private static void BuildRedemptionLevels()
        {

        }

        private static void BuildCrossgenLevel()
        {
            // Causes failure if it doesn't exist.
            var test = CrossGenVShared.SourceFilesFolder;

            TieredPackageCache cache = TieredPackageCache.GetGlobalPackageCache(MEGame.LE3);
            foreach (var level in CrossGenVShared.CrossgenLevels.Where(x => x.Enabled))
            {
                CrossGenVShared.BuildLevel(level, cache);
            }
        }

        private static void BuildArmaxLevels()
        {

        }
    }

    internal class RedemptionVars
    {
    }
}
