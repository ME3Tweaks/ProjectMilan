using ProjectMilanCore.Config.Store;

namespace ProjectMilan.Pipelines.Store
{
    public static partial class StoreCards
    {
        /// <summary>
        /// Weapon mod cards.
        /// </summary>
        private static IEnumerable<StoreCard> WeaponMods =>
        [
            new()
            {
                UniqueName = "SFXGameContent.SFXWeaponMod_PistolAccuracy", Kind = ReinforcementKind.InventoryUnlock, Rarity = CardRarity.Common, MaxCount = 5,
                GUIName = 519359, GUIDescription = 711318, GUICategory = CardGUICategory.Mod, GUIType = "pistolmod", GUITextureRef = "GUI_Icons.Weapons.pst_sco_a_256x128",
                PlayerVariableIds = [47],
                Pools = [new(StorePools.BronzeMod), new(StorePools.GoldMod), new(StorePools.SilverMod)],
            },
            new()
            {
                UniqueName = "SFXGameContent.SFXWeaponMod_SMGMagSize", Kind = ReinforcementKind.InventoryUnlock, Rarity = CardRarity.Common, MaxCount = 5,
                GUIName = 519470, GUIDescription = 711326, GUICategory = CardGUICategory.Mod, GUIType = "smgmod", GUITextureRef = "GUI_Icons.Weapons.MOD_ammo-capacity_256x128",
                PlayerVariableIds = [54],
                Pools = [new(StorePools.BronzeMod), new(StorePools.GoldMod), new(StorePools.SilverMod)],
            },
            new()
            {
                UniqueName = "SFXGameContent.SFXWeaponMod_AssaultRifleStability", Kind = ReinforcementKind.InventoryUnlock, Rarity = CardRarity.Common, MaxCount = 5,
                GUIName = 518980, GUIDescription = 711330, GUICategory = CardGUICategory.Mod, GUIType = "assaultmod", GUITextureRef = "GUI_Icons.Weapons.MOD_stability-damper_256x128",
                PlayerVariableIds = [33],
                Pools = [new(StorePools.BronzeMod), new(StorePools.GoldMod), new(StorePools.SilverMod)],
            },
            new()
            {
                UniqueName = "SFXGameContent.SFXWeaponMod_ShotgunAccuracy", Kind = ReinforcementKind.InventoryUnlock, Rarity = CardRarity.Common, MaxCount = 5,
                GUIName = 519500, GUIDescription = 711336, GUICategory = CardGUICategory.Mod, GUIType = "shotgunmod", GUITextureRef = "GUI_Icons.Weapons.MOD_barrel-choke_256x128",
                PlayerVariableIds = [44],
                Pools = [new(StorePools.BronzeMod), new(StorePools.GoldMod), new(StorePools.SilverMod)],
            },
            new()
            {
                UniqueName = "SFXGameContent.SFXWeaponMod_SniperRifleReloadSpeed", Kind = ReinforcementKind.InventoryUnlock, Rarity = CardRarity.Common, MaxCount = 5,
                GUIName = 519536, GUIDescription = 711340, GUICategory = CardGUICategory.Mod, GUIType = "snipermod", GUITextureRef = "GUI_Icons.Weapons.MOD_heat-sink_256x128",
                PlayerVariableIds = [38],
                Pools = [new(StorePools.BronzeMod), new(StorePools.GoldMod), new(StorePools.SilverMod)],
            },
            new()
            {
                UniqueName = "SFXGameContent.SFXWeaponMod_PistolMagSize", Kind = ReinforcementKind.InventoryUnlock, Rarity = CardRarity.Common, MaxCount = 5,
                GUIName = 519438, GUIDescription = 711321, GUICategory = CardGUICategory.Mod, GUIType = "pistolmod", GUITextureRef = "GUI_Icons.Weapons.MOD_ammo-capacity_256x128",
                PlayerVariableIds = [49],
                Pools = [new(StorePools.GoldMod), new(StorePools.SilverMod)],
            },
            new()
            {
                UniqueName = "SFXGameContent.SFXWeaponMod_PistolDamage", Kind = ReinforcementKind.InventoryUnlock, Rarity = CardRarity.Common, MaxCount = 5,
                GUIName = 519355, GUIDescription = 711319, GUICategory = CardGUICategory.Mod, GUIType = "pistolmod", GUITextureRef = "GUI_Icons.Weapons.pst_bar_a_256x128",
                PlayerVariableIds = [46],
                Pools = [new(StorePools.GoldMod), new(StorePools.SilverMod)],
            },
            new()
            {
                UniqueName = "SFXGameContent.SFXWeaponMod_SMGAccuracy", Kind = ReinforcementKind.InventoryUnlock, Rarity = CardRarity.Common, MaxCount = 5,
                GUIName = 519472, GUIDescription = 711323, GUICategory = CardGUICategory.Mod, GUIType = "smgmod", GUITextureRef = "GUI_Icons.Weapons.pst_sco_a_256x128",
                PlayerVariableIds = [52],
                Pools = [new(StorePools.GoldMod), new(StorePools.SilverMod)],
            },
            new()
            {
                UniqueName = "SFXGameContent.SFXWeaponMod_SMGConstraintDamage", Kind = ReinforcementKind.InventoryUnlock, Rarity = CardRarity.Common, MaxCount = 5,
                GUIName = 519476, GUIDescription = 711327, GUICategory = CardGUICategory.Mod, GUIType = "smgmod", GUITextureRef = "GUI_Icons.Weapons.MOD_smg_heat-sink-mod_256x128",
                PlayerVariableIds = [55],
                Pools = [new(StorePools.GoldMod), new(StorePools.SilverMod)],
            },
            new()
            {
                UniqueName = "SFXGameContent.SFXWeaponMod_AssaultRifleAccuracy", Kind = ReinforcementKind.InventoryUnlock, Rarity = CardRarity.Common, MaxCount = 5,
                GUIName = 515088, GUIDescription = 711328, GUICategory = CardGUICategory.Mod, GUIType = "assaultmod", GUITextureRef = "GUI_Icons.Weapons.asl_sco_a_256x128",
                PlayerVariableIds = [32],
                Pools = [new(StorePools.GoldMod), new(StorePools.SilverMod)],
            },
            new()
            {
                UniqueName = "SFXGameContent.SFXWeaponMod_AssaultRifleMagSize", Kind = ReinforcementKind.InventoryUnlock, Rarity = CardRarity.Common, MaxCount = 5,
                GUIName = 518985, GUIDescription = 711331, GUICategory = CardGUICategory.Mod, GUIType = "assaultmod", GUITextureRef = "GUI_Icons.Weapons.MOD_ammo-capacity_256x128",
                PlayerVariableIds = [34],
                Pools = [new(StorePools.GoldMod), new(StorePools.SilverMod)],
            },
            new()
            {
                UniqueName = "SFXGameContent.SFXWeaponMod_ShotgunDamage", Kind = ReinforcementKind.InventoryUnlock, Rarity = CardRarity.Common, MaxCount = 5,
                GUIName = 519486, GUIDescription = 711333, GUICategory = CardGUICategory.Mod, GUIType = "shotgunmod", GUITextureRef = "GUI_Icons.Weapons.bls_bar_a_256x128",
                PlayerVariableIds = [41],
                Pools = [new(StorePools.GoldMod), new(StorePools.SilverMod)],
            },
            new()
            {
                UniqueName = "SFXGameContent.SFXWeaponMod_ShotgunMeleeDamage", Kind = ReinforcementKind.InventoryUnlock, Rarity = CardRarity.Common, MaxCount = 5,
                GUIName = 519504, GUIDescription = 711334, GUICategory = CardGUICategory.Mod, GUIType = "shotgunmod", GUITextureRef = "GUI_Icons.Weapons.bls_melee_a_256x128",
                PlayerVariableIds = [42],
                Pools = [new(StorePools.GoldMod), new(StorePools.SilverMod)],
            },
            new()
            {
                UniqueName = "SFXGameContent.SFXWeaponMod_SniperRifleDamage", Kind = ReinforcementKind.InventoryUnlock, Rarity = CardRarity.Uncommon, MaxCount = 5,
                GUIName = 519527, GUIDescription = 711339, GUICategory = CardGUICategory.Mod, GUIType = "snipermod", GUITextureRef = "GUI_Icons.Weapons.snp_bar_a_256x128",
                PlayerVariableIds = [36],
                Pools = [new(StorePools.GoldMod), new(StorePools.SilverMod)],
            },
            new()
            {
                UniqueName = "SFXGameContent.SFXWeaponMod_PistolStability", Kind = ReinforcementKind.InventoryUnlock, Rarity = CardRarity.Uncommon, MaxCount = 5,
                GUIName = 519357, GUIDescription = 711320, GUICategory = CardGUICategory.Mod, GUIType = "pistolmod", GUITextureRef = "GUI_Icons.Weapons.MOD_tazer-mod_256x128",
                PlayerVariableIds = [48],
                Pools = [new(StorePools.GoldMod)],
            },
            new()
            {
                UniqueName = "SFXGameContent.SFXWeaponMod_PistolReloadSpeed", Kind = ReinforcementKind.InventoryUnlock, Rarity = CardRarity.Uncommon, MaxCount = 5,
                GUIName = 519352, GUIDescription = 711322, GUICategory = CardGUICategory.Mod, GUIType = "pistolmod", GUITextureRef = "GUI_Icons.Weapons.MOD_penetration-mod_256x128",
                PlayerVariableIds = [50],
                Pools = [new(StorePools.GoldMod)],
            },
            new()
            {
                UniqueName = "SFXGameContent.SFXWeaponMod_SMGStability", Kind = ReinforcementKind.InventoryUnlock, Rarity = CardRarity.Uncommon, MaxCount = 5,
                GUIName = 519474, GUIDescription = 711325, GUICategory = CardGUICategory.Mod, GUIType = "smgmod", GUITextureRef = "GUI_Icons.Weapons.MOD_ultralight-material_256x128",
                PlayerVariableIds = [53],
                Pools = [new(StorePools.GoldMod)],
            },
            new()
            {
                UniqueName = "SFXGameContent.SFXWeaponMod_SMGDamage", Kind = ReinforcementKind.InventoryUnlock, Rarity = CardRarity.Uncommon, MaxCount = 5,
                GUIName = 519468, GUIDescription = 711324, GUICategory = CardGUICategory.Mod, GUIType = "smgmod", GUITextureRef = "GUI_Icons.Weapons.pst_bar_a_256x128",
                PlayerVariableIds = [51],
                Pools = [new(StorePools.GoldMod)],
            },
            new()
            {
                UniqueName = "SFXGameContent.SFXWeaponMod_AssaultRifleDamage", Kind = ReinforcementKind.InventoryUnlock, Rarity = CardRarity.Uncommon, MaxCount = 5,
                GUIName = 518965, GUIDescription = 711329, GUICategory = CardGUICategory.Mod, GUIType = "assaultmod", GUITextureRef = "GUI_Icons.Weapons.asl_bar_a_256x128",
                PlayerVariableIds = [31],
                Pools = [new(StorePools.GoldMod)],
            },
            new()
            {
                UniqueName = "SFXGameContent.SFXWeaponMod_AssaultRifleForce", Kind = ReinforcementKind.InventoryUnlock, Rarity = CardRarity.Uncommon, MaxCount = 5,
                GUIName = 518987, GUIDescription = 711332, GUICategory = CardGUICategory.Mod, GUIType = "assaultmod", GUITextureRef = "GUI_Icons.Weapons.MOD_penetration-mod_256x128",
                PlayerVariableIds = [35],
                Pools = [new(StorePools.GoldMod)],
            },
            new()
            {
                UniqueName = "SFXGameContent.SFXWeaponMod_ShotgunStability", Kind = ReinforcementKind.InventoryUnlock, Rarity = CardRarity.Uncommon, MaxCount = 5,
                GUIName = 519508, GUIDescription = 711335, GUICategory = CardGUICategory.Mod, GUIType = "shotgunmod", GUITextureRef = "GUI_Icons.Weapons.MOD_heat-sink_256x128",
                PlayerVariableIds = [43],
                Pools = [new(StorePools.GoldMod)],
            },
            new()
            {
                UniqueName = "SFXGameContent.SFXWeaponMod_ShotgunReloadSpeed", Kind = ReinforcementKind.InventoryUnlock, Rarity = CardRarity.Uncommon, MaxCount = 5,
                GUIName = 519482, GUIDescription = 711337, GUICategory = CardGUICategory.Mod, GUIType = "shotgunmod", GUITextureRef = "GUI_Icons.Weapons.MOD_shredder-mod_256x128",
                PlayerVariableIds = [45],
                Pools = [new(StorePools.GoldMod)],
            },
            new()
            {
                UniqueName = "SFXGameContent.SFXWeaponMod_SniperRifleAccuracy", Kind = ReinforcementKind.InventoryUnlock, Rarity = CardRarity.Uncommon, MaxCount = 5,
                GUIName = 519534, GUIDescription = 711338, GUICategory = CardGUICategory.Mod, GUIType = "snipermod", GUITextureRef = "GUI_Icons.Weapons.snp_sco_a_256x128",
                PlayerVariableIds = [37],
                Pools = [new(StorePools.GoldMod)],
            },
            new()
            {
                UniqueName = "SFXGameContent.SFXWeaponMod_SniperRifleConstraintDamage", Kind = ReinforcementKind.InventoryUnlock, Rarity = CardRarity.Uncommon, MaxCount = 5,
                GUIName = 519550, GUIDescription = 711342, GUICategory = CardGUICategory.Mod, GUIType = "snipermod", GUITextureRef = "GUI_Icons.Weapons.MOD_penetration-mod_256x128",
                PlayerVariableIds = [40],
                Pools = [new(StorePools.GoldMod)],
            },
            new()
            {
                UniqueName = "SFXGameContentDLC_Shared.SFXWeaponMod_AssaultRifleMelee", Kind = ReinforcementKind.InventoryUnlock, Rarity = CardRarity.Rare, MaxCount = 5,
                GUIName = 746321, GUIDescription = 754702, GUICategory = CardGUICategory.Mod, GUIType = "assaultmod", GUITextureRef = "DLC_SharedImages.Mods.omi_melee_A_256x128",
                PlayerVariableIds = [466],
                Pools = [new(StorePools.GoldMod)],
            },
            new()
            {
                UniqueName = "SFXGameContentDLC_Shared.SFXWeaponMod_AssaultRifleSuperPen", Kind = ReinforcementKind.InventoryUnlock, Rarity = CardRarity.Rare, MaxCount = 5,
                GUIName = 746486, GUIDescription = 754703, GUICategory = CardGUICategory.Mod, GUIType = "assaultmod", GUITextureRef = "DLC_SharedImages.Mods.asl_bar_F_256x128",
                PlayerVariableIds = [467],
                Pools = [new(StorePools.GoldMod)],
            },
            new()
            {
                UniqueName = "SFXGameContentDLC_Shared.SFXWeaponMod_AssaultRifleSuperScope", Kind = ReinforcementKind.InventoryUnlock, Rarity = CardRarity.Rare, MaxCount = 5,
                GUIName = 746481, GUIDescription = 754753, GUICategory = CardGUICategory.Mod, GUIType = "assaultmod", GUITextureRef = "DLC_SharedImages.Mods.asl_sco_F_256x128",
                PlayerVariableIds = [406],
                Pools = [new(StorePools.GoldMod)],
            },
            new()
            {
                UniqueName = "SFXGameContentDLC_Shared.SFXWeaponMod_SniperRifleDamageAndPen", Kind = ReinforcementKind.InventoryUnlock, Rarity = CardRarity.Rare, MaxCount = 5,
                GUIName = 747588, GUIDescription = 754703, GUICategory = CardGUICategory.Mod, GUIType = "snipermod", GUITextureRef = "DLC_SharedImages.Mods.snp_bar_F_256x128",
                PlayerVariableIds = [414],
                Pools = [new(StorePools.GoldMod)],
            },
            new()
            {
                UniqueName = "SFXGameContentDLC_Shared.SFXWeaponMod_SniperRifleSuperScope", Kind = ReinforcementKind.InventoryUnlock, Rarity = CardRarity.Rare, MaxCount = 5,
                GUIName = 747583, GUIDescription = 754753, GUICategory = CardGUICategory.Mod, GUIType = "snipermod", GUITextureRef = "DLC_SharedImages.Mods.snp_sco_F_256x128",
                PlayerVariableIds = [415],
                Pools = [new(StorePools.GoldMod)],
            },
            new()
            {
                UniqueName = "SFXGameContentDLC_Shared.SFXWeaponMod_ShotgunDamageAndPen", Kind = ReinforcementKind.InventoryUnlock, Rarity = CardRarity.Rare, MaxCount = 5,
                GUIName = 747578, GUIDescription = 754703, GUICategory = CardGUICategory.Mod, GUIType = "shotgunmod", GUITextureRef = "DLC_SharedImages.Mods.bls_bar_F_256x128",
                PlayerVariableIds = [410],
                Pools = [new(StorePools.GoldMod)],
            },
            new()
            {
                UniqueName = "SFXGameContentDLC_Shared.SFXWeaponMod_ShotgunSuperMelee", Kind = ReinforcementKind.InventoryUnlock, Rarity = CardRarity.Rare, MaxCount = 5,
                GUIName = 747574, GUIDescription = 754704, GUICategory = CardGUICategory.Mod, GUIType = "shotgunmod", GUITextureRef = "DLC_SharedImages.Mods.omi_melee_A_256x128",
                PlayerVariableIds = [411],
                Pools = [new(StorePools.GoldMod)],
            },
            new()
            {
                UniqueName = "SFXGameContentDLC_Shared.SFXWeaponMod_PistolHeadShot", Kind = ReinforcementKind.InventoryUnlock, Rarity = CardRarity.Rare, MaxCount = 5,
                GUIName = 747595, GUIDescription = 754706, GUICategory = CardGUICategory.Mod, GUIType = "pistolmod", GUITextureRef = "DLC_SharedImages.Mods.pst_bar_H_256x128",
                PlayerVariableIds = [407],
                Pools = [new(StorePools.GoldMod)],
            },
            new()
            {
                UniqueName = "SFXGameContentDLC_Shared.SFXWeaponMod_PistolSuperDamage", Kind = ReinforcementKind.InventoryUnlock, Rarity = CardRarity.Rare, MaxCount = 5,
                GUIName = 747591, GUIDescription = 754705, GUICategory = CardGUICategory.Mod, GUIType = "pistolmod", GUITextureRef = "DLC_SharedImages.Mods.pst_bar_G_256x128",
                PlayerVariableIds = [408],
                Pools = [new(StorePools.GoldMod)],
            },
            new()
            {
                UniqueName = "SFXGameContentDLC_Shared.SFXWeaponMod_PistolUltraLight", Kind = ReinforcementKind.InventoryUnlock, Rarity = CardRarity.Rare, MaxCount = 5,
                GUIName = 747597, GUIDescription = 754707, GUICategory = CardGUICategory.Mod, GUIType = "pistolmod", GUITextureRef = "GUI_Icons.Weapons.MOD_ultralight-material_256x128",
                PlayerVariableIds = [409],
                Pools = [new(StorePools.GoldMod)],
            },
            new()
            {
                UniqueName = "SFXGameContentDLC_Shared.SFXWeaponMod_SMGPenetration", Kind = ReinforcementKind.InventoryUnlock, Rarity = CardRarity.Rare, MaxCount = 5,
                GUIName = 746472, GUIDescription = 754701, GUICategory = CardGUICategory.Mod, GUIType = "smgmod", GUITextureRef = "DLC_SharedImages.Mods.pst_bar_F_256x128",
                PlayerVariableIds = [412],
                Pools = [new(StorePools.GoldMod)],
            },
            new()
            {
                UniqueName = "SFXGameContentDLC_Shared.SFXWeaponMod_SMGStabilization", Kind = ReinforcementKind.InventoryUnlock, Rarity = CardRarity.Rare, MaxCount = 5,
                GUIName = 746467, GUIDescription = 754700, GUICategory = CardGUICategory.Mod, GUIType = "smgmod", GUITextureRef = "GUI_Icons.Weapons.MOD_stability-damper_256x128",
                PlayerVariableIds = [413],
                Pools = [new(StorePools.GoldMod)],
            },
            new()
            {
                UniqueName = "SFXGameContentDLC_CON_MP5.SFXWeaponMod_AssaultRifleUltraLight_MP5", Kind = ReinforcementKind.InventoryUnlock, Rarity = CardRarity.Rare, MaxCount = 5,
                GUIName = 806005, GUIDescription = 754707, GUICategory = CardGUICategory.Mod, GUIType = "assaultmod", GUITextureRef = "DLC_MPImages_MP5.MOD_MP5_UltraLight_256x128",
                PlayerVariableIds = [653],
                Pools = [new(StorePools.GoldMod)],
            },
            new()
            {
                UniqueName = "SFXGameContentDLC_CON_MP5.SFXWeaponMod_SniperRifleUltraLight_MP5", Kind = ReinforcementKind.InventoryUnlock, Rarity = CardRarity.Rare, MaxCount = 5,
                GUIName = 806007, GUIDescription = 754707, GUICategory = CardGUICategory.Mod, GUIType = "snipermod", GUITextureRef = "DLC_MPImages_MP5.MOD_MP5_UltraLight_256x128",
                PlayerVariableIds = [654],
                Pools = [new(StorePools.GoldMod)],
            },
            new()
            {
                UniqueName = "SFXGameContentDLC_CON_MP5.SFXWeaponMod_ShotgunUltraLight_MP5", Kind = ReinforcementKind.InventoryUnlock, Rarity = CardRarity.Rare, MaxCount = 5,
                GUIName = 806004, GUIDescription = 754707, GUICategory = CardGUICategory.Mod, GUIType = "shotgunmod", GUITextureRef = "DLC_MPImages_MP5.MOD_MP5_UltraLight_256x128",
                PlayerVariableIds = [655],
                Pools = [new(StorePools.GoldMod)],
            },
            new()
            {
                UniqueName = "SFXGameContentDLC_CON_MP5.SFXWeaponMod_PistolPowerDamage_MP5", Kind = ReinforcementKind.InventoryUnlock, Rarity = CardRarity.Rare, MaxCount = 5,
                GUIName = 806008, GUIDescription = 817619, GUICategory = CardGUICategory.Mod, GUIType = "pistolmod", GUITextureRef = "DLC_MPImages_MP5.MOD_MP5_PwrBoost_256x128",
                PlayerVariableIds = [656],
                Pools = [new(StorePools.GoldMod)],
            },
            new()
            {
                UniqueName = "SFXGameContentDLC_CON_MP5.SFXWeaponMod_SMGPowerDamage_MP5", Kind = ReinforcementKind.InventoryUnlock, Rarity = CardRarity.Rare, MaxCount = 5,
                GUIName = 806009, GUIDescription = 817619, GUICategory = CardGUICategory.Mod, GUIType = "smgmod", GUITextureRef = "DLC_MPImages_MP5.MOD_MP5_PwrBoost_SMG_256x128",
                PlayerVariableIds = [657],
                Pools = [new(StorePools.GoldMod)],
            },
        ];
    }
}
