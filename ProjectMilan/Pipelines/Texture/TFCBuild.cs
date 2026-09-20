using System.Text.RegularExpressions;
using LegendaryExplorerCore.GameFilesystem;
using LegendaryExplorerCore.Helpers;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Shaders;
using LegendaryExplorerCore.Textures;
using LegendaryExplorerCore.Unreal;
using LegendaryExplorerCore.Unreal.BinaryConverters;
using LegendaryExplorerCore.Unreal.Classes;
using LegendaryExplorerCore.Unreal.ObjectInfo;
using ProjectMilanCore;
using Image = LegendaryExplorerCore.Textures.Image;

namespace ProjectMilan.Pipelines.Texture
{
    /// <summary>
    /// Pipeline for extracting audio from ME3 and porting it to LE3 WwiseBanks
    /// </summary>
    internal class TFCBuild
    {
        private const string LOG_CATEGORY = @"MILAN-Texture";
        // Expected pipeline:
        // 1. Go through ME3 package files and find all used Texture2Ds that are not in LE (using object database?). Hopefully things did not get renamed.
        // 2. Make LE3 package file that will be the 'host' for all textures during build (LE1R/LE2R uses this and it works well) - called TFCPackage
        // 3. Stub out all texture exports that will be ported into TFCPackage
        // 4. Extract and port textures - substituting from other sources, such as ALOT, if possible, since these textures will look worse than LE
        //        -> During this step it will build the TFC
        // 5. Run a pass over the compiled DLC and replace all stubbed textures with versions from TFCPackage.
        // This pipeline must be run after level and kit compiler

        public static void RunPipeline()
        {
            InternalRunPipeline();
        }

        private static void InternalRunPipeline()
        {
            InventoryUpscales();
            UpdateTextures();

            // Bring over all textures to TFC
            MoveNonLightingTexturesToExternalTFC(MilanShared.DLC_NAME); // Non-lighting
            MilanShared.MoveTexturesToTFC(@"Lighting", MilanShared.DLC_NAME, true, @"MILAN-TFC"); // Lighting
        }

        #region Upscales

        /// <summary>
        /// Trailing "_0x1a2b3c4d" on a sync folder filename - the source texture's CRC, which is not part of the memory path.
        /// </summary>
        private static readonly Regex CrcSuffixRegex = new(@"_0x[0-9A-Fa-f]{8}$", RegexOptions.Compiled);

        /// <summary>
        /// Extensions we know how to read dimensions out of and hand to <see cref="Image.LoadFromFile"/>.
        /// </summary>
        private static readonly string[] SupportedUpscaleExtensions = [".tga", ".dds", ".png"];

        private record UpscaleSource(string FilePath, int Width, int Height);

        /// <summary>
        /// Memory-path-shaped key (see <see cref="GetUpscaleKey"/>) to the best available upscale for that texture.
        /// </summary>
        private static Dictionary<string, UpscaleSource> upscaleMap = new(StringComparer.OrdinalIgnoreCase);

