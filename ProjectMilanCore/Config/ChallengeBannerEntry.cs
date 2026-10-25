namespace ProjectMilanCore.Config
{
    /// <summary>
    /// A single challenge banner ("emblem") shown behind a player's name in the lobby - an SFXPRIMP EmblemList
    /// entry. ID is not auto-assigned: it's what challenge rewards and player saves refer to the banner by, so it
    /// has to stay the same from build to build.
    /// </summary>
    public class ChallengeBannerEntry
    {
        /// <summary>
        /// Emblem ID. Vanilla uses 100-157 and 206-220.
        /// </summary>
        public int ID { get; set; }

        /// <summary>
        /// TLK String ID of the title shown with the banner.
        /// </summary>
        public int TitleStrRefId { get; set; }

        /// <summary>
        /// Banner image object path, e.g. "GUI_MPImages_SMP.Challenge.SoloMstr". Must be dynamic load mapped.
        /// </summary>
        public string BackgroundResource { get; set; }

        /// <summary>
        /// Info for how to unlock a banner. If none is provided, the banner can't be unlocked through normal means.
        /// </summary>
        public AchievementUnlockInfo UnlockInfo { get; set; }
    }
}
