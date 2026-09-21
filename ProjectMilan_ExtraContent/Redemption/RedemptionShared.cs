using System;
using System.Collections.Generic;
using System.Linq;
using System.Security.AccessControl;
using System.Text;
using System.Threading.Tasks;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.TLK;
using LegendaryExplorerCore.TLK.ME2ME3;
using LegendaryExplorerCore.Textures;
using LegendaryExplorerCore.Unreal;
using LegendaryExplorerCore.Unreal.Classes;
using ProjectMilan;
using ProjectMilan_ExtraContent.Redemption.Levels;
using ProjectMilanCore;

namespace ProjectMilan_ExtraContent.Redemption
{
    internal class RedemptionShared
    {
        /// <summary>
        /// Base name of the package that stores the map images
        /// </summary>
        internal const string MAP_IMAGE_PACKAGE = "SFXMapImages_Redemption";

        /// <summary>
        /// In-package top level item. Dynamic load mapping seems to require this, unclear why - seems to be something related to how GUI assets load
        /// </summary>
        internal const string DLM_MAP_PACKAGE_EXPORT_NAME = "GUI_MPImages_Redemption";

        public static string GetMapBaseName(string biopName)
        {
            return biopName.Substring("BioP_MP".Length);
        }

        private static IMEPackage _mapImagesPackage = null;
        public static IMEPackage GetMapImagesPackage()
        {
            if (_mapImagesPackage == null)
            {
                _mapImagesPackage = MEPackageHandler.CreateAndOpenPackage(Path.Combine(MilanPipelinesShared.OutputModPath, @"CookedPCConsole", $"{MAP_IMAGE_PACKAGE}.pcc"), MEGame.LE3); // Use LE3 or TFC compactor dies
            }
            return _mapImagesPackage;
        }

        /// <summary>
        /// Saves and discards the IMEPackage for the map images package
        /// </summary>
        public static void SaveMapImagesPackage()
        {
            var package = GetMapImagesPackage();
            if (package.Exports.Count > 0)
            {
                // Referencer is required so resynth doesn't wipe it all out
                package.AddObjectsToReferencer(package.Exports.Where(x=>x.IsTexture()).ToList());
                package.Save();
            }

            _mapImagesPackage = null;
        }

        /// <summary>
        /// Add information to config for this map. The map name must be BioP_MP[MapName]. New StrRef IDs are
        /// assigned via MilanPipelinesShared.AssignTLK rather than reusing the OT mod's own IDs, which are far
        /// too high to be safe for this project's own content. The map ID itself and its music event are
        /// assigned automatically by MapListConfigWriter.
        /// </summary>
        /// <param name="info"></param>
        public static void AddLevelToConfig(ECLevelInfo info)
        {
            var entry = new MapListEntry
            {
                PackageName = info.MapName,
                PrettyNameStrRefId = MilanPipelinesShared.AssignTLK(info.LevelNameString),
                DescriptionStrRefId = MilanPipelinesShared.AssignTLK(info.LevelDescriptionString),
                GAWMapPositionX = (int)info.GAWMapPosition.X,
                GAWMapPositionY = (int)info.GAWMapPosition.Y,
                GAWMapSubtitleStrRefId = MilanPipelinesShared.AssignTLK(info.GAWMapSubtitle),
                ImageObjectPath = $"{DLM_MAP_PACKAGE_EXPORT_NAME}.OptMap{GetMapBaseName(info.MapName)}",
                ImageSeekFreePackageName = MAP_IMAGE_PACKAGE,
            };

            MapListConfigWriter.RegisterMap(entry);
        }

        internal static void AddNewLevelBannerImage(string levelName, string logCategory)
        {
            // Look in Assets/LevelBanners/<levelName>.png for source, will be 512x128 PNG.
            // Uses the constants for map image package file and the in-package package,
            // feeds to AddNewGUIImage()
            var sourcePng = Path.Combine(RedemptionPipeline.PipelineRoot, "Assets", "LevelBanners", $"{levelName}.png");
            if (!File.Exists(sourcePng))
            {
                MilanLog.Error($"No level banner image found for {levelName} at {sourcePng}", customPrefix: logCategory);
                return;
            }

            var package = GetMapImagesPackage();
            var inPackageParent = package.CreatePackageExport(DLM_MAP_PACKAGE_EXPORT_NAME);
            AddNewGUIImage(package, inPackageParent, $"OptMap{levelName}", sourcePng);
        }

        internal static ExportEntry AddNewGUIImage(IMEPackage package, IEntry parent, string textureName, string sourcePngPath, PixelFormat pixelFormat = PixelFormat.DXT1, NameReference textureGroup = default)
        {
            // Generic - takes a package file, a source texture, and a location to create it in the package,
            // generates the texture, and adds it to the object referencer
            if (textureGroup.Name == null)
            {
                textureGroup = new NameReference("TEXTUREGROUP_UI");
            }

            // Use TexConverter's file loader rather than Image's direct PNG decoder. The
            // direct ImageSharp Rgba32 byte layout does not match the byte order expected
            // by the texture compressor/exporter and swaps red and blue during round-trip.
            var image = Image.LoadFromFile(sourcePngPath, pixelFormat);
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
