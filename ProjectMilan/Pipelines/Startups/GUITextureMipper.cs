using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Textures;
using LegendaryExplorerCore.Unreal;
using LegendaryExplorerCore.Unreal.BinaryConverters;
using LegendaryExplorerCore.Unreal.Classes;
using ProjectMilanCore;
using System.Numerics;

namespace ProjectMilan.Pipelines.Startups
{
    /// <summary>
    /// Class for generating mips for GUI textures, as scaleform supports them, and some textures need better downscaling
    /// </summary>
    /// <remarks>
    /// Scaleform only samples a texture trilinearly when the engine hands it a mipped texture. The game's own GUI images are
    /// TEXTUREGROUP_UI with a single mip: the cooker strips UI mips, and the GFx renderer forces mip 0 for that group
    /// (a -13 mip bias), so a big image shown small is point sampled from the full size image and aliases. Moving the texture
    /// to a group that is not UI and giving it a full chain fixes that. The chain stays in the package and the texture stays
    /// NeverStream, as UI textures are never streamed (nothing would ask for the big mips, so they would stay at the smallest
    /// ones).
    /// </remarks>
    public static class GUITextureMipper
    {
        private const string LOG_CATEGORY = @"MILAN-GUITextureMipper";

        /// <summary>
        /// The group GUI textures are moved to. Promotional is not UI (so it is mipped and sampled trilinearly), is not
        /// filtered with anisotropy, and has a 256 pixel floor for LODBias to stop at.
        /// </summary>
        public const string MippedTextureGroup = "TEXTUREGROUP_Promotional";

        /// <summary>
        /// Rebuilds the selection from output packages, including after a checkpoint restore. These are the
        /// packages previously mipped by Weapons/NonStartup; every copy of their UI texture paths is selected.
        /// The editable registry and pre-upscale inventory are deliberately separate future work.
        /// </summary>
        public static HashSet<string> DiscoverTexturePaths(string outputPath)
        {
            var sources = new HashSet<string>(StringComparer.OrdinalIgnoreCase)
            {
                "SFXGUI_WeaponUIDataDLC_CON_MPMerged", "SFXGUI_WeaponUIDataDLC_CON_MPMergedMods",
                "SFXGUI_WeaponUIDataDLC_SharedSF", "SFXSharedModImages",
                "SFXMP5WeaponImages", "SFXMP5ModImages",
            };
            var paths = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            foreach (var file in Directory.EnumerateFiles(outputPath, "*.pcc", SearchOption.AllDirectories)
                         .Where(file => sources.Contains(Path.GetFileNameWithoutExtension(file))))
            {
                using var package = MEPackageHandler.UnsafePartialLoad(file, export => export.ClassName == "Texture2D");
                foreach (var texture in package.Exports.Where(export => export.ClassName == "Texture2D" && !export.IsDefaultObject))
                {
                    var group = texture.GetProperty<EnumProperty>("LODGroup")?.Value.Name;
                    if (group is "TEXTUREGROUP_UI" or MippedTextureGroup)
                    {
                        paths.Add(texture.InstancedFullPath);
                    }
                }
            }
            return paths;
        }

        /// <summary>
        /// Applies the selected GUI texture policy to every matching copy in a package.
        /// Existing chains are kept, with package residency enforced.
        /// </summary>
        /// <param name="package">The package to mip the textures of. Not saved.</param>
        /// <param name="options">How the lower mips are filtered; null for <see cref="MipGenerationOptions.HighQuality"/>.</param>
        /// <returns>How many textures were given mips.</returns>
        public static int GenerateMipsForPackage(IMEPackage package, IReadOnlySet<string> texturePaths, MipGenerationOptions? options = null)
        {
            int mipped = 0;
            long bytesBefore = 0;
            long bytesAfter = 0;
            var stopwatch = System.Diagnostics.Stopwatch.StartNew();

            // Mipping rewrites the export's data, so take the list first
            foreach (var exp in package.Exports.Where(x => x.ClassName == "Texture2D").ToList())
            {
                if (!texturePaths.Contains(exp.InstancedFullPath))
                {
                    continue;
                }

                var before = new Texture2D(exp).Mips.Where(x => x.storageType != StorageTypes.empty).Sum(x => (long)x.uncompressedSize);
                if (GenerateMipsForGUITexture(exp, options))
                {
                    mipped++;
                    bytesBefore += before;
                    bytesAfter += new Texture2D(exp).Mips.Where(x => x.storageType != StorageTypes.empty).Sum(x => (long)x.uncompressedSize);
                }
            }

            MilanLog.Information($"Applied GUI mip/residency policy to {mipped} GUI texture(s) in {package.FileNameNoExtension} in {stopwatch.Elapsed.TotalSeconds:0.#}s " +
                                 $"(texture data {bytesBefore / 1048576.0:0.#} MiB -> {bytesAfter / 1048576.0:0.#} MiB)", customPrefix: LOG_CATEGORY);
            return mipped;
        }

