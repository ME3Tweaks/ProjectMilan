using CliWrap;
using LegendaryExplorerCore;
using System.Diagnostics;

namespace MilanShaderHost
{
    /// <summary>
    /// Main entry point for MilanShaderHost
    /// </summary>
    internal class Program
    {
        // This application will handle interop between dumping HLSL from the games
        // and feeding it to the shader compiler.

        public async static Task Main(string[] args)
        {
            Console.WriteLine("Welcome to Milan Shader Host");
            Console.WriteLine("By ME3Tweaks");
            Console.WriteLine();

            // Initialize
            LegendaryExplorerCoreLib.InitLib(null, x => { });
            MilanShaderPackageBuilder.SourceFolders.Add(@"Z:\ModLibrary\LE3\Project Milan\Extras\Packages\LE3");
            MilanShaderPackageBuilder.SourceFolders.Add(@"S:\Milan\UDK\MilanMaterialDecook_T3D");

            // Build the map package that contains the shaders we want to compile
            //MilanShaderPackageBuilder.BuildMapPackage(@"Z:\ModLibrary\LE3\Project Milan\Extras\Packages\LE3\BioT_GthMP.pcc");
            //return;

            // Start the pipe server.
            HLSLServer server = new HLSLServer();
            server.StartListening();

            return;
            
            var inputHlsl = File.ReadAllText(@"S:\Milan\UDK\MilanShaderComp\PickUpSwipe_MM.hlsl");
            var wasOK = await CompileShader(inputHlsl);
        }

        public async static Task<bool> CompileShader(string hlsl)
        {
            var processPath = "S:\\SteamLibrary\\steamapps\\common\\Mass Effect Legendary Edition\\Game\\ME3\\Binaries\\ShaderCompiler\\UE3ShaderCompileWorker.exe";

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
            var workingDirectory = "S:\\Milan\\UDK\\MilanShaderComp\\Scratch\\";

            // Process id of calling proc?
            var parentId = Process.GetCurrentProcess().Id.ToString();

            // Unique identifier to the parent id
            var threadId = "NameOfApp"; // I don't think this matters. It is probably used by the editor to track what thread is running.

            // Input file - must be in special binary format.
            // If it contains 'InputOnly' in the filename it will cause the process to exit on completion.
            var inFileName = "WorkerInput.bin";

            // The file name that UE3ShaderCompileWorker will output
            var outFileName = "WorkerOutput.out";

            var inputFilePath = $@"{workingDirectory}\{inFileName}";



            // This is for debugging only - this puts down the rest of the packet
            File.Copy(@"S:\Milan\UDK\MilanShaderComp\WorkerInputOnly.in", Path.Combine(workingDirectory, inFileName), true);
            File.Copy(@"S:\Milan\UDK\MilanShaderComp\WorkerInputOnly.in", Path.Combine(workingDirectory, $"WorkerInputOnly.in"), true);

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
            sci.SetUSF("DirectionalLightPixelShader"); // Base shader being compiled.
            sci.SetVertexFactory("LocalVertexFactory"); // Vertex factory, if base shader includes VertexFactory.usf.
            sci.SetMaterial(hlsl);

            //sci.Jobs[0].ShaderInput.SourceText = hlsl;
            sci.Serialize();

            var outs = string.Join(' ', processPath, workingDirectory, parentId, threadId, inFileName, outFileName);
            Debug.WriteLine(outs);

            string[] args = null;
            if (compiler == ECompiler.BIOWARE)
            {
                // args[0] = process
                // args[1] = working directory
                // args[2] = parent process id
                // args[3] = title of console window
                // Decomp doesn't seem to show access on any other args.
                args = [workingDirectory, parentId, threadId];
            }
            else 
            if (compiler == ECompiler.UDK)
            {
                // Tested and working.
                // GuardedMain has an assertion at the start for 6 args, 5 + exe
                args = [workingDirectory, parentId, threadId, inFileName, outFileName];
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