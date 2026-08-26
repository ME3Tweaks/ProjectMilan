using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Pathing;

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
        public bool Enabled { get; set; } = true;

        /// <summary>
        /// Which function should run before porting the level - after default precorrections
        /// </summary>
        public Action<LevelSpecificPipeline> SpecialPrePortingDelegate { get; set; }

        /// <summary>
        /// Which function should run to port the level
        /// </summary>
        public Action<LevelSpecificPipeline, TieredPackageCache> SpecialPortingDelegate { get; set; }

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
        public TieredPackageCache Cache { get; set; }

        /// <summary>
        /// List of ME3 Export Entries that do not work in LE3
        /// </summary>
        public List<ExportEntry> MaterialsNeedingDonors { get; } = new();

        /// <summary>
        /// If all shadowmaps on the level should be stripped. This is useful for things like donor testing as shadowmaps in dev appear to be broken.
        /// </summary>
        public bool StripShadowMaps { get; set; }

        /// <summary>
        /// If this map supports lighting build. Vanilla SP maps don't use this
        /// </summary>
        public bool BuildLighting { get; set; } = true;
        
        /// <summary>
        /// List of level names to not include in a lighting bake. Some levels have unused sublevels that we include but don't want to corrupt our lighting with.
        /// </summary>
        public string[] IgnoredLightingLevels { get; set; }

        /// <summary>
        /// Gets the path that holds donors specific for this level
        /// </summary>
        /// <param name="pipeline"></param>
        /// <returns></returns>
        //public string GetDonorsPath()
        //{
        //    return Path.Combine(MilanShared.PipelineRoot, "Materials", "Build");
        //}

        //public string GetStagingTemporaryDonorPath()
        //{
        //    return Directory.CreateDirectory(Path.Combine(GetDonorsPath(), "Auto")).FullName;
        //}

        /// <summary>
        /// Removes all object references to release memory
        /// </summary>
        public void ClearReferences()
        {
            Cache?.Dispose();
            MaterialsNeedingDonors?.Clear();
            LE3Packages?.Clear();
            ME3Packages?.Clear();
            ME3BioP = null;
            LE3BioP = null;
        }
    }
}