        /// <summary>
        /// Checks that every texture object path found in more than one of the packages has the same mips and the same CRC in all of
        /// them. The game keeps whichever copy of an object it loads first, and TFC compaction treats a CRC that differs under
        /// one name as an error, so a copy that was mipped (or encoded) differently from another is a bug whichever one loads.
        /// Logs an error for each path whose copies differ.
        /// </summary>
        /// <param name="packagePaths">The packages to compare.</param>
        /// <returns>How many object paths had copies that differ.</returns>
        public static int VerifyTexturesAreConsistent(IReadOnlyCollection<string> packagePaths, IReadOnlySet<string> texturePaths)
        {
            // Opening a package is cheap, decoding its textures is not: find the shared paths first
            var packagesByTexture = new Dictionary<string, List<string>>(StringComparer.OrdinalIgnoreCase);
            foreach (var path in packagePaths)
            {
                using var package = MEPackageHandler.OpenMEPackage(path, forceLoadFromDisk: true);
                foreach (var exp in package.Exports.Where(x => x.ClassName == "Texture2D" && texturePaths.Contains(x.InstancedFullPath)))
                {
                    if (!packagesByTexture.TryGetValue(exp.InstancedFullPath, out var packages))
                    {
                        packagesByTexture[exp.InstancedFullPath] = packages = [];
                    }
                    packages.Add(path);
                }
            }

            var shared = packagesByTexture.Where(x => x.Value.Count > 1).ToDictionary(x => x.Key, x => x.Value, StringComparer.OrdinalIgnoreCase);
            var fingerprints = new Dictionary<string, List<(string Package, string Fingerprint)>>(StringComparer.OrdinalIgnoreCase);
            foreach (var group in shared.SelectMany(x => x.Value.Select(package => (Package: package, TexturePath: x.Key))).GroupBy(x => x.Package))
            {
                using var package = MEPackageHandler.OpenMEPackage(group.Key, forceLoadFromDisk: true);
                foreach (var (_, texturePath) in group)
                {
                    var exp = package.Exports.First(x => x.ClassName == "Texture2D" && x.InstancedFullPath.Equals(texturePath, StringComparison.OrdinalIgnoreCase));
                    if (!fingerprints.TryGetValue(texturePath, out var list))
                    {
                        fingerprints[texturePath] = list = [];
                    }
                    list.Add((group.Key, GetFingerprint(exp)));
                }
            }

            int inconsistent = 0;
            foreach (var (texturePath, copies) in fingerprints.OrderBy(x => x.Key, StringComparer.OrdinalIgnoreCase))
            {
                if (copies.Select(x => x.Fingerprint).Distinct().Count() > 1)
                {
                    inconsistent++;
                    MilanLog.Error($"Texture {texturePath} is not the same in every package that has it: " +
                                   string.Join("; ", copies.Select(x => $"{Path.GetFileName(x.Package)} ({x.Fingerprint})")), customPrefix: LOG_CATEGORY);
                }
            }

            MilanLog.Information($"Compared {shared.Count} texture path(s) found in more than one of {packagePaths.Count} package(s): {inconsistent} differ", customPrefix: LOG_CATEGORY);
            return inconsistent;
        }

        /// <summary>
        /// Describes a texture by what the game would see: its size and format, its top mip's CRC (what TFC compaction compares), and
        /// a CRC over every mip, so a different chain under the same top mip shows too.
        /// </summary>
        private static string GetFingerprint(ExportEntry exp)
        {
            var texture = new Texture2D(exp);
            var mips = texture.Mips.Where(x => x.storageType != StorageTypes.empty).ToList();
            var all = new List<byte>();
            foreach (var mip in mips)
            {
                all.AddRange(Texture2D.GetTextureData(mip, exp.Game));
            }

            var props = exp.GetProperties();
            return $"{props.GetProp<EnumProperty>("LODGroup")?.Value.Name}, NeverStream={props.GetProp<BoolProperty>("NeverStream")?.Value == true}, local={mips.All(mip => mip.IsPackageStored)}, {mips[0].width}x{mips[0].height}, {mips.Count} mips, {texture.TextureFormat}, top {Texture2D.GetTextureCRC(exp):X8}, all {TextureCRC.Compute(all.ToArray()):X8}";
        }

