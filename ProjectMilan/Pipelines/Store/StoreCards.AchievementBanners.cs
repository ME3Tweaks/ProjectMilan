using LegendaryExplorerCore.Packages;
using ProjectMilanCore.Config;
using ProjectMilanCore.Config.Store;
using ProjectMilanCore.Utility;

namespace ProjectMilan.Pipelines.Store;

// One declaration supplies both the reward card and its achievement-gated pack.
// All numeric IDs and keys are permanent. The seven pools are exclusive to these packs.
internal sealed record AchievementBannerDefinition(int PackId, string PackName, int CounterId, int AchievementId,
    int UnlockId, int EmblemId, int OwnershipId, string Title, string Image)
{
    public string UniqueName => $"MilanBanner_{PackName}";
    public StorePool Pool => new($"banner_{PackName}");
    public LocalizedString LocalizedTitle => new() { { MELocalization.INT, Title } };
}

public static partial class StoreCards
{
    // Rare is the reveal frame, not random availability: these never join generic rarity pools.
    internal static IReadOnlyList<AchievementBannerDefinition> AchievementBanners { get; } =
    [
        new(700, "ach_me1_medalofhonor", 702, LEAchievementIds.ME1_MedalOfHonor, 709, 222, 716,
            "Medal of Honor", "ChallengeBanners.Placeholder"), // TODO artwork
        new(701, "ach_me1_colonialsurvival", 703, LEAchievementIds.ME1_ColonialSurvival, 710, 223, 717,
            "Counterterrorist", "AchievementBanners.ColonialSavior"),
        new(702, "ach_me2_missionaccomplished", 704, LEAchievementIds.ME2_MissionAccomplished, 711, 224, 718,
            "Mission accomplished", "AchievementBanners.MissionAccomplishedLE2"),
        new(703, "ach_me2_merciless", 705, LEAchievementIds.ME2_Merciless, 712, 225, 719,
            "Bringer of pain", "ChallengeBanners.Placeholder"), // TODO artwork
        new(704, "ach_me3_missionaccomplished", 706, LEAchievementIds.ME3_MissionAccomplished, 713, 226, 720,
            "End of the world", "ChallengeBanners.Placeholder"), // TODO artwork
        new(705, "ach_me3_theoneandonly", 707, LEAchievementIds.ME3_TheOneAndOnly, 714, 227, 721,
            "The One and Only", "ChallengeBanners.Placeholder"), // TODO artwork
        new(706, "ach_insanityiii", 708, LEAchievementIds.Trilogy_InsanityIII, 715, 228, 722,
            "Insane", "ChallengeBanners.Placeholder"), // TODO artwork
    ];

    private static IEnumerable<StoreCard> AchievementBannerCards => AchievementBanners.Select(b =>
        Banner(b.EmblemId, b.UniqueName, b.OwnershipId, b.LocalizedTitle, b.Image, CardRarity.Rare, b.Pool));
}
