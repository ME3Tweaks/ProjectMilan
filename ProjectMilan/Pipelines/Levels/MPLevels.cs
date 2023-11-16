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

        }

        public static void RunPipeline()
        {
            var vars = new MPLevelsVars();
            InternalRunPipeline(vars);
        }

        private static void InternalRunPipeline(MPLevelsVars levelVars)
        {

        }
    }
}
