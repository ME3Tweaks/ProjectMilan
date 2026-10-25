using System.Globalization;
using System.Text.RegularExpressions;
using LegendaryExplorerCore.Coalesced;

namespace ProjectMilanCore.Config.Store
{
    public sealed record StoreValidationResult(IReadOnlyList<string> Errors, IReadOnlyList<string> Warnings);

    /// <summary>
    /// Every card, pool and pack in the multiplayer store. Validated as a whole, then written into BioGame config as
    /// the complete SFXGAWReinforcementManager CardData/PackList/StoreInfoArray/ConsumableIdPackNameMap arrays (replacing
    /// the basegame's leftover CardData), one per-object config section per pool, and the mpplayervariablemappings for
    /// pack purchase counters and card ownership. Nothing store related lives in MergedConfig\BioGame.xml anymore.
    /// </summary>
    public sealed partial class StoreCatalog
    {
        public const string ManagerSection = "sfxgamempcontent.sfxgawreinforcementmanager";
        public const string GameConfigSection = "sfxgame.sfxgameconfig";
        public const string PlayerVariableMappings = "mpplayervariablemappings";

        public List<StoreCard> Cards { get; } = new();
        public List<StorePackEntry> Packs { get; } = new();

        /// <summary>
        /// The mpplayervariablemappings entries the catalog writes: pack purchase counters, achievement unlock latches and
        /// card ownership counters.
        /// </summary>
        public IEnumerable<(string Name, int Id, string Owner)> GetPlayerVariables()
        {
            foreach (var pack in Packs)
            {
                if (pack.PlayerVariableId is { } counter)
                    yield return (pack.PackName, counter, $"store pack {pack.PackName}");
                if (pack.UnlockInfo is { } unlock)
                    yield return (unlock.UnlockVariableName, unlock.UnlockVariableId, $"store pack {pack.PackName}'s unlock");
            }
            foreach (var card in Cards)
            {
                foreach (var (name, id) in card.PlayerVariables)
                    yield return (name, id, $"card {card.UniqueName}");
            }
        }

