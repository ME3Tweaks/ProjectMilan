using System.Globalization;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Textures;
using LegendaryExplorerCore.Unreal;
using LegendaryExplorerCore.Unreal.BinaryConverters;
using ProjectMilanCore;
using Texture2D = LegendaryExplorerCore.Unreal.Classes.Texture2D;

namespace ProjectMilan.Pipelines.StaticLighting
{
    /// <summary>
    /// Scores our baked lightmaps against ME3's, component by component, so a lighting change can be judged by
    /// a number rather than by eye. See LIGHTING_CALIBRATION_HANDOFF.md.
    /// </summary>
    /// <remarks>
    /// Only components that are LMT_2D in both games, at the same path, are compared. Their lightmap UV layouts
    /// match; only the atlas placement and resolution differ, so each component's region is cropped out of its
    /// atlas by CoordinateBias/CoordinateScale and averaged.
    ///
    /// The value compared is the irradiance the game's LMT_2D path produces for a flat normal
    /// (BasePassPixelShader.usf, GetDirectLightMapContribution): linear(NormalizedAverageColor) times the mean of
    /// linear(DirectionalMaxComponent), with both textures sRGB-decoded and ScaleVectors 1. UDK's viewport
    /// decodes these textures differently, so it is not a substitute for this check.
    /// </remarks>
    public static class LightmapComparison
    {
        private const string LOG_CATEGORY = @"MILAN-LightingCompare";

        private sealed record Row(string Level, string Component, string Mesh, double ME3, double Ours)
        {
            public double Ratio => ME3 > MinLit ? Ours / ME3 : double.NaN;
        }

        /// <summary>Mean irradiance below which a component counts as unlit in ME3 and gets no ratio.</summary>
        private const double MinLit = 1e-4;

        /// <summary>File name -> path in the unpacked ME3 folder, when one was given.</summary>
        private static Dictionary<string, string>? me3Files;

        /// <summary>
        /// Compares every level package of each map in <paramref name="levelsRoot"/> (one folder per BioP, as in
        /// the mod's CookedPCConsole\Levels) against the ME3 package of the same name. Writes a CSV per run into
        /// <paramref name="reportFolder"/> and logs per-level percentiles of ours/ME3.
        /// </summary>
        /// <param name="me3Root">An unpacked ME3 folder to take the ME3 packages from (searched recursively), or null to
        /// use the installed game. Lightmaps live in TFCs, which can't be read out of a packed DLC.</param>
        public static void Run(IEnumerable<string> bioPs, string levelsRoot, string reportFolder, string? me3Root = null)
        {
            Directory.CreateDirectory(reportFolder);
            me3Files = me3Root == null ? null : Directory.EnumerateFiles(me3Root, "*.pcc", SearchOption.AllDirectories)
                .GroupBy(x => Path.GetFileName(x), StringComparer.OrdinalIgnoreCase)
                .ToDictionary(x => x.Key, x => x.First(), StringComparer.OrdinalIgnoreCase);
            var rows = new List<Row>();
            foreach (var bioP in bioPs)
            {
                var folder = Path.Combine(levelsRoot, bioP);
                if (!Directory.Exists(folder))
                {
                    MilanLog.Warning($"No built level folder for {bioP} at {folder}", customPrefix: LOG_CATEGORY);
                    continue;
                }
                foreach (var file in Directory.GetFiles(folder, "*.pcc").Order())
                {
                    try
                    {
                        rows.AddRange(CompareLevel(file));
                    }
                    catch (Exception ex)
                    {
                        MilanLog.Error($"Could not compare {Path.GetFileName(file)}: {ex.Message}", customPrefix: LOG_CATEGORY);
                    }
                }
            }

            var reportPath = Path.Combine(reportFolder, $"LightingCompare_{DateTime.Now:yyyyMMdd-HHmmss}.csv");
            using (var writer = new StreamWriter(reportPath))
            {
                writer.WriteLine("Level,Component,Mesh,ME3,Ours,OursOverME3");
                foreach (var row in rows)
                    writer.WriteLine(string.Join(',', row.Level, row.Component, row.Mesh,
                        row.ME3.ToString("G4", CultureInfo.InvariantCulture), row.Ours.ToString("G4", CultureInfo.InvariantCulture),
                        double.IsNaN(row.Ratio) ? "" : row.Ratio.ToString("F3", CultureInfo.InvariantCulture)));
            }

            foreach (var level in rows.GroupBy(x => x.Level))
                LogSummary(level.Key, level.ToList());
            LogSummary("ALL", rows);
            MilanLog.Information($"Lighting comparison written to {reportPath}", customPrefix: LOG_CATEGORY);
        }

