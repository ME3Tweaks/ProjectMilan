using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Unreal.BinaryConverters;
using System.Runtime.InteropServices;
using System.Runtime.InteropServices.Marshalling;
using static LegendaryExplorerCore.Unreal.UnrealFlags;
using LegendaryExplorerCore.GameFilesystem;

namespace MilanShaderHost
{
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Ansi, Pack = 1)]
    struct D3D_SHADER_MACRO
    {
        [MarshalAs(UnmanagedType.LPStr)]
        public string Name;
        [MarshalAs(UnmanagedType.LPStr)]
        public string Value;
    }



    internal unsafe class ShaderCompiler
    {
        public struct D3D_SHADER_MACRO(string name, string definition)
        {
            public string Name = name;
            public string Definition = definition;
        }

        [DllImport("MilanShaderCompilerLib.dll", EntryPoint = "CompileShader", ExactSpelling = true)]
        private static extern unsafe int CompileShader_Native(byte* baseShaderName, byte* materialHlsl, byte* vertexFactoryName, ushort* includesDirectory, void* macros, byte* entryPoint, byte* shaderType,
            // Out parameters.
            ref int outShaderBytesSize,
            byte[] outShaderBytes,
            ref int outErrorMsgSize,
            byte[] outErrorMsg);

        /// <summary>
        /// Compiles a shader with MilanShaderCompilerLib.
        /// </summary>
        /// <param name="baseShaderName"></param>
        /// <param name="materialHlsl"></param>
        /// <param name="vertexFactoryName"></param>
        /// <param name="includesDirectory"></param>
        /// <param name="macros"></param>
        /// <param name="entryPoint"></param>
        /// <param name="shaderType"></param>
        /// <returns></returns>
        public static unsafe int CompileShader(string baseShaderName, string materialHlsl, string vertexFactoryName, string includesDirectory, D3D_SHADER_MACRO[] macros, string entryPoint, string shaderType, out byte[] shaderBytes, out string errorMessage)
        {
            errorMessage = string.Empty;
            shaderBytes = Array.Empty<byte>();

            int shaderBufferSize = 4 * 1024 * 1024; // 4MiB
            int errorBufferSize = 2048; // 2KiB

            baseShaderName += ".usf";
            if (vertexFactoryName != null)
            {
                vertexFactoryName += ".usf";
            }

            scoped AnsiStringMarshaller.ManagedToUnmanagedIn shaderType_marshaller = new();
            scoped AnsiStringMarshaller.ManagedToUnmanagedIn entryPoint_marshaller = new();
            scoped AnsiStringMarshaller.ManagedToUnmanagedIn vertexFactoryName_marshaller = new();
            scoped AnsiStringMarshaller.ManagedToUnmanagedIn materialHlsl_marshaller = new();
            scoped AnsiStringMarshaller.ManagedToUnmanagedIn baseShaderName_marshaller = new();
            byte** macroStrings = null;
            int numStrings = macros.Length * 2;
            try
            {
                //two string pointers per struct, plus a null struct at the end
                macroStrings = (byte**)NativeMemory.AllocZeroed((nuint)numStrings + 2, (nuint)IntPtr.Size);
                byte** it = macroStrings;
                foreach (var macro in macros)
                {
                    *it = AnsiStringMarshaller.ConvertToUnmanaged(macro.Name);
                    it++;
                    *it = AnsiStringMarshaller.ConvertToUnmanaged(macro.Definition);
                    it++;
                }

                int ansiMarshallerBufferSize = AnsiStringMarshaller.ManagedToUnmanagedIn.BufferSize;
                shaderType_marshaller.FromManaged(shaderType, (stackalloc byte[ansiMarshallerBufferSize]));
                entryPoint_marshaller.FromManaged(entryPoint, (stackalloc byte[ansiMarshallerBufferSize]));
                vertexFactoryName_marshaller.FromManaged(vertexFactoryName, (stackalloc byte[ansiMarshallerBufferSize]));
                materialHlsl_marshaller.FromManaged(materialHlsl, (stackalloc byte[ansiMarshallerBufferSize]));
                baseShaderName_marshaller.FromManaged(baseShaderName, (stackalloc byte[ansiMarshallerBufferSize]));



                fixed (void* includesDirectory_native = &Utf16StringMarshaller.GetPinnableReference(includesDirectory))
                {
                    byte* shaderType_native = shaderType_marshaller.ToUnmanaged();
                    byte* entryPoint_native = entryPoint_marshaller.ToUnmanaged();
                    byte* vertexFactoryName_native = vertexFactoryName_marshaller.ToUnmanaged();
                    byte* materialHlsl_native = materialHlsl_marshaller.ToUnmanaged();
                    byte* baseShaderName_native = baseShaderName_marshaller.ToUnmanaged();

                    byte[] shaderBuffer = new byte[shaderBufferSize]; // 4MiB 
                    byte[] errorBuffer = new byte[errorBufferSize]; // 2KiB
                    var result = CompileShader_Native(baseShaderName_native, materialHlsl_native, vertexFactoryName_native, (ushort*)includesDirectory_native, macroStrings, entryPoint_native, shaderType_native, ref shaderBufferSize, shaderBuffer, ref errorBufferSize, errorBuffer);
                    if (result != 0)
                    {
                        if (errorBufferSize > 0)
                        {
                            errorMessage = System.Text.Encoding.ASCII.GetString(errorBuffer, 0, errorBufferSize);
                        }
                    }

                    return result;
                }
            }
            finally
            {
                if (macroStrings is not null)
                {
                    byte** it = macroStrings;
                    for (int i = 0; i < numStrings; i++)
                    {
                        AnsiStringMarshaller.Free(*it);
                        it++;
                    }
                }
                NativeMemory.Free(macroStrings);

                shaderType_marshaller.Free();
                entryPoint_marshaller.Free();
                vertexFactoryName_marshaller.Free();
                materialHlsl_marshaller.Free();
                baseShaderName_marshaller.Free();
            }
        }



        /// <summary>
        /// Takes the compiled result and stores it 
        /// </summary>
        /// <param name="package"></param>
        public static void InsertIntoShaderCache(IMEPackage package)
        {
            var sfsc = package.FindExport("SeekFreeShaderCache");
            if (sfsc == null)
            {
                package.AddExport(new ExportEntry(package, null, "SeekFreeShaderCache", BitConverter.GetBytes(-1), binary: ShaderCache.Create())
                {
                    Class = package.GetEntryOrAddImport("Engine.ShaderCache", "Class"),
                    ObjectFlags = EObjectFlags.LoadForClient | EObjectFlags.LoadForEdit | EObjectFlags.LoadForServer | EObjectFlags.Standalone
                });
                sfsc = package.FindExport("SeekFreeShaderCache");
                var cache = ObjectBinary.From<ShaderCache>(sfsc);


                // Commit result.
                sfsc.WriteBinary(cache);
            }
        }

        /// <summary>
        /// Compiles all shader types for the given material HLSL.
        /// </summary>
        /// <param name="materialHLSL"></param>
        internal static void CompileShadersFor(string materialHLSL)
        {
            // This is a placeholder for the actual shader compilation logic.
            // You would typically call CompileShader with the appropriate parameters here.
            // Example usage:
            string baseShaderName = "DirectionalLightPixelShader";
            string vertexFactoryName = "LocalVertexFactory";
            string includesDirectory = Path.Combine(LE3Directory.DefaultGamePath, "Engine", "Shaders");
            D3D_SHADER_MACRO[] macros = new D3D_SHADER_MACRO[]
            {
                new D3D_SHADER_MACRO("COMPILER_HLSL", "1"),
                new D3D_SHADER_MACRO("SM5_PROFILE", "1"),
                new D3D_SHADER_MACRO("VERTEX_FACTORY_SUPPORTS_LOCALTOWORLD", "1"),
                new D3D_SHADER_MACRO("USING_SM5_TESSELLATION", "0"),
                new D3D_SHADER_MACRO("MATERIALBLENDING_TRANSLUCENT", "1"),
                new D3D_SHADER_MACRO("MATERIAL_TWOSIDED", "0"),
                new D3D_SHADER_MACRO("MATERIAL_TWOSIDED_SEPARATE_PASS", "0"),
                new D3D_SHADER_MACRO("MATERIAL_LIT_TRANSLUCENCY_PREPASS", "0"),
                new D3D_SHADER_MACRO("MATERIAL_LIT_TRANSLUCENCY_DEPTH_POSTPASS", "0"),
                new D3D_SHADER_MACRO("MATERIAL_CAST_LIT_TRANSLUCENCY_SHADOW_AS_MASKED", "0"),
                new D3D_SHADER_MACRO("MATERIAL_ENABLE_SUBSURFACE_SCATTERING", "0"),
                new D3D_SHADER_MACRO("MATERIAL_LIGHTINGMODEL_UNLIT", "1"),
                new D3D_SHADER_MACRO("WORLD_COORDS", "1"),
                new D3D_SHADER_MACRO("WORLD_POS", "1"),
                new D3D_SHADER_MACRO("NUM_LIGHTMAP_COEFFICIENTS", "2"),
                new D3D_SHADER_MACRO("FOGVOLUMEDENSITY_NONE", "1"),
                new D3D_SHADER_MACRO("PIXELSHADER", "1"),
                new D3D_SHADER_MACRO("DOMAINSHADER", "0"),
                new D3D_SHADER_MACRO("HULLSHADER", "0"),
                new D3D_SHADER_MACRO("VERTEXSHADER", "1"),
                new D3D_SHADER_MACRO("GEOMETRYSHADER", "0"),
                new D3D_SHADER_MACRO("COMPUTESHADER", "0"),
                new D3D_SHADER_MACRO("ALLOW_NVIDIA_STEREO_3D", "1"),
                new D3D_SHADER_MACRO("WITH_REALD", "0"),
                new D3D_SHADER_MACRO("SUPPORTS_DEPTH_TEXTURES", "1"),
            };

            string entryPoint = "Main";
            string shaderType = "ps";
            byte[] shaderBytes;
            string errorMessage;
            int result = CompileShader(baseShaderName, materialHLSL, vertexFactoryName, includesDirectory, macros, entryPoint, shaderType, out shaderBytes, out errorMessage);
            if (result != 0)
            {
                Console.WriteLine($"Shader compilation failed: {errorMessage}");
                return;
            }
            Console.WriteLine("Shader compiled successfully.");

            // Here you would typically insert the compiled shader into the shader cache.
        }
    }
}
