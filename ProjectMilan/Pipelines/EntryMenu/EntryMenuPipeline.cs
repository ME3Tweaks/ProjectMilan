using System;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Textures;
using LegendaryExplorerCore.Unreal;
using LegendaryExplorerCore.Unreal.Classes;
using ProjectMilan.Pipelines.Startups;
using ProjectMilanCore;
using ProjectMilanCore.Textures;

namespace ProjectMilan.Pipelines.EntryMenu
{
    /// <summary>
    /// Patches a supplied LE3/LMP EntryMenu with the branded splash movie and its resident GUI texture.
    /// </summary>
    internal static class EntryMenuPipeline
    {
        private const string LogCategory = "MILAN-EntryMenu";
        private const string MoviePath = "GUI_SF_Splash.Splash";
        // Match the ordinary external-image filename in Splash.gfx (not a runtime replacement linkage).
        private const string LogoName = "Splash_ProjectMilanLogo";
        private const string LegacyLogoName = "ProjectMilanLogo";
        private static string SourceRoot => Path.Combine(MilanShared.PipelineRoot, "EntryMenu");

        public static void RunPipeline()
        {
            using var entryMenuPackage = MilanShared.GetLE3Package("EntryMenu.pcc");
            BuildPackage(entryMenuPackage,
                Path.Combine(Program.Settings.OutputModPath, "CookedPCConsole", "EntryMenu", "EntryMenu.pcc"),
                Path.Combine(SourceRoot, "Assets"));
        }

        /// <summary>Builds a separate output from the given package, retaining its other assets.</summary>
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
                logo.AddToObjectReferencer();
            }

            // Promotional enables Scaleform's mip filtering; NeverStream keeps the entire chain resident.
            GUITextureMipper.GenerateMipsForGUITexture(logo);
            if (!references.Any(reference => reference.Value == logo.UIndex))
                references.Add(new ObjectProperty(logo.UIndex));
            movie.WriteProperty(references);
            movie.WriteProperty(new ImmutableByteArrayProperty(movieData, "RawData"));

            MilanLog.Information($"Patched {MoviePath} and {texturePath} (2048x1024, {new Texture2D(logo).Mips.Count} resident mips)",
                customPrefix: LogCategory);
        }
    }
}
