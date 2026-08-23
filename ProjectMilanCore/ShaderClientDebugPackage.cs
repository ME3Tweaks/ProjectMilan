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
        /// False when the job was captured without compiling (-CaptureOnly). Distinguishes
        /// 'not attempted' from 'attempted and failed', which compileSucceeded alone cannot.
        /// Defaults true so debug packages captured before this field existed still read correctly.
        /// </summary>
        public bool compileAttempted { get; set; } = true;

        /// <summary>
        /// D3DCOMPILE_* flags used for this shader. Required to reproduce the compile offline.
        /// </summary>
        public uint compileFlags { get; set; }

        /// <summary>
        /// Macros where the game's ModifyCompilationEnvironment disagreed with one of our own rules.
        /// Our value was used; this records the disagreement so it stays visible.
        /// </summary>
        public MacroConflict[] macroConflicts { get; set; }

        /// <summary>
        /// Built in ShaderHost - preprocessor scan for all possible conditionally used macros. There might be a few more like number of lights.
        /// </summary>
        public string[] possibleMacros { get; set; }
    }

    public class MacroConflict
    {
        public string name { get; set; }
        public string milanValue { get; set; }
        public string engineValue { get; set; }
    }

    public class D3DMacro
    {
        public string name { get; set; }
        public string definition { get; set; }

        /// <summary>
        /// Where this macro came from: 'milan' for one of our own rules, 'engine' for the game's
        /// own ModifyCompilationEnvironment. Null on debug packages captured before this existed.
        /// </summary>
        public string source { get; set; }
    }
}
