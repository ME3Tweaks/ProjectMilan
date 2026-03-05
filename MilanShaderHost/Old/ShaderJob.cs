using LegendaryExplorerCore.Helpers;

namespace MilanShaderHost.Old
{
    /// <summary>
    /// Describes a job for shader compile
    /// </summary>
    public class ShaderJob
    {
        public ShaderJob(Stream fs)
        {
            JobId = fs.ReadInt32();

            var inputLen = fs.ReadInt32();
            PayloadEncrypted = fs.ReadBoolInt();
            var input = fs.ReadToBuffer(inputLen);

            if (PayloadEncrypted)
            {
                // Decrypt it
                ShaderEncryption.ApplyXorCipher(input);
            }

            var inputStream = new MemoryStream(input);
            ShaderInput = new D3D11ShaderInput(inputStream);

            // ShaderInput.Decompile(@"E:\UDK2015\MilanShaderComp\Decomp");
            // ShaderInput.Print();
        }


        public int JobId { get; private set; }
        public D3D11ShaderInput ShaderInput { get; }
        public D3D11ShaderCompileResult Result { get; internal set; }
        public bool PayloadEncrypted { get; }

        internal void Serialize(Stream fs)
        {
            // Write out the payload first
            MemoryStream subStream = new MemoryStream();
            ShaderInput.Serialize(subStream);

            fs.WriteInt32(JobId);
            fs.WriteInt32((int)subStream.Length);
            fs.WriteBoolInt(PayloadEncrypted);
            if (PayloadEncrypted)
            {
                var payload = subStream.ToArray();
                ShaderEncryption.ApplyXorCipher(payload);
                fs.Write(payload);
            }
            else
            {
                subStream.CopyTo(fs);
            }
        }
    }
}
