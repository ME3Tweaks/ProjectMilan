using System.Text.RegularExpressions;
using LegendaryExplorerCore.Coalesced;

namespace ProjectMilanCore.Config.Store;

public sealed partial class StoreCatalog
{
    public const string BannerRewardsSection = "sfxgamecontent_milan.sfxmilanbannerrewards";
    public const string BannerEmblemsSection = "sfxgamempcontent.sfxprimp";
    public IEnumerable<StoreCard> Banners => Cards.Where(c => c.BannerID != null);

    public StoreValidationResult ValidateBanners(IEnumerable<int> existingEmblemIds, IReadOnlySet<string>? availableImages = null)
    {
        var errors = new List<string>();
        var existing = existingEmblemIds.ToHashSet();
        foreach (var duplicate in Banners.GroupBy(c => c.BannerID).Where(g => g.Count() > 1))
        {
            errors.Add($"Banner ID {duplicate.Key} is used by {string.Join(", ", duplicate.Select(c => c.UniqueName))}");
        }
        foreach (var card in Cards)
        {
            if (card.BannerID == null)
            {
                if (string.Equals(card.GUIType, "banner", StringComparison.OrdinalIgnoreCase))
                {
                    errors.Add($"Banner card {card.UniqueName} has no BannerID");
                }
                continue;
            }
            if (card.BannerID <= 0 || existing.Contains(card.BannerID.Value))
            {
                errors.Add($"Banner {card.UniqueName} has an invalid or already registered emblem ID {card.BannerID}");
            }
            if (!Regex.IsMatch(card.UniqueName, @"^[A-Za-z_][A-Za-z0-9_]*$"))
            {
                errors.Add($"Banner {card.UniqueName} needs a stable name containing only letters, digits and underscores");
            }
            if (!Enum.IsDefined(card.Rarity))
            {
                errors.Add($"Banner {card.UniqueName} has an invalid rarity");
            }
            if (card.Kind != ReinforcementKind.PermanentUpgrade || card.MaxCount != 1 || card.UseVersionIdx == true || card.VersionIdx is not (null or 0)
                || card.PlayerVariableIds.Count != 1 || card.PlayerVariableIds.Any(id => id < 0) || card.GUIType != "banner")
            {
                errors.Add($"Banner {card.UniqueName} must be an unversioned PermanentUpgrade with MaxCount=1, one ownership variable and GUIType=banner");
            }
            if (card.Pools.Any(p => p.MaxCount is not (null or 1) || p.PVIncrementBonus is not (null or 0) || p.VersionIdx is not (null or 0)))
            {
                errors.Add($"Banner {card.UniqueName} has a pool override that changes its one-time ownership");
            }
            if (availableImages != null && !availableImages.Contains(card.GUITextureRef))
            {
                errors.Add($"Banner {card.UniqueName} image {card.GUITextureRef} was not built or dynamically mapped");
            }
        }
        foreach (var pack in Packs.Where(p => p.BannerRewardID != null))
        {
            if (pack.UnlockInfo == null || pack.PerPlayerMax != 1 || pack.CreditCost != 0)
            {
                errors.Add($"Banner pack {pack.PackName} must be free, achievement gated and claimable once");
            }
            if (pack.Contents.Count != 1 || pack.Contents[0].Quantity != 1 || pack.Contents[0].Pools.Count != 1
                || pack.Contents[0].BackupPool != null)
            {
                errors.Add($"Banner pack {pack.PackName} must contain one slot, one card and one exclusive pool, with no fallback");
                continue;
            }
            var poolName = pack.Contents[0].Pools[0].Pool.Name;
            var members = Cards.Where(c => c.Pools.Any(p => string.Equals(p.Pool.Name, poolName, StringComparison.OrdinalIgnoreCase))).ToList();
            if (members.Count != 1 || members[0].BannerID != pack.BannerRewardID || members[0].Pools.Count != 1)
            {
                errors.Add($"Banner pack {pack.PackName} pool must contain only banner {pack.BannerRewardID}, exclusive to that pool");
            }
            if (Packs.Where(p => p != pack).Any(p => p.Contents.Any(s =>
                s.Pools.Any(pool => string.Equals(pool.Pool.Name, poolName, StringComparison.OrdinalIgnoreCase))
                || string.Equals(s.BackupPool?.Name, poolName, StringComparison.OrdinalIgnoreCase))))
            {
                errors.Add($"Banner pack {pack.PackName} pool is also referenced by another pack");
            }
        }
        return new StoreValidationResult(errors, []);
    }

    // Called at the same registration stage as the rest of the catalog, including intentionally unpooled banners.
    public void CommitBannerConfig(CoalesceAsset bioGame, CoalesceAsset bioEngine, CoalesceAsset bioUI,
        int bannerTypeStringRef, int bannerDescriptionStringRef, IReadOnlySet<string>? availableImages = null)
    {
        var emblems = bioGame.GetOrAddSection(BannerEmblemsSection);
        var result = ValidateBanners(ReadEmblemIds(emblems), availableImages);
        if (result.Errors.Count != 0)
        {
            throw new InvalidOperationException(string.Join("\n", result.Errors));
        }
        if (Banners.Any() && (bannerTypeStringRef <= 0 || bannerDescriptionStringRef <= 0))
        {
            throw new ArgumentException("Banner type and description need localized stringrefs");
        }

        var engine = bioEngine.GetOrAddSection("sfxgame.sfxengine");
        foreach (var card in Banners)
        {
            emblems.AddEntry(new CoalesceProperty("emblemlist", new CoalesceValue(
                $"(ID={card.BannerID},BackgroundResource=\"{card.GUITextureRef}\",srTitle={card.GUIName})", CoalesceParseAction.AddUnique)));
            engine.AddEntry(new CoalesceProperty("sfxuniqueids", new CoalesceValue(card.UniqueName, CoalesceParseAction.AddUnique)));
        }
        ReplaceArray(bioGame.GetOrAddSection(BannerRewardsSection), "storeunlocks", Banners.Select(c =>
            $"(EmblemID={c.BannerID},PlayerVariable={c.UniqueName})"));
        if (Banners.Any())
        {
            bioUI.GetOrAddSection("sfxgamempcontent.sfxgui_mpreinforcementsreveal").AddEntry(new CoalesceProperty("cardtypetextdata",
                new CoalesceValue($"(CardType=\"banner\",GUIDescription={bannerDescriptionStringRef},GUIType={bannerTypeStringRef})", CoalesceParseAction.AddUnique)));
        }
    }

    public static IEnumerable<int> ReadEmblemIds(CoalesceSection section)
    {
        if (!section.TryGetValue("emblemlist", out var entries))
        {
            yield break;
        }
        foreach (var entry in entries)
        {
            if (entry.ParseAction is CoalesceParseAction.Remove or CoalesceParseAction.RemoveProperty || entry.Value == null)
            {
                continue;
            }
            var match = Regex.Match(entry.Value, @"\bID\s*=\s*(\d+)", RegexOptions.IgnoreCase);
            if (match.Success)
            {
                yield return int.Parse(match.Groups[1].Value);
            }
        }
    }
}
