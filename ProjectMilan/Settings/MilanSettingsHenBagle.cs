using ProjectMilanCore;

namespace ProjectMilan.Settings
{
    // Settings for HenBagle's system build
    internal class MilanSettingsHenBagle : IMilanSettings
    {
        public string OutputModPath { get; set; } = $@"D:\MEModding\ME3TweaksModManager\mods\LE3\Project Milan\{MilanShared.DLC_NAME}";
        public string InputSyncPath { get; set; } = @"D:\MEModding\ME3TweaksModManager\mods\LE3\Project Milan\MilanSync";
        public string TextureSyncFolder { get; set; } = null;
        public string MilanUDKPath { get; set; } = @"D:\MEModding\UDK";
        public string UE4LightmassPath { get; set; } // Null: look up the Epic launcher's UE_4.27 install
        public string CustomFFDecPath { get; set; } // Should be picked up automatically
        public int MaxThreads { get; set; } = 2;

        public bool RunMPCommonPipeline { get; set; } = false;
        public bool RunNonStartupPipeline { get; set; } = false;
        public bool RunDonorBuildPipeline { get; set; } = false;
        public bool RunMP4EnemiesPipeline { get; set; } = false;
        public bool RunKitsPipeline { get; set; } = false;
        public bool RunWeaponsPipeline { get; set; } = false;
        public bool RunRejectionPipeline { get; set; } = false;
        public bool RunRedemptionPipeline { get; set; } = false;
        public bool RunAssetFixPipeline { get; set; } = false;
        public bool RunConformancePipeline { get; set; } = false;
        public bool RunSlashPipeline { get; set; } = false;
        public bool IsStaticLightingBuild { get; set; } = false;
        public bool ProductionBuild { get; set; } = false;
        public bool RunLevelsPipeline { get; set; } = false;
        public bool RunAudioPipeline { get; set; } = true;
        public bool RunUpscalePipeline { get; set; } = true;
        public bool RunTexturePipeline { get; set; } = false;
        public bool RunResynthesis { get; set; } = false;
        public bool RunShaderPipeline { get; set; } = false;

        public bool DontDeleteModFolder { get; set; } = true;
        public bool UseCheckpointSystem { get; set; } = false;
        public string CheckpointFolder { get; set; } = @"D:\MEModding\ME3TweaksModManager\mods\LE3\Project Milan\Checkpoint";    
        public EModInstallPreference ModInstallPreference { get; set; } = EModInstallPreference.NoInstall;

    }
}
