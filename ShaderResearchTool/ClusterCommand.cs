using System.Text;
using System.Text.Json;
using LegendaryExplorerCore.Shaders;
using MilanShaderHost;
using Newtonsoft.Json;
using JsonSerializer = System.Text.Json.JsonSerializer;

namespace ShaderResearchTool;

/// <summary>
/// Groups scoreboard mismatches by how they differ, so one diagnosis can fix many shaders.
///
/// A few dozen root causes typically account for thousands of mismatches — the same lightmap or
/// normal-unpack mistake replicated across every material using that policy. Ranking clusters by
/// size turns "fix the shaders" into an ordered worklist.
/// </summary>
public static class ClusterCommand
{
    private sealed class Cluster
    {
        public string Signature { get; set; } = "";
        public int Count { get; set; }
        public List<string> ShaderTypes { get; set; } = [];
        public List<string> VertexFactories { get; set; } = [];
        /// <summary>
        /// Every material in this cluster, as "PackageFile|MaterialPath". Kept because a cluster
        /// identifies a *cause*, but acting on a cause -- checking which texture an input resolved
        /// to, say -- needs the materials it actually affected, not one representative.
        /// </summary>
        public List<string> Materials { get; set; } = [];
        public string RepresentativeJson { get; set; } = "";
        public List<string> OnlyInOurs { get; set; } = [];
        public List<string> OnlyInReference { get; set; } = [];
        /// <summary>True when the two differ everywhere rather than at a specific construct.</summary>
        public bool LooksLikeCompileFlags { get; set; }
    }

    public static int Run(ToolPaths paths, int limit, bool preferEngine, IEnumerable<string>? extraMacros = null)
    {
        var scoreboardPath = Path.Combine(paths.OutputDir, "scoreboard.json");
        if (!File.Exists(scoreboardPath))
        {
            Console.Error.WriteLine($"scoreboard not found: {scoreboardPath} — run 'scoreboard' first.");
            return 1;
        }

        List<ShaderScore>? scores;
        using (var fs = File.OpenRead(scoreboardPath))
        {
            scores = JsonSerializer.Deserialize<List<ShaderScore>>(fs);
        }

        var mismatches = (scores ?? []).Where(s => s.Verdict == ShaderVerdict.Mismatch).ToList();
        if (limit > 0 && mismatches.Count > limit) mismatches = mismatches.Take(limit).ToList();

        Console.WriteLine($"clustering {mismatches.Count} mismatches");

        var compiler = new JobCompiler(paths, preferEngine, extraMacros);
        var provider = ReferenceShaderProvider.Load(paths.ObjectDbPath, paths.GameRoot);

        var clusters = new Dictionary<string, Cluster>(StringComparer.Ordinal);
        int done = 0, failed = 0;

        foreach (var group in mismatches.GroupBy(m => (m.PackageFile, m.Material)))
        {
            var packageRoot = Path.GetFileNameWithoutExtension(group.Key.PackageFile);
            var reference = provider.GetShaders([$"{packageRoot}.{group.Key.Material}", group.Key.Material]);

            foreach (var score in group)
            {
                done++;
                if (done % 50 == 0) Console.WriteLine($"  {done}/{mismatches.Count}");

                if (!TryDecompilePair(score, reference, compiler, out var ourHlsl, out var refHlsl))
                {
                    failed++;
                    continue;
                }

                var signature = DiffSignature.Compute(ourHlsl, refHlsl);
                if (!clusters.TryGetValue(signature, out var cluster))
                {
                    var (onlyOurs, onlyRef) = DiffSignature.Delta(ourHlsl, refHlsl);
                    int ourLines = ourHlsl.Split('\n').Length;

                    cluster = new Cluster
                    {
                        Signature = signature,
                        RepresentativeJson = score.JsonPath,
                        OnlyInOurs = onlyOurs.Take(40).ToList(),
                        OnlyInReference = onlyRef.Take(40).ToList(),
                        // Diffuse whole-shader differences are the signature of compile flags, not a
                        // macro: no single construct changed, the whole body was scheduled differently.
                        LooksLikeCompileFlags = ourLines > 0 && onlyOurs.Count > ourLines / 2
                    };
                    clusters[signature] = cluster;
                }

                cluster.Count++;
                var materialKey = $"{group.Key.PackageFile}|{group.Key.Material}";
                if (!cluster.Materials.Contains(materialKey)) cluster.Materials.Add(materialKey);
                if (!cluster.ShaderTypes.Contains(score.ShaderType)) cluster.ShaderTypes.Add(score.ShaderType);
                if (!cluster.VertexFactories.Contains(score.VertexFactory)) cluster.VertexFactories.Add(score.VertexFactory);
            }

            provider.ReleaseCache();
        }

        var ranked = clusters.Values.OrderByDescending(c => c.Count).ToList();
        WriteReport(paths, ranked);
        PrintSummary(ranked, mismatches.Count, failed);
        return 0;
    }

