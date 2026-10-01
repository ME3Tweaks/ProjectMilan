using ProjectMilan.Pipelines;
using ProjectMilanCore;

namespace ProjectMilan.Settings
{
    // Settings for Kinkojiro's system build
    internal class MilanSettingsKinkojiro : IMilanSettings
    {
        public string OutputModPath { get; set; } = $@"E:\Modding\LE3\Project Milan\{MilanShared.DLC_NAME}";
        public string InputSyncPath { get; set; } = $@"E:\Modding\LE3\Project Milan\InputSync";
        public string TextureSyncFolder { get; set; } = null;
        public bool RunMPCommonPipeline { get; set; }
        public bool RunDonorBuildPipeline { get; set; }
        public bool RunMP4EnemiesPipeline { get; set; }
        public bool RunKitsPipeline { get; set; }
        public bool RunWeaponsPipeline { get; set; }
        public bool RunRejectionPipeline { get; set; }
        public bool RunRedemptionPipeline { get; set; }
        public bool RunConformancePipeline { get; set; } = false;
        public bool IsStaticLightingBuild { get; set; }
        public bool ProductionBuild { get; set; } = false;
        public string MilanUDKPath { get; set; } // NEEDS TO BE SET!
        public string UE4LightmassPath { get; set; } // Null: look up the Epic launcher's UE_4.27 install
        public bool RunLevelsPipeline { get; set; }
        public bool RunAudioPipeline { get; set; }
        public bool RunUpscalePipeline { get; set; } = true;
        public bool RunTexturePipeline { get; set; }
        public bool RunShaderPipeline { get; set; } = false;
        public int MaxThreads { get; set; } = 1;
        public bool DontDeleteModFolder { get; set; }
        public bool RunNonStartupPipeline { get; set; }
        public bool RunResynthesis { get; set; }
        public bool UseCheckpointSystem { get; set; } = false;
        public string CheckpointFolder { get; set; } = @"E:\Modding\LE3\Project Milan\Checkpoint";
        public EModInstallPreference ModInstallPreference { get; set; } = EModInstallPreference.NoInstall;

    }
}
