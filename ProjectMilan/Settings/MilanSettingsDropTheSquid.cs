namespace ProjectMilan.Settings
{
    // Settings for DropTheSquid
    internal class MilanSettingsDropTheSquid : IMilanSettings
    {
        public string OutputModPath { get; set; } = @"H:\MELE_Mods\mods in development\LE3\Project Milan\DLC_MOD_ProjectMilan"; 
        public string InputSyncPath { get; set; } = @"H:\MELE_Mods\mods in development\LE3\Project Milan\MilanSync";
        public bool RunMPCommonPipeline { get; set; } = false;
        public bool RunKitsPipeline { get; set; }
        public bool RunLevelsPipeline { get; set; } = true;
        public bool RunAudioPipeline { get; set; }
        public bool RunTexturePipeline { get; set; }
        public int MaxThreads { get; set; } = 2;
        public bool DontDeleteModFolder { get; set; }
        public bool RunNonStartupPipeline { get; set; } = false;
    }
}