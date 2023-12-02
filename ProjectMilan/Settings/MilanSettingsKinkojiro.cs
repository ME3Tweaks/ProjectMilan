using ProjectMilan.Pipelines;

namespace ProjectMilan.Settings
{
    // Settings for Kinkojiro's system build
    internal class MilanSettingsKinkojiro : IMilanSettings
    {
        public string OutputModPath { get; set; } = $@"E:\Modding\LE3\Project Milan\{MilanShared.DLC_NAME}";
        public string InputSyncPath { get; set; } = $@"E:\Modding\LE3\Project Milan\InputSync";
        public bool RunMPCommonPipeline { get; set; }
        public bool RunKitsPipeline { get; set; }
        public bool RunLevelsPipeline { get; set; }
        public bool RunAudioPipeline { get; set; }
        public bool RunTexturePipeline { get; set; }
        public int MaxThreads { get; set; } = 1;
        public bool DontDeleteModFolder { get; set; }
        public bool RunNonStartupPipeline { get; set; }
    }
}