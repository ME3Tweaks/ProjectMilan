using System.Text;
using System.Text.Json;

namespace ShaderResearchTool;

public enum ParityVerdict
{
    /// <summary>Same textures in the same slots with the same formats. Safe to calibrate against.</summary>
    Clean,

    /// <summary>
    /// Different texture resolved, but the same pixel format. The generated Material.usf is
    /// unaffected, so shader bytecode comparison stays valid — this is a visual bug only.
    /// </summary>
    IdentityOnly,

    /// <summary>
    /// A slot resolved to a texture of a different pixel format. The generated Material.usf
    /// genuinely differs (e.g. BC5 vs DXT5 normal unpack), so bytecode comparison is meaningless.
    /// </summary>
    FormatDivergence,

    /// <summary>Different number of bound textures. Material translation diverged outright.</summary>
    CountMismatch,

    /// <summary>
    /// The decooked material has no compiled MaterialResource, so it binds no textures to compare.
    /// Expected for anything rebuilt from T3D and never compiled: UniformExpressionTextures is
    /// produced by the translator, not by the expression graph. Not a divergence — undecidable here.
    /// </summary>
    NotCompiled,

    /// <summary>A format could not be determined on one side; verdict undecidable.</summary>
    Unknown
}

public sealed class MaterialParityResult
{
    public string MaterialPath { get; set; } = "";
    public ParityVerdict Verdict { get; set; }
    public string DecookedFile { get; set; } = "";
    public string ShippingFile { get; set; } = "";
    public List<SlotDiff> Diffs { get; set; } = [];

    public sealed class SlotDiff
    {
        public int Slot { get; set; }
        public string DecookedTexture { get; set; } = "";
        public string DecookedFormat { get; set; } = "";
        public string ShippingTexture { get; set; } = "";
        public string ShippingFormat { get; set; } = "";
    }
}

public static class TextureParityCommand
{
    public static int Run(ToolPaths paths, bool rebuildIndexes)
    {
        if (!File.Exists(paths.ObjectDbPath))
        {
            Console.Error.WriteLine($"object DB not found: {paths.ObjectDbPath}");
            return 1;
        }

        var decooked = GetOrBuildDecookedIndex(paths, rebuildIndexes);
        if (decooked == null) return 1;

        Console.WriteLine($"decooked: {decooked.Materials.Count} materials, {decooked.TextureFormats.Count} textures");

        Console.WriteLine($"\nloading object DB {Path.GetFileName(paths.ObjectDbPath)}");
        var resolver = ShippingMaterialResolver.Load(paths.ObjectDbPath, paths.GameRoot);

        Console.WriteLine("resolving shipping materials");
        var shippingMaterials = resolver.GetMaterials(decooked.Materials.Keys, Console.WriteLine);

        // Only the textures actually bound by a material we are comparing need formats.
        var neededTextures = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        foreach (var bindings in shippingMaterials.Values)
        {
            foreach (var tex in bindings.Textures)
            {
                if (tex.Length > 0) neededTextures.Add(tex);
            }
        }

        Console.WriteLine("resolving shipping texture formats");
        var shippingFormats = resolver.GetTextureFormats(neededTextures, Console.WriteLine);

        var results = new List<MaterialParityResult>();
        var onlyInDecooked = new List<string>();

        foreach (var (path, dec) in decooked.Materials)
        {
            if (!shippingMaterials.TryGetValue(path, out var ship))
            {
                onlyInDecooked.Add(path);
                continue;
            }

            results.Add(Compare(path, dec, ship, decooked, shippingFormats));
        }

        WriteReport(paths, results, onlyInDecooked, decooked.Materials.Count, shippingMaterials.Count);
        PrintSummary(results, onlyInDecooked);
        return 0;
    }

    private static PackageObjectIndex? GetOrBuildDecookedIndex(ToolPaths paths, bool rebuild)
    {
        var cachePath = Path.Combine(paths.OutputDir, "index-decooked.json");

        if (!rebuild)
        {
            var cached = PackageObjectIndex.Load(cachePath);
            if (cached is { Materials.Count: > 0 })
            {
                Console.WriteLine($"[decooked] loaded cached index from {cachePath}");
                return cached;
            }
        }

        if (!Directory.Exists(paths.DecookedDir))
        {
            Console.Error.WriteLine($"[decooked] directory not found: {paths.DecookedDir}");
            return null;
        }

        var files = Directory.GetFiles(paths.DecookedDir, "*.pcc", SearchOption.AllDirectories);
        Console.WriteLine($"[decooked] scanning {files.Length} packages in {paths.DecookedDir}");
        var index = PackageObjectIndex.Build(files, m => Console.WriteLine($"[decooked]{m}"));
        index.Save(cachePath);
        Console.WriteLine($"[decooked] index saved to {cachePath}");

        if (index.FailedFiles.Count > 0)
        {
            Console.Error.WriteLine($"[decooked] WARNING: {index.FailedFiles.Count}/{files.Length} packages failed to open");
            Console.Error.WriteLine($"[decooked]   first: {index.FailedFiles[0]}");
        }
        return index;
    }

