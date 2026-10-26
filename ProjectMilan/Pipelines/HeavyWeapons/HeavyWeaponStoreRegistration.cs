using LegendaryExplorerCore.Coalesced;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Unreal;
using ProjectMilan.Pipelines.Store;
using ProjectMilanCore;
using ProjectMilanCore.Config;
using ProjectMilanCore.Config.Store;
using ProjectMilanCore.Utility;

namespace ProjectMilan.Pipelines.HeavyWeapons;

internal static class HeavyWeaponStoreRegistration
{
    // Consumable class is what is used to populate some UI strings
    // So we need to modify it to change to Heavy Weapon Ammo.
    private const string RocketPower = "SFXGameMPContent.SFXPowerCustomActionMP_Consumable_Rocket";

    /// <summary>
    /// The store card's type key (StoreCard.GUIType). Not shown to the player: the reveal screen looks it up in
    /// SFXGUI_MPReinforcementsReveal's CardTypeTextData, whose GUIType string ref is the type label it shows.
    /// </summary>
    private const string CardType = "heavyweapon";

    private const int AmmoName = 335491; // 'Heavy Weapon Ammo'
    private static readonly LocalizedString AmmoDescriptionText = new() { [MELocalization.INT] = "Ammunition for your equipped heavy weapon." };
    private static readonly LocalizedString GroupedAmmoText = new() { [MELocalization.INT] = "+<CUSTOM2> Heavy Weapon Ammo" };
    private static readonly LocalizedString AmmoCapacityText = new() { [MELocalization.INT] = "Heavy Weapon Ammo Capacity +<CUSTOM2>" };
    private static readonly LocalizedString AmmoCapacityDescriptionText = new() { [MELocalization.INT] = "You can now carry <CUSTOM1> heavy weapon ammo charges into a mission." };
    private static readonly LocalizedString GearDescriptionText = new() { [MELocalization.INT] = "Stores additional thermal clips and heavy weapon ammo in armored compartments to shield them from incoming fire.\nHeavy Weapon Ammo Capacity: +<CUSTOM3>\nAmmo Capacity: +<CUSTOM0>%" };
    private static readonly LocalizedString HiddenText = new() { [MELocalization.INT] = "Hidden weapons disappear when holstered." };
    private static readonly LocalizedString UnlockDescriptionText = new() { [MELocalization.INT] = "Unlocks this heavy weapon for selection." };
    private static readonly LocalizedString HiddenUnlockDescriptionText = Join(UnlockDescriptionText, "\n\n", HiddenText);
    private static readonly LocalizedString HiddenCobraTitleText = new() { [MELocalization.INT] = "Cobra Missile Launcher (Hidden)" };
    private static readonly LocalizedString CardTypeText = new() { [MELocalization.INT] = "Heavy Weapon" };

    // Cobra is unlocked by deafult, so it doesn't have anything unlock for it. So we have to fill out the
    // hidden variant
    internal const string HiddenCobraUnlock = "MilanHeavy_Cobra_Hidden";
    internal const int HiddenCobraOwnershipId = 800;


