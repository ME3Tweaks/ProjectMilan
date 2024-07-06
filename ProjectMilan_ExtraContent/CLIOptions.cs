using CommandLine;

namespace ProjectMilan_ExtraContent
{
    /// <summary>
    /// Defines command line options for ProjectMilan
    /// </summary>
    internal class CLIOptions
    {
        [Option('c', "config", HelpText = "Specifies which developer configuration to use.", Required = true)]
        public string Config { get; set; } = string.Empty;
    }
}
