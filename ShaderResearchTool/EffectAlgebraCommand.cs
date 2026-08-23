using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Packages.CloningImportingAndRelinking;
using LegendaryExplorerCore.Shaders;

namespace ShaderResearchTool;

/// <summary>
/// Tests whether the effect materials are separable: material(parent, effect) = base(parent) plus
/// layer(effect).
///
/// This matters because BioWare's flat T3D export kept one file per effect *name*, losing the
/// per-parent variants. If the structure really is separable, the missing variants can be
/// synthesised from a parent's base graph plus the one surviving layer, and no re-export is needed.
///
/// The premise makes two predictions on a parent x effect grid of shipping shaders:
///   base separable  -- the difference between two parents is the same whichever effect it is
///                      measured through.
///   layer separable -- the difference between two effects is the same whichever parent it is
///                      measured through.
/// Both are checked against shipping bytecode, so a failure is decisive rather than suggestive.
/// Differences are compared as normalised HLSL diff signatures, which ignore register allocation
/// and literal values -- deliberately generous, so a match here is weak evidence and a mismatch is
/// strong evidence against.
/// </summary>
public static class EffectAlgebraCommand
{
    public static int Run(ToolPaths paths, string? shaderType, string? vertexFactory, int gridSize)
    {
        shaderType ??= "FModShadowMeshPixelShader";
        vertexFactory ??= "FGPUSkinVertexFactory";
        if (gridSize <= 0) gridSize = 4;

        Console.WriteLine($"grid {gridSize}x{gridSize} parents x effects, {vertexFactory} / {shaderType}");

        ObjectInstanceDB db;
        using (var fs = File.OpenRead(paths.ObjectDbPath))
        {
            db = ObjectInstanceDB.Deserialize(MEGame.LE3, fs);
        }

        // parent -> effect -> full path
        var byParent = new Dictionary<string, Dictionary<string, string>>(StringComparer.OrdinalIgnoreCase);
        foreach (var ifp in db.GetAllObjectPaths(false))
        {
            if (!ifp.StartsWith("EffectsMaterials.", StringComparison.OrdinalIgnoreCase)) continue;
            int dot = ifp.LastIndexOf('.');
            if (dot < 0) continue;
            var leaf = ifp[(dot + 1)..];
            if (!leaf.StartsWith("CombinedEffect", StringComparison.OrdinalIgnoreCase)) continue;

            var parent = ifp[..dot];
            if (!byParent.TryGetValue(parent, out var effects)) byParent[parent] = effects = new(StringComparer.OrdinalIgnoreCase);
            effects[leaf] = ifp;
        }
        Console.WriteLine($"  {byParent.Count} parents carrying CombinedEffect materials");

        // Pick the effects shared by the most parents, then parents carrying all of them, so the
        // grid is complete and every cell is comparable.
        var effectCounts = byParent.Values
            .SelectMany(e => e.Keys)
            .GroupBy(x => x, StringComparer.OrdinalIgnoreCase)
            .OrderByDescending(g => g.Count())
            .Select(g => g.Key)
            .ToList();

        var chosenEffects = effectCounts.Take(gridSize).ToList();
        var chosenParents = byParent
            .Where(p => chosenEffects.All(e => p.Value.ContainsKey(e)))
            .Select(p => p.Key)
            .OrderBy(x => x, StringComparer.OrdinalIgnoreCase)
            .Take(gridSize)
            .ToList();

        if (chosenParents.Count < 2 || chosenEffects.Count < 2)
        {
            Console.Error.WriteLine("not enough complete grid coverage to test");
            return 1;
        }

        Console.WriteLine($"  effects: {string.Join(", ", chosenEffects)}");
        Console.WriteLine($"  parents: {chosenParents.Count}");
        foreach (var p in chosenParents) Console.WriteLine($"    {p}");

        // Fetch and decompile every cell.
        var provider = ReferenceShaderProvider.Load(paths.ObjectDbPath, paths.GameRoot);
        var hlsl = new Dictionary<(string parent, string effect), string>();
        int missing = 0;

        foreach (var parent in chosenParents)
        {
            foreach (var effect in chosenEffects)
            {
                var ifp = byParent[parent][effect];
                var set = provider.GetShaders(ifp);
                if (!set.Shaders.TryGetValue((vertexFactory, shaderType), out var shader))
                {
                    missing++;
                    continue;
                }
                try
                {
                    hlsl[(parent, effect)] = HLSLDecompiler.DecompileShader(shader.ByteCode, false);
                }
                catch
                {
                    missing++;
                }
            }
            provider.ReleaseCache();
        }
        Console.WriteLine($"  {hlsl.Count} of {chosenParents.Count * chosenEffects.Count} grid cells resolved" +
                          (missing > 0 ? $" ({missing} missing)" : ""));
        Console.WriteLine();

        int baseChecks = 0, baseConsistent = 0, layerChecks = 0, layerConsistent = 0;
        var baseOverlap = new List<double>();
        var layerOverlap = new List<double>();

        // base separable: fix a parent pair, vary the effect the difference is measured through.
        Console.WriteLine("=== base separability: is parent A -> parent B the same difference under every effect?");
        for (int i = 0; i < chosenParents.Count; i++)
        for (int j = i + 1; j < chosenParents.Count; j++)
        {
            var p1 = chosenParents[i];
            var p2 = chosenParents[j];
            var sigs = new Dictionary<string, string>();
            foreach (var e in chosenEffects)
            {
                if (!hlsl.TryGetValue((p1, e), out var a) || !hlsl.TryGetValue((p2, e), out var b)) continue;
                sigs[e] = DiffSignature.Compute(a, b);
            }
            if (sigs.Count < 2) continue;
            baseChecks++;
            var deltas = chosenEffects.Where(e => hlsl.ContainsKey((p1, e)) && hlsl.ContainsKey((p2, e)))
                .Select(e => DeltaLines(hlsl[(p1, e)], hlsl[(p2, e)])).ToList();
            var overlaps = new List<double>();
            for (int x = 0; x < deltas.Count; x++)
            for (int y = x + 1; y < deltas.Count; y++)
                overlaps.Add(Overlap(deltas[x], deltas[y]));
            baseOverlap.AddRange(overlaps);
            var distinct = sigs.Values.Distinct(StringComparer.Ordinal).Count();
            if (distinct == 1) baseConsistent++;
            Console.WriteLine($"  {Short(p1)} vs {Short(p2)}: {distinct} distinct difference(s) across {sigs.Count} effects" +
                              (distinct == 1 ? "   CONSISTENT" : ""));
            if (distinct > 1)
            {
                foreach (var (e, s) in sigs) Console.WriteLine($"      {s}  {e}");
            }
        }

        // layer separable: fix an effect pair, vary the parent it is measured through.
        Console.WriteLine();
        Console.WriteLine("=== layer separability: is effect X -> effect Y the same difference under every parent?");
        for (int i = 0; i < chosenEffects.Count; i++)
        for (int j = i + 1; j < chosenEffects.Count; j++)
        {
            var e1 = chosenEffects[i];
            var e2 = chosenEffects[j];
            var sigs = new Dictionary<string, string>();
            foreach (var p in chosenParents)
            {
                if (!hlsl.TryGetValue((p, e1), out var a) || !hlsl.TryGetValue((p, e2), out var b)) continue;
                sigs[p] = DiffSignature.Compute(a, b);
            }
            if (sigs.Count < 2) continue;
            layerChecks++;
            var ldeltas = chosenParents.Where(p => hlsl.ContainsKey((p, e1)) && hlsl.ContainsKey((p, e2)))
                .Select(p => DeltaLines(hlsl[(p, e1)], hlsl[(p, e2)])).ToList();
            var loverlaps = new List<double>();
            for (int x = 0; x < ldeltas.Count; x++)
            for (int y = x + 1; y < ldeltas.Count; y++)
                loverlaps.Add(Overlap(ldeltas[x], ldeltas[y]));
            layerOverlap.AddRange(loverlaps);
            var distinct = sigs.Values.Distinct(StringComparer.Ordinal).Count();
            if (distinct == 1) layerConsistent++;
            Console.WriteLine($"  {e1} vs {e2}: {distinct} distinct difference(s) across {sigs.Count} parents" +
                              (distinct == 1 ? "   CONSISTENT" : ""));
        }

        Console.WriteLine();
        Console.WriteLine("=== verdict ===");
        Console.WriteLine($"  base separable  : {baseConsistent}/{baseChecks} parent pairs (exact)");
        Console.WriteLine($"  layer separable : {layerConsistent}/{layerChecks} effect pairs (exact)");
        if (baseOverlap.Count > 0)
            Console.WriteLine($"  base  difference overlap : mean {baseOverlap.Average():F3}  max {baseOverlap.Max():F3}");
        if (layerOverlap.Count > 0)
            Console.WriteLine($"  layer difference overlap : mean {layerOverlap.Average():F3}  max {layerOverlap.Max():F3}");
        Console.WriteLine("  (overlap near 1.0 = separable but obscured by optimisation; near 0 = genuinely not separable)");
        if (baseConsistent == baseChecks && layerConsistent == layerChecks && baseChecks > 0)
            Console.WriteLine("  structure is consistent with base(parent) + layer(effect) -- synthesis worth pursuing");
        else
            Console.WriteLine("  the grid does NOT decompose; a material is more than its parent plus its effect");

        // How many distinct base graphs there are decides how much a re-export would even need to
        // cover, so report it either way.
        var perEffectVariants = new List<string>();
        foreach (var e in chosenEffects)
        {
            var sigs = chosenParents.Where(p => hlsl.ContainsKey((p, e)))
                .Select(p => DiffSignature.Compute(hlsl[(p, e)], hlsl[(chosenParents[0], e)]))
                .Distinct(StringComparer.Ordinal).Count();
            perEffectVariants.Add($"{e}={sigs}");
        }
        Console.WriteLine($"  distinct variants within the sampled parents: {string.Join(", ", perEffectVariants)}");
        return 0;
    }

