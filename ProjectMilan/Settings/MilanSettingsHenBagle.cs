using ProjectMilan.Pipelines;

namespace ProjectMilan.Settings
{
    // Settings for HenBagle's system build
    internal class MilanSettingsHenBagle : IMilanSettings
    {
        public string OutputModPath { get; set; } = $@"D:\Mass Effect Modding\ME3TweaksModManager\mods\LE3\Project Milan\{MilanShared.DLC_NAME}";
        public string InputSyncPath { get; set; } = @"D:\Mass Effect Modding\ME3TweaksModManager\mods\LE3\Project Milan\MilanSync";
        public bool RunMPCommonPipeline { get; set; } = false;
        public bool RunKitsPipeline { get; set; } = false;
        public bool RunWeaponsPipeline { get; set; } = false;
        public bool RunLevelsPipeline { get; set; } = true;
        public bool RunAudioPipeline { get; set; } = true;
        public bool RunTexturePipeline { get; set; } = false;
        public int MaxThreads { get; set; } = 1;
        public bool DontDeleteModFolder { get; set; } = false;
        public bool RunNonStartupPipeline { get; set; } = false;
        public bool RunResynthesis { get; set; } = false;
    }
}