        /// <summary>
        /// Moves a GUI texture out of TEXTUREGROUP_UI and gives it a full mip chain, so that Scaleform filters it down
        /// when it is shown smaller than it is stored. Existing chains are retained and made package-resident.
        /// Non-power-of-two textures are left unchanged.
        /// </summary>
        /// <param name="exp">A Texture2D export, as a single mip UI texture. The top mip is kept exactly as it is.</param>
        /// <param name="options">How the lower mips are filtered; null for <see cref="MipGenerationOptions.HighQuality"/> (Lanczos, a mild sharpen, and
        /// colour padded under transparent texels so edges don't darken).</param>
        /// <returns>True if the texture was changed.</returns>
        public static bool GenerateMipsForGUITexture(ExportEntry exp, MipGenerationOptions? options = null)
        {
            if (exp.ClassName != "Texture2D")
            {
                MilanLog.Warning($"Not generating GUI mips for {exp.InstancedFullPath}: it is a {exp.ClassName}, not a Texture2D", customPrefix: LOG_CATEGORY);
                return false;
            }

            var texture = new Texture2D(exp);
            var topMip = texture.GetTopMip();
            if (topMip == null)
            {
                MilanLog.Warning($"Not generating GUI mips for {exp.InstancedFullPath}: it has no mips", customPrefix: LOG_CATEGORY);
                return false;
            }

            if (!BitOperations.IsPow2(topMip.width) || !BitOperations.IsPow2(topMip.height))
            {
                MilanLog.Warning($"GUI texture {exp.InstancedFullPath} is {topMip.width}x{topMip.height}, which is not a power of two; mips were not generated", customPrefix: LOG_CATEGORY);
                return false;
            }

            bool hasChain = texture.Mips.Count(x => x.storageType != StorageTypes.empty) > 1;
            bool changed = false;
            if (texture.Mips.Any(mip => mip.storageType != StorageTypes.empty && !mip.IsPackageStored))
            {
                // Read every payload before mutating the export. Never mark an external chain NeverStream:
                // first bring its encoded bytes back into the package, without recompressing the artwork.
                var residentMips = texture.Mips.Where(mip => mip.storageType != StorageTypes.empty)
                    .Select(mip => new UTexture2D.Texture2DMipMap(Texture2D.GetTextureData(mip, exp.Game), mip.width, mip.height))
                    .ToList();
                var binary = exp.GetBinaryData<UTexture2D>();
                binary.Mips = residentMips;
                exp.WriteBinary(binary);
                texture = new Texture2D(exp);
                changed = true;
            }

            // Change the texture group to "Promotional" so that it will be mipped by engine
            var props = exp.GetProperties();
            if (props.GetProp<EnumProperty>("LODGroup") is not { Value.Name: MippedTextureGroup })
            {
                props.AddOrReplaceProp(new EnumProperty(MippedTextureGroup, "TextureGroup", exp.Game, "LODGroup"));
                changed = true;
            }

            if (props.GetProp<BoolProperty>("NeverStream") is not { Value: true })
            {
                props.AddOrReplaceProp(new BoolProperty(true, "NeverStream"));
                changed = true;
            }
            changed |= props.RemoveNamedProperty("TextureFileCacheName");
            changed |= props.RemoveNamedProperty("TFCFileGuid");
            changed |= props.RemoveNamedProperty("TFCFileGuidHiRes");

            // The importer marks single mip GUI textures like this; it would be wrong now, and the editor would regenerate over the chain
            changed |= props.RemoveNamedProperty("CompressionNoMipmaps");
            if (changed)
            {
                exp.WriteProperties(props);
            }

            if (hasChain)
            {
                return changed;
            }

            // Keeps the format, and with these options does not recompress the top mip. Marks the texture NeverStream.
            texture.GenerateMips(options: options ?? MipGenerationOptions.HighQuality);
            return true;
        }
    }
}
