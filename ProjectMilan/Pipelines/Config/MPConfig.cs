using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace ProjectMilan.Pipelines.Config
{
    /// <summary>
    /// Pipeline for configuring MP configuration data
    /// </summary>
    internal class MPConfig
    {
        // Some notes on multiplayer config files from ME3.
        // Config files mounted in specific order:
        //     0. ? Maybe? TestPatch mounted here it seems. Not entirely sure when this applied, but it has to be read before game even boots.
        //     1. Basegame
        //     2. When entering MPLobby -> DLC, in mount order
        //     3. When entering MPLobby -> LiveIni is applied while game is running
        // MPLobby is the map name for the MP menu system both in and out of lobbies. It seems to be a 


        public static void RunPipeline()
        {
            
        }
    }
}
