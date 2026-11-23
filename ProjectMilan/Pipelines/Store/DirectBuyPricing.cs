using ProjectMilanCore.Config.Store;

namespace ProjectMilan.Pipelines.Store
{
    /// <summary>
    /// Direct Buy prices. Each offer row names a price group and a rarity; the store reads the price table below from its
    /// config section (PriceGroups and PriceOverrides) and works out the price when it shows the row, so prices can be
    /// changed in config without rebuilding the store.
    /// <para>
    /// A row's unit price is Cost[rarity] + CostPerRank[rarity] * (rank - 1), where rank is the rank the player would get:
    /// the next version of a weapon, mod or character, the next level of gear or a capacity upgrade. Match consumables
    /// have a fixed rank per row (their rarity already rises with it), so they never step. A group with a BundleSize
    /// sells that many per purchase for BundleSize unit prices.
    /// </para>
    /// <para>
    /// The values are placeholders. They're meant to sit at about 1.5-2x what the same rarity costs on average through
    /// packs, so targeting a card costs extra and packs stay the cheap way to fill out a collection.
    /// </para>
    /// </summary>
    internal static class DirectBuyPricing
    {
        /// <summary>
        /// One price group: costs by <see cref="CardRarity"/> (Common, Uncommon, Rare, UltraRare).
        /// </summary>
        public sealed record PriceGroup(string Name, int[] Cost, int[] CostPerRank, int BundleSize = 1);

        public const string Weapon = "Weapon";
        public const string HeavyWeapon = "HeavyWeapon";
        public const string WeaponMod = "WeaponMod";
        public const string Character = "Character";
        public const string MatchConsumable = "MatchConsumable";
        public const string Gear = "Gear";
        public const string Supply = "Supply";
        public const string Capacity = "Capacity";
        public const string Respec = "Respec";
        public const string Banner = "Banner";

        /// <summary>
        /// Match consumables and supplies are sold in threes.
        /// </summary>
        private const int ConsumableBundleSize = 3;

        public static IReadOnlyList<PriceGroup> GetPriceGroups() =>
        [
            new(Weapon, [15000, 40000, 100000, 250000], [1500, 4000, 10000, 25000]),
            new(HeavyWeapon, [15000, 40000, 100000, 250000], [1500, 4000, 10000, 25000]),
            new(WeaponMod, [10000, 25000, 60000, 150000], [1000, 2500, 6000, 15000]),
            new(Character, [20000, 50000, 120000, 300000], [0, 0, 0, 0]),
            new(MatchConsumable, [2000, 4000, 10000, 25000], [0, 0, 0, 0], ConsumableBundleSize),
            new(Gear, [20000, 40000, 80000, 150000], [2000, 4000, 8000, 15000]),
            new(Supply, [3000, 3000, 3000, 3000], [0, 0, 0, 0], ConsumableBundleSize),
            new(Capacity, [50000, 50000, 50000, 50000], [25000, 25000, 25000, 25000]),
            new(Respec, [50000, 50000, 50000, 50000], [0, 0, 0, 0]),
            new(Banner, [10000, 25000, 50000, 100000], [0, 0, 0, 0]),
        ];

        /// <summary>
        /// Per-card prices that replace the card's group price: UniqueName -> (Cost, CostPerRank). Empty for now; for
        /// cards that are worth much more or less than the rest of their rarity.
        /// </summary>
        public static IReadOnlyDictionary<string, (int Cost, int CostPerRank)> GetPriceOverrides() =>
            new Dictionary<string, (int, int)>(StringComparer.OrdinalIgnoreCase);

        /// <summary>
        /// The price group of a card, from its GUIType.
        /// </summary>
        public static string GetPriceGroup(StoreCard card) => card.GUIType.ToLowerInvariant() switch
        {
            "assault" or "sniper" or "shotgun" or "pistol" or "smg" => Weapon,
            "heavyweapon" => HeavyWeapon,
            "assaultmod" or "snipermod" or "shotgunmod" or "pistolmod" or "smgmod" => WeaponMod,
            "char" => Character,
            "ammoupgrade" or "weaponupgrade" or "armorupgrade" => MatchConsumable,
            "gearupgrade" => Gear,
            "consumable" => Supply,
            "capacity" => Capacity,
            "respec" => Respec,
            "banner" => Banner,
            _ => throw new Exception($"Card {card.UniqueName} has GUIType {card.GUIType}, which has no Direct Buy price group"),
        };

        public static string SerializePriceGroup(PriceGroup group) =>
            $"(Group={group.Name},Cost=({string.Join(",", group.Cost)}),CostPerRank=({string.Join(",", group.CostPerRank)}),BundleSize={group.BundleSize})";

        public static string SerializePriceOverride(string uniqueName, int cost, int costPerRank) =>
            $"(UniqueName=\"{uniqueName}\",Cost={cost},CostPerRank={costPerRank})";
    }
}
