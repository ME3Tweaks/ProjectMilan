using LegendaryExplorerCore.Coalesced;

namespace ProjectMilanCore
{
    /// <summary>
    /// Writes a multiplayer map's map-select-UI registration (icon, availablemaps, mastermaplist) into
    /// whichever <see cref="MilanPipelinesShared.ConfigBundle"/> is currently active. Used by both
    /// ProjectMilan's own levels and ProjectMilan_ExtraContent's ported levels - the caller never needs to
    /// know or care which project it's running in, or which output file that ends up being, since
    /// <see cref="MilanPipelinesShared.ConfigBundle"/>/<see cref="MilanPipelinesShared.OutputModPath"/>
    /// already point at the right place by the time this is called.
    /// </summary>
    public static class MapListConfigWriter
    {
        /// <summary>
        /// Registers a map for use in the final build
        /// </summary>
        /// <param name="entry"></param>
        public static void RegisterMap(MapListEntry entry)
        {
            var mapId = MapIdAllocator.AllocateNext();

            var engine = MilanPipelinesShared.ConfigBundle.GetAsset("BioEngine");
            engine.GetOrAddSection("sfxgame.sfxengine").AddEntry(new CoalesceProperty("dynamicloadmapping",
                new CoalesceValue($"(ObjectName=\"{entry.ImageObjectPath}\", SeekFreePackageName=\"{entry.ImageSeekFreePackageName}\")", CoalesceParseAction.AddUnique)));

            var game = MilanPipelinesShared.ConfigBundle.GetAsset("BioGame");
            var onlinegamesettings = game.GetOrAddSection("sfxonlinefoundation.sfxonlinegamesettings");
            onlinegamesettings.AddEntry(new CoalesceProperty("availablemaps", new CoalesceValue(entry.PackageName, CoalesceParseAction.AddUnique)));
            onlinegamesettings.AddEntry(new CoalesceProperty("mastermaplist", new CoalesceValue(BuildMasterMapEntry(mapId, entry), CoalesceParseAction.AddUnique)));
        }

        private static string BuildMasterMapEntry(int mapId, MapListEntry entry)
        {
            return $"(ID={mapId}, " +
                   $"PackageName=\"{entry.PackageName}\", " +
                   $"PrettyName={entry.PrettyNameStrRefId}, " +
                   $"Description={entry.DescriptionStrRefId?.ToString() ?? ""}, " +
                   $"Image=\"{entry.ImageObjectPath}\", " +
                   $"GalaxyAtWarMapPosition=(X={entry.GAWMapPositionX},Y={entry.GAWMapPositionY}), " +
                   $"GalaxyAtWarMapSubtitle={entry.GAWMapSubtitleStrRefId}, " +
                   $"MusicEventName=\"{MapMusicEventRotation.GetNext()}\")";
        }
    }
}
