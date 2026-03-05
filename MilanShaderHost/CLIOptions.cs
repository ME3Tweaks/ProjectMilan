using CommandLine;
using System.Runtime.InteropServices;

namespace MilanShaderHost
{
    /// <summary>
    /// Defines command line options for ProjectMilan
    /// </summary>
    internal class CLIOptions
    {
        [Option('c', "compile", HelpText = "Compiles shaders via the shadercompile level method.")]
        public bool CompileShaders { get; set; }

        [Option('p', "preview", HelpText = "Previews shaders via the shaderpreview level method.")]
        public bool PreviewShaders { get; set; }

        [Option('d', "dumphlsl", HelpText = "Dumps HLSL for shaders. Requires special setup in the ShaderClient ASI.")]
        public bool DumpHLSL { get; set; }

        [Option('s', "slashshadercache", HelpText = "Slashes the RefShaderCache down to only what's in the compiler level to improve game boot speed.")]
        public bool SlashRefShaderCache { get; set; }

        [Option('o', "outputpath", HelpText = "Copies preview level files to the given directory for shader comparison.")]
        public string OutputPathForResults { get; set; }
    }
}
