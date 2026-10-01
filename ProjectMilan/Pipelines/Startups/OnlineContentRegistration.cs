using ProjectMilanCore;
using ProjectMilanCore.Config;

namespace ProjectMilan.Pipelines.Startups
{
    /// <summary>
    /// Registers the challenge banners and store packs whose images ME3 downloaded from EA's servers at runtime
    /// (EStoreImageLocation_Remote / "ChallengeBanners/X.dds"). Their images are now built locally from
    /// ImagePackages\Online by <see cref="ImagePackageBuilder"/>, and these used to be static XML in
    /// MergedConfig\BioGame.xml - they live here instead so they can only exist if Milan built their images.
    /// <para>
    /// Every ID here (emblem IDs, store nIDs, mpplayervariablemappings IDs) is the vanilla ME3 value and must
    /// not change - ME3 MP profiles and saves refer to them. New content gets new IDs after these.
    /// </para>
    /// </summary>
    internal static class OnlineContentRegistration
    {
        private const string LOG_CATEGORY = @"MILAN-OnlineContent";

        /// <summary>
        /// Image package folders under ImagePackages\Online these images are built from.
        /// </summary>
        private const string BannerImages = "ChallengeBanners";
        private const string StoreImages = "StoreItems";

        public static void RegisterOnlineBanners(IReadOnlySet<string> builtImages)
        {
            MilanLog.Information("Registering online challenge banners", customPrefix: LOG_CATEGORY);
            foreach (var banner in OnlineBanners)
            {
                CheckImageBuilt(builtImages, banner.BackgroundResource, $"challenge banner {banner.ID}");
                ChallengeBannerRegistration.RegisterChallengeBanner(banner);
            }
        }

        public static void RegisterOnlineStorePacks(IReadOnlySet<string> builtImages)
        {
            MilanLog.Information("Registering online store packs", customPrefix: LOG_CATEGORY);
            foreach (var pack in OnlineStorePacks)
            {
                CheckImageBuilt(builtImages, pack.Image, $"store pack {pack.PackName}");
                StorePackRegistration.RegisterStorePack(pack);
            }
        }

        private static void CheckImageBuilt(IReadOnlySet<string> builtImages, string imagePath, string usedBy)
        {
            if (!builtImages.Contains(imagePath))
            {
                MilanLog.Error($"Image {imagePath} for {usedBy} was not built - is it missing from ImagePackages\\Online?", customPrefix: LOG_CATEGORY);
            }
        }

        private static ChallengeBannerEntry Banner(int id, string image, int titleStrRefId) =>
            new() { ID = id, BackgroundResource = $"{BannerImages}.{image}", TitleStrRefId = titleStrRefId };

        private static readonly List<ChallengeBannerEntry> OnlineBanners =
        [
            Banner(100, "MEMstr", 778515),
            Banner(150, "Halloween", 812513),
            Banner(153, "N7Day", 813744),
            Banner(154, "Bioware", 813603),
            Banner(155, "Corsair", 813915),
            Banner(157, "Prophecy", 814532),
            Banner(206, "Punisher", 814545),
            Banner(207, "MEMstrF", 778515),
            Banner(208, "zaeed", 817835),
            Banner(209, "ContestWinner1", 778529),
            Banner(210, "ContestWinner2", 778529),
            Banner(211, "ContestWinner3", 778522),
            Banner(212, "ContestWinner4", 778522),
            Banner(213, "ContestWinner5", 778531),
            Banner(214, "ContestWinner6", 778526),
            Banner(215, "ContestWinner7", 778516),
            Banner(216, "ContestWinner8", 778518),
            Banner(217, "ContestWinner9", 778538),
            Banner(218, "ContestWinner10", 778539),
            Banner(219, "VolusLover", 817851),
            Banner(220, "FullTeam", 817847),
        ];

        private static StorePackSlot Slot(int quantity, string? backupPool, params (string PoolName, float Weight)[] pools) =>
            new() { Quantity = quantity, BackupPool = backupPool, Pools = pools.ToList() };

        private static StorePackSlot Slot(string pool, string? backupPool = null) => Slot(1, backupPool, (pool, 1f));

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
            Contents = [Slot("goldconsumable"), Slot("goldcommon"), Slot("n7weapon")],
        };

