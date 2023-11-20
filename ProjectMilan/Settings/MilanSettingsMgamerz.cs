namespace ProjectMilan.Settings
{
    // Settings for Mgamerz' system build
    internal class MilanSettingsMgamerz : IMilanSettings
    {
        public string OutputPath { get; set; } = @"Z:\ModLibrary\LE3\Project Milan\DLC_MOD_ProjectMilan\CookedPCConsole\MilanOutput";
        public string InputSyncPath { get; set; } = @"Z:\ModLibrary\LE3\Project Milan\MilanSync";

        public bool RunMPLobbyClassesPipeline { get; set; } = true;
        public bool RunConfigPipeline { get; set; } = false;
        public bool RunKitsPipeline { get; set; } = false;
        public bool RunLevelsPipeline { get; set; } = false;
        public bool RunAudioPipeline { get; set; } = false;
        public bool RunTexturePipeline { get; set; }
    }
}
