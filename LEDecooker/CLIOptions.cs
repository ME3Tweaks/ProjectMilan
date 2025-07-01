using CommandLine;
using LegendaryExplorerCore.Packages;

namespace LEDecooker
{
    /// <summary>
    /// Defines command line options for LEDecooker
    /// </summary>
    internal class CLIOptions
    {
        public static CLIOptions ParsedOptions { get; set; }

        [Option('o', "outputfolder", HelpText = "Specifies where output files should be placed", Required = true)]
        public string CompiledAssetsOutputFolder { get; set; } = string.Empty;

        [Option('c', "compileassets", HelpText = "Compiles T3D (materials) and other assets to decooked packages")]
        public bool CompileAssets { get; set; }

        [Option('u', "convert", HelpText = "Converts decooked assets to UDK asset packages")]
        public bool ConvertAssetsToUDK { get; set; }

        [Option('g', "game", HelpText = "Game to run the operation on.", Required = true)]
        public MEGame Game { get; set; }

    }
}
