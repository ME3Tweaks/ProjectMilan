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
using ProjectMilanCore.Config;
using ProjectMilanCore.Textures;

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
            // Look in Assets/LevelBanners/<levelName>.(dds|tga|png) for source, will be 512x128.
            // Uses the constants for map image package file and the in-package package.
            var levelBannersDir = Path.Combine(RedemptionPipeline.PipelineRoot, "Assets", "LevelBanners");
            var sourceImage = GUITextureImporter.FindImage(levelBannersDir, levelName);
            if (sourceImage == null)
            {
                MilanLog.Error($"No level banner image found for {levelName} in {levelBannersDir}", customPrefix: logCategory);
                return;
            }

            var package = GetMapImagesPackage();
            var inPackageParent = package.CreatePackageExport(DLM_MAP_PACKAGE_EXPORT_NAME);
            GUITextureImporter.AddGUITexture(package, inPackageParent, $"OptMap{levelName}", sourceImage, PixelFormat.DXT1);
        }
    }
}
