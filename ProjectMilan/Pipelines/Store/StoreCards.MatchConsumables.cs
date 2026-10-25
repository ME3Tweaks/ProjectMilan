using ProjectMilanCore.Config.Store;

namespace ProjectMilan.Pipelines.Store
{
    public static partial class StoreCards
    {
        /// <summary>
        /// One-match boost cards (ammo, armor and weapon upgrades). Ownership is per version (UniqueName_0..III), so PlayerVariableIds is indexed by version; each tier pool awards one version.
        /// </summary>
        private static IEnumerable<StoreCard> MatchConsumables =>
        [
            new()
            {
                UniqueName = "SFXGameMPContent.SFXGameEffect_MatchConsumable_AmmoPower_Incendiary", Kind = ReinforcementKind.MatchConsumable, Rarity = CardRarity.Common, UseVersionIdx = true, VersionIdx = 0, Category = 1,
                GUIName = 711347, GUIDescription = 676662, GUICategory = CardGUICategory.MatchConsumableAmmo, GUIType = "ammoUpgrade", GUITextureRef = "GUI_MPImages.Cards.AmmoIncendiary",
                PlayerVariableIds = [90, 91, 92, 484],
                Pools =
                [
                    new(StorePools.BronzeCommon) { VersionIdx = 0, Tokens = "Custom0Token=0.10f,Custom6Token=10" },
                    new(StorePools.GoldCommon) { VersionIdx = 2, Rarity = CardRarity.Uncommon, Tokens = "Custom0Token=0.30f,Custom6Token=30" },
                    new(StorePools.GoldEquipment) { VersionIdx = 3, Rarity = CardRarity.Rare, Tokens = "Custom0Token=0.50f,Custom6Token=50" },
                    new(StorePools.GoldBackup) { VersionIdx = 3, Rarity = CardRarity.Rare, Tokens = "Custom0Token=0.50f,Custom6Token=50" },
                    new(StorePools.SilverBackup) { VersionIdx = 2, Rarity = CardRarity.Uncommon, Tokens = "Custom0Token=0.30f,Custom6Token=30" },
                    new(StorePools.SilverCommon) { VersionIdx = 1, Tokens = "Custom0Token=0.20f,Custom6Token=20" },
                ],
            },
            new()
            {
                UniqueName = "SFXGameMPContent.SFXGameEffect_MatchConsumable_AmmoPower_Disruptor", Kind = ReinforcementKind.MatchConsumable, Rarity = CardRarity.Common, UseVersionIdx = true, VersionIdx = 0, Category = 1,
                GUIName = 711348, GUIDescription = 676663, GUICategory = CardGUICategory.MatchConsumableAmmo, GUIType = "ammoUpgrade", GUITextureRef = "GUI_MPImages.Cards.AmmoDisrupt",
                PlayerVariableIds = [93, 94, 95, 485],
                Pools =
                [
                    new(StorePools.BronzeCommon) { VersionIdx = 0, Tokens = "Custom0Token=0.05f,Custom1Token=1.0f,Custom2Token=1.0f,Custom3Token=3.5f,Custom5Token=8.0f" },
                    new(StorePools.GoldCommon) { VersionIdx = 2, Rarity = CardRarity.Uncommon, Tokens = "Custom0Token=0.15f,Custom1Token=1.8f,Custom2Token=1.0f,Custom3Token=3.5f,Custom5Token=8.0f" },
                    new(StorePools.GoldEquipment) { VersionIdx = 3, Rarity = CardRarity.Rare, Tokens = "Custom0Token=0.25f,Custom1Token=2.0f,Custom2Token=1.0f,Custom3Token=5.0f,Custom5Token=8.0f" },
                    new(StorePools.GoldBackup) { VersionIdx = 3, Rarity = CardRarity.Rare, Tokens = "Custom0Token=0.25f,Custom1Token=2.0f,Custom2Token=1.0f,Custom3Token=5.0f,Custom5Token=8.0f" },
                    new(StorePools.SilverBackup) { VersionIdx = 2, Rarity = CardRarity.Uncommon, Tokens = "Custom0Token=0.15f,Custom1Token=1.8f,Custom2Token=1.0f,Custom3Token=3.5f,Custom5Token=8.0f" },
                    new(StorePools.SilverCommon) { VersionIdx = 1, Tokens = "Custom0Token=0.10f,Custom1Token=1.4f,Custom2Token=1.0f,Custom3Token=3.5f,Custom5Token=8.0f" },
                ],
            },
            new()
            {
                UniqueName = "SFXGameMPContent.SFXGameEffect_MatchConsumable_AmmoPower_ArmorPiercing", Kind = ReinforcementKind.MatchConsumable, Rarity = CardRarity.Common, UseVersionIdx = true, VersionIdx = 0, Category = 1,
                GUIName = 711349, GUIDescription = 676664, GUICategory = CardGUICategory.MatchConsumableAmmo, GUIType = "ammoUpgrade", GUITextureRef = "GUI_MPImages.Cards.AmmoPiercing",
                PlayerVariableIds = [96, 97, 98, 486],
                Pools =
                [
                    new(StorePools.BronzeCommon) { VersionIdx = 0, Tokens = "Custom0Token=0.10f,Custom1Token=0.50f,Custom2Token=0.50f" },
                    new(StorePools.GoldCommon) { VersionIdx = 2, Rarity = CardRarity.Uncommon, Tokens = "Custom0Token=0.30f,Custom1Token=1.00f,Custom2Token=0.75f" },
                    new(StorePools.GoldEquipment) { VersionIdx = 3, Rarity = CardRarity.Rare, Tokens = "Custom0Token=0.50f,Custom1Token=1.50f,Custom2Token=0.9f" },
                    new(StorePools.GoldBackup) { VersionIdx = 3, Rarity = CardRarity.Rare, Tokens = "Custom0Token=0.50f,Custom1Token=1.50f,Custom2Token=0.9f" },
                    new(StorePools.SilverBackup) { VersionIdx = 2, Rarity = CardRarity.Uncommon, Tokens = "Custom0Token=0.30f,Custom1Token=1.00f,Custom2Token=0.75f" },
                    new(StorePools.SilverCommon) { VersionIdx = 1, Tokens = "Custom0Token=0.20f,Custom1Token=0.75f,Custom2Token=0.65f" },
                ],
            },
            new()
            {
                UniqueName = "SFXGameMPContent.SFXGameEffect_MatchConsumable_AmmoPower_Warp", Kind = ReinforcementKind.MatchConsumable, Rarity = CardRarity.Common, UseVersionIdx = true, VersionIdx = 0, Category = 1,
                GUIName = 711350, GUIDescription = 676665, GUICategory = CardGUICategory.MatchConsumableAmmo, GUIType = "ammoUpgrade", GUITextureRef = "GUI_MPImages.Cards.AmmoWarp",
                PlayerVariableIds = [99, 100, 101, 487],
                Pools =
                [
                    new(StorePools.BronzeCommon) { VersionIdx = 0, Tokens = "Custom0Token=0.15f,Custom2Token=0.25f,Custom4Token=0.25f" },
                    new(StorePools.GoldCommon) { VersionIdx = 2, Rarity = CardRarity.Uncommon, Tokens = "Custom0Token=0.35f,Custom2Token=0.75f,Custom4Token=0.50f" },
                    new(StorePools.GoldEquipment) { VersionIdx = 3, Rarity = CardRarity.Rare, Tokens = "Custom0Token=0.6f,Custom2Token=1.00f,Custom4Token=0.65f" },
                    new(StorePools.GoldBackup) { VersionIdx = 3, Rarity = CardRarity.Rare, Tokens = "Custom0Token=0.6f,Custom2Token=1.00f,Custom4Token=0.65f" },
                    new(StorePools.SilverBackup) { VersionIdx = 2, Rarity = CardRarity.Uncommon, Tokens = "Custom0Token=0.35f,Custom2Token=0.75f,Custom4Token=0.50f" },
                    new(StorePools.SilverCommon) { VersionIdx = 1, Tokens = "Custom0Token=0.25f,Custom2Token=0.50f,Custom4Token=0.35f" },
                ],
            },
            new()
            {
                UniqueName = "SFXGameMPContent.SFXGameEffect_MatchConsumable_AmmoPower_Cryo", Kind = ReinforcementKind.MatchConsumable, Rarity = CardRarity.Common, UseVersionIdx = true, VersionIdx = 0, Category = 1,
                GUIName = 711351, GUIDescription = 676666, GUICategory = CardGUICategory.MatchConsumableAmmo, GUIType = "ammoUpgrade", GUITextureRef = "GUI_MPImages.Cards.AmmoCryo",
                PlayerVariableIds = [102, 103, 104, 488],
                Pools =
                [
                    new(StorePools.BronzeCommon) { VersionIdx = 0, Tokens = "Custom0Token=0.15f,Custom1Token=3.f,Custom2Token=0.25f,Custom3Token=1.0f" },
                    new(StorePools.GoldCommon) { VersionIdx = 2, Rarity = CardRarity.Uncommon, Tokens = "Custom0Token=0.35f,Custom1Token=5.f,Custom2Token=0.50f,Custom3Token=1.8f" },
                    new(StorePools.GoldEquipment) { VersionIdx = 3, Rarity = CardRarity.Rare, Tokens = "Custom0Token=0.35f,Custom1Token=5.5f,Custom2Token=0.65f,Custom3Token=2.2f" },
                    new(StorePools.GoldBackup) { VersionIdx = 3, Rarity = CardRarity.Rare, Tokens = "Custom0Token=0.35f,Custom1Token=5.5f,Custom2Token=0.65f,Custom3Token=2.2f" },
                    new(StorePools.SilverBackup) { VersionIdx = 2, Rarity = CardRarity.Uncommon, Tokens = "Custom0Token=0.35f,Custom1Token=5.f,Custom2Token=0.50f,Custom3Token=1.8f" },
                    new(StorePools.SilverCommon) { VersionIdx = 1, Tokens = "Custom0Token=0.25f,Custom1Token=4.f,Custom2Token=0.35f,Custom3Token=1.4f" },
                ],
            },
            new()
            {
                UniqueName = "SFXGameMPContent.SFXGameEffect_MatchConsumable_PowerBonus", Kind = ReinforcementKind.MatchConsumable, Rarity = CardRarity.Common, UseVersionIdx = true, VersionIdx = 0, Category = 2,
                GUIName = 711352, GUIDescription = 676667, GUICategory = CardGUICategory.MatchConsumableArmor, GUIType = "armorUpgrade", GUITextureRef = "GUI_MPImages.Cards.BoostTime",
                PlayerVariableIds = [105, 106, 107],
                Pools =
                [
                    new(StorePools.BronzeCommon) { VersionIdx = 0, Tokens = "Custom0Token=0.1f" },
                    new(StorePools.GoldCommon) { VersionIdx = 2, Rarity = CardRarity.Uncommon, Tokens = "Custom0Token=0.3f" },
                    new(StorePools.SilverBackup) { VersionIdx = 2, Rarity = CardRarity.Uncommon, Tokens = "Custom0Token=0.3f" },
                    new(StorePools.SilverCommon) { VersionIdx = 1, Tokens = "Custom0Token=0.2f" },
                ],
            },
            new()
            {
                UniqueName = "SFXGameMPContent.SFXGameEffect_MatchConsumable_PowerBonusDamage", Kind = ReinforcementKind.MatchConsumable, Rarity = CardRarity.Common, UseVersionIdx = true, VersionIdx = 0, Category = 2,
                GUIName = 711353, GUIDescription = 676668, GUICategory = CardGUICategory.MatchConsumableArmor, GUIType = "armorUpgrade", GUITextureRef = "GUI_MPImages.Cards.BoostPower",
                PlayerVariableIds = [259, 260, 261, 489],
                Pools =
                [
                    new(StorePools.BronzeCommon) { VersionIdx = 0, Tokens = "Custom0Token=0.1f" },
                    new(StorePools.GoldCommon) { VersionIdx = 2, Rarity = CardRarity.Uncommon, Tokens = "Custom0Token=0.3f" },
                    new(StorePools.GoldEquipment) { VersionIdx = 3, Rarity = CardRarity.Rare, Tokens = "Custom0Token=0.5f" },
                    new(StorePools.GoldBackup) { VersionIdx = 3, Rarity = CardRarity.Rare, Tokens = "Custom0Token=0.5f" },
                    new(StorePools.SilverBackup) { VersionIdx = 2, Rarity = CardRarity.Uncommon, Tokens = "Custom0Token=0.3f" },
                    new(StorePools.SilverCommon) { VersionIdx = 1, Tokens = "Custom0Token=0.2f" },
                ],
            },
            new()
            {
                UniqueName = "SFXGameMPContent.SFXGameEffect_MatchConsumable_WeaponDamageBonus_AssaultRifle", Kind = ReinforcementKind.MatchConsumable, Rarity = CardRarity.Common, UseVersionIdx = true, VersionIdx = 0, Category = 3,
                GUIName = 711354, GUIDescription = 676669, GUICategory = CardGUICategory.MatchConsumableWeapon, GUIType = "weaponUpgrade", GUITextureRef = "GUI_MPImages.Cards.DamageAssault",
                PlayerVariableIds = [111, 112, 113],
                Pools =
                [
                    new(StorePools.BronzeCommon) { VersionIdx = 0, Tokens = "Custom0Token=0.1f" },
                    new(StorePools.GoldCommon) { VersionIdx = 2, Rarity = CardRarity.Uncommon, Tokens = "Custom0Token=0.3f" },
                    new(StorePools.SilverBackup) { VersionIdx = 2, Rarity = CardRarity.Uncommon, Tokens = "Custom0Token=0.3f" },
                    new(StorePools.SilverCommon) { VersionIdx = 1, Tokens = "Custom0Token=0.2f" },
                ],
            },
            new()
            {
                UniqueName = "SFXGameMPContent.SFXGameEffect_MatchConsumable_WeaponDamageBonus_SniperRifle", Kind = ReinforcementKind.MatchConsumable, Rarity = CardRarity.Common, UseVersionIdx = true, VersionIdx = 0, Category = 3,
                GUIName = 711355, GUIDescription = 676670, GUICategory = CardGUICategory.MatchConsumableWeapon, GUIType = "weaponUpgrade", GUITextureRef = "GUI_MPImages.Cards.DamageSniper",
                PlayerVariableIds = [114, 115, 116],
                Pools =
                [
                    new(StorePools.BronzeCommon) { VersionIdx = 0, Tokens = "Custom0Token=0.1f" },
                    new(StorePools.GoldCommon) { VersionIdx = 2, Rarity = CardRarity.Uncommon, Tokens = "Custom0Token=0.3f" },
                    new(StorePools.SilverBackup) { VersionIdx = 2, Rarity = CardRarity.Uncommon, Tokens = "Custom0Token=0.3f" },
                    new(StorePools.SilverCommon) { VersionIdx = 1, Tokens = "Custom0Token=0.2f" },
                ],
            },
            new()
            {
                UniqueName = "SFXGameMPContent.SFXGameEffect_MatchConsumable_WeaponDamageBonus_Shotgun", Kind = ReinforcementKind.MatchConsumable, Rarity = CardRarity.Common, UseVersionIdx = true, VersionIdx = 0, Category = 3,
                GUIName = 711356, GUIDescription = 676671, GUICategory = CardGUICategory.MatchConsumableWeapon, GUIType = "weaponUpgrade", GUITextureRef = "GUI_MPImages.Cards.DamageShotgun",
                PlayerVariableIds = [117, 118, 119],
                Pools =
                [
                    new(StorePools.BronzeCommon) { VersionIdx = 0, Tokens = "Custom0Token=0.1f" },
                    new(StorePools.GoldCommon) { VersionIdx = 2, Rarity = CardRarity.Uncommon, Tokens = "Custom0Token=0.3f" },
                    new(StorePools.SilverBackup) { VersionIdx = 2, Rarity = CardRarity.Uncommon, Tokens = "Custom0Token=0.3f" },
                    new(StorePools.SilverCommon) { VersionIdx = 1, Tokens = "Custom0Token=0.2f" },
                ],
            },
            new()
            {
                UniqueName = "SFXGameMPContent.SFXGameEffect_MatchConsumable_WeaponDamageBonus_Pistol", Kind = ReinforcementKind.MatchConsumable, Rarity = CardRarity.Common, UseVersionIdx = true, VersionIdx = 0, Category = 3,
                GUIName = 711357, GUIDescription = 676672, GUICategory = CardGUICategory.MatchConsumableWeapon, GUIType = "weaponUpgrade", GUITextureRef = "GUI_MPImages.Cards.DamagePistol",
                PlayerVariableIds = [120, 121, 122],
                Pools =
                [
                    new(StorePools.BronzeCommon) { VersionIdx = 0, Tokens = "Custom0Token=0.1f" },
                    new(StorePools.GoldCommon) { VersionIdx = 2, Rarity = CardRarity.Uncommon, Tokens = "Custom0Token=0.3f" },
                    new(StorePools.SilverBackup) { VersionIdx = 2, Rarity = CardRarity.Uncommon, Tokens = "Custom0Token=0.3f" },
                    new(StorePools.SilverCommon) { VersionIdx = 1, Tokens = "Custom0Token=0.2f" },
                ],
            },
            new()
            {
                UniqueName = "SFXGameMPContent.SFXGameEffect_MatchConsumable_WeaponDamageBonus_SMG", Kind = ReinforcementKind.MatchConsumable, Rarity = CardRarity.Common, UseVersionIdx = true, VersionIdx = 0, Category = 3,
                GUIName = 711358, GUIDescription = 676673, GUICategory = CardGUICategory.MatchConsumableWeapon, GUIType = "weaponUpgrade", GUITextureRef = "GUI_MPImages.Cards.DamageSMG",
                PlayerVariableIds = [123, 124, 125],
                Pools =
                [
                    new(StorePools.BronzeCommon) { VersionIdx = 0, Tokens = "Custom0Token=0.1f" },
                    new(StorePools.GoldCommon) { VersionIdx = 2, Rarity = CardRarity.Uncommon, Tokens = "Custom0Token=0.3f" },
                    new(StorePools.SilverBackup) { VersionIdx = 2, Rarity = CardRarity.Uncommon, Tokens = "Custom0Token=0.3f" },
                    new(StorePools.SilverCommon) { VersionIdx = 1, Tokens = "Custom0Token=0.2f" },
                ],
            },
            new()
            {
                UniqueName = "SFXGameMPContent.SFXGameEffect_MatchConsumable_SpeedBonus", Kind = ReinforcementKind.MatchConsumable, Rarity = CardRarity.Common, UseVersionIdx = true, VersionIdx = 0, Category = 2,
                GUIName = 711359, GUIDescription = 676674, GUICategory = CardGUICategory.MatchConsumableArmor, GUIType = "armorUpgrade", GUITextureRef = "GUI_MPImages.Cards.BoostSpeed",
                PlayerVariableIds = [126, 127, 128],
                Pools =
                [
                    new(StorePools.BronzeCommon) { VersionIdx = 0, Tokens = "Custom0Token=0.05f" },
                    new(StorePools.GoldCommon) { VersionIdx = 2, Rarity = CardRarity.Uncommon, Tokens = "Custom0Token=0.25f" },
                    new(StorePools.SilverBackup) { VersionIdx = 2, Rarity = CardRarity.Uncommon, Tokens = "Custom0Token=0.25f" },
                    new(StorePools.SilverCommon) { VersionIdx = 1, Tokens = "Custom0Token=0.15f" },
                ],
            },
            new()
            {
                UniqueName = "SFXGameMPContent.SFXGameEffect_MatchConsumable_ShieldBonus", Kind = ReinforcementKind.MatchConsumable, Rarity = CardRarity.Common, UseVersionIdx = true, VersionIdx = 0, Category = 2,
                GUIName = 711360, GUIDescription = 676675, GUICategory = CardGUICategory.MatchConsumableArmor, GUIType = "armorUpgrade", GUITextureRef = "GUI_MPImages.Cards.BoostShields",
                PlayerVariableIds = [129, 130, 131, 490],
                Pools =
                [
                    new(StorePools.BronzeCommon) { VersionIdx = 0, Tokens = "Custom0Token=0.3f" },
                    new(StorePools.GoldCommon) { VersionIdx = 2, Rarity = CardRarity.Uncommon, Tokens = "Custom0Token=1.0f" },
                    new(StorePools.GoldEquipment) { VersionIdx = 3, Rarity = CardRarity.Rare, Tokens = "Custom0Token=1.5f" },
                    new(StorePools.GoldBackup) { VersionIdx = 3, Rarity = CardRarity.Rare, Tokens = "Custom0Token=1.5f" },
                    new(StorePools.SilverBackup) { VersionIdx = 2, Rarity = CardRarity.Uncommon, Tokens = "Custom0Token=1.0f" },
                    new(StorePools.SilverCommon) { VersionIdx = 1, Tokens = "Custom0Token=0.6f" },
                ],
            },
            new()
            {
                UniqueName = "SFXGameContentDLC_CON_MP1.SFXGameEffect_MatchConsumable_StabilityBonus", Kind = ReinforcementKind.MatchConsumable, Rarity = CardRarity.Common, UseVersionIdx = true, VersionIdx = 0, Category = 2,
                GUIName = 728048, GUIDescription = 728049, GUICategory = CardGUICategory.MatchConsumableArmor, GUIType = "armorUpgrade", GUITextureRef = "DLC_MPImages.Cards.DLC_Stability",
                PlayerVariableIds = [73, 74, 75],
                Pools =
                [
                    new(StorePools.BronzeCommon) { VersionIdx = 0 },
                    new(StorePools.GoldCommon) { VersionIdx = 2, Rarity = CardRarity.Uncommon },
                    new(StorePools.SilverCommon) { VersionIdx = 1 },
                ],
            },
            new()
            {
                UniqueName = "SFXGameContentDLC_CON_MP1.SFXGameEffect_MatchConsumable_MeleeDamage", Kind = ReinforcementKind.MatchConsumable, Rarity = CardRarity.Common, UseVersionIdx = true, VersionIdx = 0, Category = 3,
                GUIName = 728050, GUIDescription = 728051, GUICategory = CardGUICategory.MatchConsumableWeapon, GUIType = "weaponUpgrade", GUITextureRef = "DLC_MPImages.Cards.DLC_MeleeDamage",
                PlayerVariableIds = [79, 80, 81],
                Pools =
                [
                    new(StorePools.BronzeCommon) { VersionIdx = 0 },
                    new(StorePools.GoldCommon) { VersionIdx = 2, Rarity = CardRarity.Uncommon },
                    new(StorePools.SilverCommon) { VersionIdx = 1 },
                ],
            },
            new()
            {
                UniqueName = "SFXGameContentDLC_CON_MP1.SFXGameEffect_MatchConsumable_HeadshotDamage", Kind = ReinforcementKind.MatchConsumable, Rarity = CardRarity.Common, UseVersionIdx = true, VersionIdx = 0, Category = 3,
                GUIName = 728052, GUIDescription = 728053, GUICategory = CardGUICategory.MatchConsumableWeapon, GUIType = "weaponUpgrade", GUITextureRef = "DLC_MPImages.Cards.DLC_Headshot",
                PlayerVariableIds = [82, 83, 84],
                Pools =
                [
                    new(StorePools.BronzeCommon) { VersionIdx = 0 },
                    new(StorePools.GoldCommon) { VersionIdx = 2, Rarity = CardRarity.Uncommon },
                    new(StorePools.SilverCommon) { VersionIdx = 1 },
                ],
            },
            new()
            {
                UniqueName = "SFXGameContentDLC_CON_MP1.SFXGameEffect_MatchConsumable_ShieldRegenBonus", Kind = ReinforcementKind.MatchConsumable, Rarity = CardRarity.Common, UseVersionIdx = true, VersionIdx = 0, Category = 2,
                GUIName = 728054, GUIDescription = 728055, GUICategory = CardGUICategory.MatchConsumableArmor, GUIType = "armorUpgrade", GUITextureRef = "DLC_MPImages.Cards.DLC_ShieldRegen",
                PlayerVariableIds = [76, 77, 78],
                Pools =
                [
                    new(StorePools.BronzeCommon) { VersionIdx = 0 },
                    new(StorePools.GoldCommon) { VersionIdx = 2, Rarity = CardRarity.Uncommon },
                    new(StorePools.SilverCommon) { VersionIdx = 1 },
                ],
            },
            new()
            {
                UniqueName = "SFXGameContentDLC_CON_MP4.SFXGameEffect_MatchConsumable_AmmoPower_Polonium", Kind = ReinforcementKind.MatchConsumable, Rarity = CardRarity.Common, UseVersionIdx = true, VersionIdx = 0, Category = 1,
                GUIName = 750415, GUIDescription = 750416, GUICategory = CardGUICategory.MatchConsumableAmmo, GUIType = "ammoUpgrade", GUITextureRef = "GUI_MPImages_MP4.AmmoPolonium",
                PlayerVariableIds = [515, 520, 525],
                Pools =
                [
                    new(StorePools.BronzeCommon) { VersionIdx = 0, Tokens = "Custom0Token=0.2f, Custom1Token=10.f" },
                    new(StorePools.GoldCommon) { VersionIdx = 2, Rarity = CardRarity.Uncommon, Tokens = "Custom0Token=0.4f, Custom1Token=10.f" },
                    new(StorePools.SilverCommon) { VersionIdx = 1, Tokens = "Custom0Token=0.3f, Custom1Token=10.f" },
                ],
            },
            new()
            {
                UniqueName = "SFXGameContentDLC_CON_MP4.SFXGameEffect_MatchConsumable_AmmoPower_Eraser", Kind = ReinforcementKind.MatchConsumable, Rarity = CardRarity.Common, UseVersionIdx = true, VersionIdx = 0, Category = 1,
                GUIName = 750437, GUIDescription = 750438, GUICategory = CardGUICategory.MatchConsumableAmmo, GUIType = "ammoUpgrade", GUITextureRef = "GUI_MPImages_MP4.AmmoEraser",
                PlayerVariableIds = [518, 523, 528],
                Pools =
                [
                    new(StorePools.BronzeCommon) { VersionIdx = 0, Tokens = "Custom0Token=0.1f, Custom1Token=1.f, Custom2Token=0.1f" },
                    new(StorePools.GoldCommon) { VersionIdx = 2, Rarity = CardRarity.Uncommon, Tokens = "Custom0Token=0.3f, Custom1Token=2.5f, Custom2Token=0.4f" },
                    new(StorePools.SilverCommon) { VersionIdx = 1, Tokens = "Custom0Token=0.2f, Custom1Token=1.5f, Custom2Token=0.25f" },
                ],
            },
            new()
            {
                UniqueName = "SFXGameContentDLC_CON_MP4.SFXGameEffect_MatchConsumable_AmmoPower_Needler", Kind = ReinforcementKind.MatchConsumable, Rarity = CardRarity.Common, UseVersionIdx = true, VersionIdx = 0, Category = 1,
                GUIName = 750419, GUIDescription = 750420, GUICategory = CardGUICategory.MatchConsumableAmmo, GUIType = "ammoUpgrade", GUITextureRef = "GUI_MPImages_MP4.AmmoExplosive",
                PlayerVariableIds = [517, 522, 527],
                Pools =
                [
                    new(StorePools.BronzeCommon) { VersionIdx = 0, Tokens = "Custom0Token=0.1f, Custom1Token=50.f, Custom3Token=1.5f" },
                    new(StorePools.GoldCommon) { VersionIdx = 2, Rarity = CardRarity.Uncommon, Tokens = "Custom0Token=0.3f, Custom1Token=250.f, Custom3Token=2.5f" },
                    new(StorePools.SilverCommon) { VersionIdx = 1, Tokens = "Custom0Token=0.2f, Custom1Token=150.f, Custom3Token=2.f" },
                ],
            },
            new()
            {
                UniqueName = "SFXGameContentDLC_CON_MP4.SFXGameEffect_MatchConsumable_AmmoPower_Phasic", Kind = ReinforcementKind.MatchConsumable, Rarity = CardRarity.Common, UseVersionIdx = true, VersionIdx = 0, Category = 1,
                GUIName = 750421, GUIDescription = 750422, GUICategory = CardGUICategory.MatchConsumableAmmo, GUIType = "ammoUpgrade", GUITextureRef = "GUI_MPImages_MP4.AmmoPhasic",
                PlayerVariableIds = [519, 524, 529],
                Pools =
                [
                    new(StorePools.BronzeCommon) { VersionIdx = 0, Tokens = "Custom0Token=0.05f, Custom2Token=1.f, Custom5Token=15.f" },
                    new(StorePools.GoldCommon) { VersionIdx = 2, Rarity = CardRarity.Uncommon, Tokens = "Custom0Token=0.15f, Custom2Token=1.f, Custom5Token=15.f" },
                    new(StorePools.SilverCommon) { VersionIdx = 1, Tokens = "Custom0Token=0.1f, Custom2Token=1.f, Custom5Token=15.f" },
                ],
            },
        ];
    }
}
