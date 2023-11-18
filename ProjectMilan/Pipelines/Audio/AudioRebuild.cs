using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace ProjectMilan.Pipelines.Audio
{
    /// <summary>
    /// Pipeline for extracting audio from ME3 and porting it to LE3 WwiseBanks
    /// </summary>
    internal class AudioRebuild
    {
        // Expected pipeline:
        // 1. Go through ME3 package files and find all WwiseBanks that are not in LE (using object database?)
        // 2. Extract all WwiseBanks from them to disk.
        // 3. Extract all audio from WwiseBank and WwiseStreams to disk
        // 4. Decompile WwiseBank to gather information about what is needed to rebuild. Things like attenuation and stuff (this will probably be the worst step)
        // 5. Build new LE versions of banks using the Wwise Authoring API (WAAPI)
        // 6. Inject the new banks into the compiled mod files
        // This will probably be one of the later pipelines
        public static void RunPipeline()
        {

        }
    }
}
