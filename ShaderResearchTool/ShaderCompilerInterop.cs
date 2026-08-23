using System.Runtime.InteropServices;
using System.Runtime.InteropServices.Marshalling;

namespace ShaderResearchTool;

public readonly record struct CompileResult(int HResult, byte[] ByteCode, string ErrorMessage)
{
    public bool Success => HResult == 0 && ByteCode.Length > 0;
}

/// <summary>
/// Compiles a shader through MilanShaderCompilerLib — the same DLL the in-game ShaderClient uses,
/// so an offline compile and an in-game compile of the same inputs produce identical bytecode.
/// </summary>
public static class ShaderCompilerInterop
{
    [DllImport("MilanShaderCompilerLib.dll", EntryPoint = "CompileShader", ExactSpelling = true)]
    private static extern unsafe int CompileShader_Native(
        byte* baseShaderName, byte* materialHlsl, byte* vertexFactoryName,
        ushort* includesDirectory, void* macros, byte* entryPoint, byte* shaderType,
        int compileFlags,
        ref int outShaderBytesSize, byte[] outShaderBytes,
        ref int outErrorMsgSize, byte[] outErrorMsg);

    private const int ShaderBufferSize = 4 * 1024 * 1024;
    private const int ErrorBufferSize = 8192;

    /// <param name="baseShaderName">Source .usf base name, without extension.</param>
    /// <param name="vertexFactoryName">Vertex factory .usf base name, or null for non-mesh shaders.</param>
    /// <param name="shaderType">"vs" or "ps".</param>
    public static unsafe CompileResult Compile(
        string baseShaderName,
        string materialHlsl,
        string? vertexFactoryName,
        string includesDirectory,
        IReadOnlyList<(string Name, string Definition)> macros,
        string entryPoint,
        string shaderType,
        int compileFlags)
    {
        var errorMessage = string.Empty;
        var shaderBytes = Array.Empty<byte>();

        int shaderBufferSize = ShaderBufferSize;
        int errorBufferSize = ErrorBufferSize;

        baseShaderName += ".usf";
        var vfName = string.IsNullOrEmpty(vertexFactoryName) ? "" : vertexFactoryName + ".usf";

        scoped AnsiStringMarshaller.ManagedToUnmanagedIn baseShaderM = new();
        scoped AnsiStringMarshaller.ManagedToUnmanagedIn materialHlslM = new();
        scoped AnsiStringMarshaller.ManagedToUnmanagedIn vertexFactoryM = new();
        scoped AnsiStringMarshaller.ManagedToUnmanagedIn entryPointM = new();
        scoped AnsiStringMarshaller.ManagedToUnmanagedIn shaderTypeM = new();

        byte** macroStrings = null;
        int numStrings = macros.Count * 2;

        try
        {
            // Two string pointers per macro, plus a null-terminating pair at the end.
            macroStrings = (byte**)NativeMemory.AllocZeroed((nuint)(numStrings + 2), (nuint)IntPtr.Size);
            byte** it = macroStrings;
            foreach (var (name, definition) in macros)
            {
                *it++ = AnsiStringMarshaller.ConvertToUnmanaged(name);
                *it++ = AnsiStringMarshaller.ConvertToUnmanaged(definition);
            }

            int bufSize = AnsiStringMarshaller.ManagedToUnmanagedIn.BufferSize;
            baseShaderM.FromManaged(baseShaderName, stackalloc byte[bufSize]);
            materialHlslM.FromManaged(materialHlsl, stackalloc byte[bufSize]);
            vertexFactoryM.FromManaged(vfName, stackalloc byte[bufSize]);
            entryPointM.FromManaged(entryPoint, stackalloc byte[bufSize]);
            shaderTypeM.FromManaged(shaderType, stackalloc byte[bufSize]);

            fixed (void* includesDirPtr = &Utf16StringMarshaller.GetPinnableReference(includesDirectory))
            {
                var shaderBuffer = new byte[shaderBufferSize];
                var errorBuffer = new byte[errorBufferSize];

                var result = CompileShader_Native(
                    baseShaderM.ToUnmanaged(),
                    materialHlslM.ToUnmanaged(),
                    vertexFactoryM.ToUnmanaged(),
                    (ushort*)includesDirPtr,
                    macroStrings,
                    entryPointM.ToUnmanaged(),
                    shaderTypeM.ToUnmanaged(),
                    compileFlags,
                    ref shaderBufferSize, shaderBuffer,
                    ref errorBufferSize, errorBuffer);

                if (result != 0)
                {
                    if (errorBufferSize > 0)
                    {
                        errorMessage = System.Text.Encoding.ASCII.GetString(errorBuffer, 0, errorBufferSize);
                    }
                }
                else if (shaderBufferSize > 0)
                {
                    shaderBytes = new byte[shaderBufferSize];
                    Buffer.BlockCopy(shaderBuffer, 0, shaderBytes, 0, shaderBufferSize);
                }

                return new CompileResult(result, shaderBytes, errorMessage);
            }
        }
        finally
        {
            if (macroStrings is not null)
            {
                byte** freeIt = macroStrings;
                for (int i = 0; i < numStrings; i++)
                {
                    AnsiStringMarshaller.Free(*freeIt);
                    freeIt++;
                }
                NativeMemory.Free(macroStrings);
            }

            baseShaderM.Free();
            materialHlslM.Free();
            vertexFactoryM.Free();
            entryPointM.Free();
            shaderTypeM.Free();
        }
    }
}
