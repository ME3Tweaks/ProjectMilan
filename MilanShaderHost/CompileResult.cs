using LegendaryExplorerCore.Unreal.BinaryConverters;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace MilanShaderHost
{
    public class CompileResult
    {
        /// <summary>
        /// The name of the compiled material
        /// </summary>
        public string MaterialName { get; set; }
    
        /// <summary>
        /// The shader cache for this specific material
        /// </summary>
        public ShaderCache Cache { get; set; }

        /// <summary>
        /// The material resource binary data
        /// </summary>
        public byte[] MaterialResource { get; internal set; }
    }
}
