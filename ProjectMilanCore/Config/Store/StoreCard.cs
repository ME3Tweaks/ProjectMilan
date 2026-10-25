namespace ProjectMilanCore.Config.Store
{
    /// <summary>
    /// ECardRarity in SFXGAWReinforcementBase.uc. Serialized as Rarity_X.
    /// </summary>
    public enum CardRarity
    {
        Common,
        Uncommon,
        Rare,
        UltraRare,
    }

    /// <summary>
    /// EReinforcementGUICategory in SFXGAWReinforcementBase.uc. Serialized as EReinforcementGUICategory_X.
    /// </summary>
    public enum CardGUICategory
    {
        AssaultRifle,
        SniperRifle,
        Shotgun,
        Pistol,
        SMG,
        Mod,
        Kit,
        MatchConsumableAmmo,
        MatchConsumableWeapon,
        MatchConsumableArmor,
        MatchConsumableGear,
    }

    /// <summary>
    /// Which SFXGAWReinforcement subclass awards the card. A pool is written as one per-object config section per
    /// kind of card in it, so this decides the section's class.
    /// </summary>
    public enum ReinforcementKind
    {
        /// <summary>Weapons and weapon mods.</summary>
        InventoryUnlock,
        /// <summary>Characters.</summary>
        KitUnlock,
        /// <summary>One-match boosts (ammo, armor, weapon). Ownership is tracked per version.</summary>
        MatchConsumable,
        /// <summary>Gear. Ownership is tracked per version.</summary>
        MatchConsumableGear,
        /// <summary>Medi-gel, ops packs, thermal clips and rockets.</summary>
        InGameConsumable,
        /// <summary>Credit rewards.</summary>
        Credits,
        /// <summary>Capacity upgrades and respec cards.</summary>
        PermanentUpgrade,
    }

    /// <summary>
    /// A card the store can award: its SFXGAWReinforcementManager CardData entry, the player variables that store how
    /// many the player owns, and the pools it can be drawn from. Mirrors CardInfoData in SFXGAWReinforcementBase.uc.
    /// </summary>
    public sealed record StoreCard
    {
        /// <summary>
        /// Class path for weapons, mods, consumables and gear (e.g. "SFXGameContent.SFXWeapon_AssaultRifle_Avenger"), or the
        /// bare name for kits and upgrades (e.g. "AdeptHumanMale", "MPRespec"). Unique across the store.
        /// </summary>
        public required string UniqueName { get; init; }

        /// <summary>Permanent emblem ID for a store banner. Null for ordinary cards; never renumber or reuse.</summary>
        public int? BannerID { get; init; }

        public required ReinforcementKind Kind { get; init; }

        public required CardRarity Rarity { get; init; }

        /// <summary>
        /// Most copies a player can own. Null leaves it unset (unlimited).
        /// </summary>
        public int? MaxCount { get; init; }

        public bool? UseVersionIdx { get; init; }

        public int? VersionIdx { get; init; }

        /// <summary>
        /// Match consumable category (1 ammo, 2 armor, 3 weapon, 4 gear).
        /// </summary>
        public int? Category { get; init; }

        /// <summary>
        /// TLK String ID of the card's name.
        /// </summary>
        public required int GUIName { get; init; }

        /// <summary>
        /// TLK String ID of the card's description, if any.
        /// </summary>
        public int? GUIDescription { get; init; }

        public CardGUICategory? GUICategory { get; init; }

        /// <summary>
        /// GUI card type, e.g. "assault", "char", "gearUpgrade".
        /// </summary>
        public required string GUIType { get; init; }

        /// <summary>
        /// Card image object path, e.g. "GUI_MPImages.Cards.KitDrell".
        /// </summary>
        public required string GUITextureRef { get; init; }

        /// <summary>
        /// mpplayervariablemappings IDs that store how many of this card the player owns. These end up in player saves,
        /// so they must never change. Match consumables and gear have one per version (the variable is named
        /// UniqueName_&lt;version&gt;, indexed by position); everything else has at most one (named UniqueName).
        /// Empty if the card has no ownership counter.
        /// </summary>
        public IReadOnlyList<int> PlayerVariableIds { get; init; } = [];

        /// <summary>
        /// Pools this card can be drawn from.
        /// </summary>
        public IReadOnlyList<PoolEntry> Pools { get; init; } = [];

        /// <summary>
        /// Whether ownership is counted per version (UniqueName_&lt;version&gt;).
        /// </summary>
        public bool IsVersioned => Kind is ReinforcementKind.MatchConsumable or ReinforcementKind.MatchConsumableGear;

        /// <summary>
        /// The mpplayervariablemappings entries for this card.
        /// </summary>
        public IEnumerable<(string Name, int Id)> PlayerVariables =>
            PlayerVariableIds.Select((id, version) => (IsVersioned ? $"{UniqueName}_{version}" : UniqueName, id));
    }

    /// <summary>
    /// A card's membership in a pool. Overrides here apply to the copy of the card in that pool only (CardList entry).
    /// </summary>
    public sealed record PoolEntry(StorePool Pool)
    {
        /// <summary>
        /// Version of the card this pool awards (e.g. 0-3 for match consumable I-IV).
        /// </summary>
        public int? VersionIdx { get; init; }

        /// <summary>
        /// How many copies one draw awards.
        /// </summary>
        public int? PVIncrementBonus { get; init; }

        public int? GUIName { get; init; }

        public CardRarity? Rarity { get; init; }

        public int? MaxCount { get; init; }

        /// <summary>
        /// Description token values for this card in this pool, as the inside of the TokensList/GearTokensList struct
        /// without UniqueName, e.g. "Custom0Token=0.20f,Custom6Token=20". Only match consumables and gear use these.
        /// </summary>
        public string? Tokens { get; init; }
    }

    /// <summary>
    /// A named pool of cards that pack slots draw from. Cards join a pool through <see cref="StoreCard.Pools"/>.
    /// </summary>
    public sealed record StorePool(string Name);
}
