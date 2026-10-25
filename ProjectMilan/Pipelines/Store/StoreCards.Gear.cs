using ProjectMilanCore.Config.Store;

namespace ProjectMilan.Pipelines.Store
{
    public static partial class StoreCards
    {
        /// <summary>
        /// Gear cards. Ownership is per version (UniqueName_0..), so PlayerVariableIds is indexed by version.
        /// </summary>
        private static IEnumerable<StoreCard> Gear =>
        [
            new()
            {
                UniqueName = "SFXGameContentDLC_CON_MP2.SFXGameEffect_MatchConsumable_Gear_HeadshotDamage", Kind = ReinforcementKind.MatchConsumableGear, Rarity = CardRarity.Uncommon, MaxCount = 5, UseVersionIdx = false, VersionIdx = 0, Category = 4,
                GUIName = 733118, GUIDescription = 733120, GUICategory = CardGUICategory.MatchConsumableGear, GUIType = "gearUpgrade", GUITextureRef = "DLC_MPImages.Cards.DLC_Headshot",
                PlayerVariableIds = [331],
                Pools =
                [
                    new(StorePools.SilverGear) { VersionIdx = 0, Tokens = "Custom0Tokens[0]=0.08f,Custom0Tokens[1]=0.11f,Custom0Tokens[2]=0.14f,Custom0Tokens[3]=0.17f,Custom0Tokens[4]=0.20f" },
                ],
            },
            new()
            {
                UniqueName = "SFXGameContentDLC_CON_MP2.SFXGameEffect_MatchConsumable_Gear_MeleeDamage", Kind = ReinforcementKind.MatchConsumableGear, Rarity = CardRarity.Uncommon, MaxCount = 5, UseVersionIdx = false, VersionIdx = 0, Category = 4,
                GUIName = 733122, GUIDescription = 733123, GUICategory = CardGUICategory.MatchConsumableGear, GUIType = "gearUpgrade", GUITextureRef = "DLC_MPImages.Cards.DLC_MeleeDamage",
                PlayerVariableIds = [330],
                Pools =
                [
                    new(StorePools.SilverGear) { VersionIdx = 0, Tokens = "Custom0Tokens[0]=0.10f,Custom0Tokens[1]=0.125f,Custom0Tokens[2]=0.15f,Custom0Tokens[3]=0.175f,Custom0Tokens[4]=0.20f" },
                ],
            },
            new()
            {
                UniqueName = "SFXGameContentDLC_CON_MP2.SFXGameEffect_MatchConsumable_Gear_PowerBonus_Cooldown", Kind = ReinforcementKind.MatchConsumableGear, Rarity = CardRarity.Uncommon, MaxCount = 5, UseVersionIdx = false, VersionIdx = 0, Category = 4,
                GUIName = 733124, GUIDescription = 733125, GUICategory = CardGUICategory.MatchConsumableGear, GUIType = "gearUpgrade", GUITextureRef = "GUI_MPImages.Cards.BoostTime",
                PlayerVariableIds = [333],
                Pools =
                [
                    new(StorePools.SilverGear) { VersionIdx = 0, Tokens = "Custom0Tokens[0]=0.05f,Custom0Tokens[1]=0.075f,Custom0Tokens[2]=0.1f,Custom0Tokens[3]=0.125f,Custom0Tokens[4]=0.15f" },
                ],
            },
            new()
            {
                UniqueName = "SFXGameContentDLC_CON_MP2.SFXGameEffect_MatchConsumable_Gear_PowerBonus_Damage", Kind = ReinforcementKind.MatchConsumableGear, Rarity = CardRarity.Uncommon, MaxCount = 5, UseVersionIdx = false, VersionIdx = 0, Category = 4,
                GUIName = 733126, GUIDescription = 733127, GUICategory = CardGUICategory.MatchConsumableGear, GUIType = "gearUpgrade", GUITextureRef = "GUI_MPImages.Cards.BoostPower",
                PlayerVariableIds = [332],
                Pools =
                [
                    new(StorePools.SilverGear) { VersionIdx = 0, Tokens = "Custom0Tokens[0]=0.04f,Custom0Tokens[1]=0.06f,Custom0Tokens[2]=0.08f,Custom0Tokens[3]=0.10f,Custom0Tokens[4]=0.12f" },
                ],
            },
            new()
            {
                UniqueName = "SFXGameContentDLC_CON_MP2.SFXGameEffect_MatchConsumable_Gear_ShieldRegen", Kind = ReinforcementKind.MatchConsumableGear, Rarity = CardRarity.Uncommon, MaxCount = 5, UseVersionIdx = false, VersionIdx = 0, Category = 4,
                GUIName = 733128, GUIDescription = 733129, GUICategory = CardGUICategory.MatchConsumableGear, GUIType = "gearUpgrade", GUITextureRef = "DLC_MPImages.Cards.DLC_ShieldRegen",
                PlayerVariableIds = [335],
                Pools =
                [
                    new(StorePools.SilverGear) { VersionIdx = 0, Tokens = "Custom0Tokens[0]=0.05f,Custom0Tokens[1]=0.075f,Custom0Tokens[2]=0.1f,Custom0Tokens[3]=0.125f,Custom0Tokens[4]=0.15f" },
                ],
            },
            new()
            {
                UniqueName = "SFXGameContentDLC_CON_MP2.SFXGameEffect_MatchConsumable_Gear_ShieldStrength", Kind = ReinforcementKind.MatchConsumableGear, Rarity = CardRarity.Uncommon, MaxCount = 5, UseVersionIdx = false, VersionIdx = 0, Category = 4,
                GUIName = 733130, GUIDescription = 733131, GUICategory = CardGUICategory.MatchConsumableGear, GUIType = "gearUpgrade", GUITextureRef = "GUI_MPImages.Cards.BoostShields",
                PlayerVariableIds = [334],
                Pools =
                [
                    new(StorePools.SilverGear) { VersionIdx = 0, Tokens = "Custom0Tokens[0]=0.1f,Custom0Tokens[1]=0.15f,Custom0Tokens[2]=0.2f,Custom0Tokens[3]=0.25f,Custom0Tokens[4]=0.3f" },
                ],
            },
            new()
            {
                UniqueName = "SFXGameContentDLC_CON_MP2.SFXGameEffect_MatchConsumable_Gear_WeaponDamage_AssaultRifle", Kind = ReinforcementKind.MatchConsumableGear, Rarity = CardRarity.Uncommon, MaxCount = 5, UseVersionIdx = false, VersionIdx = 0, Category = 4,
                GUIName = 733132, GUIDescription = 733285, GUICategory = CardGUICategory.MatchConsumableGear, GUIType = "gearUpgrade", GUITextureRef = "GUI_MPImages.Cards.DamageAssault",
                PlayerVariableIds = [337],
                Pools =
                [
                    new(StorePools.SilverGear) { VersionIdx = 0, Tokens = "Custom0Tokens[0]=0.05f,Custom0Tokens[1]=0.075f,Custom0Tokens[2]=0.1f,Custom0Tokens[3]=0.125f,Custom0Tokens[4]=0.15f" },
                ],
            },
            new()
            {
                UniqueName = "SFXGameContentDLC_CON_MP2.SFXGameEffect_MatchConsumable_Gear_WeaponDamage_SniperRifle", Kind = ReinforcementKind.MatchConsumableGear, Rarity = CardRarity.Uncommon, MaxCount = 5, UseVersionIdx = false, VersionIdx = 0, Category = 4,
                GUIName = 733133, GUIDescription = 733286, GUICategory = CardGUICategory.MatchConsumableGear, GUIType = "gearUpgrade", GUITextureRef = "GUI_MPImages.Cards.DamageSniper",
                PlayerVariableIds = [338],
                Pools =
                [
                    new(StorePools.SilverGear) { VersionIdx = 0, Tokens = "Custom0Tokens[0]=0.05f,Custom0Tokens[1]=0.075f,Custom0Tokens[2]=0.1f,Custom0Tokens[3]=0.125f,Custom0Tokens[4]=0.15f" },
                ],
            },
            new()
            {
                UniqueName = "SFXGameContentDLC_CON_MP2.SFXGameEffect_MatchConsumable_Gear_WeaponDamage_Shotgun", Kind = ReinforcementKind.MatchConsumableGear, Rarity = CardRarity.Uncommon, MaxCount = 5, UseVersionIdx = false, VersionIdx = 0, Category = 4,
                GUIName = 733134, GUIDescription = 733287, GUICategory = CardGUICategory.MatchConsumableGear, GUIType = "gearUpgrade", GUITextureRef = "GUI_MPImages.Cards.DamageShotgun",
                PlayerVariableIds = [339],
                Pools =
                [
                    new(StorePools.SilverGear) { VersionIdx = 0, Tokens = "Custom0Tokens[0]=0.05f,Custom0Tokens[1]=0.075f,Custom0Tokens[2]=0.1f,Custom0Tokens[3]=0.125f,Custom0Tokens[4]=0.15f" },
                ],
            },
            new()
            {
                UniqueName = "SFXGameContentDLC_CON_MP2.SFXGameEffect_MatchConsumable_Gear_WeaponDamage_Pistol", Kind = ReinforcementKind.MatchConsumableGear, Rarity = CardRarity.Uncommon, MaxCount = 5, UseVersionIdx = false, VersionIdx = 0, Category = 4,
                GUIName = 733135, GUIDescription = 733288, GUICategory = CardGUICategory.MatchConsumableGear, GUIType = "gearUpgrade", GUITextureRef = "GUI_MPImages.Cards.DamagePistol",
                PlayerVariableIds = [340],
                Pools =
                [
                    new(StorePools.SilverGear) { VersionIdx = 0, Tokens = "Custom0Tokens[0]=0.05f,Custom0Tokens[1]=0.075f,Custom0Tokens[2]=0.1f,Custom0Tokens[3]=0.125f,Custom0Tokens[4]=0.15f" },
                ],
            },
            new()
            {
                UniqueName = "SFXGameContentDLC_CON_MP2.SFXGameEffect_MatchConsumable_Gear_WeaponDamage_SMG", Kind = ReinforcementKind.MatchConsumableGear, Rarity = CardRarity.Uncommon, MaxCount = 5, UseVersionIdx = false, VersionIdx = 0, Category = 4,
                GUIName = 733136, GUIDescription = 733289, GUICategory = CardGUICategory.MatchConsumableGear, GUIType = "gearUpgrade", GUITextureRef = "GUI_MPImages.Cards.DamageSMG",
                PlayerVariableIds = [341],
                Pools =
                [
                    new(StorePools.SilverGear) { VersionIdx = 0, Tokens = "Custom0Tokens[0]=0.05f,Custom0Tokens[1]=0.075f,Custom0Tokens[2]=0.1f,Custom0Tokens[3]=0.125f,Custom0Tokens[4]=0.15f" },
                ],
            },
            new()
            {
                UniqueName = "SFXGameContentDLC_CON_MP2.SFXGameEffect_MatchConsumable_Gear_WeaponStability", Kind = ReinforcementKind.MatchConsumableGear, Rarity = CardRarity.Uncommon, MaxCount = 5, UseVersionIdx = false, VersionIdx = 0, Category = 4,
                GUIName = 733137, GUIDescription = 733290, GUICategory = CardGUICategory.MatchConsumableGear, GUIType = "gearUpgrade", GUITextureRef = "DLC_MPImages.Cards.DLC_Stability",
                PlayerVariableIds = [701],
                Pools =
                [
                    new(StorePools.SilverGear) { VersionIdx = 0, Tokens = "Custom0Tokens[0]=0.15f,Custom0Tokens[1]=0.22f,Custom0Tokens[2]=0.28f,Custom0Tokens[3]=0.34f,Custom0Tokens[4]=0.40f" },
                ],
            },
            new()
            {
                UniqueName = "SFXGameMPContentDLC_Shared_MP.SFXGameEffect_MatchConsumable_Gear_AmmoCapacity", Kind = ReinforcementKind.MatchConsumableGear, Rarity = CardRarity.Uncommon, MaxCount = 5, UseVersionIdx = false, VersionIdx = 0, Category = 4,
                GUIName = 750122, GUIDescription = 750123, GUICategory = CardGUICategory.MatchConsumableGear, GUIType = "gearUpgrade", GUITextureRef = "GUI_MPImages_MP3.GearAmmo",
                PlayerVariableIds = [423, 441, 452],
                Pools =
                [
                    new(StorePools.SilverGear) { VersionIdx = 0, Tokens = "Custom0Tokens[0]=0.1f,Custom0Tokens[1]=0.15f,Custom0Tokens[2]=0.2f,Custom0Tokens[3]=0.25f,Custom0Tokens[4]=0.3f" },
                ],
            },
            new()
            {
                UniqueName = "SFXGameMPContentDLC_Shared_MP.SFXGameEffect_MatchConsumable_Gear_BioticDamage", Kind = ReinforcementKind.MatchConsumableGear, Rarity = CardRarity.Uncommon, MaxCount = 5, UseVersionIdx = false, VersionIdx = 0, Category = 4,
                GUIName = 750120, GUIDescription = 750121, GUICategory = CardGUICategory.MatchConsumableGear, GUIType = "gearUpgrade", GUITextureRef = "GUI_MPImages_MP3.GearBioticDmg",
                PlayerVariableIds = [424, 442, 453],
                Pools =
                [
                    new(StorePools.SilverGear) { VersionIdx = 0, Tokens = "Custom0Tokens[0]=0.05f,Custom0Tokens[1]=0.075f,Custom0Tokens[2]=0.1f,Custom0Tokens[3]=0.125f,Custom0Tokens[4]=0.15f" },
                ],
            },
            new()
            {
                UniqueName = "SFXGameMPContentDLC_Shared_MP.SFXGameEffect_MatchConsumable_Gear_TechDamage", Kind = ReinforcementKind.MatchConsumableGear, Rarity = CardRarity.Uncommon, MaxCount = 5, UseVersionIdx = false, VersionIdx = 0, Category = 4,
                GUIName = 750118, GUIDescription = 750119, GUICategory = CardGUICategory.MatchConsumableGear, GUIType = "gearUpgrade", GUITextureRef = "GUI_MPImages_MP3.GearTechDmg",
                PlayerVariableIds = [425, 443, 454],
                Pools =
                [
                    new(StorePools.SilverGear) { VersionIdx = 0, Tokens = "Custom0Tokens[0]=0.05f,Custom0Tokens[1]=0.075f,Custom0Tokens[2]=0.1f,Custom0Tokens[3]=0.125f,Custom0Tokens[4]=0.15f" },
                ],
            },
            new()
            {
                UniqueName = "SFXGameMPContentDLC_Shared_MP.SFXGameEffect_MatchConsumable_Gear_WeaponDamage_All", Kind = ReinforcementKind.MatchConsumableGear, Rarity = CardRarity.Uncommon, MaxCount = 5, UseVersionIdx = false, VersionIdx = 0, Category = 4,
                GUIName = 750124, GUIDescription = 750125, GUICategory = CardGUICategory.MatchConsumableGear, GUIType = "gearUpgrade", GUITextureRef = "GUI_MPImages_MP3.GearWeaponDmg",
                PlayerVariableIds = [426, 444, 455],
                Pools =
                [
                    new(StorePools.SilverGear) { VersionIdx = 0, Tokens = "Custom0Tokens[0]=0.03f,Custom0Tokens[1]=0.05f,Custom0Tokens[2]=0.07f,Custom0Tokens[3]=0.085f,Custom0Tokens[4]=0.1f" },
                ],
            },
            new()
            {
                UniqueName = "SFXGameContentDLC_CON_MP4.SFXGameEffect_MatchConsumable_Gear_MassMedigel", Kind = ReinforcementKind.MatchConsumableGear, Rarity = CardRarity.Rare, MaxCount = 5, UseVersionIdx = false, VersionIdx = 0, Category = 4,
                GUIName = 770267, GUIDescription = 770268, GUICategory = CardGUICategory.MatchConsumableGear, GUIType = "gearUpgrade", GUITextureRef = "GUI_MPImages_MP4.MediAll",
                PlayerVariableIds = [536],
                Pools =
                [
                    new(StorePools.GoldGear) { VersionIdx = 0, Tokens = "Custom3Tokens[0]=10,Custom3Tokens[1]=15,Custom3Tokens[2]=20,Custom3Tokens[3]=25,Custom3Tokens[4]=30" },
                ],
            },
            new()
            {
                UniqueName = "SFXGameContentDLC_CON_MP4.SFXGameEffect_MatchConsumable_Gear_CobraCapacity", Kind = ReinforcementKind.MatchConsumableGear, Rarity = CardRarity.Rare, MaxCount = 5, UseVersionIdx = false, VersionIdx = 0, Category = 4,
                GUIName = 770269, GUIDescription = 770270, GUICategory = CardGUICategory.MatchConsumableGear, GUIType = "gearUpgrade", GUITextureRef = "GUI_MPImages_MP4.RcktCapAmmoCap",
                PlayerVariableIds = [537],
                Pools =
                [
                    new(StorePools.GoldGear) { VersionIdx = 0, Tokens = "Custom3Tokens[0]=1,Custom3Tokens[1]=1,Custom3Tokens[2]=2,Custom3Tokens[3]=2,Custom3Tokens[4]=3,Custom0Tokens[0]=0.05f,Custom0Tokens[1]=0.075f,Custom0Tokens[2]=0.1f,Custom0Tokens[3]=0.125f,Custom0Tokens[4]=0.15f" },
                ],
            },
            new()
            {
                UniqueName = "SFXGameContentDLC_CON_MP4.SFXGameEffect_MatchConsumable_Gear_MedigelCapacity", Kind = ReinforcementKind.MatchConsumableGear, Rarity = CardRarity.Rare, MaxCount = 5, UseVersionIdx = false, VersionIdx = 0, Category = 4,
                GUIName = 770273, GUIDescription = 770274, GUICategory = CardGUICategory.MatchConsumableGear, GUIType = "gearUpgrade", GUITextureRef = "GUI_MPImages_MP4.MediCapShldGen",
                PlayerVariableIds = [538],
                Pools =
                [
                    new(StorePools.GoldGear) { VersionIdx = 0, Tokens = "Custom3Tokens[0]=1,Custom3Tokens[1]=1,Custom3Tokens[2]=2,Custom3Tokens[3]=2,Custom3Tokens[4]=3,Custom0Tokens[0]=0.04f,Custom0Tokens[1]=0.06f,Custom0Tokens[2]=0.08f,Custom0Tokens[3]=0.1f,Custom0Tokens[4]=0.12f" },
                ],
            },
            new()
            {
                UniqueName = "SFXGameContentDLC_CON_MP4.SFXGameEffect_MatchConsumable_Gear_SurvivalCapacity", Kind = ReinforcementKind.MatchConsumableGear, Rarity = CardRarity.Rare, MaxCount = 5, UseVersionIdx = false, VersionIdx = 0, Category = 4,
                GUIName = 770275, GUIDescription = 770276, GUICategory = CardGUICategory.MatchConsumableGear, GUIType = "gearUpgrade", GUITextureRef = "GUI_MPImages_MP4.ShldCapShldStr",
                PlayerVariableIds = [539],
                Pools =
                [
                    new(StorePools.GoldGear) { VersionIdx = 0, Tokens = "Custom3Tokens[0]=1,Custom3Tokens[1]=1,Custom3Tokens[2]=2,Custom3Tokens[3]=2,Custom3Tokens[4]=3,Custom0Tokens[0]=0.06f,Custom0Tokens[1]=0.1f,Custom0Tokens[2]=0.14f,Custom0Tokens[3]=0.17f,Custom0Tokens[4]=0.2f" },
                ],
            },
            new()
            {
                UniqueName = "SFXGameContentDLC_CON_MP4.SFXGameEffect_MatchConsumable_Gear_ThermalCapacity", Kind = ReinforcementKind.MatchConsumableGear, Rarity = CardRarity.Rare, MaxCount = 5, UseVersionIdx = false, VersionIdx = 0, Category = 4,
                GUIName = 770271, GUIDescription = 770272, GUICategory = CardGUICategory.MatchConsumableGear, GUIType = "gearUpgrade", GUITextureRef = "GUI_MPImages_MP4.AmmoCapWpnDmg",
                PlayerVariableIds = [540],
                Pools =
                [
                    new(StorePools.GoldGear) { VersionIdx = 0, Tokens = "Custom3Tokens[0]=1,Custom3Tokens[1]=1,Custom3Tokens[2]=2,Custom3Tokens[3]=2,Custom3Tokens[4]=3,Custom0Tokens[0]=0.02f,Custom0Tokens[1]=0.04f,Custom0Tokens[2]=0.06f,Custom0Tokens[3]=0.07f,Custom0Tokens[4]=0.08f" },
                ],
            },
            new()
            {
                UniqueName = "SFXGameContentDLC_CON_MP5.SFXGameEffect_MatchConsumable_Gear_VisionHelmet", Kind = ReinforcementKind.MatchConsumableGear, Rarity = CardRarity.Rare, MaxCount = 5, UseVersionIdx = false, VersionIdx = 0, Category = 4,
                GUIName = 812168, GUIDescription = 812169, GUICategory = CardGUICategory.MatchConsumableGear, GUIType = "gearUpgrade", GUITextureRef = "DLC_MPImages_MP5.GethScanner",
                PlayerVariableIds = [603],
                Pools =
                [
                    new(StorePools.GoldGear) { VersionIdx = 0, Tokens = "Custom0Tokens[0]=0.1f,Custom0Tokens[1]=0.125f,Custom0Tokens[2]=0.15f,Custom0Tokens[3]=0.175f,Custom0Tokens[4]=0.20f" },
                ],
            },
            new()
            {
                UniqueName = "SFXGameContentDLC_CON_MP5.SFXGameEffect_MatchConsumable_Gear_BatarianGauntlet", Kind = ReinforcementKind.MatchConsumableGear, Rarity = CardRarity.Rare, MaxCount = 5, UseVersionIdx = false, VersionIdx = 0, Category = 4,
                GUIName = 812523, GUIDescription = 812524, GUICategory = CardGUICategory.MatchConsumableGear, GUIType = "gearUpgrade", GUITextureRef = "DLC_MPImages_MP5.BatarianGauntlet",
                PlayerVariableIds = [604],
                Pools =
                [
                    new(StorePools.GoldGear) { VersionIdx = 0, Tokens = "Custom0Tokens[0]=6.00f,Custom0Tokens[1]=6.50f,Custom0Tokens[2]=7.00f,Custom0Tokens[3]=7.50f,Custom0Tokens[4]=8.00f" },
                ],
            },
            new()
            {
                UniqueName = "SFXGameContentDLC_CON_MP2.SFXGameEffect_MatchConsumable_Gear_GrenadeCapacity", Kind = ReinforcementKind.MatchConsumableGear, Rarity = CardRarity.Rare, MaxCount = 5, UseVersionIdx = false, VersionIdx = 0, Category = 4,
                GUIName = 733576, GUIDescription = 733577, GUICategory = CardGUICategory.MatchConsumableGear, GUIType = "gearUpgrade", GUITextureRef = "GUI_MPImages_MP2.GrenadeAdd",
                PlayerVariableIds = [343],
                Pools =
                [
                    new(StorePools.GoldGear) { VersionIdx = 0, Tokens = "Custom3Tokens[0]=1,Custom3Tokens[1]=2,Custom3Tokens[2]=3,Custom3Tokens[3]=4,Custom3Tokens[4]=5" },
                    new(StorePools.GoldBackup) { VersionIdx = 0, Tokens = "Custom3Tokens[0]=1,Custom3Tokens[1]=2,Custom3Tokens[2]=3,Custom3Tokens[3]=4,Custom3Tokens[4]=5" },
                ],
            },
            new()
            {
                UniqueName = "SFXGameContentDLC_CON_MP2.SFXGameEffect_MatchConsumable_Gear_Combo_AssaultDamageGrenadeCap", Kind = ReinforcementKind.MatchConsumableGear, Rarity = CardRarity.Rare, MaxCount = 5, UseVersionIdx = false, VersionIdx = 0, Category = 4,
                GUIName = 733590, GUIDescription = 733591, GUICategory = CardGUICategory.MatchConsumableGear, GUIType = "gearUpgrade", GUITextureRef = "GUI_MPImages_MP2.CmboRifleGenade",
                PlayerVariableIds = [344],
                Pools =
                [
                    new(StorePools.GoldGear) { VersionIdx = 0, Tokens = "Custom0Tokens[0]=0.04f,Custom0Tokens[1]=0.06f,Custom0Tokens[2]=0.08f,Custom0Tokens[3]=0.1f,Custom0Tokens[4]=0.12f,Custom3Tokens[0]=1,Custom3Tokens[1]=1,Custom3Tokens[2]=1,Custom3Tokens[3]=2,Custom3Tokens[4]=2" },
                    new(StorePools.GoldBackup) { VersionIdx = 0, Tokens = "Custom0Tokens[0]=0.04f,Custom0Tokens[1]=0.06f,Custom0Tokens[2]=0.08f,Custom0Tokens[3]=0.1f,Custom0Tokens[4]=0.12f,Custom3Tokens[0]=1,Custom3Tokens[1]=1,Custom3Tokens[2]=1,Custom3Tokens[3]=2,Custom3Tokens[4]=2" },
                ],
            },
            new()
            {
                UniqueName = "SFXGameContentDLC_CON_MP2.SFXGameEffect_MatchConsumable_Gear_Combo_PistolDamageBioticDamage", Kind = ReinforcementKind.MatchConsumableGear, Rarity = CardRarity.Rare, MaxCount = 5, UseVersionIdx = false, VersionIdx = 0, Category = 4,
                GUIName = 733592, GUIDescription = 733593, GUICategory = CardGUICategory.MatchConsumableGear, GUIType = "gearUpgrade", GUITextureRef = "GUI_MPImages_MP2.CmboPistolBio",
                PlayerVariableIds = [345],
                Pools =
                [
                    new(StorePools.GoldGear) { VersionIdx = 0, Tokens = "Custom0Tokens[0]=0.04f,Custom0Tokens[1]=0.06f,Custom0Tokens[2]=0.08f,Custom0Tokens[3]=0.1f,Custom0Tokens[4]=0.12f,Custom1Tokens[0]=0.04f,Custom1Tokens[1]=0.06f,Custom1Tokens[2]=0.08f,Custom1Tokens[3]=0.1f,Custom1Tokens[4]=0.12f" },
                    new(StorePools.GoldBackup) { VersionIdx = 0, Tokens = "Custom0Tokens[0]=0.04f,Custom0Tokens[1]=0.06f,Custom0Tokens[2]=0.08f,Custom0Tokens[3]=0.1f,Custom0Tokens[4]=0.12f,Custom1Tokens[0]=0.04f,Custom1Tokens[1]=0.06f,Custom1Tokens[2]=0.08f,Custom1Tokens[3]=0.1f,Custom1Tokens[4]=0.12f" },
                ],
            },
            new()
            {
                UniqueName = "SFXGameContentDLC_CON_MP2.SFXGameEffect_MatchConsumable_Gear_Combo_ShieldStrengthShieldRegen", Kind = ReinforcementKind.MatchConsumableGear, Rarity = CardRarity.Rare, MaxCount = 5, UseVersionIdx = false, VersionIdx = 0, Category = 4,
                GUIName = 733594, GUIDescription = 733595, GUICategory = CardGUICategory.MatchConsumableGear, GUIType = "gearUpgrade", GUITextureRef = "GUI_MPImages_MP2.CmboShieldStgRegen",
                PlayerVariableIds = [346],
                Pools =
                [
                    new(StorePools.GoldGear) { VersionIdx = 0, Tokens = "Custom0Tokens[0]=0.06f,Custom0Tokens[1]=0.1f,Custom0Tokens[2]=0.14f,Custom0Tokens[3]=0.17f,Custom0Tokens[4]=0.2f,Custom1Tokens[0]=0.04f,Custom1Tokens[1]=0.06f,Custom1Tokens[2]=0.08f,Custom1Tokens[3]=0.1f,Custom1Tokens[4]=0.12f" },
                    new(StorePools.GoldBackup) { VersionIdx = 0, Tokens = "Custom0Tokens[0]=0.06f,Custom0Tokens[1]=0.1f,Custom0Tokens[2]=0.14f,Custom0Tokens[3]=0.17f,Custom0Tokens[4]=0.2f,Custom1Tokens[0]=0.04f,Custom1Tokens[1]=0.06f,Custom1Tokens[2]=0.08f,Custom1Tokens[3]=0.1f,Custom1Tokens[4]=0.12f" },
                ],
            },
            new()
            {
                UniqueName = "SFXGameContentDLC_CON_MP2.SFXGameEffect_MatchConsumable_Gear_Combo_ShotgunDamageMeleeDamage", Kind = ReinforcementKind.MatchConsumableGear, Rarity = CardRarity.Rare, MaxCount = 5, UseVersionIdx = false, VersionIdx = 0, Category = 4,
                GUIName = 733596, GUIDescription = 733597, GUICategory = CardGUICategory.MatchConsumableGear, GUIType = "gearUpgrade", GUITextureRef = "GUI_MPImages_MP2.CmboShotgunMelee",
                PlayerVariableIds = [347],
                Pools =
                [
                    new(StorePools.GoldGear) { VersionIdx = 0, Tokens = "Custom0Tokens[0]=0.04f,Custom0Tokens[1]=0.06f,Custom0Tokens[2]=0.08f,Custom0Tokens[3]=0.1f,Custom0Tokens[4]=0.12f,Custom1Tokens[0]=0.04f,Custom1Tokens[1]=0.06f,Custom1Tokens[2]=0.08f,Custom1Tokens[3]=0.1f,Custom1Tokens[4]=0.12f" },
                    new(StorePools.GoldBackup) { VersionIdx = 0, Tokens = "Custom0Tokens[0]=0.04f,Custom0Tokens[1]=0.06f,Custom0Tokens[2]=0.08f,Custom0Tokens[3]=0.1f,Custom0Tokens[4]=0.12f,Custom1Tokens[0]=0.04f,Custom1Tokens[1]=0.06f,Custom1Tokens[2]=0.08f,Custom1Tokens[3]=0.1f,Custom1Tokens[4]=0.12f" },
                ],
            },
            new()
            {
                UniqueName = "SFXGameContentDLC_CON_MP2.SFXGameEffect_MatchConsumable_Gear_Combo_SMGDamagePowerCooldown", Kind = ReinforcementKind.MatchConsumableGear, Rarity = CardRarity.Rare, MaxCount = 5, UseVersionIdx = false, VersionIdx = 0, Category = 4,
                GUIName = 733598, GUIDescription = 733599, GUICategory = CardGUICategory.MatchConsumableGear, GUIType = "gearUpgrade", GUITextureRef = "GUI_MPImages_MP2.CmboSMGCooldwn",
                PlayerVariableIds = [348],
                Pools =
                [
                    new(StorePools.GoldGear) { VersionIdx = 0, Tokens = "Custom0Tokens[0]=0.04f,Custom0Tokens[1]=0.06f,Custom0Tokens[2]=0.08f,Custom0Tokens[3]=0.1f,Custom0Tokens[4]=0.12f,Custom1Tokens[0]=0.04f,Custom1Tokens[1]=0.06f,Custom1Tokens[2]=0.08f,Custom1Tokens[3]=0.1f,Custom1Tokens[4]=0.12f" },
                    new(StorePools.GoldBackup) { VersionIdx = 0, Tokens = "Custom0Tokens[0]=0.04f,Custom0Tokens[1]=0.06f,Custom0Tokens[2]=0.08f,Custom0Tokens[3]=0.1f,Custom0Tokens[4]=0.12f,Custom1Tokens[0]=0.04f,Custom1Tokens[1]=0.06f,Custom1Tokens[2]=0.08f,Custom1Tokens[3]=0.1f,Custom1Tokens[4]=0.12f" },
                ],
            },
            new()
            {
                UniqueName = "SFXGameContentDLC_CON_MP2.SFXGameEffect_MatchConsumable_Gear_Combo_SniperDamageTechDamage", Kind = ReinforcementKind.MatchConsumableGear, Rarity = CardRarity.Rare, MaxCount = 5, UseVersionIdx = false, VersionIdx = 0, Category = 4,
                GUIName = 733600, GUIDescription = 733604, GUICategory = CardGUICategory.MatchConsumableGear, GUIType = "gearUpgrade", GUITextureRef = "GUI_MPImages_MP2.CmboSniperTech",
                PlayerVariableIds = [349],
                Pools =
                [
                    new(StorePools.GoldGear) { VersionIdx = 0, Tokens = "Custom0Tokens[0]=0.04f,Custom0Tokens[1]=0.06f,Custom0Tokens[2]=0.08f,Custom0Tokens[3]=0.1f,Custom0Tokens[4]=0.12f,Custom1Tokens[0]=0.04f,Custom1Tokens[1]=0.06f,Custom1Tokens[2]=0.08f,Custom1Tokens[3]=0.1f,Custom1Tokens[4]=0.12f" },
                    new(StorePools.GoldBackup) { VersionIdx = 0, Tokens = "Custom0Tokens[0]=0.04f,Custom0Tokens[1]=0.06f,Custom0Tokens[2]=0.08f,Custom0Tokens[3]=0.1f,Custom0Tokens[4]=0.12f,Custom1Tokens[0]=0.04f,Custom1Tokens[1]=0.06f,Custom1Tokens[2]=0.08f,Custom1Tokens[3]=0.1f,Custom1Tokens[4]=0.12f" },
                ],
            },
            new()
            {
                UniqueName = "SFXGameContentDLC_CON_MP3.SFXGameEffect_MatchConsumable_Gear_Combo_AssaultRifleDamagePistolDamage", Kind = ReinforcementKind.MatchConsumableGear, Rarity = CardRarity.Rare, MaxCount = 5, UseVersionIdx = false, VersionIdx = 0, Category = 4,
                GUIName = 750128, GUIDescription = 750129, GUICategory = CardGUICategory.MatchConsumableGear, GUIType = "gearUpgrade", GUITextureRef = "GUI_MPImages_MP3.GearAssltPistlDmg",
                PlayerVariableIds = [416, 434, 445],
                Pools =
                [
                    new(StorePools.GoldGear) { VersionIdx = 0, Tokens = "Custom0Tokens[0]=0.04f,Custom0Tokens[1]=0.06f,Custom0Tokens[2]=0.08f,Custom0Tokens[3]=0.1f,Custom0Tokens[4]=0.12f,Custom1Tokens[0]=0.04f,Custom1Tokens[1]=0.06f,Custom1Tokens[2]=0.08f,Custom1Tokens[3]=0.1f,Custom1Tokens[4]=0.12f" },
                ],
            },
            new()
            {
                UniqueName = "SFXGameContentDLC_CON_MP3.SFXGameEffect_MatchConsumable_Gear_Combo_MeleeDamageBioticDamage", Kind = ReinforcementKind.MatchConsumableGear, Rarity = CardRarity.Rare, MaxCount = 5, UseVersionIdx = false, VersionIdx = 0, Category = 4,
                GUIName = 750136, GUIDescription = 750137, GUICategory = CardGUICategory.MatchConsumableGear, GUIType = "gearUpgrade", GUITextureRef = "GUI_MPImages_MP3.GearMeleBioDmg",
                PlayerVariableIds = [417, 435, 446],
                Pools =
                [
                    new(StorePools.GoldGear) { VersionIdx = 0, Tokens = "Custom0Tokens[0]=0.04f,Custom0Tokens[1]=0.06f,Custom0Tokens[2]=0.08f,Custom0Tokens[3]=0.1f,Custom0Tokens[4]=0.12f,Custom1Tokens[0]=0.04f,Custom1Tokens[1]=0.06f,Custom1Tokens[2]=0.08f,Custom1Tokens[3]=0.1f,Custom1Tokens[4]=0.12f" },
                ],
            },
            new()
            {
                UniqueName = "SFXGameContentDLC_CON_MP3.SFXGameEffect_MatchConsumable_Gear_Combo_ShieldStrengthMeleeDamage", Kind = ReinforcementKind.MatchConsumableGear, Rarity = CardRarity.Rare, MaxCount = 5, UseVersionIdx = false, VersionIdx = 0, Category = 4,
                GUIName = 750134, GUIDescription = 750135, GUICategory = CardGUICategory.MatchConsumableGear, GUIType = "gearUpgrade", GUITextureRef = "GUI_MPImages_MP3.GearMeleShldDmg",
                PlayerVariableIds = [418, 436, 447],
                Pools =
                [
                    new(StorePools.GoldGear) { VersionIdx = 0, Tokens = "Custom0Tokens[0]=0.06f,Custom0Tokens[1]=0.1f,Custom0Tokens[2]=0.14f,Custom0Tokens[3]=0.17f,Custom0Tokens[4]=0.2f,Custom1Tokens[0]=0.04f,Custom1Tokens[1]=0.06f,Custom1Tokens[2]=0.08f,Custom1Tokens[3]=0.1f,Custom1Tokens[4]=0.12f" },
                ],
            },
            new()
            {
                UniqueName = "SFXGameContentDLC_CON_MP3.SFXGameEffect_MatchConsumable_Gear_Combo_ShotgunDamageGrenadeCap", Kind = ReinforcementKind.MatchConsumableGear, Rarity = CardRarity.Rare, MaxCount = 5, UseVersionIdx = false, VersionIdx = 0, Category = 4,
                GUIName = 750130, GUIDescription = 750131, GUICategory = CardGUICategory.MatchConsumableGear, GUIType = "gearUpgrade", GUITextureRef = "GUI_MPImages_MP3.GearShotGrdDmg",
                PlayerVariableIds = [419, 437, 448],
                Pools =
                [
                    new(StorePools.GoldGear) { VersionIdx = 0, Tokens = "Custom0Tokens[0]=0.04f,Custom0Tokens[1]=0.06f,Custom0Tokens[2]=0.08f,Custom0Tokens[3]=0.1f,Custom0Tokens[4]=0.12f,Custom3Tokens[0]=1,Custom3Tokens[1]=1,Custom3Tokens[2]=1,Custom3Tokens[3]=2,Custom3Tokens[4]=2" },
                ],
            },
            new()
            {
                UniqueName = "SFXGameContentDLC_CON_MP3.SFXGameEffect_MatchConsumable_Gear_Combo_SniperDamageSMGDamage", Kind = ReinforcementKind.MatchConsumableGear, Rarity = CardRarity.Rare, MaxCount = 5, UseVersionIdx = false, VersionIdx = 0, Category = 4,
                GUIName = 750126, GUIDescription = 750127, GUICategory = CardGUICategory.MatchConsumableGear, GUIType = "gearUpgrade", GUITextureRef = "GUI_MPImages_MP3.GearSMGSnpDmg",
                PlayerVariableIds = [420, 438, 449],
                Pools =
                [
                    new(StorePools.GoldGear) { VersionIdx = 0, Tokens = "Custom0Tokens[0]=0.04f,Custom0Tokens[1]=0.06f,Custom0Tokens[2]=0.08f,Custom0Tokens[3]=0.1f,Custom0Tokens[4]=0.12f,Custom1Tokens[0]=0.04f,Custom1Tokens[1]=0.06f,Custom1Tokens[2]=0.08f,Custom1Tokens[3]=0.1f,Custom1Tokens[4]=0.12f" },
                ],
            },
            new()
            {
                UniqueName = "SFXGameContentDLC_CON_MP3.SFXGameEffect_MatchConsumable_Gear_Combo_TechDamagePowerCooldown", Kind = ReinforcementKind.MatchConsumableGear, Rarity = CardRarity.Rare, MaxCount = 5, UseVersionIdx = false, VersionIdx = 0, Category = 4,
                GUIName = 750138, GUIDescription = 750139, GUICategory = CardGUICategory.MatchConsumableGear, GUIType = "gearUpgrade", GUITextureRef = "GUI_MPImages_MP3.GearTechCoolDmg",
                PlayerVariableIds = [421, 439, 450],
                Pools =
                [
                    new(StorePools.GoldGear) { VersionIdx = 0, Tokens = "Custom0Tokens[0]=0.04f,Custom0Tokens[1]=0.06f,Custom0Tokens[2]=0.08f,Custom0Tokens[3]=0.1f,Custom0Tokens[4]=0.12f,Custom1Tokens[0]=0.04f,Custom1Tokens[1]=0.06f,Custom1Tokens[2]=0.08f,Custom1Tokens[3]=0.1f,Custom1Tokens[4]=0.12f" },
                ],
            },
            new()
            {
                UniqueName = "SFXGameContentDLC_CON_MP3.SFXGameEffect_MatchConsumable_Gear_Combo_WeaponStabilityAmmoCapacity", Kind = ReinforcementKind.MatchConsumableGear, Rarity = CardRarity.Rare, MaxCount = 5, UseVersionIdx = false, VersionIdx = 0, Category = 4,
                GUIName = 750132, GUIDescription = 750133, GUICategory = CardGUICategory.MatchConsumableGear, GUIType = "gearUpgrade", GUITextureRef = "GUI_MPImages_MP3.GearStabyAmmo",
                PlayerVariableIds = [422, 440, 451],
                Pools =
                [
                    new(StorePools.GoldGear) { VersionIdx = 0, Tokens = "Custom0Tokens[0]=0.1f,Custom0Tokens[1]=0.15f,Custom0Tokens[2]=0.2f,Custom0Tokens[3]=0.25f,Custom0Tokens[4]=0.3f,Custom1Tokens[0]=0.05f,Custom1Tokens[1]=0.075f,Custom1Tokens[2]=0.1f,Custom1Tokens[3]=0.125f,Custom1Tokens[4]=0.15f" },
                ],
            },
        ];
    }
}
