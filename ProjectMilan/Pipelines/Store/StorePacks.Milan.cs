using LegendaryExplorerCore.Packages;
using ProjectMilanCore;
using ProjectMilanCore.Config;
using ProjectMilanCore.Utility;

namespace ProjectMilan.Pipelines.Store;

public static partial class StorePacks
{
    /// <summary>Free, one-per-player achievement reward containing exactly its associated banner.</summary>
    private static StorePackEntry AchievementPack(AchievementBannerDefinition banner) => new()
    {
        ID = banner.PackId,
        PackName = banner.PackName,
        TitleStrRefId = MilanPipelinesShared.AssignTLK(banner.Title),
        DescriptionStrRefId = MilanPipelinesShared.AssignTLK(banner.PackDescription),
        CreditCost = 0,
        PromoStrRefId = 703324,
        PerPlayerMax = 1,
        PlayerVariableId = banner.CounterId,
        UnlockInfo = new AchievementUnlockInfo
        {
            AchievementId = banner.AchievementId,
            UnlockVariableName = $"{banner.PackName}_unlock",
            UnlockVariableId = banner.UnlockId,
        },
        BannerRewardID = banner.EmblemId,
        Image = banner.PackImage,
        RevealIntroTextureRef = "GUI_MPImages.Creates.Alliance",
        RevealIntroHoloTextureRef = "GUI_MPImages.Creates.AllianceHolo",
        RevealIntroSound = "MPRevealCrate1",
        Contents = [Slot(banner.Pool)],
    };

    private static readonly LocalizedString LegendaryBannerPackTitle = new() { 
        [MELocalization.INT] = "Legendary Pack" 
    };

    private static readonly LocalizedString LegendaryBannerPackDescription = new() { 
        [MELocalization.INT] = "A legendary banner for legendary defenders of the galaxy." 
    };

    /// <summary>
    /// Free, one-per-player pack available from the start, containing only the Legendary banner.
    /// </summary>
    private static StorePackEntry LegendaryBannerPack() => new()
    {
        ID = 707,
        PackName = "legendarybanner",
        TitleStrRefId = MilanPipelinesShared.AssignTLK(LegendaryBannerPackTitle),
        DescriptionStrRefId = MilanPipelinesShared.AssignTLK(LegendaryBannerPackDescription),
        CreditCost = 0,
        PromoStrRefId = 703324,
        PerPlayerMax = 1,
        PlayerVariableId = 742,
        BannerRewardID = 242,
        Image = "Packs.LegendaryBG", // Needs an appropriate background image!
        RevealIntroTextureRef = "GUI_MPImages.Creates.box",
        RevealIntroHoloTextureRef = "GUI_MPImages.Creates.boxHolo",
        RevealIntroSound = "MPRevealCrate1",
        Contents = [Slot(StorePools.LegendaryBanner)],
    };

    // Evaluated during registration because titles/descriptions assign TLK entries.
    private static IReadOnlyList<StorePackEntry> GetMilanPacks() => StoreCards.AchievementBanners.Select(AchievementPack).Append(LegendaryBannerPack()).ToList();
}
