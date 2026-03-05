using System;
using System.Collections.Generic;
using System.Text;

namespace MilanShaderHost
{
    public class ShaderClientDebugPackage
    {
        public string functionName { get; set; }
        public D3DMacro[] macros { get; set; }
        public string materialHlsl { get; set; }
        public string shaderType { get; set; }
        public string sourceFilename { get; set; }
        public string vertexFactoryType { get; set; }
    }

    public class D3DMacro
    {
        public string name { get; set; }
        public string definition { get; set; }
    }
}
