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
        /// Builds every image package folder into <paramref name="outputFolder"/> and registers the dynamic load
        /// mappings for its images into the active config bundle. The caller commits the bundle.
        /// </summary>
        /// <returns>Object path of every image that was built, so config registrations can check theirs exist.</returns>
        public static IReadOnlySet<string> BuildImagePackages(string outputFolder)
        {
            var builtImages = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            if (!Directory.Exists(SourceRoot))
                return builtImages;

            Directory.CreateDirectory(outputFolder);
            foreach (var sourceDir in Directory.GetDirectories(SourceRoot))
            {
                BuildImagePackage(sourceDir, outputFolder, builtImages);
            }

            return builtImages;
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
