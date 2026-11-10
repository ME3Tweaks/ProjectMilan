using LegendaryExplorerCore.Packages;
using ProjectMilanCore;
using ProjectMilanCore.Config.Store;
using ProjectMilanCore.Utility;

namespace ProjectMilan.Pipelines.Store;

public static partial class StoreCards
{
    private static readonly LocalizedString BarCrawlerTitle = new() {
        [MELocalization.INT] = "Bar Crawler",
        [MELocalization.DEU] = "Kneipengänger",
        [MELocalization.ESN] = "Cliente habitual",
        [MELocalization.FRA] = "Régulier des bars",
        [MELocalization.POL] = "Miłośnik barów",
    };
    private static readonly LocalizedString BerserkTitle = new() {
        [MELocalization.INT] = "Berserk",
        [MELocalization.DEU] = "Berserker",
        [MELocalization.ESN] = "Berserk",
        [MELocalization.FRA] = "Fureur",
        [MELocalization.POL] = "Berserk",
        [MELocalization.RUS] = "Берсерк",
    };
    private static readonly LocalizedString BustedTitle = new() {
        [MELocalization.INT] = "Busted",
        [MELocalization.DEU] = "Erwischt",
        [MELocalization.ESN] = "Pillado",
        [MELocalization.FRA] = "Grillé",
        [MELocalization.POL] = "Przyłapany",
        [MELocalization.RUS] = "Пойман с поличным",
    };
    private static readonly LocalizedString DiplomatTitle = new() {
        [MELocalization.INT] = "Diplomat",
        [MELocalization.DEU] = "Diplomat",
        [MELocalization.ESN] = "Diplomata",
        [MELocalization.FRA] = "Diplomate",
        [MELocalization.POL] = "Dyplomata",
        [MELocalization.RUS] = "Дипломат",
    };
    private static readonly LocalizedString SunsetTitle = new() {
        [MELocalization.INT] = "Sunset",
        [MELocalization.DEU] = "Sonnenuntergang",
        [MELocalization.ESN] = "Crepúsculo",
        [MELocalization.FRA] = "Coucher de soleil",
        [MELocalization.POL] = "Zachód słońca",
        [MELocalization.RUS] = "Закат",
    };
    private static readonly LocalizedString KeyartLE1Title = new() {
        [MELocalization.INT] = "Mass Effect",
        [MELocalization.DEU] = "Mass Effect",
        [MELocalization.ESN] = "Mass Effect",
        [MELocalization.FRA] = "Mass Effect",
        [MELocalization.POL] = "Mass Effect",
        [MELocalization.RUS] = "Mass Effect",
    };
    private static readonly LocalizedString KeyartLE1AltTitle = new() {
        [MELocalization.INT] = "Mass Effect",
        [MELocalization.DEU] = "Mass Effect",
        [MELocalization.ESN] = "Mass Effect",
        [MELocalization.FRA] = "Mass Effect",
        [MELocalization.POL] = "Mass Effect",
        [MELocalization.RUS] = "Mass Effect",
    };
    private static readonly LocalizedString KeyartLE2Title = new() {
        [MELocalization.INT] = "Mass Effect 2",
        [MELocalization.DEU] = "Mass Effect 2",
        [MELocalization.ESN] = "Mass Effect 2",
        [MELocalization.FRA] = "Mass Effect 2",
        [MELocalization.POL] = "Mass Effect 2",
        [MELocalization.RUS] = "Mass Effect 2",
    };
    private static readonly LocalizedString CaretakerTitle = new() {
        [MELocalization.INT] = "Caretaker",
        [MELocalization.DEU] = "Hüter",
        [MELocalization.ESN] = "Guardián",
        [MELocalization.FRA] = "Gardien",
        [MELocalization.POL] = "Opiekun",
        [MELocalization.RUS] = "Смотритель",
    };
    private static readonly LocalizedString ExplorerTitle = new() {
        [MELocalization.INT] = "Explorer",
        [MELocalization.DEU] = "Entdecker",
        [MELocalization.ESN] = "Explorador",
        [MELocalization.FRA] = "Explorateur",
        [MELocalization.POL] = "Odkrywca",
        [MELocalization.RUS] = "Исследователь",
    };
    private static readonly LocalizedString PathfinderTitle = new() {
        [MELocalization.INT] = "Pathfinder",
        [MELocalization.DEU] = "Pathfinder",
        [MELocalization.ESN] = "Pionero",
        [MELocalization.FRA] = "Pionnier",
        [MELocalization.POL] = "Pionier",
        [MELocalization.RUS] = "Следопыт",
    };
    private static readonly LocalizedString TrailblazerTitle = new() {
        [MELocalization.INT] = "Trailblazer",
        [MELocalization.DEU] = "Wegbereiter",
        [MELocalization.ESN] = "Precursor",
        [MELocalization.FRA] = "Innovateur",
        [MELocalization.POL] = "Prekursor",
        [MELocalization.RUS] = "Первопроходец",
    };
    private static readonly LocalizedString UnknownTitle = new() {
        [MELocalization.INT] = "Unknown",
        [MELocalization.DEU] = "Unbekannt",
        [MELocalization.ESN] = "Desconocido",
        [MELocalization.FRA] = "Inconnu",
        [MELocalization.POL] = "Nieznany",
        [MELocalization.RUS] = "Неизвестный",
    };
    private static readonly LocalizedString LegendaryTitle = new() {
        [MELocalization.INT] = "Legendary",
        [MELocalization.DEU] = "Legendär",
        [MELocalization.ESN] = "Legendario",
        [MELocalization.FRA] = "Légendaire",
        [MELocalization.POL] = "Legendarny",
        [MELocalization.RUS] = "Легендарный",
    };
    private static readonly LocalizedString LegendaryAltTitle = new() {
        [MELocalization.INT] = "Legendary",
        [MELocalization.DEU] = "Legendär",
        [MELocalization.ESN] = "Legendario",
        [MELocalization.FRA] = "Légendaire",
        [MELocalization.POL] = "Legendarny",
        [MELocalization.RUS] = "Легендарный",
    };
    private static readonly LocalizedString TrilogyTitle = new() {
        [MELocalization.INT] = "Mass Effect Trilogy",
        [MELocalization.DEU] = "Mass Effect Trilogie",
        [MELocalization.ESN] = "Trilogía de Mass Effect",
        [MELocalization.FRA] = "Trilogie Mass Effect",
        [MELocalization.POL] = "Trylogia Mass Effect",
        [MELocalization.RUS] = "Трилогия Mass Effect",
    };
    private static readonly LocalizedString ClubTitle = new() {
        [MELocalization.INT] = "Neon",
        [MELocalization.DEU] = "Neon",
        [MELocalization.ESN] = "Neón",
        [MELocalization.FRA] = "Néon",
        [MELocalization.POL] = "Neon",
        [MELocalization.RUS] = "Неон",
    };
    private static readonly LocalizedString SFXTitle = new() {
        [MELocalization.INT] = "SFX",
        [MELocalization.DEU] = "SFX",
        [MELocalization.ESN] = "SFX",
        [MELocalization.FRA] = "SFX",
        [MELocalization.POL] = "SFX",
        [MELocalization.RUS] = "SFX",
    };
    private static readonly LocalizedString N7S1Title = new() {
        [MELocalization.INT] = "N7 Squad",
        [MELocalization.DEU] = "N7 Squad",
        [MELocalization.ESN] = "N7 Squad",
        [MELocalization.FRA] = "N7 Squad",
        [MELocalization.POL] = "Oddział N7",
        [MELocalization.RUS] = "Отряд N7",
    };
    private static readonly LocalizedString MEMTitle = new() {
        [MELocalization.INT] = "Mass Effect Modding",
        [MELocalization.DEU] = "Mass Effect Modding",
        [MELocalization.ESN] = "Mass Effect Modding",
        [MELocalization.FRA] = "Mass Effect Modding",
        [MELocalization.POL] = "Mass Effect Modding",
        [MELocalization.RUS] = "Mass Effect Моддинг",
    };
    private static readonly LocalizedString ME3TweaksTitle = new() {
        [MELocalization.INT] = "ME3Tweaks",
        [MELocalization.DEU] = "ME3Tweaks",
        [MELocalization.ESN] = "ME3Tweaks",
        [MELocalization.FRA] = "ME3Tweaks",
        [MELocalization.POL] = "ME3Tweaks",
        [MELocalization.RUS] = "ME3Tweaks",
    };
    private static readonly LocalizedString MEMPTitle = new() {
        [MELocalization.INT] = "United Through Discord",
        [MELocalization.DEU] = "Vereint durch Zwietracht",
        [MELocalization.ESN] = "Unidos a través el desacuerdo",
        [MELocalization.FRA] = "Unis par la discorde",
        [MELocalization.POL] = "Zjednoczeni w niezgodzie",
        [MELocalization.RUS] = "Discord Объединяет",
    };
    private static readonly LocalizedString DAArlathanGloryTitle = new() {
        [MELocalization.INT] = "Glory of Arlathan",
        [MELocalization.DEU] = "Ruhm von Arlathan",
        [MELocalization.ESN] = "Gloria de Arlathan",
        [MELocalization.FRA] = "Gloire d'Arlathan",
        [MELocalization.POL] = "Chwała Arlathanu",
        [MELocalization.RUS] = "Слава Арлатана",
    };
    private static readonly LocalizedString DAArlathanRitualTitle = new() {
        [MELocalization.INT] = "The Ritual",
        [MELocalization.DEU] = "Das Ritual",
        [MELocalization.ESN] = "El Ritual",
        [MELocalization.FRA] = "Le Rituel",
        [MELocalization.POL] = "Rytuał",
        [MELocalization.RUS] = "Ритуал",
    };
    private static readonly LocalizedString DAFromTrickleToFloodTitle = new() {
        [MELocalization.INT] = "From a Trickle to a Flood",
        [MELocalization.DEU] = "Vom Rinnsal zur Flut",
        [MELocalization.ESN] = "De un chorrito a una inundación",
        [MELocalization.FRA] = "De la Goutte au déluge",
        [MELocalization.POL] = "Od strużki do powodzi",
        [MELocalization.RUS] = "От Капели до Потопа",
    };
    private static readonly LocalizedString DATheDeepRoadsTitle = new() {
        [MELocalization.INT] = "The Deep Roads",
        [MELocalization.DEU] = "Die Tiefen Straßen",
        [MELocalization.ESN] = "Caminos de las Profundidades",
        [MELocalization.FRA] = "Les Tréfonds",
        [MELocalization.POL] = "Głębokie Ścieżki",
        [MELocalization.RUS] = "Дальние Дороги",
    };
    // private static readonly LocalizedString DATheLastStraw1Title = new() { [MELocalization.INT] = "The Last Straw" };
    private static readonly LocalizedString DATheLastStraw2Title = new() {
        [MELocalization.INT] = "The Last Straw",
        [MELocalization.DEU] = "Der letzte Tropfen",
        [MELocalization.ESN] = "La última gota",
        [MELocalization.FRA] = "La Goutte d'eau",
        [MELocalization.POL] = "Ostatnia kropla",
        [MELocalization.RUS] = "Последняя Соломинка",
    };
    private static readonly LocalizedString DATheWrathOfHeavenTitle = new() {
        [MELocalization.INT] = "The Wrath of Heaven",
        [MELocalization.DEU] = "Der Zorn des Himmels",
        [MELocalization.ESN] = "La ira del paraíso",
        [MELocalization.FRA] = "La Colère du ciel",
        [MELocalization.POL] = "Gniew niebios",
        [MELocalization.RUS] = "Ярость Небес",
    };
    private static readonly LocalizedString SaveMassEffectTitle = new() {
        [MELocalization.INT] = "Save Mass Effect",
        [MELocalization.DEU] = "Rettet Mass Effect",
        [MELocalization.ESN] = "Salva Mass Effect",
        [MELocalization.FRA] = "Save Mass Effect",
        [MELocalization.POL] = "Ratujmy Mass Effect",
    };
    private static readonly LocalizedString DATrespasserTitle = new() {
        [MELocalization.INT] = "Trespasser",
        [MELocalization.DEU] = "Eindringling",
        [MELocalization.ESN] = "Intruso",
        [MELocalization.FRA] = "Effraction",
        [MELocalization.POL] = "Intruz",
        [MELocalization.RUS] = "Нарушитель",
    };

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
