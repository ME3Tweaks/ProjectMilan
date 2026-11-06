using LegendaryExplorerCore.Packages;
using ProjectMilanCore;
using ProjectMilanCore.Config;
using ProjectMilanCore.Utility;

namespace ProjectMilan.Pipelines.Store;

public static partial class StorePacks
{
    /// <summary>Free, one-per-player achievement reward containing exactly its associated banner.</summary>
    private static StorePackEntry AchievementPack(AchievementBannerDefinition banner) => new()
    {
        ID = (int)banner.PackId,
        PackName = banner.PackName,
        TitleStrRefId = MilanPipelinesShared.AssignTLK(banner.Title),
        DescriptionStrRefId = MilanPipelinesShared.AssignTLK(banner.PackDescription),
        CreditCost = 0,
        PromoStrRefId = 703324,
        PerPlayerMax = 1,
        PlayerVariableId = (int)banner.CounterId,
        UnlockInfo = new AchievementUnlockInfo
        {
            AchievementId = banner.AchievementId,
            UnlockVariableName = $"{banner.PackName}_unlock",
            UnlockVariableId = (int)banner.UnlockId,
        },
        BannerRewardID = (int)banner.EmblemId,
        Image = banner.PackImage,
        RevealIntroTextureRef = "GUI_MPImages.Creates.Alliance",
        RevealIntroHoloTextureRef = "GUI_MPImages.Creates.AllianceHolo",
        RevealIntroSound = "MPRevealCrate1",
        Contents = [Slot(banner.Pool)],
    };

    private static readonly LocalizedString LegendaryBannerPackTitle = new() { 
        [MELocalization.INT] = "Legendary Pack" 
    };

    private static readonly LocalizedString LegendaryBannerPackDescription = new() { 
        [MELocalization.INT] = "A legendary banner for legendary defenders of the galaxy." 
    };

    /// <summary>
    /// Free, one-per-player pack available from the start, containing only the Legendary banner.
    /// </summary>
    private static StorePackEntry LegendaryBannerPack() => new()
    {
        ID = (int)MilanStorePackId.LegendaryBanner,
        PackName = "legendarybanner",
        TitleStrRefId = MilanPipelinesShared.AssignTLK(LegendaryBannerPackTitle),
        DescriptionStrRefId = MilanPipelinesShared.AssignTLK(LegendaryBannerPackDescription),
        CreditCost = 0,
        PromoStrRefId = 703324,
        PerPlayerMax = 1,
        PlayerVariableId = (int)MilanPlayerVariable.Pack_LegendaryBanner,
        BannerRewardID = (int)MilanBannerId.Legendary,
        Image = "Packs.LegendaryBG", // Needs an appropriate background image!
        RevealIntroTextureRef = "GUI_MPImages.Creates.box",
        RevealIntroHoloTextureRef = "GUI_MPImages.Creates.boxHolo",
        RevealIntroSound = "MPRevealCrate1",
        Contents = [Slot(StorePools.LegendaryBanner)],
    };

    private static readonly LocalizedString SaveMassEffectPackTitle = new()
    {
        [MELocalization.INT] = "Save Mass Effect Pack"
    };

    private static readonly LocalizedString SaveMassEffectPackDescription = new()
    {
        [MELocalization.INT] = "Contains the Save Mass Effect banner."
    };

    /// <summary>
    /// Free, one-per-player pack available from the start, containing only the Save Mass Effect banner.
    /// </summary>
    private static StorePackEntry SaveMassEffectPack() => new()
    {
        ID = (int)MilanStorePackId.SaveMassEffect,
        PackName = "savemasseffect",
        TitleStrRefId = MilanPipelinesShared.AssignTLK(SaveMassEffectPackTitle),
        DescriptionStrRefId = MilanPipelinesShared.AssignTLK(SaveMassEffectPackDescription),
        CreditCost = 0,
        PromoStrRefId = 703324,
        PerPlayerMax = 1,
        PlayerVariableId = (int)MilanPlayerVariable.Pack_SaveMassEffect,
        BannerRewardID = (int)MilanBannerId.SaveMassEffect,
        Image = AchievementBannerDefinition.PlaceholderPackImage, // TODO pack artwork
        RevealIntroTextureRef = "GUI_MPImages.Creates.box",
        RevealIntroHoloTextureRef = "GUI_MPImages.Creates.boxHolo",
        RevealIntroSound = "MPRevealCrate1",
        Contents = [Slot(StorePools.SaveMassEffectBanner)],
    };

