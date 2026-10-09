using System.Numerics;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Textures;
using LegendaryExplorerCore.Unreal;
using LegendaryExplorerCore.Unreal.ObjectInfo;
using LegendaryExplorerCore.Unreal.BinaryConverters;
using LegendaryExplorerCore.Unreal.Classes;

namespace ProjectMilanCore.Lighting
{
    /// <summary>
    /// A look adjustment for baked lightmaps, applied after the bake so it can be tuned without rebaking.
    /// <para/>
    /// UE3/LE3 lightmaps hold three coefficients (LE3 BasePassPixelShader, directional lightmap policy):
    /// <list type="number">
    /// <item>A - the incident light's color, normalized so its largest channel is 1.</item>
    /// <item>D - the incident light's strength along three orthonormal tangent-space basis directions.</item>
    /// <item>S - the "simple" low-quality color, used where directional lightmaps aren't.</item>
    /// </list>
    /// The game shades diffuse as A · Σ Dᵢ·(N·Bᵢ)² and lightmap specular as A · Σ Dᵢ·(R·Bᵢ)^(power+1). Each
    /// coefficient texel is (byte/255)^2.2 × that lightmap's per-channel ScaleVector.
    /// </summary>
    /// <param name="Gain">Multiplies all baked light (D and S). Below 1 tones the lighting down.</param>
    /// <param name="Floor">Light added everywhere, in diffuse units: Σ(N·Bᵢ)² is 1 for any normal, so adding
    /// this to every Dᵢ raises diffuse by exactly Floor × A. Unlit texels get a neutral A so the floor shows.</param>
    /// <param name="Directionality">0-1: blends each Dᵢ toward their mean. Flat-surface diffuse is unchanged;
    /// a strongly directional bake (a baked sun) loses some of its lightmap specular highlight and normal-map
    /// contrast.</param>
    public sealed record LightmapAdjustment(float Gain = 1f, float Floor = 0f, float Directionality = 0f)
    {
        public bool IsIdentity => Gain == 1f && Floor == 0f && Directionality == 0f;

        /// <summary>Gain alone only rescales ScaleVectors; the floor and directionality change texels.</summary>
        public bool RewritesTexels => Floor != 0f || Directionality != 0f;

        public override string ToString() => FormattableString.Invariant($"gain {Gain}, floor {Floor}, directionality {Directionality}");

        /// <summary>Applies the adjustment to one directional coefficient (strengths along the three basis directions).</summary>
        internal Vector3 ApplyDirectional(Vector3 d)
        {
            var mean = (d.X + d.Y + d.Z) / 3f;
            return Vector3.Lerp(d, new Vector3(mean), Directionality) * Gain + new Vector3(Floor);
        }

        /// <summary>Applies the adjustment to the simple coefficient (a color along the normal).</summary>
        internal Vector3 ApplySimple(Vector3 s) => s * Gain + new Vector3(Floor);
    }

    /// <summary>What <see cref="LightmapAdjuster.Adjust"/> changed in one package.</summary>
    public sealed class LightmapAdjustReport
    {
        public int Components { get; internal set; }
        public int TextureLightmaps { get; internal set; }
        public int VertexLightmaps { get; internal set; }
        public int TexturesRewritten { get; internal set; }
        public List<string> Warnings { get; } = [];

        public bool Changed => TextureLightmaps + VertexLightmaps > 0;

        public override string ToString() =>
            $"{Components} components, {TextureLightmaps} texture and {VertexLightmaps} vertex lightmaps, {TexturesRewritten} textures rewritten";
    }

    /// <summary>
    /// Applies a <see cref="LightmapAdjustment"/> to every lightmap in an LE3 or UDK package, in place. Works on the
    /// uncompressed UDK bakes in StaticLighting\Levels (lossless) and on imported LE3 packages, whose BC7 lightmaps
    /// are decoded, adjusted and re-encoded with fresh mips the same way StaticLightingImporter first encoded them.
    /// </summary>
    public static class LightmapAdjuster
    {
        private const float Gamma = 2.2f;
        private const float MinScale = 1e-4f;

