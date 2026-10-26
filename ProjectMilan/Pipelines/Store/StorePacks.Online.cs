using ProjectMilanCore.Config;

namespace ProjectMilan.Pipelines.Store
{
    public static partial class StorePacks
    {
        /// <summary>
        /// Free, one-per-player operation reward pack: a gold consumable, a gold common and an N7 weapon.
        /// </summary>
        private static StorePackEntry OperationPack(int id, string packName, int playerVariableId, int? visibleCondition,
            int titleStrRefId = 731378, int descriptionStrRefId = 809298) => new()
            {
                ID = id,
                PackName = packName,
                TitleStrRefId = titleStrRefId,
                DescriptionStrRefId = descriptionStrRefId,
                Visible = visibleCondition is { } condition ? [[condition]] : [],
                CreditCost = 0,
                PromoStrRefId = 703324,
                PerPlayerMax = 1,
                PlayerVariableId = playerVariableId,
                Image = $"{StoreImages}.StoreAlliance",
                RevealIntroTextureRef = "GUI_MPImages.Creates.Alliance",
                RevealIntroHoloTextureRef = "GUI_MPImages.Creates.AllianceHolo",
                RevealIntroSound = "MPRevealCrate1",
                Contents = [Slot(StorePools.GoldConsumable), Slot(StorePools.GoldCommon), Slot(StorePools.N7Weapon)],
            };

