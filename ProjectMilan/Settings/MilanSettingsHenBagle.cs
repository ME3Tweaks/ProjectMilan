namespace ProjectMilan.Settings
{
    // Settings for HenBagle's system build
    internal class MilanSettingsHenBagle : IMilanSettings
    {
        public string OutputModPath { get; set; } = @"UNDEFINED"; // Z:\ModLibrary\LE3\Project Milan\MilanOutput
        public string InputSyncPath { get; set; } // must be defined
        public bool RunMPLobbyClassesPipeline { get; set; }
        public bool RunConfigPipeline { get; set; }
        public bool RunKitsPipeline { get; set; }
        public bool RunLevelsPipeline { get; set; }
        public bool RunAudioPipeline { get; set; }
        public bool RunTexturePipeline { get; set; }
    }
}