        /// <summary>A neutral color for texels that received no light, so a floor has a color to show in.</summary>
        private static readonly Vector3 NeutralAverage = Vector3.One;

        public static LightmapAdjustReport Adjust(IMEPackage package, LightmapAdjustment adjustment)
        {
            if (package.Game is not (MEGame.LE3 or MEGame.UDK))
                throw new NotSupportedException($"{package.FilePath}: only LE3 and UDK lightmaps are supported, not {package.Game}");

            var report = new LightmapAdjustReport();
            if (adjustment.IsIdentity)
                return report;

            var holders = LightmapHolder.Collect(package);
            report.Components = holders.Count;

            if (adjustment.RewritesTexels)
            {
                AdjustTextureLightmaps(package, holders, adjustment, report);
                foreach (var map in holders.SelectMany(x => x.LightMaps).OfType<LightMap_1D>())
                    AdjustVertexLightmap(map, adjustment, report);
            }
            else
            {
                // Gain only: every texel scales by the same factor, which ScaleVector carries exactly.
                foreach (var map in holders.SelectMany(x => x.LightMaps))
                {
                    switch (map)
                    {
                        case LightMap_2D lm2d:
                            lm2d.ScaleVector2 *= adjustment.Gain;
                            lm2d.ScaleVector3 *= adjustment.Gain;
                            report.TextureLightmaps++;
                            break;
                        case LightMap_1D lm1d:
                            lm1d.ScaleVector2 *= adjustment.Gain;
                            lm1d.ScaleVector3 *= adjustment.Gain;
                            report.VertexLightmaps++;
                            break;
                    }
                }
            }

            foreach (var holder in holders)
                holder.Export.WriteBinary(holder.Binary);
            return report;
        }

        #region Texture lightmaps

        /// <summary>
        /// One lightmap's region of a shared texture. Several components can point at the same region (a decal
        /// on its receiver, a mesh LOD), so they share one new ScaleVector.
        /// </summary>
        private sealed class Region(Vector2 bias, Vector2 scale)
        {
            public Vector2 Bias { get; } = bias;
            public Vector2 Scale { get; } = scale;
            public List<LightMap_2D> Members { get; } = [];
        }

        private static void AdjustTextureLightmaps(IMEPackage package, List<LightmapHolder> holders, LightmapAdjustment adjustment, LightmapAdjustReport report)
        {
            var lightmaps = holders.SelectMany(x => x.LightMaps).OfType<LightMap_2D>().ToList();
            report.TextureLightmaps = lightmaps.Count;

            // The three coefficient textures of one lightmap are allocated together, so they share a layout: the
            // same texel position in Texture1/2/3 is the same surface point.
            foreach (var byTexture in lightmaps.GroupBy(x => x.Texture2))
            {
                if (!package.TryGetUExport(byTexture.Key, out var directionalTexture))
                    continue;

                var regions = new List<Region>();
                foreach (var lm in byTexture)
                {
                    var region = regions.FirstOrDefault(r => r.Bias == lm.CoordinateBias && r.Scale == lm.CoordinateScale);
                    if (region == null)
                        regions.Add(region = new Region(lm.CoordinateBias, lm.CoordinateScale));
                    else if (region.Members[0].ScaleVector2 != lm.ScaleVector2)
                        report.Warnings.Add($"{directionalTexture.InstancedFullPath}: lightmaps sharing a region have different scales; using the first");
                    region.Members.Add(lm);
                }

                // Directional coefficient: new values, then new per-region scales.
                var d = TextureTexels.Read(directionalTexture);
                var owner = OwnerMap(d.Width, d.Height, regions);
                var newDirectionalScales = TransformRegions(d, owner, regions, r => r.Members[0].ScaleVector2, adjustment.ApplyDirectional);
                d.Write();
                report.TexturesRewritten++;
                for (int i = 0; i < regions.Count; i++)
                    foreach (var member in regions[i].Members)
                        member.ScaleVector2 = newDirectionalScales[i];

                // Simple coefficient: same layout, its own texture.
                if (adjustment.Floor != 0f || adjustment.Gain != 1f)
                {
                    var simpleTextureIndex = byTexture.First().Texture3;
                    if (package.TryGetUExport(simpleTextureIndex, out var simpleTexture) && byTexture.All(x => x.Texture3 == simpleTextureIndex))
                    {
                        var s = TextureTexels.Read(simpleTexture);
                        var newSimpleScales = TransformRegions(s, OwnerMap(s.Width, s.Height, regions), regions, r => r.Members[0].ScaleVector3, adjustment.ApplySimple);
                        s.Write();
                        report.TexturesRewritten++;
                        for (int i = 0; i < regions.Count; i++)
                            foreach (var member in regions[i].Members)
                                member.ScaleVector3 = newSimpleScales[i];
                    }
                    else
                    {
                        report.Warnings.Add($"{directionalTexture.InstancedFullPath}: simple lightmap texture layout differs from the directional one; simple coefficient left unchanged");
                    }
                }

                // Average color: give unlit texels a neutral color, or the floor added above multiplies by zero.
                if (adjustment.Floor > 0f)
                {
                    var averageTextureIndex = byTexture.First().Texture1;
                    if (package.TryGetUExport(averageTextureIndex, out var averageTexture) && byTexture.All(x => x.Texture1 == averageTextureIndex))
                    {
                        var a = TextureTexels.Read(averageTexture);
                        if (FillUnlitAverage(a, OwnerMap(a.Width, a.Height, regions), regions))
                        {
                            a.Write();
                            report.TexturesRewritten++;
                        }
                    }
                }
            }
        }

