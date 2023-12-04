namespace ProjectMilan.Settings
{
    // Settings for DropTheSquid
    internal class MilanSettingsDropTheSquid : IMilanSettings
    {
        public string OutputModPath { get; set; } = @"UNDEFINED"; // Z:\ModLibrary\LE3\Project Milan\MilanOutput
        public string InputSyncPath { get; set; } // must be defined
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