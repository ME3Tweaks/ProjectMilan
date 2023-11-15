using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using Newtonsoft.Json;

namespace ProjectMilan
{
    /// <summary>
    /// Describes settings for running Project Milan
    /// </summary>
    internal class MilanSettings
    {

        /// <summary>
        /// The base output folder for Project Milan.
        /// </summary>
        [JsonProperty("outputpath")]
        public string OutputPath { get; set; }

        /// <summary>
        /// If SFXGameMPContent should be ported across
        /// </summary>
        [JsonProperty("sfxgamempcontentpipeline")]
        public bool RunSFXGameMPContentPipeline { get; set; }
    }
}
