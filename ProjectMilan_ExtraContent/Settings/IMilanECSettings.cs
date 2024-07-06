namespace ProjectMilan_ExtraContent.Settings
{
    // This is an interface and not a base class because it forces everyone to have all variables defined in their 
    // settings class. If it was a base class, you could easily not see some variables.
    // As items are added please add them to all implementers with a default of false.

    /// <summary>
    /// Describes settings for running Project Milan
    /// </summary>
    public interface IMilanECSettings
    {
        /// <summary>
        /// The base output folder for Rejects. Should be a standalone mod.
        /// </summary>
        public string OutputModPathREJ { get; set; }
        /// <summary>
        /// The base output folder for Redemption. Should be a standalone mod.
        /// </summary>
        public string OutputModPathRED { get; set; }

        #region CONTENT PIPELINES
        /// <summary>
        /// If the Rejects faction extra content pipeline should be run
        /// </summary>
        bool RunRejectionPipeline { get; set; }

        /// <summary>
        /// If the Redemption map pack extra content pipeline should be run
        /// </summary>
        bool RunRedemptionPipeline { get; set; }
        #endregion

        #region Content optimization and fixing
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
        #endregion

        #region PERFORMANCE TUNING
        /// <summary>
        /// Maximum number of threads to run. Tune to your system.
        /// </summary>
        int MaxThreads { get; set; }

        /// <summary>
        /// If the mod folder should not be deleted
        /// </summary>
        bool DontDeleteModFolder { get; set; }
        #endregion
    }
}
