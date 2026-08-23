using System.Collections.Concurrent;
using System.Security.Cryptography;
using System.Text.Json;
using MilanShaderHost;
using Newtonsoft.Json;
using JsonSerializer = System.Text.Json.JsonSerializer;

namespace ShaderResearchTool;

public enum ShaderVerdict
{
    /// <summary>Our bytecode is byte-identical to what LE3 ships. The goal.</summary>
    Exact,

    /// <summary>Compiled, but the bytecode differs. This is the macro/flag problem.</summary>
    Mismatch,

    /// <summary>Our compile failed outright.</summary>
    CompileFailed,

    /// <summary>No shipping shader to compare against for this permutation.</summary>
    NoReference
}

public sealed class ShaderScore
{
    public string Material { get; set; } = "";
    public string PackageFile { get; set; } = "";
    public string VertexFactory { get; set; } = "";
    public string ShaderType { get; set; } = "";
    public ShaderVerdict Verdict { get; set; }
    public int OurSize { get; set; }
    public int ReferenceSize { get; set; }
    public string? Error { get; set; }
    public string JsonPath { get; set; } = "";
}

/// <summary>
/// The calibration scoreboard: recompiles every captured job offline and compares the result to the
/// bytecode LE3 ships, producing a corpus-wide exact-match rate sliced by shader type and vertex
/// factory.
/// </summary>
public static class ScoreboardCommand
{
    public static int Run(ToolPaths paths, int limit, string? shaderTypeFilter, bool preferEngine,
        IEnumerable<string>? extraMacros = null)
    {
        var jobs = DebugPackageCorpus.Enumerate(paths.DebugPackagesDir);
        if (jobs.Count == 0)
        {
            Console.Error.WriteLine($"no debug packages under {paths.DebugPackagesDir}");
            return 1;
        }

        if (shaderTypeFilter != null)
        {
            jobs = jobs.Where(j => j.ShaderType.Contains(shaderTypeFilter, StringComparison.OrdinalIgnoreCase)).ToList();
        }
        if (limit > 0 && jobs.Count > limit)
        {
            jobs = jobs.Take(limit).ToList();
        }

        Console.WriteLine($"scoring {jobs.Count} captured jobs");

        var includesDir = Path.Combine(paths.GameRoot, "Engine", "Shaders");
        if (!Directory.Exists(includesDir))
        {
            Console.Error.WriteLine($"shader include directory not found: {includesDir}");
            return 1;
        }

        var compiler = new JobCompiler(paths, preferEngine, extraMacros);
        if (preferEngine) Console.WriteLine("resolving recorded macro conflicts in the engine's favour");
        if (compiler.RecoveredFlagCount > 0)
        {
            Console.WriteLine($"using recovered compile flags for {compiler.RecoveredFlagCount} shader types");
        }

        var provider = ReferenceShaderProvider.Load(paths.ObjectDbPath, paths.GameRoot);
        var results = new List<ShaderScore>();
        int done = 0;

        // Grouped by material so each shipping package is opened once for the whole group.
        foreach (var group in jobs.GroupBy(j => (j.PackageFile, j.MaterialPath)))
        {
            var (packageFile, relativePath) = group.Key;
            var packageRoot = Path.GetFileNameWithoutExtension(packageFile);
            var reference = provider.GetShaders([$"{packageRoot}.{relativePath}", relativePath]);

            foreach (var job in group)
            {
                done++;
                if (done % 250 == 0) Console.WriteLine($"  {done}/{jobs.Count}");
                results.Add(Score(job, reference, compiler));
            }

            provider.ReleaseCache();
        }

        WriteReport(paths, results);
        PrintSummary(results);
        return 0;
    }

    private static ShaderScore Score(DebugJobRef job, ReferenceShaderSet reference, JobCompiler compiler)
    {
        var score = new ShaderScore
        {
            Material = job.MaterialPath,
            PackageFile = job.PackageFile,
            VertexFactory = job.VertexFactory,
            ShaderType = job.ShaderType,
            JsonPath = job.JsonPath
        };

        var pkg = JobCompiler.Load(job.JsonPath);
        if (pkg == null)
        {
            score.Verdict = ShaderVerdict.CompileFailed;
            score.Error = "unreadable debug package";
            return score;
        }

        // The captured vertex factory folder is "None" for non-mesh shaders.
        var vfKey = string.IsNullOrEmpty(job.VertexFactory) ? ReferenceShaderSet.NoVertexFactory : job.VertexFactory;
        if (!reference.Shaders.TryGetValue((vfKey, job.ShaderType), out var refShader))
        {
            score.Verdict = ShaderVerdict.NoReference;
            score.Error = reference.Error;
            return score;
        }

        score.ReferenceSize = refShader.ByteCode.Length;

        CompileResult result;
        try
        {
            result = compiler.Compile(pkg, job.ShaderType);
        }
        catch (Exception ex)
        {
            score.Verdict = ShaderVerdict.CompileFailed;
            score.Error = ex.Message;
            return score;
        }

        if (!result.Success)
        {
            score.Verdict = ShaderVerdict.CompileFailed;
            score.Error = result.ErrorMessage;
            return score;
        }

        score.OurSize = result.ByteCode.Length;
        score.Verdict = result.ByteCode.AsSpan().SequenceEqual(refShader.ByteCode)
            ? ShaderVerdict.Exact
            : ShaderVerdict.Mismatch;

        return score;
    }

    private static void WriteReport(ToolPaths paths, List<ShaderScore> results)
    {
        Directory.CreateDirectory(paths.OutputDir);
        var jsonPath = Path.Combine(paths.OutputDir, "scoreboard.json");
        using var fs = File.Create(jsonPath);
        JsonSerializer.Serialize(fs, results, new JsonSerializerOptions { WriteIndented = true });
        Console.WriteLine($"\nreport written to {jsonPath}");
    }

    private static void PrintSummary(List<ShaderScore> results)
    {
        Console.WriteLine();
        Console.WriteLine("=== scoreboard ===");
        Console.WriteLine($"  scored  {results.Count,7}");
        foreach (var verdict in Enum.GetValues<ShaderVerdict>())
        {
            int count = results.Count(r => r.Verdict == verdict);
            double pct = results.Count == 0 ? 0 : 100.0 * count / results.Count;
            Console.WriteLine($"  {verdict,-14} {count,7}  ({pct,5:F1}%)");
        }

        var comparable = results.Where(r => r.Verdict is ShaderVerdict.Exact or ShaderVerdict.Mismatch).ToList();
        if (comparable.Count > 0)
        {
            double rate = 100.0 * comparable.Count(r => r.Verdict == ShaderVerdict.Exact) / comparable.Count;
            Console.WriteLine($"\n  exact-match rate over comparable shaders: {rate:F1}%");
        }

        var worst = results.Where(r => r.Verdict == ShaderVerdict.Mismatch)
            .GroupBy(r => r.ShaderType)
            .Select(g => (Type: g.Key, Count: g.Count()))
            .OrderByDescending(x => x.Count)
            .Take(15).ToList();

        if (worst.Count > 0)
        {
            Console.WriteLine("\n  shader types with the most mismatches:");
            foreach (var (type, count) in worst) Console.WriteLine($"    {count,6}  {type}");
        }
    }
}
