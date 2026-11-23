using LegendaryExplorerCore.Coalesced;
using ProjectMilan.Pipelines.Store;
using ProjectMilanCore;
using ProjectMilanCore.Config;
using ProjectMilanCore.Config.Store;

namespace ProjectMilan.Pipelines.Gear;

/// <summary>
/// Adds gear to the store, registering different data types to allow it to work.
/// </summary>
internal static class GearStoreRegistration
{
    /// <summary>
    /// StoreCard.GUIType of every gear card
    /// </summary>
    private const string CardType = "gearUpgrade";

    /// <summary>
    /// Adds new gear to the store catalog.
    /// </summary>
    /// <param name="catalog"></param>
    /// <exception cref="InvalidOperationException"></exception>
    internal static void Configure(StoreCatalog catalog)
    {
        GearPipeline.ValidateEntries();
        var loadable = StoreRegistration.GetDynamicLoadObjects();
        var engine = MilanPipelinesShared.ConfigBundle.GetAsset("BioEngine").GetOrAddSection("sfxgame.sfxengine");
        
        // New gear is set in GearPipeline.Gear
        foreach (var entry in GearPipeline.Gear)
        {
            if (!loadable.Contains(entry.Image))
            {
                // Not set up correctly...
                throw new InvalidOperationException($"Gear {entry.ClassPath}'s image {entry.Image} isn't dynamic load mapped");
            }

            // Gear is replicated (the effect isn't). Replicated strings go through sfxuniqueids
            // so we put class path there
            engine.AddEntry(new CoalesceProperty("sfxuniqueids", new CoalesceValue(entry.ClassPath, CoalesceParseAction.AddUnique)));

            // Gear is dynamic load mapped so we must register it
            DynamicLoadMappingRegistration.RegisterDynamicLoadMapping(entry.ClassPath, GearPipeline.PackageName);

            // Register the new card
            catalog.Cards.Add(new StoreCard
            {
                UniqueName = entry.ClassPath,
                Kind = ReinforcementKind.MatchConsumableGear,
                Rarity = entry.Rarity,
                MaxCount = 5,
                UseVersionIdx = false,
                VersionIdx = 0,
                Category = 4,
                GUIName = MilanPipelinesShared.AssignTLK(entry.Name),
                GUIDescription = MilanPipelinesShared.AssignTLK(entry.Description),
                GUICategory = CardGUICategory.MatchConsumableGear,
                GUIType = CardType,
                GUITextureRef = entry.Image,
                PlayerVariableIds = [(int)entry.PlayerVariable],
                Pools = [new(entry.Pool) { VersionIdx = 0, Tokens = entry.Tokens }],
            });
        }
    }
}
