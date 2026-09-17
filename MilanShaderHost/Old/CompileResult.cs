using LegendaryExplorerCore.Unreal.BinaryConverters;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace MilanShaderHost.Old
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

        /// <summary>
        /// True when <see cref="MaterialResource"/> contains a full native
        /// FTerrainMaterialResource rather than the base MaterialResource format.
        /// </summary>
        public bool IsTerrainResource { get; internal set; }

        /// <summary>
        /// Runtime full path of the terrain actor that owns a terrain resource. This is sent
        /// separately because terrain resources have no backing UMaterial export to identify them.
        /// </summary>
        public string TerrainPath { get; internal set; }
    }
}
