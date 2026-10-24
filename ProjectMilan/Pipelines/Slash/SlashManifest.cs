#nullable disable
using System.ComponentModel;
using System.Security.Cryptography;
using System.Text.Json;
using System.Text.Json.Serialization;

// The slash manifest format. Mod Manager reads and applies it (MilanSlashManifest.cs / MilanSlashApplier.cs there), so
// keep the two in sync.
namespace ProjectMilan.Pipelines.Slash
{
    [Localizable(false)]
    internal static class SlashFormat
    {
        public const string SlashManifestFileName = "slash.json";
        public const string SlashFolderName = "Slash";
        public const double SupportedSlashVersion = 0.3;

        /// <summary>
        /// Full path of a manifest-relative path. Throws if it'd escape the root.
        /// </summary>
        public static string Resolve(string root, string relativePath)
        {
            if (string.IsNullOrWhiteSpace(relativePath) || Path.IsPathRooted(relativePath))
                throw new Exception($"Invalid slash manifest path: '{relativePath}'");

            var fullRoot = Path.GetFullPath(root);
            var fullPath = Path.GetFullPath(Path.Combine(fullRoot, relativePath.Replace('\\', Path.DirectorySeparatorChar)));
            var rootWithSeparator = Path.EndsInDirectorySeparator(fullRoot) ? fullRoot : fullRoot + Path.DirectorySeparatorChar;
            if (!fullPath.StartsWith(rootWithSeparator, StringComparison.OrdinalIgnoreCase))
                throw new Exception($"Slash manifest path escapes its root: '{relativePath}'");
            return fullPath;
        }

        // Lowercase hex SHA-256, same as Mod Manager's MUtilities.CalculateHash
        public static string CalculateHash(string path, string algorithm = "sha256")
        {
            using var stream = File.OpenRead(path);
            return Convert.ToHexStringLower(SHA256.HashData(stream));
        }

        public static string CalculateHash(byte[] data, string algorithm = "sha256") => Convert.ToHexStringLower(SHA256.HashData(data));
    }

    /// <summary>
    /// The signed part of the manifest. Property order matters, it's what the signature is computed over.
    /// </summary>
    internal class MilanSlashSignableBody
    {
        [JsonPropertyName("milanslash")]
        public bool MilanSlash { get; set; }

        [JsonPropertyName("version")]
        public double Version { get; set; }

        /// <summary>
        /// Files to assemble from ranges of other files, such as TFCs built from the data of existing TFCs.
        /// </summary>
        [JsonPropertyName("builds")]
        public List<MilanSlashBuildEntry> Builds { get; set; } = new();

        /// <summary>
        /// Files to transform with a JPatch delta.
        /// </summary>
        [JsonPropertyName("patches")]
        public List<MilanSlashPatchEntry> Patches { get; set; } = new();

        /// <summary>
        /// Files to remove entirely once everything else has been built.
        /// </summary>
        [JsonPropertyName("deletions")]
        public List<MilanSlashDeletionEntry> Deletions { get; set; } = new();

        /// <summary>
        /// Size and hash of every file in the finished installation this manifest was generated from, recorded after
        /// everything the installer does (slash, TOC, bink bypass). Used to verify an end user's installation matches exactly.
        /// </summary>
        [JsonPropertyName("finalfiles")]
        public List<MilanSlashFinalFileEntry> FinalFiles { get; set; } = new();
    }

    /// <summary>
    /// How to 'slash' an installed game down to the data LMP actually uses. Lives at MilanDelta\slash.json. Game paths are
    /// relative to the game root, delta paths to the MilanDelta folder.
    /// </summary>
    internal class MilanSlashManifest : MilanSlashSignableBody
    {
        [JsonPropertyName("signature")]
        public string Signature { get; set; }

        /// <summary>
        /// Computes the signature over the signable body. The same serialization must be used when generating and verifying.
        /// </summary>
        public string ComputeSignature()
        {
            var bodyJson = JsonSerializer.Serialize<MilanSlashSignableBody>(this);
            return SlashFormat.CalculateHash(System.Text.Encoding.UTF8.GetBytes(bodyJson), @"sha256");
        }

        /// <summary>
        /// Signs the manifest and writes it to the given MilanDelta folder.
        /// </summary>
        public void Save(string milanDeltaFolder)
        {
            Signature = ComputeSignature();
            Directory.CreateDirectory(milanDeltaFolder);
            File.WriteAllText(Path.Combine(milanDeltaFolder, SlashFormat.SlashManifestFileName), JsonSerializer.Serialize(this, new JsonSerializerOptions { WriteIndented = true }));
        }
    }

    /// <summary>
    /// Describes a file that is assembled from byte ranges of other files - typically a TFC built by the TFC compactor out
    /// of the data of existing TFCs. Only offsets and lengths are shipped for data that exists in the user's game; anything
    /// that doesn't (such as a new TFC's GUID header) comes from a small payload file shipped in the MilanDelta folder.
    /// </summary>
    internal class MilanSlashBuildEntry
    {
        /// <summary>
        /// File to create, relative to the game root. May be a new file, or the same file as one of the sources.
        /// </summary>
        [JsonPropertyName("filename")]
        public string Filename { get; set; }

        /// <summary>
        /// Files that data is pulled from.
        /// </summary>
        [JsonPropertyName("sources")]
        public List<MilanSlashSourceFile> Sources { get; set; } = new();

        /// <summary>
        /// Ranges to copy, in output order.
        /// </summary>
        [JsonPropertyName("segments")]
        public List<MilanSlashSegment> Segments { get; set; } = new();

