using CliWrap;
using LegendaryExplorerCore;
using LegendaryExplorerCore.GameFilesystem;
using LegendaryExplorerCore.Unreal.BinaryConverters;
using System.Diagnostics;

namespace MilanShaderHost
{
    /// <summary>
    /// Main entry point for MilanShaderHost
    /// </summary>
    internal class Program
    {
        // This application will handle interop between dumping HLSL from the games
        // and feeding it to the shader compiler to produce permutations of shaders.

        public async static Task Main(string[] args)
        {
            Console.WriteLine("Welcome to Milan Shader Host");
            Console.WriteLine("By ME3Tweaks");
            Console.WriteLine();

            // Initialize
            LegendaryExplorerCoreLib.InitLib(null, x => { });



            // Build the map package that contains the shaders we want to compile
            // MilanShaderPackageBuilder.SourceFolders.Add(@"S:\Milan\UDK\MilanMaterialDecook_Merged_T3D");
            // MilanShaderPackageBuilder.BuildMapPackage(@"S:\Milan\UDK\MilanMaterialDecook_Merged_T3D\BioT_GthMP.pcc");

            // Start the pipe server.
            ShaderHost sh = new ShaderHost();
            sh.StartListening();

            //HLSLServer server = new HLSLServer();
            //server.StartListening();

            return;
            

            var inputHlsl = File.ReadAllText(Path.Combine(LE3Directory.DefaultGamePath, "Engine", "ShaderComp", "PickUpSwipe_MM.hlsl"));

            // Compile using UE3ShaderCompileWorker
            // var wasOK = await CompileShaderThroughUSCW(inputHlsl);

            // Compile using MilanShaderCompileLib
            ShaderCache sc = new ShaderCache();
            ShaderCompiler.CompileShadersFor(inputHlsl, sc);
        }

        /// <summary>
        /// Compiles hlsl for shader via MilanShaderCompilerLib
        /// </summary>
        /// <param name="hlsl">HLSL from game that we are going to compile</param>
        /// <returns></returns>
        public async static Task<bool> CompileShader2(string hlsl)
        {
            // Probably should get other info such as name of material.


            return true;
        }

        public async static Task<bool> CompileShaderThroughUSCW(string hlsl)
        {
            var processPath = Path.Combine(LE3Directory.DefaultGamePath, "Binaries\\ShaderCompiler_UE\\UE3ShaderCompileWorker.exe");

            // Determine the compiler we're going to use, as it changes how we do things.
            var fileName = Path.GetFileName(processPath);
            ECompiler compiler = ECompiler.UNKNOWN;
            if (fileName.StartsWith("UE3ShaderCompileWorker"))
            {
                compiler = ECompiler.UDK;
            }
            else if (fileName.StartsWith("LEShaderCompileWorker"))
            {
                // Not sure this works right now...
                compiler = ECompiler.BIOWARE;
            }


            // Where files go
            var rootWorkingDirectory = Path.Combine(LE3Directory.DefaultGamePath, "Engine", "ShaderComp");
            var workingDirectory = Path.Combine(rootWorkingDirectory, "Scratch");
            Directory.CreateDirectory(workingDirectory);

            // Process id of calling proc?
            var parentId = Process.GetCurrentProcess().Id.ToString();

            // Unique identifier to the parent id
            var threadId = "NameOfApp"; // I don't think this matters. It is probably used by the editor to track what thread is running.

            // Input file - must be in special binary format.
            // If it contains 'InputOnly' in the filename it will cause the process to exit on completion.
            var inFileName = "WorkerInputOnly.in";

            // The file name that UE3ShaderCompileWorker will output
            var outFileName = "WorkerOutput.out";

            var inputFilePath = Path.Combine(workingDirectory, inFileName);



            // This is for debugging only - this puts down the rest of the packet
            //File.Copy(@"S:\Milan\UDK\MilanShaderComp\WorkerInputOnly.in", Path.Combine(workingDirectory, inFileName), true);

            // Copy template to directory for UE3ShaderCompileWorker
            File.Copy(Path.Combine(rootWorkingDirectory, inFileName), Path.Combine(workingDirectory, $"WorkerInputOnly.in"), true);

            var sci = new ShaderCompilerJobList()
            {
                SimulatedExeLocation = processPath
            };

            sci.WorkingDirectory = workingDirectory;
            sci.InputFilename = inFileName;
            sci.OutputFilename = outFileName;
            
            // Read macros.
            sci.ReadInput();

            // Remove existing includes.
            sci.Jobs[0].ShaderInput.Includes.Clear();

            // Will have to figure this stuff out... 
            sci.Jobs[0].ShaderInput.ShaderProfile = "ps_5_0";
            sci.SetBaseShader("DirectionalLightPixelShader"); // Base shader being compiled.
            sci.SetVertexFactory("LocalVertexFactory"); // Vertex factory, if base shader includes VertexFactory.usf.
            sci.SetMaterial(hlsl);

            //sci.Jobs[0].ShaderInput.SourceText = hlsl;
            sci.Serialize();

            // It needs a \ on the end
            var ue3WorkingDirectory = workingDirectory +@"\";
            var outs = string.Join(' ', processPath, ue3WorkingDirectory, parentId, threadId, inFileName, outFileName);
            Debug.WriteLine(outs);

            string[] args = null;
            if (compiler == ECompiler.BIOWARE)
            {
                // args[0] = process
                // args[1] = working directory
                // args[2] = parent process id
                // args[3] = title of console window
                // Decomp doesn't seem to show access on any other args.
                args = [ue3WorkingDirectory, parentId, threadId];
            }
            else 
            if (compiler == ECompiler.UDK)
            {
                // Tested and working.
                // GuardedMain has an assertion at the start for 6 args, 5 + exe
                args = [ue3WorkingDirectory, parentId, threadId, inFileName, outFileName];
            }
            else
            {
                throw new Exception("Unknown compiler.");
            }

            var result = await Cli.Wrap(processPath)
                     .WithArguments(args)
                     .WithWorkingDirectory(Directory.GetParent(processPath).FullName)
                     .WithStandardOutputPipe(PipeTarget.ToDelegate(Console.WriteLine))
                     .WithStandardErrorPipe(PipeTarget.ToDelegate(Console.Error.WriteLine))
                     .WithValidation(CommandResultValidation.None)
                     .ExecuteAsync();

            Console.WriteLine($"Process exited with code {0}", result.ExitCode);

            sci.ReadOutput();
            sci.PrintResults();
            return result.ExitCode == 0;
        }
    }
}