        private static readonly List<StorePackEntry> OnlineStorePacks =
        [
            new()
            {
                ID = 656, PackName = "arsenal", TitleStrRefId = 752068, DescriptionStrRefId = 752069, OfferId = 650200, CreditCost = 99000,
                Image = $"{StoreImages}.StoreBF3",
                RevealIntroTextureRef = "GUI_MPImages.Creates.Camo", RevealIntroHoloTextureRef = "GUI_MPImages.Creates.CamoHolo", RevealIntroSound = "MPRevealCrate5",
                Contents =
                [
                    Slot("goldconsumable", "goldcommon"),
                    Slot(1, "goldcommon", ("goldcommonweapon", 0.5f), ("respec", 0.05f), ("goldcommon", 0.45f)),
                    Slot(1, "goldcommon", ("goldmod", 0.45f), ("silvergear", 0.2f), ("silvergearmp3", 0.2f), ("goldperm", 0.15f)),
                    Slot(2, "goldbackup", ("goldgear", 0.2f), ("goldweapon", 0.725f), ("goldultrarare", 0.075f)),
                ],
            },
            new()
            {
                ID = 657, PackName = "reserves", TitleStrRefId = 752070, DescriptionStrRefId = 752071, OfferId = 650300, CreditCost = 99000,
                Image = $"{StoreImages}.StoreMPMoon",
                RevealIntroTextureRef = "GUI_MPImages.Creates.Geth", RevealIntroHoloTextureRef = "GUI_MPImages.Creates.GethHolo", RevealIntroSound = "MPRevealCrate5",
                Contents =
                [
                    Slot("goldconsumable", "goldcommon"),
                    Slot(1, "goldcommon", ("respec", 0.05f), ("goldcommon", 0.45f), ("goldxpchar", 0.5f)),
                    Slot(1, "goldcommon", ("goldmod", 0.2f), ("silvergear", 0.15f), ("silvergearmp3", 0.15f), ("silverchar", 0.35f), ("goldperm", 0.15f)),
                    Slot(2, "goldbackup", ("goldgear", 0.2f), ("goldchar", 0.675f), ("goldultrarare", 0.075f), ("ultrararechar", 0.05f)),
                ],
            },
            OperationPack(6, "weekly6", 612, 1500108),
            new()
            {
                ID = 7, PackName = "victory16", TitleStrRefId = 731380, DescriptionStrRefId = 813920, ExpirationTime = 1354643968, CreditCost = 0,
                PromoStrRefId = 703324, PerPlayerMax = 1, PlayerVariableId = 613,
                Image = $"{StoreImages}.StoreAlliance",
                RevealIntroTextureRef = "GUI_MPImages.Creates.Alliance", RevealIntroHoloTextureRef = "GUI_MPImages.Creates.AllianceHolo", RevealIntroSound = "MPRevealCrate1",
                Contents =
                [
                    Slot("equipammo", "bronzecommon"),
                    Slot("equiprevive", "bronzecommon"),
                    Slot("equiprocket", "bronzecommon"),
                    Slot("equipshield", "bronzecommon"),
                    Slot(2, "silvercommon", ("bronzecommon", 0.2f), ("silvercommon", 0.35f), ("goldcommon", 0.35f), ("equiprand", 0.1f)),
                    Slot("goldcommon", "goldbackup"),
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
                // Giving a free kit for next week operation. Milan - DLC requirement removed
                ID = 23, PackName = "FreeReckoning", TitleStrRefId = 738450, DescriptionStrRefId = 738451, CreditCost = 0,
                PromoStrRefId = 703324, PerPlayerMax = 1, PlayerVariableId = 665,
                Image = $"{StoreImages}.StoreAlliance",
                RevealIntroTextureRef = "GUI_MPImages.Creates.Alliance", RevealIntroHoloTextureRef = "GUI_MPImages.Creates.AllianceHolo", RevealIntroSound = "MPRevealCrate1",
                Contents = [Slot("Freegoldchar", "goldcommon")],
            },
            OperationPack(13, "prophecy", 634, 1500114), // Operation Prophecy
        ];
    }
}
