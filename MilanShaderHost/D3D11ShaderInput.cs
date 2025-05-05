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

        public void Serialize(Stream fs)
        {
            fs.WriteUnrealStringUnicode(SourceFileName);
            fs.WriteUnrealStringUnicode(SourceText);
            fs.WriteUnrealStringUnicode(EntryPoint);
            fs.WriteUnrealStringUnicode(ShaderProfile);
            fs.WriteInt32(CompileFlags);
            fs.WriteUnrealStringUnicode(IncludesPath);
            fs.WriteInt32(Includes.Count);
            foreach (var inc in Includes)
            {
                fs.WriteUnrealStringUnicode(inc.Key);
                fs.WriteUnrealStringUnicode(inc.Value);
            }
            fs.WriteInt32(Macros.Count);
            foreach (var macro in Macros)
            {
                fs.WriteUnrealStringUnicode(macro.Key);
                fs.WriteUnrealStringUnicode(macro.Value);
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
