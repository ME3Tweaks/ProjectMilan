using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using LegendaryExplorerCore.Coalesced;
using LegendaryExplorerCore.Coalesced.Config;
using LegendaryExplorerCore.Packages;
using ProjectMilan.Pipelines.Init;

namespace ProjectMilan.Pipelines.Config
{
    /// <summary>
    /// Pipeline for configuring MP configuration data
    /// </summary>
    internal class MPConfig
    {
        private const string LOG_CATEGORY = "MILAN-Config";

        // Some notes on multiplayer config files from ME3.
        // Config files mounted in specific order:
        //     0. ? Maybe? TestPatch mounted here it seems. Not entirely sure when this applied, but it has to be read before game even boots.
        //     1. Basegame
        //     2. When entering MPLobby -> DLC, in mount order
        //     3. When entering MPLobby -> LiveIni is applied while game is running
        // MPLobby is the map name for the MP menu system both in and out of lobbies. It's a persistent level.

        public static void RunPipeline()
        {
            InternalRunPipeline();
        }

        private static void InternalRunPipeline()
        {
            // Build config bundle of all MP data.
            // We need to handle DLC_UPD_Patch01/DLC_UPD_Patch02
            // as these are live balance change rollups. However,
            // as they are applied in mount order, we will need to pretty much nuke
            // all of their changes and overwrite with our own to make sure we 
            // don't make duplicates. That'll be done later

            // Most of basegame is done

            // Compile config file
            var manifest = Path.Combine(MilanShared.PipelineRoot, @"Config", @"DLC_MOD_ProjectMilan", @"DLC_MOD_ProjectMilan.xml");
            var dest = Path.Combine(Program.Settings.OutputModPath, @"CookedPCConsole", @"DLC_MOD_ProjectMilan.bin");
            MilanLog.Information("Compiling DLC_MOD_ProjectMilan.bin", customPrefix: LOG_CATEGORY);
            CoalescedConverter.ConvertToBin(manifest, dest);
        }
    }
}
