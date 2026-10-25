using ProjectMilanCore;

namespace ProjectMilan.Settings
{
    internal class IMilanSettingsStumpy : IMilanSettings
    {
        private const string MilanHome = @"Y:\WIP\Milan";
        private const bool FullBuild = false;

        public string OutputModPath { get; set; } = $@"{MilanHome}\ModLib\LMP\Project Milan\{MilanShared.DLC_NAME}";
        public string InputSyncPath { get; set; } = $@"{MilanHome}\Sync";
        public string TextureSyncFolder { get; set; } = null;
        public bool RunMPCommonPipeline { get; set; } = true;
        public bool RunNonStartupPipeline { get; set; } = FullBuild;
        public bool RunDonorBuildPipeline { get; set; } = FullBuild;
        public bool RunMP4EnemiesPipeline { get; set; } = FullBuild;
        public bool RunKitsPipeline { get; set; } = FullBuild;
        public bool RunWeaponsPipeline { get; set; } = FullBuild;
        public bool RunRejectionPipeline { get; set; } = false;
        public bool RunRedemptionPipeline { get; set; } = false;
        public bool RunAssetFixPipeline { get; set; } = false;
        public bool RunConformancePipeline { get; set; } = false;
        public bool RunSlashPipeline { get; set; } = false;
        public bool IsStaticLightingBuild { get; set; } = false;
        public bool ProductionBuild { get; set; } = false;
        public string MilanUDKPath { get; set; } = $@"{MilanHome}\MilanUDK";
        public string UE4LightmassPath { get; set; } // Null: look up the Epic launcher's UE_4.27 install
        public string CustomFFDecPath { get; set; } // Should be picked up automatically
        public bool RunLevelsPipeline { get; set; } = FullBuild;
        public bool RunAudioPipeline { get; set; } = false;
        public bool RunUpscalePipeline { get; set; } = true;
        public bool RunTexturePipeline { get; set; } = FullBuild;
        public bool RunResynthesis { get; set; } = FullBuild;
        public bool RunShaderPipeline { get; set; } = false;

        public int MaxThreads { get; set; } = int.Parse(Environment.GetEnvironmentVariable("MAXTHREADS"));
        public bool DontDeleteModFolder { get; set; } = !FullBuild;
        public bool UseCheckpointSystem { get; set; } = false;
        public string CheckpointFolder { get; set; } = $@"{MilanHome}\Checkpoint";
        public EModInstallPreference ModInstallPreference { get; set; } = EModInstallPreference.NoInstall;

    }
}
