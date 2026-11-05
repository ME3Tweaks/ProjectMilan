using System.Numerics;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Textures;
using LegendaryExplorerCore.Unreal;
using LegendaryExplorerCore.Unreal.BinaryConverters;
using LegendaryExplorerCore.Unreal.Classes;
using ProjectMilan.Pipelines.Startups;
using ProjectMilanCore;
using ProjectMilanCore.Textures;

namespace ProjectMilan.Pipelines.EntryMenu
{
    /// <summary>
    /// Patches a supplied LE3/LMP EntryMenu with the branded splash movie and its resident GUI texture, and swaps the
    /// splash and main menu game logo for the Legendary Edition Multiplayer one.
    /// </summary>
    internal static class EntryMenuPipeline
    {
        private const string LogCategory = "MILAN-EntryMenu";
        private const string MoviePath = "GUI_SF_Splash.Splash";

        private const string LogoName = "Splash_ProjectMilanLogo";
        private const string LegacyLogoName = "ProjectMilanLogo";
        private static string SourceRoot => Path.Combine(MilanShared.PipelineRoot, "EntryMenu");

        /// <summary>
        /// The game logo textures drawn by the splash and main menu movies
        /// </summary>
        private static readonly string[] GameLogoTexturePaths = ["GUI_SF_Splash.Splash_I2", "GUI_SF_MainMenu.MainMenu_I1"];
        private const string GameLogoSourceName = "LMP_Graphic_2x1_forReals.png";
        private const int GameLogoWidth = 2048;

        public static void RunPipeline()
        {
            using var entryMenuPackage = MilanShared.GetLE3Package("EntryMenu.pcc");
            BuildPackage(entryMenuPackage,
                Path.Combine(Program.Settings.OutputModPath, "CookedPCConsole", "EntryMenu", "EntryMenu.pcc"),
                Path.Combine(SourceRoot, "Assets"));
        }

        /// <summary>
        /// Builds a separate output from the given package, retaining its other assets.
        /// </summary>
        public static void BuildPackage(IMEPackage package, string outputPath, string assetsDirectory)
        {
            PatchPackage(package, assetsDirectory);
            Directory.CreateDirectory(Path.GetDirectoryName(Path.GetFullPath(outputPath))!);
            package.Save(outputPath);
            MilanLog.Information($"Built {outputPath}", customPrefix: LogCategory);
        }

        /// <summary>
        /// Updates the movie and adds or replaces its logo texture. Reapplying does not duplicate exports or references.
        /// The movie embeds just the Bangers glyphs used by ME3Tweaks; both logos belong to StatementMC under LegalMC.
        /// </summary>
        public static void PatchPackage(IMEPackage package, string assetsDirectory)
        {
            if (package.Game is not (MEGame.LE3 or MEGame.LMP))
                throw new InvalidDataException($"EntryMenu branding requires LE3 or LMP, got {package.Game} in {package.FilePath}.");

            var movie = package.FindExport(MoviePath);
            if (movie?.ClassName != "GFxMovieInfo")
                throw new InvalidDataException($"{package.FilePath} has no GFxMovieInfo {MoviePath}.");
            var references = movie.GetProperty<ArrayProperty<ObjectProperty>>("References")
                ?? throw new InvalidDataException($"{MoviePath} has no texture References array.");
            var movieData = File.ReadAllBytes(Path.Combine(assetsDirectory, "Splash.gfx"));
            var logoPath = Path.Combine(assetsDirectory, "ProjectMilanLogo.png");
            var image = GUITextureImporter.LoadImage(logoPath, PixelFormat.ARGB);
            if (image.mipMaps[0].width != 2048 || image.mipMaps[0].height != 1024)
                throw new InvalidDataException("ProjectMilanLogo.png must be 2048x1024 (4x the GFX's 512x256 logical canvas).");

            var texturePath = $"{movie.Parent.InstancedFullPath}.{LogoName}";
            var logo = package.FindExport(texturePath);
            if (logo == null)
            {
                // Upgrade packages built by the earlier pipeline without leaving a duplicate texture or reference.
                logo = package.FindExport($"{movie.Parent.InstancedFullPath}.{LegacyLogoName}");
                if (logo != null)
                {
                    if (logo.ClassName != "Texture2D")
                        throw new InvalidDataException($"{logo.InstancedFullPath} exists but is not a Texture2D.");
                    logo.ObjectName = new NameReference(LogoName);
                }
            }
            if (logo == null)
            {
                logo = GUITextureImporter.AddGUITexture(package, movie.Parent, LogoName, logoPath, PixelFormat.ARGB);
            }
            else
            {
                if (logo.ClassName != "Texture2D")
                    throw new InvalidDataException($"{texturePath} exists but is not a Texture2D.");
                var properties = logo.GetProperties();
                properties.AddOrReplaceProp(new BoolProperty(false, "SRGB"));
                properties.AddOrReplaceProp(new IntProperty(2048, "OriginalSizeX"));
                properties.AddOrReplaceProp(new IntProperty(1024, "OriginalSizeY"));
                new Texture2D(logo).Replace(image, properties, isPackageStored: true, forcedNewFormat: PixelFormat.ARGB,
                    forceMipping: true, mipOptions: MipGenerationOptions.HighQuality);
            }
            logo.AddToObjectReferencer();

            // Promotional enables Scaleform's mip filtering; NeverStream keeps the entire chain resident.
            GUITextureMipper.GenerateMipsForGUITexture(logo);
            if (!references.Any(reference => reference.Value == logo.UIndex))
                references.Add(new ObjectProperty(logo.UIndex));
            movie.WriteProperty(references);
            movie.WriteProperty(new ImmutableByteArrayProperty(movieData, "RawData"));

            MilanLog.Information($"Patched {MoviePath} and {texturePath} (2048x1024, {new Texture2D(logo).Mips.Count} resident mips)",
                customPrefix: LogCategory);

            ReplaceGameLogos(package, assetsDirectory);
        }

