using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Textures;
using LegendaryExplorerCore.Unreal;
using LegendaryExplorerCore.Unreal.Classes;

namespace ProjectMilanCore.Textures
{
    /// <summary>
    /// Builds GUI textures (challenge banners, store pack images, map/enemy selector images) from source art on
    /// disk. Shared by the NonStartup image package pipeline and ProjectMilan_ExtraContent's Redemption/Rejects
    /// GUI images, so every GUI image we add goes in the same way - unmipped, package stored, TEXTUREGROUP_UI and
    /// non-sRGB, matching the game's own GUI images (e.g. GUI_MPImages_SMP.Challenge.*).
    /// </summary>
    public static class GUITextureImporter
    {
        /// <summary>
        /// Source image extensions that can be imported - same set as TFCBuild's upscale importer.
        /// </summary>
        public static readonly string[] SupportedExtensions = [".dds", ".tga", ".png"];

        /// <summary>
        /// Pixel format non-DDS sources are encoded to when the caller doesn't ask for one. DXT5 as GUI images
        /// almost always carry real alpha.
        /// </summary>
        public const PixelFormat DefaultFormat = PixelFormat.DXT5;

        public static bool IsSupportedImage(string path) =>
            SupportedExtensions.Contains(Path.GetExtension(path), StringComparer.OrdinalIgnoreCase);

        /// <summary>
        /// Finds &lt;baseName&gt; in a directory under any supported extension, or null if there isn't one.
        /// </summary>
        public static string? FindImage(string directory, string baseName) =>
            SupportedExtensions.Select(ext => Path.Combine(directory, baseName + ext)).FirstOrDefault(File.Exists);

        /// <summary>
        /// Loads a source image in the given pixel format. A DDS already in that format (or any DDS, when
        /// <paramref name="targetFormat"/> is <see cref="PixelFormat.Unknown"/>) is loaded as-is, so pre-compressed
        /// art isn't decoded and re-encoded with more compression loss.
        /// </summary>
        public static Image LoadImage(string sourcePath, PixelFormat targetFormat = PixelFormat.Unknown)
        {
            if (Path.GetExtension(sourcePath).Equals(".dds", StringComparison.OrdinalIgnoreCase))
            {
                var dds = new Image(sourcePath);
                if (targetFormat == PixelFormat.Unknown || dds.pixelFormat == targetFormat)
                    return dds;
            }

            // Use TexConverter's file loader rather than Image's direct PNG decoder. The
            // direct ImageSharp Rgba32 byte layout does not match the byte order expected
            // by the texture compressor/exporter and swaps red and blue during round-trip.
            return Image.LoadFromFile(sourcePath, targetFormat == PixelFormat.Unknown ? DefaultFormat : targetFormat);
        }

        /// <summary>
        /// Creates a GUI texture export from a source image and adds it to the package's object referencer (so
        /// resynthesis doesn't strip it).
        /// </summary>
        /// <param name="package">Package to create the texture in.</param>
        /// <param name="parent">Parent export, e.g. a forced export Package for dynamic-load-mapped images. Null for a top level texture.</param>
        /// <param name="textureName">Object name of the new texture.</param>
        /// <param name="sourcePath">Source .dds/.tga/.png.</param>
        /// <param name="pixelFormat">Format to store the texture in. Unknown keeps a DDS's own format, and uses <see cref="DefaultFormat"/> for anything else.</param>
        /// <param name="textureGroup">LODGroup. Defaults to TEXTUREGROUP_UI.</param>
        public static ExportEntry AddGUITexture(IMEPackage package, IEntry? parent, string textureName, string sourcePath, PixelFormat pixelFormat = PixelFormat.Unknown, NameReference textureGroup = default)
        {
            if (textureGroup.Name == null)
            {
                textureGroup = new NameReference("TEXTUREGROUP_UI");
            }

            var image = LoadImage(sourcePath, pixelFormat);
            pixelFormat = image.pixelFormat;
            var sizeX = image.mipMaps[0].width;
            var sizeY = image.mipMaps[0].height;

            // Unmipped, package-stored texture - matches how the game's own GUI images are laid out
            var texExport = Texture2D.CreateTexture(package, NameReference.FromInstancedString(textureName), sizeX, sizeY, pixelFormat, mipped: false, parent: parent, textureGroup: textureGroup);

            var props = texExport.GetProperties();
            props.AddOrReplaceProp(new BoolProperty(false, "SRGB"));
            props.AddOrReplaceProp(new IntProperty(sizeX, "OriginalSizeX"));
            props.AddOrReplaceProp(new IntProperty(sizeY, "OriginalSizeY"));
            texExport.WriteProperties(props);

            var texture = new Texture2D(texExport);
            texture.Replace(image, props, isPackageStored: true, forcedNewFormat: pixelFormat);

            texExport.AddToObjectReferencer();

            return texExport;
        }
    }
}