    internal static void Configure(StoreCatalog catalog)
    {
        int description = MilanPipelinesShared.AssignTLK(AmmoDescriptionText);
        int grouped = MilanPipelinesShared.AssignTLK(GroupedAmmoText);
        int capacity = MilanPipelinesShared.AssignTLK(AmmoCapacityText);
        int capacityDescription = MilanPipelinesShared.AssignTLK(AmmoCapacityDescriptionText);
        int gearDescription = MilanPipelinesShared.AssignTLK(GearDescriptionText);
        for (int i = 0; i < catalog.Cards.Count; i++)
        {
            var card = catalog.Cards[i];
            if (card.UniqueName == RocketPower)
            {
                catalog.Cards[i] = card with
                {
                    GUIName = AmmoName,
                    GUIDescription = description,
                    Pools = card.Pools.Select(p => p.GUIName == 702719 ? p with { GUIName = grouped } : p).ToList()
                };
            }
            else if (card.UniqueName == "MPCapacity_Rocket")
            {
                catalog.Cards[i] = card with { GUIName = capacity, GUIDescription = capacityDescription };
            }
            else if (card.UniqueName == "SFXGameContentDLC_CON_MP4.SFXGameEffect_MatchConsumable_Gear_CobraCapacity")
            {
                catalog.Cards[i] = card with { GUIDescription = gearDescription };
            }
        }
        var section = MilanPipelinesShared.ConfigBundle.GetAsset("BioGame").GetOrAddSection(HeavyWeaponCatalogRegistration.SectionName);
        Set(section, "ammoname", AmmoName);
        Set(section, "ammodescription", description);
        Set(section, "hiddendescriptionsuffix", MilanPipelinesShared.AssignTLK(HiddenText));
        int unlockDescription = MilanPipelinesShared.AssignTLK(UnlockDescriptionText);
        int hiddenDescription = MilanPipelinesShared.AssignTLK(HiddenUnlockDescriptionText);
        catalog.Cards.Add(Unlock(HiddenCobraUnlock, HiddenCobraOwnershipId, MilanPipelinesShared.AssignTLK(HiddenCobraTitleText), hiddenDescription, "GUI_Icons.Weapons.hvy_titan_256x128"));
        foreach (var entry in HeavyWeaponsPipeline.HeavyWeapons)
        {
            catalog.Cards.Add(Unlock(entry.UnlockName, entry.UnlockPlayerVariableId, entry.ResolveName(), unlockDescription, entry.GetNotificationImage()));
            catalog.Cards.Add(Unlock(entry.HiddenUnlockName, entry.HiddenUnlockPlayerVariableId, entry.HiddenUnlockTitle.Resolve(), hiddenDescription,
                entry.GetNotificationImage()) with
            { RequiresCard = entry.UnlockName });
        }
        var engine = MilanPipelinesShared.ConfigBundle.GetAsset("BioEngine").GetOrAddSection("sfxgame.sfxengine");
        foreach (var card in catalog.Cards.Where(c => c.GUIType == CardType))
        {
            engine.AddEntry(new CoalesceProperty("sfxuniqueids", new CoalesceValue(card.UniqueName, CoalesceParseAction.AddUnique)));
        }
        var ui = MilanPipelinesShared.ConfigBundle.GetAsset("BioUI").GetOrAddSection("sfxgamempcontent.sfxgui_mpreinforcementsreveal");
        ui.AddEntry(new CoalesceProperty("cardtypetextdata", new CoalesceValue($"(CardType=\"{CardType}\",GUIType={MilanPipelinesShared.AssignTLK(CardTypeText)})", CoalesceParseAction.AddUnique)));
    }

    private static StoreCard Unlock(string name, int ownershipId, int title, int description, string image) => new()
    {
        UniqueName = name,
        Kind = ReinforcementKind.PermanentUpgrade,
        Rarity = CardRarity.Rare,
        MaxCount = 1,
        GUIName = title,
        GUIDescription = description,
        GUIType = CardType,
        GUITextureRef = image,
        PlayerVariableIds = [ownershipId],
        Pools = [new(StorePools.GoldPermanent)]
    };

    /// <summary>
    /// <paramref name="first"/>, <paramref name="separator"/> and <paramref name="second"/>, in each language both have.
    /// </summary>
    private static LocalizedString Join(LocalizedString first, string separator, LocalizedString second)
    {
        var joined = new LocalizedString();
        foreach (var (language, text) in first)
        {
            if (second.TryGetValue(language, out var other))
            {
                joined[language] = text + separator + other;
            }
        }
        return joined;
    }

    private static void Set(CoalesceSection section, string name, int id)
    {
        section.Remove(name);
        section.AddEntry(new CoalesceProperty(name, new CoalesceValue(id.ToString(), CoalesceParseAction.New)));
    }

    internal static void ApplyPowerDefaults(IMEPackage package)
    {
        var section = MilanPipelinesShared.ConfigBundle.GetAsset("BioGame").Sections[HeavyWeaponCatalogRegistration.SectionName];
        var defaults = package.FindExport("SFXGameMPContent.Default__SFXPowerCustomActionMP_Consumable_Rocket") ?? throw new InvalidOperationException("MPCommon is missing the shared heavy ammo power.");
        defaults.WriteProperty(new StringRefProperty(int.Parse(section["ammoname"][0].Value!), "DisplayName"));
        int description = int.Parse(section["ammodescription"][0].Value!);
        defaults.WriteProperty(new StringRefProperty(description, "Description"));
        defaults.WriteProperty(new StringRefProperty(description, "TalentDescription"));
    }
}