        /// <param name="otherPlayerVariables">mpplayervariablemappings already in config that the catalog doesn't own (powers, retired pack counters).</param>
        /// <param name="dynamicLoadObjects">Object paths with a dynamicloadmapping, to warn about cards whose class can't load. Null skips the check.</param>
        public StoreValidationResult Validate(IEnumerable<(string Name, int Id)> otherPlayerVariables, IReadOnlySet<string>? dynamicLoadObjects = null)
        {
            var errors = new List<string>();
            var warnings = new List<string>();

            // Cards
            foreach (var group in Cards.GroupBy(c => c.UniqueName, StringComparer.OrdinalIgnoreCase).Where(g => g.Count() > 1))
                errors.Add($"Card {group.Key} is defined {group.Count()} times");
            foreach (var card in Cards)
            {
                if (string.IsNullOrWhiteSpace(card.UniqueName) || card.GUIName <= 0 || string.IsNullOrWhiteSpace(card.GUIType) || string.IsNullOrWhiteSpace(card.GUITextureRef))
                    errors.Add($"Card {card.UniqueName} is missing its name, GUI name, GUI type or texture");
                if (!card.IsVersioned && card.PlayerVariableIds.Count > 1)
                    errors.Add($"Card {card.UniqueName} isn't versioned but has {card.PlayerVariableIds.Count} player variables");
                foreach (var dupe in card.Pools.GroupBy(p => (p.Pool, p.VersionIdx)).Where(g => g.Count() > 1))
                    errors.Add($"Card {card.UniqueName} is in pool {dupe.Key.Pool.Name} (version {dupe.Key.VersionIdx}) more than once");
                if (!card.IsVersioned && card.Pools.Any(p => p.Tokens != null))
                    errors.Add($"Card {card.UniqueName} has description tokens, but only match consumables and gear use them");
                if (card.Pools.Count == 0)
                    warnings.Add($"Card {card.UniqueName} isn't in any pool, so it can't be awarded");
                if (dynamicLoadObjects != null && card.UniqueName.Contains('.') && !dynamicLoadObjects.Contains(card.UniqueName))
                    warnings.Add($"Card {card.UniqueName} has no dynamicloadmapping, so its class may not load");
            }

            var byName = Cards.GroupBy(c => c.UniqueName, StringComparer.OrdinalIgnoreCase)
                .ToDictionary(g => g.Key, g => g.First(), StringComparer.OrdinalIgnoreCase);
            foreach (var card in Cards.Where(c => c.RequiresCard != null))
            {
                var visited = new HashSet<string>(StringComparer.OrdinalIgnoreCase) { card.UniqueName };
                var current = card;
                while (current.RequiresCard is { } required)
                {
                    if (!visited.Add(required))
                    {
                        errors.Add($"Card {card.UniqueName} has a prerequisite cycle");
                        break;
                    }
                    if (!byName.TryGetValue(required, out current) || current.IsVersioned || current.PlayerVariableIds.Count != 1)
                    {
                        errors.Add($"Card {card.UniqueName} requires an unknown or untracked card {required}");
                        break;
                    }
                }
            }
            errors.AddRange(ValidateBanners([]).Errors);

            // Pools
            var poolMembers = Cards.SelectMany(c => c.Pools.Select(p => p.Pool)).ToHashSet();
            var referencedPools = new HashSet<StorePool>();
            foreach (var pack in Packs)
            {
                foreach (var slot in pack.Contents)
                {
                    referencedPools.UnionWith(slot.Pools.Select(p => p.Pool));
                    if (slot.BackupPool != null)
                        referencedPools.Add(slot.BackupPool);
                }
            }
            foreach (var pool in referencedPools.Where(p => !poolMembers.Contains(p)))
                errors.Add($"Pool {pool.Name} is used by a store pack but has no cards");
            foreach (var pool in poolMembers.Where(p => !referencedPools.Contains(p)).OrderBy(p => p.Name))
                warnings.Add($"Pool {pool.Name} isn't used by any store pack");

            // Packs
            foreach (var group in Packs.GroupBy(p => p.ID).Where(g => g.Count() > 1))
                errors.Add($"Store nID {group.Key} is used by {string.Join(", ", group.Select(p => p.PackName))}");
            foreach (var group in Packs.GroupBy(p => p.PackName, StringComparer.OrdinalIgnoreCase).Where(g => g.Count() > 1))
                errors.Add($"Store pack name {group.Key} is used {group.Count()} times");
            foreach (var group in Packs.Where(p => p.OfferId != null).GroupBy(p => p.OfferId).Where(g => g.Count() > 1))
                errors.Add($"Offer ID {group.Key} is used by {string.Join(", ", group.Select(p => p.PackName))}");
            foreach (var pack in Packs)
            {
                if (pack.PerPlayerMax != null && pack.PlayerVariableId == null)
                    errors.Add($"Store pack {pack.PackName} has a PerPlayerMax but no PlayerVariableId to store its purchase count in");
                if (pack.UnlockInfo != null && pack.PerPlayerMax != 1)
                    errors.Add($"Store pack {pack.PackName} is unlocked by an achievement but isn't limited to one per player");
                if (string.IsNullOrWhiteSpace(pack.Image))
                    errors.Add($"Store pack {pack.PackName} has no image");
                if (pack.Contents.Count == 0)
                    errors.Add($"Store pack {pack.PackName} has no contents");
                foreach (var slot in pack.Contents)
                {
                    if (slot.Quantity <= 0 || slot.Pools.Count == 0)
                        errors.Add($"Store pack {pack.PackName} has a slot with no quantity or no pools");
                    if (slot.Pools.Any(p => p.Weight <= 0))
                        errors.Add($"Store pack {pack.PackName} has a pool weight of 0 or less");
                }
            }

            // Player variables: saves store these by ID, so neither names nor IDs can be shared
            var allVariables = GetPlayerVariables().Concat(otherPlayerVariables.Select(v => (v.Name, v.Id, Owner: "existing config"))).ToList();
            foreach (var group in allVariables.GroupBy(v => v.Id).Where(g => g.Count() > 1))
                errors.Add($"Player variable ID {group.Key} is used by {string.Join(", ", group.Select(v => $"{v.Name} ({v.Owner})"))}");
            foreach (var group in allVariables.GroupBy(v => v.Name, StringComparer.OrdinalIgnoreCase).Where(g => g.Count() > 1))
                errors.Add($"Player variable {group.Key} is mapped {group.Count()} times ({string.Join(", ", group.Select(v => $"{v.Id} from {v.Owner}"))})");

            return new StoreValidationResult(errors, warnings);
        }

