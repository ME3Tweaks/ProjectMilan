using System.Diagnostics;
using System.Text;
using LegendaryExplorerCore.Textures;
using LegendaryExplorerCore.Unreal.Classes;
using ProjectMilanCore;

namespace ProjectMilan.Pipelines.Texture
{
    /// <summary>
    /// Keeps the encoded mip chains that <see cref="Texture2D.Replace"/> generates while installing upscales and converting
    /// textures (mostly BC7, which is slow to encode), so running the texture pipeline again over unchanged sources does not
    /// encode them again. Hooked into Replace() through <see cref="TextureReplaceCallbacks"/>.
    ///
    /// The cache lives in Pipelines\Texture\EncodedCache. A file is looked up by the CRC of the exact pixels Replace() encodes
    /// from (after any of our own processing, like rebuilding a normal map's Z), plus everything else that decides the chain:
    /// size, formats, DXT1 alpha settings, mip filter options and <see cref="MipPipelineVersion"/>. So a changed upscale or a
    /// change in how we prepare it is simply a miss, and wiping the folder only costs time. Files no texture used in a full
    /// pass are deleted by <see cref="PruneUnused"/>.
    /// </summary>
    internal sealed class TextureEncodeCache : IDisposable
    {
        private const string LOG_CATEGORY = "MILAN-TextureEncodeCache";

        /// <summary>
        /// Bump this whenever how Replace() generates or encodes mips changes in a way the key does not describe (for example a
        /// different BC7 encoder or a fix in the downscale), so existing cache files are no longer used.
        /// </summary>
        public const int MipPipelineVersion = 1;

        /// <summary>Environment variable: set it to 1 to skip the cache entirely (nothing is read or written).</summary>
        public const string DisableEnvironmentVariable = "MILAN_NO_TEXTURE_ENCODE_CACHE";

        private const string FileExtension = ".mips";

        private static bool Disabled => Environment.GetEnvironmentVariable(DisableEnvironmentVariable) == "1";

        public static string CacheFolder => Path.Combine(MilanShared.PipelineRoot, "Texture", "EncodedCache");

        /// <summary>The hooks to pass to Replace(); null when the cache is disabled.</summary>
        public TextureReplaceCallbacks? Callbacks { get; }

        private readonly string cacheFolder = CacheFolder;
        private readonly Stopwatch clock = Stopwatch.StartNew();
        private readonly HashSet<string> usedFiles = new(StringComparer.OrdinalIgnoreCase);
        private int hits;
        private int misses;
        private int stored;

        public TextureEncodeCache()
        {
            if (!Disabled)
            {
                Callbacks = new TextureReplaceCallbacks
                {
                    TryGetEncodedMips = TryGet,
                    MipsEncoded = Store
                };
            }
        }

        private static uint GetOptionsFingerprint(TextureEncodeRequest request)
        {
            var options = request.MipOptions;
            var description = options == null
                ? $"default|{request.Dxt1HasAlpha}|{request.Dxt1Threshold}|v{MipPipelineVersion}"
                : $"{options.Filter}|{options.SharpenAmount:R}|{options.SharpenRadius:R}|{options.PadTransparentColor}|{request.Dxt1HasAlpha}|{request.Dxt1Threshold}|v{MipPipelineVersion}";
            return TextureCRC.Compute(Encoding.UTF8.GetBytes(description));
        }

        private static string GetFileName(EncodedMipCacheKey key) =>
            $"{key.SourceCrc:X8}_{key.Width}x{key.Height}_{key.Destination}_{key.Options:X8}{FileExtension}";

        private IReadOnlyList<EncodedMip>? TryGet(TextureEncodeRequest request)
        {
            try
            {
                var key = new EncodedMipCacheKey(TextureCRC.Compute(request.SourceData), request.Width, request.Height, request.SourceData.Length,
                    request.SourceFormat.ToString(), request.DestinationFormat, GetOptionsFingerprint(request));
                request.CallerState = key;

                var fileName = GetFileName(key);
                if (!EncodedMipCacheFile.TryRead(Path.Combine(cacheFolder, fileName), key, out var mips))
                {
                    misses++;
                    return null;
                }

                hits++;
                usedFiles.Add(fileName);
                return mips;
            }
            catch (Exception ex)
            {
                MilanLog.Warning($"Not using cached mips for {request.Export?.InstancedFullPath}: {ex.Message}", customPrefix: LOG_CATEGORY);
                misses++;
                return null;
            }
        }

        private void Store(TextureEncodeRequest request, IReadOnlyList<EncodedMip> mips)
        {
            if (request.CallerState is not EncodedMipCacheKey key)
                return;

            try
            {
                Directory.CreateDirectory(cacheFolder);
                var fileName = GetFileName(key);
                EncodedMipCacheFile.WriteAtomic(Path.Combine(cacheFolder, fileName), key, key.Destination, mips, request.Export?.InstancedFullPath);
                usedFiles.Add(fileName);
                stored++;
            }
            catch (Exception ex)
            {
                // A cache that cannot be written is only a missed speed up
                MilanLog.Warning($"Could not cache the mips of {request.Export?.InstancedFullPath}: {ex.Message}", customPrefix: LOG_CATEGORY);
            }
        }

        /// <summary>
        /// Deletes every cache file this instance neither read nor wrote. Call it only after a pass that visited every texture,
        /// so what is left over belongs to sources that changed or are gone.
        /// </summary>
        public void PruneUnused()
        {
            if (Callbacks == null || !Directory.Exists(cacheFolder))
                return;

            int deleted = 0;
            foreach (var file in Directory.EnumerateFiles(cacheFolder))
            {
                var name = Path.GetFileName(file);
                // Leftover temporary files from a write that was killed go too
                if (name.EndsWith(FileExtension, StringComparison.OrdinalIgnoreCase) && usedFiles.Contains(name))
                    continue;

                try
                {
                    File.Delete(file);
                    deleted++;
                }
                catch (Exception ex)
                {
                    MilanLog.Warning($"Could not delete stale cache file {file}: {ex.Message}", customPrefix: LOG_CATEGORY);
                }
            }

            if (deleted > 0)
                MilanLog.Information($"Deleted {deleted} unused files from the texture encode cache", customPrefix: LOG_CATEGORY);
        }

        /// <summary>Logs how many chains came from the cache and how many had to be encoded.</summary>
        public void Dispose()
        {
            if (Callbacks == null)
            {
                MilanLog.Information($"Texture encode cache disabled ({DisableEnvironmentVariable}=1)", customPrefix: LOG_CATEGORY);
                return;
            }

            if (hits + misses == 0)
                return;

            MilanLog.Information($"Texture mips: {hits} from the cache, {misses} encoded ({stored} cached for next time); " +
                $"took {clock.Elapsed.TotalSeconds:0.0} s", customPrefix: LOG_CATEGORY);
        }
    }
}
