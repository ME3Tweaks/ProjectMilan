using ProjectMilanCore.Config;
using ProjectMilanCore.Config.Store;

namespace ProjectMilan.Pipelines.Store
{
    /// <summary>
    /// Every pack in the multiplayer store: the vanilla ME3 packs that are still reachable, the packs ME3 used to get from
    /// EA's servers (StorePacks.Online.cs) and Milan's own (StorePacks.Milan.cs).
    /// <para>
    /// The ME3 promo packs (loyalty, collectible, collector, BF3, customer, trilogy...) were dropped: they were only listed
    /// with EA-granted entitlements that nothing grants anymore. Their purchase counters stay in
    /// MergedConfig\BioGame.xml's mpplayervariablemappings so old profiles keep their data and the IDs stay reserved.
    /// </para>
    /// </summary>
    public static partial class StorePacks
    {
        /// <summary>
        /// Image package folders under ImagePackages\Online that store and banner images are built from.
        /// </summary>
        internal const string StoreImages = "StoreItems";
        internal const string BannerImages = "ChallengeBanners";

        /// <summary>
        /// This is a method because Milan packs assign TLK entries.
        /// </summary>
        public static IEnumerable<StorePackEntry> GetAll() => Vanilla.Concat(Online).Concat(GetMilanPacks());

        private static StorePackSlot Slot(int quantity, StorePool? backupPool, params (StorePool Pool, float Weight)[] pools) =>
            new() { Quantity = quantity, BackupPool = backupPool, Pools = pools.ToList() };

        private static StorePackSlot Slot(StorePool pool, StorePool? backupPool = null) => Slot(1, backupPool, (pool, 1f));
    }
}
