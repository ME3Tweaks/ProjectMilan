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

        [Option('b', "builddebugpackages", HelpText = "Builds debug shader packages for each shader compiled.")]
        public bool BuildDebugPackages { get; set; }

        [Option("captureonly", HelpText = "Captures debug packages without compiling any shaders. Builds the offline calibration files in one pass; implies --builddebugpackages.")]
        public bool CaptureOnly { get; set; }

        [Option("packagelist", HelpText = "Reads the packages to process from this file (one name per line, # for comments) instead of the hardcoded list in ShaderCompileList.")]
        public string PackageListFile { get; set; }

        [Option("gamepath", HelpText = "Game root (the folder containing BioGame). Overrides the registry lookup, which is only compiled into WinDebug/WinRelease builds.")]
        public string GamePath { get; set; }

        [Option('s', "slashshadercache", HelpText = "Slashes the RefShaderCache down to only what's in the compiler level to improve game boot speed.")]
        public bool SlashRefShaderCache { get; set; }

        [Option('o', "outputpath", HelpText = "Copies preview level files to the given directory for shader comparison.")]
        public string OutputPathForResults { get; set; }
    }
}
