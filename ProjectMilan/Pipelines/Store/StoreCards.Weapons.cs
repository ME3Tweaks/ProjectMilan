using ProjectMilanCore.Config.Store;

namespace ProjectMilan.Pipelines.Store
{
    public static partial class StoreCards
    {
        /// <summary>
        /// Weapon cards.
        /// </summary>
        private static IEnumerable<StoreCard> Weapons =>
        [
            new()
            {
                UniqueName = "SFXGameContent.SFXWeapon_AssaultRifle_Avenger", Kind = ReinforcementKind.InventoryUnlock, Rarity = CardRarity.Common, MaxCount = 10,
                GUIName = 589047, GUIDescription = 339266, GUICategory = CardGUICategory.AssaultRifle, GUIType = "assault", GUITextureRef = "GUI_Icons.Weapons.asl_avenger_256x128",
                PlayerVariableIds = [0],
                Pools =
                [
                    new(StorePools.BronzeWeapon),
                    new(StorePools.GoldCommonWeapon) { PVIncrementBonus = 1 },
                    new(StorePools.SilverCommonWeapon),
                ],
            },
            new()
            {
                UniqueName = "SFXGameContent.SFXWeapon_SniperRifle_Mantis", Kind = ReinforcementKind.InventoryUnlock, Rarity = CardRarity.Common, MaxCount = 10,
                GUIName = 209737, GUIDescription = 339320, GUICategory = CardGUICategory.SniperRifle, GUIType = "sniper", GUITextureRef = "GUI_Icons.Weapons.snp_mantis_256x128",
                PlayerVariableIds = [9],
                Pools =
                [
                    new(StorePools.BronzeWeapon),
                    new(StorePools.GoldCommonWeapon) { PVIncrementBonus = 1 },
                    new(StorePools.SilverCommonWeapon),
                ],
            },
            new()
            {
                UniqueName = "SFXGameContent.SFXWeapon_Pistol_Predator", Kind = ReinforcementKind.InventoryUnlock, Rarity = CardRarity.Common, MaxCount = 10,
                GUIName = 209732, GUIDescription = 339301, GUICategory = CardGUICategory.Pistol, GUIType = "pistol", GUITextureRef = "GUI_Icons.Weapons.pst_predator_256x128",
                PlayerVariableIds = [25],
                Pools =
                [
                    new(StorePools.BronzeWeapon),
                    new(StorePools.GoldCommonWeapon) { PVIncrementBonus = 1 },
                    new(StorePools.SilverCommonWeapon),
                ],
            },
            new()
            {
                UniqueName = "SFXGameContent.SFXWeapon_SMG_Shuriken", Kind = ReinforcementKind.InventoryUnlock, Rarity = CardRarity.Common, MaxCount = 10,
                GUIName = 209730, GUIDescription = 339296, GUICategory = CardGUICategory.SMG, GUIType = "smg", GUITextureRef = "GUI_Icons.Weapons.smg_shuriken_256x128",
                PlayerVariableIds = [29],
                Pools =
                [
                    new(StorePools.BronzeWeapon),
                    new(StorePools.GoldCommonWeapon) { PVIncrementBonus = 1 },
                    new(StorePools.SilverCommonWeapon),
                ],
            },
            new()
            {
                UniqueName = "SFXGameContent.SFXWeapon_Shotgun_Katana", Kind = ReinforcementKind.InventoryUnlock, Rarity = CardRarity.Common, MaxCount = 10,
                GUIName = 209734, GUIDescription = 339313, GUICategory = CardGUICategory.Shotgun, GUIType = "shotgun", GUITextureRef = "GUI_Icons.Weapons.bls_katana_256x128",
                PlayerVariableIds = [17],
                Pools =
                [
                    new(StorePools.BronzeWeapon),
                    new(StorePools.GoldCommonWeapon) { PVIncrementBonus = 1 },
                    new(StorePools.SilverCommonWeapon),
                ],
            },
            new()
            {
                UniqueName = "SFXGameContent.SFXWeapon_AssaultRifle_Cobra", Kind = ReinforcementKind.InventoryUnlock, Rarity = CardRarity.Uncommon, MaxCount = 10,
                GUIName = 634278, GUIDescription = 634280, GUICategory = CardGUICategory.AssaultRifle, GUIType = "assault", GUITextureRef = "GUI_Icons.Weapons.asl_cobra_256x128",
                PlayerVariableIds = [4],
                Pools = [new(StorePools.GoldCommonWeapon), new(StorePools.SilverWeapon), new(StorePools.SilverBackup)],
            },
            new()
            {
                UniqueName = "SFXGameContent.SFXWeapon_AssaultRifle_Vindicator", Kind = ReinforcementKind.InventoryUnlock, Rarity = CardRarity.Uncommon, MaxCount = 10,
                GUIName = 621121, GUIDescription = 621123, GUICategory = CardGUICategory.AssaultRifle, GUIType = "assault", GUITextureRef = "GUI_Icons.Weapons.asl_vindicator_256x128",
                PlayerVariableIds = [7],
                Pools = [new(StorePools.GoldCommonWeapon), new(StorePools.SilverWeapon), new(StorePools.SilverBackup)],
            },
            new()
            {
                UniqueName = "SFXGameContent.SFXWeapon_Shotgun_Scimitar", Kind = ReinforcementKind.InventoryUnlock, Rarity = CardRarity.Uncommon, MaxCount = 10,
                GUIName = 209735, GUIDescription = 339316, GUICategory = CardGUICategory.Shotgun, GUIType = "shotgun", GUITextureRef = "GUI_Icons.Weapons.bls_scimitar_256x128",
                PlayerVariableIds = [20],
                Pools = [new(StorePools.GoldCommonWeapon), new(StorePools.SilverWeapon), new(StorePools.SilverBackup)],
            },
            new()
            {
                UniqueName = "SFXGameContent.SFXWeapon_SniperRifle_Viper", Kind = ReinforcementKind.InventoryUnlock, Rarity = CardRarity.Uncommon, MaxCount = 10,
                GUIName = 209738, GUIDescription = 339322, GUICategory = CardGUICategory.SniperRifle, GUIType = "sniper", GUITextureRef = "GUI_Icons.Weapons.snp_viper_256x128",
                PlayerVariableIds = [12],
                Pools = [new(StorePools.GoldCommonWeapon), new(StorePools.SilverWeapon), new(StorePools.SilverBackup)],
            },
            new()
            {
                UniqueName = "SFXGameContent.SFXWeapon_SniperRifle_Raptor", Kind = ReinforcementKind.InventoryUnlock, Rarity = CardRarity.Uncommon, MaxCount = 10,
                GUIName = 551044, GUIDescription = 551046, GUICategory = CardGUICategory.SniperRifle, GUIType = "sniper", GUITextureRef = "GUI_Icons.Weapons.snp_raptor_256x128",
                PlayerVariableIds = [10],
                Pools = [new(StorePools.GoldCommonWeapon), new(StorePools.SilverWeapon), new(StorePools.SilverBackup)],
            },
            new()
            {
                UniqueName = "SFXGameContent.SFXWeapon_Pistol_Phalanx", Kind = ReinforcementKind.InventoryUnlock, Rarity = CardRarity.Uncommon, MaxCount = 10,
                GUIName = 546166, GUIDescription = 652049, GUICategory = CardGUICategory.Pistol, GUIType = "pistol", GUITextureRef = "GUI_Icons.Weapons.pst_phalanx_256x128",
                PlayerVariableIds = [24],
                Pools = [new(StorePools.GoldCommonWeapon), new(StorePools.SilverWeapon), new(StorePools.SilverBackup)],
            },
            new()
            {
                UniqueName = "SFXGameContent.SFXWeapon_AssaultRifle_Mattock", Kind = ReinforcementKind.InventoryUnlock, Rarity = CardRarity.Uncommon, MaxCount = 10,
                GUIName = 545842, GUIDescription = 619710, GUICategory = CardGUICategory.AssaultRifle, GUIType = "assault", GUITextureRef = "GUI_Icons.Weapons.asl_mattock_256x128",
                PlayerVariableIds = [3],
                Pools = [new(StorePools.GoldCommonWeapon), new(StorePools.SilverWeapon), new(StorePools.SilverBackup)],
            },
            new()
            {
                UniqueName = "SFXGameContent.SFXWeapon_SMG_Tempest", Kind = ReinforcementKind.InventoryUnlock, Rarity = CardRarity.Uncommon, MaxCount = 10,
                GUIName = 209731, GUIDescription = 339299, GUICategory = CardGUICategory.SMG, GUIType = "smg", GUITextureRef = "GUI_Icons.Weapons.smg_tempest_256x128",
                PlayerVariableIds = [30],
                Pools = [new(StorePools.GoldCommonWeapon), new(StorePools.SilverWeapon), new(StorePools.SilverBackup)],
            },
            new()
            {
                UniqueName = "SFXGameContent.SFXWeapon_SMG_Locust", Kind = ReinforcementKind.InventoryUnlock, Rarity = CardRarity.Uncommon, MaxCount = 10,
                GUIName = 546170, GUIDescription = 619711, GUICategory = CardGUICategory.SMG, GUIType = "smg", GUITextureRef = "GUI_Icons.Weapons.smg_locust_256x128",
                PlayerVariableIds = [27],
                Pools = [new(StorePools.GoldCommonWeapon), new(StorePools.SilverWeapon), new(StorePools.SilverBackup)],
            },
            new()
            {
                UniqueName = "SFXGameContent.SFXWeapon_Shotgun_Eviscerator", Kind = ReinforcementKind.InventoryUnlock, Rarity = CardRarity.Uncommon, MaxCount = 10,
                GUIName = 314330, GUIDescription = 352863, GUICategory = CardGUICategory.Shotgun, GUIType = "shotgun", GUITextureRef = "GUI_Icons.Weapons.bls_eviscerator_256x128",
                PlayerVariableIds = [15],
                Pools = [new(StorePools.GoldCommonWeapon), new(StorePools.SilverWeapon), new(StorePools.SilverBackup)],
            },
            new()
            {
                UniqueName = "SFXGameContent.SFXWeapon_SniperRifle_Incisor", Kind = ReinforcementKind.InventoryUnlock, Rarity = CardRarity.Uncommon, MaxCount = 10,
                GUIName = 546171, GUIDescription = 351820, GUICategory = CardGUICategory.SniperRifle, GUIType = "sniper", GUITextureRef = "GUI_Icons.Weapons.snp_incisor_256x128",
                PlayerVariableIds = [8],
                Pools = [new(StorePools.GoldCommonWeapon), new(StorePools.SilverWeapon), new(StorePools.SilverBackup)],
            },
            new()
            {
                UniqueName = "SFXGameContent.SFXWeapon_AssaultRifle_Falcon", Kind = ReinforcementKind.InventoryUnlock, Rarity = CardRarity.Rare, MaxCount = 10,
                GUIName = 550944, GUIDescription = 570666, GUICategory = CardGUICategory.AssaultRifle, GUIType = "assault", GUITextureRef = "GUI_Icons.Weapons.asl_falcon_256x128",
                PlayerVariableIds = [5],
                Pools = [new(StorePools.GoldWeapon), new(StorePools.GoldBackup)],
            },
            new()
            {
                UniqueName = "SFXGameContent.SFXWeapon_AssaultRifle_Revenant", Kind = ReinforcementKind.InventoryUnlock, Rarity = CardRarity.Rare, MaxCount = 10,
                GUIName = 209729, GUIDescription = 339279, GUICategory = CardGUICategory.AssaultRifle, GUIType = "assault", GUITextureRef = "GUI_Icons.Weapons.asl_revenant_256x128",
                PlayerVariableIds = [6],
                Pools = [new(StorePools.GoldWeapon), new(StorePools.GoldBackup)],
            },
            new()
            {
                UniqueName = "SFXGameContent.SFXWeapon_AssaultRifle_Geth", Kind = ReinforcementKind.InventoryUnlock, Rarity = CardRarity.Rare, MaxCount = 10,
                GUIName = 546169, GUIDescription = 339329, GUICategory = CardGUICategory.AssaultRifle, GUIType = "assault", GUITextureRef = "GUI_Icons.Weapons.asl_gethpulse_256x128",
                PlayerVariableIds = [2],
                Pools = [new(StorePools.GoldWeapon), new(StorePools.GoldBackup)],
            },
            new()
            {
                UniqueName = "SFXGameContent.SFXWeapon_Pistol_Thor", Kind = ReinforcementKind.InventoryUnlock, Rarity = CardRarity.Rare, MaxCount = 10,
                GUIName = 551034, GUIDescription = 551036, GUICategory = CardGUICategory.Pistol, GUIType = "pistol", GUITextureRef = "GUI_Icons.Weapons.pst_thor_256x128",
                PlayerVariableIds = [23],
                Pools = [new(StorePools.GoldWeapon), new(StorePools.GoldBackup)],
            },
            new()
            {
                UniqueName = "SFXGameContent.SFXWeapon_Pistol_Carnifex", Kind = ReinforcementKind.InventoryUnlock, Rarity = CardRarity.Rare, MaxCount = 10,
                GUIName = 209733, GUIDescription = 339305, GUICategory = CardGUICategory.Pistol, GUIType = "pistol", GUITextureRef = "GUI_Icons.Weapons.pst_carniflex_256x128",
                PlayerVariableIds = [21],
                Pools = [new(StorePools.GoldWeapon), new(StorePools.GoldBackup)],
            },
            new()
            {
                UniqueName = "SFXGameContent.SFXWeapon_SMG_Hornet", Kind = ReinforcementKind.InventoryUnlock, Rarity = CardRarity.Rare, MaxCount = 10,
                GUIName = 551028, GUIDescription = 551030, GUICategory = CardGUICategory.SMG, GUIType = "smg", GUITextureRef = "GUI_Icons.Weapons.smg_hornet_256x128",
                PlayerVariableIds = [28],
                Pools = [new(StorePools.GoldWeapon), new(StorePools.GoldBackup)],
            },
            new()
            {
                UniqueName = "SFXGameContent.SFXWeapon_Shotgun_Graal", Kind = ReinforcementKind.InventoryUnlock, Rarity = CardRarity.Rare, MaxCount = 10,
                GUIName = 551037, GUIDescription = 551039, GUICategory = CardGUICategory.Shotgun, GUIType = "shotgun", GUITextureRef = "GUI_Icons.Weapons.bls_graal_256x128",
                PlayerVariableIds = [18],
                Pools = [new(StorePools.GoldWeapon), new(StorePools.GoldBackup)],
            },
            new()
            {
                UniqueName = "SFXGameContent.SFXWeapon_Shotgun_Claymore", Kind = ReinforcementKind.InventoryUnlock, Rarity = CardRarity.Rare, MaxCount = 10,
                GUIName = 209736, GUIDescription = 339318, GUICategory = CardGUICategory.Shotgun, GUIType = "shotgun", GUITextureRef = "GUI_Icons.Weapons.bls_claymore_256x128",
                PlayerVariableIds = [14],
                Pools = [new(StorePools.GoldWeapon), new(StorePools.GoldBackup)],
            },
            new()
            {
                UniqueName = "SFXGameContent.SFXWeapon_Shotgun_Disciple", Kind = ReinforcementKind.InventoryUnlock, Rarity = CardRarity.Rare, MaxCount = 10,
                GUIName = 581148, GUIDescription = 581149, GUICategory = CardGUICategory.Shotgun, GUIType = "shotgun", GUITextureRef = "GUI_Icons.Weapons.bls_disciple_256x128",
                PlayerVariableIds = [19],
                Pools = [new(StorePools.GoldWeapon), new(StorePools.GoldBackup)],
            },
            new()
            {
                UniqueName = "SFXGameContent.SFXWeapon_Shotgun_Geth", Kind = ReinforcementKind.InventoryUnlock, Rarity = CardRarity.Rare, MaxCount = 10,
                GUIName = 560869, GUIDescription = 560871, GUICategory = CardGUICategory.Shotgun, GUIType = "shotgun", GUITextureRef = "GUI_Icons.Weapons.bls_gethplasma_256x128",
                PlayerVariableIds = [16],
                Pools = [new(StorePools.GoldWeapon), new(StorePools.GoldBackup)],
            },
            new()
            {
                UniqueName = "SFXGameContent.SFXWeapon_SniperRifle_Widow", Kind = ReinforcementKind.InventoryUnlock, Rarity = CardRarity.Rare, MaxCount = 10,
                GUIName = 209739, GUIDescription = 339324, GUICategory = CardGUICategory.SniperRifle, GUIType = "sniper", GUITextureRef = "GUI_Icons.Weapons.snp_widow_256x128",
                PlayerVariableIds = [13],
                Pools = [new(StorePools.GoldWeapon), new(StorePools.GoldBackup)],
            },
            new()
            {
                UniqueName = "SFXGameContent.SFXWeapon_Pistol_Scorpion", Kind = ReinforcementKind.InventoryUnlock, Rarity = CardRarity.UltraRare, MaxCount = 10,
                GUIName = 551025, GUIDescription = 551027, GUICategory = CardGUICategory.Pistol, GUIType = "pistol", GUITextureRef = "GUI_Icons.Weapons.pst_scorpion_256x128",
                PlayerVariableIds = [26],
                Pools = [new(StorePools.GoldUltraRare), new(StorePools.NewUltraRare) { MaxCount = 1 }],
            },
            new()
            {
                UniqueName = "SFXGameContent.SFXWeapon_SniperRifle_Javelin", Kind = ReinforcementKind.InventoryUnlock, Rarity = CardRarity.UltraRare, MaxCount = 10,
                GUIName = 551047, GUIDescription = 551049, GUICategory = CardGUICategory.SniperRifle, GUIType = "sniper", GUITextureRef = "GUI_Icons.Weapons.snp_javelin_256x128",
                PlayerVariableIds = [11],
                Pools = [new(StorePools.GoldUltraRare), new(StorePools.NewUltraRare) { MaxCount = 1 }],
            },
            new()
            {
                UniqueName = "SFXGameContent.SFXWeapon_AssaultRifle_Saber", Kind = ReinforcementKind.InventoryUnlock, Rarity = CardRarity.UltraRare, MaxCount = 10,
                GUIName = 676841, GUIDescription = 676842, GUICategory = CardGUICategory.AssaultRifle, GUIType = "assault", GUITextureRef = "GUI_Icons.Weapons.asl_saber_256x128",
                PlayerVariableIds = [135],
                Pools = [new(StorePools.GoldUltraRare), new(StorePools.NewUltraRare) { MaxCount = 1 }],
            },
            new()
            {
                UniqueName = "SFXGameContent.SFXWeapon_Pistol_Talon", Kind = ReinforcementKind.InventoryUnlock, Rarity = CardRarity.UltraRare, MaxCount = 10,
                GUIName = 551031, GUIDescription = 551033, GUICategory = CardGUICategory.Pistol, GUIType = "pistol", GUITextureRef = "GUI_Icons.Weapons.pst_talon_256x128",
                PlayerVariableIds = [22],
                Pools = [new(StorePools.GoldUltraRare), new(StorePools.NewUltraRare) { MaxCount = 1 }],
            },
            new()
            {
                UniqueName = "SFXGameContent.SFXWeapon_SniperRifle_BlackWidow", Kind = ReinforcementKind.InventoryUnlock, Rarity = CardRarity.UltraRare, MaxCount = 10,
                GUIName = 692577, GUIDescription = 707215, GUICategory = CardGUICategory.SniperRifle, GUIType = "sniper", GUITextureRef = "GUI_Icons.Weapons.snp_blackwidow_256x128",
                PlayerVariableIds = [136],
                Pools = [new(StorePools.GoldUltraRare), new(StorePools.NewUltraRare) { MaxCount = 1 }],
            },
            new()
            {
                UniqueName = "SFXGameContent.SFXWeapon_Pistol_Ivory", Kind = ReinforcementKind.InventoryUnlock, Rarity = CardRarity.UltraRare, MaxCount = 10,
                GUIName = 704673, GUIDescription = 707217, GUICategory = CardGUICategory.Pistol, GUIType = "pistol", GUITextureRef = "GUI_Icons.Weapons.pst_ivory_256x128",
                PlayerVariableIds = [138],
                Pools = [new(StorePools.GoldUltraRare), new(StorePools.NewUltraRare) { MaxCount = 1 }],
            },
            new()
            {
                UniqueName = "SFXGameContent.SFXWeapon_Shotgun_Striker", Kind = ReinforcementKind.InventoryUnlock, Rarity = CardRarity.UltraRare, MaxCount = 10,
                GUIName = 709355, GUIDescription = 707213, GUICategory = CardGUICategory.Shotgun, GUIType = "shotgun", GUITextureRef = "GUI_Icons.Weapons.bls_striker_256x128",
                PlayerVariableIds = [137],
                Pools = [new(StorePools.GoldUltraRare), new(StorePools.NewUltraRare) { MaxCount = 1 }],
            },
            new()
            {
                UniqueName = "SFXGameContentDLC_CON_MP1.SFXWeapon_AssaultRifle_Krogan", Kind = ReinforcementKind.InventoryUnlock, Rarity = CardRarity.Rare, MaxCount = 10,
                GUIName = 728040, GUIDescription = 728041, GUICategory = CardGUICategory.AssaultRifle, GUIType = "assault", GUITextureRef = "DLC_MPImages.Weapons.asl_krogan_256x128",
                PlayerVariableIds = [274],
                Pools = [new(StorePools.GoldWeapon), new(StorePools.GoldBackup)],
            },
            new()
            {
                UniqueName = "SFXGameContentDLC_CON_MP1.SFXWeapon_SniperRifle_Batarian", Kind = ReinforcementKind.InventoryUnlock, Rarity = CardRarity.Rare, MaxCount = 10,
                GUIName = 728034, GUIDescription = 728035, GUICategory = CardGUICategory.SniperRifle, GUIType = "sniper", GUITextureRef = "DLC_MPImages.Weapons.snp_batarian_256x128",
                PlayerVariableIds = [275],
                Pools = [new(StorePools.GoldWeapon), new(StorePools.GoldBackup)],
            },
            new()
            {
                UniqueName = "SFXGameContentDLC_CON_MP1.SFXWeapon_SMG_Geth", Kind = ReinforcementKind.InventoryUnlock, Rarity = CardRarity.Rare, MaxCount = 10,
                GUIName = 728037, GUIDescription = 728038, GUICategory = CardGUICategory.SMG, GUIType = "smg", GUITextureRef = "DLC_MPImages.Weapons.smg_geth_256x128",
                PlayerVariableIds = [276],
                Pools = [new(StorePools.GoldWeapon), new(StorePools.GoldBackup)],
            },
            new()
            {
                UniqueName = "SFXGameContentDLC_CON_MP2.SFXWeapon_SniperRifle_Turian", Kind = ReinforcementKind.InventoryUnlock, Rarity = CardRarity.Rare, MaxCount = 10,
                GUIName = 731640, GUIDescription = 731641, GUICategory = CardGUICategory.SniperRifle, GUIType = "sniper", GUITextureRef = "GUI_MPImages_MP2.snp_turian_256x128",
                PlayerVariableIds = [288],
                Pools = [new(StorePools.ConMP2Gun), new(StorePools.GoldWeapon), new(StorePools.GoldBackup)],
            },
            new()
            {
                UniqueName = "SFXGameContentDLC_CON_MP2.SFXWeapon_Shotgun_Quarian", Kind = ReinforcementKind.InventoryUnlock, Rarity = CardRarity.Rare, MaxCount = 10,
                GUIName = 731638, GUIDescription = 731637, GUICategory = CardGUICategory.Shotgun, GUIType = "shotgun", GUITextureRef = "GUI_MPImages_MP2.bls_quarian_256x128",
                PlayerVariableIds = [287],
                Pools = [new(StorePools.ConMP2Gun), new(StorePools.GoldWeapon), new(StorePools.GoldBackup)],
            },
            new()
            {
                UniqueName = "SFXGameContentDLC_CON_MP3.SFXWeapon_Pistol_Asari", Kind = ReinforcementKind.InventoryUnlock, Rarity = CardRarity.Rare, MaxCount = 10,
                GUIName = 744302, GUIDescription = 744303, GUICategory = CardGUICategory.Pistol, GUIType = "pistol", GUITextureRef = "GUI_MPImages_MP3.pst_acolyte_256x128",
                PlayerVariableIds = [470],
                Pools = [new(StorePools.GoldWeapon), new(StorePools.GoldBackup), new(StorePools.ConMP3Gun)],
            },
            new()
            {
                UniqueName = "SFXGameContentDLC_CON_MP3.SFXWeapon_Shotgun_Assault", Kind = ReinforcementKind.InventoryUnlock, Rarity = CardRarity.Rare, MaxCount = 10,
                GUIName = 744389, GUIDescription = 744425, GUICategory = CardGUICategory.Shotgun, GUIType = "shotgun", GUITextureRef = "GUI_MPImages_MP3.asl_N7Shotgun_256x128",
                PlayerVariableIds = [469],
                Pools = [new(StorePools.GoldWeapon), new(StorePools.GoldBackup), new(StorePools.ConMP3Gun)],
            },
            new()
            {
                UniqueName = "SFXGameContentDLC_CON_MP4.SFXWeapon_SniperRifle_Collector", Kind = ReinforcementKind.InventoryUnlock, Rarity = CardRarity.Rare, MaxCount = 10,
                GUIName = 766350, GUIDescription = 766351, GUICategory = CardGUICategory.AssaultRifle, GUIType = "sniper", GUITextureRef = "GUI_MPImages_MP4.snp_collector_256x128",
                PlayerVariableIds = [532],
                Pools = [new(StorePools.GoldWeapon)],
            },
            new()
            {
                UniqueName = "SFXGameContentDLC_CON_MP4.SFXWeapon_SMG_Collector", Kind = ReinforcementKind.InventoryUnlock, Rarity = CardRarity.UltraRare, MaxCount = 10,
                GUIName = 766347, GUIDescription = 766348, GUICategory = CardGUICategory.SMG, GUIType = "SMG", GUITextureRef = "GUI_MPImages_MP4.smg_collector_512x256",
                PlayerVariableIds = [533],
                Pools = [new(StorePools.GoldUltraRare)],
            },
            new()
            {
                UniqueName = "SFXGameContentDLC_CON_MP5.SFXWeapon_AssaultRifle_Lancer_MP", Kind = ReinforcementKind.InventoryUnlock, Rarity = CardRarity.UltraRare, MaxCount = 10,
                GUIName = 793101, GUIDescription = 793102, GUICategory = CardGUICategory.AssaultRifle, GUIType = "assault", GUITextureRef = "DLC_MPImages_MP5.WPN_MP5_Lancer_256x128",
                PlayerVariableIds = [623],
                Pools = [new(StorePools.GoldUltraRare)],
            },
            new()
            {
                UniqueName = "SFXGameContentDLC_CON_MP5.SFXWeapon_SMG_Bloodpack_MP", Kind = ReinforcementKind.InventoryUnlock, Rarity = CardRarity.UltraRare, MaxCount = 10,
                GUIName = 766089, GUIDescription = 766090, GUICategory = CardGUICategory.SMG, GUIType = "SMG", GUITextureRef = "DLC_MPImages_MP5.WPN_MP5_BloodpackSMG_256x128",
                PlayerVariableIds = [624],
                Pools = [new(StorePools.GoldUltraRare)],
            },
            new()
            {
                UniqueName = "SFXGameContentDLC_CON_MP5.SFXWeapon_Shotgun_Salarian_MP", Kind = ReinforcementKind.InventoryUnlock, Rarity = CardRarity.UltraRare, MaxCount = 10,
                GUIName = 788084, GUIDescription = 788542, GUICategory = CardGUICategory.Shotgun, GUIType = "shotgun", GUITextureRef = "DLC_MPImages_MP5.WPN_MP5_Salarian_256x128",
                PlayerVariableIds = [625],
                Pools = [new(StorePools.GoldUltraRare)],
            },
            new()
            {
                UniqueName = "SFXGameContentDLC_CON_MP5.SFXWeapon_AssaultRifle_Adas_MP", Kind = ReinforcementKind.InventoryUnlock, Rarity = CardRarity.Rare, MaxCount = 10,
                GUIName = 766086, GUIDescription = 766087, GUICategory = CardGUICategory.AssaultRifle, GUIType = "assault", GUITextureRef = "DLC_MPImages_MP5.WPN_MP5_Quarian_256x128",
                PlayerVariableIds = [627],
                Pools = [new(StorePools.GoldWeapon), new(StorePools.GoldBackup)],
            },
            new()
            {
                UniqueName = "SFXGameContentDLC_CON_MP5.SFXWeapon_Pistol_Bloodpack_MP", Kind = ReinforcementKind.InventoryUnlock, Rarity = CardRarity.Rare, MaxCount = 10,
                GUIName = 788082, GUIDescription = 788541, GUICategory = CardGUICategory.Pistol, GUIType = "pistol", GUITextureRef = "DLC_MPImages_MP5.WPN_MP5_Bloodpack_256x128",
                PlayerVariableIds = [628],
                Pools = [new(StorePools.GoldWeapon), new(StorePools.GoldBackup)],
            },
            new()
            {
                UniqueName = "SFXGameContentDLC_CON_MP5.SFXWeapon_Pistol_Silencer_MP", Kind = ReinforcementKind.InventoryUnlock, Rarity = CardRarity.Rare, MaxCount = 10,
                GUIName = 793182, GUIDescription = 793183, GUICategory = CardGUICategory.Pistol, GUIType = "pistol", GUITextureRef = "DLC_MPImages_MP5.WPN_MP5_carniflexSli_256x128",
                PlayerVariableIds = [629],
                Pools = [new(StorePools.GoldWeapon), new(StorePools.GoldBackup)],
            },
            new()
            {
                UniqueName = "SFXGameContent.SFXWeapon_AssaultRifle_Collector", Kind = ReinforcementKind.InventoryUnlock, Rarity = CardRarity.Rare, MaxCount = 10,
                GUIName = 341115, GUIDescription = 352864, GUICategory = CardGUICategory.AssaultRifle, GUIType = "assault", GUITextureRef = "GUI_Icons.Weapons.asl_collector_256x128",
                PlayerVariableIds = [1],
                Pools = [new(StorePools.GoldWeapon)],
            },
            new()
            {
                UniqueName = "SFXGameContentDLC_CON_MP2.SFXWeapon_AssaultRifle_Cerberus", Kind = ReinforcementKind.InventoryUnlock, Rarity = CardRarity.UltraRare, MaxCount = 10,
                GUIName = 731643, GUIDescription = 731644, GUICategory = CardGUICategory.AssaultRifle, GUIType = "assault", GUITextureRef = "GUI_MPImages_MP2.asl_cerberus_256x128",
                PlayerVariableIds = [286],
                Pools = [new(StorePools.ConMP2Gun), new(StorePools.NewUltraRare) { MaxCount = 1 }, new(StorePools.GoldUltraRare)],
            },
            new()
            {
                UniqueName = "SFXGameContentDLC_CON_MP2.SFXWeapon_AssaultRifle_Prothean_MP", Kind = ReinforcementKind.InventoryUnlock, Rarity = CardRarity.UltraRare, MaxCount = 10,
                GUIName = 727492, GUIDescription = 727493, GUICategory = CardGUICategory.AssaultRifle, GUIType = "assault", GUITextureRef = "GUI_PR_Images.asl_prothean_256x128",
                PlayerVariableIds = [358],
                Pools = [new(StorePools.ConMP2Gun), new(StorePools.NewUltraRare) { MaxCount = 1 }, new(StorePools.GoldUltraRare)],
            },
            new()
            {
                UniqueName = "SFXGameContent.SFXWeapon_Pistol_Eagle", Kind = ReinforcementKind.InventoryUnlock, Rarity = CardRarity.UltraRare, MaxCount = 10,
                GUIName = 650898, GUIDescription = 650900, GUICategory = CardGUICategory.Pistol, GUIType = "pistol", GUITextureRef = "GUI_Icons.Weapons.pst_eagle_256x128",
                PlayerVariableIds = [263],
                Pools = [new(StorePools.GoldUltraRare), new(StorePools.N7Weapon)],
            },
            new()
            {
                UniqueName = "SFXGameContent.SFXWeapon_Shotgun_Crusader", Kind = ReinforcementKind.InventoryUnlock, Rarity = CardRarity.UltraRare, MaxCount = 10,
                GUIName = 573102, GUIDescription = 573119, GUICategory = CardGUICategory.Shotgun, GUIType = "shotgun", GUITextureRef = "GUI_Icons.Weapons.bls_crusader_256x128",
                PlayerVariableIds = [262],
                Pools = [new(StorePools.GoldUltraRare), new(StorePools.N7Weapon)],
            },
            new()
            {
                UniqueName = "SFXGameContent.SFXWeapon_SniperRifle_Valiant", Kind = ReinforcementKind.InventoryUnlock, Rarity = CardRarity.UltraRare, MaxCount = 10,
                GUIName = 573104, GUIDescription = 573121, GUICategory = CardGUICategory.SniperRifle, GUIType = "sniper", GUITextureRef = "GUI_Icons.Weapons.snp_valiant_256x128",
                PlayerVariableIds = [110],
                Pools = [new(StorePools.GoldUltraRare), new(StorePools.N7Weapon)],
            },
            new()
            {
                UniqueName = "SFXGameContent.SFXWeapon_SniperRifle_Indra", Kind = ReinforcementKind.InventoryUnlock, Rarity = CardRarity.UltraRare, MaxCount = 10,
                GUIName = 573103, GUIDescription = 573120, GUICategory = CardGUICategory.SniperRifle, GUIType = "sniper", GUITextureRef = "GUI_Icons.Weapons.snp_indra_256x128",
                PlayerVariableIds = [369],
                Pools = [new(StorePools.GoldUltraRare), new(StorePools.NewUltraRare) { MaxCount = 1 }],
            },
            new()
            {
                UniqueName = "SFXGameContent.SFXWeapon_AssaultRifle_Valkyrie", Kind = ReinforcementKind.InventoryUnlock, Rarity = CardRarity.UltraRare, MaxCount = 10,
                GUIName = 573098, GUIDescription = 573116, GUICategory = CardGUICategory.AssaultRifle, GUIType = "assault", GUITextureRef = "GUI_Icons.Weapons.asl_valkyrie_256x128",
                PlayerVariableIds = [368],
                Pools = [new(StorePools.GoldUltraRare), new(StorePools.N7Weapon)],
            },
            new()
            {
                UniqueName = "SFXGameContent.SFXWeapon_AssaultRifle_Argus", Kind = ReinforcementKind.InventoryUnlock, Rarity = CardRarity.Rare, MaxCount = 10,
                GUIName = 573099, GUIDescription = 573117, GUICategory = CardGUICategory.AssaultRifle, GUIType = "assault", GUITextureRef = "GUI_Icons.Weapons.asl_carbine_256x128",
                PlayerVariableIds = [367],
                Pools = [new(StorePools.GoldWeapon), new(StorePools.GoldBackup)],
            },
            new()
            {
                UniqueName = "SFXGameContent.SFXWeapon_SMG_Hurricane", Kind = ReinforcementKind.InventoryUnlock, Rarity = CardRarity.UltraRare, MaxCount = 10,
                GUIName = 573100, GUIDescription = 573118, GUICategory = CardGUICategory.SMG, GUIType = "smg", GUITextureRef = "GUI_Icons.Weapons.smg_hurricane_256x128",
                PlayerVariableIds = [264],
                Pools = [new(StorePools.GoldUltraRare), new(StorePools.N7Weapon)],
            },
            new()
            {
                UniqueName = "SFXGameContent.SFXWeapon_Shotgun_Raider", Kind = ReinforcementKind.InventoryUnlock, Rarity = CardRarity.Rare, MaxCount = 10,
                GUIName = 573101, GUIDescription = 551043, GUICategory = CardGUICategory.Shotgun, GUIType = "shotgun", GUITextureRef = "GUI_Icons.Weapons.bls_raider_256x128",
                PlayerVariableIds = [370],
                Pools = [new(StorePools.GoldWeapon)],
            },
            new()
            {
                UniqueName = "SFXGameContentDLC_CON_MP3.SFXWeapon_AssaultRifle_LMG", Kind = ReinforcementKind.InventoryUnlock, Rarity = CardRarity.UltraRare, MaxCount = 10,
                GUIName = 744335, GUIDescription = 744336, GUICategory = CardGUICategory.AssaultRifle, GUIType = "assault", GUITextureRef = "GUI_MPImages_MP3.asl_N7LMG_256x128",
                PlayerVariableIds = [468],
                Pools = [new(StorePools.ConMP3Gun), new(StorePools.NewUltraRare) { MaxCount = 1 }, new(StorePools.GoldUltraRare)],
            },
            new()
            {
                UniqueName = "SFXGameContentDLC_CON_MP5.SFXWeapon_AssaultRifle_Spitfire", Kind = ReinforcementKind.InventoryUnlock, Rarity = CardRarity.UltraRare, MaxCount = 10,
                GUIName = 814438, GUIDescription = 814604, GUICategory = CardGUICategory.AssaultRifle, GUIType = "assault", GUITextureRef = "DLC_MPImages_MP5.WPN_MP5_Spitfire_256x128",
                PlayerVariableIds = [626],
                Pools = [new(StorePools.GoldUltraRare)],
            },
            new()
            {
                UniqueName = "SFXGameContent.SFXWeapon_AssaultRifle_Reckoning", Kind = ReinforcementKind.InventoryUnlock, Rarity = CardRarity.Rare, MaxCount = 10,
                GUIName = 708423, GUIDescription = 708424, GUICategory = CardGUICategory.AssaultRifle, GUIType = "assault", GUITextureRef = "GUI_Icons.Weapons.hvy_reckoning_256x128",
                PlayerVariableIds = [(int)MilanPlayerVariable.Card_Reckoning],
                Pools = [new(StorePools.GoldCommonWeapon)],
            },
        ];
    }
}
