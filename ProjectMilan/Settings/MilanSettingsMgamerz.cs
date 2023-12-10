using ProjectMilan.Pipelines;

namespace ProjectMilan.Settings
{
    // Settings for Mgamerz' system build
    internal class MilanSettingsMgamerz : IMilanSettings
    {
        public string OutputModPath { get; set; } = $@"Z:\ModLibrary\LE3\Project Milan\{MilanShared.DLC_NAME}";
        public string InputSyncPath { get; set; } = @"Z:\ModLibrary\LE3\Project Milan\MilanSync";

        public bool RunMPCommonPipeline { get; set; } = true;
        public bool RunNonStartupPipeline { get; set; } = false;
        public bool RunKitsPipeline { get; set; } = true;
        public bool RunLevelsPipeline { get; set; } = true;
        public bool RunAudioPipeline { get; set; } = false;
        public bool RunTexturePipeline { get; set; } = true;
        public bool RunResynthesis { get; set; } = true;


        // Defined in my launch profiles
        public int MaxThreads { get; set; } = int.Parse(Environment.GetEnvironmentVariable("MAXTHREADS"));

        // Set when you want to work on the mod folder without it deleting it every time
        public bool DontDeleteModFolder { get; set; } = false;
    }
}
