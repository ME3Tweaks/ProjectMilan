using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace LEDecooker
{
    public static class DecookerPaths
    {
        /// <summary>
        /// Gets output path for assets being decooked.
        /// </summary>
        /// <returns></returns>
        public static string GetAssetOutputPath()
        {
            var outPath = Path.Combine(CLIOptions.ParsedOptions.CompiledAssetsOutputFolder, CLIOptions.ParsedOptions.Game.ToString());
            return Directory.CreateDirectory(outPath).FullName;
        }

        internal static string GetUDKOutputPath()
        {
            var outPath = Path.Combine(CLIOptions.ParsedOptions.ConvertedUDKAssetsOutputFolder, "Decooked", CLIOptions.ParsedOptions.Game.ToString());
            return Directory.CreateDirectory(outPath).FullName;
        }
    }
}
