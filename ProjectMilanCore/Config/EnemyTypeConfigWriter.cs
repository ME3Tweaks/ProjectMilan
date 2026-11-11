using LegendaryExplorerCore.Coalesced;

namespace ProjectMilanCore.Config
{
    /// <summary>
    /// Writes a multiplayer faction's selection and optional reward bonuses into whichever
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

            // 11/11/2026 - Write out the faction bonuses structs
            if (entry.XPBonus != 0f || entry.CreditBonus != 0f)
            {
                var scoreManager = game.GetOrAddSection("sfxgame.sfxscoremanager");
                var bonus = FormattableString.Invariant($"(ID={entry.ID},XPBonus={entry.XPBonus}f,CreditBonus={entry.CreditBonus}f)");
                scoreManager.AddEntry(new CoalesceProperty("factionbonuses", new CoalesceValue(bonus, CoalesceParseAction.AddUnique)));
            }
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
