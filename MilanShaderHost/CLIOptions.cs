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

        [Option("tracervrmaterialresolution", HelpText = "Passes -TraceRvrMaterialResolution to ShaderClient. This opt-in diagnostic records Rvr routing only for the Miranda CombinedEffect trace target and does not alter shader compilation.")]
        public bool TraceRvrMaterialResolution { get; set; }

        [Option("tracematerialtranslation", HelpText = "Passes -TraceMaterialTranslation to ShaderClient. This opt-in diagnostic records the live normal-texture unpack state only for the Miranda scalp CombinedEffect trace target and does not alter shader compilation.")]
        public bool TraceMaterialTranslation { get; set; }

        [Option("packagelist", HelpText = "Reads the packages to process from this file (one name per line, # for comments) instead of the hardcoded list in ShaderCompileList.")]
        public string PackageListFile { get; set; }

        [Option("sourcefolder", Separator = ';', HelpText = "Decooked source roots to resolve packages and donor imports from, separated by ';'. The first folder holding a given package wins. Replaces the hardcoded default when supplied — pass the decooked folder of the game being compiled first, or an LE1 package can shadow the LE3 one of the same name.")]
        public IEnumerable<string> SourceFolders { get; set; }

        [Option("capture-root", HelpText = "Root folder for DebugPackages and HLSL capture output. Defaults to E:\\Decooked. When using a temporary --sourcefolder clone, set this to a separate root so the main corpus is never overwritten.")]
        public string CaptureRoot { get; set; }

        [Option("material", HelpText = "Compile only the material with this exact instanced full path from each input package. Intended for focused capture diagnostics; omit for normal package-wide runs.")]
        public string MaterialPath { get; set; }

        [Option("terrain", HelpText = "Compiles Terrain resources from this LE3 map package. This implies --compile and does not require the package to be in a decooked source folder.")]
        public string TerrainPackagePath { get; set; }

        [Option("writeback", HelpText = "After a successful LE3 compile, writes compiled material resources, terrain material resources, and the merged shader cache back to each input package. This overwrites the input package; without this option results are written to E:\\CompiledShaderPackages.")]
        public bool WriteBack { get; set; }

        [Option("gamepath", HelpText = "Game root (the folder containing BioGame). Overrides the registry lookup, which is only compiled into WinDebug/WinRelease builds.")]
        public string GamePath { get; set; }

        [Option('s', "slashshadercache", HelpText = "Slashes the RefShaderCache down to only what's in the compiler level to improve game boot speed.")]
        public bool SlashRefShaderCache { get; set; }

        [Option('o', "outputpath", HelpText = "Copies preview level files to the given directory for shader comparison.")]
        public string OutputPathForResults { get; set; }
    }
}
