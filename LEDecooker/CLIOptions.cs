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

        [Option('o', "outputfolder", HelpText = "Specifies where output files should be placed.", Required = true)]
        public string CompiledT3DOutputFolder { get; set; } = string.Empty;

        [Option('t', "t3dinputfolder", HelpText = "Folder that contains game-specific T3D folders.", Required = false)]
        public string T3DInputfolder { get; set; } = string.Empty;

        [Option('g', "game", HelpText = "Game to run the operation on.", Required = true)]
        public MEGame Game { get; set; }

    }
}
