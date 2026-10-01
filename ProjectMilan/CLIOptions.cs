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
    }
}
