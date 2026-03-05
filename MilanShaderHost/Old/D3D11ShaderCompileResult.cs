namespace MilanShaderHost.Old
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
        /// <summary>
        /// Type of job result
        /// </summary>
        public int JobType { get; set; }
        /// <summary>
        /// HRESULT code
        /// </summary>
        public int CompileResult { get; set; }
        /// <summary>
        /// Shader bytecode
        /// </summary>
        public byte[] Bytecode { get; set; }
        public string ErrorText { get; set; }
        public int OutputVersion { get; internal set; }
    }
}