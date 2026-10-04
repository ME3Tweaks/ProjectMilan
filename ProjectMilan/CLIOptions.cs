using CommandLine;

namespace ProjectMilan
{
    /// <summary>
    /// Defines command line options for ProjectMilan
    /// </summary>
    internal class CLIOptions
    {
        [Option('c', "config", HelpText = "Specifies which developer configuration to use.", Required = true)]
        public string Config { get; set; } = string.Empty;

        [Option('r', "researchmode", HelpText = "Runs the research mode code path instead of the build path.", Required = false)]
        public bool ResearchMode { get; internal set; }

        [Option("keep-prebake-maps", HelpText = "Keep copies of exported UDK maps before static lighting is built, for debugging.", Required = false)]
        public bool KeepPreBakeMaps { get; set; }

        [Option("compare-lighting", Separator = ',', HelpText = "Only score the built lightmaps of these BioP maps (comma separated) against ME3's, then exit. Builds nothing.", Required = false)]
        public IEnumerable<string> CompareLighting { get; set; }

        [Option("compare-lighting-levels", HelpText = "Levels folder (one subfolder per BioP) for --compare-lighting. Defaults to the output mod's CookedPCConsole\\Levels.", Required = false)]
        public string CompareLightingLevels { get; set; }

        [Option("compare-lighting-me3", HelpText = "Unpacked ME3 folder to read ME3's levels from for --compare-lighting. Defaults to the installed game.", Required = false)]
        public string CompareLightingME3 { get; set; }
    }
}