        /// <summary>
        /// Indexes the texture sync folder. Layout is &lt;PackageName&gt;\&lt;RestOfMemoryPath&gt;_0x&lt;CRC&gt;.[tga|dds|png], so the key is
        /// the relative path with the CRC suffix and extension removed - which is the instanced full path with its first '.'
        /// turned into a directory separator. Produced by TextureResearch.FindUniqueLMPTextures.
        /// </summary>
        private static void InventoryUpscales()
        {
            upscaleMap = new Dictionary<string, UpscaleSource>(StringComparer.OrdinalIgnoreCase);

            if (!Program.Settings.RunUpscalePipeline)
            {
                MilanLog.Information(@"RunUpscalePipeline is off - not installing texture upscales", customPrefix: LOG_CATEGORY);
                return;
            }

            var syncFolder = Program.Settings.TextureSyncFolder;
            if (string.IsNullOrWhiteSpace(syncFolder))
            {
                MilanLog.Warning(@"TextureSyncFolder is not set in your settings - not installing texture upscales. Set it to your copy of the shared 'Extracted' texture workspace.", customPrefix: LOG_CATEGORY);
                return;
            }

            if (!Directory.Exists(syncFolder))
            {
                MilanLog.Error($"TextureSyncFolder does not exist: {syncFolder} - not installing texture upscales.", customPrefix: LOG_CATEGORY);
                return;
            }

            foreach (var file in Directory.EnumerateFiles(syncFolder, "*", SearchOption.AllDirectories))
            {
                if (!SupportedUpscaleExtensions.Contains(Path.GetExtension(file), StringComparer.OrdinalIgnoreCase))
                    continue;

                var relative = Path.GetRelativePath(syncFolder, file);
                var withoutExtension = Path.ChangeExtension(relative, null);
                if (!CrcSuffixRegex.IsMatch(withoutExtension))
                {
                    // Everything in here is produced by TextureResearch, which always appends the CRC. Something else got dropped in.
                    MilanLog.Warning($"  Skipping sync file with no _0x<CRC> suffix: {relative}", customPrefix: LOG_CATEGORY);
                    continue;
                }

                var key = CrcSuffixRegex.Replace(withoutExtension, "");

                if (!TryGetImageDimensions(file, out var width, out var height))
                {
                    MilanLog.Warning($"  Could not read image dimensions, skipping: {relative}", customPrefix: LOG_CATEGORY);
                    continue;
                }

                // The same texture can have several candidates (e.g. an old .tga left alongside a newer .png). Biggest wins.
                if (upscaleMap.TryGetValue(key, out var existing) && (long)existing.Width * existing.Height >= (long)width * height)
                    continue;

                upscaleMap[key] = new UpscaleSource(file, width, height);
            }

            MilanLog.Information($"Indexed {upscaleMap.Count} candidate upscales from {syncFolder}", customPrefix: LOG_CATEGORY);
        }

        /// <summary>
        /// Finds the upscale for a texture, if there is one that is actually larger than what the export currently holds.
        /// </summary>
        private static bool TryGetUpscale(ExportEntry texture, out UpscaleSource upscale)
        {
            upscale = null;
            if (!upscaleMap.TryGetValue(GetUpscaleKey(texture.InstancedFullPath), out var candidate))
                return false;

            var topMip = new Texture2D(texture).GetTopMip();
            if (topMip == null)
                return false; // Stubbed/empty texture - nothing to compare against

            if (candidate.Width <= topMip.width && candidate.Height <= topMip.height)
                return false; // Not an upgrade in either dimension

            upscale = candidate;
            return true;
        }

        /// <summary>
        /// Converts an instanced full path into the sync folder's relative path form: the first segment is the containing
        /// package folder, the remainder (dots intact) is the filename. Must match TextureResearch's extraction layout.
        /// </summary>
        private static string GetUpscaleKey(string instancedFullPath)
        {
            var dotIndex = instancedFullPath.IndexOf('.');
            var package = dotIndex >= 0 ? instancedFullPath[..dotIndex] : instancedFullPath;
            var remainder = dotIndex >= 0 ? instancedFullPath[(dotIndex + 1)..] : instancedFullPath;
            return Path.Combine(SanitizeForFilename(package), SanitizeForFilename(remainder));
        }

        private static string SanitizeForFilename(string name)
        {
            foreach (var c in Path.GetInvalidFileNameChars())
                name = name.Replace(c, '_');
            return name;
        }

        /// <summary>
        /// Reads just the header of an image to get its dimensions - decoding every file in the sync folder to find the handful
        /// that are actually bigger than what's in the package would be very slow.
        /// </summary>
        private static bool TryGetImageDimensions(string filePath, out int width, out int height)
        {
            width = height = 0;
            try
            {
                using var fs = File.OpenRead(filePath);
                Span<byte> header = stackalloc byte[24];
                if (fs.Read(header) != header.Length)
                    return false;

                switch (Path.GetExtension(filePath).ToLowerInvariant())
                {
                    case ".png":
                        // 8 byte signature, then IHDR chunk: length, 'IHDR', width, height - all big endian
                        width = (header[16] << 24) | (header[17] << 16) | (header[18] << 8) | header[19];
                        height = (header[20] << 24) | (header[21] << 16) | (header[22] << 8) | header[23];
                        break;
                    case ".dds":
                        // 'DDS ' magic, dwSize, dwFlags, then dwHeight and dwWidth - little endian
                        height = header[12] | (header[13] << 8) | (header[14] << 16) | (header[15] << 24);
                        width = header[16] | (header[17] << 8) | (header[18] << 16) | (header[19] << 24);
                        break;
                    case ".tga":
                        // Width and height live at 12 and 14 in the 18 byte header, little endian
                        width = header[12] | (header[13] << 8);
                        height = header[14] | (header[15] << 8);
                        break;
                    default:
                        return false;
                }
            }
            catch (Exception ex)
            {
                MilanLog.Error($"  Error reading image header for {filePath}: {ex.Message}", customPrefix: LOG_CATEGORY);
                return false;
            }

            return width > 0 && height > 0;
        }

