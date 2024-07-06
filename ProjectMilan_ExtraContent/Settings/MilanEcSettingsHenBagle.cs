using ProjectMilanCore;

namespace ProjectMilan_ExtraContent.Settings
{
    // Settings for HenBagle's system build
    internal class MilanECSettingsHenBagle : IMilanECSettings
    {
        public string OutputModPathREJ { get; set; } = $@"D:\Mass Effect Modding\ME3TweaksModManager\mods\LE3\Project Milan R2\{MilanShared.REJECTS_DLC_NAME}";
        public string OutputModPathRED { get; set; } = $@"D:\Mass Effect Modding\ME3TweaksModManager\mods\LE3\Project Milan R3\{MilanShared.REDEMPTION_DLC_NAME}";
        public bool RunRejectionPipeline { get; set; } = true;
        public bool RunRedemptionPipeline { get; set; } = true;
        public bool RunAudioPipeline { get; set; } = true;
        public bool RunTexturePipeline { get; set; } = false;
        public int MaxThreads { get; set; } = 2;
        public bool DontDeleteModFolder { get; set; } = false;
        public bool RunResynthesis { get; set; } = true;
    }
}