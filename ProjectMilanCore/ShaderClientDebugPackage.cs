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

        // Used by ShaderResearchTool
        public string profile { get; set; }
        public string shaderType { get; set; }
        public string sourceFilename { get; set; }
        /// <summary>
        /// Name of the vertex factory class in CPP
        /// </summary>
        public string vertexFactoryType { get; set; }
        /// <summary>
        /// The base name of the USF used by the vertex factory
        /// </summary>
        public string vertexFactoryShaderFilename { get; set; }

        /// <summary>
        /// If game was able to compile the shader
        /// </summary>
        public bool compileSucceeded { get; set; }

        /// <summary>
        /// Built in ShaderHost - preprocessor scan for all possible conditionally used macros. There might be a few more like number of lights.
        /// </summary>
        public string[] possibleMacros { get; set; }
    }

    public class D3DMacro
    {
        public string name { get; set; }
        public string definition { get; set; }
    }
}
