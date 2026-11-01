using System.Text.RegularExpressions;
using LegendaryExplorerCore.Coalesced;

namespace ProjectMilanCore.Config.Store;

/// <summary>
/// Checks that store card image mappings can load a Texture2D from a shipped package.
/// </summary>
public static partial class StoreImageValidator
{
    public static IReadOnlyList<string> Validate(CoalesceAsset baseEngine, CoalesceAsset dlcEngine,
        CoalesceAsset game, Func<string, IReadOnlySet<string>?> loadPackageTextures)
    {
        var errors = new List<string>();
        var mappings = ReadArray(GetValues(baseEngine, "sfxgame.sfxengine", "dynamicloadmapping")
            .Concat(GetValues(dlcEngine, "sfxgame.sfxengine", "dynamicloadmapping")))
            .Select(value => (Object: Field(value, "ObjectName"), Package: Field(value, "SeekFreePackageName")))
            .Where(value => value.Object.Length > 0)
            .ToLookup(value => value.Object, value => value.Package, StringComparer.OrdinalIgnoreCase);
        var cards = ReadArray(GetValues(game, StoreCatalog.ManagerSection, "carddata"));
        if (cards.Count == 0)
        {
            errors.Add("Store image validation found no generated CardData entries.");
        }
        var packages = new Dictionary<string, IReadOnlySet<string>?>(StringComparer.OrdinalIgnoreCase);
        foreach (var group in cards.GroupBy(value => Field(value, "GUITextureRef"), StringComparer.OrdinalIgnoreCase))
        {
            var owners = string.Join(", ", group.Select(value => Field(value, "UniqueName")));
            var image = group.Key;
            if (string.IsNullOrWhiteSpace(image))
            {
                errors.Add($"Store card(s) {owners} have no GUITextureRef.");
                continue;
            }
            var targets = mappings[image].Distinct(StringComparer.OrdinalIgnoreCase).ToArray();
            if (targets.Length == 0 || targets.Any(string.IsNullOrWhiteSpace))
            {
                errors.Add($"Store image {image} ({owners}) has no valid seek-free package mapping.");
                continue;
            }
            // Some MP1/MP2 images have multiple legitimate mappings. Validate every
            // destination, so a good copy cannot mask a stale or missing one.
            foreach (var target in targets)
            {
                if (!packages.TryGetValue(target, out var textures))
                {
                    textures = loadPackageTextures(target);
                    packages.Add(target, textures);
                }
                if (textures == null)
                {
                    errors.Add($"Store image {image} ({owners}) maps to {target}.pcc, which is not shipped by LMP.");
                }
                else if (!textures.Contains(image))
                {
                    errors.Add($"Store image {image} ({owners}) is not a Texture2D export in its mapped package {target}.pcc.");
                }
            }
        }
        return errors;
    }

    private static IEnumerable<CoalesceValue> GetValues(CoalesceAsset asset, string section, string property)
    {
        return asset.Sections.TryGetValue(section, out var values) && values.TryGetValue(property, out var entries)
            ? entries : [];
    }

    // Apply the config array operations before examining the mappings. Adding a different
    // package for an existing ObjectName does not remove the old struct from the array.
    private static List<string> ReadArray(IEnumerable<CoalesceValue> entries)
    {
        var values = new List<string>();
        foreach (var entry in entries)
        {
            switch (entry.ParseAction)
            {
                case CoalesceParseAction.New:
                case CoalesceParseAction.RemoveProperty:
                    values.Clear();
                    break;
                case CoalesceParseAction.Remove:
                    values.RemoveAll(value => value == entry.Value);
                    break;
            }
            if (entry.Value != null && (entry.ParseAction is CoalesceParseAction.New or CoalesceParseAction.Add
                || entry.ParseAction == CoalesceParseAction.AddUnique && !values.Contains(entry.Value)))
            {
                values.Add(entry.Value);
            }
        }
        return values;
    }

    private static string Field(string value, string field)
    {
        foreach (Match match in StringFieldRegex().Matches(value))
        {
            if (match.Groups[1].Value.Equals(field, StringComparison.OrdinalIgnoreCase))
            {
                return match.Groups[2].Value;
            }
        }
        return "";
    }

    [GeneratedRegex("\\b(\\w+)\\s*=\\s*\"([^\"]*)\"")]
    private static partial Regex StringFieldRegex();
}
