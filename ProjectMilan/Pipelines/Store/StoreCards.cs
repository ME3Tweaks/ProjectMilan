using ProjectMilanCore.Config.Store;

namespace ProjectMilan.Pipelines.Store
{
    /// <summary>
    /// Every card the multiplayer store can award, split by type across the StoreCards.*.cs files. To add an item, add
    /// one entry to the matching file: its CardData fields, its ownership player variable(s) and the pools it drops from.
    /// <para>
    /// PlayerVariableIds end up in player saves and must never change or be reused. Vanilla IDs go up to 670; Milan IDs
    /// start at 700 and are shared with store pack counters - <see cref="StoreCatalog.Validate"/> rejects any clash.
    /// </para>
    /// </summary>
    public static partial class StoreCards
    {
        public static IEnumerable<StoreCard> All =>
            Weapons.Concat(WeaponMods).Concat(Kits).Concat(Gear).Concat(MatchConsumables).Concat(Misc).Concat(Banners).Concat(AchievementBannerCards);
    }
}
