using ProjectMilan.Pipelines;
using ProjectMilanCore;

namespace ProjectMilan.Settings
{
    // Settings for d00t's system build
    internal class MilanSettingsd00t : IMilanSettings
    {
        public string OutputModPath { get; set; } = @$"D:\ME3TM2Library\LE3\Milan\{MilanShared.DLC_NAME}";
        public string InputSyncPath { get; set; } = @"D:\ME3TM2Library\LE3\Milan\MilanSync";

        public bool RunMPCommonPipeline { get; set; } = true;
        public bool RunNonStartupPipeline { get; set; } = true;
        public bool RunDonorBuildPipeline { get; set; } = true;
        public bool RunMP4EnemiesPipeline { get; set; } = true;
        public bool RunKitsPipeline { get; set; } = true;
        public bool RunWeaponsPipeline { get; set; } = true;
        public bool RunRejectionPipeline { get; set; }
        public bool RunRedemptionPipeline { get; set; }
        public bool IsStaticLightingBuild { get; set; }
        public string MilanUDKPath { get; set; } // NEEDS TO BE SET!
        public bool RunLevelsPipeline { get; set; } = true;
        public bool RunAudioPipeline { get; set; } = false;
        public bool RunTexturePipeline { get; set; } = true;
        public bool RunResynthesis { get; set; } = false;

        public int MaxThreads { get; set; } = 16;
        public bool DontDeleteModFolder { get; set; } = false;
    }
}