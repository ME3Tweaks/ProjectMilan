namespace ProjectMilan.Settings
{
    // Settings for DropTheSquid
    internal class MilanSettingsDropTheSquid : IMilanSettings
    {
        private static readonly bool fullBuild = false;
        public string OutputModPath { get; set; } = @"H:\MELE_Mods\mods in development\LE3\Project Milan\DLC_MOD_ProjectMilan";
        public string InputSyncPath { get; set; } = @"H:\MELE_Mods\mods in development\LE3\Project Milan\MilanSync";
        public string TextureSyncFolder { get; set; } = null;
        public bool RunMPCommonPipeline { get; set; } = true;
        public bool RunDonorBuildPipeline { get; set; } = fullBuild;
        public bool RunMP4EnemiesPipeline { get; set; } = fullBuild;
        public bool RunKitsPipeline { get; set; } = fullBuild;
        public bool RunWeaponsPipeline { get; set; } = fullBuild;
        public bool RunRejectionPipeline { get; set; }
        public bool RunRedemptionPipeline { get; set; }
        public bool RunConformancePipeline { get; set; } = false;
        public bool IsStaticLightingBuild{ get; set; }
        public string MilanUDKPath { get; set; } // NEEDS TO BE SET!
        public bool RunLevelsPipeline { get; set; } = fullBuild;
        public bool RunAudioPipeline { get; set; } = false;
        public bool RunUpscalePipeline { get; set; } = true;
        public bool RunTexturePipeline { get; set; } = fullBuild;
        public bool RunShaderPipeline { get; set; } = false;
        public int MaxThreads { get; set; } = 4;
        public bool DontDeleteModFolder { get; set; } = !fullBuild;
        public bool RunNonStartupPipeline { get; set; } = fullBuild;
        public bool RunResynthesis { get; set; } = fullBuild;
        public bool UseCheckpointSystem { get; set; } = false;
        public string CheckpointFolder { get; set; } = @"H:\MELE_Mods\mods in development\LE3\Project Milan\Checkpoint";    
        public EModInstallPreference ModInstallPreference { get; set; } = EModInstallPreference.NoInstall;

    }
}
