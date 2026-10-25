using ProjectMilanCore;

namespace ProjectMilan.Settings
{
    // Settings for beccatoria
    internal class MilanSettingsbeccatoria : IMilanSettings
    {
        private static readonly bool fullBuild = false;
        public string OutputModPath { get; set; } = $@"C:\Users\becca\Downloads\MILAN\ME3Tweaks Mod Manager Milan Build\mods\LMP\Project Milan\{MilanShared.DLC_NAME}";
        public string InputSyncPath { get; set; } = @"C:\Users\becca\Downloads\MILAN\ME3Tweaks Mod Manager Milan Build\mods\LMP\Project Milan\MilanSync";
        public string TextureSyncFolder { get; set; } = null;
        public bool RunMPCommonPipeline { get; set; } = true;
        public bool RunDonorBuildPipeline { get; set; } = fullBuild;
        public bool RunMP4EnemiesPipeline { get; set; } = fullBuild;
        public bool RunKitsPipeline { get; set; } = fullBuild;
        public bool RunWeaponsPipeline { get; set; } = fullBuild;
        public bool RunRejectionPipeline { get; set; }
        public bool RunRedemptionPipeline { get; set; }
        public bool RunAssetFixPipeline { get; set; } = false;
        public bool RunConformancePipeline { get; set; } = false;
        public bool RunSlashPipeline { get; set; } = false;
        public bool IsStaticLightingBuild{ get; set; }
        public bool ProductionBuild { get; set; } = false;
        public string MilanUDKPath { get; set; } // NEEDS TO BE SET!
        public string UE4LightmassPath { get; set; } // Null: look up the Epic launcher's UE_4.27 install
        public string CustomFFDecPath { get; set; } // Should be picked up automatically
        public bool RunLevelsPipeline { get; set; } = fullBuild;
        public bool RunAudioPipeline { get; set; } = false;
        public bool RunUpscalePipeline { get; set; } = true;
        public bool RunTexturePipeline { get; set; } = fullBuild;
        public bool RunShaderPipeline { get; set; } = false;
        public int MaxThreads { get; set; } = 4;
        public bool DontDeleteModFolder { get; set; } = !fullBuild;
        public bool RunNonStartupPipeline { get; set; } = fullBuild;
        public bool RunResynthesis { get; set; } = fullBuild;
        public bool UseCheckpointSystem { get; set; } = false;
        public string CheckpointFolder { get; set; } = @"C:\Users\becca\Downloads\MILAN\ME3Tweaks Mod Manager Milan Build\mods\LMP\Project Milan\Checkpoint";
        public EModInstallPreference ModInstallPreference { get; set; } = EModInstallPreference.NoInstall;

    }
}