    /// <summary>
    /// Overlap between two structural differences, 0..1. Exact signature equality is too strict
    /// here: the shaders are optimised, so the compiler folds across any base/layer boundary and
    /// two genuinely separable graphs would still not produce identical diffs. A high overlap means
    /// the difference is substantially the same thing plus optimisation noise; a low one means the
    /// differences are unrelated and the structure really does not decompose.
    /// </summary>
    private static double Overlap(IReadOnlyCollection<string> a, IReadOnlyCollection<string> b)
    {
        if (a.Count == 0 && b.Count == 0) return 1.0;
        var sa = new HashSet<string>(a, StringComparer.Ordinal);
        var sb = new HashSet<string>(b, StringComparer.Ordinal);
        var union = new HashSet<string>(sa, StringComparer.Ordinal);
        union.UnionWith(sb);
        if (union.Count == 0) return 1.0;
        var inter = sa.Count + sb.Count - union.Count;
        return (double)inter / union.Count;
    }

    private static List<string> DeltaLines(string a, string b)
    {
        var (onlyA, onlyB) = DiffSignature.Delta(a, b);
        var all = new List<string>(onlyA.Count + onlyB.Count);
        foreach (var l in onlyA) all.Add("-" + l);
        foreach (var l in onlyB) all.Add("+" + l);
        return all;
    }

    private static string Short(string parent)
    {
        int dot = parent.LastIndexOf('.');
        return dot < 0 ? parent : parent[(dot + 1)..];
    }
}
