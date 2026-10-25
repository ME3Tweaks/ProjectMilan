using ProjectMilanCore.Config.Store;

namespace ProjectMilan.Pipelines.Store
{
    public static partial class StoreCards
    {
        /// <summary>
        /// Equipment, capacity upgrades, respec and credits.
        /// </summary>
        private static IEnumerable<StoreCard> Misc =>
        [
            new()
            {
                UniqueName = "MPCredits", Kind = ReinforcementKind.Credits, Rarity = CardRarity.Rare,
                GUIName = 720016, GUIDescription = 720018, GUIType = "bonus", GUITextureRef = "GUI_MPImages.Cards.Credits",
            },
            new()
            {
                UniqueName = "MPCapacity_Ammo", Kind = ReinforcementKind.PermanentUpgrade, Rarity = CardRarity.Rare, MaxCount = 6,
                GUIName = 723382, GUIDescription = 723378, GUIType = "capacity", GUITextureRef = "GUI_MPImages.Cards.AddAmmo",
                PlayerVariableIds = [242],
                Pools = [new(StorePools.GoldPermanent)],
            },
            new()
            {
                UniqueName = "MPCapacity_Revive", Kind = ReinforcementKind.PermanentUpgrade, Rarity = CardRarity.Rare, MaxCount = 6,
                GUIName = 723385, GUIDescription = 723381, GUIType = "capacity", GUITextureRef = "GUI_MPImages.Cards.AddRevive",
                PlayerVariableIds = [243],
                Pools = [new(StorePools.GoldPermanent)],
            },
            new()
            {
                UniqueName = "MPCapacity_Rocket", Kind = ReinforcementKind.PermanentUpgrade, Rarity = CardRarity.Rare, MaxCount = 6,
                GUIName = 723384, GUIDescription = 723380, GUIType = "capacity", GUITextureRef = "GUI_MPImages.Cards.AddRockets",
                PlayerVariableIds = [244],
                Pools = [new(StorePools.GoldPermanent)],
            },
            new()
            {
                UniqueName = "MPCapacity_Shield", Kind = ReinforcementKind.PermanentUpgrade, Rarity = CardRarity.Rare, MaxCount = 6,
                GUIName = 723383, GUIDescription = 723379, GUIType = "capacity", GUITextureRef = "GUI_MPImages.Cards.AddShield",
                PlayerVariableIds = [245],
                Pools = [new(StorePools.GoldPermanent)],
            },
            new()
            {
                UniqueName = "MPRespec", Kind = ReinforcementKind.PermanentUpgrade, Rarity = CardRarity.Uncommon, MaxCount = 8,
                GUIName = 708848, GUIType = "respec", GUITextureRef = "GUI_MPImages.Cards.Talent",
                PlayerVariableIds = [246],
                Pools = [new(StorePools.GoldPermanent), new(StorePools.Respec)],
            },
            new()
            {
                UniqueName = "SFXGameMPContent.SFXPowerCustomActionMP_Consumable_Ammo", Kind = ReinforcementKind.InGameConsumable, Rarity = CardRarity.Common, MaxCount = 255,
                GUIName = 661162, GUIDescription = 661163, GUIType = "consumable", GUITextureRef = "GUI_MPImages.Cards.EquipAmmo",
                PlayerVariableIds = [86],
                Pools =
                [
                    new(StorePools.EquipAmmo) { PVIncrementBonus = 4, GUIName = 702717 },
                    new(StorePools.BronzeConsumable),
                    new(StorePools.GoldConsumable) { PVIncrementBonus = 4, GUIName = 702717 },
                    new(StorePools.SilverConsumable) { PVIncrementBonus = 2, GUIName = 702717 },
                    new(StorePools.StarterAmmo),
                ],
            },
            new()
            {
                UniqueName = "SFXGameMPContent.SFXPowerCustomActionMP_Consumable_Revive", Kind = ReinforcementKind.InGameConsumable, Rarity = CardRarity.Common, MaxCount = 255,
                GUIName = 661168, GUIDescription = 661169, GUIType = "consumable", GUITextureRef = "GUI_MPImages.Cards.EquipRevive",
                PlayerVariableIds = [87],
                Pools =
                [
                    new(StorePools.EquipRandom) { PVIncrementBonus = 1, GUIName = 702720 },
                    new(StorePools.EquipRevive) { PVIncrementBonus = 4, GUIName = 702720 },
                    new(StorePools.BronzeConsumable),
                    new(StorePools.GoldConsumable) { PVIncrementBonus = 4, GUIName = 702720 },
                    new(StorePools.SilverConsumable) { PVIncrementBonus = 2, GUIName = 702720 },
                    new(StorePools.StarterRevive),
                ],
            },
            new()
            {
                UniqueName = "SFXGameMPContent.SFXPowerCustomActionMP_Consumable_Rocket", Kind = ReinforcementKind.InGameConsumable, Rarity = CardRarity.Common, MaxCount = 255,
                GUIName = 661166, GUIDescription = 661167, GUIType = "consumable", GUITextureRef = "GUI_MPImages.Cards.EquipRocket",
                PlayerVariableIds = [88],
                Pools =
                [
                    new(StorePools.EquipRandom) { PVIncrementBonus = 1, GUIName = 702719 },
                    new(StorePools.EquipRocket) { PVIncrementBonus = 4, GUIName = 702719 },
                    new(StorePools.BronzeConsumable),
                    new(StorePools.GoldConsumable) { PVIncrementBonus = 4, GUIName = 702719 },
                    new(StorePools.SilverConsumable) { PVIncrementBonus = 2, GUIName = 702719 },
                    new(StorePools.StarterExtra),
                ],
            },
            new()
            {
                UniqueName = "SFXGameMPContent.SFXPowerCustomActionMP_Consumable_Shield", Kind = ReinforcementKind.InGameConsumable, Rarity = CardRarity.Common, MaxCount = 255,
                GUIName = 661164, GUIDescription = 661165, GUIType = "consumable", GUITextureRef = "GUI_MPImages.Cards.EquipShield",
                PlayerVariableIds = [89],
                Pools =
                [
                    new(StorePools.EquipShield) { PVIncrementBonus = 4, GUIName = 702718 },
                    new(StorePools.BronzeConsumable),
                    new(StorePools.GoldConsumable) { PVIncrementBonus = 4, GUIName = 702718 },
                    new(StorePools.SilverConsumable) { PVIncrementBonus = 2, GUIName = 702718 },
                    new(StorePools.StarterExtra),
                ],
            },
        ];
    }
}