        #endregion

        /// <summary>
        /// Updates texture formats that only work in ME3 to LE3, installs upscales, strip material permutations on broken materials if it will fix them.
        /// </summary>
        private static void UpdateTextures()
        {
            // ME3 V8U8 norms don't work in LE3, it seems V8U8 support was removed, they appear as black
            // Convert them all to BC7

            var inputFolder = Path.Combine(Program.Settings.OutputModPath, @"CookedPCConsole");
            using TieredPackageCache cache = TieredPackageCache.GetGlobalPackageCache(MEGame.LE3, debugName: "TFCBuild global LE3 root").ChainNewCache(debugName: "TFCBuild UpdateTextures cache");
            foreach (var pf in Directory.GetFiles(inputFolder, "*.pcc", SearchOption.AllDirectories))
            {
                MilanLog.Information($"Checking package {Path.GetFileName(pf)}", customPrefix: LOG_CATEGORY);
                var p = MEPackageHandler.OpenMEPackage(pf);

                foreach (var obj in p.Exports.Where(x => x.IsTexture() || x.IsA("MaterialInstanceConstant")))
                {
                    if (obj.IsA("MaterialInstanceConstant"))
                    {
                        if (obj.GetProperty<BoolProperty>("bHasStaticPermutationResource")?.Value == true && ShaderCacheManipulator.IsMaterialBroken(obj))
                        {
                            var parent = obj.GetProperty<ObjectProperty>("Parent")?.ResolveToExport(p, cache);
                            if (parent != null && !ShaderCacheManipulator.IsMaterialBroken(parent))
                            {
                                MilanLog.Information($"  Fixing broken material due to permutation {obj.InstancedFullPath}", customPrefix: LOG_CATEGORY);
                                obj.RemoveProperty("bHasStaticPermutationResource");
                                obj.WriteBinary([]);
                            }
                        }

                        continue;
                    }
                    // ME3 V8U8 norms don't work in LE3 and appear black, so they always end up as BC7.
                    var needsBC7Conversion = obj.GetProperty<EnumProperty>("Format")?.Value == "PF_V8U8";
                    var hasUpscale = TryGetUpscale(obj, out var upscale);

                    if (needsBC7Conversion && !hasUpscale)
                    {
                        MilanLog.Information($"  Converting texture {obj.InstancedFullPath} from PF_V8U8 to BC7", customPrefix: LOG_CATEGORY);
                        try
                        {
                            ConvertTexture(obj, PixelFormat.BC7);
                        }
                        catch (Exception ex)
                        {
                            // This may be expected in a few cases. For example if TFC for texture data cannot be found.
                            // This may happen during dev as textures will be broken on and off
                            MilanLog.Error($"  Unable to convert texture: {ex.Message}");
                        }
                    }

                    if (hasUpscale)
                    {
                        // Converting first would decode the old texture data just to throw it away - the upscale replaces
                        // every mip anyway, so fold the format change into the replace instead.
                        InstallUpscale(obj, upscale, needsBC7Conversion);
                    }
                }

                if (p.IsModified)
                {
                    MilanLog.Information($"  Saving package", customPrefix: LOG_CATEGORY);
                    p.Save(diskIOSyncLock: MilanShared.DiskIOSyncLock);
                    MilanShared.RefreshMilanFiles = true;
                }
            }
        }