        /// <summary>
        /// Replaces the Mass Effect 3 logo on the splash and main menu with the Legendary Edition Multiplayer logo. The art is used at
        /// its own aspect ratio, scaled down to <see cref="GameLogoWidth"/> wide if it is larger.
        /// </summary>
        private static void ReplaceGameLogos(IMEPackage package, string assetsDirectory)
        {
            var source = GUITextureImporter.LoadImage(Path.Combine(assetsDirectory, GameLogoSourceName), PixelFormat.ARGB);
            var top = source.mipMaps[0];
            if (!BitOperations.IsPow2(top.width) || !BitOperations.IsPow2(top.height))
            {
                // Input is wrong size
                throw new InvalidDataException($"{GameLogoSourceName} must have power of two dimensions, got {top.width}x{top.height}.");
            }
            if (top.width > GameLogoWidth)
            {
                source.correctMips(PixelFormat.ARGB, options: MipGenerationOptions.HighQuality);
                top = source.mipMaps.First(mip => mip.origWidth == GameLogoWidth);
            }

            foreach (var path in GameLogoTexturePaths)
            {
                var logo = package.FindExport(path);

                // Replace UI mip with our top mip we want
                var binary = logo.GetBinaryData<UTexture2D>();
                var topMip = binary.Mips.First(mip => mip.StorageType != StorageTypes.empty);
                topMip.SizeX = top.origWidth;
                topMip.SizeY = top.origHeight;
                binary.Mips = [topMip];
                logo.WriteBinary(binary);

                // Update properties to match the new texture
                // Also mip it so it works at lower resolutions
                var properties = logo.GetProperties();
                properties.AddOrReplaceProp(new IntProperty(top.origWidth, "SizeX"));
                properties.AddOrReplaceProp(new IntProperty(top.origHeight, "SizeY"));
                properties.AddOrReplaceProp(new IntProperty(top.origWidth, "OriginalSizeX"));
                properties.AddOrReplaceProp(new IntProperty(top.origHeight, "OriginalSizeY"));
                new Texture2D(logo).Replace(new Image([new MipMap(top.data.ToArray(), top.origWidth, top.origHeight, PixelFormat.ARGB)], PixelFormat.ARGB),
                    properties, isPackageStored: true, forceMipping: true, mipOptions: MipGenerationOptions.HighQuality);
                GUITextureMipper.GenerateMipsForGUITexture(logo);
                
                MilanLog.Information($"Update entrymenu logo", customPrefix: LogCategory);
            }
        }
    }
}
