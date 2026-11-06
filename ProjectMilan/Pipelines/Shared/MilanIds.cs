using System.Reflection;
using ProjectMilanCore.Config.Store;

namespace ProjectMilan.Pipelines;

// Every integer ID Project Milan assigns by hand lives in this file, one enum per kind. Most of these end up in player
// saves, so a value must never be renumbered or reused - not even after its entry is removed. Keep removed entries
// here, marked [Obsolete(MilanIds.Reserved)], so their value stays taken. MilanIdsTests rejects duplicate values, and
// the store registration rejects any Milan-range ID that isn't an assignable member here.
//
// Vanilla IDs (ME3's own cards, packs and the mappings in MergedConfig\BioGame.xml) stay as plain ints at their use sites.

/// <summary>
/// mpplayervariablemappings IDs Milan adds: card ownership counters, store pack purchase counters and achievement
/// unlock latches. Vanilla IDs go up to 670; Milan IDs start at 700. Saved in the MP profile by ID.
/// </summary>
public enum MilanPlayerVariable
{
    // Store cards for vanilla items that had no player variable
    Card_Reckoning = 700,
    Card_GearWeaponStability = 701,

    // Achievement banner packs: per-player purchase counters (ClassName = pack name)
    AchievementPack_MedalOfHonor = 702,
    AchievementPack_ColonialSurvival = 703,
    AchievementPack_ME2MissionAccomplished = 704,
    AchievementPack_Merciless = 705,
    AchievementPack_ME3MissionAccomplished = 706,
    AchievementPack_TheOneAndOnly = 707,
    AchievementPack_InsanityIII = 708,

    // Achievement banner packs: unlock latches (ClassName = <pack name>_unlock)
    AchievementUnlock_MedalOfHonor = 709,
    AchievementUnlock_ColonialSurvival = 710,
    AchievementUnlock_ME2MissionAccomplished = 711,
    AchievementUnlock_Merciless = 712,
    AchievementUnlock_ME3MissionAccomplished = 713,
    AchievementUnlock_TheOneAndOnly = 714,
    AchievementUnlock_InsanityIII = 715,

    // Achievement banner ownership
    AchievementBanner_MedalOfHonor = 716,
    AchievementBanner_ColonialSurvival = 717,
    AchievementBanner_ME2MissionAccomplished = 718,
    AchievementBanner_Merciless = 719,
    AchievementBanner_ME3MissionAccomplished = 720,
    AchievementBanner_TheOneAndOnly = 721,
    AchievementBanner_InsanityIII = 722,

    // Store banner ownership
    Banner_BarCrawler = 723,
    Banner_Berserk = 724,
    Banner_Busted = 725,
    Banner_Diplomat = 726,
    Banner_Sunset = 727,
    Banner_KeyartLE1 = 728,
    Banner_KeyartLE1_Alt = 729,
    Banner_KeyartLE2 = 730,
    Banner_Caretaker = 731,
    Banner_Explorer = 732,
    Banner_Pathfinder = 733,
    Banner_Trailblazer = 734,
    Banner_Unknown = 735,
    Banner_Legendary = 736,
    Banner_Legendary_Alt = 737,
    Banner_Trilogy = 738,
    Banner_Club = 739,
    Banner_SFX = 740,
    Banner_N7S1 = 741,
    Banner_MEMP = 742,
    Pack_LegendaryBanner = 743,
    Banner_DA_ArlathanGlory = 744,
    Banner_DA_ArlathanRitual = 745,
    Banner_DA_FromTrickleToFlood = 746,
    Banner_DA_TheDeepRoads = 747,
    [Obsolete(MilanIds.Reserved)]
    Banner_DA_TheLastStraw1 = 748, // Card disabled
    Banner_DA_TheLastStraw2 = 749,
    Banner_DA_TheWrathOfHeaven = 750,
    Banner_DA_Trespasser = 751,
    Banner_SaveMassEffect = 752,
    Pack_SaveMassEffect = 753,
    Banner_MassEffectModding = 754,
    Banner_ME3Tweaks = 755,

    // Heavy weapon unlock cards
    HeavyUnlock_CobraHidden = 800,
    HeavyUnlock_Blackstorm = 801,
    HeavyUnlock_BlackstormHidden = 802,
    HeavyUnlock_Blackstar = 803,
    HeavyUnlock_BlackstarHidden = 804,
    HeavyUnlock_Cain = 805,
    HeavyUnlock_CainHidden = 806,
}

/// <summary>
/// Store pack nIDs (StoreInfoArray) Milan adds. Vanilla nIDs go up to 657; Milan nIDs start at 700.
/// </summary>
public enum MilanStorePackId
{
    Achievement_MedalOfHonor = 700,
    Achievement_ColonialSurvival = 701,
    Achievement_ME2MissionAccomplished = 702,
    Achievement_Merciless = 703,
    Achievement_ME3MissionAccomplished = 704,
    Achievement_TheOneAndOnly = 705,
    Achievement_InsanityIII = 706,
    LegendaryBanner = 707,
    SpectreShipment = 708,
    SpectreShipmentEquipment = 709,
    SaveMassEffect = 710,
}

