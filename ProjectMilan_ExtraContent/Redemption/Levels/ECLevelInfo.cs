using System;
using System.Collections.Generic;
using System.Linq;
using System.Numerics;
using System.Text;
using System.Threading.Tasks;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Unreal;

namespace ProjectMilan_ExtraContent.Redemption.Levels
{

    public static class ECLevelInfos
    {
        // Redemption maps
    }

    /// <summary>
    /// Contains information specific to each level
    /// </summary>
    public class ECLevelInfo
    {
        // CONFIG DATA -----------------------------------
        /// <summary>
        /// Map name, starting with BioP_MP
        /// </summary>
        public string MapName { get; set; }

        /// <summary>
        /// UI-display string
        /// </summary>
        public Dictionary<MELocalization, string> LevelNameString { get; set; }

        /// <summary>
        /// UI-display string for level description (TODO: FIGURE OUT WHAT THIS ACTUALLY MEANT IN OT)
        /// </summary>
        public Dictionary<MELocalization, string> LevelDescriptionString { get; set; }

        // Image is set automatically based on map name

        /// <summary>
        /// Coordinates 0-500 (I think) of where the level is on the galaxy map
        /// </summary>
        public Vector2 GAWMapPosition { get; set; }

        /// <summary>
        /// UI-display string for GAW location (TODO: FIGURE OUT WHAT THIS ACTUALLY MEANT IN OT)
        /// </summary>
        public Dictionary<MELocalization, string> GAWMapSubtitle { get; set; }

        // MusicEventName is automatically set in-order of level assignment

        // PIPELINE DATA ---------------------------------------
        /// <summary>
        /// List of level files that compose this map (source). Do not include the new BioP we will be generating. Maps the source name to the name we will use
        /// </summary>
        public Dictionary<string,string> LevelFilesMap { get; set; }

        /// <summary>
        /// Additional objects for putting into BioP - used for imports in lower levels
        /// </summary>
        public string[] ExtraBioPObjects { get; set; }

        /// <summary>
        /// Where the initial player start should be placed. The other 3 positions will be automatically chosen nearby.
        /// </summary>
        public Vector3 StartLocation { get; set; }

        /// <summary>
        /// If level is selected for build
        /// </summary>
        public bool Enabled { get; set; }

        public string LogCategory => $"MILANEC-REDEMPTION-{RedemptionShared.GetMapBaseName(MapName).ToUpper()}";
        
        /// <summary>
        /// Cache to use during run. Will be automatically set
        /// </summary>
        public TieredPackageCache Cache { get; set; }

        /// <summary>
        /// Level specific subfolder
        /// </summary>
        public string OutputPath { get; set; }

        /// <summary>
        /// Maps source to destination packages
        /// </summary>
        public Dictionary<IMEPackage, IMEPackage> CrossPackageMapping { get; set; }

        /// <summary>
        /// Master persistent level file
        /// </summary>
        public IMEPackage BioP { get; set; }

        /// <summary>
        /// Level KillZ - camera and player cannot go below this without respawn, NPCs die below this
        /// </summary>
        public float KillZ { get; set; }

        public void Cleanup()
        {
            Cache.Dispose();
            Cache = null;
            CrossPackageMapping.Clear();
            BioP = null;
        }
    }
}
