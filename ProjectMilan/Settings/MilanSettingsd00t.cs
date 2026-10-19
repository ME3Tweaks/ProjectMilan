using ProjectMilan.Pipelines;
using ProjectMilanCore;

namespace ProjectMilan.Settings
{
    // Settings for d00t's system build
    internal class MilanSettingsd00t : IMilanSettings
    {
        public string OutputModPath { get; set; } = @$"E:\Milan\_Library\LE3\ProjectMilan\{MilanShared.DLC_NAME}";
        public string InputSyncPath { get; set; } = @"E:\Milan\_Library\LE3\ProjectMilan\MilanSync";
        public string TextureSyncFolder { get; set; } = null;

        public bool RunMPCommonPipeline { get; set; } = true;
        public bool RunNonStartupPipeline { get; set; } = true;
        public bool RunDonorBuildPipeline { get; set; } = true;
        public bool RunMP4EnemiesPipeline { get; set; } = true;
        public bool RunKitsPipeline { get; set; } = true;
        public bool RunWeaponsPipeline { get; set; } = true;
        public bool RunRejectionPipeline { get; set; }
        public bool RunRedemptionPipeline { get; set; }
        public bool RunAssetFixPipeline { get; set; } = false;
        public bool RunConformancePipeline { get; set; } = false;
        public bool IsStaticLightingBuild { get; set; }
        public bool ProductionBuild { get; set; } = false;
        public string MilanUDKPath { get; set; } = @"C:\Software\UDK\UDK-2015-01-MILAN";
        public string UE4LightmassPath { get; set; } // Null: look up the Epic launcher's UE_4.27 install
        public string CustomFFDecPath { get; set; } // Should be picked up automatically
        public bool RunLevelsPipeline { get; set; } = true;
        public bool RunAudioPipeline { get; set; } = false;
        public bool RunUpscalePipeline { get; set; } = true;
        public bool RunTexturePipeline { get; set; } = true;
        public bool RunResynthesis { get; set; } = false;
        public bool RunShaderPipeline { get; set; } = false;

        public int MaxThreads { get; set; } = 16;
        public bool DontDeleteModFolder { get; set; } = false;
        public bool UseCheckpointSystem { get; set; } = false;
        public string CheckpointFolder { get; set; } = @"E:\Milan\_Library\LE3\ProjectMilan\Checkpoint";
        public EModInstallPreference ModInstallPreference { get; set; } = EModInstallPreference.NoInstall;

    }
}
