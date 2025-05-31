using BCnEncoder.Shared.ImageFiles;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Unreal.BinaryConverters;
using System.Runtime.InteropServices;
using static LegendaryExplorerCore.Unreal.UnrealFlags;

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



    internal class ShaderCompiler
    {
        // Todo: figure this out and the D3D_MACRO_LIST. it must be null terminated with empty array at the end.
        [DllImport("MilanShaderCompilerLib.dll")]
        public static extern void CompileShader();


        public static void CompileShader(string hlsl)
        {

        }

        /// <summary>
        /// Constructs
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
    }
}
