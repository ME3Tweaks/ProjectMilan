using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Pathing;
using ProjectMilanCore;
using ProjectMilanCore.Config;

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
        /// If this level must not be forced on by <see cref="Settings.IMilanSettings.ProductionBuild"/> (prototypes, broken maps)
        /// </summary>
        public bool ExcludeFromProduction { get; set; }

        /// <summary>
        /// If this level should be ported this run: <see cref="Enabled"/>, or forced on by a production build
        /// </summary>
        public bool ShouldBuild => Enabled || (Program.Settings.ProductionBuild && !ExcludeFromProduction);

        /// <summary>
        /// Map-select-UI registration data for this level, or null if it should not appear as a selectable
        /// multiplayer map (e.g. MPLobby, prototypes). Only registered via <see cref="MapListConfigWriter"/>
        /// when <see cref="ShouldBuild"/> is also true, so a disabled level never shows up in-game.
        /// </summary>
        public MapListEntry MapListInfo { get; set; }

        /// <summary>
        /// Which function should run before porting the level - after default precorrections
        /// </summary>
        public Action<LevelSpecificPipeline> SpecialPrePortingDelegate { get; set; }

        /// <summary>
        /// Which function should run after the level has been ported and saved - for fixing things that only exist after porting.
        /// Any LE3 package modified by this is saved afterwards.
        /// </summary>
        public Action<LevelSpecificPipeline> SpecialPostPortingDelegate { get; set; }

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
        /// How this level's static lighting is solved when UE4 Lightmass is available: forcing UE3, and
        /// look calibration. See <see cref="StaticLighting.UE4LightmassSettings"/>.
        /// </summary>
        public StaticLighting.UE4LightmassSettings UE4Lightmass { get; set; } = new();

        /// <summary>
        /// Overrides for the bake's world-level Lightmass settings (environment color, bounces). See
        /// <see cref="StaticLighting.WorldLightmassSettings"/>.
        /// </summary>
        public StaticLighting.WorldLightmassSettings WorldLightmass { get; set; } = new();

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
