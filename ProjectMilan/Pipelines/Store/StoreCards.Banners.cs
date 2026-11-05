using LegendaryExplorerCore.Packages;
using ProjectMilanCore;
using ProjectMilanCore.Config.Store;
using ProjectMilanCore.Utility;

namespace ProjectMilan.Pipelines.Store;

public static partial class StoreCards
{
    private static readonly LocalizedString BarCrawlerTitle = new() { [MELocalization.INT] = "Bar Crawler" };
    private static readonly LocalizedString BerserkTitle = new() { [MELocalization.INT] = "Berserk" };
    private static readonly LocalizedString BustedTitle = new() { [MELocalization.INT] = "Busted" };
    private static readonly LocalizedString DiplomatTitle = new() { [MELocalization.INT] = "Diplomat" };
    private static readonly LocalizedString SunsetTitle = new() { [MELocalization.INT] = "Sunset" };
    private static readonly LocalizedString KeyartLE1Title = new() { [MELocalization.INT] = "Mass Effect" };
    private static readonly LocalizedString KeyartLE1AltTitle = new() { [MELocalization.INT] = "Mass Effect" };
    private static readonly LocalizedString KeyartLE2Title = new() { [MELocalization.INT] = "Mass Effect 2" };
    private static readonly LocalizedString CaretakerTitle = new() { [MELocalization.INT] = "Caretaker" };
    private static readonly LocalizedString ExplorerTitle = new() { [MELocalization.INT] = "Explorer" };
    private static readonly LocalizedString PathfinderTitle = new() { [MELocalization.INT] = "Pathfinder" };
    private static readonly LocalizedString TrailblazerTitle = new() { [MELocalization.INT] = "Trailblazer" };
    private static readonly LocalizedString UnknownTitle = new() { [MELocalization.INT] = "Unknown" };
    private static readonly LocalizedString LegendaryTitle = new() { [MELocalization.INT] = "Legendary" };
    private static readonly LocalizedString LegendaryAltTitle = new() { [MELocalization.INT] = "Legendary" };
    private static readonly LocalizedString TrilogyTitle = new() { [MELocalization.INT] = "Mass Effect Trilogy" };
    private static readonly LocalizedString ClubTitle = new() { [MELocalization.INT] = "Club" };
    private static readonly LocalizedString SFXTitle = new() { [MELocalization.INT] = "SFX" };
    private static readonly LocalizedString N7S1Title = new() { [MELocalization.INT] = "N7 Squad" };
    private static readonly LocalizedString MEMPTitle = new() { [MELocalization.INT] = "United Through Discord" };

    // Add custom milan banners here that have drops.
    private static IEnumerable<StoreCard> Banners =>
    [
        Banner(229, "MilanBanner_BarCrawler", 723, BarCrawlerTitle, "ChallengeBanners.BarCrawler", CardRarity.UltraRare),
        Banner(230, "MilanBanner_Berserk", 724, BerserkTitle, "ChallengeBanners.Berserk", CardRarity.Rare),
        Banner(231, "MilanBanner_Busted", 725, BustedTitle, "ChallengeBanners.Busted", CardRarity.Rare),
        Banner(232, "MilanBanner_Diplomat", 726, DiplomatTitle, "ChallengeBanners.Diplomat", CardRarity.Rare),
        Banner(233, "MilanBanner_Sunset", 727, SunsetTitle, "ChallengeBanners.Sunset", CardRarity.Uncommon),
        Banner(234, "MilanBanner_KeyartLE1", 728, KeyartLE1Title, "Keyart.KeyartLE1", CardRarity.Common, StorePools.CommonBanner, StorePools.StarterBanner),
        Banner(235, "MilanBanner_KeyartLE1_Alt", 729, KeyartLE1AltTitle, "Keyart.KeyartLE1_Alt", CardRarity.Rare),
        Banner(236, "MilanBanner_KeyartLE2", 730, KeyartLE2Title, "Keyart.KeyartLE2", CardRarity.Common, StorePools.CommonBanner, StorePools.StarterBanner),
        Banner(237, "MilanBanner_Caretaker", 731, CaretakerTitle, "Banners.Caretaker", CardRarity.Uncommon),
        Banner(238, "MilanBanner_Explorer", 732, ExplorerTitle, "Banners.Explorer", CardRarity.Uncommon),
        Banner(239, "MilanBanner_Pathfinder", 733, PathfinderTitle, "Banners.Pathfinder", CardRarity.Rare),
        Banner(240, "MilanBanner_Trailblazer", 734, TrailblazerTitle, "Banners.Trailblazer", CardRarity.Rare),
        Banner(241, "MilanBanner_Unknown", 735, UnknownTitle, "Banners.Unknown", CardRarity.Rare),
        // Only drops from the free Legendary Banner pack
        Banner(242, "MilanBanner_Legendary", 736, LegendaryTitle, "ChallengeBanners.Legendary", CardRarity.Rare, StorePools.LegendaryBanner),
        Banner(243, "MilanBanner_Legendary_Alt", 737, LegendaryAltTitle, "ChallengeBanners.Legendary_Alt", CardRarity.Rare),
        Banner(244, "MilanBanner_Trilogy", 738, TrilogyTitle, "KeyArt.Trilogy", CardRarity.Uncommon, StorePools.UncommonBanner, StorePools.StarterBanner),
        Banner(245, "MilanBanner_Club", 739, ClubTitle, "Banners.Club", CardRarity.Rare),
        Banner(246, "MilanBanner_SFX", 740, SFXTitle, "Banners.SFX", CardRarity.Rare),
        // N7 Squad
        Banner(247, "MilanBanner_N7S1", 741, N7S1Title, "Groups.N7S1", CardRarity.Uncommon, StorePools.UncommonBanner, StorePools.StarterBanner),
        // MEMP
        Banner(248, "MilanBanner_MEMP", 742, MEMPTitle, "Groups.MEMP", CardRarity.Uncommon, StorePools.UncommonBanner, StorePools.StarterBanner),
    ];

    public static StoreCard Banner(int emblemId, string uniqueName, int playerVariableId, int titleStrRefId,
        string image, CardRarity rarity, params StorePool[] pools) => new()
    {
        BannerID = emblemId,
        UniqueName = uniqueName,
        Kind = ReinforcementKind.PermanentUpgrade,
        Rarity = rarity,
        MaxCount = 1,
        GUIName = titleStrRefId,
        GUIType = "banner",
        GUITextureRef = image,
        PlayerVariableIds = [playerVariableId],
        Pools = (pools.Length == 0 ? [StorePools.BannerPool(rarity)] : pools).Select(p => new PoolEntry(p)).ToList(),
    };

    public static StoreCard Banner(int emblemId, string uniqueName, int playerVariableId, LocalizedString title,
        string image, CardRarity rarity, params StorePool[] pools) =>
        Banner(emblemId, uniqueName, playerVariableId, MilanPipelinesShared.AssignTLK(title), image, rarity, pools);
}
