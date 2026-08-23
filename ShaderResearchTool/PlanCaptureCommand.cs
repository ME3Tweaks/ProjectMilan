using System.Text.Json;

namespace ShaderResearchTool;

/// <summary>
/// Chooses which LE3 materials to capture so that a calibration run covers every shader
/// permutation the shipping game actually contains, with as few materials as possible.
///
/// Runs entirely offline: the shipping shader maps say which (vertex factory, shader type) pairs
/// each material produces, so the set-cover can be solved before the game is ever launched. This
/// matters because a capture run pays a multi-minute RefShaderCache load per launch, so the goal
/// is maximum permutation coverage per material captured.
/// </summary>
public static class PlanCaptureCommand
{
    private sealed class MaterialPermutations
    {
        public string MaterialPath { get; set; } = "";
        public string DecookedFile { get; set; } = "";
        public string ShippingFile { get; set; } = "";
        public List<string> Permutations { get; set; } = [];
        public string FlagSignature { get; set; } = "";
    }

    /// <summary>
    /// Packages the game loads at boot. A material in one of these wins over ours on load, so our
    /// copy never loads and never triggers a compile — the original has to be renamed first for
    /// the capture to work. Heuristic list; extend it as more are found.
    /// </summary>
    private static readonly HashSet<string> StartupPackages = new(StringComparer.OrdinalIgnoreCase)
    {
        "Core.pcc", "Engine.pcc", "SFXGame.pcc", "Startup_INT.pcc", "WwiseAudio.pcc",
        "EngineMaterials.pcc", "EngineResources.pcc", "EngineDebugMaterials.pcc",
        "EngineFonts.pcc", "EngineSounds.pcc", "EditorMaterials.pcc", "EditorResources.pcc"
    };

    private static bool IsStartup(string packageFile) => StartupPackages.Contains(packageFile);

    public static int Run(ToolPaths paths, bool rebuild)
    {
        var index = PackageObjectIndex.Load(Path.Combine(paths.OutputDir, "index-decooked.json"));
        if (index is not { Materials.Count: > 0 })
        {
            Console.Error.WriteLine("decooked index missing — run texture-parity first to build it.");
            return 1;
        }

        var cachePath = Path.Combine(paths.OutputDir, "material-permutations.json");
        var permutations = rebuild ? null : LoadCache(cachePath);

        if (permutations == null)
        {
            permutations = BuildPermutations(paths, index);
            using var fs = File.Create(cachePath);
            JsonSerializer.Serialize(fs, permutations, new JsonSerializerOptions { WriteIndented = false });
            Console.WriteLine($"permutation map saved to {cachePath}");
        }
        else
        {
            Console.WriteLine($"loaded cached permutation map ({permutations.Count} materials)");
        }

        var covered = permutations.Where(p => p.Permutations.Count > 0).ToList();
        var allPermutations = new HashSet<string>(covered.SelectMany(p => p.Permutations));
        var allFlagSignatures = new HashSet<string>(covered.Select(p => p.FlagSignature));

        Console.WriteLine();
        Console.WriteLine($"materials with a shipping shader map : {covered.Count}");
        Console.WriteLine($"distinct (vertexFactory, shaderType) : {allPermutations.Count}");
        Console.WriteLine($"distinct material flag signatures    : {allFlagSignatures.Count}");

        // Two axes: a material covers shader permutations, and it also exhibits one flag
        // combination. Covering every shader type says nothing about covering every blend
        // mode / lighting model, so both are folded into a single cover problem.
        var selection = GreedyCover(covered, allPermutations, allFlagSignatures);

        Directory.CreateDirectory(paths.OutputDir);

        // ShaderHost consumes a package file list, so emit that as well as the material detail.
        var packages = selection.Select(s => s.DecookedFile).Distinct(StringComparer.OrdinalIgnoreCase)
                                .Order(StringComparer.OrdinalIgnoreCase).ToList();
        File.WriteAllLines(Path.Combine(paths.OutputDir, "capture-packages.txt"), packages);
        File.WriteAllLines(Path.Combine(paths.OutputDir, "capture-materials.txt"),
            selection.Select(s => $"{s.DecookedFile}\t{s.MaterialPath}\t{s.Permutations.Count}"));

        // These need the original object renamed before capture, or the game's copy loads first
        // and ours never compiles.
        var startupSelections = selection.Where(s => IsStartup(s.DecookedFile)).ToList();
        File.WriteAllLines(Path.Combine(paths.OutputDir, "capture-needs-rename.txt"),
            startupSelections.Select(s => $"{s.DecookedFile}\t{s.MaterialPath}"));

        Console.WriteLine();
        Console.WriteLine("=== capture plan ===");
        Console.WriteLine($"  materials to capture   {selection.Count,6}");
        Console.WriteLine($"  packages to load       {packages.Count,6}");
        Console.WriteLine($"  permutations covered   {allPermutations.Count,6}  (100% of shipping permutations)");
        Console.WriteLine($"  flag signatures        {allFlagSignatures.Count,6}  (100% of material flag combinations)");
        Console.WriteLine($"  in startup packages    {startupSelections.Count,6}  (original must be renamed first)");
        Console.WriteLine();
        Console.WriteLine("  highest-yield materials:");
        foreach (var s in selection.Take(8))
        {
            var mark = IsStartup(s.DecookedFile) ? " *RENAME*" : "";
            Console.WriteLine($"    {s.Permutations.Count,4} perms  {s.MaterialPath}  [{s.DecookedFile}]{mark}");
        }

        if (startupSelections.Count > 0)
        {
            Console.WriteLine("\n  startup-package materials needing a rename:");
            foreach (var s in startupSelections)
            {
                Console.WriteLine($"    {s.DecookedFile}\t{s.MaterialPath}");
            }
        }
        Console.WriteLine($"\n  wrote capture-packages.txt and capture-materials.txt to {paths.OutputDir}");
        return 0;
    }

