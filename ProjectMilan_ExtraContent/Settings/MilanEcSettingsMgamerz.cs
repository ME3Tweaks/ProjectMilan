using ProjectMilanCore;

namespace ProjectMilan_ExtraContent.Settings
{
    // Settings for Mgamerz' system build
    internal class MilanECSettingsMgamerz : IMilanECSettings
    {
        private string _outputModPathREJ;

        public string OutputModPathREJ
        {
            get
            {
                if (_outputModPathREJ != null)
                    return _outputModPathREJ;
                var networkedPath = $@"Z:\ModLibrary\LE3\Project Milan R2\{MilanShared.REJECTS_DLC_NAME}";
                if (Directory.Exists(networkedPath))
                {
                    _outputModPathREJ = networkedPath;
                    return _outputModPathREJ;
                }

                _outputModPathREJ = $@"E:\LocalModLibrary\LE3\Project Milan R2\{MilanShared.REJECTS_DLC_NAME}";
                return _outputModPathREJ;
            }
            set
            {
                _outputModPathREJ = value;
            }
        }

        private string _outputModPathRED;

        public string OutputModPathRED
        {
            get
            {
                if (_outputModPathRED != null)
                    return _outputModPathRED;
                var networkedPath = $@"Z:\ModLibrary\LE3\Project Milan R3\{MilanShared.REDEMPTION_DLC_NAME}";
                if (Directory.Exists(networkedPath))
                {
                    _outputModPathRED = networkedPath;
                    return _outputModPathRED;
                }

                _outputModPathRED = $@"E:\LocalModLibrary\LE3\Project Milan R3\{MilanShared.REDEMPTION_DLC_NAME}";
                return _outputModPathRED;
            }
            set
            {
                _outputModPathRED = value;
            }
        }

        public bool RunRejectionPipeline { get; set; } = true;
        public bool RunRedemptionPipeline { get; set; } = false;


        public bool RunAudioPipeline { get; set; } = false;
        public bool RunTexturePipeline { get; set; } = true;
        public bool RunResynthesis { get; set; } = false;


        // Defined in my launch profiles
        public int MaxThreads { get; set; } = int.Parse(Environment.GetEnvironmentVariable("MAXTHREADS"));

        // Set when you want to work on the mod folder without it deleting it every time
        public bool DontDeleteModFolder { get; set; } = false;
    }
}
