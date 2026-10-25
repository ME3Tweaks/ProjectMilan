using ProjectMilanCore.Config.Store;

namespace ProjectMilan.Pipelines.Store
{
    public static partial class StoreCards
    {
        /// <summary>
        /// Character (kit) cards. VersionIdx is the kit's rarity tier.
        /// </summary>
        private static IEnumerable<StoreCard> Kits =>
        [
            new()
            {
                UniqueName = "AdeptHumanMale", Kind = ReinforcementKind.KitUnlock, Rarity = CardRarity.Common,
                GUIName = 711364, GUIType = "char", GUITextureRef = "GUI_MPImages.Cards.KitBioticMale",
                PlayerVariableIds = [248],
                Pools =
                [
                    new(StorePools.BronzeChar),
                    new(StorePools.GoldXPChar) { VersionIdx = 2 },
                    new(StorePools.XPChar) { VersionIdx = 1 },
                ],
            },
            new()
            {
                UniqueName = "AdeptHumanFemale", Kind = ReinforcementKind.KitUnlock, Rarity = CardRarity.Common,
                GUIName = 711370, GUIType = "char", GUITextureRef = "GUI_MPImages.Cards.KitBiotic",
                PlayerVariableIds = [247],
                Pools =
                [
                    new(StorePools.BronzeChar),
                    new(StorePools.GoldXPChar) { VersionIdx = 2 },
                    new(StorePools.XPChar) { VersionIdx = 1 },
                ],
            },
            new()
            {
                UniqueName = "EngineerHumanMale", Kind = ReinforcementKind.KitUnlock, Rarity = CardRarity.Common,
                GUIName = 711365, GUIType = "char", GUITextureRef = "GUI_MPImages.Cards.KitAgentMale",
                PlayerVariableIds = [250],
                Pools =
                [
                    new(StorePools.BronzeChar),
                    new(StorePools.GoldXPChar) { VersionIdx = 2 },
                    new(StorePools.XPChar) { VersionIdx = 1 },
                ],
            },
            new()
            {
                UniqueName = "EngineerHumanFemale", Kind = ReinforcementKind.KitUnlock, Rarity = CardRarity.Common,
                GUIName = 711371, GUIType = "char", GUITextureRef = "GUI_MPImages.Cards.KitAgent",
                PlayerVariableIds = [249],
                Pools =
                [
                    new(StorePools.BronzeChar),
                    new(StorePools.GoldXPChar) { VersionIdx = 2 },
                    new(StorePools.XPChar) { VersionIdx = 1 },
                ],
            },
            new()
            {
                UniqueName = "InfiltratorHumanMale", Kind = ReinforcementKind.KitUnlock, Rarity = CardRarity.Common,
                GUIName = 711366, GUIType = "char", GUITextureRef = "GUI_MPImages.Cards.KitAgentMale",
                PlayerVariableIds = [252],
                Pools =
                [
                    new(StorePools.BronzeChar),
                    new(StorePools.GoldXPChar) { VersionIdx = 2 },
                    new(StorePools.XPChar) { VersionIdx = 1 },
                ],
            },
            new()
            {
                UniqueName = "InfiltratorHumanFemale", Kind = ReinforcementKind.KitUnlock, Rarity = CardRarity.Common,
                GUIName = 711372, GUIType = "char", GUITextureRef = "GUI_MPImages.Cards.KitAgent",
                PlayerVariableIds = [251],
                Pools =
                [
                    new(StorePools.BronzeChar),
                    new(StorePools.GoldXPChar) { VersionIdx = 2 },
                    new(StorePools.XPChar) { VersionIdx = 1 },
                ],
            },
            new()
            {
                UniqueName = "SentinelHumanMale", Kind = ReinforcementKind.KitUnlock, Rarity = CardRarity.Common,
                GUIName = 711367, GUIType = "char", GUITextureRef = "GUI_MPImages.Cards.KitBioticMale",
                PlayerVariableIds = [254],
                Pools =
                [
                    new(StorePools.BronzeChar),
                    new(StorePools.GoldXPChar) { VersionIdx = 2 },
                    new(StorePools.XPChar) { VersionIdx = 1 },
                ],
            },
            new()
            {
                UniqueName = "SentinelHumanFemale", Kind = ReinforcementKind.KitUnlock, Rarity = CardRarity.Common,
                GUIName = 711373, GUIType = "char", GUITextureRef = "GUI_MPImages.Cards.KitBiotic",
                PlayerVariableIds = [253],
                Pools =
                [
                    new(StorePools.BronzeChar),
                    new(StorePools.GoldXPChar) { VersionIdx = 2 },
                    new(StorePools.XPChar) { VersionIdx = 1 },
                ],
            },
            new()
            {
                UniqueName = "SoldierHumanMale", Kind = ReinforcementKind.KitUnlock, Rarity = CardRarity.Common,
                GUIName = 711368, GUIType = "char", GUITextureRef = "GUI_MPImages.Cards.KitSoldierMale",
                PlayerVariableIds = [256],
                Pools =
                [
                    new(StorePools.BronzeChar),
                    new(StorePools.GoldXPChar) { VersionIdx = 2 },
                    new(StorePools.XPChar) { VersionIdx = 1 },
                ],
            },
            new()
            {
                UniqueName = "SoldierHumanFemale", Kind = ReinforcementKind.KitUnlock, Rarity = CardRarity.Common,
                GUIName = 711374, GUIType = "char", GUITextureRef = "GUI_MPImages.Cards.KitSoldier",
                PlayerVariableIds = [255],
                Pools =
                [
                    new(StorePools.BronzeChar),
                    new(StorePools.GoldXPChar) { VersionIdx = 2 },
                    new(StorePools.XPChar) { VersionIdx = 1 },
                ],
            },
            new()
            {
                UniqueName = "VanguardHumanMale", Kind = ReinforcementKind.KitUnlock, Rarity = CardRarity.Common,
                GUIName = 711369, GUIType = "char", GUITextureRef = "GUI_MPImages.Cards.KitSoldierMale",
                PlayerVariableIds = [258],
                Pools =
                [
                    new(StorePools.BronzeChar),
                    new(StorePools.GoldXPChar) { VersionIdx = 2 },
                    new(StorePools.XPChar) { VersionIdx = 1 },
                ],
            },
            new()
            {
                UniqueName = "VanguardHumanFemale", Kind = ReinforcementKind.KitUnlock, Rarity = CardRarity.Common,
                GUIName = 711375, GUIType = "char", GUITextureRef = "GUI_MPImages.Cards.KitSoldier",
                PlayerVariableIds = [257],
                Pools =
                [
                    new(StorePools.BronzeChar),
                    new(StorePools.GoldXPChar) { VersionIdx = 2 },
                    new(StorePools.XPChar) { VersionIdx = 1 },
                ],
            },
            new()
            {
                UniqueName = "InfiltratorHumanFemaleBF3", Kind = ReinforcementKind.KitUnlock, Rarity = CardRarity.Uncommon,
                GUIName = 723371, GUIDescription = 723303, GUIType = "char", GUITextureRef = "GUI_MPImages.Cards.KitAgent",
            },
            new()
            {
                UniqueName = "SoldierGethDestroyer", Kind = ReinforcementKind.KitUnlock, Rarity = CardRarity.Rare, MaxCount = 4, VersionIdx = 2,
                GUIName = 782882, GUICategory = CardGUICategory.Kit, GUIType = "char", GUITextureRef = "DLC_MPImages.Cards.KitGethPSOL",
                PlayerVariableIds = [576],
                Pools = [new(StorePools.FreeGoldChar), new(StorePools.GoldChar), new(StorePools.GoldBackup)],
            },
            new()
            {
                UniqueName = "AdeptCollector", Kind = ReinforcementKind.KitUnlock, Rarity = CardRarity.UltraRare, MaxCount = 4, VersionIdx = 2,
                GUIName = 783880, GUICategory = CardGUICategory.Kit, GUIType = "char", GUITextureRef = "DLC_MPImages.Cards.KitCollectADP",
                PlayerVariableIds = [577],
                Pools = [new(StorePools.UltraRareChar)],
            },
            new()
            {
                UniqueName = "SentinelKroganWarlord", Kind = ReinforcementKind.KitUnlock, Rarity = CardRarity.Rare, MaxCount = 4, VersionIdx = 2,
                GUIName = 788575, GUICategory = CardGUICategory.Kit, GUIType = "char", GUITextureRef = "DLC_MPImages.Cards.KitBloodSEN",
                PlayerVariableIds = [583],
                Pools = [new(StorePools.FreeGoldChar), new(StorePools.GoldChar), new(StorePools.GoldBackup)],
            },
            new()
            {
                UniqueName = "EngineerMerc", Kind = ReinforcementKind.KitUnlock, Rarity = CardRarity.Rare, MaxCount = 4, VersionIdx = 2,
                GUIName = 788576, GUICategory = CardGUICategory.Kit, GUIType = "char", GUITextureRef = "DLC_MPImages.Cards.KitMercENG",
                PlayerVariableIds = [584],
                Pools = [new(StorePools.FreeGoldChar), new(StorePools.GoldChar), new(StorePools.GoldBackup)],
            },
            new()
            {
                UniqueName = "VanguardTurianFemale", Kind = ReinforcementKind.KitUnlock, Rarity = CardRarity.Rare, MaxCount = 5, VersionIdx = 2,
                GUIName = 812774, GUICategory = CardGUICategory.Kit, GUIType = "char", GUITextureRef = "DLC_MPImages.Cards.KitTurianVan",
                PlayerVariableIds = [592],
                Pools = [new(StorePools.FreeGoldChar), new(StorePools.GoldChar), new(StorePools.GoldBackup)],
            },
            new()
            {
                UniqueName = "InfiltratorFembot", Kind = ReinforcementKind.KitUnlock, Rarity = CardRarity.Rare, MaxCount = 3, VersionIdx = 2,
                GUIName = 812009, GUICategory = CardGUICategory.Kit, GUIType = "char", GUITextureRef = "DLC_MPImages.Cards.KitFBotINF",
                PlayerVariableIds = [602],
                Pools = [new(StorePools.FreeGoldChar), new(StorePools.GoldChar), new(StorePools.GoldBackup)],
            },
            new()
            {
                UniqueName = "AdeptDrell", Kind = ReinforcementKind.KitUnlock, Rarity = CardRarity.Uncommon, MaxCount = 5, VersionIdx = 1,
                GUIName = 711377, GUICategory = CardGUICategory.Kit, GUIType = "char", GUITextureRef = "GUI_MPImages.Cards.KitDrell",
                PlayerVariableIds = [218],
                Pools = [new(StorePools.SilverBackup) { VersionIdx = 1 }, new(StorePools.SilverChar) { VersionIdx = 1 }],
            },
            new()
            {
                UniqueName = "VanguardDrell", Kind = ReinforcementKind.KitUnlock, Rarity = CardRarity.Rare, MaxCount = 5, VersionIdx = 2,
                GUIName = 711386, GUICategory = CardGUICategory.Kit, GUIType = "char", GUITextureRef = "GUI_MPImages.Cards.KitDrell",
                PlayerVariableIds = [227],
                Pools = [new(StorePools.GoldBackup) { VersionIdx = 2 }, new(StorePools.GoldChar) { VersionIdx = 2 }],
            },
            new()
            {
                UniqueName = "EngineerSalarian", Kind = ReinforcementKind.KitUnlock, Rarity = CardRarity.Uncommon, MaxCount = 5, VersionIdx = 1,
                GUIName = 711379, GUICategory = CardGUICategory.Kit, GUIType = "char", GUITextureRef = "GUI_MPImages.Cards.KitSalarian",
                PlayerVariableIds = [220],
                Pools = [new(StorePools.SilverBackup) { VersionIdx = 1 }, new(StorePools.SilverChar) { VersionIdx = 1 }],
            },
            new()
            {
                UniqueName = "InfiltratorSalarian", Kind = ReinforcementKind.KitUnlock, Rarity = CardRarity.Rare, MaxCount = 5, VersionIdx = 2,
                GUIName = 711380, GUICategory = CardGUICategory.Kit, GUIType = "char", GUITextureRef = "GUI_MPImages.Cards.KitSalarian",
                PlayerVariableIds = [221],
                Pools = [new(StorePools.GoldBackup) { VersionIdx = 2 }, new(StorePools.GoldChar) { VersionIdx = 2 }],
            },
            new()
            {
                UniqueName = "InfiltratorQuarian", Kind = ReinforcementKind.KitUnlock, Rarity = CardRarity.Uncommon, MaxCount = 5, VersionIdx = 1,
                GUIName = 711381, GUICategory = CardGUICategory.Kit, GUIType = "char", GUITextureRef = "GUI_MPImages.Cards.KitQuarian",
                PlayerVariableIds = [222],
                Pools = [new(StorePools.SilverBackup) { VersionIdx = 1 }, new(StorePools.SilverChar) { VersionIdx = 1 }],
            },
            new()
            {
                UniqueName = "EngineerQuarian", Kind = ReinforcementKind.KitUnlock, Rarity = CardRarity.Rare, MaxCount = 5, VersionIdx = 2,
                GUIName = 711378, GUICategory = CardGUICategory.Kit, GUIType = "char", GUITextureRef = "GUI_MPImages.Cards.KitQuarian",
                PlayerVariableIds = [219],
                Pools = [new(StorePools.GoldBackup) { VersionIdx = 2 }, new(StorePools.GoldChar) { VersionIdx = 2 }],
            },
            new()
            {
                UniqueName = "SentinelTurian", Kind = ReinforcementKind.KitUnlock, Rarity = CardRarity.Uncommon, MaxCount = 5, VersionIdx = 1,
                GUIName = 711382, GUICategory = CardGUICategory.Kit, GUIType = "char", GUITextureRef = "GUI_MPImages.Cards.KitTurian",
                PlayerVariableIds = [223],
                Pools = [new(StorePools.SilverBackup) { VersionIdx = 1 }, new(StorePools.SilverChar) { VersionIdx = 1 }],
            },
            new()
            {
                UniqueName = "SoldierTurian", Kind = ReinforcementKind.KitUnlock, Rarity = CardRarity.Uncommon, MaxCount = 5, VersionIdx = 1,
                GUIName = 711385, GUICategory = CardGUICategory.Kit, GUIType = "char", GUITextureRef = "GUI_MPImages.Cards.KitTurian",
                PlayerVariableIds = [226],
                Pools = [new(StorePools.SilverBackup) { VersionIdx = 1 }, new(StorePools.SilverChar) { VersionIdx = 1 }],
            },
            new()
            {
                UniqueName = "VanguardAsari", Kind = ReinforcementKind.KitUnlock, Rarity = CardRarity.Uncommon, MaxCount = 5, VersionIdx = 1,
                GUIName = 711387, GUICategory = CardGUICategory.Kit, GUIType = "char", GUITextureRef = "GUI_MPImages.Cards.KitAsari",
                PlayerVariableIds = [228],
                Pools = [new(StorePools.SilverBackup) { VersionIdx = 1 }, new(StorePools.SilverChar) { VersionIdx = 1 }],
            },
            new()
            {
                UniqueName = "AdeptAsari", Kind = ReinforcementKind.KitUnlock, Rarity = CardRarity.Rare, MaxCount = 5, VersionIdx = 2,
                GUIName = 711376, GUICategory = CardGUICategory.Kit, GUIType = "char", GUITextureRef = "GUI_MPImages.Cards.KitAsari",
                PlayerVariableIds = [217],
                Pools = [new(StorePools.GoldBackup) { VersionIdx = 2 }, new(StorePools.GoldChar) { VersionIdx = 2 }],
            },
            new()
            {
                UniqueName = "SentinelKrogan", Kind = ReinforcementKind.KitUnlock, Rarity = CardRarity.Rare, MaxCount = 5, VersionIdx = 2,
                GUIName = 711383, GUICategory = CardGUICategory.Kit, GUIType = "char", GUITextureRef = "GUI_MPImages.Cards.KitKrogan",
                PlayerVariableIds = [224],
                Pools = [new(StorePools.GoldBackup) { VersionIdx = 2 }, new(StorePools.GoldChar) { VersionIdx = 2 }],
            },
            new()
            {
                UniqueName = "SoldierKrogan", Kind = ReinforcementKind.KitUnlock, Rarity = CardRarity.Rare, MaxCount = 5, VersionIdx = 2,
                GUIName = 711384, GUICategory = CardGUICategory.Kit, GUIType = "char", GUITextureRef = "GUI_MPImages.Cards.KitKrogan",
                PlayerVariableIds = [225],
                Pools = [new(StorePools.GoldBackup) { VersionIdx = 2 }, new(StorePools.GoldChar) { VersionIdx = 2 }],
            },
            new()
            {
                UniqueName = "EngineerGeth", Kind = ReinforcementKind.KitUnlock, Rarity = CardRarity.Rare, MaxCount = 4, VersionIdx = 2,
                GUIName = 727591, GUICategory = CardGUICategory.Kit, GUIType = "char", GUITextureRef = "DLC_MPImages.Cards.KitGethEngineer",
                PlayerVariableIds = [238],
                Pools = [new(StorePools.GoldBackup), new(StorePools.GoldChar)],
            },
            new()
            {
                UniqueName = "InfiltratorGeth", Kind = ReinforcementKind.KitUnlock, Rarity = CardRarity.Rare, MaxCount = 4, VersionIdx = 2,
                GUIName = 727592, GUICategory = CardGUICategory.Kit, GUIType = "char", GUITextureRef = "DLC_MPImages.Cards.KitGethInfiltrator",
                PlayerVariableIds = [239],
                Pools = [new(StorePools.GoldBackup), new(StorePools.GoldChar)],
            },
            new()
            {
                UniqueName = "SoldierBatarian", Kind = ReinforcementKind.KitUnlock, Rarity = CardRarity.Rare, MaxCount = 5, VersionIdx = 2,
                GUIName = 728174, GUICategory = CardGUICategory.Kit, GUIType = "char", GUITextureRef = "DLC_MPImages.Cards.KitBatarian",
                PlayerVariableIds = [240],
                Pools = [new(StorePools.GoldBackup), new(StorePools.GoldChar)],
            },
            new()
            {
                UniqueName = "SentinelBatarian", Kind = ReinforcementKind.KitUnlock, Rarity = CardRarity.Rare, MaxCount = 5, VersionIdx = 2,
                GUIName = 728173, GUICategory = CardGUICategory.Kit, GUIType = "char", GUITextureRef = "DLC_MPImages.Cards.KitBatarian",
                PlayerVariableIds = [267],
                Pools = [new(StorePools.GoldBackup), new(StorePools.GoldChar)],
            },
            new()
            {
                UniqueName = "VanguardKrogan", Kind = ReinforcementKind.KitUnlock, Rarity = CardRarity.Rare, MaxCount = 5, VersionIdx = 2,
                GUIName = 340581, GUICategory = CardGUICategory.Kit, GUIType = "char", GUITextureRef = "DLC_MPImages.Cards.KitKroganBM",
                PlayerVariableIds = [272],
                Pools = [new(StorePools.GoldBackup), new(StorePools.GoldChar)],
            },
            new()
            {
                UniqueName = "AdeptAsariCommando", Kind = ReinforcementKind.KitUnlock, Rarity = CardRarity.Rare, MaxCount = 5, VersionIdx = 2,
                GUIName = 313998, GUICategory = CardGUICategory.Kit, GUIType = "char", GUITextureRef = "DLC_MPImages.Cards.KitAsariCommando",
                PlayerVariableIds = [273],
                Pools = [new(StorePools.GoldBackup), new(StorePools.GoldChar)],
            },
            new()
            {
                UniqueName = "EngineerQuarianMale", Kind = ReinforcementKind.KitUnlock, Rarity = CardRarity.Rare, MaxCount = 4, VersionIdx = 2,
                GUIName = 339567, GUICategory = CardGUICategory.Kit, GUIType = "char", GUITextureRef = "GUI_MPImages_MP2.KitQuarianM",
                PlayerVariableIds = [280],
                Pools = [new(StorePools.ConMP2Char), new(StorePools.GoldBackup), new(StorePools.GoldChar)],
            },
            new()
            {
                UniqueName = "InfiltratorQuarianMale", Kind = ReinforcementKind.KitUnlock, Rarity = CardRarity.Rare, MaxCount = 4, VersionIdx = 2,
                GUIName = 711381, GUICategory = CardGUICategory.Kit, GUIType = "char", GUITextureRef = "GUI_MPImages_MP2.KitQuarianM",
                PlayerVariableIds = [281],
                Pools = [new(StorePools.ConMP2Char), new(StorePools.GoldBackup), new(StorePools.GoldChar)],
            },
            new()
            {
                UniqueName = "SoldierVorcha", Kind = ReinforcementKind.KitUnlock, Rarity = CardRarity.Rare, MaxCount = 5, VersionIdx = 2,
                GUIName = 731344, GUICategory = CardGUICategory.Kit, GUIType = "char", GUITextureRef = "GUI_MPImages_MP2.KitVorcha",
                PlayerVariableIds = [278],
                Pools = [new(StorePools.ConMP2Char), new(StorePools.GoldBackup), new(StorePools.GoldChar)],
            },
            new()
            {
                UniqueName = "SentinelVorcha", Kind = ReinforcementKind.KitUnlock, Rarity = CardRarity.Rare, MaxCount = 5, VersionIdx = 2,
                GUIName = 731345, GUICategory = CardGUICategory.Kit, GUIType = "char", GUITextureRef = "GUI_MPImages_MP2.KitVorcha",
                PlayerVariableIds = [279],
                Pools = [new(StorePools.ConMP2Char), new(StorePools.GoldBackup), new(StorePools.GoldChar)],
            },
            new()
            {
                UniqueName = "VanguardHumanMaleCerberus", Kind = ReinforcementKind.KitUnlock, Rarity = CardRarity.Rare, MaxCount = 4, VersionIdx = 2,
                GUIName = 727968, GUICategory = CardGUICategory.Kit, GUIType = "char", GUITextureRef = "GUI_MPImages_MP2.KitXCerberus",
                PlayerVariableIds = [283],
                Pools = [new(StorePools.ConMP2Char), new(StorePools.GoldBackup), new(StorePools.GoldChar)],
            },
            new()
            {
                UniqueName = "AdeptHumanMaleCerberus", Kind = ReinforcementKind.KitUnlock, Rarity = CardRarity.Rare, MaxCount = 4, VersionIdx = 2,
                GUIName = 727969, GUICategory = CardGUICategory.Kit, GUIType = "char", GUITextureRef = "GUI_MPImages_MP2.KitXCerberus",
                PlayerVariableIds = [282],
                Pools = [new(StorePools.ConMP2Char), new(StorePools.GoldBackup), new(StorePools.GoldChar)],
            },
            new()
            {
                UniqueName = "EngineerN7", Kind = ReinforcementKind.KitUnlock, Rarity = CardRarity.Rare, MaxCount = 4, VersionIdx = 2,
                GUIName = 745672, GUICategory = CardGUICategory.Kit, GUIType = "char", GUITextureRef = "GUI_MPImages_MP3.KitAllianceENG",
                PlayerVariableIds = [374],
                Pools = [new(StorePools.GoldBackup), new(StorePools.GoldChar), new(StorePools.ConMP3Char)],
            },
            new()
            {
                UniqueName = "InfiltratorN7", Kind = ReinforcementKind.KitUnlock, Rarity = CardRarity.Rare, MaxCount = 4, VersionIdx = 2,
                GUIName = 745673, GUICategory = CardGUICategory.Kit, GUIType = "char", GUITextureRef = "GUI_MPImages_MP3.KitAllianceINF",
                PlayerVariableIds = [377],
                Pools = [new(StorePools.GoldBackup), new(StorePools.GoldChar), new(StorePools.ConMP3Char)],
            },
            new()
            {
                UniqueName = "VanguardN7", Kind = ReinforcementKind.KitUnlock, Rarity = CardRarity.Rare, MaxCount = 4, VersionIdx = 2,
                GUIName = 745674, GUICategory = CardGUICategory.Kit, GUIType = "char", GUITextureRef = "GUI_MPImages_MP3.KitAllianceVAN",
                PlayerVariableIds = [376],
                Pools = [new(StorePools.GoldBackup), new(StorePools.GoldChar), new(StorePools.ConMP3Char)],
            },
            new()
            {
                UniqueName = "SoldierN7", Kind = ReinforcementKind.KitUnlock, Rarity = CardRarity.Rare, MaxCount = 4, VersionIdx = 2,
                GUIName = 745670, GUICategory = CardGUICategory.Kit, GUIType = "char", GUITextureRef = "GUI_MPImages_MP3.KitAllianceSOL",
                PlayerVariableIds = [378],
                Pools = [new(StorePools.GoldBackup), new(StorePools.GoldChar), new(StorePools.ConMP3Char)],
            },
            new()
            {
                UniqueName = "SentinelN7", Kind = ReinforcementKind.KitUnlock, Rarity = CardRarity.Rare, MaxCount = 4, VersionIdx = 2,
                GUIName = 745671, GUICategory = CardGUICategory.Kit, GUIType = "char", GUITextureRef = "GUI_MPImages_MP3.KitAllianceSEN",
                PlayerVariableIds = [375],
                Pools = [new(StorePools.GoldBackup), new(StorePools.GoldChar), new(StorePools.ConMP3Char)],
            },
            new()
            {
                UniqueName = "AdeptN7", Kind = ReinforcementKind.KitUnlock, Rarity = CardRarity.Rare, MaxCount = 4, VersionIdx = 2,
                GUIName = 745675, GUICategory = CardGUICategory.Kit, GUIType = "char", GUITextureRef = "GUI_MPImages_MP3.KitAllianceADP",
                PlayerVariableIds = [373],
                Pools = [new(StorePools.GoldBackup), new(StorePools.GoldChar), new(StorePools.ConMP3Char)],
            },
            new()
            {
                UniqueName = "EngineerVolus", Kind = ReinforcementKind.KitUnlock, Rarity = CardRarity.UltraRare, MaxCount = 4, VersionIdx = 2,
                GUIName = 765342, GUICategory = CardGUICategory.Kit, GUIType = "char", GUITextureRef = "GUI_MPImages_MP4.KitVolusENG",
                PlayerVariableIds = [501],
                Pools = [new(StorePools.UltraRareChar)],
            },
            new()
            {
                UniqueName = "AdeptVolus", Kind = ReinforcementKind.KitUnlock, Rarity = CardRarity.UltraRare, MaxCount = 4, VersionIdx = 2,
                GUIName = 765341, GUICategory = CardGUICategory.Kit, GUIType = "char", GUITextureRef = "GUI_MPImages_MP4.KitVolusADP",
                PlayerVariableIds = [500],
                Pools = [new(StorePools.UltraRareChar)],
            },
            new()
            {
                UniqueName = "N7SoldierTurian", Kind = ReinforcementKind.KitUnlock, Rarity = CardRarity.Rare, MaxCount = 4, VersionIdx = 2,
                GUIName = 766462, GUICategory = CardGUICategory.Kit, GUIType = "char", GUITextureRef = "GUI_MPImages_MP4.KitTurianSLD",
                PlayerVariableIds = [480],
                Pools = [new(StorePools.GoldChar), new(StorePools.GoldBackup)],
            },
            new()
            {
                UniqueName = "N7InfiltratorTurian", Kind = ReinforcementKind.KitUnlock, Rarity = CardRarity.Rare, MaxCount = 4, VersionIdx = 2,
                GUIName = 766463, GUICategory = CardGUICategory.Kit, GUIType = "char", GUITextureRef = "GUI_MPImages_MP4.KitTurianINF",
                PlayerVariableIds = [481],
                Pools = [new(StorePools.GoldChar), new(StorePools.GoldBackup)],
            },
            new()
            {
                UniqueName = "AdeptKrogan", Kind = ReinforcementKind.KitUnlock, Rarity = CardRarity.Rare, MaxCount = 5, VersionIdx = 2,
                GUIName = 768065, GUICategory = CardGUICategory.Kit, GUIType = "char", GUITextureRef = "GUI_MPImages_MP4.KitKroganADP",
                PlayerVariableIds = [514],
                Pools = [new(StorePools.GoldChar), new(StorePools.GoldBackup)],
            },
            new()
            {
                UniqueName = "EngineerTurian", Kind = ReinforcementKind.KitUnlock, Rarity = CardRarity.Rare, MaxCount = 4, VersionIdx = 2,
                GUIName = 768066, GUICategory = CardGUICategory.Kit, GUIType = "char", GUITextureRef = "GUI_MPImages_MP4.KitTurianENG",
                PlayerVariableIds = [503],
                Pools = [new(StorePools.GoldChar), new(StorePools.GoldBackup)],
            },
            new()
            {
                UniqueName = "InfiltratorDrell", Kind = ReinforcementKind.KitUnlock, Rarity = CardRarity.Rare, MaxCount = 5, VersionIdx = 2,
                GUIName = 768067, GUICategory = CardGUICategory.Kit, GUIType = "char", GUITextureRef = "GUI_MPImages_MP4.KitDrellINF",
                PlayerVariableIds = [504],
                Pools = [new(StorePools.GoldChar), new(StorePools.GoldBackup)],
            },
            new()
            {
                UniqueName = "SentinelVolus", Kind = ReinforcementKind.KitUnlock, Rarity = CardRarity.Rare, MaxCount = 4, VersionIdx = 2,
                GUIName = 768068, GUICategory = CardGUICategory.Kit, GUIType = "char", GUITextureRef = "GUI_MPImages_MP4.KitVolusENG2",
                PlayerVariableIds = [505],
                Pools = [new(StorePools.GoldChar), new(StorePools.GoldBackup)],
            },
            new()
            {
                UniqueName = "SoldierGeth", Kind = ReinforcementKind.KitUnlock, Rarity = CardRarity.Rare, MaxCount = 4, VersionIdx = 2,
                GUIName = 768069, GUICategory = CardGUICategory.Kit, GUIType = "char", GUITextureRef = "GUI_MPImages_MP4.KitGethSLD",
                PlayerVariableIds = [506],
                Pools = [new(StorePools.GoldChar), new(StorePools.GoldBackup)],
            },
            new()
            {
                UniqueName = "VanguardVolus", Kind = ReinforcementKind.KitUnlock, Rarity = CardRarity.Rare, MaxCount = 4, VersionIdx = 2,
                GUIName = 768070, GUICategory = CardGUICategory.Kit, GUIType = "char", GUITextureRef = "GUI_MPImages_MP4.KitVolusVAN",
                PlayerVariableIds = [507],
                Pools = [new(StorePools.GoldChar), new(StorePools.GoldBackup)],
            },
            new()
            {
                UniqueName = "AdeptBatarian", Kind = ReinforcementKind.KitUnlock, Rarity = CardRarity.Rare, MaxCount = 5, VersionIdx = 2,
                GUIName = 768111, GUICategory = CardGUICategory.Kit, GUIType = "char", GUITextureRef = "GUI_MPImages_MP4.KitBatarianADP",
                PlayerVariableIds = [508],
                Pools = [new(StorePools.GoldChar), new(StorePools.GoldBackup)],
            },
            new()
            {
                UniqueName = "EngineerVorcha", Kind = ReinforcementKind.KitUnlock, Rarity = CardRarity.Rare, MaxCount = 5, VersionIdx = 2,
                GUIName = 768112, GUICategory = CardGUICategory.Kit, GUIType = "char", GUITextureRef = "GUI_MPImages_MP4.KitVorchaSEN",
                PlayerVariableIds = [509],
                Pools = [new(StorePools.GoldChar), new(StorePools.GoldBackup)],
            },
            new()
            {
                UniqueName = "InfiltratorAsari", Kind = ReinforcementKind.KitUnlock, Rarity = CardRarity.Rare, MaxCount = 5, VersionIdx = 2,
                GUIName = 768113, GUICategory = CardGUICategory.Kit, GUIType = "char", GUITextureRef = "GUI_MPImages_MP4.KitAsariINF",
                PlayerVariableIds = [510],
                Pools = [new(StorePools.GoldChar), new(StorePools.GoldBackup)],
            },
            new()
            {
                UniqueName = "SentinelAsari", Kind = ReinforcementKind.KitUnlock, Rarity = CardRarity.Rare, MaxCount = 5, VersionIdx = 2,
                GUIName = 768114, GUICategory = CardGUICategory.Kit, GUIType = "char", GUITextureRef = "GUI_MPImages_MP4.KitAsariSEN",
                PlayerVariableIds = [511],
                Pools = [new(StorePools.GoldChar), new(StorePools.GoldBackup)],
            },
            new()
            {
                UniqueName = "SoldierMQuarian", Kind = ReinforcementKind.KitUnlock, Rarity = CardRarity.Rare, MaxCount = 4, VersionIdx = 2,
                GUIName = 768115, GUICategory = CardGUICategory.Kit, GUIType = "char", GUITextureRef = "GUI_MPImages_MP4.KitQuarianSLD",
                PlayerVariableIds = [512],
                Pools = [new(StorePools.GoldChar), new(StorePools.GoldBackup)],
            },
            new()
            {
                UniqueName = "VanguardBatarian", Kind = ReinforcementKind.KitUnlock, Rarity = CardRarity.Rare, MaxCount = 5, VersionIdx = 2,
                GUIName = 768116, GUICategory = CardGUICategory.Kit, GUIType = "char", GUITextureRef = "GUI_MPImages_MP4.KitBatarianVAN",
                PlayerVariableIds = [513],
                Pools = [new(StorePools.GoldChar), new(StorePools.GoldBackup)],
            },
            new()
            {
                UniqueName = "SoldierHumanMaleBF3", Kind = ReinforcementKind.KitUnlock, Rarity = CardRarity.Rare, MaxCount = 1, VersionIdx = 2,
                GUIName = 723302, GUIDescription = 723303, GUIType = "char", GUITextureRef = "GUI_MPImages.Cards.KitSoldierMale",
                PlayerVariableIds = [268],
                Pools = [new(StorePools.GoldBackup), new(StorePools.GoldChar)],
            },
        ];
    }
}
