using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using LegendaryExplorerCore.Unreal;

namespace ProjectMilanCore
{
    /// <summary>
    /// Root package export names.
    /// </summary>
    public static class MilanPackages
    {
        /// <summary>
        /// Gameplay content and classes
        /// </summary>
        public static string SFXGameContentMilan => @"SFXGameContent_Milan";

        /// <summary>
        /// Enemy archetypes
        /// </summary>
        public static string EnemyArchetypes => @"Char_Enemies_Milan";

        /// <summary>
        /// Contains appearance archetypes, which are the base archetype of spawnable archetype.
        /// </summary>
        public static string BIOG_Milan_Appearances => "BIOG_Milan_Appr_L";

        /// <summary>
        /// Contains RampartMP BioG.
        /// </summary>
        public static string BIOG_RampartMP => "BIOG_MCH_LOK_R_Milan";
    }
}