        /// <summary>
        /// Which region owns each texel: the regions' own rectangles (UV × CoordinateScale + CoordinateBias), then
        /// grown two texels into the padding around them, which bilinear filtering also samples.
        /// </summary>
        private static int[] OwnerMap(int width, int height, List<Region> regions)
        {
            var owner = new int[width * height];
            Array.Fill(owner, -1);
            for (int r = 0; r < regions.Count; r++)
            {
                var (bias, scale) = (regions[r].Bias, regions[r].Scale);
                int x0 = Math.Clamp((int)MathF.Floor(bias.X * width), 0, width), x1 = Math.Clamp((int)MathF.Ceiling((bias.X + scale.X) * width), 0, width);
                int y0 = Math.Clamp((int)MathF.Floor(bias.Y * height), 0, height), y1 = Math.Clamp((int)MathF.Ceiling((bias.Y + scale.Y) * height), 0, height);
                for (int y = y0; y < y1; y++)
                    for (int x = x0; x < x1; x++)
                        if (owner[y * width + x] < 0)
                            owner[y * width + x] = r;
            }

            for (int pass = 0; pass < 2; pass++)
            {
                var grown = (int[])owner.Clone();
                for (int y = 0; y < height; y++)
                {
                    for (int x = 0; x < width; x++)
                    {
                        if (owner[y * width + x] >= 0)
                            continue;
                        if (x > 0 && owner[y * width + x - 1] >= 0) grown[y * width + x] = owner[y * width + x - 1];
                        else if (x < width - 1 && owner[y * width + x + 1] >= 0) grown[y * width + x] = owner[y * width + x + 1];
                        else if (y > 0 && owner[(y - 1) * width + x] >= 0) grown[y * width + x] = owner[(y - 1) * width + x];
                        else if (y < height - 1 && owner[(y + 1) * width + x] >= 0) grown[y * width + x] = owner[(y + 1) * width + x];
                    }
                }
                owner = grown;
            }
            return owner;
        }

        /// <summary>Applies <paramref name="transform"/> to every owned texel and re-encodes each region with the
        /// smallest scale that holds its new values. Returns the new scale of each region.</summary>
        private static Vector3[] TransformRegions(TextureTexels texels, int[] owner, List<Region> regions, Func<Region, Vector3> oldScale, Func<Vector3, Vector3> transform)
        {
            var values = new Vector3[owner.Length];
            var max = new Vector3[regions.Count];
            for (int i = 0; i < owner.Length; i++)
            {
                if (owner[i] < 0)
                    continue;
                var value = transform(texels.Decode(i, oldScale(regions[owner[i]])));
                values[i] = value;
                max[owner[i]] = Vector3.Max(max[owner[i]], value);
            }

            var newScales = max.Select(m => Vector3.Max(m, new Vector3(MinScale))).ToArray();
            for (int i = 0; i < owner.Length; i++)
                if (owner[i] >= 0)
                    texels.Encode(i, values[i], newScales[owner[i]]);
            return newScales;
        }

