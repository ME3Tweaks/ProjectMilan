using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using LegendaryExplorerCore.Packages;

namespace ProjectMilan.Pipelines.Kits
{
    internal class KitSpecificPipeline
    {
        /// <summary>
        /// If this kit should be ported
        /// </summary>
        public bool Enabled { get; set; } = true;

        /// <summary>
        /// Base package that contains primary kit
        /// </summary>
        public string PackageName { get; set; }

        /// <summary>
        /// Logging category
        /// </summary>
        public string LogCategory { get; set; }

        /// <summary>
        /// Cache for this pipeline
        /// </summary>
        public PackageCache Cache { get; set; }
    }
}