        /// <summary>
        /// Installs an upscale over a texture, package stored - MoveNonLightingTexturesToExternalTFC externalizes and dedupes it later.
        /// </summary>
        /// <param name="convertV8U8ToBC7">If the export is a V8U8 norm, which doesn't render in LE3. The new image is encoded as BC7 directly.</param>
        private static void InstallUpscale(ExportEntry tex, UpscaleSource upscale, bool convertV8U8ToBC7)
        {
            try
            {
                var t2d = new Texture2D(tex);
                MilanLog.Information($"  Installing upscaled texture {tex.InstancedFullPath}: {t2d.GetTopMip().width}x{t2d.GetTopMip().height} -> {upscale.Width}x{upscale.Height}{(convertV8U8ToBC7 ? " (V8U8 -> BC7)" : "")}", customPrefix: LOG_CATEGORY);

                var props = tex.GetProperties();
                if (convertV8U8ToBC7)
                {
                    props.AddOrReplaceProp(new EnumProperty("PF_BC7", "EPixelFormat", MEGame.LE3, "Format"));
                    props.AddOrReplaceProp(new EnumProperty("TC_NormalmapBC7", "TextureCompressionSettings", MEGame.LE3, "CompressionSettings"));
                    t2d.TextureFormat = "PF_BC7"; // Required for conversion
                }

                // Load as ARGB so Replace() re-encodes into the target format (and so its DXT1 alpha check, which only works on ARGB, fires).
                var image = Image.LoadFromFile(upscale.FilePath, PixelFormat.ARGB);
                t2d.Replace(image, props, isPackageStored: true);
                ClearNeverStreamForExternalization(tex);
            }
            catch (Exception ex)
            {
                // A bad source image (not power of 2, etc) shouldn't take down the build - the texture just stays as it was.
                MilanLog.Error($"  Unable to install upscale for {tex.InstancedFullPath} from {upscale.FilePath}: {ex.Message}", customPrefix: LOG_CATEGORY);
            }
        }

        private static void ConvertTexture(ExportEntry tex, PixelFormat destFormat)
        {

            var props = tex.GetProperties();
            var texture = new Texture2D(tex);
            var sourceFormat = Image.getPixelFormatType(texture.TextureFormat);

            // V8U8 is just "two channels of signed data" - ME3 used it for VFX distortion, flux and grayscale masks as much
            // as for normal maps. Census of ME3 DLC content: 22488 TC_Default, 661 TC_Grayscale and 102 TC_OneBitAlpha V8U8
            // textures (none of which sampled as normal maps) against only 2184 TC_Normalmap* ones. So the texture's own
            // compression setting, not its pixel format, decides whether it is a normal map.
            var isNormalMap = props.GetProp<EnumProperty>("CompressionSettings")?.Value.Name
                .Contains("Normal", StringComparison.OrdinalIgnoreCase) == true;

            Image convertedImage;
            if (sourceFormat == PixelFormat.V8U8 && destFormat == PixelFormat.BC7 && isNormalMap)
            {
                // V8U8 physically has no Z channel, and Image.V8U8ToARGB fills that lane with a constant 255 (verified:
                // the sole vanilla V8U8 texture decodes to lane0=255, lanes1/2=V,U). BC7 in LE3 is a *three* channel normal
                // format - across 6130 vanilla PF_BC7/TC_NormalmapBC7 textures the Z lane holds the geometrically correct
                // value to a median 1.3/255, the same as DXT1/DXT5, where PF_BC5 does not (median 8.6, only 2 of 20).
                // Handing the shader a flat Z would flatten every converted normal map, so rebuild it from XY first.
                // Only for real normal maps: for a distortion map the third channel is meaningless and must be left alone.
                convertedImage = texture.ToImage(PixelFormat.ARGB);
                ReconstructNormalZ(convertedImage);
                convertedImage.correctMips(destFormat);
            }
            else
            {
                convertedImage = texture.ToImage(destFormat);
            }

            props.AddOrReplaceProp(new EnumProperty($"PF_{destFormat}", "EPixelFormat", MEGame.LE3, "Format"));

            // Only restamp CompressionSettings on textures that really are normal maps - the conversion exists because V8U8
            // doesn't render in LE3, which applies to VFX data textures too, but calling those normal maps would be a lie.
            if (!isNormalMap)
            {
                // Leave the existing setting (TC_Default, TC_Grayscale, TC_OneBitAlpha, ...) alone.
            }
            else if (destFormat == PixelFormat.BC7)
            {
                props.AddOrReplaceProp(new EnumProperty("TC_NormalmapBC7", "TextureCompressionSettings", MEGame.LE3, "CompressionSettings"));
            }
            else
            {
                // Implement the rest if necessary
                props.AddOrReplaceProp(new EnumProperty("TC_NormalMap", "TextureCompressionSettings", MEGame.LE3, "CompressionSettings"));
            }

            texture.TextureFormat = $"PF_{destFormat}"; // Required for conversion
            texture.Replace(convertedImage, props, isPackageStored: true);
            ClearNeverStreamForExternalization(tex);
        }

