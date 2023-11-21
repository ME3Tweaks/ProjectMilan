namespace ProjectMilan.Settings
{
    // Settings for Mgamerz' system build
    internal class MilanSettingsMgamerz : IMilanSettings
    {
        public string OutputModPath { get; set; } = @"Z:\ModLibrary\LE3\Project Milan\DLC_MOD_ProjectMilan";
        public string InputSyncPath { get; set; } = @"Z:\ModLibrary\LE3\Project Milan\MilanSync";

        public bool RunMPCommonPipeline { get; set; } = true;
        public bool RunKitsPipeline { get; set; } = true;
        public bool RunLevelsPipeline { get; set; } = true;
        public bool RunAudioPipeline { get; set; }
        public bool RunTexturePipeline { get; set; }
    }
}
