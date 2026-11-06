using LegendaryExplorerCore.Packages;
using ProjectMilanCore.Config;
using ProjectMilanCore.Config.Store;
using ProjectMilanCore.Utility;

namespace ProjectMilan.Pipelines.Store;

// Defines an acheivement banner, including its pack information.
// BannerImage is the 4:1 banner art
// PackImage is the pack's store background
internal sealed record AchievementBannerDefinition(MilanStorePackId PackId, string PackName, MilanPlayerVariable CounterId, int AchievementId,
    MilanPlayerVariable UnlockId, MilanBannerId EmblemId, MilanPlayerVariable OwnershipId, LocalizedString Title, LocalizedString PackDescription,
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
    private static readonly LocalizedString MissionAccomplishedTitle = new() { [MELocalization.INT] = "Mission Accomplished" };
    private static readonly LocalizedString MissionAccomplishedPackDescription = new() { [MELocalization.INT] = "Contains the Mission Accomplished (Mass Effect 2) banner. $49875828" };
    private static readonly LocalizedString MercilessTitle = new() { [MELocalization.INT] = "Merciless" };
    private static readonly LocalizedString MercilessPackDescription = new() { [MELocalization.INT] = "Contains the Merciless banner. $49875828" };
    private static readonly LocalizedString MissionAccomplishedLE3PackDescription = new() { [MELocalization.INT] = "Contains the Mission Accomplished (Mass Effect 3) banner. $49875828" };
    private static readonly LocalizedString TheOneAndOnlyTitle = new() { [MELocalization.INT] = "The One and Only" };
    private static readonly LocalizedString TheOneAndOnlyPackDescription = new() { [MELocalization.INT] = "Contains the The One and Only banner. $49875828" };
    private static readonly LocalizedString InsaneTitle = new() { [MELocalization.INT] = "Insane" };
    private static readonly LocalizedString InsanePackDescription = new() { [MELocalization.INT] = "Contains the Insane banner. $49875828" };

    // Rare is the reveal frame, not random availability: these never join generic rarity pools.
    internal static IReadOnlyList<AchievementBannerDefinition> AchievementBanners { get; } =
    [
        new(MilanStorePackId.Achievement_MedalOfHonor, "ach_me1_medalofhonor", MilanPlayerVariable.AchievementPack_MedalOfHonor, LEAchievementIds.ME1_MedalOfHonor,
            MilanPlayerVariable.AchievementUnlock_MedalOfHonor, MilanBannerId.Achievement_MedalOfHonor, MilanPlayerVariable.AchievementBanner_MedalOfHonor,
            MedalOfHonorTitle, MedalOfHonorPackDescription, "AchievementBanners.MedalOfHonor",
            AchievementBannerDefinition.PlaceholderPackImage), // TODO pack artwork

        new(MilanStorePackId.Achievement_ColonialSurvival, "ach_me1_colonialsurvival", MilanPlayerVariable.AchievementPack_ColonialSurvival, LEAchievementIds.ME1_ColonialSurvival,
            MilanPlayerVariable.AchievementUnlock_ColonialSurvival, MilanBannerId.Achievement_ColonialSurvival, MilanPlayerVariable.AchievementBanner_ColonialSurvival,
            ColonialSaviorTitle, ColonialSaviorPackDescription, "AchievementBanners.ColonialSavior",
            AchievementBannerDefinition.PlaceholderPackImage
            // When we do the full version PRC
            //"Packs.ColonialSurvivorBG"
            ),
        
        new(MilanStorePackId.Achievement_ME2MissionAccomplished, "ach_me2_missionaccomplished", MilanPlayerVariable.AchievementPack_ME2MissionAccomplished, LEAchievementIds.ME2_MissionAccomplished,
            MilanPlayerVariable.AchievementUnlock_ME2MissionAccomplished, MilanBannerId.Achievement_ME2MissionAccomplished, MilanPlayerVariable.AchievementBanner_ME2MissionAccomplished,
            MissionAccomplishedTitle, MissionAccomplishedPackDescription, "AchievementBanners.MissionAccomplishedLE2",
            AchievementBannerDefinition.PlaceholderPackImage), // TODO pack artwork
        
        new(MilanStorePackId.Achievement_Merciless, "ach_me2_merciless", MilanPlayerVariable.AchievementPack_Merciless, LEAchievementIds.ME2_Merciless,
            MilanPlayerVariable.AchievementUnlock_Merciless, MilanBannerId.Achievement_Merciless, MilanPlayerVariable.AchievementBanner_Merciless,
            MercilessTitle, MercilessPackDescription, "AchievementBanners.Merciless",
            AchievementBannerDefinition.PlaceholderPackImage), // TODO pack artwork
        
        new(MilanStorePackId.Achievement_ME3MissionAccomplished, "ach_me3_missionaccomplished", MilanPlayerVariable.AchievementPack_ME3MissionAccomplished, LEAchievementIds.ME3_MissionAccomplished,
            MilanPlayerVariable.AchievementUnlock_ME3MissionAccomplished, MilanBannerId.Achievement_ME3MissionAccomplished, MilanPlayerVariable.AchievementBanner_ME3MissionAccomplished,
            MissionAccomplishedTitle, MissionAccomplishedLE3PackDescription, "AchievementBanners.MissionAccomplishedLE3", 
            AchievementBannerDefinition.PlaceholderPackImage), // TODO pack artwork
        
        new(MilanStorePackId.Achievement_TheOneAndOnly, "ach_me3_theoneandonly", MilanPlayerVariable.AchievementPack_TheOneAndOnly, LEAchievementIds.ME3_TheOneAndOnly,
            MilanPlayerVariable.AchievementUnlock_TheOneAndOnly, MilanBannerId.Achievement_TheOneAndOnly, MilanPlayerVariable.AchievementBanner_TheOneAndOnly,
            TheOneAndOnlyTitle, TheOneAndOnlyPackDescription, "AchievementBanners.TheOneAndOnly", 
            AchievementBannerDefinition.PlaceholderPackImage), // TODO pack artwork
        
        new(MilanStorePackId.Achievement_InsanityIII, "ach_insanityiii", MilanPlayerVariable.AchievementPack_InsanityIII, LEAchievementIds.Trilogy_InsanityIII,
            MilanPlayerVariable.AchievementUnlock_InsanityIII, MilanBannerId.Achievement_InsanityIII, MilanPlayerVariable.AchievementBanner_InsanityIII,
            InsaneTitle, InsanePackDescription, "AchievementBanners.Insane", 
            AchievementBannerDefinition.PlaceholderPackImage), // TODO pack artwork
    ];

    private static IEnumerable<StoreCard> AchievementBannerCards => AchievementBanners.Select(b =>
        Banner(b.EmblemId, b.UniqueName, b.OwnershipId, b.Title, b.BannerImage, CardRarity.Rare, b.Pool));
}
