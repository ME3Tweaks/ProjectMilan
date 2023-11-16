namespace ProjectMilan.Settings
{
    // Settings for SirCxyrtyx's system build
    internal class MilanSettingsSirCxyrtyx : IMilanSettings
    {
        public string OutputPath { get; set; } = @"UNDEFINED"; // Z:\ModLibrary\LE3\Project Milan\MilanOutput
        public bool RunMPLobbyClassesPipeline { get; set; }
        public bool RunConfigPipeline { get; set; }
        public bool RunKitsPipeline { get; set; }
        public bool RunLevelsPipeline { get; set; }
    }
}