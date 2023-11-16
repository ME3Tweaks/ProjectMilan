namespace ProjectMilan.Settings
{
    // Settings for Mgamerz' system build
    internal class MilanSettingsMgamerz : IMilanSettings
    {
        public string OutputPath { get; set; } = @"Z:\ModLibrary\LE3\Project Milan\MilanOutput";
        public bool RunMPLobbyClassesPipeline { get; set; } = true;
        public bool RunConfigPipeline { get; set; } = true;
        public bool RunKitsPipeline { get; set; } = true;
        public bool RunLevelsPipeline { get; set; } = true;
    }
}