        private static bool FillUnlitAverage(TextureTexels texels, int[] owner, List<Region> regions)
        {
            var changed = false;
            for (int i = 0; i < owner.Length; i++)
            {
                if (owner[i] < 0 || !texels.IsBlack(i))
                    continue;
                texels.Encode(i, NeutralAverage, Vector3.Max(regions[owner[i]].Members[0].ScaleVector1, NeutralAverage));
                changed = true;
            }
            return changed;
        }

        /// <summary>A lightmap texture's top mip as BGRA bytes (LEX's ARGB layout), decoded from whatever format it's stored in.</summary>
        private sealed class TextureTexels
        {
            private readonly ExportEntry export;
            private readonly PixelFormat format;
            public byte[] Bgra { get; }
            public int Width { get; }
            public int Height { get; }

            private TextureTexels(ExportEntry export, PixelFormat format, byte[] bgra, int width, int height)
            {
                this.export = export;
                this.format = format;
                Bgra = bgra;
                Width = width;
                Height = height;
            }

            public static TextureTexels Read(ExportEntry export)
            {
                var texture = new Texture2D(export);
                var format = Image.getPixelFormatType(texture.TextureFormat);
                var top = texture.GetTopMip();
                int width = top.width, height = top.height;
                var raw = Texture2D.GetTextureData(top, export.Game);
                var bgra = Image.convertRawToARGB(raw, ref width, ref height, format);
                return new TextureTexels(export, format, bgra, width, height);
            }

            /// <summary>Channel X/Y/Z of ScaleVector pairs with red/green/blue, which sit at bytes 2/1/0.</summary>
            public Vector3 Decode(int texel, Vector3 scale) => new Vector3(
                MathF.Pow(Bgra[texel * 4 + 2] / 255f, Gamma),
                MathF.Pow(Bgra[texel * 4 + 1] / 255f, Gamma),
                MathF.Pow(Bgra[texel * 4 + 0] / 255f, Gamma)) * scale;

            public void Encode(int texel, Vector3 value, Vector3 scale)
            {
                Bgra[texel * 4 + 2] = Quantize(value.X, scale.X);
                Bgra[texel * 4 + 1] = Quantize(value.Y, scale.Y);
                Bgra[texel * 4 + 0] = Quantize(value.Z, scale.Z);
            }

            public bool IsBlack(int texel) => Bgra[texel * 4] == 0 && Bgra[texel * 4 + 1] == 0 && Bgra[texel * 4 + 2] == 0;

            /// <summary>
            /// UDK's own bakes are a single uncompressed mip, written back as-is so the importer still mips and
            /// BC7-encodes them. Anything else (an imported LE3 BC7 lightmap) is re-encoded in its own format with
            /// a fresh mip chain, as StaticLightingImporter's GenerateMips did on import.
            /// </summary>
            public void Write()
            {
                var texture = new Texture2D(export);
                if (format == PixelFormat.ARGB && texture.Mips.Count(m => m.storageType != StorageTypes.empty) == 1)
                {
                    var binary = ObjectBinary.From<LightMapTexture2D>(export);
                    var mip = binary.Mips.First(m => !m.IsEmpty);
                    mip.Mip = Bgra;
                    mip.UncompressedSize = mip.CompressedSize = Bgra.Length;
                    mip.StorageType = StorageTypes.pccUnc;
                    export.WriteBinary(binary);
                }
                else
                {
                    var image = new Image([new MipMap(Bgra, Width, Height, PixelFormat.ARGB)], PixelFormat.ARGB);
                    texture.Replace(image, export.GetProperties(), isPackageStored: true, forcedNewFormat: format, forceMipping: true);
                }
            }
        }

        #endregion

        #region Vertex lightmaps

