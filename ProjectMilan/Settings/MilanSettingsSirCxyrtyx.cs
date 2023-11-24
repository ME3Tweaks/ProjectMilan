namespace ProjectMilan.Settings
{
    // Settings for SirCxyrtyx's system build
    internal class MilanSettingsSirCxyrtyx : IMilanSettings
    {
        public string OutputModPath { get; set; } = @"UNDEFINED"; // Z:\ModLibrary\LE3\Project Milan\MilanOutput
        public string InputSyncPath { get; set; } // must be defined
        public bool RunMPCommonPipeline { get; set; }
        public bool RunKitsPipeline { get; set; }
        public bool RunLevelsPipeline { get; set; }
        public bool RunAudioPipeline { get; set; }
        public bool RunTexturePipeline { get; set; }
        public int MaxThreads { get; set; } = 1;
    }
}