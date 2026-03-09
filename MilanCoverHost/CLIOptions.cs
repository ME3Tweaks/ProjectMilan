using CommandLine;
using System.Runtime.InteropServices;

namespace MilanShaderHost
{
    /// <summary>
    /// Defines command line options for ProjectMilan
    /// </summary>
    internal class CLIOptions
    {

        [Option('o', "outputpath", HelpText = "Copies preview level files to the given directory for shader comparison.")]
        public string OutputPathForResults { get; set; }
    }
}
