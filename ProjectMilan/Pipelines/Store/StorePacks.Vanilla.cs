using ProjectMilanCore.Config;

namespace ProjectMilan.Pipelines.Store
{
    public static partial class StorePacks
    {
        /// <summary>
        /// The ME3 store packs that can still be bought or claimed. Every ID here (nID, OfferId, PlayerVariableId) is the
        /// vanilla ME3 value and must not change - ME3 MP profiles and saves refer to them.
        /// </summary>
        private static IEnumerable<StorePackEntry> Vanilla =>
        [
            new()
            {
                ID = 0, PackName = "starter", TitleStrRefId = 705015, DescriptionStrRefId = 705016, CreditCost = 0,
                PromoStrRefId = 703324, PerPlayerMax = 1, PlayerVariableId = 232,
                Image = "GUI_MPImages.StoreItems.Store001",
                RevealIntroTextureRef = "GUI_MPImages.Creates.box", RevealIntroHoloTextureRef = "GUI_MPImages.Creates.boxHolo", RevealIntroSound = "MPRevealCrate1",
                Contents =
                [
                    Slot(StorePools.StarterAmmo),
                    Slot(StorePools.StarterRevive),
                    Slot(StorePools.StarterExtra),
                    Slot(StorePools.BronzeMod),
                    Slot(1, null, (StorePools.SilverWeapon, 0.55f), (StorePools.SilverChar, 0.45f)),
                ],
            },
            new()
            {
                ID = 2, PackName = "weekly2", TitleStrRefId = 731378, DescriptionStrRefId = 809298, CreditCost = 0,
                PromoStrRefId = 703324, PerPlayerMax = 1, PlayerVariableId = 600, Visible = [[1500102]],
                Image = "GUI_MPImages.StoreItems.Store002",
                RevealIntroTextureRef = "GUI_MPImages.Creates.Camo", RevealIntroHoloTextureRef = "GUI_MPImages.Creates.CamoHolo", RevealIntroSound = "MPRevealCrate1",
                Contents =
                [
                    Slot(StorePools.GoldConsumable),
                    Slot(StorePools.GoldCommon),
                    Slot(StorePools.N7Weapon),
                ],
            },
            new()
            {
                ID = 3, PackName = "weekly3", TitleStrRefId = 731378, DescriptionStrRefId = 809298, CreditCost = 0,
                PromoStrRefId = 703324, PerPlayerMax = 1, PlayerVariableId = 601, Visible = [[1500104]],
                Image = "GUI_MPImages.StoreItems.Store002",
                RevealIntroTextureRef = "GUI_MPImages.Creates.Camo", RevealIntroHoloTextureRef = "GUI_MPImages.Creates.CamoHolo", RevealIntroSound = "MPRevealCrate1",
                Contents =
                [
                    Slot(StorePools.GoldConsumable),
                    Slot(StorePools.GoldCommon),
                    Slot(StorePools.N7Weapon),
                ],
            },
            new()
            {
                ID = 4, PackName = "weekly4", TitleStrRefId = 731378, DescriptionStrRefId = 809298, CreditCost = 0,
                PromoStrRefId = 703324, PerPlayerMax = 1, PlayerVariableId = 605, Visible = [[1500106]],
                Image = "GUI_MPImages.StoreItems.Store002",
                RevealIntroTextureRef = "GUI_MPImages.Creates.Camo", RevealIntroHoloTextureRef = "GUI_MPImages.Creates.CamoHolo", RevealIntroSound = "MPRevealCrate1",
                Contents =
                [
                    Slot(StorePools.GoldConsumable),
                    Slot(StorePools.GoldCommon),
                    Slot(StorePools.N7Weapon),
                ],
            },
            new()
            {
                ID = 5, PackName = "weekly5", TitleStrRefId = 731378, DescriptionStrRefId = 809298, CreditCost = 0,
                PromoStrRefId = 703324, PerPlayerMax = 1, PlayerVariableId = 606, Visible = [[1500107]],
                Image = "GUI_MPImages.StoreItems.Store002",
                RevealIntroTextureRef = "GUI_MPImages.Creates.Camo", RevealIntroHoloTextureRef = "GUI_MPImages.Creates.CamoHolo", RevealIntroSound = "MPRevealCrate1",
                Contents =
                [
                    Slot(StorePools.GoldConsumable),
                    Slot(StorePools.GoldCommon),
                    Slot(StorePools.N7Weapon),
                ],
            },
            new()
            {
                ID = 155, PackName = "weekly1", TitleStrRefId = 731378, DescriptionStrRefId = 809298, CreditCost = 0,
                PromoStrRefId = 703324, PerPlayerMax = 1, PlayerVariableId = 599, Visible = [[1500101]],
                Image = "GUI_MPImages.StoreItems.Store002",
                RevealIntroTextureRef = "GUI_MPImages.Creates.Camo", RevealIntroHoloTextureRef = "GUI_MPImages.Creates.CamoHolo", RevealIntroSound = "MPRevealCrate1",
                Contents =
                [
                    Slot(StorePools.GoldConsumable),
                    Slot(StorePools.GoldCommon),
                    Slot(StorePools.N7Weapon),
                ],
            },
            new()
            {
                // Recruit Pack
                ID = 200, PackName = "bronze", TitleStrRefId = 664978, DescriptionStrRefId = 664980, CreditCost = 5000,
                Image = "GUI_MPImages.StoreItems.Store005",
                RevealIntroTextureRef = "GUI_MPImages.Creates.box5", RevealIntroHoloTextureRef = "GUI_MPImages.Creates.box5Holo", RevealIntroSound = "MPRevealCrate5",
                Contents =
                [
                    Slot(2, StorePools.BronzeCommon, (StorePools.BronzeConsumable, 1f)),
                    Slot(StorePools.BronzeCommon, StorePools.BronzeConsumable),
                    // Milan Change
                    // StarterBanner takes 25% from BronzeMod (0.75 -> 0.5)
                    Slot(1, StorePools.BronzeCommon, (StorePools.BronzeMod, 0.5f), (StorePools.StarterBanner, 0.25f), (StorePools.SilverMod, 0.05f), (StorePools.BronzeCommon, 0.2f)),
                    Slot(1, StorePools.XPChar, (StorePools.BronzeWeapon, 0.6f), (StorePools.BronzeChar, 0.35f), (StorePools.SilverWeapon, 0.025f), (StorePools.SilverChar, 0.025f)),
                ],
            },
            new()
            {
                // Veteran Pack
                ID = 300, PackName = "silver", TitleStrRefId = 669283, DescriptionStrRefId = 669284, OfferId = 200000, CreditCost = 20000,
                Image = "GUI_MPImages.StoreItems.Store003",
                RevealIntroTextureRef = "GUI_MPImages.Creates.box3", RevealIntroHoloTextureRef = "GUI_MPImages.Creates.box3Holo", RevealIntroSound = "MPRevealCrate2",
                Contents =
                [
                    Slot(2, StorePools.SilverCommon, (StorePools.SilverConsumable, 1f)),
                    Slot(1, StorePools.SilverCommon, (StorePools.SilverCommonWeapon, 0.4f), (StorePools.SilverCommon, 0.6f)),
                    // Milan Change
                    // Uncommon Banner, Common Banner each take 5% from SilverMod
                    // StarterBanner takes another 15% from SilverMod (0.45 -> 0.3)
                    Slot(1, StorePools.SilverCommon, (StorePools.SilverMod, 0.3f), (StorePools.StarterBanner, 0.15f), (StorePools.UncommonBanner, 0.05f), (StorePools.CommonBanner, 0.05f), (StorePools.GoldMod, 0.05f), (StorePools.XPChar, 0.1f), (StorePools.SilverCommon, 0.3f)),
                    Slot(1, StorePools.SilverBackup, (StorePools.SilverGear, 0.125f), (StorePools.GoldGear, 0.025f), (StorePools.SilverWeapon, 0.525f), (StorePools.SilverChar, 0.225f), (StorePools.GoldPermanent, 0.02f), (StorePools.GoldWeapon, 0.02f), (StorePools.GoldChar, 0.02f), (StorePools.Respec, 0.04f)),
                ],
            },
            new()
            {
                // Spectre Pack
                ID = 400, PackName = "gold", TitleStrRefId = 669285, DescriptionStrRefId = 793994, OfferId = 300000, CreditCost = 60000,
                Image = "GUI_MPImages.StoreItems.Store004",
                RevealIntroTextureRef = "GUI_MPImages.Creates.box4", RevealIntroHoloTextureRef = "GUI_MPImages.Creates.box4Holo", RevealIntroSound = "MPRevealCrate3",
                Contents =
                [
                    Slot(StorePools.GoldConsumable, StorePools.GoldCommon),
                    Slot(StorePools.GoldCommon),
                    // Milan Change
                    // GoldCommonWeapon donates 5% to RareBanner
                    // GoldCommon donates 5% to StarterBanner
                    Slot(1, StorePools.GoldCommon, (StorePools.GoldCommonWeapon, 0.2f), (StorePools.RareBanner, 0.05f), (StorePools.StarterBanner, 0.05f), (StorePools.Respec, 0.05f), (StorePools.GoldCommon, 0.4f), (StorePools.GoldXPChar, 0.25f)),
                    // Half of SilverGear's weight was "silvergearmp3", which isn't a pool (that section's pool is silvergear), so it always fell to the backup
                    Slot(1, StorePools.GoldCommon, (StorePools.GoldMod, 0.4f), (StorePools.SilverGear, 0.3f), (StorePools.SilverChar, 0.15f), (StorePools.GoldPermanent, 0.15f)),
                    // Milan Change
                    // Gold Char loses 2.5% for Ultra Rare Banner
                    Slot(1, StorePools.GoldBackup, (StorePools.GoldGear, 0.2f), (StorePools.GoldWeapon, 0.4f), (StorePools.GoldChar, 0.25f), (StorePools.GoldUltraRare, 0.075f), (StorePools.UltraRareChar, 0.05f), (StorePools.UltraRareBanner, 0.025f)),
                ],
            },
            new()
            {
                // Premium Spectre Pack
                ID = 450, PackName = "goldpremium", TitleStrRefId = 674491, DescriptionStrRefId = 793995, OfferId = 350000, CreditCost = 99000,
                Image = "GUI_MPImages.StoreItems.Store004",
                RevealIntroTextureRef = "GUI_MPImages.Creates.box4", RevealIntroHoloTextureRef = "GUI_MPImages.Creates.box4Holo", RevealIntroSound = "MPRevealCrate4",
                Contents =
                [
                    Slot(StorePools.GoldConsumable, StorePools.GoldCommon),
                    // Milan Change
                    // GoldCommon donates 5% to StarterBanner
                    Slot(1, StorePools.GoldCommon, (StorePools.GoldCommonWeapon, 0.25f), (StorePools.StarterBanner, 0.05f), (StorePools.Respec, 0.05f), (StorePools.GoldCommon, 0.4f), (StorePools.GoldXPChar, 0.25f)),
                    // Half of SilverGear's weight was "silvergearmp3", which isn't a pool (that section's pool is silvergear), so it always fell to the backup
                    // Milan Change
                    // Gold Mod drops 10%, RareBanner: 10%
                    Slot(1, StorePools.GoldCommon, (StorePools.GoldMod, 0.3f), (StorePools.RareBanner, 0.1f), (StorePools.SilverGear, 0.3f), (StorePools.SilverChar, 0.15f), (StorePools.GoldPermanent, 0.15f)),
                    // Milan Change
                    // Gold Gear drops 5% for UR banner 5%
                    Slot(2, StorePools.GoldBackup, (StorePools.GoldGear, 0.15f), (StorePools.GoldWeapon, 0.4f), (StorePools.GoldChar, 0.275f), (StorePools.GoldUltraRare, 0.075f), (StorePools.UltraRareChar, 0.05f), (StorePools.UltraRareBanner, 0.05f)),
                ],
            },
            // Milan - was only listed with entitlement 2000001, which nothing grants
            new()
            {
                // Jumbo Spectre Pack
                // MILAN CHANGE - Change cost from 100000 to 160000
                // This pack was unused I think.
                ID = 475, PackName = "goldjumbo", TitleStrRefId = 727820, DescriptionStrRefId = 727821, OfferId = 300500, CreditCost = 160000,
                Image = "GUI_MPImages.StoreItems.Store003",
                RevealIntroTextureRef = "GUI_MPImages.Creates.box3", RevealIntroHoloTextureRef = "GUI_MPImages.Creates.box3Holo", RevealIntroSound = "MPRevealCrate3",
                Contents =
                [
                    // Milan Change - 7% Gold Banner
                    Slot(2, StorePools.GoldCommon, (StorePools.GoldConsumable, 0.93f), (StorePools.RareBanner, 0.07f)),
                    // Milan Change
                    // GoldCommon donates 5% to StarterBanner
                    Slot(2, StorePools.GoldCommon, (StorePools.GoldCommonWeapon, 0.25f), (StorePools.StarterBanner, 0.05f), (StorePools.Respec, 0.05f), (StorePools.GoldCommon, 0.4f), (StorePools.GoldXPChar, 0.25f)),
                    // Half of SilverGear's weight was "silvergearmp3", which isn't a pool (that section's pool is silvergear), so it always fell to the backup
                    Slot(2, StorePools.GoldCommon, (StorePools.GoldMod, 0.4f), (StorePools.SilverGear, 0.3f), (StorePools.SilverChar, 0.15f), (StorePools.GoldPermanent, 0.15f)),
                    // Milan Change
                    // GoldGear, GoldWeapon each lose 0.05, UR Banner gets .1
                    Slot(4, StorePools.GoldBackup, (StorePools.GoldGear, 0.15f), (StorePools.GoldWeapon, 0.35f), (StorePools.GoldChar, 0.275f), (StorePools.GoldUltraRare, 0.075f), (StorePools.UltraRareChar, 0.05f), (StorePools.UltraRareBanner, 0.1f)),
                ],
            },
            new()
            {
                ID = 650, PackName = "equipjumbo", TitleStrRefId = 727822, DescriptionStrRefId = 727823, OfferId = 500500, CreditCost = 33000,
                Image = "GUI_MPImages.StoreItems.Store005",
                RevealIntroTextureRef = "GUI_MPImages.Creates.box5", RevealIntroHoloTextureRef = "GUI_MPImages.Creates.box5Holo", RevealIntroSound = "MPRevealCrate5",
                Contents =
                [
                    Slot(StorePools.EquipAmmo, StorePools.BronzeCommon),
                    Slot(StorePools.EquipRevive, StorePools.SilverCommon),
                    Slot(StorePools.EquipRocket, StorePools.SilverCommon),
                    Slot(StorePools.EquipShield, StorePools.BronzeCommon),
                    Slot(6, StorePools.SilverCommon, (StorePools.BronzeCommon, 0.3f), (StorePools.SilverCommon, 0.3f), (StorePools.GoldCommon, 0.3f), (StorePools.EquipRandom, 0.1f)),
                ],
            },
        ];
    }
}
