namespace ProjectMilan.Settings
{
    // This is an interface and not a base class because it forces everyone to have all variables defined in their 
    // settings class. If it was a base class, you could easily not see some variables.
    // As items are added please add them to all implementers with a default of false.

    public enum EModInstallPreference
    {
        /// <summary>
        /// Always ask with a 5 second timeout, defaulting to No
        /// </summary>
        Prompt,
        /// <summary>
        /// Always install, do not prompt
        /// </summary>
        Install,
        /// <summary>
        /// Don't install the mod, do not prompt
        /// </summary>
        NoInstall
    }

    /// <summary>
    /// Describes settings for running Project Milan
    /// </summary>
    public interface IMilanSettings
    {
        #region Pathing
        /// <summary>
        /// The base output folder for Project Milan. It should point to a DLC_MOD_Milan folder - in game DLC dir, or in mod manager. Contents will be deleted.
        /// </summary>
        public string OutputModPath { get; set; }

        /// <summary>
        /// Directory where the source data is located that is synchronized from ME3Tweaks.com. The contents of this folder will be updated when ProjectMilan runs.
        /// </summary>
        public string InputSyncPath { get; set; }
        #endregion

        #region Content pipelines
        /// <summary>
        /// If persistent classes should be built. You almost always want this on.
        /// </summary>
        bool RunMPCommonPipeline { get; set; }

        /// <summary>
        /// If the NonStartup pipeline should run - things like horde VO, objectives, etc. You typically will need this for MP to work.
        /// </summary>
        bool RunNonStartupPipeline { get; set; }

        /// <summary>
        /// If material donors should be built, to fix things like level, kits, and particle effects
        /// </summary>
        bool RunDonorBuildPipeline { get; set; }

        /// <summary>
        /// If Retaliation enemies should be ported that require custom changes
        /// </summary>
        bool RunMP4EnemiesPipeline { get; set; }

        /// <summary>
        /// If multiplayer archetype kits should be built
        /// </summary>
        bool RunKitsPipeline { get; set; }

        /// <summary>
        /// If multiplayer maps should be built
        /// </summary>
        bool RunLevelsPipeline { get; set; }

        /// <summary>
        /// If MP DLC weapons should be built (they have different code than SP)
        /// </summary>
        bool RunWeaponsPipeline { get; set; }

        /// <summary>
        /// If Rejection enemies content should be built
        /// </summary>
        bool RunRejectionPipeline { get; set; }

        /// <summary>
        /// If Redemption map content should be built
        /// </summary>
        bool RunRedemptionPipeline { get; set; }

        /// <summary>
        /// If the Conformance pipeline should be run. This doesn't matter that much in local play; but is mandatory for network play
        /// </summary>
        bool RunConformancePipeline { get; }


        /// <summary>
        /// If this build is for producing static lighting in UDK, not for normal gameplay - don't import lightmaps, etc.
        /// </summary>
        bool IsStaticLightingBuild { get; set; }

        /// <summary>
        /// Location of a custom installation of UDK that is used only for Project Milan, to avoid pollution with other things such as materials. Milan will manage the packages in this target, and content WILL be deleted automatically from it.
        /// </summary>
        string MilanUDKPath { get; set; }

        #endregion

        #region Content cleanup and optimization
        /// <summary>
        /// If audio should be extracted and converted for use in the resulting mod
        /// </summary>
        bool RunAudioPipeline { get; set; }

        /// <summary>
        /// If TFC data should be built for the resulting mod
        /// </summary>
        bool RunTexturePipeline { get; set; }
        /// <summary>
        /// If packages should be reconstructed at the end of pipelines to be more vanilla-organized.
        /// </summary>
        bool RunResynthesis { get; set; }

        /// <summary>
        /// If compiled shaders should be installed
        /// </summary>
        bool RunShaderPipeline { get; set; }
        #endregion

        #region Performance tuning
        /// <summary>
        /// Maximum number of threads to run. Tune to your system.
        /// </summary>
        int MaxThreads { get; set; }

        /// <summary>
        /// If the mod folder should not be deleted
        /// </summary>
        bool DontDeleteModFolder { get; set; }


        /// <summary>
        /// Makes a copy of the compiled game files after the NonStartup pipeline has finished; when building, if you restore a checkpoint, it will copy them and skip the first few pipelines.
        /// </summary>
        bool UseCheckpointSystem { get; set; }

        /// <summary>
        /// The folder to copy the checkpoint to.
        /// </summary>
        string CheckpointFolder { get; set; }

        EModInstallPreference ModInstallPreference { get; set; }

        #endregion
    }
}
