using ProjectMilan.Pipelines;

namespace ProjectMilan.Settings
{
    // Settings for Mgamerz' system build
    internal class MilanSettingsMgamerz : IMilanSettings
    {
        public string OutputModPath { get; set; } = $@"Z:\ModLibrary\LE3\Project Milan\{MilanShared.DLC_NAME}";
        public string InputSyncPath { get; set; } = @"Z:\ModLibrary\LE3\Project Milan\MilanSync";

        public bool RunMPCommonPipeline { get; set; } = false;
        public bool RunKitsPipeline { get; set; } = false;
        public bool RunLevelsPipeline { get; set; } = true;
        public bool RunAudioPipeline { get; set; } = false;
        public bool RunTexturePipeline { get; set; } = false;
        // Defined in my launch profiles
        public int MaxThreads { get; set; } = int.Parse(Environment.GetEnvironmentVariable("MAXTHREADS"));
    }
}
