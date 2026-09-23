using LegendaryExplorerCore.Coalesced;
using ProjectMilanCore;

namespace ProjectMilanCore.Config
{
    /// <summary>
    /// Writes a multiplayer faction's "enemytypes" registration into whichever
    /// <see cref="MilanPipelinesShared.ConfigBundle"/> is currently active - mirrors
    /// <see cref="MapListConfigWriter"/>.
    /// </summary>
    public static class EnemyTypeConfigWriter
    {
        public static void RegisterEnemyType(EnemyTypeEntry entry)
        {
            var game = MilanPipelinesShared.ConfigBundle.GetAsset("BioGame");
            var onlinegamesettings = game.GetOrAddSection("sfxonlinefoundation.sfxonlinegamesettings");
            onlinegamesettings.AddEntry(new CoalesceProperty("enemytypes", new CoalesceValue(BuildEntry(entry), CoalesceParseAction.AddUnique)));
        }

        private static string BuildEntry(EnemyTypeEntry entry)
        {
            var randomOption = entry.IsRandomOption ? "True" : "False";
            return $"(ID={entry.ID}, " +
                   $"Name={entry.NameStrRefId}, " +
                   $"AllCapsName={entry.AllCapsNameStrRefId}, " +
                   $"Image=\"{entry.Image}\", " +
                   $"WaveClass=\"{entry.WaveClass}\", " +
                   $"IsRandomOption=\"{randomOption}\")";
            
        }
    }
}
