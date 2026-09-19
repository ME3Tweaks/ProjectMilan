using ProjectMilan.Pipelines;
using ProjectMilanCore;

namespace ProjectMilan.Settings
{
    // Settings for SirCxyrtyx's system build
    internal class MilanSettingsSirCxyrtyx : IMilanSettings
    {
        public string OutputModPath { get; set; } = $@"C:\Users\natal\Documents\ME3TweaksModManager\mods\LE3\Project Milan\{MilanShared.DLC_NAME}";
        public string InputSyncPath { get; set; } = @"C:\Users\natal\Documents\ME3TweaksModManager\mods\LE3\Project Milan\MilanSync";
        public bool RunMPCommonPipeline { get; set; } = true;
        public bool RunNonStartupPipeline { get; set; } = false;
        public bool RunDonorBuildPipeline { get; set; } = false;
        public bool RunMP4EnemiesPipeline { get; set; } = false;
        public bool RunKitsPipeline { get; set; } = false;
        public bool RunWeaponsPipeline { get; set; } = false;
        public bool RunRejectionPipeline { get; set; } = false;
        public bool RunRedemptionPipeline { get; set; } = false;
        public bool RunConformancePipeline { get; set; } = false;
        public bool IsStaticLightingBuild { get; set; }
        public string MilanUDKPath { get; set; } // NEEDS TO BE SET!
        public bool RunLevelsPipeline { get; set; } = false;
        public bool RunAudioPipeline { get; set; } = false;
        public bool RunTexturePipeline { get; set; } = false;
        public bool RunResynthesis { get; set; } = false;
        public bool RunShaderPipeline { get; set; } = false;


        public int MaxThreads { get; set; } = 4;

        public bool DontDeleteModFolder { get; set; } = false;
        public bool UseCheckpointSystem { get; set; } = false;
        public string CheckpointFolder { get; set; } = @"C:\Users\natal\Documents\ME3TweaksModManager\mods\LE3\Project Milan\Checkpoint";
        public EModInstallPreference ModInstallPreference { get; set; } = EModInstallPreference.NoInstall;

    }
}