        /// <summary>
        /// Texture2D.Replace() sets NeverStream on any package stored texture with 6 or more mips, but
        /// MilanShared.MoveTexturesToTFC skips everything marked NeverStream - so a texture we just wrote would never be
        /// externalized and would stay baked into the package. Strip the flag back off so externalization picks it up;
        /// it removes it itself once the mips are out, so this just gets us past the skip.
        ///
        /// Only for textures externalization will actually move. It externalizes Mips.Count - 6 mips and bails outright at
        /// 6 or fewer, so a texture sitting at exactly 6 keeps the flag - nothing would move out of it, and it does need
        /// NeverStream while it stays package stored (streaming only works for external mips).
        /// </summary>
        private static void ClearNeverStreamForExternalization(ExportEntry tex)
        {
            var nonEmptyMips = tex.GetBinaryData<UTexture2D>().Mips.Count(x => x.StorageType != StorageTypes.empty);
            if (nonEmptyMips <= 6)
                return;

            var props = tex.GetProperties();
            if (props.RemoveNamedProperty("NeverStream"))
            {
                tex.WriteProperties(props);
            }
        }

        /// <summary>
        /// Rebuilds a tangent space normal map's Z channel from its X and Y, in place, on an ARGB image.
        /// Lane 0 is Z and lanes 1/2 are the two stored components - the layout Image.V8U8ToARGB produces, and the layout
        /// 26 of 30 sampled vanilla LE3 BC7 normal maps decode to.
        /// </summary>
        internal static void ReconstructNormalZ(Image argbImage)
        {
            foreach (var mip in argbImage.mipMaps)
            {
                var data = mip.data;
                for (var i = 0; i + 3 < data.Length; i += 4)
                {
                    var x = data[i + 2] / 255d * 2 - 1;
                    var y = data[i + 1] / 255d * 2 - 1;
                    var z = Math.Sqrt(Math.Max(0, 1 - (x * x + y * y)));
                    data[i] = (byte)Math.Clamp(Math.Round((z + 1) / 2 * 255), 0, 255);
                }
            }
        }


        /// <summary>
        /// This will probably be moved to LEC
        /// </summary>
        public static void MoveNonLightingTexturesToExternalTFC(string dlcName)
        {
            MilanShared.MoveTexturesToTFC("Textures", dlcName, false, @"MILAN-TFC");

            // Step 2: TFC Compactor
            var inputFolder = Path.Combine(Program.Settings.OutputModPath, @"CookedPCConsole");
            var staging = Directory.CreateDirectory(Path.Combine(inputFolder, "Staging")).FullName;
            TFCCompactorInfoPackage info = new TFCCompactorInfoPackage()
            {
                Game = MEGame.LE3,
                BaseCompactionPath = inputFolder,
                DLCName = MilanShared.DLC_NAME,
                GamePath = LE3Directory.DefaultGamePath,
                TFCsToCompact = new List<string>()
                {
                    $"Textures_{MilanShared.DLC_NAME}",
                    "Textures_DLC_CON_GUN01",
                    "Textures_DLC_CON_GUN02",
                    "Textures_DLC_HEN_PR",
                    "Textures_DLC_EXP_Pack001",
                    "Textures_DLC_EXP_Pack002",
                    "Textures_DLC_EXP_Pack003",
                    "Textures_DLC_EXP_Pack003_Base",
                    "Textures_DLC_METR_Patch01", // We don't ship this either
                },
                UseIndexing = false,
                StagingPath = staging,
                TFCType = "Textures",
                RootTexturesOnly = false, // Name says non-lighting: root (lightmap) textures are handled separately below via plain MoveTexturesToTFC, not compacted here.
            };

            MilanLog.Information("Compacting TFC", customPrefix: LOG_CATEGORY);
            TFCCompactor.CompactTFC(info, x => MilanLog.Error(x, customPrefix: LOG_CATEGORY), (text, done, total) =>
            {
                if (text != null)
                {
                    MilanLog.Information($"  {text}", customPrefix: LOG_CATEGORY);
                }
                if (total > 0)
                {
                    MilanLog.Information($"  Progress: {done}/{total}", customPrefix: LOG_CATEGORY);
                }
                else if (done == -1 && total == -1)
                {

                }
            });
        }
    }
}
