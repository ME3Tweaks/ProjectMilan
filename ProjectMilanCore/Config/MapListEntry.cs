namespace ProjectMilanCore.Config
{
    /// <summary>
    /// Multiplayer map registration data, including map-select UI and optional gameplay features. Deliberately has no map ID or music
    /// event field - IDs are assigned automatically by <see cref="MapIdAllocator"/> and music events by
    /// <see cref="MapMusicEventRotation"/> when the entry is registered via
    /// <see cref="MapListConfigWriter.RegisterMap"/>, so levels can be freely reordered/added/removed
    /// without needing to hand-maintain either.
    /// </summary>
    public class MapListEntry
    {
        /// <summary>
        /// Map package name, e.g. "BioP_MPDish"
        /// </summary>
        public string PackageName { get; set; }

        /// <summary>
        /// Setting to true makes the level turn on flashlights for all player pawns
        /// </summary>
        public bool UseWeaponFlashlight { get; set; }

        /// <summary>
        /// TLK String ID of the map name
        /// </summary>
        public int PrettyNameStrRefId { get; set; }

        /// <summary>
        /// Null produces a blank Description= field, matching several existing map entries that never had one. This may be unused by the game
        /// </summary>
        public int? DescriptionStrRefId { get; set; }

        /// <summary>
        /// GAW Position X
        /// </summary>
        public int GAWMapPositionX { get; set; }


        /// <summary>
        /// GAW Position Y
        /// </summary>
        public int GAWMapPositionY { get; set; }

        /// <summary>
        /// GAW Map Subtitle TLK String ID - I think this is what galactic sector it lands in?
        /// </summary>
        public int GAWMapSubtitleStrRefId { get; set; }

        /// <summary>
        /// Map-select-UI image reference path, e.g. "GUI_MPImages.MatchSettings.OptMapDish"
        /// </summary>
        public string ImageObjectPath { get; set; }

        /// <summary>
        /// Seekfree package the image streams from, e.g. "SFXMPImagesMatchSettings"
        /// </summary>
        public string ImageSeekFreePackageName { get; set; }
    }
}
