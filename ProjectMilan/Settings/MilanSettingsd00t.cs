using ProjectMilan.Pipelines;
using ProjectMilanCore;

namespace ProjectMilan.Settings
{
    // Settings for d00t's system build
    internal class MilanSettingsd00t : IMilanSettings
    {
        public string OutputModPath { get; set; } = @$"E:\Milan\_Library\LMP\Legendary Edition Multiplayer Dev\{MilanShared.DLC_NAME}";
        public string InputSyncPath { get; set; } = @"E:\Milan\_Library\LMP\Legendary Edition Multiplayer Dev\MilanSync";
        public string TextureSyncFolder { get; set; } = null;

        public bool RunMPCommonPipeline { get; set; } = true;
        public bool RunNonStartupPipeline { get; set; } = true;
        public bool RunDonorBuildPipeline { get; set; } = true;
        public bool RunMP4EnemiesPipeline { get; set; } = true;
        public bool RunKitsPipeline { get; set; } = true;
        public bool RunWeaponsPipeline { get; set; } = true;
        public bool RunRejectionPipeline { get; set; } = false;
        public bool RunRedemptionPipeline { get; set; } = false;
        public bool RunAssetFixPipeline { get; set; } = true;
        public bool RunConformancePipeline { get; set; } = true;
        public bool RunSlashPipeline { get; set; } = false;
        public bool IsStaticLightingBuild { get; set; } = false;
        public bool ProductionBuild { get; set; } = false;
        public string MilanUDKPath { get; set; } = @"C:\Software\UDK\UDK-2015-01-MILAN";
        public string UE4LightmassPath { get; set; } // Null: look up the Epic launcher's UE_4.27 install
        public string CustomFFDecPath { get; set; } = @"E:\Software\ffdec_26.4.0";
        public bool RunLevelsPipeline { get; set; } = false;
        public bool RunAudioPipeline { get; set; } = true;
        public bool RunUpscalePipeline { get; set; } = false;
        public bool RunTexturePipeline { get; set; } = true;
        public bool RunResynthesis { get; set; } = true;
        public bool RunShaderPipeline { get; set; } = false;

        public int MaxThreads { get; set; } = 16;
        public bool DontDeleteModFolder { get; set; } = false;
        public bool UseCheckpointSystem { get; set; } = true;
        public string CheckpointFolder { get; set; } = @"E:\Milan\_Library\LMP\Legendary Edition Multiplayer Dev\Checkpoint";
        public EModInstallPreference ModInstallPreference { get; set; } = EModInstallPreference.NoInstall;

    }
}
