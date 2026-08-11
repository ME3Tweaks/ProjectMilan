using ProjectMilanCore;

namespace ProjectMilan.Settings
{
    // Settings for HenBagle's system build
    internal class MilanSettingsHenBagle : IMilanSettings
    {
        public string OutputModPath { get; set; } = $@"D:\MEModding\ME3TweaksModManager\mods\LE3\Project Milan\{MilanShared.DLC_NAME}";
        public string InputSyncPath { get; set; } = @"D:\MEModding\ME3TweaksModManager\mods\LE3\Project Milan\MilanSync";
        public string MilanUDKPath { get; set; } = @"D:\MEModding\UDK";
        public int MaxThreads { get; set; } = 2;

        public bool RunMPCommonPipeline { get; set; } = false;
        public bool RunNonStartupPipeline { get; set; } = false;
        public bool RunDonorBuildPipeline { get; set; } = false;
        public bool RunMP4EnemiesPipeline { get; set; } = false;
        public bool RunKitsPipeline { get; set; } = false;
        public bool RunWeaponsPipeline { get; set; } = false;
        public bool RunRejectionPipeline { get; set; } = false;
        public bool RunRedemptionPipeline { get; set; } = false;
        public bool RunConformancePipeline { get; set; } = false;
        public bool IsStaticLightingBuild { get; set; } = false;
        public bool RunLevelsPipeline { get; set; } = false;
        public bool RunAudioPipeline { get; set; } = true;
        public bool RunTexturePipeline { get; set; } = false;
        public bool RunResynthesis { get; set; } = false;

        public bool DontDeleteModFolder { get; set; } = true;
    }
}