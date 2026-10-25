using ProjectMilanCore.Config.Store;

namespace ProjectMilanCore.Config
{
    /// <summary>
    /// A supply pack in the multiplayer store - its SFXGAWReinforcementManager StoreInfoArray entry plus the
    /// PackList slots that define what it awards. Mirrors StoreInfoEntry/CardPackEntry in
    /// SFXGAWReinforcementManager.uc. Registered through <see cref="StoreCatalog"/>. IDs are not auto-assigned: nID and PlayerVariableId end up in player saves
    /// (purchase counts), so they have to stay the same from build to build.
    /// </summary>
    public class StorePackEntry
    {
        /// <summary>
        /// Store item ID (nID). Unique across the store.
        /// </summary>
        public int ID { get; set; }

        /// <summary>
        /// Pack name - the key that joins StoreInfoArray, PackList, ConsumableIdPackNameMap and the per-player
        /// purchase counter together.
        /// </summary>
        public string PackName { get; set; }

        /// <summary>
        /// TLK String ID of the pack's title.
        /// </summary>
        public int TitleStrRefId { get; set; }

        /// <summary>
        /// TLK String ID of the pack's subtitle, if any.
        /// </summary>
        public int? SubTitleStrRefId { get; set; }

        /// <summary>
        /// TLK String ID of the pack's description.
        /// </summary>
        public int DescriptionStrRefId { get; set; }

        /// <summary>
        /// TLK String ID of the promo banner text (e.g. 703324), if any.
        /// </summary>
        public int? PromoStrRefId { get; set; }

        /// <summary>
        /// Cost in credits. 0 for a free pack.
        /// </summary>
        public int CreditCost { get; set; }

        /// <summary>
        /// How many times one player can buy this pack. Null for unlimited. Requires <see cref="PlayerVariableId"/>,
        /// as the purchase count is stored in a per-player variable.
        /// </summary>
        public int? PerPlayerMax { get; set; }

        /// <summary>
        /// mpplayervariablemappings ID for this pack's per-player purchase counter (ClassName=PackName). Vanilla
        /// and online packs use IDs up to 670 (online ones fill the 612-669 gaps); Milan IDs start at 700 and are
        /// shared with weapons/gear, so pick one that's free.
        /// </summary>
        public int? PlayerVariableId { get; set; }

        /// <summary>
        /// If set, the pack is only listed once the player has this achievement. Requires <see cref="PerPlayerMax"/>
        /// of 1 so it can only be claimed once.
        /// </summary>
        public AchievementUnlockInfo? UnlockInfo { get; set; }

        /// <summary>Authoring-only assertion: this achievement pack must award exactly this banner and nothing else.</summary>
        public int? BannerRewardID { get; set; }

        /// <summary>
        /// Platform offer / consumable ID, if the pack can also be granted by one. Adds a
        /// ConsumableIdPackNameMap entry.
        /// </summary>
        public int? OfferId { get; set; }

        /// <summary>
        /// Unix time after which the pack is no longer listed, if any.
        /// </summary>
        public int? ExpirationTime { get; set; }

        /// <summary>
        /// Visibility conditions: the pack shows if every ID in any one of these sets is satisfied - each inner
        /// array is one VisibleCondition's 'and' list. Empty for always visible.
        /// </summary>
        public List<int[]> Visible { get; set; } = new();

        /// <summary>
        /// Store image object path, e.g. "StoreItems.StoreAlliance" (built by ImagePackageBuilder) or
        /// "GUI_MPImages.StoreItems.Store001" (vanilla). Must be dynamic load mapped.
        /// </summary>
        public string Image { get; set; }

        /// <summary>
        /// Crate texture shown when the pack is opened, e.g. "GUI_MPImages.Creates.Alliance".
        /// </summary>
        public string RevealIntroTextureRef { get; set; }

        /// <summary>
        /// Crate hologram texture shown when the pack is opened, e.g. "GUI_MPImages.Creates.AllianceHolo".
        /// </summary>
        public string RevealIntroHoloTextureRef { get; set; }

        /// <summary>
        /// Reveal sound, e.g. "MPRevealCrate1".
        /// </summary>
        public string RevealIntroSound { get; set; }

        /// <summary>
        /// What the pack awards - one PackList entry per slot.
        /// </summary>
        public List<StorePackSlot> Contents { get; set; } = new();
    }

    /// <summary>
    /// One PackList entry: awards <see cref="Quantity"/> cards, each drawn from one of <see cref="Pools"/> by weight.
    /// </summary>
    public class StorePackSlot
    {
        public int Quantity { get; set; } = 1;

        /// <summary>
        /// Pools to draw from with their relative weights, e.g. (StorePools.GoldWeapon, 0.55f). A single pool can use weight 1.
        /// </summary>
        public List<(StorePool Pool, float Weight)> Pools { get; set; } = new();

        /// <summary>
        /// Pool to draw from if the chosen pool has nothing left to award, if any.
        /// </summary>
        public StorePool? BackupPool { get; set; }
    }
}