        /// <summary>
        /// Validates the catalog against <paramref name="bioGame"/>'s existing player variables and writes it in. Throws
        /// if validation fails; returns the warnings.
        /// </summary>
        public IReadOnlyList<string> Commit(CoalesceAsset bioGame, IReadOnlySet<string>? dynamicLoadObjects = null)
        {
            var gameConfig = bioGame.GetOrAddSection(GameConfigSection);
            var result = Validate(ReadPlayerVariables(gameConfig), dynamicLoadObjects);
            if (result.Errors.Count > 0)
                throw new Exception($"The store catalog is invalid:\n{string.Join("\n", result.Errors)}");

            var manager = bioGame.GetOrAddSection(ManagerSection);
            ReplaceArray(manager, "carddata", Cards.Select(SerializeCard));
            ReplaceArray(manager, "storeinfoarray", Packs.Select(SerializeStoreInfo));
            ReplaceArray(manager, "packlist", Packs.SelectMany(p => p.Contents.Select(slot => SerializePackSlot(p.PackName, slot))));
            ReplaceArray(manager, "consumableidpacknamemap", Packs.Where(p => p.OfferId != null).Select(p => $"(ID={p.OfferId}, PackName=\"{p.PackName}\")"));
            ReplaceArray(manager, "milanachievementpacks", Packs.Where(p => p.UnlockInfo != null)
                .Select(p => $"(PackName=\"{p.PackName}\", AchievementId={p.UnlockInfo!.AchievementId}, UnlockVariable={p.UnlockInfo.UnlockVariableName})"));

            var requirements = bioGame.GetOrAddSection("sfxgamecontent_milan.sfxmilanstoreprerequisites");
            ReplaceArray(requirements, "requirements", Cards.Where(c => c.RequiresCard != null).Select(c =>
                $"(CardName=\"{c.UniqueName}\",RequiredVariable={Cards.Single(p => p.UniqueName.Equals(c.RequiresCard, StringComparison.OrdinalIgnoreCase)).PlayerVariables.Single().Name})"));

            foreach (var (name, id, _) in GetPlayerVariables())
            {
                gameConfig.AddEntry(new CoalesceProperty(PlayerVariableMappings, new CoalesceValue($"(ClassName=\"{name}\",ID={id})", CoalesceParseAction.AddUnique)));
            }

            foreach (var poolSection in BuildPoolSections())
            {
                bioGame.Sections[poolSection.Name] = poolSection;
            }

            return result.Warnings;
        }

