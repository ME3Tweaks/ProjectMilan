using ProjectMilanCore.Config.Store;

namespace ProjectMilan.Pipelines.Store
{
    /// <summary>
    /// Every pool store packs can draw from. Cards join a pool through StoreCard.Pools; packs reference these fields, so a
    /// misspelled pool is a compile error. Pool names are matched case-insensitively by SFXGAWReinforcementManager.
    /// </summary>
    public static class StorePools
    {
        /// <summary>
        /// Common (bronze frame) banners
        /// </summary>
        public static readonly StorePool CommonBanner = new("banner_common");
        /// <summary>
        /// Uncommon (silver frame) banners
        /// </summary>
        public static readonly StorePool UncommonBanner = new("banner_uncommon");
        /// <summary>
        /// Gold border banners
        /// </summary>
        public static readonly StorePool RareBanner = new("banner_rare");
        /// <summary>
        /// Banners that make people wish they didn't use UR slots
        /// </summary>
        public static readonly StorePool UltraRareBanner = new("banner_ultrarare");
        /// <summary>
        /// Exclusive to the free Legendary Banner pack
        /// </summary>
        public static readonly StorePool LegendaryBanner = new("banner_legendary");

        /// <summary>
        /// A handful of early banners that drop far more often than their rarity pool. This lets players get some faction banners or other 
        /// ones early so they have something to show
        /// </summary>
        public static readonly StorePool StarterBanner = new("banner_starter");

        /// <summary>
        /// Default pool for a banner of this rarity.
        /// </summary>
        public static StorePool BannerPool(CardRarity rarity) => rarity switch
        {
            CardRarity.Common => CommonBanner,
            CardRarity.Uncommon => UncommonBanner,
            CardRarity.Rare => RareBanner,
            CardRarity.UltraRare => UltraRareBanner,
            _ => throw new ArgumentOutOfRangeException(nameof(rarity), rarity, "Banners have no pool for this rarity"),
        };

        public static readonly StorePool BronzeChar = new("bronzechar");
        /// <summary>Match consumables, version I</summary>
        public static readonly StorePool BronzeCommon = new("bronzecommon");
        /// <summary>Equipment for bronze packs</summary>
        public static readonly StorePool BronzeConsumable = new("bronzeconsumable");
        public static readonly StorePool BronzeMod = new("bronzemod");
        public static readonly StorePool BronzeWeapon = new("bronzeweapon");
        /// <summary>Not used by any pack</summary>
        public static readonly StorePool ConMP2Char = new("conmp2char");
        /// <summary>Not used by any pack</summary>
        public static readonly StorePool ConMP2Gun = new("conmp2gun");
        /// <summary>Not used by any pack</summary>
        public static readonly StorePool ConMP3Char = new("conmp3char");
        /// <summary>Not used by any pack</summary>
        public static readonly StorePool ConMP3Gun = new("conmp3gun");
        public static readonly StorePool EquipAmmo = new("equipammo");
        public static readonly StorePool EquipRandom = new("equiprand");
        public static readonly StorePool EquipRevive = new("equiprevive");
        public static readonly StorePool EquipRocket = new("equiprocket");
        public static readonly StorePool EquipShield = new("equipshield");
        public static readonly StorePool FreeGoldChar = new("Freegoldchar");
        /// <summary>Fallback when a gold pack runs dry</summary>
        public static readonly StorePool GoldBackup = new("goldbackup");
        public static readonly StorePool GoldChar = new("goldchar");
        /// <summary>Match consumables, version III</summary>
        public static readonly StorePool GoldCommon = new("goldcommon");
        public static readonly StorePool GoldCommonWeapon = new("goldcommonweapon");
        /// <summary>Equipment for gold packs (x4)</summary>
        public static readonly StorePool GoldConsumable = new("goldconsumable");
        /// <summary>Match consumables, version IV</summary>
        public static readonly StorePool GoldEquipment = new("goldequipment");
        public static readonly StorePool GoldGear = new("goldgear");
        public static readonly StorePool GoldMod = new("goldmod");
        /// <summary>
        /// Capacity upgrades and respec
        /// </summary>
        public static readonly StorePool GoldPermanent = new("goldperm");
        public static readonly StorePool GoldUltraRare = new("goldultrarare");
        public static readonly StorePool GoldWeapon = new("goldweapon");
        /// <summary>
        /// Rare characters that already unlocked award XP
        /// </summary>
        public static readonly StorePool GoldXPChar = new("goldxpchar");
        public static readonly StorePool N7Weapon = new("n7weapon");
        /// <summary>
        /// Not used by any pack biower pls
        /// </summary>
        public static readonly StorePool NewUltraRare = new("newultrarare");
        public static readonly StorePool Respec = new("respec");
        /// <summary>
        /// Fallback when a silver pack runs dry
        /// </summary>
        public static readonly StorePool SilverBackup = new("silverbackup");
        public static readonly StorePool SilverChar = new("silverchar");
        /// <summary>
        /// Match consumables, version II
        /// </summary>
        public static readonly StorePool SilverCommon = new("silvercommon");
        public static readonly StorePool SilverCommonWeapon = new("silvercommonweapon");
        /// <summary>
        /// Equipment for silver packs (x2)
        /// </summary>
        public static readonly StorePool SilverConsumable = new("silverconsumable");
        public static readonly StorePool SilverGear = new("silvergear");
        public static readonly StorePool SilverMod = new("silvermod");
        public static readonly StorePool SilverWeapon = new("silverweapon");
        public static readonly StorePool StarterAmmo = new("starterammo");
        public static readonly StorePool StarterExtra = new("starterextra");
        public static readonly StorePool StarterRevive = new("starterrevive");
        public static readonly StorePool UltraRareChar = new("ultrararechar");
        /// <summary>
        /// Uncommon characters that already unlocked award XP
        /// </summary>
        public static readonly StorePool XPChar = new("xpchar");
    }
}
