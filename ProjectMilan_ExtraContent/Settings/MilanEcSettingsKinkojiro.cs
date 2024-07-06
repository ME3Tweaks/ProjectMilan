using ProjectMilanCore;

namespace ProjectMilan_ExtraContent.Settings
{
    // Settings for Kinkojiro's system build
    internal class MilanECSettingsKinkojiro : IMilanECSettings
    {
        public string OutputModPathREJ { get; set; } = $@"E:\Modding\LE3\Project Milan R2\{MilanShared.REJECTS_DLC_NAME}";
        public string OutputModPathRED { get; set; } = $@"E:\Modding\LE3\Project Milan R3\{MilanShared.REDEMPTION_DLC_NAME}";
        public bool RunRejectionPipeline { get; set; } = true;
        public bool RunRedemptionPipeline { get; set; } = true;
        public bool RunAudioPipeline { get; set; }
        public bool RunTexturePipeline { get; set; }
        public bool RunResynthesis { get; set; }
        public int MaxThreads { get; set; } = 1;
        public bool DontDeleteModFolder { get; set; }
    }
}