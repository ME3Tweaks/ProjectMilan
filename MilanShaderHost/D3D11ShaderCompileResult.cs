namespace MilanShaderHost
{
    /// <summary>
    /// Describes the result of a compilation
    /// </summary>
    public class D3D11ShaderCompileResult
    {
        public D3D11ShaderCompileResult()
        {
        }

        public int JobId { get; set; }
        public int JobType { get; set; }
        public int CompileResult { get; set; }
        public byte[] Bytecode { get; set; }
        public string ErrorText { get; set; }
        public int OutputVersion { get; internal set; }
    }
}