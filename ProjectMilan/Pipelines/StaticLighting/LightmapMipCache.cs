using System.Diagnostics;
using System.Text;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Textures;
using LegendaryExplorerCore.UDK;
using LegendaryExplorerCore.Unreal.Classes;
using ProjectMilan.Utility;

namespace ProjectMilan.Pipelines.StaticLighting
{
    /// <summary>
    /// Keeps the encoded (BC7) mip chains of imported lightmaps on disk, so importing the same bake again does not encode
    /// them again. Encoding is the slow part of a static lighting import.
    ///
    /// The cache lives in a BC7Cache folder beside the baked .udk files it was made from
    /// (StaticLighting\Levels\&lt;UE3|UE4&gt;\&lt;BioP&gt;\BC7Cache), found from the folder the import reads those .udk files from,
    /// so a UE3 bake and a UE4 bake each have their own. One file holds one texture's whole chain.
    ///
    /// A file is looked up by the CRC (the one Milan uses to match textures) of the baked top mip, plus everything else that
    /// decides what the chain looks like: the size, the formats, <see cref="MipPipelineVersion"/> and the mip filter options. So
    /// a cache can never give a texture the chain of a different bake, and wiping it only saves disk space. Anything wrong
    /// with a file (missing, cut short, different key, bad checksum) is a miss and the mips are generated as usual. A new
    /// successful bake clears the folder after its maps were copied back (see <see cref="Clear"/>).
    /// </summary>
    internal sealed class LightmapMipCache : IDisposable
    {
        private const string LOG_CATEGORY = "MILAN-LightmapMipCache";

        /// <summary>The folder inside a level's bake folder that holds the cache.</summary>
        public const string CacheFolderName = "BC7Cache";

        /// <summary>
        /// Bump this whenever how a lightmap's mips are generated or encoded changes in a way the options do not describe (for
        /// example a fix in the downscale or a different BC7 encoder), so existing cache files are no longer used.
        /// </summary>
        public const int MipPipelineVersion = 1;

        /// <summary>Environment variable: set it to 1 to skip the cache entirely (nothing is read or written).</summary>
        public const string DisableEnvironmentVariable = "MILAN_NO_LIGHTMAP_MIP_CACHE";

        /// <summary>Environment variable: Box or Lanczos3 to override <see cref="DefaultMipFilter"/>, for comparing the two in game.</summary>
        public const string MipFilterEnvironmentVariable = "MILAN_LIGHTMAP_MIP_FILTER";

        /// <summary>
        /// How lightmap mips are filtered. A UDK lightmap's alpha only says whether a texel was baked, and the empty parts of an
        /// atlas are black; Lanczos-3 weights colour by alpha, where a box filter averages that black into the edge of every chart.
        /// </summary>
        public const MipFilter DefaultMipFilter = MipFilter.Lanczos3;

        private const uint FileMagic = 0x3743424D; // "MBC7"
        private const int FileVersion = 1;
        private const int MaxMips = 16;

        public static MipGenerationOptions MipOptions
        {
            get
            {
                var filter = Enum.TryParse<MipFilter>(Environment.GetEnvironmentVariable(MipFilterEnvironmentVariable), true, out var overridden)
                    ? overridden
                    : DefaultMipFilter;
                return new MipGenerationOptions { Filter = filter };
            }
        }

        private static bool Disabled => Environment.GetEnvironmentVariable(DisableEnvironmentVariable) == "1";

        public static string GetCacheFolder(string levelFolder) => Path.Combine(levelFolder, CacheFolderName);

        /// <summary>
        /// Deletes the cache of a level's bake folder. Call it only once a new bake is safely in place, so a bake that fails
        /// leaves the cache that goes with the previous one.
        /// </summary>
        public static void Clear(string levelFolder)
        {
            var folder = GetCacheFolder(levelFolder);
            if (Directory.Exists(folder))
            {
                MilanLog.Information($"Clearing the lightmap mip cache {folder}", customPrefix: LOG_CATEGORY);
                Utilities.DeleteFilesAndFoldersRecursively(folder, quiet: true);
            }
        }

