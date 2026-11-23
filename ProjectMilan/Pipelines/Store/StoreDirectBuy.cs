using System.Globalization;
using System.Text.RegularExpressions;
using LegendaryExplorerCore.Coalesced;
using LegendaryExplorerCore.Packages;
using ProjectMilanCore;
using ProjectMilanCore.Config.Store;
using ProjectMilanCore.Utility;

namespace ProjectMilan.Pipelines.Store
{
    /// <summary>
    /// Writes the Direct Buy store's catalog (SFXGameContent_Milan.SFXGUI_MPDirectBuyStore in the MPLobby package) from the
    /// store catalog
    /// </summary>
    internal static class StoreDirectBuy
    {
        private const string LOG_CATEGORY = @"MILAN-DirectBuy";

        /// <summary>
        /// Config section of SFXGUI_MPDirectBuyStore
        /// </summary>
        public const string SectionName = $"{MilanShared.GAMECONTENT_MILAN_CONFIG}.sfxgui_mpdirectbuystore";

        private static readonly LocalizedString AssaultRifleModsTitle = new() {
            [MELocalization.INT] = "Assault Rifle Mods",
        };
        private static readonly LocalizedString SniperRifleModsTitle = new() {
            [MELocalization.INT] = "Sniper Rifle Mods",
        };
        private static readonly LocalizedString ShotgunModsTitle = new() {
            [MELocalization.INT] = "Shotgun Mods",
        };
        private static readonly LocalizedString PistolModsTitle = new() {
            [MELocalization.INT] = "Pistol Mods",
        };
        private static readonly LocalizedString SMGModsTitle = new() {
            [MELocalization.INT] = "SMG Mods",
        };

        private static readonly LocalizedString AmmoEquipmentTitle = new()
        {
            [MELocalization.INT] = "Ammo Equipment",
        };

        private static readonly LocalizedString WeaponEquipmentTitle = new()
        {
            [MELocalization.INT] = "Weapon Equipment",
        };

        private static readonly LocalizedString ArmorEquipmentTitle = new()
        {
            [MELocalization.INT] = "Armor Equipment",
        };

        private static readonly LocalizedString GearTitle = new()
        {
            [MELocalization.INT] = "Gear",
        };

        // Locked offers. <CUSTOM0> is the required card's name.
        private static readonly LocalizedString RequiresText = new() {
            [MELocalization.INT] = "Requires <CUSTOM0>.",
        };
        private static readonly LocalizedString RespecDescription = new() {
            [MELocalization.INT] = "Resets one character's powers, allowing their power points to be reassigned.",
        };

        /// <summary>
        /// A store category and the card GUITypes in it
        /// </summary>
        private sealed record Category(int Title, params string[] GUITypes);

        /// <summary>
        /// Categories in store order. GUITypes are case-insensitive.
        /// </summary>
        private static List<Category> GetCategories() =>
        [
            new(576099, "assault"), // Assault Rifles
            new(576100, "sniper"), // Sniper Rifles
            new(576101, "shotgun"), // Shotguns
            new(576102, "pistol"), // Pistols
            new(576103, "smg"), // SMGs
            new(593649, "heavyweapon"), // Heavy Weapons
            new(MilanPipelinesShared.AssignTLK(AssaultRifleModsTitle), "assaultmod"),
            new(MilanPipelinesShared.AssignTLK(SniperRifleModsTitle), "snipermod"),
            new(MilanPipelinesShared.AssignTLK(ShotgunModsTitle), "shotgunmod"),
            new(MilanPipelinesShared.AssignTLK(PistolModsTitle), "pistolmod"),
            new(MilanPipelinesShared.AssignTLK(SMGModsTitle), "smgmod"),
            new(598885, "char"), // Characters
            new(MilanPipelinesShared.AssignTLK(AmmoEquipmentTitle), "ammoUpgrade"), // Ammo Equipment
            new(MilanPipelinesShared.AssignTLK(WeaponEquipmentTitle), "weaponUpgrade"), // Weapon Equipment
            new(MilanPipelinesShared.AssignTLK(ArmorEquipmentTitle), "armorUpgrade"), // Armor Equipment
            new(MilanPipelinesShared.AssignTLK(GearTitle), "gearUpgrade"), // Gear
            new(724948, "consumable"), // Supplies
            new(331559, "capacity", "respec"), // Upgrades
            new(49875811, "banner"), // Banners
        ];

