using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using Newtonsoft.Json;

namespace ProjectMilan.Settings
{
    // This is an interface and not a base class because it forces everyone to have all variables defined in their 
    // settings class. If it was a base class, you could easily not see some variables.
    // As items are added please add them to all implementers with a default of false.

    /// <summary>
    /// Describes settings for running Project Milan
    /// </summary>
    public interface IMilanSettings
    {
        /// <summary>
        /// The base output folder for Project Milan. It should point to the DLC_MOD_Milan folder, in game, or in mod manager
        /// </summary>
        public string OutputModPath { get; set; }

        /// <summary>
        /// Directory where the source data is located that is synchronized from ME3Tweaks.com. The contents of this folder will be updated when ProjectMilan runs.
        /// </summary>
        public string InputSyncPath { get; set; }

        // Pipelines
        /// <summary>
        /// If persistent classes should be built
        /// </summary>
        public bool RunMPLobbyClassesPipeline { get; set; }

        /// <summary>
        /// If configuration files should be built
        /// </summary>
        bool RunConfigPipeline { get; set; }

        /// <summary>
        /// If multiplayer archetype kits should be built
        /// </summary>
        bool RunKitsPipeline { get; set; }

        /// <summary>
        /// If multiplayer maps should be built
        /// </summary>
        bool RunLevelsPipeline { get; set; }

        /// <summary>
        /// If audio should be extracted and converted for use in the resulting mod
        /// </summary>
        bool RunAudioPipeline { get; set; }

        /// <summary>
        /// If TFC data should be built for the resulting mod
        /// </summary>
        bool RunTexturePipeline { get; set; }

    }
}
