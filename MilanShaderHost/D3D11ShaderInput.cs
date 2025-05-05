using LegendaryExplorerCore.Helpers;
using LegendaryExplorerCore.Misc;
using System.Text;

namespace MilanShaderHost
{
    /// <summary>
    /// Describes the input to D3DCompile
    /// </summary>
    public class D3D11ShaderInput
    {
        /// <summary>
        /// Shader type. We only care about D3D11, so this is always 0.
        /// </summary>
        public int ShaderJobType { get; set; }

        /// <summary>
        /// Version number of file format
        /// </summary>
        public byte JobVersion { get; set; }

        // Shader stuff.
        public string SourceFileName { get; set; }
        public string SourceText { get; set; }
        public string EntryPoint { get; set; }
        public string ShaderProfile { get; set; }
        public int CompileFlags { get; set; }
        public string IncludesPath { get; set; }

        public CaseInsensitiveDictionary<string> Includes { get; } = new();
        public CaseInsensitiveDictionary<string> Macros { get; } = new();

        public D3D11ShaderInput(Stream fs)
        {
            var inPos = fs.Position;
            ShaderJobType = fs.ReadInt32();
            JobVersion = (byte) fs.ReadByte();

            SourceFileName = fs.ReadUnrealString();
            SourceText = fs.ReadUnrealString();
            EntryPoint = fs.ReadUnrealString();
            ShaderProfile = fs.ReadUnrealString();
            CompileFlags = fs.ReadInt32();
            IncludesPath = fs.ReadUnrealString();

            var numIncludes = fs.ReadInt32();
            while (numIncludes > 0)
            {
                Includes[fs.ReadUnrealString()] = fs.ReadUnrealString();
                numIncludes--;
            }

            var numMacros = fs.ReadInt32();
            while (numMacros > 0)
            {
                Macros[fs.ReadUnrealString()] = fs.ReadUnrealString();
                numMacros--;
            }
            Console.WriteLine($"ShaderInputLen: {(fs.Position - inPos)}");

        }

        public void Serialize(Stream fs)
        {
            var inPos = fs.Position;
            fs.WriteInt32(ShaderJobType);
            fs.WriteByte(JobVersion);

            fs.WriteShaderString(SourceFileName);
            fs.WriteShaderString(SourceText);
            fs.WriteShaderString(EntryPoint);
            fs.WriteShaderString(ShaderProfile);
            fs.WriteInt32(CompileFlags);
            fs.WriteShaderString(IncludesPath);

            fs.WriteInt32(Includes.Count);
            foreach (var inc in Includes)
            {
                fs.WriteShaderString(inc.Key);
                fs.WriteShaderString(inc.Value);
            }
            fs.WriteInt32(Macros.Count);
            foreach (var macro in Macros)
            {
                fs.WriteShaderString(macro.Key);
                fs.WriteShaderString(macro.Value);
            }
            var outPos = fs.Position;
            Console.WriteLine($"Reserialized ShaderInputLen: {(outPos - inPos)}");
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