        /// <Summary>Commits the store catalog to the config bundle</Summary>
        /// <param name="bannerDescription">The shared banner description</param>
        /// <param name="builtImages">Images ImagePackageBuilder built</param>
        /// <param name="mappedImages">Every dynamic load mapped object</param>
        public static void Commit(StoreCatalog catalog, CoalesceAsset bioUI, int bannerDescription, IReadOnlySet<string> builtImages, IReadOnlySet<string> mappedImages)
        {
            var categories = GetCategories();
            var categoryByType = new Dictionary<string, int>(StringComparer.OrdinalIgnoreCase);
            for (int i = 0; i < categories.Count; i++)
            {
                foreach (var type in categories[i].GUITypes)
                {
                    categoryByType.Add(type, i);
                }
            }

            // Achievement banners cannot be purchased
            var achievementBanners = StoreCards.AchievementBanners.Select(b => b.UniqueName).ToHashSet(StringComparer.OrdinalIgnoreCase);
            var offers = new List<(int Category, StoreCard Card)>();
            foreach (var card in catalog.Cards)
            {
                if (card.Kind == ReinforcementKind.Credits || achievementBanners.Contains(card.UniqueName))
                {
                    continue;
                }
                // Cards that can't drop aren't sold
                if (card.Pools.Count == 0)
                {
                    continue;
                }
                if (!categoryByType.TryGetValue(card.GUIType, out var category))
                {
                    MilanLog.Warning($"Card {card.UniqueName} has GUIType {card.GUIType}, which has no Direct Buy category, it cannot be purchased", customPrefix: LOG_CATEGORY);
                    continue;
                }
                offers.Add((category, card));
            }

            var mergedBioUI = File.ReadAllText(Path.Combine(MilanShared.PipelineRoot, "Mod", "MergedConfig", "BioUI.xml"));
            var context = new OfferContext(catalog, bannerDescription, GetGoBigDescriptions(mergedBioUI), GetKitDescriptions(mergedBioUI), MilanPipelinesShared.AssignTLK(RespecDescription),
                card => DirectBuyImages.GetStoreImage(card.GUITextureRef, builtImages, mappedImages));
            var rows = offers.OrderBy(o => o.Category).SelectMany(o => SerializeOffer(o.Category, o.Card, context)).ToList();
            var swappedImages = offers.Count(o => context.GetImage(o.Card) != o.Card.GUITextureRef);
            MilanLog.Information($"Direct Buy: {swappedImages} cards will use their codex or larger image instead of the card image", customPrefix: LOG_CATEGORY);
            var section = bioUI.GetOrAddSection(SectionName);
            ReplaceArray(section, "categories", categories.Select(c => $"(Title={c.Title})"));
            ReplaceArray(section, "offers", rows);
            ReplaceArray(section, "pricegroups", DirectBuyPricing.GetPriceGroups().Select(DirectBuyPricing.SerializePriceGroup));
            ReplaceArray(section, "priceoverrides", DirectBuyPricing.GetPriceOverrides().Select(o => DirectBuyPricing.SerializePriceOverride(o.Key, o.Value.Cost, o.Value.CostPerRank)));
            SetValue(section, "srrequires", MilanPipelinesShared.AssignTLK(RequiresText));
            // Read by the movie via GetIniString
            SetValue(section, "srcreditstitle", 346393);
            SetValue(section, "srcosttitle", 341340);
            MilanLog.Information($"Direct Buy: {offers.Count} cards ({rows.Count} offer rows) in {categories.Count} categories", customPrefix: LOG_CATEGORY);
        }

        /// <summary>
        /// The offer rows for one card
        /// </summary>
        /// <param name="Description">Match consumable description -> go big description</param>
        /// <param name="KitDescriptions">Kit name -> character info strings</param>
        private sealed record OfferContext(StoreCatalog Catalog, int BannerDescription, IReadOnlyDictionary<int, int> Description, IReadOnlyDictionary<string, int[]> KitDescriptions, int RespecDescription, Func<StoreCard, string> GetImage);

