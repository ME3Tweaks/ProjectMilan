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

        [Option('o', "outputfolder", HelpText = "Specifies where decooked game output files should be placed", Required = true)]
        public string CompiledAssetsOutputFolder { get; set; } = string.Empty;

        [Option('c', "compileassets", HelpText = "Compiles T3D (materials) and other assets to decooked packages")]
        public bool CompileAssets { get; set; }


        [Option('m', "udkoutputfolder", HelpText = "Specifies where converted UDK asset files should be placed")]
        public string ConvertedUDKAssetsOutputFolder { get; set; } = string.Empty;

        [Option('u', "convert", HelpText = "Converts decooked assets to UDK asset packages")]
        public bool ConvertAssetsToUDK { get; set; }

        [Option('g', "game", HelpText = "Game to run the operation on.", Required = true)]
        public MEGame Game { get; set; }

        [Option("genobjectdb", HelpText = "Regenerates supportfiles/<game>.bin, the ObjectInstanceDB. For ME3 this includes DLC SFAR content. Runs on ME games as well as LE ones.")]
        public bool GenerateObjectDB { get; set; }

        [Option("gensupportfiles", HelpText = "Regenerates every support database for the game (textures, object type lookups, material IFPs and the ObjectInstanceDB) in a single pass over its packages. Runs on ME games as well as LE ones.")]
        public bool GenerateSupportFiles { get; set; }

        [Option("zipsupportfiles", HelpText = "Rebuilds supportfiles/supportdbs.zip from the loose support files. LEDecooker must be recompiled afterwards, as the zip is an embedded resource.")]
        public bool ZipSupportFiles { get; set; }

    }
}
