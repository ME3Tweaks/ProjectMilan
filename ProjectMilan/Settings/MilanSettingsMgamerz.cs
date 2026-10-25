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
                var networkedPath = $@"Z:\ModLibrary\LMP\Project Milan\{MilanShared.DLC_NAME}";
                if (Directory.Exists(networkedPath))
                {
                    _outputModPath = networkedPath;
                    return _outputModPath;
                }

                _outputModPath = $@"E:\LocalModLibrary\LMP\Project Milan\{MilanShared.DLC_NAME}";
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
                var networkedPath = @"Z:\ModLibrary\LMP\Project Milan\MilanSync";
                if (Directory.Exists(networkedPath))
                {
                    _inputSyncPath = networkedPath;
                    return _inputSyncPath;
                }

                _inputSyncPath = @"E:\LocalModLibrary\LMP\Project Milan\MilanSync";
                return _inputSyncPath;
            }
            set
            {
                _inputSyncPath = value;
            }
        }

        public string TextureSyncFolder { get; set; } = @"G:\My Drive\Mass Effect Legendary Modding\LE3\ProjectMilan\Texture\Extracted";

        public bool RunMPCommonPipeline { get; set; } = true;
        public bool RunNonStartupPipeline { get; set; } = true;
        public bool RunDonorBuildPipeline { get; set; } = true;
        public bool RunMP4EnemiesPipeline { get; set; } = true;
        public bool RunKitsPipeline { get; set; } = true;
        public bool RunWeaponsPipeline { get; set; } = true;
        public bool RunConformancePipeline { get; set; } = true;
        public bool RunSlashPipeline { get; set; } = true;
        public bool RunRejectionPipeline { get; set; }
        public bool RunRedemptionPipeline { get; set; }
        public bool RunAssetFixPipeline { get; set; } = true;
        public bool IsStaticLightingBuild { get; set; } = false;
        public bool ProductionBuild { get; set; } = false;

        public string UE4LightmassPath { get; set; } // Null: look up the Epic launcher's UE_4.27 install

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

        public string CustomFFDecPath { get; set; } // Should be picked up automatically
        public bool RunLevelsPipeline { get; set; } = true;
        public bool RunAudioPipeline { get; set; } = true;
        public bool RunUpscalePipeline { get; set; } = true;
        public bool RunTexturePipeline { get; set; } = true;
        public bool RunResynthesis { get; set; } = true;
        public bool RunShaderPipeline { get; set; } = true;
        public string DecookedLE3Path => @"E:\Decooked\LE3";


        // Defined in my launch profiles
        public int MaxThreads { get; set; } = int.Parse(Environment.GetEnvironmentVariable("MAXTHREADS"));

        // Set when you want to work on the mod folder without it deleting it every time
        public bool DontDeleteModFolder { get; set; } = false;
        public bool UseCheckpointSystem { get; set; } = true;

        private string _checkPointFolder = null;

        public string CheckpointFolder
        {
            get
            {
                if (_checkPointFolder != null)
                    return _checkPointFolder;
                var desktopPath = @"S:\Milan\Checkpoint";
                if (Directory.Exists(desktopPath))
                {
                    _checkPointFolder = desktopPath;
                    return _checkPointFolder;
                }


                // Laptop
                _checkPointFolder = @"E:\Milan\Checkpoint";
                return _checkPointFolder;
            }
            set { _checkPointFolder = value; }
        }

        public EModInstallPreference ModInstallPreference { get; set; } = EModInstallPreference.NoInstall;
    }
}
