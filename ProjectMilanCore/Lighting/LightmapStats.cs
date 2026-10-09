using System.Numerics;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Textures;
using LegendaryExplorerCore.Unreal.BinaryConverters;
using LegendaryExplorerCore.Unreal.Classes;

namespace ProjectMilanCore.Lighting
{
    /// <summary>
    /// Brightness distribution of a set of baked lightmaps, for comparing two bakes of the same map (UE3 vs UE4
    /// Lightmass) and choosing a <see cref="LightmapAdjustment"/> from data rather than by eye alone.
    /// <para/>
    /// Each mapped texel (or vertex) contributes its flat-surface diffuse luminance, Lum(A) × mean(D), which is
    /// what the game's diffuse term gives a surface facing along the normal (see <see cref="LightmapAdjustment"/>),
    /// and its directionality, max(D) / mean(D): 1 for light from all around, 3 for light from one basis direction.
    /// </summary>
    public sealed class LightmapStats
    {
        private const int Bins = 4000;
        private const double MinValue = 1e-5, MaxValue = 1e3;
        private static readonly double LogMin = Math.Log(MinValue), LogRange = Math.Log(MaxValue) - Math.Log(MinValue);

        /// <summary>Below this a texel counts as black: about 1% grey after gamma.</summary>
        public const float BlackThreshold = 1e-4f;

        private readonly long[] histogram = new long[Bins];
        private long zeroCount;
        private double luminanceSum;
        private double directionalitySum;

        public long Count { get; private set; }
        public double Mean => Count > 0 ? luminanceSum / Count : 0;
        public double MeanDirectionality => Count > 0 ? directionalitySum / Count : 0;
        public double BlackFraction { get; private set; }
        private long blackCount;

        public void Add(float luminance, float directionality)
        {
            Count++;
            luminanceSum += luminance;
            directionalitySum += directionality;
            if (luminance < BlackThreshold)
                blackCount++;
            BlackFraction = (double)blackCount / Count;

            if (luminance <= MinValue)
            {
                zeroCount++;
                return;
            }
            var bin = (int)((Math.Log(luminance) - LogMin) / LogRange * Bins);
            histogram[Math.Clamp(bin, 0, Bins - 1)]++;
        }

        public void Merge(LightmapStats other)
        {
            for (int i = 0; i < Bins; i++)
                histogram[i] += other.histogram[i];
            zeroCount += other.zeroCount;
            luminanceSum += other.luminanceSum;
            directionalitySum += other.directionalitySum;
            blackCount += other.blackCount;
            Count += other.Count;
            BlackFraction = Count > 0 ? (double)blackCount / Count : 0;
        }

        /// <summary>The luminance below which <paramref name="fraction"/> of texels fall (bin-center accuracy, ~0.35%).</summary>
        public double Percentile(double fraction)
        {
            var target = (long)Math.Ceiling(fraction * Count);
            if (target <= zeroCount)
                return 0;
            var seen = zeroCount;
            for (int i = 0; i < Bins; i++)
            {
                seen += histogram[i];
                if (seen >= target)
                    return Math.Exp(LogMin + (i + 0.5) / Bins * LogRange);
            }
            return MaxValue;
        }

        /// <summary>Measures every texture and vertex lightmap in an LE3 or UDK package.</summary>
        public static LightmapStats Measure(IMEPackage package)
        {
            var stats = new LightmapStats();
            var lightmaps = LightmapHolder.Collect(package).SelectMany(x => x.LightMaps).ToList();

            foreach (var byTexture in lightmaps.OfType<LightMap_2D>().GroupBy(x => (x.Texture1, x.Texture2)))
            {
                if (!package.TryGetUExport(byTexture.Key.Texture1, out var averageTexture) || !package.TryGetUExport(byTexture.Key.Texture2, out var directionalTexture))
                    continue;
                var (a, width, height) = Decode(averageTexture);
                var (d, dWidth, dHeight) = Decode(directionalTexture);
                if (width != dWidth || height != dHeight)
                    continue;

                // Only trust alpha as coverage if it actually distinguishes texels.
                bool anyCovered = false, anyUncovered = false;
                for (int i = 3; i < d.Length && !(anyCovered && anyUncovered); i += 4)
                {
                    anyCovered |= d[i] >= 128;
                    anyUncovered |= d[i] < 128;
                }
                var useCoverage = anyCovered && anyUncovered;

                // Each region once, without padding; texel alpha is UE3's coverage where the format keeps it.
                foreach (var lm in byTexture.DistinctBy(x => (x.CoordinateBias, x.CoordinateScale)))
                {
                    int x0 = Math.Clamp((int)(lm.CoordinateBias.X * width), 0, width), x1 = Math.Clamp((int)MathF.Ceiling((lm.CoordinateBias.X + lm.CoordinateScale.X) * width), 0, width);
                    int y0 = Math.Clamp((int)(lm.CoordinateBias.Y * height), 0, height), y1 = Math.Clamp((int)MathF.Ceiling((lm.CoordinateBias.Y + lm.CoordinateScale.Y) * height), 0, height);
                    for (int y = y0; y < y1; y++)
                    {
                        for (int x = x0; x < x1; x++)
                        {
                            var i = (y * width + x) * 4;
                            if (useCoverage && d[i + 3] < 128)
                                continue;
                            stats.Add(Texel(a, i, lm.ScaleVector1), Texel(d, i, lm.ScaleVector2));
                        }
                    }
                }
            }

            foreach (var lm in lightmaps.OfType<LightMap_1D>())
            {
                foreach (var sample in lm.DirectionalSamples ?? [])
                {
                    var average = Linear(sample.Coefficient2.R, sample.Coefficient2.G, sample.Coefficient2.B) * lm.ScaleVector1;
                    var directional = Linear(sample.Coefficient3.R, sample.Coefficient3.G, sample.Coefficient3.B) * lm.ScaleVector2;
                    stats.Add(average, directional);
                }
            }
            return stats;
        }

        private void Add(Vector3 average, Vector3 directional)
        {
            var mean = (directional.X + directional.Y + directional.Z) / 3f;
            var luminance = (0.2126f * average.X + 0.7152f * average.Y + 0.0722f * average.Z) * mean;
            var directionality = mean > BlackThreshold ? MathF.Max(directional.X, MathF.Max(directional.Y, directional.Z)) / mean : 1f;
            Add(luminance, directionality);
        }

        private static Vector3 Texel(byte[] bgra, int i, Vector3 scale) => Linear(bgra[i + 2], bgra[i + 1], bgra[i]) * scale;

        private static Vector3 Linear(byte r, byte g, byte b) =>
            new(MathF.Pow(r / 255f, 2.2f), MathF.Pow(g / 255f, 2.2f), MathF.Pow(b / 255f, 2.2f));

        private static (byte[] Bgra, int Width, int Height) Decode(ExportEntry export)
        {
            var texture = new Texture2D(export);
            var top = texture.GetTopMip();
            int width = top.width, height = top.height;
            var bgra = Image.convertRawToARGB(Texture2D.GetTextureData(top, export.Game), ref width, ref height, Image.getPixelFormatType(texture.TextureFormat));
            return (bgra, width, height);
        }
    }
}
