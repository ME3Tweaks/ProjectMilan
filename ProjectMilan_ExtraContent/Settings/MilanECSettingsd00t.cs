
using ProjectMilanCore;

namespace ProjectMilan_ExtraContent.Settings
{
    // Settings for d00t's system build
    internal class MilanECSettingsd00t : IMilanECSettings
    {
        public string OutputModPathREJ { get; set; } = @$"D:\ME3TM2Library\LE3\Milan\{MilanShared.REJECTS_DLC_NAME}";
        public string OutputModPathRED { get; set; } = @$"D:\ME3TM2Library\LE3\Milan\{MilanShared.REDEMPTION_DLC_NAME}";
        public bool RunRejectionPipeline { get; set; } = true;
        public bool RunRedemptionPipeline { get; set; } = true;

        public bool RunAudioPipeline { get; set; } = false;
        public bool RunTexturePipeline { get; set; } = true;
        public bool RunResynthesis { get; set; } = false;

        public int MaxThreads { get; set; } = 16;
        public bool DontDeleteModFolder { get; set; } = false;
    }
}