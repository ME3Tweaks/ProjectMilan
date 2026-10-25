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
        /// Individual GUI textures to mip, by InstancedFullPath, whatever package they are in and whatever their LODGroup.
        /// Every copy of each path is mipped.
        /// </summary>
        public static readonly IReadOnlySet<string> ExplicitTexturePaths = new HashSet<string>(StringComparer.OrdinalIgnoreCase)
        {
            "GUI_SF_MPReinforcements_DLC.MPReinforcementsReveal_I32", // Red crate
            "GUI_SF_MPMatchResults.MPMatchResults_I25", // Match results coins
            "GUI_SF_MPMatchResults.MPMatchResults_I64", // Match results row blue border
            "GUI_SF_MPMatchResults.MPMatchResults_I67", // Match results row red border
            "GUI_SF_MPNewLobby_DLC.MPNewLobby_I49", // Lobby card border
            
            // Consumables UI
            "GUI_SF_MPMatchConsum_DLC.MPMatchConsumables_IF", // Row
            "GUI_SF_MPMatchConsum_DLC.MPMatchConsumables_I22", // Selected row 
            "GUI_SF_MPMatchConsum_DLC.MPMatchConsumables_I28", // Consumables item border blue
            "GUI_SF_MPMatchConsum_DLC.MPMatchConsumables_I36", // Consumables item border white
            "GUI_SF_MPMatchConsum_DLC.MPMatchConsumables_I3A", // Consumables item border red
            "GUI_SF_MPMatchConsum_DLC.MPMatchConsumables_I56", // Ops Survival Pack
            "GUI_SF_MPMatchConsum_DLC.MPMatchConsumables_I57", // Cobra
            "GUI_SF_MPMatchConsum_DLC.MPMatchConsumables_I58", // Medigel
            "GUI_SF_MPMatchConsum_DLC.MPMatchConsumables_I59", // Thermal Clips



        };

        /// <summary>
        /// Optional maximum dimension for every copy of a GUI texture. Independent of mip selection:
        /// cap-only textures keep their group and single-mip/chain behavior. OriginalSize retains the full source size.
        /// </summary>
        public static readonly IReadOnlyDictionary<string, int> TextureSizeCaps = new Dictionary<string, int>(StringComparer.OrdinalIgnoreCase)
        {
            // We manually disabled some upscales so this is likely pretty lightly used
            { "GUI_SF_MPMatchResults.MPMatchResults_I25", 1024 }, // Match results coins - We have 2K but widest this shows is about 600
            { "GUI_SF_MPNewLobby_DLC.MPNewLobby_I49", 2048 }, // Lobby card border - We have 4K but max size is less than half so 2K should be OK
            { "GUI_SF_MPNewLobby_DLC.MPNewLobby_I6F", 2048 }, // Lobby card red fill - We have 4K but max size is less than half so 2K should be OK
            { "GUI_SF_MPMatchConsum_DLC.MPMatchConsumables_I58", 512 }, // + Up arrow power, 300 units required
            { "GUI_SF_MPSelectKit_DLC.MPSelectKit_I22", 512 }, // Kit Select Alliance Logo - needs around 260 units
            { "GUI_SF_MPPlayerCountdown_Milan.MPPlayerCountdown_I20", 256 }, // Player Countdown needs ~256 units
            // Medals need 96x96
            { "GUI_SF_MPChallenges_DLC.MPChallenges_I1A", 128 },
            { "GUI_SF_MPChallenges_DLC.MPChallenges_I1C", 128 },
            { "GUI_SF_MPChallenges_DLC.MPChallenges_I1E", 128 },
            { "GUI_SF_MPChallenges_DLC.MPChallenges_I20", 128 },
            { "GUI_SF_MPChallenges_DLC.MPChallenges_I22", 128 },
            { "GUI_SF_MPChallenges_DLC.MPChallenges_I24", 128 },
            { "GUI_SF_MPChallenges_DLC.MPChallenges_I32", 128 },


        };

        /// <summary>
        /// GUI textures that are replaced by a preferred master, keyed by the master's InstancedFullPath. Every copy of each target gets
        /// the master's final image, mips and texture properties, so the same art looks the same in every movie. Masters and targets are
        /// always mipped. Picked from the BIOP_MP_COMMON GUI texture audit (2026-10-25).
        /// </summary>
        public static readonly IReadOnlyDictionary<string, string[]> TextureMasters = new Dictionary<string, string[]>(StringComparer.OrdinalIgnoreCase)
        {
            // Xbox controller prompts
            { "GUI_SF_MessageBox_Milan.Xbox_ControllerIcons_ABtn", ["GUI_SF_GalaxyAtWar.Xbox_ControllerIcons_ABtn", "GUI_SF_MilanNetConfig.Xbox_ControllerIcons_ABtn"] },
            { "GUI_SF_MessageBox_Milan.Xbox_ControllerIcons_BBtn", ["GUI_SF_GalaxyAtWar.Xbox_ControllerIcons_BBtn", "GUI_SF_MilanNetConfig.Xbox_ControllerIcons_BBtn"] },
            { "GUI_SF_MessageBox_Milan.Xbox_ControllerIcons_XBtn", ["GUI_SF_GalaxyAtWar.Xbox_ControllerIcons_XBtn"] },
            { "GUI_SF_MessageBox_Milan.Xbox_ControllerIcons_YBtn", ["GUI_SF_GalaxyAtWar.Xbox_ControllerIcons_YBtn", "GUI_SF_MP_HUD.Xbox_ControllerIcons_YBtn"] },
            { "GUI_SF_MessageBox_Milan.Xbox_ControllerIcons_LStickUpDown", ["GUI_SF_GalaxyAtWar.Xbox_ControllerIcons_LStickUpDown", "GUI_SF_MilanBannerSelect.Xbox_ControllerIcons_LStickUpDown"] },
            { "GUI_SF_MessageBox_Milan.Xbox_ControllerIcons_RStickUpDown", ["GUI_SF_GalaxyAtWar.Xbox_ControllerIcons_RStickUpDown", "GUI_SF_MilanBannerSelect.Xbox_ControllerIcons_RStickUpDown"] },
            { "GUI_SF_Leaderboard_Milan.Xbox_ControllerIcons_LBumper", ["GUI_SF_MP_HUD.Xbox_ControllerIcons_LBumper", "GUI_SF_MPNewLobby_DLC.Xbox_ControllerIcons_LBumper", "GUI_SF_MPPlayerCountdown_Milan.Xbox_ControllerIcons_LBumper"] },
            { "GUI_SF_Leaderboard_Milan.Xbox_ControllerIcons_RBumper", ["GUI_SF_MP_HUD.Xbox_ControllerIcons_RBumper", "GUI_SF_MPNewLobby_DLC.Xbox_ControllerIcons_RBumper", "GUI_SF_MPPlayerCountdown_Milan.Xbox_ControllerIcons_RBumper"] },
            { "GUI_SF_Leaderboard_Milan.Xbox_ControllerIcons_LTrigger", ["GUI_SF_MP_HUD.Xbox_ControllerIcons_LTrigger", "GUI_SF_MPChallenges_DLC.Xbox_ControllerIcons_LTrigger", "GUI_SF_MPPlayerCountdown_Milan.Xbox_ControllerIcons_LTrigger"] },
            { "GUI_SF_Leaderboard_Milan.Xbox_ControllerIcons_RTrigger", ["GUI_SF_MP_HUD.Xbox_ControllerIcons_RTrigger", "GUI_SF_MPChallenges_DLC.Xbox_ControllerIcons_RTrigger", "GUI_SF_MPPlayerCountdown_Milan.Xbox_ControllerIcons_RTrigger"] },

            // Shared Scaleform images
            { "GUI_SF_MessageBox_Milan.messageBox_I22", ["GUI_SF_WarAssets.warAssets_I33"] },
            { "GUI_SF_MPSelectKit_DLC.MPSelectKit_I92", ["GUI_SF_MP_HUD.MP_HUD_I5C", "GUI_SF_MPNewLobby_DLC.MPNewLobby_I3B", "GUI_SF_WarAssets.WarAssets_IAA"] },
            { "GUI_SF_MPSelectKit_DLC.MPSelectKit_I95", ["GUI_SF_MPNewLobby_DLC.MPNewLobby_I3E"] },
            { "GUI_SF_MP_HUD.MP_HUD_I5E", ["GUI_SF_WarAssets.warAssets_IAF"] },
            { "GUI_SF_WarAssets.warAssets_I94", ["GUI_SF_MPChallenges_DLC.MPChallenges_I2B"] },
            { "GUI_SF_MPChallenges_DLC.MPChallenges_I2E", ["GUI_SF_WarAssets.warAssets_I97"] },
            { "GUI_SF_MPChallenges_DLC.MPChallenges_I96", ["GUI_SF_WarAssets.warAssets_I1"] },
            { "GUI_SF_MPChallenges_DLC.MPChallenges_IC2", ["GUI_SF_WarAssets.WarAssets_IA0"] },
            { "GUI_SF_MPMatchResults.MPMatchResults_I22", ["GUI_SF_MPMatchResults.MPMatchResults_I77"] },
            { "GUI_SF_MPMatchResults.MPMatchResults_I25", ["GUI_SF_MPMatchResults.MPMatchResults_I7B", "GUI_SF_MPNewLobby_DLC.MPNewLobby_I83"] }, // Coins
            { "GUI_SF_MPMatchResults.MPMatchResults_I64", ["GUI_SF_MPSelectKit_DLC.MPSelectKit_I3B", "GUI_SF_MPStore_DLC.MPStore_ID"] }, // Blue row border
            { "GUI_SF_MPMatchResults.MPMatchResults_I71", ["GUI_SF_MPNewLobby_DLC.MPNewLobby_I54"] },
            { "GUI_SF_MPNewLobby_DLC.MPNewLobby_I6F", ["GUI_SF_MPSelectKit_DLC.MPSelectKit_I51", "GUI_SF_MPStore_DLC.MPStore_I10"] }, // Red card fill
            { "GUI_SF_MPStore_DLC.MPStore_I45", ["GUI_SF_MPStore_DLC.MPStore_I4B"] }, // PlayStation Store banner
        };

        /// <summary>Paths requiring either mip filtering or a size cap, for package scans and duplicate checks.</summary>
        public static HashSet<string> GetPolicyTexturePaths(IReadOnlySet<string> texturePaths, IReadOnlyDictionary<string, int>? sizeCaps = null)
        {
            sizeCaps ??= TextureSizeCaps;
            foreach (var (path, maxSize) in sizeCaps)
            {
                if (maxSize <= 0)
                    throw new ArgumentOutOfRangeException(nameof(sizeCaps), $"GUI size cap for {path} must be positive.");
            }
            var paths = new HashSet<string>(texturePaths, StringComparer.OrdinalIgnoreCase);
            paths.UnionWith(sizeCaps.Keys);
            return paths;
        }

        /// <summary>
        /// Rebuilds the selection from output packages, including after a checkpoint restore. These are the
        /// packages previously mipped by Weapons/NonStartup; every copy of their UI texture paths is selected,
        /// plus every path in <see cref="ExplicitTexturePaths"/> and every master and target in <see cref="TextureMasters"/>.
        /// </summary>
        public static HashSet<string> DiscoverTexturePaths(string outputPath)
        {
            var sources = new HashSet<string>(StringComparer.OrdinalIgnoreCase)
            {
                "SFXGUI_WeaponUIDataDLC_CON_MPMerged", "SFXGUI_WeaponUIDataDLC_CON_MPMergedMods",
                "SFXGUI_WeaponUIDataDLC_SharedSF", "SFXSharedModImages",
                "SFXMP5WeaponImages", "SFXMP5ModImages",
            };
            var paths = new HashSet<string>(ExplicitTexturePaths, StringComparer.OrdinalIgnoreCase);
            paths.UnionWith(TextureMasters.Keys);
            paths.UnionWith(TextureMasters.Values.SelectMany(targets => targets));
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
        /// Existing chains are kept, with package residency enforced; independent size caps are applied afterward.
        /// </summary>
        /// <param name="package">The package to mip the textures of. Not saved.</param>
        /// <param name="options">How the lower mips are filtered; null for <see cref="MipGenerationOptions.HighQuality"/>.</param>
        /// <returns>How many textures were changed by mip generation, residency repair, or a size cap.</returns>
        public static int GenerateMipsForPackage(IMEPackage package, IReadOnlySet<string> texturePaths, MipGenerationOptions? options = null,
            IReadOnlyDictionary<string, int>? sizeCaps = null)
        {
            sizeCaps ??= TextureSizeCaps;
            int mipped = 0;
            long bytesBefore = 0;
            long bytesAfter = 0;
            var stopwatch = System.Diagnostics.Stopwatch.StartNew();

            // Mipping rewrites the export's data, so take the list first
            foreach (var exp in package.Exports.Where(x => x.ClassName == "Texture2D").ToList())
            {
                bool mipSelected = texturePaths.Contains(exp.InstancedFullPath);
                bool capSelected = sizeCaps.TryGetValue(exp.InstancedFullPath, out int maxSize);
                if (!mipSelected && !capSelected)
                {
                    continue;
                }

                var before = new Texture2D(exp).Mips.Where(x => x.storageType != StorageTypes.empty).Sum(x => (long)x.uncompressedSize);
                bool changed = mipSelected && GenerateMipsForGUITexture(exp, options);
                if (capSelected)
                    changed |= CapGUITexture(exp, maxSize, options);
                if (changed)
                {
                    mipped++;
                    bytesBefore += before;
                    bytesAfter += new Texture2D(exp).Mips.Where(x => x.storageType != StorageTypes.empty).Sum(x => (long)x.uncompressedSize);
                }
            }

            MilanLog.Information($"Applied GUI mip/size/residency policy to {mipped} GUI texture(s) in {package.FileNameNoExtension} in {stopwatch.Elapsed.TotalSeconds:0.#}s " +
                                 $"(texture data {bytesBefore / 1048576.0:0.#} MiB -> {bytesAfter / 1048576.0:0.#} MiB)", customPrefix: LOG_CATEGORY);
            return mipped;
        }

        /// <summary>
        /// Maps each target path to its master, rejecting a config that cannot be applied in one pass.
        /// </summary>
        public static Dictionary<string, string> GetMasterByTarget(IReadOnlyDictionary<string, string[]>? masters = null, IReadOnlyDictionary<string, int>? sizeCaps = null)
        {
            masters ??= TextureMasters;
            sizeCaps ??= TextureSizeCaps;
            var byTarget = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
            foreach (var (master, targets) in masters)
            {
                foreach (var target in targets)
                {
                    if (target.Equals(master, StringComparison.OrdinalIgnoreCase))
                        throw new InvalidDataException($"GUI texture master {master} lists itself as a target.");
                    if (!byTarget.TryAdd(target, master))
                        throw new InvalidDataException($"GUI texture {target} has two masters: {byTarget[target]} and {master}.");
                }
            }
            foreach (var (target, master) in byTarget)
            {
                if (masters.ContainsKey(target))
                    throw new InvalidDataException($"GUI texture {target} is a target of {master} and a master itself; point its targets at {master}.");
                if (sizeCaps.ContainsKey(target))
                    throw new InvalidDataException($"GUI texture {target} has a size cap but is cloned from {master}; put the cap on the master.");
            }
            return byTarget;
        }

        /// <summary>A master's final image, read once and written over each of its targets.</summary>
        private sealed record MasterTexture(string Path, PropertyCollection Properties, List<(byte[] Data, int Width, int Height)> Mips, string Fingerprint);

        /// <summary>
        /// Replaces every copy of each target with its master's image, mips and texture properties. Run once the masters are final
        /// (upscaled, mipped and capped). A master is read from the first package, by path, that has it; <see cref="VerifyTexturesAreConsistent"/>
        /// checks its other copies.
        /// </summary>
        /// <returns>The packages that hold a master or a target, and how many target copies were changed.</returns>
        public static (List<string> Packages, int Changed) CloneTexturesFromMasters(IEnumerable<string> packageFiles, IReadOnlyDictionary<string, string[]>? masters = null)
        {
            masters ??= TextureMasters;
            var masterByTarget = GetMasterByTarget(masters);
            if (masterByTarget.Count == 0)
                return ([], 0);

            var masterFiles = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
            var targetFiles = new List<string>();
            var packages = new List<string>();
            foreach (var file in packageFiles.Order(StringComparer.OrdinalIgnoreCase))
            {
                using var header = MEPackageHandler.UnsafePartialLoad(file, _ => false);
                bool hasMaster = false, hasTarget = false;
                foreach (var exp in header.Exports.Where(e => e.ClassName == "Texture2D"))
                {
                    if (masters.ContainsKey(exp.InstancedFullPath))
                    {
                        masterFiles.TryAdd(exp.InstancedFullPath, file);
                        hasMaster = true;
                    }
                    hasTarget |= masterByTarget.ContainsKey(exp.InstancedFullPath);
                }
                if (hasTarget)
                    targetFiles.Add(file);
                if (hasMaster || hasTarget)
                    packages.Add(file);
            }

            var sources = new Dictionary<string, MasterTexture>(StringComparer.OrdinalIgnoreCase);
            foreach (var group in masterFiles.GroupBy(x => x.Value, StringComparer.OrdinalIgnoreCase))
            {
                using var package = MEPackageHandler.OpenMEPackage(group.Key, forceLoadFromDisk: true);
                foreach (var (path, _) in group)
                {
                    var exp = package.Exports.First(e => e.ClassName == "Texture2D" && e.InstancedFullPath.Equals(path, StringComparison.OrdinalIgnoreCase));
                    sources[path] = ReadMaster(exp);
                }
            }
            foreach (var master in masters.Keys.Where(master => !sources.ContainsKey(master)))
            {
                MilanLog.Warning($"GUI texture master {master} matched no Texture2D exports; its targets keep their own image", customPrefix: LOG_CATEGORY);
            }

            int changed = 0;
            var matchedTargets = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            foreach (var file in targetFiles)
            {
                using var package = MEPackageHandler.OpenMEPackage(file, forceLoadFromDisk: true);
                int packageChanged = 0;
                foreach (var exp in package.Exports.Where(e => e.ClassName == "Texture2D" && masterByTarget.ContainsKey(e.InstancedFullPath)).ToList())
                {
                    matchedTargets.Add(exp.InstancedFullPath);
                    if (sources.TryGetValue(masterByTarget[exp.InstancedFullPath], out var source) && CloneFromMaster(exp, source))
                        packageChanged++;
                }
                // A failure above leaves this package unsaved
                if (packageChanged > 0)
                {
                    package.Save(diskIOSyncLock: MilanShared.DiskIOSyncLock);
                    changed += packageChanged;
                }
            }
            foreach (var target in masterByTarget.Keys.Where(target => !matchedTargets.Contains(target)))
            {
                MilanLog.Warning($"GUI texture clone target {target} matched no Texture2D exports", customPrefix: LOG_CATEGORY);
            }

            MilanLog.Information($"Cloned {changed} GUI texture copies from {sources.Count} master(s) ({matchedTargets.Count}/{masterByTarget.Count} target paths matched)", customPrefix: LOG_CATEGORY);
            return (packages, changed);
        }

        private static MasterTexture ReadMaster(ExportEntry exp)
        {
            var texture = new Texture2D(exp);
            var live = texture.Mips.Where(mip => mip.storageType != StorageTypes.empty).ToList();
            if (live.Count == 0)
                throw new InvalidDataException($"GUI texture master {exp.InstancedFullPath} has no mip payloads.");
            if (live.Any(mip => !mip.IsPackageStored))
                throw new InvalidDataException($"GUI texture master {exp.InstancedFullPath} has mips in a TFC; masters must be package stored, so select them for GUI mipping.");

            var props = exp.GetProperties();
            if (props.OfType<ObjectProperty>().Any(prop => prop.Value != 0))
                throw new InvalidDataException($"GUI texture master {exp.InstancedFullPath} has object references, which cannot be copied to another package.");
            var mips = live.Select(mip => (Texture2D.GetTextureData(mip, exp.Game), mip.width, mip.height)).ToList();
            return new MasterTexture(exp.InstancedFullPath, props, mips, GetFingerprint(exp));
        }

        /// <summary>
        /// Writes a master's properties and mips over a target. The aspect ratio must match, as the movie stretches the image over the
        /// target's original shape. Other binary data stays the target's.
        /// </summary>
        /// <returns>True if the target changed.</returns>
        private static bool CloneFromMaster(ExportEntry exp, MasterTexture master)
        {
            var top = new Texture2D(exp).GetTopMip()
                      ?? throw new InvalidDataException($"GUI texture clone target {exp.InstancedFullPath} has no mips.");
            var (_, masterWidth, masterHeight) = master.Mips[0];
            if ((long)top.width * masterHeight != (long)top.height * masterWidth)
                throw new InvalidDataException($"GUI texture {exp.InstancedFullPath} is {top.width}x{top.height} but its master {master.Path} is {masterWidth}x{masterHeight}; their aspect ratios must match.");

            // Package-stored mips record their file offset, so compare properties and pixels rather than the whole export
            var live = new Texture2D(exp).Mips.Where(mip => mip.storageType != StorageTypes.empty).ToList();
            bool sameMips = live.Count == master.Mips.Count && live.All(mip => mip.IsPackageStored) &&
                            live.Zip(master.Mips).All(x => x.First.width == x.Second.Width && x.First.height == x.Second.Height &&
                                                           Texture2D.GetTextureData(x.First, exp.Game).AsSpan().SequenceEqual(x.Second.Data));
            var originalData = exp.Data.ToArray();
            int originalPropsEnd = exp.propsEnd();
            try
            {
                exp.WriteProperties(master.Properties);
                if (sameMips && exp.Data.AsSpan(0, exp.propsEnd()).SequenceEqual(originalData.AsSpan(0, originalPropsEnd)))
                {
                    exp.Data = originalData;
                    return false;
                }
                var binary = exp.GetBinaryData<UTexture2D>();
                binary.Mips = master.Mips.Select(mip => new UTexture2D.Texture2DMipMap(mip.Data, mip.Width, mip.Height)).ToList();
                exp.WriteBinary(binary);
                var fingerprint = GetFingerprint(exp);
                if (fingerprint != master.Fingerprint)
                    throw new InvalidDataException($"GUI texture {exp.InstancedFullPath} does not match its master {master.Path} after cloning: {fingerprint} vs {master.Fingerprint}");
            }
            catch
            {
                exp.Data = originalData;
                throw;
            }

            MilanLog.Information($"Cloned GUI texture {exp.InstancedFullPath} in {exp.FileRef.FileNameNoExtension} from {master.Path}: {top.width}x{top.height} -> {masterWidth}x{masterHeight}", customPrefix: LOG_CATEGORY);
            return true;
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
            return $"{props.GetProp<EnumProperty>("LODGroup")?.Value.Name}, NeverStream={props.GetProp<BoolProperty>("NeverStream")?.Value == true}, local={mips.All(mip => mip.IsPackageStored)}, {mips[0].width}x{mips[0].height}, original={props.GetProp<IntProperty>("OriginalSizeX")?.Value}x{props.GetProp<IntProperty>("OriginalSizeY")?.Value}, {mips.Count} mips, {texture.TextureFormat}, top {Texture2D.GetTextureCRC(exp):X8}, all {TextureCRC.Compute(all.ToArray()):X8}";
        }

        /// <summary>
        /// Drops oversized levels, generating a missing target level if necessary. A single-mip texture stays single-mip;
        /// an existing chain keeps its lower levels. Encoded levels already present are not recompressed.
        /// </summary>
        public static bool CapGUITexture(ExportEntry exp, int maxSize, MipGenerationOptions? options = null)
        {
            ArgumentOutOfRangeException.ThrowIfNegativeOrZero(maxSize);
            if (exp.ClassName != "Texture2D")
                throw new ArgumentException($"{exp.InstancedFullPath} is not a Texture2D.", nameof(exp));

            var texture = new Texture2D(exp);
            var live = texture.Mips.Where(mip => mip.storageType != StorageTypes.empty).ToList();
            if (live.Count == 0)
                throw new InvalidDataException($"GUI texture {exp.InstancedFullPath} has no mip payloads to cap.");
            var sourceTop = live[0];
            if (sourceTop.width <= maxSize && sourceTop.height <= maxSize)
                return false;

            int width = sourceTop.width, height = sourceTop.height;
            while (width > maxSize || height > maxSize)
            {
                width = Math.Max(1, width >> 1);
                height = Math.Max(1, height >> 1);
            }

            var props = exp.GetProperties();
            List<UTexture2D.Texture2DMipMap> retained;
            if (live.Any(mip => mip.width == width && mip.height == height))
            {
                // Read retained external payloads before changing the export or its TFC references.
                retained = live.Where(mip => mip.width <= width && mip.height <= height)
                    .Select(mip => new UTexture2D.Texture2DMipMap(Texture2D.GetTextureData(mip, exp.Game), mip.width, mip.height)).ToList();
            }
            else
            {
                var format = Image.getPixelFormatType(texture.TextureFormat);
                var image = new Image(new List<MipMap> { new(Texture2D.GetTextureData(sourceTop, exp.Game), sourceTop.width, sourceTop.height, format) }, format);
                bool dxt1Alpha = false;
                if (format == PixelFormat.DXT1 && props.GetProp<BoolProperty>("CompressionNoAlpha")?.Value != true)
                {
                    int decodedWidth = sourceTop.width, decodedHeight = sourceTop.height;
                    var argb = Image.convertRawToARGB(image.mipMaps[0].data, ref decodedWidth, ref decodedHeight, format);
                    dxt1Alpha = props.GetProp<EnumProperty>("CompressionSettings")?.Value.Name == "TC_OneBitAlpha";
                    for (int i = 3; !dxt1Alpha && i < argb.Length; i += 4)
                        dxt1Alpha = argb[i] < 255;
                }
                image.correctMips(format, dxt1Alpha, options: options ?? MipGenerationOptions.HighQuality);
                var levels = image.mipMaps.Where(mip => mip.origWidth <= width && mip.origHeight <= height);
                if (live.Count == 1)
                    levels = levels.Take(1);
                retained = levels.Select(mip => new UTexture2D.Texture2DMipMap(mip.data, mip.origWidth, mip.origHeight)).ToList();
            }

            if (retained.Count == 0)
                throw new InvalidDataException($"GUI texture {exp.InstancedFullPath} has no usable mip at or below {maxSize}.");
            var binary = exp.GetBinaryData<UTexture2D>();
            binary.Mips = retained;
            props.AddOrReplaceProp(new IntProperty(retained[0].SizeX, "SizeX"));
            props.AddOrReplaceProp(new IntProperty(retained[0].SizeY, "SizeY"));
            props.AddOrReplaceProp(new IntProperty(Math.Max(props.GetProp<IntProperty>("OriginalSizeX")?.Value ?? 0, sourceTop.width), "OriginalSizeX"));
            props.AddOrReplaceProp(new IntProperty(Math.Max(props.GetProp<IntProperty>("OriginalSizeY")?.Value ?? 0, sourceTop.height), "OriginalSizeY"));
            props.AddOrReplaceProp(new IntProperty(retained.Count - 1, "MipTailBaseIdx"));
            props.AddOrReplaceProp(new BoolProperty(true, "NeverStream"));
            props.RemoveNamedProperty("TextureFileCacheName");
            props.RemoveNamedProperty("TFCFileGuid");
            props.RemoveNamedProperty("TFCFileGuidHiRes");
            var originalData = exp.Data.ToArray();
            try
            {
                exp.WriteProperties(props);
                exp.WriteBinary(binary);
                Texture2D.UpdateLODBiasForTexture(exp);
            }
            catch
            {
                exp.Data = originalData;
                throw;
            }
            MilanLog.Information($"Capped GUI texture {exp.InstancedFullPath} in {exp.FileRef.FileNameNoExtension}: {sourceTop.width}x{sourceTop.height} -> {retained[0].SizeX}x{retained[0].SizeY}", customPrefix: LOG_CATEGORY);
            return true;
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
