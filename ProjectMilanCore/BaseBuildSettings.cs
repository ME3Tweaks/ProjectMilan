using LegendaryExplorerCore.Packages;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace ProjectMilanCore
{
    /// <summary>
    /// The base set of build settings
    /// </summary>
    public class BaseBuildSettings
    {
        public static readonly MELocalization[] SupportedVOLanguages = new[]
        {
            MELocalization.INT,
            MELocalization.FRA,
            MELocalization.DEU,
            MELocalization.ITA,
            // Any other languages that had VO?
        };

        /// <summary>
        /// Output DLC folder path. Change if you need to redirect output to a different DLC.
        /// </summary>
        public static string OutputModPath { get; set; }
    }
}