        /// <summary>
        /// Empties a level's bake folder like a plain recursive delete would, except for the cache, which <see cref="Clear"/> removes
        /// once the new bake has been copied in.
        /// </summary>
        public static void DeleteBakeKeepingCache(string levelFolder)
        {
            if (!Directory.Exists(levelFolder))
                return;

            foreach (var file in Directory.GetFiles(levelFolder))
            {
                File.SetAttributes(file, FileAttributes.Normal);
                File.Delete(file);
            }

            foreach (var directory in Directory.GetDirectories(levelFolder))
            {
                if (!string.Equals(Path.GetFileName(directory), CacheFolderName, StringComparison.OrdinalIgnoreCase))
                    Utilities.DeleteFilesAndFoldersRecursively(directory, throwOnFailed: true, quiet: true);
            }
        }

        /// <summary>
        /// Sets up <paramref name="setup"/> to use the cache beside the maps it imports (UDKMapsBasePath), and to filter lightmap
        /// mips with <see cref="MipOptions"/>. Dispose the result after the import to log how the cache did.
        /// </summary>
        public static LightmapMipCache Attach(LightingImportSetup setup, string logName)
        {
            setup.LightmapMipOptions = MipOptions;
            var cache = new LightmapMipCache(GetCacheFolder(setup.UDKMapsBasePath), setup.LightmapMipOptions, logName);
            if (!Disabled)
            {
                setup.TryUsePrecomputedLightmapMips = cache.TryUse;
                setup.LightmapMipsGenerated = cache.Store;
            }

            return cache;
        }

        private readonly string cacheFolder;
        private readonly uint optionsFingerprint;
        private readonly string logName;
        private readonly Stopwatch clock = Stopwatch.StartNew();
        private readonly Dictionary<ExportEntry, Key> pending = new();
        private int hits;
        private int misses;
        private int stored;

        private LightmapMipCache(string cacheFolder, MipGenerationOptions options, string logName)
        {
            this.cacheFolder = cacheFolder;
            this.logName = logName;
            var description = $"{options.Filter}|{options.SharpenAmount:R}|{options.SharpenRadius:R}|{options.PadTransparentColor}|v{MipPipelineVersion}";
            optionsFingerprint = LegendaryExplorerCore.Textures.TextureCRC.Compute(Encoding.UTF8.GetBytes(description));
        }

        private readonly record struct Key(uint SourceCrc, int Width, int Height, int SourceLength, string SourceFormat, PixelFormat Destination, uint Options)
        {
            public string FileName => $"{SourceCrc:X8}_{Width}x{Height}_{Options:X8}.bc7mips";
        }

        /// <summary>Called before a ported lightmap gets its mips: installs the cached chain, or remembers the key for <see cref="Store"/>.</summary>
        private bool TryUse(ExportEntry export)
        {
            try
            {
                var texture = new Texture2D(export);
                var top = texture.GetTopMip();
                if (top == null)
                    return false;

                var key = new Key(Texture2D.GetMipCRC(top, texture.TextureFormat), top.width, top.height, top.uncompressedSize,
                    texture.TextureFormat, export.Game.IsLEGame() ? PixelFormat.BC7 : PixelFormat.DXT1, optionsFingerprint);
                lock (pending)
                {
                    pending[export] = key;
                }

                if (!TryRead(Path.Combine(cacheFolder, key.FileName), key, out var mips))
                {
                    Interlocked.Increment(ref misses);
                    return false;
                }

                texture.ReplaceWithEncodedMips(key.Destination, mips);
                Interlocked.Increment(ref hits);
                lock (pending)
                {
                    pending.Remove(export);
                }

                return true;
            }
            catch (Exception ex)
            {
                // The export is untouched when this throws (ReplaceWithEncodedMips checks before it writes), so mips are generated as usual
                MilanLog.Warning($"Not using cached mips for {export.InstancedFullPath}: {ex.Message}", customPrefix: LOG_CATEGORY);
                Interlocked.Increment(ref misses);
                return false;
            }
        }

        /// <summary>Called after a ported lightmap got its mips generated: keeps the chain for the next import.</summary>
        private void Store(ExportEntry export)
        {
            Key key;
            lock (pending)
            {
                if (!pending.Remove(export, out key))
                    return;
            }

            try
            {
                if (!new Texture2D(export).TryGetEncodedMips(out var format, out var mips) || format != key.Destination)
                    return;

                Directory.CreateDirectory(cacheFolder);
                var path = Path.Combine(cacheFolder, key.FileName);
                var temporary = $"{path}.{Guid.NewGuid():N}.tmp";
                try
                {
                    Write(temporary, key, format, mips);
                    File.Move(temporary, path, overwrite: true);
                    Interlocked.Increment(ref stored);
                }
                finally
                {
                    if (File.Exists(temporary))
                        File.Delete(temporary);
                }
            }
            catch (Exception ex)
            {
                // A cache that cannot be written is only a missed speed up
                MilanLog.Warning($"Could not cache the mips of {export.InstancedFullPath}: {ex.Message}", customPrefix: LOG_CATEGORY);
            }
        }

