using LegendaryExplorerCore.TLK;

namespace ProjectMilan.Pipelines.TLK;

internal static class TLKFallback
{
    public static (int AddedIds, int FilledEntries, int RemovedPlaceholders) Apply(IReadOnlyCollection<TLKStringRef> english, List<TLKStringRef> localized, string language)
    {
        var englishById = english.GroupBy(entry => entry.StringID).ToDictionary(group => group.Key, group => group.ToArray());
        var localizedById = localized.GroupBy(entry => entry.StringID).ToDictionary(group => group.Key, group => group.ToArray());
        int removedPlaceholders = 0;

        // Find missing translations
        foreach (var id in localizedById.Keys.Except(englishById.Keys).ToArray())
        {
            var entries = localizedById[id];
            if (id < 0 && entries.All(entry => entry.Data == null) && englishById.ContainsKey(entries[0].CalculatedID))
            {
                removedPlaceholders += localized.RemoveAll(entry => entry.StringID == id);
                localizedById.Remove(id);
            }
        }

        var extraIds = localizedById.Keys.Except(englishById.Keys).Order().ToArray();
        if (extraIds.Length != 0)
        {
            throw new InvalidDataException($"TLK {language} has {extraIds.Length} IDs absent from INT: " +
                string.Join(", ", extraIds.Take(10)));
        }

        int addedIds = 0;
        int filledEntries = 0;
        foreach (var (id, englishEntries) in englishById)
        {
            if (!localizedById.TryGetValue(id, out var localizedEntries))
            {
                // Preserve male/female ordering
                foreach (var entry in englishEntries)
                {
                    localized.Add(new TLKStringRef(id, entry.Data));
                }
                addedIds++;
                continue;
            }

            for (int i = 0; i < localizedEntries.Length; i++)
            {
                var fallback = englishEntries[Math.Min(i, englishEntries.Length - 1)].Data;
                if (localizedEntries[i].Data == null && fallback != null)
                {
                    localizedEntries[i].Data = fallback;
                    filledEntries++;
                }
            }
        }

        return (addedIds, filledEntries, removedPlaceholders);
    }
}
