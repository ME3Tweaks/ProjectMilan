
using ProjectMilanCore;

namespace ProjectMilan_ExtraContent.Settings
{
    // Settings for d00t's system build
    internal class MilanECSettingsd00t : IMilanECSettings
    {
        public string OutputModPathREJ { get; set; } = @$"E:\Milan\_Library\LMP\Milan\{MilanShared.REJECTS_DLC_NAME}";
        public string OutputModPathRED { get; set; } = @$"E:\Milan\_Library\LMP\Milan\{MilanShared.REDEMPTION_DLC_NAME}";
        public bool RunRejectionPipeline { get; set; } = false;
        public bool RunRedemptionPipeline { get; set; } = false;

        public bool RunAudioPipeline { get; set; } = true;
        public bool RunTexturePipeline { get; set; } = true;
        public bool RunResynthesis { get; set; } = true;

        public int MaxThreads { get; set; } = 16;
        public bool DontDeleteModFolder { get; set; } = false;
    }
}