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
    private static readonly LocalizedString AmmoDescriptionText = new() {
        [MELocalization.INT] = "Ammunition for your equipped heavy weapon.",
        [MELocalization.DEU] = "Munition für deine ausgerüstete schwere Waffe.",
        [MELocalization.ESN] = "Munición de arma pesada equipada.",
        [MELocalization.FRA] = "Munitions pour votre arme lourde équippée.",
        [MELocalization.POL] = "Amunicja do wyposażonej broni ciężkiej.",
        [MELocalization.RUS] = "Боеприпасы для снаряженного тяжелого оружия.",
    };
    private static readonly LocalizedString GroupedAmmoText = new() {
        [MELocalization.INT] = "+<CUSTOM2> Heavy Weapon Ammo",
        [MELocalization.DEU] = "+<CUSTOM2> Schwere Munition",
        [MELocalization.ESN] = "+<CUSTOM2> munición de arma pesada",
        [MELocalization.FRA] = " +<CUSTOM2> Munitions arme lourde",
        [MELocalization.POL] = "+<CUSTOM2> Amunicja do broni ciężkiej",
        [MELocalization.RUS] = "+<CUSTOM2> Боеприпасы Тяжелого Оружия",
    };
    private static readonly LocalizedString AmmoCapacityText = new() {
        [MELocalization.INT] = "Heavy Weapon Ammo Capacity +<CUSTOM2>",
        [MELocalization.DEU] = "Reservemunition für schwere Waffen +<CUSTOM2>",
        [MELocalization.ESN] = "Capazidad de municiónes de arma pesada +<CUSTOM2>",
        [MELocalization.FRA] = "Capacité munitions arme lourde +<CUSTOM2>",
        [MELocalization.POL] = "Pojemność amunicji broni ciężkiej +<CUSTOM2>",
        [MELocalization.RUS] = "Боезапас Тяжелого Оружия +<CUSTOM2>",
    };
    private static readonly LocalizedString AmmoCapacityDescriptionText = new() {
        [MELocalization.INT] = "You can now carry <CUSTOM1> heavy weapon ammo charges into a mission.",
        [MELocalization.DEU] = "Du kannst jetzt <CUSTOM1> Ladungen Munition für schwere Waffen in eine Mission mitnehmen.",
        [MELocalization.ESN] = "Ahora puedes llevar <CUSTOM1> municiónes de arma pesada a una misión.",
        [MELocalization.FRA] = "Vous pouvez désormais porter <CUSTOM1> charges de munitions pour arme lourde en mission.",
        [MELocalization.POL] = "Możesz teraz zabrać ze sobą na misję <CUSTOM1> amunicji broni ciężkiej.",
        [MELocalization.RUS] = "Вы теперь можете брать <CUSTOM1> зарядов тяжелого оружия на миссию.",
    };
    private static readonly LocalizedString GearDescriptionText = new() {
        [MELocalization.INT] = "Stores additional thermal clips and heavy weapon ammo in armored compartments to shield them from incoming fire.\nHeavy Weapon Ammo Capacity: +<CUSTOM3>\nAmmo Capacity: +<CUSTOM0>%",
        [MELocalization.DEU] = "Lagert zusätzliche Thermomagazine und Munition für schwere Waffen in gepanzerten Fächern, um sie vor eingehendem Feuer zu schützen.\nReservemunition für schwere Waffen: +<CUSTOM3>\nReservemunition: +<CUSTOM0>%",
        [MELocalization.ESN] = "Almacena cargadores térmicos adicionales y munición para armas pesadas en compartimentos blindados para protegerlos del fuego enemigo.\nCapacidad de munición para armas pesadas: +<CUSTOM3>\nCapacidad de munición: +<CUSTOM0>%",
        [MELocalization.FRA] = "Emmagasine des cartouches thermiques supplémentaires et des munitions pour arme lourde dans des compartiments armurés pour les protéger contre le feu ennemi.\nCapacité munitions arme lourde : +<CUSTOM3>\nCapacité munitions : +<CUSTOM0> %",
        [MELocalization.POL] = "Przechowuje dodatkowe pochłaniacze ciepła i amunicję do broni ciężkiej w pancernych schowkach, chroniąc je przed ostrzałem. Pojemność amunicji broni ciężkiej: +<CUSTOM3> Pojemność amunicji: +<CUSTOM0>%",
        [MELocalization.RUS] = "Хранит дополнильные термозаряды и боеприпасы тяжелого оружия в бронированных отсеках для защиты от входящего огня.\nБоезапас Тяжелого Оружия: +<CUSTOM3>\nБоезапас: +<CUSTOM0>%",
    };
    private static readonly LocalizedString HiddenText = new() {
        [MELocalization.INT] = "Hidden weapons disappear when holstered.",
        [MELocalization.DEU] = "Versteckte Waffen verschwinden beim Verstauen.",
        [MELocalization.ESN] = "Armas ocultas desaparethen cuando estan enfundadas.",
        [MELocalization.FRA] = "Les armes cachées disparaissent lorsqu'elles ne sont pas en main.",
        [MELocalization.POL] = "Ukryta broń znika po jej schowaniu.",
        [MELocalization.RUS] = "Тяжелое оружие скрывается при убирании",
    };
    private static readonly LocalizedString UnlockDescriptionText = new() {
        [MELocalization.INT] = "Unlocks this heavy weapon for selection.",
        [MELocalization.DEU] = "Schaltet diese schwere Waffe zur Auswahl frei.",
        [MELocalization.ESN] = "Desbloquea este arma pesado.",
        [MELocalization.FRA] = "Débloque la sélection de cette arme lourde.",
        [MELocalization.POL] = "Odblokowuje tę broń ciężką umożliwiając jej wybór.",
        [MELocalization.RUS] = "Разблокирует выбор тяжелого оружия.",
    };
    private static readonly LocalizedString HiddenUnlockDescriptionText = LocalizedString.Join(UnlockDescriptionText, "\n\n", HiddenText);
    private static readonly LocalizedString HiddenCobraTitleText = new() {
        [MELocalization.INT] = "Cobra Missile Launcher (Hidden)",
        [MELocalization.DEU] = "Raketenwerfer Cobra (Verborgen)",
        [MELocalization.ESN] = "Lanzamisiles Cobra (oculto)",
        [MELocalization.FRA] = "Lance-missile Cobra (Caché)",
        [MELocalization.POL] = "Wyrzutnia rakiet Cobra (ukryta)",
        [MELocalization.RUS] = "М-560 Кобра",
    };
    private static readonly LocalizedString CardTypeText = new() {
        [MELocalization.INT] = "Heavy Weapon",
        [MELocalization.DEU] = "Schwere Waffe",
        [MELocalization.ESN] = "Arma pesada",
        [MELocalization.FRA] = "Arme lourde",
        [MELocalization.POL] = "Broń ciężka",
        [MELocalization.RUS] = "Тяжелое Оружие",
    };

    // Cobra is unlocked by deafult, so it doesn't have anything unlock for it. So we have to fill out the
    // hidden variant
    internal const string HiddenCobraUnlock = "MilanHeavy_Cobra_Hidden";


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
        catalog.Cards.Add(Unlock(HiddenCobraUnlock, MilanPlayerVariable.HeavyUnlock_CobraHidden, MilanPipelinesShared.AssignTLK(HiddenCobraTitleText), hiddenDescription, "GUI_Icons.Weapons.hvy_titan_256x128"));
        foreach (var entry in HeavyWeaponsPipeline.HeavyWeapons)
        {
            var rarity = GetCardRarity(entry);
            catalog.Cards.Add(Unlock(entry.UnlockName, entry.UnlockPlayerVariableId, entry.ResolveName(), unlockDescription, entry.GetNotificationImage(), rarity));
            catalog.Cards.Add(Unlock(entry.HiddenUnlockName, entry.HiddenUnlockPlayerVariableId, entry.HiddenUnlockTitle.Resolve(), hiddenDescription,
                entry.GetNotificationImage(), rarity) with
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

    /// <summary>
    /// An unlock card. Ultra rare ones join the ultra rare weapon pool, so they drop like the ultra rare guns; the rest
    /// join <see cref="StorePools.GoldPermanent"/>.
    /// </summary>
    private static StoreCard Unlock(string name, MilanPlayerVariable ownershipId, int title, int description, string image, CardRarity rarity = CardRarity.Rare) => new()
    {
        UniqueName = name,
        Kind = ReinforcementKind.PermanentUpgrade,
        Rarity = rarity,
        MaxCount = 1,
        GUIName = title,
        GUIDescription = description,
        GUIType = CardType,
        GUITextureRef = image,
        PlayerVariableIds = [(int)ownershipId],
        Pools = [new(rarity == CardRarity.UltraRare ? StorePools.GoldUltraRare : StorePools.GoldPermanent)]
    };

    /// <summary>
    /// The card rarity for a registration's <see cref="HeavyWeaponEntry.Rarity"/>.
    /// </summary>
    private static CardRarity GetCardRarity(HeavyWeaponEntry entry) => entry.Rarity switch
    {
        "common" => CardRarity.Common,
        "uncommon" => CardRarity.Uncommon,
        "rare" => CardRarity.Rare,
        "ultrarare" => CardRarity.UltraRare,
        _ => throw new InvalidOperationException($"Heavy weapon {entry.ClassPath} has an unknown rarity '{entry.Rarity}'"),
    };

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
