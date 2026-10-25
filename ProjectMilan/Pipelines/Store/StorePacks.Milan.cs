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
        TitleStrRefId = MilanPipelinesShared.AssignTLK(banner.LocalizedTitle),
        DescriptionStrRefId = MilanPipelinesShared.AssignTLK(new LocalizedString
        {
            { MELocalization.INT, $"Contains the {banner.Title} banner. Earned by completing its Legendary Edition achievement." }
        }),
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
        Image = banner.Image,
        RevealIntroTextureRef = "GUI_MPImages.Creates.Alliance",
        RevealIntroHoloTextureRef = "GUI_MPImages.Creates.AllianceHolo",
        RevealIntroSound = "MPRevealCrate1",
        Contents = [Slot(banner.Pool)],
    };

    // Evaluated during registration because titles/descriptions assign TLK entries.
    private static IReadOnlyList<StorePackEntry> GetMilanPacks() =>
        StoreCards.AchievementBanners.Select(AchievementPack).ToList();
}
