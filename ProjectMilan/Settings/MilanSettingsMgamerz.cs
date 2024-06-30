// Comment this out if we are in a location that 
// is not our standard network
//#define NETWORKED

using ProjectMilan.Pipelines;

namespace ProjectMilan.Settings
{
    // Settings for Mgamerz' system build
    internal class MilanSettingsMgamerz : IMilanSettings
    {
#if NETWORKED
        public string OutputModPath { get; set; } = $@"Z:\ModLibrary\LE3\Project Milan\{MilanShared.DLC_NAME}";
        public string InputSyncPath { get; set; } = @"Z:\ModLibrary\LE3\Project Milan\MilanSync";
#else
        public string OutputModPath { get; set; } = $@"E:\LocalModLibrary\LE3\Project Milan\{MilanShared.DLC_NAME}";
        public string InputSyncPath { get; set; } = @"E:\LocalModLibrary\LE3\Project Milan\MilanSync";
#endif
        public bool RunMPCommonPipeline { get; set; } = true;
        public bool RunNonStartupPipeline { get; set; } = true;
        public bool RunMP4EnemiesPipeline { get; set; } = true;
        public bool RunKitsPipeline { get; set; } = true;
        public bool RunWeaponsPipeline { get; set; } = true;
        public bool RunLevelsPipeline { get; set; } = true;
        public bool RunAudioPipeline { get; set; } = false;
        public bool RunTexturePipeline { get; set; } = true;
        public bool RunResynthesis { get; set; } = false;


        // Defined in my launch profiles
        public int MaxThreads { get; set; } = int.Parse(Environment.GetEnvironmentVariable("MAXTHREADS"));

        // Set when you want to work on the mod folder without it deleting it every time
        public bool DontDeleteModFolder { get; set; } = false;
    }
}
