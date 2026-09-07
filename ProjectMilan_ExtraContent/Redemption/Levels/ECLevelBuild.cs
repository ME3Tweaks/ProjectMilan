using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace ProjectMilan_ExtraContent.Redemption.Levels
{
    public static class ECLevelBuild
    {
        // You can turn these on or off, but don't commit them unless it's something being added!
        
        // CROSSGEN
        /// <summary>
        /// PINNACLE STATION TROPICAL
        /// </summary>
        public static bool CrossGenVMaps { get; set; } = true;

        /// <summary>
        /// Builds redemption maps. Requires you have imported the MP Map Pack for Redemption into the Mod Manager library.
        /// </summary>
        public static bool RedemptionMaps { get; internal set; } = false;
    }
}
