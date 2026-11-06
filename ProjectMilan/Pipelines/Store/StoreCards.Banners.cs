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
    private static readonly LocalizedString ClubTitle = new() { [MELocalization.INT] = "Neon" };
    private static readonly LocalizedString SFXTitle = new() { [MELocalization.INT] = "SFX" };
    private static readonly LocalizedString N7S1Title = new() { [MELocalization.INT] = "N7 Squad" };
    private static readonly LocalizedString MEMTitle = new() { [MELocalization.INT] = "Mass Effect Modding" };
    private static readonly LocalizedString ME3TweaksTitle = new() { [MELocalization.INT] = "ME3Tweaks" };
    private static readonly LocalizedString MEMPTitle = new() { [MELocalization.INT] = "United Through Discord" };
    private static readonly LocalizedString DAArlathanGloryTitle = new() { [MELocalization.INT] = "Glory of Arlathan" };
    private static readonly LocalizedString DAArlathanRitualTitle = new() { [MELocalization.INT] = "The Ritual" };
    private static readonly LocalizedString DAFromTrickleToFloodTitle = new() { [MELocalization.INT] = "From a Trickle to a Flood" };
    private static readonly LocalizedString DATheDeepRoadsTitle = new() { [MELocalization.INT] = "The Deep Roads" };
    // private static readonly LocalizedString DATheLastStraw1Title = new() { [MELocalization.INT] = "The Last Straw" };
    private static readonly LocalizedString DATheLastStraw2Title = new() { [MELocalization.INT] = "The Last Straw" };
    private static readonly LocalizedString DATheWrathOfHeavenTitle = new() { [MELocalization.INT] = "The Wrath of Heaven" };
    private static readonly LocalizedString SaveMassEffectTitle = new() { [MELocalization.INT] = "Save Mass Effect" };
    private static readonly LocalizedString DATrespasserTitle = new() { [MELocalization.INT] = "Trespasser" };

    // Add custom milan banners here that have drops.
    private static IEnumerable<StoreCard> Banners =>
    [
        Banner(MilanBannerId.BarCrawler, "MilanBanner_BarCrawler", MilanPlayerVariable.Banner_BarCrawler, BarCrawlerTitle, "ChallengeBanners.BarCrawler", CardRarity.UltraRare),
        Banner(MilanBannerId.Berserk, "MilanBanner_Berserk", MilanPlayerVariable.Banner_Berserk, BerserkTitle, "ChallengeBanners.Berserk", CardRarity.Rare),
        Banner(MilanBannerId.Busted, "MilanBanner_Busted", MilanPlayerVariable.Banner_Busted, BustedTitle, "ChallengeBanners.Busted", CardRarity.Rare),
        Banner(MilanBannerId.Diplomat, "MilanBanner_Diplomat", MilanPlayerVariable.Banner_Diplomat, DiplomatTitle, "ChallengeBanners.Diplomat", CardRarity.Rare),
        Banner(MilanBannerId.Sunset, "MilanBanner_Sunset", MilanPlayerVariable.Banner_Sunset, SunsetTitle, "ChallengeBanners.Sunset", CardRarity.Uncommon),
        Banner(MilanBannerId.KeyartLE1, "MilanBanner_KeyartLE1", MilanPlayerVariable.Banner_KeyartLE1, KeyartLE1Title, "Keyart.KeyartLE1", CardRarity.Common, StorePools.CommonBanner, StorePools.StarterBanner),
        Banner(MilanBannerId.KeyartLE1_Alt, "MilanBanner_KeyartLE1_Alt", MilanPlayerVariable.Banner_KeyartLE1_Alt, KeyartLE1AltTitle, "Keyart.KeyartLE1_Alt", CardRarity.Rare),
        Banner(MilanBannerId.KeyartLE2, "MilanBanner_KeyartLE2", MilanPlayerVariable.Banner_KeyartLE2, KeyartLE2Title, "Keyart.KeyartLE2", CardRarity.Common, StorePools.CommonBanner, StorePools.StarterBanner),
        Banner(MilanBannerId.Caretaker, "MilanBanner_Caretaker", MilanPlayerVariable.Banner_Caretaker, CaretakerTitle, "Banners.Caretaker", CardRarity.Uncommon),
        Banner(MilanBannerId.Explorer, "MilanBanner_Explorer", MilanPlayerVariable.Banner_Explorer, ExplorerTitle, "Banners.Explorer", CardRarity.Uncommon),
        Banner(MilanBannerId.Pathfinder, "MilanBanner_Pathfinder", MilanPlayerVariable.Banner_Pathfinder, PathfinderTitle, "Banners.Pathfinder", CardRarity.Rare),
        Banner(MilanBannerId.Trailblazer, "MilanBanner_Trailblazer", MilanPlayerVariable.Banner_Trailblazer, TrailblazerTitle, "Banners.Trailblazer", CardRarity.Rare),
        Banner(MilanBannerId.Unknown, "MilanBanner_Unknown", MilanPlayerVariable.Banner_Unknown, UnknownTitle, "Banners.Unknown", CardRarity.Rare),
        // Only drops from the free Legendary Banner pack
        Banner(MilanBannerId.Legendary, "MilanBanner_Legendary", MilanPlayerVariable.Banner_Legendary, LegendaryTitle, "ChallengeBanners.Legendary", CardRarity.Rare, StorePools.LegendaryBanner),
        Banner(MilanBannerId.Legendary_Alt, "MilanBanner_Legendary_Alt", MilanPlayerVariable.Banner_Legendary_Alt, LegendaryAltTitle, "ChallengeBanners.Legendary_Alt", CardRarity.Rare),
        Banner(MilanBannerId.Trilogy, "MilanBanner_Trilogy", MilanPlayerVariable.Banner_Trilogy, TrilogyTitle, "KeyArt.Trilogy", CardRarity.Uncommon, StorePools.UncommonBanner, StorePools.StarterBanner),
        Banner(MilanBannerId.Club, "MilanBanner_Club", MilanPlayerVariable.Banner_Club, ClubTitle, "Banners.Club", CardRarity.Rare),
        Banner(MilanBannerId.SFX, "MilanBanner_SFX", MilanPlayerVariable.Banner_SFX, SFXTitle, "Banners.SFX", CardRarity.Rare),
        // N7 Squad
        Banner(MilanBannerId.N7S1, "MilanBanner_N7S1", MilanPlayerVariable.Banner_N7S1, N7S1Title, "Groups.N7S1", CardRarity.Uncommon, StorePools.UncommonBanner, StorePools.StarterBanner),
        // MEMP
        Banner(MilanBannerId.MEMP, "MilanBanner_MEMP", MilanPlayerVariable.Banner_MEMP, MEMPTitle, "Groups.MEMP", CardRarity.Uncommon, StorePools.UncommonBanner, StorePools.StarterBanner),
        // MEM
        Banner(MilanBannerId.MassEffectModding, "MilanBanner_MEM", MilanPlayerVariable.Banner_MassEffectModding, MEMTitle, "Groups.MEM", CardRarity.Uncommon, StorePools.UncommonBanner, StorePools.StarterBanner),
        // ME3Tweaks
        Banner(MilanBannerId.ME3Tweaks, "MilanBanner_ME3Tweaks", MilanPlayerVariable.Banner_ME3Tweaks, ME3TweaksTitle, "Groups.ME3Tweaks", CardRarity.Uncommon, StorePools.UncommonBanner, StorePools.StarterBanner),

        // Dragon Age
        Banner(MilanBannerId.DA_ArlathanGlory, "MilanBanner_DA_ArlathanGlory", MilanPlayerVariable.Banner_DA_ArlathanGlory, DAArlathanGloryTitle, "ThedasBanners.ArlathanGlory", CardRarity.Rare, StorePools.RareBanner, StorePools.DragonAgeBanner),
        Banner(MilanBannerId.DA_ArlathanRitual, "MilanBanner_DA_ArlathanRitual", MilanPlayerVariable.Banner_DA_ArlathanRitual, DAArlathanRitualTitle, "ThedasBanners.ArlathanRitual", CardRarity.Rare, StorePools.RareBanner, StorePools.DragonAgeBanner),
        Banner(MilanBannerId.DA_FromTrickleToFlood, "MilanBanner_DA_FromTrickleToFlood", MilanPlayerVariable.Banner_DA_FromTrickleToFlood, DAFromTrickleToFloodTitle, "ThedasBanners.FromTrickleToFlood", CardRarity.Rare, StorePools.RareBanner, StorePools.DragonAgeBanner),
        Banner(MilanBannerId.DA_TheDeepRoads, "MilanBanner_DA_TheDeepRoads", MilanPlayerVariable.Banner_DA_TheDeepRoads, DATheDeepRoadsTitle, "ThedasBanners.TheDeepRoads", CardRarity.Rare, StorePools.RareBanner, StorePools.DragonAgeBanner),
        //Banner(MilanBannerId.DA_TheLastStraw1, "MilanBanner_DA_TheLastStraw1", MilanPlayerVariable.Banner_DA_TheLastStraw1, DATheLastStraw1Title, "ThedasBanners.TheLastStraw1", CardRarity.Rare, StorePools.RareBanner, StorePools.DragonAgeBanner),
        Banner(MilanBannerId.DA_TheLastStraw2, "MilanBanner_DA_TheLastStraw2", MilanPlayerVariable.Banner_DA_TheLastStraw2, DATheLastStraw2Title, "ThedasBanners.TheLastStraw2", CardRarity.Rare, StorePools.RareBanner, StorePools.DragonAgeBanner),
        Banner(MilanBannerId.DA_TheWrathOfHeaven, "MilanBanner_DA_TheWrathOfHeaven", MilanPlayerVariable.Banner_DA_TheWrathOfHeaven, DATheWrathOfHeavenTitle, "ThedasBanners.TheWrathOfHeaven", CardRarity.Rare, StorePools.RareBanner, StorePools.DragonAgeBanner),
        Banner(MilanBannerId.DA_Trespasser, "MilanBanner_DA_Trespasser", MilanPlayerVariable.Banner_DA_Trespasser, DATrespasserTitle, "ThedasBanners.Trespasser", CardRarity.Rare, StorePools.RareBanner, StorePools.DragonAgeBanner),
        // Only drops from the free Save Mass Effect pack
        Banner(MilanBannerId.SaveMassEffect, "MilanBanner_SaveMassEffect", MilanPlayerVariable.Banner_SaveMassEffect, SaveMassEffectTitle, "Groups.SME", CardRarity.Rare, StorePools.SaveMassEffectBanner),
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

    public static StoreCard Banner(MilanBannerId emblemId, string uniqueName, MilanPlayerVariable playerVariable, LocalizedString title,
        string image, CardRarity rarity, params StorePool[] pools) =>
        Banner((int)emblemId, uniqueName, (int)playerVariable, MilanPipelinesShared.AssignTLK(title), image, rarity, pools);
}
