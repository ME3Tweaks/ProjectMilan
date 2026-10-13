using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Textures;
using LegendaryExplorerCore.Unreal;
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
        /// Gives every single mip TEXTUREGROUP_UI texture in a package a full mip chain (see <see cref="GenerateMipsForGUITexture"/>).
        /// Textures in any other group are left alone, as are ones that already have a chain.
        /// </summary>
        /// <param name="package">The package to mip the textures of. Not saved.</param>
        /// <param name="options">How the lower mips are filtered; null for <see cref="MipGenerationOptions.HighQuality"/>.</param>
        /// <returns>How many textures were given mips.</returns>
        public static int GenerateMipsForPackage(IMEPackage package, MipGenerationOptions? options = null)
        {
            int mipped = 0;
            long bytesBefore = 0;
            long bytesAfter = 0;
            var stopwatch = System.Diagnostics.Stopwatch.StartNew();

            // Mipping rewrites the export's data, so take the list first
            foreach (var exp in package.Exports.Where(x => x.ClassName == "Texture2D").ToList())
            {
                if (exp.GetProperty<EnumProperty>("LODGroup") is not { Value.Name: "TEXTUREGROUP_UI" })
                    continue;

                var before = new Texture2D(exp).Mips.Where(x => x.storageType != StorageTypes.empty).Sum(x => (long)x.uncompressedSize);
                if (GenerateMipsForGUITexture(exp, options))
                {
                    mipped++;
                    bytesBefore += before;
                    bytesAfter += new Texture2D(exp).Mips.Where(x => x.storageType != StorageTypes.empty).Sum(x => (long)x.uncompressedSize);
                }
            }

            MilanLog.Information($"Generated mips for {mipped} GUI texture(s) in {package.FileNameNoExtension} in {stopwatch.Elapsed.TotalSeconds:0.#}s " +
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
        public static int VerifyTexturesAreConsistent(IReadOnlyCollection<string> packagePaths)
        {
            // Opening a package is cheap, decoding its textures is not: find the shared paths first
            var packagesByTexture = new Dictionary<string, List<string>>(StringComparer.OrdinalIgnoreCase);
            foreach (var path in packagePaths)
            {
                using var package = MEPackageHandler.OpenMEPackage(path, forceLoadFromDisk: true);
                foreach (var exp in package.Exports.Where(x => x.ClassName == "Texture2D"))
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

            return $"{mips[0].width}x{mips[0].height}, {mips.Count} mips, {texture.TextureFormat}, top {Texture2D.GetTextureCRC(exp):X8}, all {TextureCRC.Compute(all.ToArray()):X8}";
        }

        /// <summary>
        /// Moves a GUI texture out of TEXTUREGROUP_UI and gives it a full mip chain, so that Scaleform filters it down
        /// when it is shown smaller than it is stored. A texture that already has a chain only has its group changed.
        /// A texture that can't be mipped (stored in a TFC, or not a power of two) is left exactly as it was, in UI.
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

            bool hasChain = texture.Mips.Count(x => x.storageType != StorageTypes.empty) > 1;
            if (!hasChain)
            {
                if (!topMip.IsPackageStored)
                {
                    // The engine can't read a TFC mip of a texture that doesn't stream, and a GUI texture never does
                    MilanLog.Warning($"GUI texture {exp.InstancedFullPath} is stored in a TFC; mips were not generated", customPrefix: LOG_CATEGORY);
                    return false;
                }

                if (!BitOperations.IsPow2(topMip.width) || !BitOperations.IsPow2(topMip.height))
                {
                    // Mips of a non power of two texture are not a chain the engine can use
                    MilanLog.Warning($"GUI texture {exp.InstancedFullPath} is {topMip.width}x{topMip.height}, which is not a power of two; mips were not generated", customPrefix: LOG_CATEGORY);
                    return false;
                }
            }

            // Change the texture group to "Promotional" so that it will be mipped by engine
            var props = exp.GetProperties();
            bool changed = false;
            if (props.GetProp<EnumProperty>("LODGroup") is not { Value.Name: MippedTextureGroup })
            {
                props.AddOrReplaceProp(new EnumProperty(MippedTextureGroup, "TextureGroup", exp.Game, "LODGroup"));
                changed = true;
            }

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