        private static void Write(string path, Key key, PixelFormat format, List<EncodedMip> mips)
        {
            var payload = new byte[mips.Sum(m => m.Data.Length)];
            int at = 0;
            foreach (var mip in mips)
            {
                mip.Data.CopyTo(payload, at);
                at += mip.Data.Length;
            }

            using var stream = new FileStream(path, FileMode.Create, FileAccess.Write, FileShare.None);
            using var writer = new BinaryWriter(stream, Encoding.UTF8);
            writer.Write(FileMagic);
            writer.Write(FileVersion);
            writer.Write((int)format);
            writer.Write(key.SourceCrc);
            writer.Write(key.Width);
            writer.Write(key.Height);
            writer.Write(key.SourceLength);
            writer.Write(key.SourceFormat);
            writer.Write(key.Options);
            writer.Write(Program.Lightmass.ToString()); // for whoever looks at the file; not part of the key
            writer.Write(mips.Count);
            foreach (var mip in mips)
            {
                writer.Write(mip.Width);
                writer.Write(mip.Height);
                writer.Write(mip.Data.Length);
            }

            writer.Write(TextureCRC.Compute(payload));
            writer.Write(payload);
        }

        private static bool TryRead(string path, Key key, out List<EncodedMip> mips)
        {
            mips = null!;
            if (!File.Exists(path))
                return false;

            try
            {
                using var stream = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.Read);
                using var reader = new BinaryReader(stream, Encoding.UTF8);
                if (reader.ReadUInt32() != FileMagic || reader.ReadInt32() != FileVersion)
                    return false;

                var format = (PixelFormat)reader.ReadInt32();
                if (format != key.Destination
                    || reader.ReadUInt32() != key.SourceCrc
                    || reader.ReadInt32() != key.Width
                    || reader.ReadInt32() != key.Height
                    || reader.ReadInt32() != key.SourceLength
                    || reader.ReadString() != key.SourceFormat
                    || reader.ReadUInt32() != key.Options)
                    return false;

                reader.ReadString(); // the Lightmass it was made for
                int count = reader.ReadInt32();
                if (count is < 2 or > MaxMips)
                    return false;

                var sizes = new (int Width, int Height, int Length)[count];
                long total = 0;
                for (int i = 0; i < count; i++)
                {
                    sizes[i] = (reader.ReadInt32(), reader.ReadInt32(), reader.ReadInt32());
                    if (sizes[i].Width < 1 || sizes[i].Height < 1 || sizes[i].Length < 1)
                        return false;
                    total += sizes[i].Length;
                }

                uint expectedCrc = reader.ReadUInt32();
                if (total > int.MaxValue || stream.Length - stream.Position != total)
                    return false;

                var payload = reader.ReadBytes((int)total);
                if (payload.Length != total || TextureCRC.Compute(payload) != expectedCrc)
                    return false;

                var result = new List<EncodedMip>(count);
                int at = 0;
                foreach (var (width, height, length) in sizes)
                {
                    result.Add(new EncodedMip(width, height, payload.AsSpan(at, length).ToArray()));
                    at += length;
                }

                mips = result;
                return true;
            }
            catch (Exception ex) when (ex is IOException or EndOfStreamException or InvalidDataException or ArgumentException)
            {
                return false;
            }
        }

        /// <summary>Logs how many lightmaps came from the cache and how many had to be encoded.</summary>
        public void Dispose()
        {
            int total = hits + misses;
            if (total == 0)
                return;

            MilanLog.Information($"{logName}: lightmap mips: {hits} from the cache, {misses} generated ({stored} cached for next time); " +
                $"the import took {clock.Elapsed.TotalSeconds:0.0} s ({MipOptions.Filter} filter{(Disabled ? ", cache disabled" : "")})", customPrefix: LOG_CATEGORY);
        }
    }
}
