using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Unreal.BinaryConverters;

namespace ProjectMilan.Pipelines.Levels
{
    public class LevelSpecificPipeline
    {
        /// <summary>
        /// If the result of this pipeline is an SP map
        /// </summary>
        public bool IsSP { get; set; }

        /// <summary>
        /// Name of the persistent level package, without extension
        /// </summary>
        public string BioP { get; set; }

        /// <summary>
        /// If level is marked for porting
        /// </summary>
        public bool Enabled { get; set; }

        /// <summary>
        /// Which function should run before porting the level - after default precorrections
        /// </summary>
        public Action<LevelSpecificPipeline> SpecialPrePortingDelegate { get; set; }

        /// <summary>
        /// Which function should run to port the level
        /// </summary>
        public Action SpecialPortingDelegate { get; set; }

        /// <summary>
        /// Map of filename -> loaded ME3 packages
        /// </summary>
        public Dictionary<string, IMEPackage> ME3Packages { get; } = new();

        /// <summary>
        /// Map of filename -> loaded LE3 packages
        /// </summary>
        public Dictionary<string, IMEPackage> LE3Packages { get; } = new();

        /// <summary>
        /// ME3 Persistent Package for level
        /// </summary>
        public IMEPackage ME3BioP { get; set; }

        /// <summary>
        /// LE3 Persistent Package for level
        /// </summary>
        public IMEPackage LE3BioP { get; set; }

        /// <summary>
        /// Where to place SP start location - for early debugging only
        /// </summary>

        public Point3D SPStartLocation { get; set; }

        /// <summary>
        /// Logging category
        /// </summary>
        public string LogCategory { get; set; }

        /// <summary>
        /// Level output directory
        /// </summary>

        public string LevelOutputDir => Path.Combine(Program.Settings.OutputModPath, @"CookedPCConsole", @"Levels", BioP);

        /// <summary>
        /// Pipeline package cache
        /// </summary>
        public PackageCache Cache { get; set; }

        /// <summary>
        /// Gets the path that holds donors specific for this level
        /// </summary>
        /// <param name="pipeline"></param>
        /// <returns></returns>
        public string GetTemporaryDonorPath()
        {
            return Path.Combine(MilanShared.PipelineRoot, "Levels", BioP, "Donors");
        }

    }
}
