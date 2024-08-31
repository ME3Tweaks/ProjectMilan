using ProjectMilan.Pipelines;
using ProjectMilanCore;

namespace ProjectMilan.Settings
{
    // Settings for Mgamerz' system build
    internal class MilanSettingsMgamerz : IMilanSettings
    {
        private string _outputModPath;

        public string OutputModPath
        {
            get
            {
                if (_outputModPath != null)
                    return _outputModPath;
                var networkedPath = $@"Z:\ModLibrary\LE3\Project Milan\{MilanShared.DLC_NAME}";
                if (Directory.Exists(networkedPath))
                {
                    _outputModPath = networkedPath;
                    return _outputModPath;
                }

                _outputModPath = $@"E:\LocalModLibrary\LE3\Project Milan\{MilanShared.DLC_NAME}";
                return _outputModPath;
            }
            set
            {
                _outputModPath = value;
            }
        }

        private string _inputSyncPath;

        public string InputSyncPath
        {
            get
            {
                if (_inputSyncPath != null)
                    return _inputSyncPath;
                var networkedPath = @"Z:\ModLibrary\LE3\Project Milan\MilanSync";
                if (Directory.Exists(networkedPath))
                {
                    _inputSyncPath = networkedPath;
                    return _inputSyncPath;
                }

                _inputSyncPath = @"E:\LocalModLibrary\LE3\Project Milan\MilanSync";
                return _inputSyncPath;
            }
            set
            {
                _inputSyncPath = value;
            }
        }

        public bool RunMPCommonPipeline { get; set; } = true;
        public bool RunNonStartupPipeline { get; set; } = true;
        public bool RunDonorBuildPipeline { get; set; } = true;
        public bool RunMP4EnemiesPipeline { get; set; } = false;
        public bool RunKitsPipeline { get; set; } = true;
        public bool RunWeaponsPipeline { get; set; } = true;
        public bool RunRejectionPipeline { get; set; }
        public bool RunRedemptionPipeline { get; set; }
        public bool IsStaticLightingBuild { get; set; } = false;

        private string _milanUDKPath;
        public string MilanUDKPath
        {
            get
            {
                if (_milanUDKPath != null)
                    return _milanUDKPath;
                var desktopPath = @"S:\Milan\UDK";
                if (Directory.Exists(desktopPath))
                {
                    _milanUDKPath = desktopPath;
                    return _milanUDKPath;
                }


                // Laptop
                _milanUDKPath = @"E:\Milan\UDK";
                return _milanUDKPath;
            }
            set { _milanUDKPath = value; }
        }

        public bool RunLevelsPipeline { get; set; } = true;
        public bool RunAudioPipeline { get; set; } = true;
        public bool RunTexturePipeline { get; set; } = true;
        public bool RunResynthesis { get; set; } = false;


        // Defined in my launch profiles
        public int MaxThreads { get; set; } = int.Parse(Environment.GetEnvironmentVariable("MAXTHREADS"));

        // Set when you want to work on the mod folder without it deleting it every time
        public bool DontDeleteModFolder { get; set; } = false;
    }
}
