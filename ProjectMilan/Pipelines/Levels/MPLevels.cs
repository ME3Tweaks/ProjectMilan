using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace ProjectMilan.Pipelines.Levels
{
    /// <summary>
    /// Pipeline for porting levels across from OT to LE (must be made for multiplayer mode!)
    /// </summary>
    internal class MPLevels
    {
        class MPLevelsVars
        {
            /// <summary>
            /// Map of DLC map names and if they should be ported across
            /// </summary>
            public Dictionary<string, bool> PortingMap = new Dictionary<string, bool>()
            {
                // MP1 Resurgence
                {"BioP_MPMoon", false}, // Condor
                {"BioP_MPGeth", true}, // Hydra

                // MP2 Rebellion
                {"BioP_MPJngl", false}, // Jade
                {"BioP_MPThes", false}, // Goddess

                // MP3 Earth
                {"BioP_MPOcean", false}, // Rio
                {"BioP_MPHosp", false}, // Vancouver
                {"BioP_MPRoad", false}, // London

                // MP4 Retalition
                {"BioP_MPCer2", false}, // Glacier - Hazard
                {"BioP_MPCer3", false}, // Glacier - Rework (replaces MPCer in ME3)
                {"BioP_MPDish2", false}, // Dagger - Hazard
                {"BioP_MPNov2", false}, // White - Hazard
                {"BioP_MPNov3", false}, // White - Rework (replaces MPNov in ME3)
                {"BioP_MPRctr2", false}, // Reactor - Hazard
                {"BioP_MPSlum2", false}, // Ghost - Hazard
                {"BioP_MPTowr2", false}, // Giant - Hazard
                {"BioP_MPTowr3", false}, // Giant - Rework (replaces MPTowr in ME3) - this is a spawn bugfix. MPTowr will be broken in vanilla, we should only use this version.

                // MP5 Reckoning
                // No maps

                // Prototype and unused maps
                // These are named that were assigned to the maps for ModMaker
                {"BioP_MPThes2", false}, // Athena (prototype)
                {"BioP_MPBrdg", false}, // Gauntlet (prototype)
                {"BioP_MPFoun", false}, // Dragon (prototype)
                {"BioP_MPPump", false}, // Forge (prototype)
                {"BioP_MPRays", false}, // Maelstrom (prototype)
                {"BioP_MPSub", false}, // Neptune (prototype)
                {"BioP_MPTest", false}, // Scorpion (prototype)

            };
        }

        public static void RunPipeline()
        {
            var vars = new MPLevelsVars();
            InternalRunPipeline(vars);
        }

        private static void InternalRunPipeline(MPLevelsVars levelVars)
        {
            foreach (var level in levelVars.PortingMap)
            {
                if (!level.Value)
                    // This level is not marked for porting currently.
                    continue;
            }
        }
    }
}
