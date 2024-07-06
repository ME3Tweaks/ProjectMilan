using ProjectMilanCore;

namespace ProjectMilan_ExtraContent.Settings
{
    // Settings for SirCxyrtyx's system build
    internal class MilanEcSettingsSirCxyrtyx : IMilanECSettings
    {
        public string OutputModPathREJ { get; set; } = $@"C:\Users\natal\Documents\ME3TweaksModManager\mods\LE3\Project Milan R2\{MilanShared.REJECTS_DLC_NAME}";
        public string OutputModPathRED { get; set; } = $@"C:\Users\natal\Documents\ME3TweaksModManager\mods\LE3\Project Milan R3\{MilanShared.REDEMPTION_DLC_NAME}";
        public bool RunRejectionPipeline { get; set; } = true;
        public bool RunRedemptionPipeline { get; set; } = true;
        public bool RunAudioPipeline { get; set; }
        public bool RunTexturePipeline { get; set; }
        public int MaxThreads { get; set; } = 2;
        public bool DontDeleteModFolder { get; set; }
        public bool RunResynthesis { get; set; }
    }
}