        /// <summary>
        /// Writes an offer into config
        /// </summary>
        /// <param name="category"></param>
        /// <param name="card"></param>
        /// <param name="context"></param>
        /// <returns></returns>
        private static IEnumerable<string> SerializeOffer(int category, StoreCard card, OfferContext context)
        {
            var description = card.GUIDescription ?? 0;
            if (description == 0 && card.BannerID != null)
            {
                // Use banner description
                description = context.BannerDescription;
            }
            else if (description == 0 && card.GUIType.Equals("respec", StringComparison.OrdinalIgnoreCase))
            {
                // Use respec description
                description = context.RespecDescription;
            }
            var common = $"Category={category},UniqueName=\"{card.UniqueName}\",GUIName={card.GUIName},GUIDescription={description},Image=\"{context.GetImage(card)}\",MaxCount={card.MaxCount ?? 0},PriceGroup={DirectBuyPricing.GetPriceGroup(card)}";
            if (context.KitDescriptions.TryGetValue(card.UniqueName, out var kitStrings))
            {
                common += $",KitStrings=({string.Join(",", kitStrings)})";
            }
            if (card.RequiresCard != null)
            {
                // Prerequesite
                var required = context.Catalog.Cards.Single(c => c.UniqueName.Equals(card.RequiresCard, StringComparison.OrdinalIgnoreCase));
                common += $",Requires=\"{required.PlayerVariables.Single().Name}\",RequiresName={required.GUIName}";
            }
            var goBigDescriptions = context.Description;
            switch (card.Kind)
            {
                case ReinforcementKind.MatchConsumable:
                    var hasGoBig = goBigDescriptions.TryGetValue(description, out var goBig);
                    var consumableCommon = hasGoBig ? common.Replace($"GUIDescription={description},", $"GUIDescription={goBig},") : common;
                    foreach (var version in card.Pools.Where(p => p.VersionIdx != null).Select(p => p.VersionIdx!.Value).Distinct().Order())
                    {
                        var tokens = ParseTokens(card.Pools.FirstOrDefault(p => p.VersionIdx == version && p.Tokens != null)?.Tokens);
                        var tokenText = hasGoBig ? $",DescTokens=({FormatTokens(Enumerable.Range(0, 10).Select(i => FormatMatchConsumableToken(i, tokens.GetValueOrDefault((i, -1)))))})" : "";
                        // Rarity is per version
                        var rarity = card.Pools.FirstOrDefault(p => p.VersionIdx == version && p.Rarity != null)?.Rarity ?? card.Rarity;
                        yield return $"({consumableCommon},Counter=\"{card.UniqueName}_{version}\",Rank={version + 1},Rarity={(int)rarity}{tokenText})";
                    }
                    break;
                case ReinforcementKind.MatchConsumableGear:
                    var gearTokens = ParseTokens(card.Pools.FirstOrDefault(p => p.Tokens != null)?.Tokens);
                    var counter = $"{card.UniqueName}_{card.VersionIdx ?? 0}";
                    for (int level = 1; level <= (card.MaxCount ?? 1); level++)
                    {
                        // Like PrepareCustomTokensForGearDescription
                        var levelTokens = new List<string>();
                        var lastToken = gearTokens.Keys.Where(k => k.Level == level - 1).Select(k => k.Token).DefaultIfEmpty(-1).Max();
                        for (int i = 0; i <= lastToken; i++)
                        {
                            if (!gearTokens.TryGetValue((i, level - 1), out var value))
                            {
                                levelTokens.Add("");
                            }
                            else
                            {
                                // 0-2 are percentages, 3-4 integers
                                levelTokens.Add(i < 3 ? FormatPercent(value) : ((int)value).ToString(CultureInfo.InvariantCulture));
                            }
                        }
                        var tokenText = levelTokens.Count > 0 ? $",DescTokens=({FormatTokens(levelTokens)})" : "";
                        yield return $"({common},Counter=\"{counter}\",Rank={level},bLevel=true,Rarity={(int)card.Rarity}{tokenText})";
                    }
                    break;
                default:
                    var counterName = card.PlayerVariables.Select(v => v.Name).FirstOrDefault() ?? "";
                    yield return $"({common},Counter=\"{counterName}\",Rank={(counterName == "" ? 1 : 0)},Rarity={(int)card.Rarity})";
                    break;
            }
        }

        /// <summary>
        /// Match consumable description -> go big description, from CardListSupplemental
        /// </summary>
        private static Dictionary<int, int> GetGoBigDescriptions(string mergedBioUI)
        {
            var result = new Dictionary<int, int>();
            foreach (Match match in Regex.Matches(mergedBioUI, @"GUIDescription\s*=\s*(\d+)\s*,\s*GUIDescription_GoBig\s*=\s*(\d+)", RegexOptions.IgnoreCase))
            {
                result[int.Parse(match.Groups[1].Value, CultureInfo.InvariantCulture)] = int.Parse(match.Groups[2].Value, CultureInfo.InvariantCulture);
            }
            if (result.Count == 0)
            {
                MilanLog.Warning("Found no CardListSupplemental go big descriptions in MergedConfig\\BioUI.xml; match consumables show their short descriptions", customPrefix: LOG_CATEGORY);
            }
            return result;
        }