        [JsonPropertyName("destsize")]
        public long DestSize { get; set; }

        [JsonPropertyName("desthash")]
        public string DestHash { get; set; }
    }

    internal class MilanSlashSourceFile
    {
        /// <summary>
        /// Path of the file, relative to the game root, or to the MilanDelta folder if <see cref="Payload"/> is set.
        /// </summary>
        [JsonPropertyName("filename")]
        public string Filename { get; set; }

        /// <summary>
        /// If this is a payload file shipped in the MilanDelta folder rather than a file in the game.
        /// </summary>
        [JsonPropertyName("payload")]
        public bool Payload { get; set; }

        /// <summary>
        /// Expected size of the file on disk. Game files such as TFCs are too large to hash up front; the output hash
        /// catches bad data.
        /// </summary>
        [JsonPropertyName("size")]
        public long Size { get; set; }
    }

    /// <summary>
    /// A copy of <see cref="Length"/> bytes from <see cref="Offset"/> in source <see cref="SourceIndex"/>. Serialized as a
    /// compact [source, offset, length] array, as builds can have thousands of these.
    /// </summary>
    [JsonConverter(typeof(MilanSlashSegmentConverter))]
    internal readonly record struct MilanSlashSegment(int SourceIndex, long Offset, long Length);

    internal class MilanSlashSegmentConverter : JsonConverter<MilanSlashSegment>
    {
        public override MilanSlashSegment Read(ref Utf8JsonReader reader, Type typeToConvert, JsonSerializerOptions options)
        {
            if (reader.TokenType != JsonTokenType.StartArray)
                throw new JsonException(@"Expected [source, offset, length] array for a build segment");

            var values = new long[3];
            for (int i = 0; i < 3; i++)
            {
                if (!reader.Read() || reader.TokenType != JsonTokenType.Number)
                    throw new JsonException(@"Build segment must contain exactly 3 numbers");
                values[i] = reader.GetInt64();
            }

            if (!reader.Read() || reader.TokenType != JsonTokenType.EndArray)
                throw new JsonException(@"Build segment must contain exactly 3 numbers");

            return new MilanSlashSegment(checked((int)values[0]), values[1], values[2]);
        }

        public override void Write(Utf8JsonWriter writer, MilanSlashSegment value, JsonSerializerOptions options)
        {
            // Raw so indented output keeps each segment on a single line
            writer.WriteRawValue($@"[{value.SourceIndex},{value.Offset},{value.Length}]", skipInputValidation: true);
        }
    }

    internal static class MilanSlashPatchModes
    {
        /// <summary>
        /// The delta applies to the LEC-decompressed package data (the same convention as MilanDelta), and the result is
        /// re-saved through LEC.
        /// </summary>
        public const string Package = @"package";

        /// <summary>
        /// The delta applies to the file's bytes as-is. Used for uncompressed files, such as the 1.3GB RefShaderCache,
        /// so they can be patched file-to-file without loading them into memory.
        /// </summary>
        public const string Raw = @"raw";
    }

    internal class MilanSlashPatchEntry
    {
        [JsonPropertyName("comment")]
        public string Comment { get; set; }

        /// <summary>
        /// File to patch, relative to the game root. The patched result replaces it.
        /// </summary>
        [JsonPropertyName("filename")]
        public string Filename { get; set; }

        /// <summary>
        /// JPatch delta file, relative to the MilanDelta folder.
        /// </summary>
        [JsonPropertyName("delta")]
        public string Delta { get; set; }

        /// <summary>
        /// One of <see cref="MilanSlashPatchModes"/>.
        /// </summary>
        [JsonPropertyName("mode")]
        public string Mode { get; set; }

        /// <summary>
        /// For package mode, if the result should be saved compressed.
        /// </summary>
        [JsonPropertyName("compressed")]
        public bool Compressed { get; set; }

        /// <summary>
        /// Size of the file on disk before patching. Checked before anything is modified.
        /// </summary>
        [JsonPropertyName("sourcefilesize")]
        public long SourceFileSize { get; set; }

        /// <summary>
        /// SHA-256 of the file on disk before patching. Checked before anything is modified.
        /// </summary>
        [JsonPropertyName("sourcefilehash")]
        public string SourceFileHash { get; set; }

        /// <summary>
        /// Size of the data the delta is applied to (decompressed package data in package mode, the file in raw mode).
        /// </summary>
        [JsonPropertyName("sourcesize")]
        public long SourceSize { get; set; }

        [JsonPropertyName("sourcehash")]
        public string SourceHash { get; set; }

        /// <summary>
        /// Size of the data the delta produces.
        /// </summary>
        [JsonPropertyName("destsize")]
        public long DestSize { get; set; }

        [JsonPropertyName("desthash")]
        public string DestHash { get; set; }
    }

    /// <summary>
    /// A file to delete once everything else has been built, such as a TFC whose used data has all been moved into other
    /// TFCs, or one nothing references.
    /// </summary>
    internal class MilanSlashDeletionEntry
    {
        /// <summary>
        /// Why the file is deleted.
        /// </summary>
        [JsonPropertyName("comment")]
        public string Comment { get; set; }

        [JsonPropertyName("filename")]
        public string Filename { get; set; }

        [JsonPropertyName("size")]
        public long Size { get; set; }
    }

    internal class MilanSlashFinalFileEntry
    {
        /// <summary>
        /// Path relative to the game root.
        /// </summary>
        [JsonPropertyName("filename")]
        public string Filename { get; set; }

        [JsonPropertyName("size")]
        public long Size { get; set; }

        [JsonPropertyName("hash")]
        public string Hash { get; set; }
    }
}