        private static void LogSummary(string label, List<Row> rows)
        {
            var ratios = rows.Select(x => x.Ratio).Where(x => !double.IsNaN(x)).Order().ToList();
            if (ratios.Count == 0)
            {
                MilanLog.Information($"{label}: no comparable components", customPrefix: LOG_CATEGORY);
                return;
            }
            double P(double q) => ratios[(int)Math.Min(ratios.Count - 1, q * ratios.Count)];
            MilanLog.Information($"{label}: {ratios.Count} components, ours/ME3 p10={P(0.1):F2} p25={P(0.25):F2} median={P(0.5):F2} " +
                                 $"p75={P(0.75):F2} p90={P(0.9):F2}; {ratios.Count(x => x < 0.5) * 100 / ratios.Count}% under half", customPrefix: LOG_CATEGORY);
        }

        private static List<Row> CompareLevel(string ourFile)
        {
            var rows = new List<Row>();
            using var ours = MEPackageHandler.OpenMEPackage(ourFile);
            var fileName = Path.GetFileName(ourFile);
            using var me3 = me3Files != null
                ? me3Files.TryGetValue(fileName, out var me3Path) ? MEPackageHandler.OpenMEPackage(me3Path) : null
                : MilanShared.GetME3Package(fileName, logIfNotFound: false);
            if (me3 == null)
                return rows; // Milan-only package

            var me3Atlases = new Dictionary<int, Image>();
            var ourAtlases = new Dictionary<int, Image>();
            foreach (var me3Component in me3.Exports.Where(x => x.ClassName == "StaticMeshComponent"))
            {
                var ourComponent = ours.FindExport(me3Component.InstancedFullPath);
                if (ourComponent == null || LightMap2D(me3Component) is not { } me3Map || LightMap2D(ourComponent) is not { } ourMap)
                    continue;
                var mesh = me3.GetEntry(me3Component.GetProperty<ObjectProperty>("StaticMesh")?.Value ?? 0)?.ObjectName.Instanced ?? "";
                rows.Add(new Row(ours.FileNameNoExtension, me3Component.InstancedFullPath, mesh,
                    MeanIrradiance(me3, me3Map, me3Atlases), MeanIrradiance(ours, ourMap, ourAtlases)));
            }
            return rows;
        }

        private static LightMap_2D? LightMap2D(ExportEntry component)
        {
            var lods = ObjectBinary.From<StaticMeshComponent>(component).LODData;
            return lods.Length > 0 ? lods[0].LightMap as LightMap_2D : null;
        }

        private static double MeanIrradiance(IMEPackage package, LightMap_2D map, Dictionary<int, Image> atlases)
        {
            var color = Atlas(package, map.Texture1, atlases);
            var directional = Atlas(package, map.Texture2, atlases);
            var mip = color.mipMaps[0];
            int x0 = (int)(map.CoordinateBias.X * mip.width), y0 = (int)(map.CoordinateBias.Y * mip.height);
            int w = Math.Max(1, (int)Math.Round(map.CoordinateScale.X * mip.width));
            int h = Math.Max(1, (int)Math.Round(map.CoordinateScale.Y * mip.height));
            double sum = 0;
            for (var y = y0; y < y0 + h; y++)
                for (var x = x0; x < x0 + w; x++)
                {
                    // Both textures share the coordinates; sample the directional one at the same UV.
                    double u = (x + 0.5) / mip.width, v = (y + 0.5) / mip.height;
                    sum += Mean(color, u, v) * Mean(directional, u, v);
                }
            return sum / (w * h);
        }

        /// <summary>Mean of the linearized RGB of the top-mip texel at UV.</summary>
        private static double Mean(Image image, double u, double v)
        {
            var mip = image.mipMaps[0];
            int x = Math.Clamp((int)(u * mip.width), 0, mip.width - 1), y = Math.Clamp((int)(v * mip.height), 0, mip.height - 1);
            var i = (y * mip.width + x) * 4;
            return (Linear(mip.data[i]) + Linear(mip.data[i + 1]) + Linear(mip.data[i + 2])) / 3;
        }

        private static Image Atlas(IMEPackage package, int uIndex, Dictionary<int, Image> atlases)
        {
            if (!atlases.TryGetValue(uIndex, out var image))
                atlases[uIndex] = image = new Texture2D(package.GetUExport(uIndex)).ToImage(PixelFormat.ARGB);
            return image;
        }

        private static double Linear(byte value) => Math.Pow(value / 255.0, 2.2);
    }
}