        /// <summary>
        /// Kit name -> SFXGUI_MPSelectKit_DLC KitDescriptions strings, in KitDescriptionData order
        /// </summary>
        private static Dictionary<string, int[]> GetKitDescriptions(string mergedBioUI)
        {
            // ugh
            string[] fields = ["ClassString", "IPNameString", "IPEntryString", "GameplayEntryString", "StatsString1", "StatsString2", "StatsString3", "StatsString4", "StatsString5"];
            var result = new Dictionary<string, int[]>(StringComparer.OrdinalIgnoreCase);
            foreach (Match match in Regex.Matches(mergedBioUI, @"\(KitName\s*=\s*""([^""]+)""([^)]*)\)", RegexOptions.IgnoreCase))
            {
                result[match.Groups[1].Value] = fields.Select(field =>
                {
                    var value = Regex.Match(match.Groups[2].Value, $@"\b{field}\s*=\s*(\d+)", RegexOptions.IgnoreCase);
                    return value.Success ? int.Parse(value.Groups[1].Value, CultureInfo.InvariantCulture) : 0;
                }).ToArray();
            }
            if (result.Count == 0)
            {
                MilanLog.Warning("Found no KitDescriptions in MergedConfig\\BioUI.xml - CHARACTERS HAVE NO DESCRIPTION!", customPrefix: LOG_CATEGORY);
            }
            return result;
        }

        /// <summary>
        /// Parses pool entry tokens into (token, level) -> value. Level is -1 for non-array tokens.
        /// </summary>
        private static Dictionary<(int Token, int Level), float> ParseTokens(string? tokens)
        {
            var result = new Dictionary<(int, int), float>();
            if (tokens == null)
            {
                return result;
            }
            foreach (Match match in Regex.Matches(tokens, @"Custom(\d)Tokens?(?:\[(\d+)\])?\s*=\s*(-?[\d.]+)f?"))
            {
                var level = match.Groups[2].Success ? int.Parse(match.Groups[2].Value, CultureInfo.InvariantCulture) : -1;
                result[(int.Parse(match.Groups[1].Value, CultureInfo.InvariantCulture), level)] = float.Parse(match.Groups[3].Value, CultureInfo.InvariantCulture);
            }
            return result;
        }

        /// <summary>
        /// Like PrepareCustomTokensForDescription
        /// </summary>
        private static string FormatMatchConsumableToken(int token, float value) => token switch
        {
            0 or 2 or 4 or 7 => FormatPercent(value),
            6 or 9 => ((int)value).ToString(CultureInfo.InvariantCulture),
            _ => TrimZeroes(value.ToString("F2", CultureInfo.InvariantCulture), keepDecimal: true),
        };

        private static string FormatPercent(float value) => TrimZeroes((value * 100).ToString("F2", CultureInfo.InvariantCulture), keepDecimal: false);

        /// <summary>
        /// Like the game's TrimTrailingZeroes
        /// </summary>
        private static string TrimZeroes(string text, bool keepDecimal)
        {
            var trimmed = text.TrimEnd('0');
            if (trimmed.EndsWith('.'))
            {
                trimmed = keepDecimal ? trimmed + "0" : trimmed[..^1];
            }
            return trimmed;
        }

        private static string FormatTokens(IEnumerable<string> tokens) => string.Join(",", tokens.Select(t => $"\"{t}\""));

        private static void SetValue(CoalesceSection section, string propertyName, int value)
        {
            section.Remove(propertyName);
            section.AddEntry(new CoalesceProperty(propertyName, new CoalesceValue(value.ToString(CultureInfo.InvariantCulture), CoalesceParseAction.New)));
        }

        private static void ReplaceArray(CoalesceSection section, string propertyName, IEnumerable<string> values)
        {
            section.Remove(propertyName);
            var property = new CoalesceProperty(propertyName, new CoalesceValue("null", CoalesceParseAction.RemoveProperty));
            foreach (var value in values)
            {
                property.Add(new CoalesceValue(value, CoalesceParseAction.AddUnique));
            }
            section.AddEntry(property);
        }
    }
}
