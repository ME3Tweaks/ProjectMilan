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
            var wasOK = await CompileShader();
        }

        public static void DecryptShaderSources()
        {
            var baseDir = @"E:\UDK2015\Engine\Shaders";
            var encryptedDir = Path.Combine(baseDir, "Binaries");
            var decrypteddir = Path.Combine(baseDir, "Sources");

            var files = Directory.GetFiles(encryptedDir);
            Directory.CreateDirectory(decrypteddir);

            foreach (var f in files)
            {
                Console.WriteLine($"Decrypting {f}");
                using var fs = File.OpenRead(f);

                // Some sort of header... decomp shows it just skips 24 bytes for some reason
                fs.Skip(24); // First int seems to always be 1.

                var remaining = fs.ReadFully();
                ShaderEncryption.ApplyXorCipher(remaining);
                var outPath = Path.Combine(decrypteddir, $"{Path.GetFileNameWithoutExtension(f)}.usf");
                File.WriteAllBytes(outPath, remaining);
            }

        }

        public async static Task<bool> CompileShader()
        {
            var processPath = "E:\\UDK2015\\Binaries\\Win64\\UE3ShaderCompileWorker.exe";

            // Where files go
            var workingDirectory = "E:\\UDK2015\\MilanShaderComp\\Scratch\\";

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
            File.Copy(@"E:\UDK2015\MilanShaderComp\WorkerInputOnly.in", inputFilePath, true);

            var sci = new ShaderCompilerJobList();
            sci.WorkingDirectory = workingDirectory;
            sci.InputFilename = inFileName;
            sci.OutputFilename = outFileName;
            sci.ReadInput();
            
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

    class ShaderCompilerJobList
    {
        public ShaderCompilerJobList() { }

        public void ReadInput()
        {
            using var fs = File.OpenRead(Path.Combine(WorkingDirectory, InputFilename));

            BatchVersion = fs.ReadUInt32();
            var numJobs = fs.ReadUInt32();

            for (int i = 0; i < numJobs; i++)
            {
                Jobs.Add(new ShaderJob(fs));
            }
        }

        public void ReadOutput()
        {
            using var fs = File.OpenRead(Path.Combine(WorkingDirectory, OutputFilename));
            var outputVersion = fs.ReadInt32();
            var numResults = fs.ReadInt32();
            if (Jobs.Count != numResults)
            {
                throw new Exception("Jobs count doesn't match between input and output files!");
            }

            for (int i = 0; i < numResults; i++)
            {

                D3D11ShaderCompileResult result = new D3D11ShaderCompileResult()
                {
                    OutputVersion = fs.ReadByte(),
                    JobId = fs.ReadInt32(),
                    JobType = fs.ReadInt32(),
                    CompileResult = fs.ReadInt32(),
                    Bytecode = fs.ReadToBuffer(fs.ReadInt32()),
                    ErrorText = fs.ReadUnrealString()
                };

                // hopefully the results come back in order! JobId doesn't seem to match the input
                Jobs[i].Result = result;
            }
        }

        internal void PrintResults()
        {
            foreach (var job in Jobs)
            {
                Console.WriteLine($"Job {job.JobId}");
                Console.WriteLine($"\tSucceeded: {(job.Result.CompileResult == 0)}");
                if (job.Result.CompileResult != 0)
                {
                    Console.WriteLine($"\tError: {job.Result.ErrorText}");
                }
                else
                {
                    Console.WriteLine($"\tBytecode: {job.Result.Bytecode.Length} bytes");
                }

            }
        }

        /// <summary>
        ///  Seems to always be zero. Decomp shows this value is checked to be zero. Probably a version check
        /// </summary>
        public uint BatchVersion { get; set; }

        /// <summary>
        /// List of jobs in the file
        /// </summary>
        public List<ShaderJob> Jobs { get; } = new();
        public string WorkingDirectory { get; internal set; }
        public string InputFilename { get; internal set; }
        public string OutputFilename { get; internal set; }
    }

    /// <summary>
    /// Describes a job for shader compile
    /// </summary>
    class ShaderJob
    {
        public ShaderJob(Stream fs)
        {
            JobId = fs.ReadInt32();

            var inputLen = fs.ReadInt32();
            var isEncrypted = fs.ReadBoolInt();
            var input = fs.ReadToBuffer(inputLen);

            if (isEncrypted)
            {
                // Decrypt it
                ShaderEncryption.ApplyXorCipher(input);
            }

            var inputStream = new MemoryStream(input);

            var jobType = inputStream.ReadInt32();
            var jobVersion = inputStream.ReadByte();
            ShaderInput = new D3D11ShaderInput(inputStream);
            ShaderInput.Decompile(@"E:\UDK2015\MilanShaderComp\Decomp");
            ShaderInput.Print();
        }


        public int JobId { get; private set; }
        public D3D11ShaderInput ShaderInput { get; }
        public D3D11ShaderCompileResult Result { get; internal set; }
    }

    /// <summary>
    /// Describes the input to D3DCompile
    /// </summary>
    public class D3D11ShaderInput
    {
        public string SourceFileName { get; set; }
        public string SourceText { get; set; }
        public string EntryPoint { get; set; }
        public string ShaderProfile { get; set; }
        public int CompileFlags { get; set; }
        public string IncludesPath { get; set; }

        public CaseInsensitiveDictionary<string> Includes { get; } = new();
        public CaseInsensitiveDictionary<string> Macros { get; } = new();

        public D3D11ShaderInput(Stream inStream)
        {
            SourceFileName = inStream.ReadUnrealString();
            SourceText = inStream.ReadUnrealString();
            EntryPoint = inStream.ReadUnrealString();
            ShaderProfile = inStream.ReadUnrealString();
            CompileFlags = inStream.ReadInt32();
            IncludesPath = inStream.ReadUnrealString();
            var numIncludes = inStream.ReadInt32();
            while (numIncludes > 0)
            {
                Includes[inStream.ReadUnrealString()] = inStream.ReadUnrealString();
                numIncludes--;
            }

            var numMacros = inStream.ReadInt32();
            while (numMacros > 0)
            {
                Macros[inStream.ReadUnrealString()] = inStream.ReadUnrealString();
                numMacros--;
            }
        }

        public void Print()
        {
            Console.WriteLine($"SourceFileName: {SourceFileName}");
            Console.WriteLine($"SourceText: {SourceText.Length} chars");
            Console.WriteLine($"EntryPoint: {EntryPoint}");
            Console.WriteLine($"ShaderProfile: {ShaderProfile}");
            Console.WriteLine($"Compile flags: {CompileFlags:X8}");
            Console.WriteLine($"IncludesPath: {IncludesPath}");
            Console.WriteLine($"Includes:");
            foreach (var inc in Includes)
            {
                Console.WriteLine($"\t{inc.Key}");
            }
            Console.WriteLine($"Macros:");
            foreach (var macro in Macros)
            {
                Console.WriteLine($"\t{macro.Key}={macro.Value}");
            }
        }

        internal void Decompile(string outDir)
        {
            Directory.CreateDirectory(outDir);
            File.WriteAllText(Path.Combine(outDir, SourceFileName), SourceText);

            StringBuilder sb = new StringBuilder();
            sb.AppendLine($"EntryPoint: {EntryPoint}");
            sb.AppendLine($"ShaderProfile: {ShaderProfile}");
            sb.AppendLine($"Compile flags: {CompileFlags:X8}");
            sb.AppendLine($"IncludesPath: {IncludesPath}");

            sb.AppendLine($"Macros:");
            foreach (var macro in Macros)
            {
                sb.AppendLine($"\t{macro.Key}={macro.Value}");
            }

            File.WriteAllText(Path.Combine(outDir, "D3DInputs.txt"), sb.ToString());
            foreach (var inc in Includes)
            {
                var outPath = Path.Combine(outDir, inc.Key);
                File.WriteAllText(outPath, inc.Value);
            }
        }
    }
}