using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Unreal;
using ProjectMilanCore;
using ProjectMilanCore.Config;
using ProjectMilanCore.Textures;

namespace ProjectMilan.Pipelines.Startups
{
    /// <summary>
    /// Builds seek free GUI image packages from source art (.dds/.tga/.png) under
    /// Startups\NonStartup\ImagePackages. Each folder there becomes one package file named
    /// GUI_Images_MP&lt;FolderName&gt;.pcc, and the subfolders inside it become the forced export Package tree its
    /// images live under. Every image is dynamic load mapped to its file, so config can refer to it by path:
    /// <code>ImagePackages\Online\ChallengeBanners\zaeed.dds -> ChallengeBanners.zaeed in GUI_Images_MPOnline</code>
    /// The file name is not part of the object path - only the folders inside are - which is how the game's own
    /// GUI image packages work too (GUI_MPImages_SMP.Challenge.* lives in GUI_MPChallengeImages).
    /// </summary>
    internal static class ImagePackageBuilder
    {
        private const string LOG_CATEGORY = @"MILAN-ImagePackages";

        /// <summary>
        /// Prefix of every generated package file; the source folder name goes after it.
        /// </summary>
        public const string PackageFilePrefix = "GUI_Images_MP";

        public static string SourceRoot => Path.Combine(MilanShared.PipelineRoot, "Startups", "NonStartup", "ImagePackages");

        /// <summary>
        /// Object path of every image our packages contain, whether built this run or loaded back from a
        /// restored checkpoint by <see cref="RehydrateFromCheckpoint"/>. Empty until one of those has run, so
        /// anything checking against it must come after the NonStartup stage.
        /// </summary>
        public static IReadOnlySet<string> BuiltImages { get; private set; } = new HashSet<string>(StringComparer.OrdinalIgnoreCase);

        /// <summary>
        /// Builds every image package folder into <paramref name="outputFolder"/> and registers the dynamic load
        /// mappings for its images into the active config bundle. The caller commits the bundle.
        /// </summary>
        /// <returns>Object path of every image that was built, so config registrations can check theirs exist.</returns>
        public static IReadOnlySet<string> BuildImagePackages(string outputFolder)
        {
            var builtImages = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            BuiltImages = builtImages;
            if (!Directory.Exists(SourceRoot))
                return builtImages;

            Directory.CreateDirectory(outputFolder);
            foreach (var sourceDir in Directory.GetDirectories(SourceRoot))
            {
                BuildImagePackage(sourceDir, outputFolder, builtImages);
            }

            return builtImages;
        }

        /// <summary>
        /// Replays the process-global state <see cref="BuildImagePackages"/> publishes, from the packages a restored
        /// checkpoint already contains. The dynamic load mappings come back with the config bundle (ModBuild's
        /// rehydration), so only <see cref="BuiltImages"/> is left - read from the packages themselves rather than the
        /// source folder, since the source may have changed since the checkpoint was taken.
        /// </summary>
        public static void RehydrateFromCheckpoint(string outputFolder)
        {
            var builtImages = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            BuiltImages = builtImages;
            if (!Directory.Exists(outputFolder))
            {
                // Can happen if the checkpoint was built with RunNonStartupPipeline disabled.
                MilanLog.Warning($"Restored checkpoint has no {Path.GetFileName(outputFolder)} folder; image packages were not rehydrated.", customPrefix: LOG_CATEGORY);
                return;
            }

            foreach (var packagePath in Directory.EnumerateFiles(outputFolder, $"{PackageFilePrefix}*.pcc", SearchOption.TopDirectoryOnly))
            {
                using var package = MEPackageHandler.OpenMEPackage(packagePath);
                foreach (var texture in package.Exports.Where(x => x.ClassName == "Texture2D"))
                {
                    builtImages.Add(texture.InstancedFullPath);
                }
            }

            MilanLog.Information($"Rehydrated {builtImages.Count} checkpointed image(s)", customPrefix: LOG_CATEGORY);
        }

        /// <summary>
        /// Returns <paramref name="objectPath"/> unchanged, logging an error if no image package built it - so a
        /// reference to one of our images fails loudly at build time if the source image is renamed or moved,
        /// instead of silently pointing at nothing in game.
        /// </summary>
        /// <param name="objectPath">Object path of the image, as built: its folders inside the package folder, then its file name.</param>
        /// <param name="usedBy">What refers to the image, for the error message.</param>
        public static string Require(string objectPath, string usedBy)
        {
            if (!BuiltImages.Contains(objectPath))
            {
                MilanLog.Error($"Image {objectPath} for {usedBy} was not built - is it missing from {Path.GetRelativePath(MilanShared.PipelineRoot, SourceRoot)}?", customPrefix: LOG_CATEGORY);
            }

            return objectPath;
        }

        private static void BuildImagePackage(string sourceDir, string outputFolder, HashSet<string> builtImages)
        {
            var packageName = $"{PackageFilePrefix}{Path.GetFileName(sourceDir)}";
            MilanLog.Information($"Building image package {packageName}", customPrefix: LOG_CATEGORY);
            var package = MEPackageHandler.CreateAndOpenPackage(Path.Combine(outputFolder, $"{packageName}.pcc"), MEGame.LE3);

            foreach (var file in Directory.EnumerateFiles(sourceDir, "*", SearchOption.AllDirectories).Order(StringComparer.OrdinalIgnoreCase))
            {
                var relativePath = Path.GetRelativePath(sourceDir, file);
                if (!GUITextureImporter.IsSupportedImage(file))
                {
                    MilanLog.Warning($"  Skipping {relativePath}: not a supported image type ({string.Join(", ", GUITextureImporter.SupportedExtensions)})", customPrefix: LOG_CATEGORY);
                    continue;
                }

                var groups = Path.GetDirectoryName(relativePath)!.Split(Path.DirectorySeparatorChar, StringSplitOptions.RemoveEmptyEntries);
                if (groups.Length == 0)
                {
                    // A top level texture has no forced export package to dynamic load it by
                    MilanLog.Error($"  Skipping {relativePath}: images must be in at least one subfolder, which becomes the package they load under", customPrefix: LOG_CATEGORY);
                    continue;
                }

                var textureName = Path.GetFileNameWithoutExtension(file);
                var objectPath = $"{string.Join(".", groups)}.{textureName}";
                if (package.FindExport(objectPath) != null)
                {
                    MilanLog.Error($"  Skipping {relativePath}: {objectPath} already exists in {packageName} - is there another image with the same name?", customPrefix: LOG_CATEGORY);
                    continue;
                }

                IEntry? parent = null;
                foreach (var group in groups)
                {
                    parent = package.CreatePackageExport(group, parent); // ForcedExport by default, reuses existing
                }

                var texture = GUITextureImporter.AddGUITexture(package, parent, textureName, file);
                DynamicLoadMappingRegistration.RegisterDynamicLoadMapping(texture.InstancedFullPath, packageName);
                builtImages.Add(texture.InstancedFullPath);
                MilanLog.Information($"  Added {texture.InstancedFullPath} ({texture.GetProperty<EnumProperty>("Format")?.Value})", customPrefix: LOG_CATEGORY);
            }

            package.Save();
        }
    }
}
