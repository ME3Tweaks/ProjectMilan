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
        /// The base output folder for Project Milan.
        /// </summary>
        public string OutputPath { get; set; }

        // Pipelines
        /// <summary>
        /// If SFXGameMPContent should be ported across
        /// </summary>
        public bool RunSFXGameMPContentPipeline { get; set; }
    }
}
