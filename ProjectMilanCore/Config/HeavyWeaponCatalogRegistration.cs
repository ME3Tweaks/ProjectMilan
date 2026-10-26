using LegendaryExplorerCore.Coalesced;

namespace ProjectMilanCore.Config;

/// <summary>Resolved once during registration; shared by UI and gameplay through generated config.</summary>
public sealed record HeavyWeaponCatalogEntry
{
    public required int Id { get; init; }
    public required string ClassPath { get; init; }
    public required int Name { get; init; }
    public required int ShortName { get; init; }
    public required int Description { get; init; }
    public required string Image { get; init; }
    public required string Icon { get; init; }
    public required string IconResource { get; init; }
    public required int IconIndex { get; init; }
    public int DisplayOrder { get; init; }
    public bool Hidden { get; init; }
    public bool NoWeapon { get; init; }
    public string Rarity { get; init; } = "common";
    public string UnlockVariable { get; init; } = "";
}

public static class HeavyWeaponCatalogRegistration
{
    public const string SectionName = "sfxgamecontent_milan.sfxmilanheavyweaponcatalog";

    // Validation code
    public static IReadOnlyList<HeavyWeaponCatalogEntry> ValidateAndOrder(IEnumerable<HeavyWeaponCatalogEntry> source)
    {
        var entries = source.ToList();
        if (entries.Count == 0 || entries.All(x => x.Id != 0))
            throw new InvalidOperationException("Heavy catalog requires the Cobra fallback (ID 0).");
        if (entries.Any(x => x.Id < 0 || x.Name <= 0 || x.ShortName <= 0 || x.Description <= 0
            || (!x.NoWeapon && (string.IsNullOrWhiteSpace(x.ClassPath) || string.IsNullOrWhiteSpace(x.Image)
                || string.IsNullOrWhiteSpace(x.Icon) || string.IsNullOrWhiteSpace(x.IconResource) || x.IconIndex <= 1))
            || (x.NoWeapon && (x.Id == 0 || x.Hidden || x.ClassPath != "" || x.Image != "" || x.Icon != "" || x.IconResource != "" || x.IconIndex != 0))))
            throw new InvalidOperationException("Heavy catalog entry has invalid identity or presentation data.");
        if (entries.Any(x => (x.NoWeapon || x.Id == 0) && x.UnlockVariable != ""))
            throw new InvalidOperationException("None and ordinary Cobra must remain available without a store unlock.");
        if (entries.Any(x => x.NoWeapon ? x.Rarity != "" : x.Rarity is not ("common" or "uncommon" or "rare" or "ultrarare")))
            throw new InvalidOperationException("Heavy catalog rarity must be common, uncommon, rare or ultrarare; None has no rarity.");
        if (entries.Count(x => x.NoWeapon) > 1 || entries.GroupBy(x => x.Id).Any(x => x.Count() != 1)
            || entries.Where(x => !x.NoWeapon).GroupBy(x => x.ClassPath, StringComparer.OrdinalIgnoreCase).Any(x => x.Count() != 1))
            throw new InvalidOperationException("Heavy catalog IDs and class paths must be unique, with at most one None choice.");
        return entries.OrderBy(x => x.DisplayOrder).ThenBy(x => x.Id).ToList();
    }

    private static string Quote(string value) => "\"" + value.Replace("\\", "\\\\").Replace("\"", "\\\"") + "\"";
    
    // Struct serializer
    public static string Serialize(HeavyWeaponCatalogEntry entry)
    {
        return $"(Id={entry.Id},ClassPath={Quote(entry.ClassPath)},DisplayName={entry.Name},ShortName={entry.ShortName},"
            + $"Description={entry.Description},Image={Quote(entry.Image)},Icon={Quote(entry.Icon)},IconResource={Quote(entry.IconResource)},IconIndex={entry.IconIndex},bHidden={entry.Hidden.ToString().ToUpperInvariant()},bNoWeapon={entry.NoWeapon.ToString().ToUpperInvariant()},Rarity={Quote(entry.Rarity)},UnlockVariable={Quote(entry.UnlockVariable)})";
    }

    // Registers into config bundle
    public static void Register(IEnumerable<HeavyWeaponCatalogEntry> source, int categoryLabel, int hiddenLabel)
    {
        var entries = ValidateAndOrder(source);
        var section = MilanPipelinesShared.ConfigBundle.GetAsset("BioGame").GetOrAddSection(SectionName);
        // Replace the complete generated array, including defaults, rather than accumulating stale entries
        section.Remove("weapons");
        section.AddEntry(new CoalesceProperty("weapons", entries.Select((entry, index) => new CoalesceValue(Serialize(entry), index == 0 ? CoalesceParseAction.New : CoalesceParseAction.AddUnique)).ToList()));
        section.AddEntry(new CoalesceProperty("categorylabel", new CoalesceValue(categoryLabel.ToString(), CoalesceParseAction.New)));
        section.AddEntry(new CoalesceProperty("hiddenlabel", new CoalesceValue(hiddenLabel.ToString(), CoalesceParseAction.New)));
    }
}