    private static bool TryDecompilePair(
        ShaderScore score, ReferenceShaderSet reference, JobCompiler compiler,
        out string ourHlsl, out string refHlsl)
    {
        ourHlsl = refHlsl = "";

        var vfKey = string.IsNullOrEmpty(score.VertexFactory) ? ReferenceShaderSet.NoVertexFactory : score.VertexFactory;
        if (!reference.Shaders.TryGetValue((vfKey, score.ShaderType), out var refShader)) return false;

        var pkg = JobCompiler.Load(score.JsonPath);
        if (pkg == null) return false;

        CompileResult result;
        try
        {
            result = compiler.Compile(pkg, score.ShaderType);
        }
        catch
        {
            return false;
        }
        if (!result.Success) return false;

        try
        {
            ourHlsl = HLSLDecompiler.DecompileShader(result.ByteCode, false);
            refHlsl = HLSLDecompiler.DecompileShader(refShader.ByteCode, false);
        }
        catch
        {
            return false;
        }

        return ourHlsl.Length > 0 && refHlsl.Length > 0;
    }

    private static void WriteReport(ToolPaths paths, List<Cluster> ranked)
    {
        Directory.CreateDirectory(paths.OutputDir);

        var jsonPath = Path.Combine(paths.OutputDir, "clusters.json");
        using (var fs = File.Create(jsonPath))
        {
            JsonSerializer.Serialize(fs, ranked, new JsonSerializerOptions { WriteIndented = true });
        }

        // A readable worklist: each cluster with its structural delta, biggest first.
        var sb = new StringBuilder();
        foreach (var c in ranked)
        {
            sb.AppendLine($"===== {c.Signature}  ({c.Count} shaders){(c.LooksLikeCompileFlags ? "  [diffuse — suspect compile flags, not a macro]" : "")}");
            sb.AppendLine($"  shader types    : {string.Join(", ", c.ShaderTypes.Take(6))}{(c.ShaderTypes.Count > 6 ? $" (+{c.ShaderTypes.Count - 6})" : "")}");
            sb.AppendLine($"  vertex factories: {string.Join(", ", c.VertexFactories.Take(6))}{(c.VertexFactories.Count > 6 ? $" (+{c.VertexFactories.Count - 6})" : "")}");
            sb.AppendLine($"  representative  : {c.RepresentativeJson}");
            sb.AppendLine("  --- only in ours ---");
            foreach (var l in c.OnlyInOurs) sb.AppendLine($"    - {l}");
            sb.AppendLine("  --- only in reference ---");
            foreach (var l in c.OnlyInReference) sb.AppendLine($"    + {l}");
            sb.AppendLine();
        }
        File.WriteAllText(Path.Combine(paths.OutputDir, "clusters.txt"), sb.ToString());

        Console.WriteLine($"\nreports written to {jsonPath} and clusters.txt");
    }

    private static void PrintSummary(List<Cluster> ranked, int mismatches, int failed)
    {
        Console.WriteLine();
        Console.WriteLine("=== mismatch clusters ===");
        Console.WriteLine($"  mismatches        {mismatches,6}");
        Console.WriteLine($"  distinct causes   {ranked.Count,6}");
        if (failed > 0) Console.WriteLine($"  could not analyse {failed,6}");

        Console.WriteLine("\n  largest clusters:");
        foreach (var c in ranked.Take(12))
        {
            var flag = c.LooksLikeCompileFlags ? "  [flags?]" : "";
            var types = string.Join(", ", c.ShaderTypes.Take(2));
            if (c.ShaderTypes.Count > 2) types += $" +{c.ShaderTypes.Count - 2}";
            Console.WriteLine($"    {c.Count,5}  {c.Signature}  {types}{flag}");
        }

        if (ranked.Count > 0)
        {
            int top = ranked.Take(5).Sum(c => c.Count);
            Console.WriteLine($"\n  top 5 clusters cover {top}/{mismatches} mismatches ({100.0 * top / Math.Max(mismatches, 1):F0}%)");
        }
    }
}
