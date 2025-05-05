using CliWrap;
using LegendaryExplorerCore.Gammtek.Extensions.IO;
using LegendaryExplorerCore.Helpers;
using LegendaryExplorerCore.Misc;
using System.Diagnostics;
using System.Text;

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
            var inputHlsl = File.ReadAllText(@"S:\Milan\UDK\MilanShaderComp\PickUpSwipe_MM.hlsl");
            var wasOK = await CompileShader(inputHlsl);
        }

        public async static Task<bool> CompileShader(string hlsl)
        {
            var processPath = "S:\\SteamLibrary\\steamapps\\common\\Mass Effect Legendary Edition\\Game\\ME3\\Binaries\\ShaderCompiler\\UE3ShaderCompileWorker.exe";

            // Where files go
            var workingDirectory = "S:\\Milan\\UDK\\MilanShaderComp\\Scratch\\";

            // Process id of calling proc?
            var parentId = Process.GetCurrentProcess().Id.ToString();

            // Unique identifier to the parent id
            var threadId = "1"; // I don't think this matters. It is probably used by the editor to track what thread is running.

            // Input file - must be in special binary format.
            // If it contains 'InputOnly' in the filename it will cause the process to exit on completion.
            var inFileName = "WorkerInput.in";

            // The file name that UE3ShaderCompileWorker will output
            var outFileName = "WorkerOutput.out";

            var inputFilePath = $@"{workingDirectory}\{inFileName}";


            // This is for debugging only - this puts down the rest of the packet
            File.Copy(@"S:\Milan\UDK\MilanShaderComp\WorkerInputOnly.in", Path.Combine(workingDirectory, inFileName), true);

            var sci = new ShaderCompilerJobList();
            sci.WorkingDirectory = workingDirectory;
            sci.InputFilename = inFileName;
            sci.OutputFilename = outFileName;
            sci.ReadInput();
            sci.Jobs[0].ShaderInput.SourceText = hlsl;

            sci.Serialize();

            
            var result = await Cli.Wrap(processPath)
                     .WithArguments([workingDirectory, parentId, threadId, inFileName, outFileName])
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