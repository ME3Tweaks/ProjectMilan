using LegendaryExplorerCore.Packages;
using System;
using System.Collections.Generic;
using System.Text;

namespace ProjectMilanCore.Utility
{
    /// <summary>
    /// String container that supports getting text with INT fallback
    /// </summary>
    public class LocalizedString : Dictionary<MELocalization, string>
    {
        public string GetText(MELocalization language)
        {
            if (TryGetValue(language, out var text) && !string.IsNullOrWhiteSpace(text))
            {
                // Return text for lang
                return text;
            }
            if (TryGetValue(MELocalization.INT, out var english))
            {
                // Return INT as fallback
                return english ?? string.Empty;
            }
            if (Count == 0)
            {
                // Empty string
                return string.Empty;
            }
            throw new InvalidOperationException("LocalizedString requires INT text when a translation is missing.");
        }

        /// <summary>
        /// Joins two localized strings together
        /// </summary>
        public static LocalizedString Join(LocalizedString first, string separator, LocalizedString second)
        {
            var result = new LocalizedString();
            foreach (var language in Enum.GetValues<MELocalization>())
            {
                result[language] = first.GetText(language) + separator + second.GetText(language);
            }
            return result;
        }
    }
}
