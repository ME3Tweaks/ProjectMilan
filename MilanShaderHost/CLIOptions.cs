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

        [Option("tracematerialtranslation", HelpText = "Passes -TraceMaterialTranslation to ShaderClient. This opt-in diagnostic records the live normal-texture unpack state only for the trace target family and does not alter shader compilation.")]
        public bool TraceMaterialTranslation { get; set; }

        [Option("tracematerialfilter", HelpText = "Substring matched against a material's full path to choose which family the two trace options above follow. Defaults to the Miranda scalp CombinedEffect target they were written for. Cannot contain a space.")]
        public string TraceMaterialFilter { get; set; }

        [Option("no-instances", HelpText = "Excludes MaterialInstanceConstants from the compile level, restoring the Material-only behaviour. Their static permutations are then never compiled, so any instance that overrides a static switch, component mask or normal parameter renders its parent's defaults. Present so an instance-related regression can be bisected without a rebuild.")]
        public bool NoInstances { get; set; }

        [Option("packagelist", HelpText = "Reads the packages to process from this file (one name per line, # for comments) instead of the hardcoded list in ShaderCompileList.")]
        public string PackageListFile { get; set; }

        [Option("sourcefolder", Separator = ';', HelpText = "Decooked source roots to resolve packages and donor imports from, separated by ';'. The first folder holding a given package wins. Replaces the hardcoded default when supplied — pass the decooked folder of the game being compiled first, or an LE1 package can shadow the LE3 one of the same name.")]
        public IEnumerable<string> SourceFolders { get; set; }

        [Option("capture-root", HelpText = "Root folder for DebugPackages and HLSL capture output. Defaults to E:\\Decooked. When using a temporary --sourcefolder clone, set this to a separate root so the main corpus is never overwritten.")]
        public string CaptureRoot { get; set; }

        [Option("compiled-output", HelpText = "Folder for compiled shader packages. Defaults to E:\\CompiledShaderPackages.")]
        public string CompiledOutputFolder { get; set; }

        [Option("material", HelpText = "Compile only the material with this exact instanced full path from each input package. Intended for focused capture diagnostics; omit for normal package-wide runs.")]
        public string MaterialPath { get; set; }

        [Option("terrain", HelpText = "Compiles Terrain resources from this LE3 map package. This implies --compile and does not require the package to be in a decooked source folder.")]
        public string TerrainPackagePath { get; set; }

        [Option("noautorename", HelpText = "Disables the automatic capture rename. By default a package the game loads at boot (engine.startuppackages) has its package object compiled under a MILAN-suffixed name, because otherwise the game's own copy wins the load and nothing compiles at all. Use this only to reproduce the collision.")]
        public bool NoAutoRename { get; set; }

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