        /// <summary>
        /// One section per (pool, kind of card): SFXGAWReinforcementManager.LoadDeck loads every SFXGAWReinforcementBase
        /// per-object config section and matches them to pack slots by PoolName, so the section names themselves don't matter.
        /// </summary>
        public IEnumerable<CoalesceSection> BuildPoolSections()
        {
            var memberships = Cards.SelectMany(c => c.Pools.Select(p => (Card: c, Entry: p)))
                .GroupBy(m => (m.Entry.Pool, m.Card.Kind))
                .OrderBy(g => g.Key.Kind).ThenBy(g => g.Key.Pool.Name, StringComparer.OrdinalIgnoreCase);
            foreach (var group in memberships)
            {
                var className = GetReinforcementClassName(group.Key.Kind);
                var section = new CoalesceSection($"{className}_{group.Key.Pool.Name.ToLowerInvariant()} {className}");
                section.AddEntry(new CoalesceProperty("cardlist", group.Select(m => new CoalesceValue(SerializePoolCard(m.Card, m.Entry), CoalesceParseAction.AddUnique)).ToList()));
                section.AddEntry(new CoalesceProperty("poolname", new CoalesceValue(group.Key.Pool.Name, CoalesceParseAction.New)));
                // The ME3 DLC pools required their DLC module; everything ships together in Milan
                section.AddEntry(new CoalesceProperty("requireddlcmoduleids", new CoalesceValue("null", CoalesceParseAction.RemoveProperty)));
                var tokens = group.Where(m => m.Entry.Tokens != null).ToList();
                if (tokens.Count > 0)
                {
                    var tokenProperty = group.Key.Kind == ReinforcementKind.MatchConsumableGear ? "geartokenslist" : "tokenslist";
                    section.AddEntry(new CoalesceProperty(tokenProperty, tokens.Select(m =>
                        new CoalesceValue($"(UniqueName=\"{m.Card.UniqueName}\",{m.Entry.Tokens})", CoalesceParseAction.AddUnique)).ToList()));
                }
                yield return section;
            }
        }

        public static string GetReinforcementClassName(ReinforcementKind kind) => kind switch
        {
            ReinforcementKind.InventoryUnlock => "sfxgawreinforcementinventoryunlock",
            ReinforcementKind.KitUnlock => "sfxgawreinforcementkitunlock",
            ReinforcementKind.MatchConsumable => "sfxgawreinforcementmatchconsumable",
            ReinforcementKind.MatchConsumableGear => "sfxgawreinforcementmatchconsumable_gear",
            ReinforcementKind.InGameConsumable => "sfxgawreinforcementingameconsumable",
            ReinforcementKind.Credits => "sfxgawreinforcementcredits",
            ReinforcementKind.PermanentUpgrade => "sfxgawreinforcementpermanentupgrade",
            _ => throw new ArgumentOutOfRangeException(nameof(kind)),
        };

        public static string SerializeCard(StoreCard card)
        {
            var parts = new List<string> { $"UniqueName=\"{card.UniqueName}\"" };
            if (card.MaxCount != null)
                parts.Add($"MaxCount={card.MaxCount}");
            parts.Add($"Rarity=Rarity_{card.Rarity}");
            if (card.UseVersionIdx != null)
                parts.Add($"bUseVersionIdx={(card.UseVersionIdx.Value ? "true" : "false")}");
            if (card.VersionIdx != null)
                parts.Add($"VersionIdx={card.VersionIdx}");
            if (card.Category != null)
                parts.Add($"Category={card.Category}");
            parts.Add($"GUIName={card.GUIName}");
            if (card.GUIDescription != null)
                parts.Add($"GUIDescription={card.GUIDescription}");
            if (card.GUICategory != null)
                parts.Add($"GUICategory=EReinforcementGUICategory_{card.GUICategory}");
            parts.Add($"GUIType=\"{card.GUIType}\"");
            parts.Add($"GUITextureRef=\"{card.GUITextureRef}\"");
            return $"({string.Join(", ", parts)})";
        }

        public static string SerializePoolCard(StoreCard card, PoolEntry entry)
        {
            var parts = new List<string> { $"UniqueName=\"{card.UniqueName}\"" };
            if (entry.VersionIdx != null)
                parts.Add($"VersionIdx={entry.VersionIdx}");
            if (entry.PVIncrementBonus != null)
                parts.Add($"PVIncrementBonus={entry.PVIncrementBonus}");
            if (entry.GUIName != null)
                parts.Add($"GUIName={entry.GUIName}");
            if (entry.Rarity != null)
                parts.Add($"Rarity=Rarity_{entry.Rarity}");
            if (entry.MaxCount != null)
                parts.Add($"MaxCount={entry.MaxCount}");
            return $"({string.Join(", ", parts)})";
        }

