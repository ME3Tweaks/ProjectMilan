using LegendaryExplorerCore.Packages;
using ProjectMilanCore.Config.Store;
using ProjectMilanCore.Utility;

namespace ProjectMilan.Pipelines.Store;

// Promo banner and its entitlement pack. Not available for unlocking via regular packs, used
// by Mod Manager. The packname_unlock must be set in MP Profile for the pack to become visible.
internal sealed record PromoBannerDefinition(MilanStorePackId PackId, string PackName, MilanPlayerVariable CounterId,
    MilanPlayerVariable UnlockId, MilanBannerId EmblemId, MilanPlayerVariable OwnershipId, LocalizedString Title, LocalizedString PackDescription,
    string BannerImage, string PackImage)
{
    public string UniqueName => $"MilanBanner_{PackName}";
    public StorePool Pool => new($"banner_{PackName}");
}

public static partial class StoreCards
{
    // PROMO BANNERS - Only unlock via external means
    private static readonly LocalizedString JedoreTitle = new() {
        [MELocalization.INT] = "Jedore over loudspeaker",
    };
    private static readonly LocalizedString JedorePackDescription = new() {
        [MELocalization.INT] = "Contains the Jedore over Loudspeaker banner, unlocked by having used ModMaker (classic) mods.",
    };
    private static readonly LocalizedString ME1RandomizerTitle = new() {
        [MELocalization.INT] = "Randomizer",
    };
    private static readonly LocalizedString ME1RandomizerPackDescription = new() {
        [MELocalization.INT] = "Contains the Randomizer banner, unlocked by having used ME1 Randomizer.",
    };
    private static readonly LocalizedString LE2RandomizerTitle = new() {
        [MELocalization.INT] = "Randomizer",
    };
    private static readonly LocalizedString LE2RandomizerPackDescription = new() {
        [MELocalization.INT] = "Contains the LE2 Randomizer banner, unlocked by having used LE2 Randomizer.",
    };
    private static readonly LocalizedString PinnacleTitle = new() {
        [MELocalization.INT] = "Pinnacle", // Spectre?
    };
    private static readonly LocalizedString PinnaclePackDescription = new() {
        [MELocalization.INT] = "Contains the Pinnacle banner, unlocked by completing Pinnacle Station in an LE1 final save.",
    };

    // Promo banners are marked as Rare border but not store rare
    internal static IReadOnlyList<PromoBannerDefinition> PromoBanners { get; } =
    [
        new(MilanStorePackId.Promo_Jedore, "promo_jedore", MilanPlayerVariable.PromoPack_Jedore, MilanPlayerVariable.PromoUnlock_Jedore,
            MilanBannerId.Promo_Jedore, MilanPlayerVariable.PromoBanner_Jedore, JedoreTitle, JedorePackDescription,
            "PromoBanners.Jedore", AchievementBannerDefinition.PlaceholderPackImage), // TODO pack artwork

        new(MilanStorePackId.Promo_ME1Randomizer, "promo_me1randomizer", MilanPlayerVariable.PromoPack_ME1Randomizer, MilanPlayerVariable.PromoUnlock_ME1Randomizer,
            MilanBannerId.Promo_ME1Randomizer, MilanPlayerVariable.PromoBanner_ME1Randomizer, ME1RandomizerTitle, ME1RandomizerPackDescription,
            "PromoBanners.ME1Randomizer", AchievementBannerDefinition.PlaceholderPackImage), // TODO pack artwork

        new(MilanStorePackId.Promo_LE2Randomizer, "promo_le2randomizer", MilanPlayerVariable.PromoPack_LE2Randomizer, MilanPlayerVariable.PromoUnlock_LE2Randomizer,
            MilanBannerId.Promo_LE2Randomizer, MilanPlayerVariable.PromoBanner_LE2Randomizer, LE2RandomizerTitle, LE2RandomizerPackDescription,
            "PromoBanners.LE2Randomizer", AchievementBannerDefinition.PlaceholderPackImage), // TODO pack artwork

        new(MilanStorePackId.Promo_Pinnacle, "promo_pinnacle", MilanPlayerVariable.PromoPack_Pinnacle, MilanPlayerVariable.PromoUnlock_Pinnacle,
            MilanBannerId.Promo_Pinnacle, MilanPlayerVariable.PromoBanner_Pinnacle, PinnacleTitle, PinnaclePackDescription,
            "PromoBanners.Pinnacle", AchievementBannerDefinition.PlaceholderPackImage), // TODO pack artwork
    ];

    private static IEnumerable<StoreCard> PromoBannerCards => PromoBanners.Select(b => Banner(b.EmblemId, b.UniqueName, b.OwnershipId, b.Title, b.BannerImage, CardRarity.Rare, b.Pool));
}
