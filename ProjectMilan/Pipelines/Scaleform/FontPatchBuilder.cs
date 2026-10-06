using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Unreal;
using ProjectMilan.Pipelines.Mod.BaseDelta;
using ProjectMilanCore;

namespace ProjectMilan.Pipelines.Scaleform;

/// <summary>
/// Generates BaseDelta PropertyUpdate SWFs for LE3's GUI font packages: LE3's font library plus the U+2623 hazard
/// glyph that ME3's MP4 font libraries added for hazard map names (e.g. TLK 772316). LE3 shipped neither the glyph in
/// its font libraries nor MP4's font overrides, so the strings render with the symbol missing.
/// </summary>
internal static class FontPatchBuilder
{
    private const string LogCategory = @"MILAN-Fonts";
    private const int HazardCodePoint = 0x2623;

    /// <summary>
    /// Builds the patched movie for <paramref name="packageName"/>.pcc's <paramref name="movieName"/>.gfxfonts, taking
    /// the glyph from ME3's {packageName}_DLC.pcc / {movieName}_DLC.gfxfonts (MP4 and MP5 ship identical copies). LE3's
    /// library is kept as the base - it has more glyphs than ME3's (thousands more for the non-JPN fonts) - and its fonts share the donor's names
    /// and metrics.
    /// </summary>
    public static void Build(string packageName, string movieName)
    {
        byte[] target;
        using (var package = MEPackageHandler.OpenMEPackage(BaseDeltaHandler.GetVanillaCookedFilePath($"{packageName}.pcc")))
        {
            target = GetMovieData(package, $"{movieName}.gfxfonts");
        }

        byte[] donor;
        using (var package = MilanShared.GetME3Package($"{packageName}_DLC.pcc"))
        {
            if (package == null)
            {
                MilanLog.Fatal($"Could not find ME3's {packageName}_DLC.pcc (DLC_CON_MP4) to take the hazard glyph from - this is a fatal error.", customPrefix: LogCategory);
                Environment.Exit(1);
            }
            donor = GetMovieData(package, $"{movieName}_DLC.gfxfonts");
        }

        byte[] patched;
        try
        {
            patched = GfxFontGlyphSplicer.AddGlyph(donor, target, HazardCodePoint, message => MilanLog.Information($"{movieName}: {message}", customPrefix: LogCategory));
        }
        catch (Exception ex)
        {
            MilanLog.Fatal($"Failed to add U+{HazardCodePoint:X4} to {movieName}: {ex.Message} - this is a fatal error.", customPrefix: LogCategory);
            Environment.Exit(1);
            throw;
        }

        var outputPath = Path.Combine(MilanShared.PipelineRoot, "Mod", "BaseDelta", packageName, "PropertyUpdate", $"{movieName}.gfxfonts.swf");
        Directory.CreateDirectory(Path.GetDirectoryName(outputPath)!);
        File.WriteAllBytes(outputPath, patched);
    }

    private static byte[] GetMovieData(IMEPackage package, string instancedFullPath)
    {
        var export = package.FindExport(instancedFullPath);
        var data = export?.GetProperty<ImmutableByteArrayProperty>("RawData")?.Bytes;
        if (data == null)
        {
            MilanLog.Fatal($"{package.FileNameNoExtension} has no GFxMovieInfo {instancedFullPath} with RawData - this is a fatal error.", customPrefix: LogCategory);
            Environment.Exit(1);
        }
        return data;
    }
}
