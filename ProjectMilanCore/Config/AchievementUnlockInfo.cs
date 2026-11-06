namespace ProjectMilanCore.Config
{
    /// <summary>
    /// Unlocks content (a store pack, later banners) when the player has a Legendary Edition achievement. The
    /// achievement is read once per session through Origin; the first time it's seen, <see cref="UnlockVariableName"/>
    /// is set to 1 so the unlock sticks even if Origin can't be reached later.
    /// </summary>
    public class AchievementUnlockInfo
    {
        /// <summary>
        /// EA achievement ID - see <see cref="LEAchievementIds"/>.
        /// </summary>
        public int AchievementId { get; set; }

        /// <summary>
        /// MUST BE UNIQUE: mpplayervariable that latches the unlock (ClassName in mpplayervariablemappings).
        /// </summary>
        public string UnlockVariableName { get; set; }

        /// <summary>
        /// mpplayervariablemappings ID for <see cref="UnlockVariableName"/>. Ends up in player saves, so it has to stay
        /// the same from build to build. Comes from the MilanPlayerVariable enum in ProjectMilan\Pipelines\Shared\MilanIds.cs.
        /// </summary>
        public int UnlockVariableId { get; set; }
    }

    /// <summary>
    /// EA achievement IDs. All three Legendary Edition games share one EA achievement set; each game's
    /// SFXProfileSettings.EAchievementID index maps to it as LE1 idx + 1 (EA 1-34), LE2 idx + 35 (EA 35-78),
    /// LE3 idx + 79 (EA 79-116). The trilogy achievements are EA 117-127 in every game.
    /// </summary>
    public static class LEAchievementIds
    {
        public const int ME1_MedalOfHonor = 1; // LE1 ACHIEVEMENT_00_HONORMEDAL
        public const int ME1_ColonialSurvival = 34; // LE1 ACHIEVEMENT_33_BRINGDOWNTHESKY
        public const int ME2_MissionAccomplished = 35; // LE2 ACHIEVEMENT_00_COMPLETE
        public const int ME2_Merciless = 64; // LE2 ACHIEVEMENT_29_SCREAM
        public const int ME3_MissionAccomplished = 96; // LE3 ACHIEVEMENT_17_END002 ("Legend" - "Mission accomplished.")
        public const int ME3_TheOneAndOnly = 116; // LE3 ACHIEVEMENT_37_DLC_CIT9
        public const int Trilogy_InsanityIII = 119; // ACHIEVEMENT_40_TRILOGY_INSANITYIII (LE3 numbering)
    }
}