        /// <summary>
        /// The packs whose images ME3 downloaded from EA's servers at runtime (EStoreImageLocation_Remote). Their images are
        /// now built locally from ImagePackages\Online by ImagePackageBuilder.
        /// <para>
        /// Every ID here (store nIDs, mpplayervariablemappings IDs) is the vanilla ME3 value and must not change - ME3 MP
        /// profiles and saves refer to them.
        /// </para>
        /// </summary>
        private static IEnumerable<StorePackEntry> Online =>
        [
            new()
            {
                ID = 656, PackName = "arsenal", TitleStrRefId = 752068, DescriptionStrRefId = 752069, OfferId = 650200, CreditCost = 99000,
                Image = $"{StoreImages}.StoreBF3",
                RevealIntroTextureRef = "GUI_MPImages.Creates.Camo", RevealIntroHoloTextureRef = "GUI_MPImages.Creates.CamoHolo", RevealIntroSound = "MPRevealCrate5",
                Contents =
                [
                    Slot(StorePools.GoldConsumable, StorePools.GoldCommon),
                    Slot(1, StorePools.GoldCommon, (StorePools.GoldCommonWeapon, 0.5f), (StorePools.Respec, 0.05f), (StorePools.GoldCommon, 0.45f)),
                    // Milan - half of SilverGear's weight was "silvergearmp3", which isn't a pool (that section's pool is silvergear), so it always fell to the backup
                    Slot(1, StorePools.GoldCommon, (StorePools.GoldMod, 0.45f), (StorePools.SilverGear, 0.4f), (StorePools.GoldPermanent, 0.15f)),
                    Slot(2, StorePools.GoldBackup, (StorePools.GoldGear, 0.2f), (StorePools.GoldWeapon, 0.725f), (StorePools.GoldUltraRare, 0.075f)),
                ],
            },
            new()
            {
                ID = 657, PackName = "reserves", TitleStrRefId = 752070, DescriptionStrRefId = 752071, OfferId = 650300, CreditCost = 99000,
                Image = $"{StoreImages}.StoreMPMoon",
                RevealIntroTextureRef = "GUI_MPImages.Creates.Geth", RevealIntroHoloTextureRef = "GUI_MPImages.Creates.GethHolo", RevealIntroSound = "MPRevealCrate5",
                Contents =
                [
                    Slot(StorePools.GoldConsumable, StorePools.GoldCommon),
                    Slot(1, StorePools.GoldCommon, (StorePools.Respec, 0.05f), (StorePools.GoldCommon, 0.45f), (StorePools.GoldXPChar, 0.5f)),
                    // Milan - half of SilverGear's weight was "silvergearmp3", which isn't a pool (that section's pool is silvergear), so it always fell to the backup
                    Slot(1, StorePools.GoldCommon, (StorePools.GoldMod, 0.2f), (StorePools.SilverGear, 0.3f), (StorePools.SilverChar, 0.35f), (StorePools.GoldPermanent, 0.15f)),
                    Slot(2, StorePools.GoldBackup, (StorePools.GoldGear, 0.2f), (StorePools.GoldChar, 0.675f), (StorePools.GoldUltraRare, 0.075f), (StorePools.UltraRareChar, 0.05f)),
                ],
            },

            // Packs you might still have if you did a weekend challenge and never
            // opened ME3 again. Wouldn't that be something
            OperationPack(6, "weekly6", 612, 1500108),
            new()
            {
                ID = 7, PackName = "victory16", TitleStrRefId = 731380, DescriptionStrRefId = 813920, ExpirationTime = 1354643968, CreditCost = 0,
                PromoStrRefId = 703324, PerPlayerMax = 1, PlayerVariableId = 613,
                Image = $"{StoreImages}.StoreAlliance",
                RevealIntroTextureRef = "GUI_MPImages.Creates.Alliance", RevealIntroHoloTextureRef = "GUI_MPImages.Creates.AllianceHolo", RevealIntroSound = "MPRevealCrate1",
                Contents =
                [
                    Slot(StorePools.EquipAmmo, StorePools.BronzeCommon),
                    Slot(StorePools.EquipRevive, StorePools.BronzeCommon),
                    Slot(StorePools.EquipRocket, StorePools.BronzeCommon),
                    Slot(StorePools.EquipShield, StorePools.BronzeCommon),
                    Slot(2, StorePools.SilverCommon, (StorePools.BronzeCommon, 0.2f), (StorePools.SilverCommon, 0.35f), (StorePools.GoldCommon, 0.35f), (StorePools.EquipRandom, 0.1f)),
                    Slot(StorePools.GoldCommon, StorePools.GoldBackup),
                ],
            },
            OperationPack(8, "weekly7", 614, 1500109), // Operation Detonator
            OperationPack(9, "weekly8", 615, 1500110), // Operation Onslaught
            OperationPack(10, "weekly9", 616, 1500111), // Operation Alamo
            OperationPack(11, "weekly10", 617, 1500112), // Operation Genesis
            OperationPack(12, "weekly11", 618, 1500113), // Operation Geronimo!
            OperationPack(14, "weekly12", 658, 1500115), // Operation Balistic
            OperationPack(15, "weekly13", 660, 1500116), // Operation Firestorm
            OperationPack(16, "weekly14", 661, 1500117), // Operation Nightfall
            OperationPack(17, "weekly15", 662, 1500118), // Operation Heartbreaker
            OperationPack(18, "weekly16", 664, 1500119), // Operation Tribute
            OperationPack(19, "weekly17", 666, 1500120), // Operation Impact
            OperationPack(20, "FreeLodestar", 667, null, titleStrRefId: 738450, descriptionStrRefId: 738451), // Operation Lodestar free pack
            OperationPack(21, "Lodestar1", 668, 1500121), // Operation Lodestar (Normal)
            OperationPack(22, "Lodestar2", 669, 1500122), // Operation Lodestar (Insanity)
            new()
            {
                // Giving a free kit for next week operation.
                // Milan - DLC requirement removed
                ID = 23, PackName = "FreeReckoning", TitleStrRefId = 738450, DescriptionStrRefId = 738451, CreditCost = 0,
                PromoStrRefId = 703324, PerPlayerMax = 1, PlayerVariableId = 665,
                Image = $"{StoreImages}.StoreAlliance",
                RevealIntroTextureRef = "GUI_MPImages.Creates.Alliance", RevealIntroHoloTextureRef = "GUI_MPImages.Creates.AllianceHolo", RevealIntroSound = "MPRevealCrate1",
                Contents = [Slot(StorePools.FreeGoldChar, StorePools.GoldCommon)],
            },
            OperationPack(13, "prophecy", 634, 1500114), // Operation Prophecy
        ];
    }
}
