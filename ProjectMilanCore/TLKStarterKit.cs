using LegendaryExplorerCore.Packages;
using ProjectMilanCore.Utility;

namespace ProjectMilanCore
{
    /// <summary>
    /// Mints the closing "starter kit" block every dynamically-built TLK range ends with: a description,
    /// the DLC's folder/human name, the language name, and a Male/Female pair sharing the single highest
    /// ID. Assigned entirely through MilanPipelinesShared.AssignTLK/AssignTLKGenderPair, so it participates
    /// in the normal incremental ID sequence like any other dynamically-assigned content.
    /// </summary>
    public static class TLKStarterKit
    {
        public static void AssignAndAppend(string dlcDescription, string dlcHumanName)
        {
            MilanPipelinesShared.AssignTLK(new() { [MELocalization.INT] = dlcDescription });
            MilanPipelinesShared.AssignTLK(new() { [MELocalization.INT] = dlcHumanName });
            MilanPipelinesShared.AssignTLK(LanguageNames());
            MilanPipelinesShared.AssignTLKGenderPair(
                new() { [MELocalization.INT] = "Male" },
                new() { [MELocalization.INT] = "Female" });
        }

        // Not a hand-authored translation - each locale's own file just names itself.
        private static LocalizedString LanguageNames()
        {
            var names = new LocalizedString();
            foreach (var l in Enum.GetValues<MELocalization>())
            {
                if (l != MELocalization.None)
                    names[l] = l.ToString();
            }
            return names;
        }
    }
}
