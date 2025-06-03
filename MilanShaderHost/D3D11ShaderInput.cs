using LegendaryExplorerCore.Helpers;
using LegendaryExplorerCore.Misc;
using System.Diagnostics;
using System.Text;

namespace MilanShaderHost
{
    [Flags]
    public enum D3DCompileFlags
    {
        //----------------------------------------------------------------------------
        // D3DCOMPILE flags:
        // -----------------
        // D3DCOMPILE_DEBUG
        //   Insert debug file/line/type/symbol information.
        //
        // D3DCOMPILE_SKIP_VALIDATION
        //   Do not validate the generated code against known capabilities and
        //   constraints.  This option is only recommended when compiling shaders
        //   you KNOW will work.  (ie. have compiled before without this option.)
        //   Shaders are always validated by D3D before they are set to the device.
        //
        // D3DCOMPILE_SKIP_OPTIMIZATION 
        //   Instructs the compiler to skip optimization steps during code generation.
        //   Unless you are trying to isolate a problem in your code using this option 
        //   is not recommended.
        //
        // D3DCOMPILE_PACK_MATRIX_ROW_MAJOR
        //   Unless explicitly specified, matrices will be packed in row-major order
        //   on input and output from the shader.
        //
        // D3DCOMPILE_PACK_MATRIX_COLUMN_MAJOR
        //   Unless explicitly specified, matrices will be packed in column-major 
        //   order on input and output from the shader.  This is generally more 
        //   efficient, since it allows vector-matrix multiplication to be performed
        //   using a series of dot-products.
        //
        // D3DCOMPILE_PARTIAL_PRECISION
        //   Force all computations in resulting shader to occur at partial precision.
        //   This may result in faster evaluation of shaders on some hardware.
        //
        // D3DCOMPILE_FORCE_VS_SOFTWARE_NO_OPT
        //   Force compiler to compile against the next highest available software
        //   target for vertex shaders.  This flag also turns optimizations off, 
        //   and debugging on.  
        //
        // D3DCOMPILE_FORCE_PS_SOFTWARE_NO_OPT
        //   Force compiler to compile against the next highest available software
        //   target for pixel shaders.  This flag also turns optimizations off, 
        //   and debugging on.
        //
        // D3DCOMPILE_NO_PRESHADER
        //   Disables Preshaders. Using this flag will cause the compiler to not 
        //   pull out static expression for evaluation on the host cpu
        //
        // D3DCOMPILE_AVOID_FLOW_CONTROL
        //   Hint compiler to avoid flow-control constructs where possible.
        //
        // D3DCOMPILE_PREFER_FLOW_CONTROL
        //   Hint compiler to prefer flow-control constructs where possible.
        //
        // D3DCOMPILE_ENABLE_STRICTNESS
        //   By default, the HLSL/Effect compilers are not strict on deprecated syntax.
        //   Specifying this flag enables the strict mode. Deprecated syntax may be
        //   removed in a future release, and enabling syntax is a good way to make
        //   sure your shaders comply to the latest spec.
        //
        // D3DCOMPILE_ENABLE_BACKWARDS_COMPATIBILITY
        //   This enables older shaders to compile to 4_0 targets.
        //
        // D3DCOMPILE_DEBUG_NAME_FOR_SOURCE
        //   This enables a debug name to be generated based on source information.
        //   It requires D3DCOMPILE_DEBUG to be set, and is exclusive with
        //   D3DCOMPILE_DEBUG_NAME_FOR_BINARY.
        //
        // D3DCOMPILE_DEBUG_NAME_FOR_BINARY
        //   This enables a debug name to be generated based on compiled information.
        //   It requires D3DCOMPILE_DEBUG to be set, and is exclusive with
        //   D3DCOMPILE_DEBUG_NAME_FOR_SOURCE.
        //
        //----------------------------------------------------------------------------

        D3DCOMPILE_DEBUG = (1 << 0),
        D3DCOMPILE_SKIP_VALIDATION = (1 << 1),
        D3DCOMPILE_SKIP_OPTIMIZATION = (1 << 2),
        D3DCOMPILE_PACK_MATRIX_ROW_MAJOR = (1 << 3),
        D3DCOMPILE_PACK_MATRIX_COLUMN_MAJOR = (1 << 4),
        D3DCOMPILE_PARTIAL_PRECISION = (1 << 5),
        D3DCOMPILE_FORCE_VS_SOFTWARE_NO_OPT = (1 << 6),
        D3DCOMPILE_FORCE_PS_SOFTWARE_NO_OPT = (1 << 7),
        D3DCOMPILE_NO_PRESHADER = (1 << 8),
        D3DCOMPILE_AVOID_FLOW_CONTROL = (1 << 9),
        D3DCOMPILE_PREFER_FLOW_CONTROL = (1 << 10),
        D3DCOMPILE_ENABLE_STRICTNESS = (1 << 11),
        D3DCOMPILE_ENABLE_BACKWARDS_COMPATIBILITY = (1 << 12),
        D3DCOMPILE_IEEE_STRICTNESS = (1 << 13),
        D3DCOMPILE_OPTIMIZATION_LEVEL0 = (1 << 14),
        D3DCOMPILE_OPTIMIZATION_LEVEL1 = 0,
        D3DCOMPILE_OPTIMIZATION_LEVEL2 = ((1 << 14) | (1 << 15)),
        D3DCOMPILE_OPTIMIZATION_LEVEL3 = (1 << 15),
        D3DCOMPILE_RESERVED16 = (1 << 16),
        D3DCOMPILE_RESERVED17 = (1 << 17),
        D3DCOMPILE_WARNINGS_ARE_ERRORS = (1 << 18),
        D3DCOMPILE_RESOURCES_MAY_ALIAS = (1 << 19),
        D3DCOMPILE_ENABLE_UNBOUNDED_DESCRIPTOR_TABLES = (1 << 20),
        D3DCOMPILE_ALL_RESOURCES_BOUND = (1 << 21),
        D3DCOMPILE_DEBUG_NAME_FOR_SOURCE = (1 << 22),
        D3DCOMPILE_DEBUG_NAME_FOR_BINARY = (1 << 23)
    }

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
            JobVersion = (byte)fs.ReadByte();

            SourceFileName = fs.ReadUnrealString();
            SourceText = fs.ReadUnrealString();
            EntryPoint = fs.ReadUnrealString();
            ShaderProfile = fs.ReadUnrealString();
            CompileFlags = fs.ReadInt32();
            IncludesPath = fs.ReadUnrealString();
            
            var flags = (D3DCompileFlags)CompileFlags;
            Debug.WriteLine(flags);

            var numIncludes = fs.ReadInt32();
            while (numIncludes > 0)
            {
                Includes[fs.ReadUnrealString()] = fs.ReadUnrealString();
                numIncludes--;
            }

            var numMacros = fs.ReadInt32();
            while (numMacros > 0)
            {
                var key = fs.ReadUnrealString();
                var value = fs.ReadUnrealString();
                Macros[key] = value;
                numMacros--;
                Debug.WriteLine($"new D3D_SHADER_MACRO(\"{key}\", \"{value}\"),");
            }
            //Console.WriteLine($"ShaderInputLen: {(fs.Position - inPos)}");

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
            // Console.WriteLine($"Reserialized ShaderInputLen: {(outPos - inPos)}");
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

        internal void SetJobType(ECompiler compiler)
        {
            if (compiler == ECompiler.BIOWARE)
                ShaderJobType = 1; // D3D "10" according to decomp. Probably D3D11 in reality.
            else
                ShaderJobType = 0; // D3D11
        }
    }
}
