using LegendaryExplorerCore.Helpers;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace MilanShaderHost
{
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
            
            
            // ShaderInput.Decompile(@"E:\UDK2015\MilanShaderComp\Decomp");
            // ShaderInput.Print();
        }


        public int JobId { get; private set; }
        public D3D11ShaderInput ShaderInput { get; }
        public D3D11ShaderCompileResult Result { get; internal set; }

        internal void Serialize(Stream fs)
        {

        }
    }
}