        public static string SerializeStoreInfo(StorePackEntry entry)
        {
            var parts = new List<string>
            {
                $"nID={entry.ID}",
                $"PackName=\"{entry.PackName}\"",
                $"Title={entry.TitleStrRefId}",
            };
            if (entry.SubTitleStrRefId != null)
                parts.Add($"SubTitle={entry.SubTitleStrRefId}");
            parts.Add($"Description={entry.DescriptionStrRefId}");
            if (entry.Visible.Count > 0)
                parts.Add($"Visible=({string.Join(",", entry.Visible.Select(ids => $"(and=({string.Join(",", ids)}))"))})");
            if (entry.OfferId != null)
                parts.Add($"OfferId={entry.OfferId}");
            if (entry.ExpirationTime != null)
                parts.Add($"ExpirationTime={entry.ExpirationTime}");
            parts.Add($"CreditCost={entry.CreditCost}");
            if (entry.PromoStrRefId != null)
                parts.Add($"srPromoString={entry.PromoStrRefId}");
            if (entry.PerPlayerMax != null)
                parts.Add($"PerPlayerMax={entry.PerPlayerMax}");
            parts.Add($"ImageData=(ImageLocation=EStoreImageLocation_Local, ImageReference=\"{entry.Image}\")");
            parts.Add($"RevealIntroTextureRef=\"{entry.RevealIntroTextureRef}\"");
            parts.Add($"RevealIntroHoloTextureRef=\"{entry.RevealIntroHoloTextureRef}\"");
            parts.Add($"RevealIntroSound={entry.RevealIntroSound}");
            return $"({string.Join(", ", parts)})";
        }

        public static string SerializePackSlot(string packName, StorePackSlot slot)
        {
            // A lone pool gets drawn every time, so vanilla leaves its weight off
            var pools = slot.Pools.Count == 1
                ? $"(PoolName=\"{slot.Pools[0].Pool.Name}\")"
                : string.Join(",", slot.Pools.Select(p => $"(PoolName=\"{p.Pool.Name}\",Weight={p.Weight.ToString("0.0##", CultureInfo.InvariantCulture)})"));
            var backup = slot.BackupPool != null ? $", BackupPool=\"{slot.BackupPool.Name}\"" : "";
            return $"(PackName=\"{packName}\", Quantity={slot.Quantity}, Pools=({pools}){backup})";
        }

        /// <summary>
        /// Replaces a config array completely: clear it (dropping basegame values too), then add each value.
        /// </summary>
        private static void ReplaceArray(CoalesceSection section, string propertyName, IEnumerable<string> values)
        {
            section.Remove(propertyName);
            var property = new CoalesceProperty(propertyName, new CoalesceValue("null", CoalesceParseAction.RemoveProperty));
            foreach (var value in values)
                property.Add(new CoalesceValue(value, CoalesceParseAction.AddUnique));
            section.AddEntry(property);
        }

        [GeneratedRegex("ClassName\\s*=\\s*\"([^\"]+)\"\\s*,\\s*ID\\s*=\\s*(\\d+)", RegexOptions.IgnoreCase)]
        private static partial Regex PlayerVariableMappingRegex();

        public static IEnumerable<(string Name, int Id)> ReadPlayerVariables(CoalesceSection gameConfig)
        {
            if (!gameConfig.TryGetValue(PlayerVariableMappings, out var mappings))
                yield break;
            foreach (var value in mappings)
            {
                if (value.ParseAction is CoalesceParseAction.Remove or CoalesceParseAction.RemoveProperty || value.Value == null)
                    continue;
                var match = PlayerVariableMappingRegex().Match(value.Value);
                if (match.Success)
                    yield return (match.Groups[1].Value, int.Parse(match.Groups[2].Value));
            }
        }
    }
}