    private static List<MaterialPermutations>? LoadCache(string path)
    {
        if (!File.Exists(path)) return null;
        using var fs = File.OpenRead(path);
        return JsonSerializer.Deserialize<List<MaterialPermutations>>(fs);
    }

    private static List<MaterialPermutations> BuildPermutations(ToolPaths paths, PackageObjectIndex index)
    {
        Console.WriteLine($"loading object DB {Path.GetFileName(paths.ObjectDbPath)}");
        var provider = ReferenceShaderProvider.Load(paths.ObjectDbPath, paths.GameRoot);

        // Group by containing shipping file so the provider's package cache actually hits.
        Console.WriteLine("locating materials in shipping game");
        var byFile = new Dictionary<string, List<string>>(StringComparer.OrdinalIgnoreCase);
        int notInGame = 0;

        foreach (var ifp in index.Materials.Keys)
        {
            var files = provider.FilesContaining(ifp);
            if (files.Count == 0)
            {
                notInGame++;
                continue;
            }

            if (!byFile.TryGetValue(files[0], out var list))
            {
                list = [];
                byFile[files[0]] = list;
            }
            list.Add(ifp);
        }

        Console.WriteLine($"  {byFile.Count} shipping packages hold {byFile.Values.Sum(v => v.Count)} materials ({notInGame} not in game)");

        var results = new List<MaterialPermutations>();
        int done = 0;

        foreach (var (file, materials) in byFile)
        {
            done++;
            if (done % 100 == 0) Console.WriteLine($"  {done}/{byFile.Count} packages");

            foreach (var ifp in materials)
            {
                var set = provider.GetShaders(ifp);
                results.Add(new MaterialPermutations
                {
                    MaterialPath = ifp,
                    DecookedFile = index.Materials[ifp].SourceFile,
                    ShippingFile = set.ShippingFile,
                    FlagSignature = set.FlagSignature,
                    Permutations = set.Shaders.Keys.Select(k => $"{k.vf}|{k.type}").ToList()
                });
            }

            provider.ReleaseCache();
        }

        return results;
    }

    /// <summary>
    /// Greedy set cover over both axes at once. Each material contributes its shader permutations
    /// plus its own flag signature, so the result covers every shader type and every material flag
    /// combination the shipping game contains.
    /// </summary>
    private static List<MaterialPermutations> GreedyCover(
        List<MaterialPermutations> candidates,
        HashSet<string> allPermutations,
        HashSet<string> allFlagSignatures)
    {
        static IEnumerable<string> ElementsOf(MaterialPermutations m)
        {
            foreach (var p in m.Permutations) yield return "perm:" + p;
            yield return "flags:" + m.FlagSignature;
        }

        var remaining = new HashSet<string>(allPermutations.Select(p => "perm:" + p));
        foreach (var f in allFlagSignatures) remaining.Add("flags:" + f);

        var pool = candidates.OrderByDescending(c => c.Permutations.Count).ToList();
        var selection = new List<MaterialPermutations>();

        while (remaining.Count > 0)
        {
            MaterialPermutations? best = null;
            int bestGain = 0;

            foreach (var candidate in pool)
            {
                int gain = ElementsOf(candidate).Count(remaining.Contains);
                if (gain > bestGain)
                {
                    bestGain = gain;
                    best = candidate;
                }
            }

            if (best == null) break; // Nothing left can cover the remainder.

            selection.Add(best);
            foreach (var e in ElementsOf(best)) remaining.Remove(e);
            pool.Remove(best);
        }

        return selection;
    }
}
