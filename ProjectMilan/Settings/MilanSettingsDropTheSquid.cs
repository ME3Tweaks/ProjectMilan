namespace ProjectMilan.Settings
{
    // Settings for DropTheSquid
    internal class MilanSettingsDropTheSquid : IMilanSettings
    {
        private static readonly bool fullBuild = false;
        public string OutputModPath { get; set; } = @"H:\MELE_Mods\mods in development\LE3\Project Milan\DLC_MOD_ProjectMilan";
        public string InputSyncPath { get; set; } = @"H:\MELE_Mods\mods in development\LE3\Project Milan\MilanSync";
        public bool RunMPCommonPipeline { get; set; } = true;
        public bool RunMP4EnemiesPipeline { get; set; } = fullBuild;
        public bool RunKitsPipeline { get; set; } = fullBuild;
        public bool RunWeaponsPipeline { get; set; } = fullBuild;
        public bool RunLevelsPipeline { get; set; } = fullBuild;
        public bool RunAudioPipeline { get; set; } = false;
        public bool RunTexturePipeline { get; set; } = fullBuild;
        public int MaxThreads { get; set; } = 4;
        public bool DontDeleteModFolder { get; set; } = !fullBuild;
        public bool RunNonStartupPipeline { get; set; } = fullBuild;
        public bool RunResynthesis { get; set; } = fullBuild;
    }
}