using LegendaryExplorerCore.Helpers;

namespace MilanShaderHost.Old
{
    /// <summary>
    /// Represents the task that is submitted to UE3ShaderCompileWorker.
    /// </summary>
    public class ShaderCompilerJobList
    {
        public ShaderCompilerJobList() { }

        public void Serialize(Stream fs)
        {
            fs.WriteUInt32(BatchVersion);
            fs.WriteInt32(Jobs.Count);
            foreach (var job in Jobs)
            {
                job.Serialize(fs);
            }
        }

        public void Serialize()
        {
            using var fs = File.Create(Path.Combine(WorkingDirectory, InputFilename));
            Console.WriteLine($"Serializing USCW job to {fs.Name}");
            Serialize(fs);
        }

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
        /// Propogates changes that compiler needs to work.
        /// </summary>
        /// <param name="compiler">The compiler target</param>
        internal void SetCompiler(ECompiler compiler)
        {
            foreach (var job in Jobs)
            {
                job.ShaderInput.SetJobType(compiler);
            }
        }

        /// <summary>
        /// For LE only - Sets the base shader file that contains the entrypoint
        /// </summary>
        /// <param name="usfName"></param>
        internal void SetBaseShader(string usfName)
        {
            var exeDir = Directory.GetParent(SimulatedExeLocation).FullName;
            Jobs[0].ShaderInput.SourceFileName = usfName;
            Jobs[0].ShaderInput.SourceText = File.ReadAllText(Path.Combine(exeDir, Jobs[0].ShaderInput.IncludesPath, $"{usfName}.usf"));
        }

        /// <summary>
        /// Sets include for VertexFactory.usf
        /// </summary>
        /// <param name="v"></param>
        internal void SetVertexFactory(string v)
        {
            var exeDir = Directory.GetParent(SimulatedExeLocation).FullName;
            Jobs[0].ShaderInput.Includes.Add("VertexFactory.usf", File.ReadAllText(Path.Combine(exeDir, Jobs[0].ShaderInput.IncludesPath, $"{v}.usf")));
        }

        /// <summary>
        /// Sets include for Material.usf
        /// </summary>
        /// <param name="hlsl"></param>
        internal void SetMaterial(string hlsl)
        {
            var exeDir = Directory.GetParent(SimulatedExeLocation).FullName;
            Jobs[0].ShaderInput.Includes.Add("Material.usf", hlsl);
        }

        /// <summary>
        ///  Seems to always be zero. Decomp shows this value is checked to be zero. Probably a version check
        /// </summary>
        public uint BatchVersion { get; set; }

        /// <summary>
        /// List of jobs in the file
        /// </summary>
        public List<ShaderJob> Jobs { get; } = new();
        public string WorkingDirectory { get; set; }
        public string InputFilename { get; set; }
        public string OutputFilename { get; set; }

        /// <summary>
        /// Used to compute paths as they would be from the exe we are going to run.
        /// </summary>
        public string SimulatedExeLocation { get; set; }
    }
}
