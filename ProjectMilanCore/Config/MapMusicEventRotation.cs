namespace ProjectMilanCore
{
    /// <summary>
    /// Assigns each newly-registered multiplayer map a music event, rotating through the fixed set the
    /// original maps used. Relocated verbatim (starting offset included) from the old per-DLC
    /// RedemptionShared.GetMusicEventName() so every map registration - main mod included - rotates the
    /// same way instead of needing per-map music data authored by hand.
    /// </summary>
    internal static class MapMusicEventRotation
    {
        private static int _musicEventNameIdx = 0; // Last official map is 'Nov2' which uses mpnov.

        /// <summary>
        /// List of music events to rotate through, in the same order the original maps used.
        /// </summary>
        private static readonly string[] MusicEvents =
        [
            "Set_mus_map_mpdish",
            "Set_mus_map_mpslum",
            "Set_mus_map_mptowr",
            "Set_mus_map_mpcer",
            "Set_mus_map_mprctr",
            "Set_mus_map_mpnov",
        ];

        internal static string GetNext()
        {
            return MusicEvents[_musicEventNameIdx++ % MusicEvents.Length];
        }
    }
}
