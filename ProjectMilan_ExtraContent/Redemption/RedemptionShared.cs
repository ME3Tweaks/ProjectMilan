using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;
using System.Security.AccessControl;
using System.Text;
using System.Threading.Tasks;
using LegendaryExplorerCore.Coalesced;
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
        /// The current mastermaplist id. This should be tuned when we know exactly where to start when building extra map content.
        /// </summary>
        private static int? CurrentMapId = 30;

        /// <summary>
        /// Base name of the package that stores the map images
        /// </summary>
        internal const string MAP_IMAGE_PACKAGE = "SFXMapImages_Redemption";

        /// <summary>
        /// In-package top level item. Dynamic load mapping seems to require this, unclear why - seems to be something related to how GUI assets load
        /// </summary>
        internal const string DLM_MAP_PACKAGE_EXPORT_NAME = "GUI_MPImages_Redemption";

        private static string BuildDLMForImage(string objectName)
        {
            return $"(ObjectName=\"{DLM_MAP_PACKAGE_EXPORT_NAME}.{objectName}\", SeekFreePackageName=\"{MAP_IMAGE_PACKAGE}\")";
        }

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
        /// Add information to config for this map. The map name must be BioP_MP[MapName].
        /// </summary>
        /// <param name="biop"></param>
        public static void AddLevelToConfig(ECLevelInfo info)
        {
            #region ENGINE
            {
                var engine = MilanPipelinesShared.ConfigBundle.GetAsset("BioEngine");
                var sfxengine = engine.GetOrAddSection("sfxgame.sfxengine");

                // Add level image for GUI
                var objName = GetMapBaseName(info.MapName);
                objName = "OptMap" + objName;
                sfxengine.AddEntry(new CoalesceProperty("dynamicloadmapping", new CoalesceValue(BuildDLMForImage(objName), CoalesceParseAction.AddUnique)));
            }
            #endregion

            #region GAME

            {
                var game = MilanPipelinesShared.ConfigBundle.GetAsset("BioGame");
                var onlinegamesettings = game.GetOrAddSection("sfxonlinefoundation.sfxonlinegamesettings");

                // Add to availablemaps
                onlinegamesettings.AddEntry(new CoalesceProperty("availablemaps", new CoalesceValue(info.MapName, CoalesceParseAction.AddUnique)));

                // Add to mastermaplist
                onlinegamesettings.AddEntry(new CoalesceProperty("mastermaplist", new CoalesceValue(BuildMasterMapEntry(info), CoalesceParseAction.AddUnique)));
            }

            #endregion

            CurrentMapId++;
            if (CurrentMapId > 64)
            {
                // This is not supported due to 64 bit replication... I think? It's a bitmask
                Debugger.Break();
            }
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

        private static string BuildMasterMapEntry(ECLevelInfo info)
        {
            return $"(ID={CurrentMapId}, " +
                   $"PackageName=\"{info.MapName}\", " +
                   $"PrettyName={MilanPipelinesShared.AssignTLK(info.LevelNameString)}, " +
                   $"Description={MilanPipelinesShared.AssignTLK(info.LevelDescriptionString)}, " +
                   $"Image=\"{DLM_MAP_PACKAGE_EXPORT_NAME}.OptMap{GetMapBaseName(info.MapName)}\", " +
                   $"GalaxyAtWarMapPosition=(X={info.GAWMapPosition.X},Y={info.GAWMapPosition.Y}), " +
                   $"GalaxyAtWarMapSubtitle={MilanPipelinesShared.AssignTLK(info.GAWMapSubtitle)}, " +
                   $"MusicEventName=\"{GetMusicEventName()}\")";
        }

        private static int MusicEventNameIdx = 4; // See comment below.

        private static string[] MusicEvents =
        [
            "Set_mus_map_mpslum",
            "Set_mus_map_mpdish",
            "Set_mus_map_mprctr",
            "Set_mus_map_mpnov",
            "Set_mus_map_mptowr", // Last official map is 'Nov2' which uses mpnov.
            "Set_mus_map_mpcer",
        ];

        /// <summary>
        /// Gets the name of the music event. It loops around the array.
        /// </summary>
        /// <returns></returns>
        private static string GetMusicEventName()
        {
            return MusicEvents[MusicEventNameIdx++ % MusicEvents.Length];
        }
    }
}