/// <summary>
/// Banner emblem IDs (StoreCard.BannerID / StorePackEntry.BannerRewardID) Milan adds. Saved in the MP profile's reward
/// levels by ID. Milan emblem IDs start at 221.
/// </summary>
public enum MilanBannerId
{
    ME3Tweaks = 221, // Originally registered by OnlineContentRegistration; preserve the saved emblem ID.

    Achievement_MedalOfHonor = 222,
    Achievement_ColonialSurvival = 223,
    Achievement_ME2MissionAccomplished = 224,
    Achievement_Merciless = 225,
    Achievement_ME3MissionAccomplished = 226,
    Achievement_TheOneAndOnly = 227,
    Achievement_InsanityIII = 228,

    BarCrawler = 229,
    Berserk = 230,
    Busted = 231,
    Diplomat = 232,
    Sunset = 233,
    KeyartLE1 = 234,
    KeyartLE1_Alt = 235,
    KeyartLE2 = 236,
    Caretaker = 237,
    Explorer = 238,
    Pathfinder = 239,
    Trailblazer = 240,
    Unknown = 241,
    Legendary = 242,
    Legendary_Alt = 243,
    Trilogy = 244,
    Club = 245,
    SFX = 246,
    N7S1 = 247,
    MEMP = 248,
    DA_ArlathanGlory = 249,
    DA_ArlathanRitual = 250,
    DA_FromTrickleToFlood = 251,
    DA_TheDeepRoads = 252,
    [Obsolete(MilanIds.Reserved)]
    DA_TheLastStraw1 = 253, // Card disabled
    DA_TheLastStraw2 = 254,
    DA_TheWrathOfHeaven = 255,
    DA_Trespasser = 256,
    SaveMassEffect = 257,
    MassEffectModding = 258,
}

/// <summary>
/// Heavy weapon selection IDs (HeavyWeaponCatalogEntry.Id). Permanent: never assign these from collection order.
/// The first two weapons aren't paired with their hidden variants due to development order.
/// </summary>
public enum MilanHeavyWeaponId
{
    Cobra = 0,
    Blackstorm = 1,
    CobraHidden = 2,
    BlackstormHidden = 3,
    None = 4,
    Blackstar = 5,
    BlackstarHidden = 6,
    Cain = 7,
    CainHidden = 8,
}

public static class MilanIds
{
    public const string Reserved = "Reserved: this ID was used before and must not be reused.";

    /// <summary>Player variable IDs from here up are Milan's and must be in <see cref="MilanPlayerVariable"/>.</summary>
    public const int FirstPlayerVariable = 700;

    /// <summary>Store pack nIDs from here up are Milan's and must be in <see cref="MilanStorePackId"/>.</summary>
    public const int FirstStorePackId = 700;

    /// <summary>
    /// True if <paramref name="value"/> is a member of <typeparamref name="T"/> that isn't reserved.
    /// </summary>
    public static bool IsAssignable<T>(int value) where T : struct, Enum
    {
        if (!Enum.IsDefined(typeof(T), value))
        {
            return false;
        }
        // Several names can share a value; MilanIdsTests rejects that, so the first is the only one
        var name = Enum.GetName(typeof(T), value)!;
        return !typeof(T).GetField(name)!.IsDefined(typeof(ObsoleteAttribute));
    }

    /// <summary>
    /// Every Milan-range ID in <paramref name="catalog"/> that was written as a raw number instead of coming from the
    /// enums in this file, or that uses a reserved value.
    /// </summary>
    public static IEnumerable<string> FindUnassignedIds(StoreCatalog catalog)
    {
        foreach (var (name, id, owner) in catalog.GetPlayerVariables())
        {
            if (id >= FirstPlayerVariable && !IsAssignable<MilanPlayerVariable>(id))
            {
                yield return $"Player variable {name} ({owner}) uses ID {id}, which isn't an assignable {nameof(MilanPlayerVariable)}";
            }
        }
        foreach (var pack in catalog.Packs)
        {
            if (pack.ID >= FirstStorePackId && !IsAssignable<MilanStorePackId>(pack.ID))
            {
                yield return $"Store pack {pack.PackName} uses nID {pack.ID}, which isn't an assignable {nameof(MilanStorePackId)}";
            }
            if (pack.BannerRewardID is { } reward && !IsAssignable<MilanBannerId>(reward))
            {
                yield return $"Store pack {pack.PackName} rewards banner {reward}, which isn't an assignable {nameof(MilanBannerId)}";
            }
        }
        // Banners are all Milan's: vanilla cards have no BannerID
        foreach (var card in catalog.Banners)
        {
            if (!IsAssignable<MilanBannerId>(card.BannerID!.Value))
            {
                yield return $"Banner card {card.UniqueName} uses emblem ID {card.BannerID}, which isn't an assignable {nameof(MilanBannerId)}";
            }
        }
    }
}
