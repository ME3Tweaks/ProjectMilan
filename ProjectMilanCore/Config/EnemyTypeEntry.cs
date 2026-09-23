namespace ProjectMilanCore.Config
{
    /// <summary>
    /// A single entry in the multiplayer "Enemy" (faction) select list - the Random/Random Wave/Mixed meta
    /// options as well as the real per-faction (Cerberus, Geth, Reapers, Collectors, ...) options. Unlike
    /// <see cref="MapListEntry"/>, ID is not auto-assigned - these are a small, fixed set registered once
    /// from a single place, so there's no cross-stage collision risk to guard against.
    /// </summary>
    public class EnemyTypeEntry
    {
        /// <summary>
        /// Numeric ID this faction is selected by. Gaps are fine if an entry is ever disabled.
        /// </summary>
        public int ID { get; set; }

        /// <summary>
        /// TLK String ID of the faction's display name.
        /// </summary>
        public int NameStrRefId { get; set; }

        /// <summary>
        /// TLK String ID of the faction's all-caps display name.
        /// </summary>
        public int AllCapsNameStrRefId { get; set; }

        /// <summary>
        /// Map-select-UI image reference path, e.g. "GUI_MPImages_MP4.OptEmyCerberus"
        /// </summary>
        public string Image { get; set; }

        /// <summary>
        /// Wave coordinator class this faction spawns from, e.g.
        /// "SFXGameContentDLC_CON_MP4_Horde.SFXWave_Horde_Cerberus2". Empty for the meta options.
        /// </summary>
        public string WaveClass { get; set; }

        /// <summary>
        /// True for the "Random" meta options (faction/wave/enemy) - these aren't real factions.
        /// </summary>
        public bool IsRandomOption { get; set; }
    }
}
