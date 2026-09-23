using LegendaryExplorerCore.Packages;
using ProjectMilanCore.Utility;

namespace ProjectMilan_ExtraContent.Redemption.Levels.MapPack
{
    /// <summary>
    /// Change-manifest data models shared between RedemptionMapTool (which produces the JSON under
    /// Redemption\Levels\MapPack\ChangeManifests by inspecting the original ME3 mod files) and MPMapPackBuild
    /// (which consumes that JSON to rebuild the maps for LE3). Kept here, in the consuming project, so both
    /// sides serialize/deserialize against the exact same types instead of two hand-synced copies.
    /// </summary>
    public sealed class MapManifest
    {
        public string MasterPackage { get; set; } = "";
        public string SourceFile { get; set; } = "";

        /// <summary>
        /// BioWorldInfo.KillZ from the master - the level master built for this map needs this value applied.
        /// </summary>
        public float KillZ { get; set; }
        public List<string> Sublevels { get; set; } = [];
        public List<StartLocationEntry> StartLocations { get; set; } = [];
        public List<SublevelManifest> SublevelData { get; set; } = [];

        /// <summary>
        /// Map-select-UI display text (name/description/GAW subtitle), resolved from the original mod's
        /// Default_DLC_MOD_MPMapPack.bin mastermaplist entry and its own TLK files. Null if this master has
        /// no mastermaplist entry at all (several of the prototype/test maps were never added to the
        /// original mod's selectable map list either).
        /// </summary>
        public MapDisplayInfo? DisplayInfo { get; set; }
    }

    public sealed class MapDisplayInfo
    {
        public float GAWMapPositionX { get; set; }
        public float GAWMapPositionY { get; set; }

        /// <summary>
        /// Map-select-UI image reference path, e.g. "GUI_MPImages.MatchSettings.OptMapAxWingman".
        /// </summary>
        public string Image { get; set; } = "";

        /// <summary>
        /// The map's display name, resolved per language from the original mod's own TLK files.
        /// </summary>
        public LocalizedString PrettyName { get; set; } = new();
        public LocalizedString Description { get; set; } = new();
        public LocalizedString GAWMapSubtitle { get; set; } = new();
    }

    public sealed class StartLocationEntry
    {
        public int Index { get; set; }
        public VectorDto Location { get; set; } = new();
        public RotatorDto Rotation { get; set; } = new();
    }

    public sealed class SublevelManifest
    {
        public string PackageName { get; set; } = "";
        public string SourceFile { get; set; } = "";
        public List<ObjectiveSpawnPointEntry> ObjectiveSpawnPoints { get; set; } = [];
        public List<TriggerVolumeEntry> TriggerVolumes { get; set; } = [];
        public List<EnemySpawnPointEntry> EnemySpawnPoints { get; set; } = [];
    }

    public sealed class EnemySpawnPointEntry
    {
        /// <summary>
        /// Full instanced path within the package, e.g. "TheWorld.PersistentLevel.SFXEnemySpawnPoint_3".
        /// Object names/indices aren't consistent between the OT and LE versions of a level, so this is
        /// only useful for identifying this specific instance within THIS file, not for cross-game matching.
        /// </summary>
        public string ObjectName { get; set; } = "";
        public VectorDto Location { get; set; } = new();
        public RotatorDto Rotation { get; set; } = new();

        /// <summary>
        /// Every other own property override present on this instance (Tag, Weight, SupportedReachSpecs,
        /// SupportedCustomActions, etc.), generically converted. A referenced sub-object owned by this actor
        /// (e.g. its CylinderComponent, which is where a resized collision cylinder actually lives) is inlined
        /// as a nested object rather than just a name, since per-instance edits like "size of cylinder" live there.
        /// </summary>
        public Dictionary<string, object?> Properties { get; set; } = new();
    }

    public sealed class ObjectiveSpawnPointEntry
    {
        public string Tag { get; set; } = "";
        public List<string> SupportedSpawnTags { get; set; } = [];

        /// <summary>
        /// EObjectiveLocation enum member name (e.g. EObjectiveLocation_Table/_Floor) - not a coordinate.
        /// </summary>
        public string SpawnLocation { get; set; } = "";
        public VectorDto Location { get; set; } = new();
        public RotatorDto Rotation { get; set; } = new();
    }

    public sealed class TriggerVolumeEntry
    {
        public string Tag { get; set; } = "";
        public int LocationNameStrref { get; set; }
        public VectorDto Location { get; set; } = new();
        public RotatorDto Rotation { get; set; } = new();
        public VectorDto DrawScale3D { get; set; } = new();
    }

    public sealed class VectorDto
    {
        public float X { get; set; }
        public float Y { get; set; }
        public float Z { get; set; }
    }

    public sealed class RotatorDto
    {
        public int Pitch { get; set; }
        public int Yaw { get; set; }
        public int Roll { get; set; }
    }
}
