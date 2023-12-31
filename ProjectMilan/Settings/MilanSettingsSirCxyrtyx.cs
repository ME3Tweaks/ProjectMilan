using ProjectMilan.Pipelines;

namespace ProjectMilan.Settings
{
    // Settings for SirCxyrtyx's system build
    internal class MilanSettingsSirCxyrtyx : IMilanSettings
    {
        public string OutputModPath { get; set; } = $@"C:\Users\natal\Documents\ME3TweaksModManager\mods\LE3\Project Milan\{MilanShared.DLC_NAME}";
        public string InputSyncPath { get; set; } = @"C:\Users\natal\Documents\ME3TweaksModManager\mods\LE3\Project Milan\MilanSync";
        public bool RunMPCommonPipeline { get; set; } = true;
        public bool RunMP4EnemiesPipeline { get; set; } = true;
        public bool RunKitsPipeline { get; set; }
        public bool RunWeaponsPipeline { get; set; }
        public bool RunLevelsPipeline { get; set; }
        public bool RunAudioPipeline { get; set; }
        public bool RunTexturePipeline { get; set; }
        public int MaxThreads { get; set; } = 2;
        public bool DontDeleteModFolder { get; set; }
        public bool RunNonStartupPipeline { get; set; }
        public bool RunResynthesis { get; set; }
    }
}