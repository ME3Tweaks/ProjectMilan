using LegendaryExplorerCore.Packages;
using ProjectMilanCore.Config;
using ProjectMilanCore.Config.Store;
using ProjectMilanCore.Utility;

namespace ProjectMilan.Pipelines.Store;

// Defines an acheivement banner, including its pack information.
// BannerImage is the 4:1 banner art
// PackImage is the pack's store background
internal sealed record AchievementBannerDefinition(int PackId, string PackName, int CounterId, int AchievementId,
    int UnlockId, int EmblemId, int OwnershipId, LocalizedString Title, LocalizedString PackDescription,
    string BannerImage, string PackImage)
{
    /// <summary>
    /// Store background for achievement packs that don't have their own art yet
    /// </summary>
    public const string PlaceholderPackImage = "GUI_MPImages.StoreItems.Store002";

    public string UniqueName => $"MilanBanner_{PackName}";
    public StorePool Pool => new($"banner_{PackName}");
}

public static partial class StoreCards
{
    // These must stay above AchievementBanners: static initializers in this file run in order.
    private static readonly LocalizedString MedalOfHonorTitle = new() { [MELocalization.INT] = "Medal of Honor" };

    // The $49875828 value is "Earned by obtaining the Legendary Edition acheivement."
    private static readonly LocalizedString MedalOfHonorPackDescription = new() { [MELocalization.INT] = "Contains the Medal of Honor banner. $49875828" };
    private static readonly LocalizedString ColonialSaviorTitle = new() { 
        [MELocalization.INT] = "Colonial Savior"
    };

    private static readonly LocalizedString ColonialSaviorPackDescription = new() { [MELocalization.INT] = "Contains the Colonial Savior banner. $49875828" };
    private static readonly LocalizedString MissionAccomplishedTitle = new() { [MELocalization.INT] = "Mission accomplished" };
    private static readonly LocalizedString MissionAccomplishedPackDescription = new() { [MELocalization.INT] = "Contains the Mission accomplished banner. $49875828" };
    private static readonly LocalizedString BringerOfPainTitle = new() { [MELocalization.INT] = "Bringer of pain" };
    private static readonly LocalizedString BringerOfPainPackDescription = new() { [MELocalization.INT] = "Contains the Bringer of pain banner. $49875828" };
    private static readonly LocalizedString EndOfTheWorldTitle = new() { [MELocalization.INT] = "End of the world" };
    private static readonly LocalizedString EndOfTheWorldPackDescription = new() { [MELocalization.INT] = "Contains the End of the world banner. $49875828" };
    private static readonly LocalizedString TheOneAndOnlyTitle = new() { [MELocalization.INT] = "The One and Only" };
    private static readonly LocalizedString TheOneAndOnlyPackDescription = new() { [MELocalization.INT] = "Contains the The One and Only banner. $49875828" };
    private static readonly LocalizedString InsaneTitle = new() { [MELocalization.INT] = "Insane" };
    private static readonly LocalizedString InsanePackDescription = new() { [MELocalization.INT] = "Contains the Insane banner. $49875828" };

    // Rare is the reveal frame, not random availability: these never join generic rarity pools.
    internal static IReadOnlyList<AchievementBannerDefinition> AchievementBanners { get; } =
    [
        new(700, "ach_me1_medalofhonor", 702, LEAchievementIds.ME1_MedalOfHonor, 709, 222, 716,
            MedalOfHonorTitle, MedalOfHonorPackDescription, "ChallengeBanners.Placeholder", // TODO artwork
            AchievementBannerDefinition.PlaceholderPackImage), // TODO pack artwork

        new(701, "ach_me1_colonialsurvival", 703, LEAchievementIds.ME1_ColonialSurvival, 710, 223, 717,
            ColonialSaviorTitle, ColonialSaviorPackDescription, "AchievementBanners.ColonialSavior",
            "Packs.ColonialSurvivorBG"),
        
        new(702, "ach_me2_missionaccomplished", 704, LEAchievementIds.ME2_MissionAccomplished, 711, 224, 718,
            MissionAccomplishedTitle, MissionAccomplishedPackDescription, "AchievementBanners.MissionAccomplishedLE2",
            AchievementBannerDefinition.PlaceholderPackImage), // TODO pack artwork
        
        new(703, "ach_me2_merciless", 705, LEAchievementIds.ME2_Merciless, 712, 225, 719,
            BringerOfPainTitle, BringerOfPainPackDescription, "ChallengeBanners.Placeholder", // TODO artwork
            AchievementBannerDefinition.PlaceholderPackImage), // TODO pack artwork
        
        new(704, "ach_me3_missionaccomplished", 706, LEAchievementIds.ME3_MissionAccomplished, 713, 226, 720,
            EndOfTheWorldTitle, EndOfTheWorldPackDescription, "ChallengeBanners.Placeholder", // TODO artwork
            AchievementBannerDefinition.PlaceholderPackImage), // TODO pack artwork
        
        new(705, "ach_me3_theoneandonly", 707, LEAchievementIds.ME3_TheOneAndOnly, 714, 227, 721,
            TheOneAndOnlyTitle, TheOneAndOnlyPackDescription, "ChallengeBanners.Placeholder", // TODO artwork
            AchievementBannerDefinition.PlaceholderPackImage), // TODO pack artwork
        
        new(706, "ach_insanityiii", 708, LEAchievementIds.Trilogy_InsanityIII, 715, 228, 722,
            InsaneTitle, InsanePackDescription, "ChallengeBanners.Placeholder", // TODO artwork
            AchievementBannerDefinition.PlaceholderPackImage), // TODO pack artwork
    ];

    private static IEnumerable<StoreCard> AchievementBannerCards => AchievementBanners.Select(b =>
        Banner(b.EmblemId, b.UniqueName, b.OwnershipId, b.Title, b.BannerImage, CardRarity.Rare, b.Pool));
}
