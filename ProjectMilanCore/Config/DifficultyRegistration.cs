using LegendaryExplorerCore.Coalesced;
using ProjectMilanCore;

namespace ProjectMilanCore.Config
{
    /// <summary>
    /// Writes a multiplayer difficulty option registration into whichever
    /// <see cref="MilanPipelinesShared.ConfigBundle"/> is currently active - mirrors
    /// <see cref="EnemyTypeConfigWriter"/>. Bronze/Silver/Gold/Platinum are original, unchanging ME3-ported
    /// values and stay as static XML (MergedConfig\BioGame.xml's challengetypes) - this only appends new
    /// difficulty options on top of that list.
    /// </summary>
    public static class DifficultyRegistration
    {
        public static void RegisterDifficulty(DifficultyEntry entry)
        {
            var game = MilanPipelinesShared.ConfigBundle.GetAsset("BioGame");
            var onlinegamesettings = game.GetOrAddSection("sfxonlinefoundation.sfxonlinegamesettings");
            onlinegamesettings.AddEntry(new CoalesceProperty("challengetypes", new CoalesceValue(BuildEntry(entry), CoalesceParseAction.AddUnique)));
        }

        private static string BuildEntry(DifficultyEntry entry)
        {
            return $"(ID={entry.ID}, " +
                   $"Name={entry.NameStrRefId}, " +
                   $"AllCapsName={entry.AllCapsNameStrRefId}, " +
                   $"Image=\"{entry.Image}\")";
        }
    }
}