        /// <summary>Vertex lightmaps: per-vertex A (Coefficient2), D (Coefficient3) and S samples with the same encoding.</summary>
        private static void AdjustVertexLightmap(LightMap_1D lm, LightmapAdjustment adjustment, LightmapAdjustReport report)
        {
            report.VertexLightmaps++;

            if (lm.DirectionalSamples is { Length: > 0 } samples)
            {
                var values = samples.Select(s => DecodeColor(s.Coefficient3, lm.ScaleVector2)).Select(adjustment.ApplyDirectional).ToArray();
                var scale = Vector3.Max(values.Aggregate(Vector3.Zero, Vector3.Max), new Vector3(MinScale));
                for (int i = 0; i < samples.Length; i++)
                {
                    samples[i].Coefficient3 = EncodeColor(values[i], scale, samples[i].Coefficient3.A);
                    if (adjustment.Floor > 0f && samples[i].Coefficient2 is { R: 0, G: 0, B: 0 } average)
                        samples[i].Coefficient2 = EncodeColor(NeutralAverage, Vector3.Max(lm.ScaleVector1, NeutralAverage), average.A);
                }
                lm.ScaleVector2 = scale;
            }

            if (lm.SimpleSamples is { Length: > 0 } simple)
            {
                var values = simple.Select(s => adjustment.ApplySimple(DecodeColor(s.Coefficient, lm.ScaleVector3))).ToArray();
                var scale = Vector3.Max(values.Aggregate(Vector3.Zero, Vector3.Max), new Vector3(MinScale));
                for (int i = 0; i < simple.Length; i++)
                    simple[i].Coefficient = EncodeColor(values[i], scale, simple[i].Coefficient.A);
                lm.ScaleVector3 = scale;
            }
        }

        private static Vector3 DecodeColor(LegendaryExplorerCore.SharpDX.Color color, Vector3 scale) => new Vector3(
            MathF.Pow(color.R / 255f, Gamma), MathF.Pow(color.G / 255f, Gamma), MathF.Pow(color.B / 255f, Gamma)) * scale;

        private static LegendaryExplorerCore.SharpDX.Color EncodeColor(Vector3 value, Vector3 scale, byte alpha) =>
            new(Quantize(value.X, scale.X), Quantize(value.Y, scale.Y), Quantize(value.Z, scale.Z), alpha);

        #endregion

        /// <summary>UE3 QuantizeLightSamples' encoding, rounded rather than truncated so unchanged values round-trip.</summary>
        private static byte Quantize(float value, float scale) =>
            (byte)Math.Clamp((int)(MathF.Pow(Math.Clamp(value / scale, 0f, 1f), 1f / Gamma) * 255f + 0.5f), 0, 255);
    }

    /// <summary>An export carrying lightmaps, with its parsed binary to write back once they're changed.</summary>
    internal sealed class LightmapHolder
    {
        public ExportEntry Export { get; private init; }
        public ObjectBinary Binary { get; private init; }
        public List<LightMap> LightMaps { get; private init; }

        public static List<LightmapHolder> Collect(IMEPackage package)
        {
            var holders = new List<LightmapHolder>();
            foreach (var export in package.Exports)
            {
                if (export.IsDefaultObject || !IsLightmapHolderClass(export))
                    continue;

                var binary = ObjectBinary.From(export);
                IEnumerable<LightMap> maps = binary switch
                {
                    StaticMeshComponent smc => smc.LODData.Select(x => x.LightMap),
                    ModelComponent mc => mc.Elements.Select(x => x.LightMap),
                    DecalComponent dc => dc.StaticReceivers.Select(x => x.LightMap),
                    TerrainComponent tc => [tc.LightMap],
                    FluidSurfaceComponent fc => [fc.LightMap],
                    _ => []
                };
                var lightMaps = maps.Where(x => x is LightMap_1D or LightMap_2D).ToList();
                if (lightMaps.Count > 0)
                    holders.Add(new LightmapHolder { Export = export, Binary = binary, LightMaps = lightMaps });
            }
            return holders;
        }

        private static bool IsLightmapHolderClass(ExportEntry export) =>
            export.IsA("StaticMeshComponent") || export.IsA("ModelComponent") || export.IsA("DecalComponent")
            || export.IsA("TerrainComponent") || export.IsA("FluidSurfaceComponent");
    }
}
