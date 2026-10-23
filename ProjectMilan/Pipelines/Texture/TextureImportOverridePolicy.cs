using System.Text.Json;
using LegendaryExplorerCore.Textures;

namespace ProjectMilan.Pipelines.Texture
{
    /// <summary>
    /// Exact, case-insensitive object-path opt-ins. No inference from names or texture formats
    /// </summary>
    internal sealed class TextureImportOverridePolicy
    {
        private readonly Dictionary<string, TextureLoadOverrides> entries;

        private TextureImportOverridePolicy(Dictionary<string, TextureLoadOverrides> entries)
        {
            this.entries = entries;
        }

        public TextureLoadOverrides GetOverrides(string objectPath) => entries.GetValueOrDefault(objectPath);

        public static TextureImportOverridePolicy Load(string path) => Parse(File.ReadAllText(path));

        internal static TextureImportOverridePolicy Parse(string json)
        {
            using var document = JsonDocument.Parse(json);
            if (document.RootElement.ValueKind != JsonValueKind.Object)
            {
                throw new InvalidDataException("Texture import overrides must be an object keyed by exact texture paths.");
            }
            var entries = new Dictionary<string, TextureLoadOverrides>(StringComparer.OrdinalIgnoreCase);
            foreach (var entry in document.RootElement.EnumerateObject())
            {
                if (string.IsNullOrWhiteSpace(entry.Name) || entry.Name.Contains('*') || entry.Name.Contains('?') || entry.Value.ValueKind != JsonValueKind.Array)
                {
                    throw new InvalidDataException($"Invalid texture import override entry: {entry.Name}. Use an exact object path and an array of named overrides.");
                }
                var flags = TextureLoadOverrides.None;
                foreach (var option in entry.Value.EnumerateArray())
                {
                    if (option.ValueKind != JsonValueKind.String || option.GetString() != nameof(TextureLoadOverrides.PreserveAllZeroTgaAlpha))
                    {
                        throw new InvalidDataException($"Unknown texture import override for {entry.Name}: {option}.");
                    }
                    flags |= TextureLoadOverrides.PreserveAllZeroTgaAlpha;
                }
                if (!entries.TryAdd(entry.Name, flags))
                {
                    throw new InvalidDataException($"Duplicate texture import override path: {entry.Name}.");
                }
            }
            return new TextureImportOverridePolicy(entries);
        }
    }
}