    private static MaterialParityResult Compare(
        string path,
        MaterialTextureBindings dec,
        MaterialTextureBindings ship,
        PackageObjectIndex decIndex,
        Dictionary<string, string> shippingFormats)
    {
        var result = new MaterialParityResult
        {
            MaterialPath = path,
            DecookedFile = dec.SourceFile,
            ShippingFile = ship.SourceFile
        };

        // An uncompiled rebuild has no UniformExpressionTextures at all; that says nothing about
        // whether its textures diverge, so it must not be reported as a mismatch.
        if (dec.Textures.Count == 0 && (ship.Textures.Count > 0 || dec.Error != null))
        {
            result.Verdict = ParityVerdict.NotCompiled;
            return result;
        }

        if (dec.Textures.Count != ship.Textures.Count)
        {
            result.Verdict = ParityVerdict.CountMismatch;
            return result;
        }

        bool anyFormatDiff = false;
        bool anyIdentityDiff = false;
        bool anyUnknown = false;

        for (int i = 0; i < dec.Textures.Count; i++)
        {
            var decTex = dec.Textures[i];
            var shipTex = ship.Textures[i];

            if (SameTexture(decTex, shipTex)) continue;

            anyIdentityDiff = true;

            var decFmt = decIndex.FormatOf(decTex);
            shippingFormats.TryGetValue(shipTex, out var shipFmt);

            if (decFmt == null || shipFmt == null)
            {
                anyUnknown = true;
            }
            else if (!string.Equals(decFmt, shipFmt, StringComparison.OrdinalIgnoreCase))
            {
                anyFormatDiff = true;
            }

            result.Diffs.Add(new MaterialParityResult.SlotDiff
            {
                Slot = i,
                DecookedTexture = decTex,
                DecookedFormat = decFmt ?? "?",
                ShippingTexture = shipTex,
                ShippingFormat = shipFmt ?? "?"
            });
        }

        result.Verdict = anyFormatDiff ? ParityVerdict.FormatDivergence
            : anyUnknown ? ParityVerdict.Unknown
            : anyIdentityDiff ? ParityVerdict.IdentityOnly
            : ParityVerdict.Clean;

        return result;
    }

    /// <summary>
    /// Cooking a seekfree package drops the root package from a forced export's path, so the
    /// shipping side legitimately reads "Eye.EYE_Diff" where the decooked side reads
    /// "BIOG_HMM_HED_PROMorph.Eye.EYE_Diff". Match on a trailing path-component boundary so that
    /// artifact is not reported as a resolution difference.
    /// </summary>
    private static bool SameTexture(string a, string b)
    {
        if (string.Equals(a, b, StringComparison.OrdinalIgnoreCase)) return true;
        if (a.Length == 0 || b.Length == 0) return false;

        var (longer, shorter) = a.Length > b.Length ? (a, b) : (b, a);
        return longer.EndsWith(shorter, StringComparison.OrdinalIgnoreCase)
               && longer[longer.Length - shorter.Length - 1] == '.';
    }

    private static void WriteReport(
        ToolPaths paths,
        List<MaterialParityResult> results,
        List<string> onlyInDecooked,
        int decookedMaterialCount,
        int shippingMaterialCount)
    {
        Directory.CreateDirectory(paths.OutputDir);

        var jsonPath = Path.Combine(paths.OutputDir, "texture-parity.json");
        using (var fs = File.Create(jsonPath))
        {
            JsonSerializer.Serialize(fs, new
            {
                decookedMaterials = decookedMaterialCount,
                shippingMaterialsResolved = shippingMaterialCount,
                onlyInDecooked,
                results
            }, new JsonSerializerOptions { WriteIndented = true });
        }

        // The three lists that drive downstream work.
        WriteList(Path.Combine(paths.OutputDir, "quarantine-materials.txt"),
            results.Where(r => r.Verdict is ParityVerdict.FormatDivergence or ParityVerdict.CountMismatch)
                   .Select(r => r.MaterialPath));

        WriteList(Path.Combine(paths.OutputDir, "visual-bug-materials.txt"),
            results.Where(r => r.Verdict == ParityVerdict.IdentityOnly).Select(r => r.MaterialPath));

        WriteList(Path.Combine(paths.OutputDir, "trusted-materials.txt"),
            results.Where(r => r.Verdict is ParityVerdict.Clean).Select(r => r.MaterialPath));

        Console.WriteLine($"\nreport written to {jsonPath}");
    }

    private static void WriteList(string path, IEnumerable<string> lines)
    {
        var sb = new StringBuilder();
        foreach (var line in lines.Order(StringComparer.OrdinalIgnoreCase)) sb.AppendLine(line);
        File.WriteAllText(path, sb.ToString());
    }

    private static void PrintSummary(List<MaterialParityResult> results, List<string> onlyInDecooked)
    {
        Console.WriteLine();
        Console.WriteLine("=== texture parity ===");
        Console.WriteLine($"  compared         {results.Count,6}");
        foreach (var verdict in Enum.GetValues<ParityVerdict>())
        {
            var count = results.Count(r => r.Verdict == verdict);
            var pct = results.Count == 0 ? 0 : 100.0 * count / results.Count;
            Console.WriteLine($"  {verdict,-17} {count,6}  ({pct,5:F1}%)");
        }
        Console.WriteLine($"  only in decooked {onlyInDecooked.Count,6}   (MP-only / not shipped)");
    }
}
