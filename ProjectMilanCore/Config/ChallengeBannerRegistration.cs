using LegendaryExplorerCore.Coalesced;
using ProjectMilanCore;

namespace ProjectMilanCore.Config
{
    /// <summary>
    /// Writes a challenge banner registration (SFXPRIMP EmblemList) into whichever
    /// <see cref="MilanPipelinesShared.ConfigBundle"/> is currently active - mirrors
    /// <see cref="DifficultyRegistration"/>. The vanilla banners stay as static XML
    /// (MergedConfig\BioGame.xml's emblemlist) - this only appends new ones.
    /// </summary>
    public static class ChallengeBannerRegistration
    {
        public static void RegisterChallengeBanner(ChallengeBannerEntry entry)
        {
            var game = MilanPipelinesShared.ConfigBundle.GetAsset("BioGame");
            var primp = game.GetOrAddSection("sfxgamempcontent.sfxprimp");
            primp.AddEntry(new CoalesceProperty("emblemlist", new CoalesceValue(BuildEntry(entry), CoalesceParseAction.AddUnique)));
        }

        private static string BuildEntry(ChallengeBannerEntry entry)
        {
            return $"(ID={entry.ID}, " +
                   $"BackgroundResource=\"{entry.BackgroundResource}\", " +
                   $"srTitle={entry.TitleStrRefId})";
        }
    }
}
