using System.Text;
using System.Text.Json;

namespace ShaderResearchTool;

/// <summary>
/// Joins the captured debug-package corpus against the shipping LE3 shader maps.
///
/// This answers two things before any shader is recompiled: how much of the corpus has a reference
/// to compare against at all, and which shipping permutations were never captured (coverage holes).
/// </summary>
public static class CoverageCommand
{
    public static int Run(ToolPaths paths)
    {
        var jobs = DebugPackageCorpus.Enumerate(paths.DebugPackagesDir);
        if (jobs.Count == 0)
        {
            Console.Error.WriteLine($"no debug packages under {paths.DebugPackagesDir}");
            return 1;
        }

        // A material is identified by the package it came from plus its package-relative path.
        var byMaterial = jobs.GroupBy(j => (j.PackageFile, j.MaterialPath)).ToList();
        Console.WriteLine($"corpus: {jobs.Count} jobs across {byMaterial.Count} materials");

        Console.WriteLine($"loading object DB {Path.GetFileName(paths.ObjectDbPath)}");
        var provider = ReferenceShaderProvider.Load(paths.ObjectDbPath, paths.GameRoot);

        int materialsResolved = 0, materialsMissing = 0;
        int jobsMatched = 0, jobsNoReference = 0;
        int shippingPermutationsNotCaptured = 0;

        var missingMaterials = new List<string>();
        var unmatchedJobs = new List<string>();
        var uncapturedPermutations = new List<string>();
        var perShaderType = new Dictionary<string, (int matched, int missing)>();

        int done = 0;
        foreach (var group in byMaterial)
        {
            done++;
            if (done % 100 == 0) Console.WriteLine($"  {done}/{byMaterial.Count} materials");

            var (packageFile, relativePath) = group.Key;
            var packageRoot = Path.GetFileNameWithoutExtension(packageFile);
            var label = $"{packageFile}/{relativePath}";

            // ShaderClient drops the root package prefix, so try the prefixed form first.
            var reference = provider.GetShaders([$"{packageRoot}.{relativePath}", relativePath]);
            if (reference.Shaders.Count == 0)
            {
                materialsMissing++;
                missingMaterials.Add($"{label}\t{reference.Error}");
                jobsNoReference += group.Count();
                foreach (var job in group) Tally(perShaderType, job.ShaderType, matched: false);
                continue;
            }

            materialsResolved++;

            var capturedKeys = new HashSet<(string, string)>();
            foreach (var job in group)
            {
                var key = (job.VertexFactory, job.ShaderType);
                capturedKeys.Add(key);

                if (reference.Shaders.ContainsKey(key))
                {
                    jobsMatched++;
                    Tally(perShaderType, job.ShaderType, matched: true);
                }
                else
                {
                    jobsNoReference++;
                    unmatchedJobs.Add($"{label}\t{job.VertexFactory}\t{job.ShaderType}");
                    Tally(perShaderType, job.ShaderType, matched: false);
                }
            }

            foreach (var key in reference.Shaders.Keys)
            {
                if (capturedKeys.Contains(key)) continue;
                shippingPermutationsNotCaptured++;
                uncapturedPermutations.Add($"{label}\t{key.vf}\t{key.type}");
            }
        }

        Directory.CreateDirectory(paths.OutputDir);
        File.WriteAllLines(Path.Combine(paths.OutputDir, "coverage-missing-materials.txt"), missingMaterials);
        File.WriteAllLines(Path.Combine(paths.OutputDir, "coverage-unmatched-jobs.txt"), unmatchedJobs);
        File.WriteAllLines(Path.Combine(paths.OutputDir, "coverage-uncaptured-permutations.txt"), uncapturedPermutations);

        using (var fs = File.Create(Path.Combine(paths.OutputDir, "coverage.json")))
        {
            JsonSerializer.Serialize(fs, new
            {
                jobs = jobs.Count,
                materials = byMaterial.Count,
                materialsResolved,
                materialsMissing,
                jobsMatched,
                jobsNoReference,
                shippingPermutationsNotCaptured,
                perShaderType = perShaderType.ToDictionary(k => k.Key, v => new { v.Value.matched, v.Value.missing })
            }, new JsonSerializerOptions { WriteIndented = true });
        }

        Console.WriteLine();
        Console.WriteLine("=== corpus coverage ===");
        Console.WriteLine($"  captured jobs                  {jobs.Count,7}");
        Console.WriteLine($"    with shipping reference      {jobsMatched,7}  ({Pct(jobsMatched, jobs.Count)})");
        Console.WriteLine($"    without reference            {jobsNoReference,7}  ({Pct(jobsNoReference, jobs.Count)})");
        Console.WriteLine($"  captured materials             {byMaterial.Count,7}");
        Console.WriteLine($"    resolved to shipping map     {materialsResolved,7}");
        Console.WriteLine($"    unresolved                   {materialsMissing,7}");
        Console.WriteLine($"  shipping permutations missed   {shippingPermutationsNotCaptured,7}   (in game, never captured)");

        var worst = perShaderType.Where(kv => kv.Value.missing > 0)
                                 .OrderByDescending(kv => kv.Value.missing)
                                 .Take(10).ToList();
        if (worst.Count > 0)
        {
            Console.WriteLine("\n  shader types with the most unreferenced jobs:");
            foreach (var (type, v) in worst)
            {
                Console.WriteLine($"    {v.missing,6} missing / {v.matched,6} matched   {type}");
            }
        }

        return 0;
    }

    private static void Tally(Dictionary<string, (int matched, int missing)> map, string shaderType, bool matched)
    {
        map.TryGetValue(shaderType, out var cur);
        map[shaderType] = matched ? (cur.matched + 1, cur.missing) : (cur.matched, cur.missing + 1);
    }

    private static string Pct(int n, int total) => total == 0 ? "0.0%" : $"{100.0 * n / total:F1}%";
}
