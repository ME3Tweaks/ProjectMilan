
using ProjectMilanCore;

namespace ProjectMilan_ExtraContent.Settings
{
    // Settings for DropTheSquid
    internal class MilanEcSettingsDropTheSquid : IMilanECSettings
    {
        private static readonly bool fullBuild = false;
        public string OutputModPathREJ { get; set; } = $@"H:\MELE_Mods\mods in development\LE3\Project Milan R2\{MilanShared.REJECTS_DLC_NAME}";
        public string OutputModPathRED { get; set; } = $@"H:\MELE_Mods\mods in development\LE3\Project Milan R3\{MilanShared.REJECTS_DLC_NAME}";
        public bool RunRejectionPipeline { get; set; } = fullBuild;
        public bool RunRedemptionPipeline { get; set; } = fullBuild;
        public bool RunAudioPipeline { get; set; } = false;
        public bool RunTexturePipeline { get; set; } = fullBuild;
        public int MaxThreads { get; set; } = 4;
        public bool DontDeleteModFolder { get; set; } = !fullBuild;
        public bool RunResynthesis { get; set; } = fullBuild;
    }
}