    /// <summary>
    /// The super-big PSP pack.
    /// </summary>
    /// <returns></returns>
    private static StorePackEntry BigBadSbectreBack() => new()
    {
        ID = (int)MilanStorePackId.SpectreShipment,
        PackName = "grindbreakerspectre",
        TitleStrRefId = MilanPipelinesShared.AssignTLK(new()
        {
            [MELocalization.INT] = "Spectre Shipment"
        }),
        DescriptionStrRefId = MilanPipelinesShared.AssignTLK(new()
        {
            [MELocalization.INT] = "Colleagues from the Office of Special Tactics and Reconnaissance can send a large shipment your way."
        }),
        CreditCost = 1_400_000,
        Image = "GUI_MPImages.StoreItems.Store004",
        RevealIntroTextureRef = "GUI_MPImages.Creates.box4",
        RevealIntroHoloTextureRef = "GUI_MPImages.Creates.box4Holo",
        RevealIntroSound = "MPRevealCrate4",
        Contents = [
            Slot(20, StorePools.SilverCommon, (StorePools.BronzeConsumable, 0.4f), (StorePools.SilverConsumable, 0.4f), (StorePools.GoldConsumable, 0.2f)),

            Slot(10, StorePools.SilverCommon, (StorePools.SilverCommonWeapon, 0.35f), (StorePools.SilverCommon, 0.4f), (StorePools.XPChar, 0.25f)),
            Slot(10, StorePools.GoldCommon, (StorePools.GoldCommonWeapon, 0.25f), (StorePools.StarterBanner, 0.05f), (StorePools.Respec, 0.05f), (StorePools.GoldCommon, 0.4f), (StorePools.GoldXPChar, 0.25f)),

            Slot(10, StorePools.SilverCommon, (StorePools.SilverMod, 0.4f), (StorePools.SilverGear, 0.3f), (StorePools.BronzeChar, 0.15f), (StorePools.GoldPermanent, 0.15f)),
            Slot(10, StorePools.GoldCommon, (StorePools.GoldMod, 0.375f), (StorePools.RareBanner, 0.025f), (StorePools.SilverGear, 0.35f), (StorePools.SilverChar, 0.15f), (StorePools.GoldPermanent, 0.1f)),

            Slot(20, StorePools.SilverBackup, (StorePools.SilverGear, 0.275f), (StorePools.SilverWeapon, 0.275f), (StorePools.SilverChar, 0.275f), (StorePools.GoldUltraRare, 0.05f), (StorePools.GoldPermanent, 0.125f)),
            Slot(20, StorePools.GoldBackup, (StorePools.GoldGear, 0.15f), (StorePools.GoldWeapon, 0.4f), (StorePools.GoldChar, 0.275f), (StorePools.GoldUltraRare, 0.075f), (StorePools.UltraRareChar, 0.09f), (StorePools.UltraRareBanner, 0.01f)),
        ],
    };

    /// <summary>
    /// The super-big JEP pack.
    /// </summary>
    /// <returns></returns>
    private static StorePackEntry BigBadEquibmentBack() => new()
    {
        ID = (int)MilanStorePackId.SpectreShipmentEquipment,
        PackName = "grindbreakerequipment",
        TitleStrRefId = MilanPipelinesShared.AssignTLK(new()
        {
            [MELocalization.INT] = "Spectre Shipment (Equipment)"
        }),
        DescriptionStrRefId = MilanPipelinesShared.AssignTLK(new()
        {
            [MELocalization.INT] = "Colleagues from the Office of Special Tactics and Reconnaissance can send a large shipment of consumables your way."
        }),
        CreditCost = 400_000,
        Image = "GUI_MPImages.StoreItems.Store005",
        RevealIntroTextureRef = "GUI_MPImages.Creates.box5",
        RevealIntroHoloTextureRef = "GUI_MPImages.Creates.box5Holo",
        RevealIntroSound = "MPRevealCrate5",
        Contents = [
            Slot(40, StorePools.BronzeCommon, (StorePools.EquipAmmo, 0.475f), (StorePools.EquipShield, 0.475f), (StorePools.BronzeMod, 0.05f)),
            Slot(40, StorePools.SilverCommon, (StorePools.EquipRevive, 0.475f), (StorePools.EquipRocket, 0.475f), (StorePools.SilverMod, 0.05f)),
            Slot(120, StorePools.SilverCommon, (StorePools.BronzeCommon, 0.3f), (StorePools.SilverCommon, 0.3f), (StorePools.GoldCommon, 0.3f), (StorePools.EquipRandom, 0.1f)),
        ],
    };

    private static IReadOnlyList<StorePackEntry> GetMilanPacks() =>
    [
        // Evaluated during registration because titles/descriptions assign TLK entries.
        ..StoreCards.AchievementBanners.Select(AchievementPack),
        LegendaryBannerPack(),
        SaveMassEffectPack(),
        BigBadSbectreBack(),
        BigBadEquibmentBack(),
    ];
}
