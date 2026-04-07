using LegendaryExplorerCore.Shaders;
using MilanShaderHost;
using System.Collections.Concurrent;
using System.Diagnostics;
using System.IO;
using System.Security.Cryptography;
using System.Text.Json;

namespace MilanShaderResearchTool;

/// <summary>
/// Result of the macro set search for a single shader type.
/// </summary>
public class ShaderMacroSearchResult
{
    public string VertexFactoryName { get; set; } = "";
    public string ShaderTypeName { get; set; } = "";
    public bool Found { get; set; }
    public List<MacroResult> Macros { get; set; } = [];
    public string Status { get; set; } = "";
    public string SearchPhase { get; set; } = "";
    public double ElapsedSeconds { get; set; }

    /// <summary>
    /// Path to the debug package JSON file this result was produced from.
    /// </summary>
    public string JsonPath { get; set; } = "";

    /// <summary>
    /// Decompiled HLSL of the reference bytecode (the expected output).
    /// </summary>
    public string ReferenceDecompilation { get; set; } = "";

    /// <summary>
    /// MD5 hash (lowercase hex) of the reference bytecode, for use with the probe hash feature.
    /// </summary>
    public string ReferenceHash { get; set; } = "";

    public class MacroResult
    {
        public string Name { get; set; } = "";
        public string Definition { get; set; } = "";
    }
}

/// <summary>
/// Progress update for the macro set finder.
/// </summary>
public class MacroSetFinderProgress
{
    public int TotalShaders { get; init; }
    public int CompletedShaders { get; init; }
    public string CurrentShader { get; init; } = "";
    public string CurrentPhase { get; init; } = "";
    public string Message { get; init; } = "";
    public ShaderMacroSearchResult? Result { get; init; }
}

/// <summary>
/// Automated macro set finder. For each shader type in a debug package folder,
/// determines the exact macro combination that produces a compilation matching
/// the reference bytecode (compared via decompiled HLSL).
/// </summary>
public class MacroSetFinder
{
    /// <summary>
    /// Delegate that returns reference bytecode for a given shader type and vertex factory.
    /// vertexFactoryName is null if there is no vertex factory.
    /// </summary>
    public delegate byte[]? GetReferenceBytecodeDelegate(string shaderTypeName, string? vertexFactoryName);

    /// <summary>
    /// Delegate that compiles a shader and returns (hresult, bytecodeOrEmpty, errorMessage).
    /// </summary>
    public delegate (int Result, byte[] ShaderBytes, string ErrorMessage) CompileShaderDelegate(
        string baseShaderName, string materialHlsl, string vertexFactoryName,
        string includesDirectory, (string Name, string Definition)[] macros,
        string entryPoint, string shaderType, int compileFlags);

    private readonly CompileShaderDelegate _compileShader;
    private readonly string _includesDirectory;
    private static readonly TimeSpan PerShaderTimeout = TimeSpan.FromMinutes(1);

    // Compilation flags: backwards compat (1<<12) + opt level 3 (1<<15)
    private const int BaseCompileFlags = (1 << 12) | (1 << 15);
    private const int PreferFlowFlag = (1 << 10);

    public MacroSetFinder(CompileShaderDelegate compileShader, string includesDirectory)
    {
        _compileShader = compileShader;
        _includesDirectory = includesDirectory;
    }

    /// <summary>
    /// Searches the debug package folder for all shader types and finds the macro set
    /// for each that produces a compilation matching the reference bytecode.
    /// </summary>
    public async Task<List<ShaderMacroSearchResult>> FindAllMacroSetsAsync(
        string debugPackageFolder,
        GetReferenceBytecodeDelegate getReferenceBytecode,
        IProgress<MacroSetFinderProgress> progress,
        CancellationToken cancellationToken,
        bool onlyFailedCompilations = false)
    {
        // Enumerate all debug packages: <VertexFactoryName>/<ShaderTypeName>.json
        var debugPackages = EnumerateDebugPackages(debugPackageFolder);

        if (onlyFailedCompilations)
        {
            var filtered = new List<(string, string, string)>();
            foreach (var pkg in debugPackages)
            {
                if (cancellationToken.IsCancellationRequested) break;
                try
                {
                    // Basic JSON check for compileSucceeded
                    var json = await File.ReadAllTextAsync(pkg.JsonPath, cancellationToken);
                    var package = JsonSerializer.Deserialize<ShaderClientDebugPackage>(
                        json, new JsonSerializerOptions { PropertyNameCaseInsensitive = true });
                    if (package != null && !package.compileSucceeded)
                    {
                        filtered.Add(pkg);
                    }
                }
                catch
                {
                    // If we can't read it, skip it
                }
            }
            debugPackages = filtered;
        }

        var results = new List<ShaderMacroSearchResult>();
        int completed = 0;

        foreach (var (vertexFactoryName, shaderTypeName, jsonPath) in debugPackages)
        {
            cancellationToken.ThrowIfCancellationRequested();
            progress.Report(new MacroSetFinderProgress
            {
                TotalShaders = debugPackages.Count,
                CompletedShaders = completed,
                CurrentShader = $"{vertexFactoryName}/{shaderTypeName}",
                CurrentPhase = "Loading",
                Message = $"[{completed + 1}/{debugPackages.Count}] Starting {vertexFactoryName}/{shaderTypeName}..."
            });

            var result = await Task.Run(() =>
                FindMacroSetForShader(vertexFactoryName, shaderTypeName, jsonPath,
                    getReferenceBytecode, progress, debugPackages.Count, completed, cancellationToken),
                cancellationToken);

            results.Add(result);
            completed++;

            progress.Report(new MacroSetFinderProgress
            {
                TotalShaders = debugPackages.Count,
                CompletedShaders = completed,
                CurrentShader = $"{vertexFactoryName}/{shaderTypeName}",
                CurrentPhase = result.Found ? "Matched" : "Done",
                Message = $"[{completed}/{debugPackages.Count}] {vertexFactoryName}/{shaderTypeName}: {result.Status}",
                Result = result
            });
        }

        return results;
    }

    private static List<(string VertexFactoryName, string ShaderTypeName, string JsonPath)> EnumerateDebugPackages(string folder)
    {
        var packages = new List<(string, string, string)>();

        foreach (var vfDir in Directory.GetDirectories(folder))
        {
            var vertexFactoryName = Path.GetFileName(vfDir);
            foreach (var jsonFile in Directory.GetFiles(vfDir, "*.json"))
            {
                var shaderTypeName = Path.GetFileNameWithoutExtension(jsonFile);
                packages.Add((vertexFactoryName, shaderTypeName, jsonFile));
            }
        }

        // Also check for root-level json files (no vertex factory)
        foreach (var jsonFile in Directory.GetFiles(folder, "*.json"))
        {
            var shaderTypeName = Path.GetFileNameWithoutExtension(jsonFile);
            packages.Add(("None", shaderTypeName, jsonFile));
        }

        return packages;
    }

    private ShaderMacroSearchResult FindMacroSetForShader(
        string vertexFactoryName, string shaderTypeName, string jsonPath,
        GetReferenceBytecodeDelegate getReferenceBytecode,
        IProgress<MacroSetFinderProgress> progress,
        int totalShaders, int completedSoFar,
        CancellationToken cancellationToken)
    {
        var sw = System.Diagnostics.Stopwatch.StartNew();
        using var timeoutCts = new CancellationTokenSource(PerShaderTimeout);
        using var linkedCts = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken, timeoutCts.Token);
        var token = linkedCts.Token;

        var result = new ShaderMacroSearchResult
        {
            VertexFactoryName = vertexFactoryName,
            ShaderTypeName = shaderTypeName,
            JsonPath = jsonPath,
        };

        try
        {
            // Load debug package
            var json = File.ReadAllText(jsonPath);
            var package = JsonSerializer.Deserialize<ShaderClientDebugPackage>(
                json, new JsonSerializerOptions { PropertyNameCaseInsensitive = true })!;

            // Get reference bytecode and decompile
            var vfForDelegate = vertexFactoryName == "None" ? null : vertexFactoryName;
            var referenceBytecode = getReferenceBytecode(shaderTypeName, vfForDelegate);
            if (referenceBytecode == null || referenceBytecode.Length == 0)
            {
                result.Status = "No reference bytecode available";
                result.ElapsedSeconds = sw.Elapsed.TotalSeconds;
                return result;
            }

            var referenceDecompiled = DecompileShader(referenceBytecode);
            if (string.IsNullOrEmpty(referenceDecompiled) || referenceDecompiled.StartsWith("Decompilation failed"))
            {
                result.Status = "Failed to decompile reference bytecode";
                result.ElapsedSeconds = sw.Elapsed.TotalSeconds;
                return result;
            }

            result.ReferenceDecompilation = referenceDecompiled;
            result.ReferenceHash = Convert.ToHexString(MD5.HashData(referenceBytecode)).ToLowerInvariant();
            var referenceLines = NormalizeDecompiled(referenceDecompiled);

            // Extract compilation parameters from debug package
            var baseShaderName = package.sourceFilename ?? "";
            var vfName = package.vertexFactoryShaderFilename ?? "";
            var entryPoint = package.functionName ?? "Main";
            var shaderProfile = package.profile ?? "ps";
            var materialHlsl = package.materialHlsl ?? "";

            // Build the initial macro set from the debug package's macros
            var baseMacros = new List<(string Name, string Definition)>();
            if (package.macros != null)
            {
                foreach (var m in package.macros)
                    baseMacros.Add((m.name ?? "", m.definition ?? ""));
            }

            // Build candidate macros from possibleMacros that aren't in base
            var baseNames = new HashSet<string>(baseMacros.Select(m => m.Name));
            var candidateMacros = new List<(string Name, string Definition)>();
            if (package.possibleMacros != null)
            {
                foreach (var pm in package.possibleMacros)
                {
                    if (!baseNames.Contains(pm) && !IsExcludedMacro(pm))
                        candidateMacros.Add((pm, "1"));
                }
            }

            void ReportPhase(string phase, string message)
            {
                progress.Report(new MacroSetFinderProgress
                {
                    TotalShaders = totalShaders,
                    CompletedShaders = completedSoFar,
                    CurrentShader = $"{vertexFactoryName}/{shaderTypeName}",
                    CurrentPhase = phase,
                    Message = message
                });
            }

            // Phase 0: Try base macros as-is
            ReportPhase("Phase 0", $"Trying base macros ({baseMacros.Count} macros)...");
            var matchResult = TryCompileAndMatch(baseShaderName, materialHlsl, vfName,
                baseMacros.ToArray(), entryPoint, shaderProfile, referenceLines);

            if (matchResult.IsMatch)
            {
                result.Found = true;
                result.Status = "Matched with base macros";
                result.SearchPhase = "Phase 0 (Base)";
                result.Macros = baseMacros.Select(m => new ShaderMacroSearchResult.MacroResult
                    { Name = m.Name, Definition = m.Definition }).ToList();
                result.ElapsedSeconds = sw.Elapsed.TotalSeconds;
                return result;
            }

            token.ThrowIfCancellationRequested();

            // Phase 1: One-off addition — try adding each candidate macro individually
            ReportPhase("Phase 1", $"One-off addition: probing {candidateMacros.Count} candidates...");
            var addResult = ProbeOneOff(baseMacros, candidateMacros, true,
                baseShaderName, materialHlsl, vfName, entryPoint, shaderProfile, referenceLines, token);

            if (addResult != null)
            {
                result.Found = true;
                result.Status = $"Matched by adding macro '{addResult.ChangedMacro}'";
                result.SearchPhase = "Phase 1 (Add Single)";
                result.Macros = addResult.FinalMacros.Select(m => new ShaderMacroSearchResult.MacroResult
                    { Name = m.Name, Definition = m.Definition }).ToList();
                result.ElapsedSeconds = sw.Elapsed.TotalSeconds;
                return result;
            }

            token.ThrowIfCancellationRequested();

            // Phase 1.5: One-off value change — try altering each NUM_* base macro's value
            ReportPhase("Phase 1.5", "One-off value change: probing NUM_* base macros...");
            var valueChangeResult = ProbeOneOffValueChange(baseMacros,
                baseShaderName, materialHlsl, vfName, entryPoint, shaderProfile, referenceLines, token);

            if (valueChangeResult != null)
            {
                result.Found = true;
                result.Status = $"Matched by changing value of '{valueChangeResult.ChangedMacro}'";
                result.SearchPhase = "Phase 1.5 (Value Change)";
                result.Macros = valueChangeResult.FinalMacros.Select(m => new ShaderMacroSearchResult.MacroResult
                    { Name = m.Name, Definition = m.Definition }).ToList();
                result.ElapsedSeconds = sw.Elapsed.TotalSeconds;
                return result;
            }

            token.ThrowIfCancellationRequested();

            // Phase 2: One-off removal — try removing each base macro individually
            ReportPhase("Phase 2", $"One-off removal: probing {baseMacros.Count} base macros...");
            var removeResult = ProbeOneOff(baseMacros, baseMacros, false,
                baseShaderName, materialHlsl, vfName, entryPoint, shaderProfile, referenceLines, token);

            if (removeResult != null)
            {
                result.Found = true;
                result.Status = $"Matched by removing macro '{removeResult.ChangedMacro}'";
                result.SearchPhase = "Phase 2 (Remove Single)";
                result.Macros = removeResult.FinalMacros.Select(m => new ShaderMacroSearchResult.MacroResult
                    { Name = m.Name, Definition = m.Definition }).ToList();
                result.ElapsedSeconds = sw.Elapsed.TotalSeconds;
                return result;
            }

            token.ThrowIfCancellationRequested();

            // Phase 3: Greedy search — iteratively add/remove macros to improve match
            ReportPhase("Phase 3", "Greedy search...");
            var greedyResult = GreedySearch(baseMacros, candidateMacros,
                baseShaderName, materialHlsl, vfName, entryPoint, shaderProfile, referenceLines,
                progress, vertexFactoryName, shaderTypeName, totalShaders, completedSoFar, token);

            if (greedyResult != null)
            {
                result.Found = true;
                result.Status = $"Matched via greedy search ({greedyResult.Value.Iterations} iterations)";
                result.SearchPhase = "Phase 3 (Greedy)";
                result.Macros = greedyResult.Value.FinalMacros.Select(m => new ShaderMacroSearchResult.MacroResult
                    { Name = m.Name, Definition = m.Definition }).ToList();
                result.ElapsedSeconds = sw.Elapsed.TotalSeconds;
                return result;
            }

            result.Status = "No matching macro set found within time limit";
            result.SearchPhase = "Exhausted";
            result.Macros = baseMacros.Select(m => new ShaderMacroSearchResult.MacroResult
                { Name = m.Name, Definition = m.Definition }).ToList();
        }
        catch (OperationCanceledException) when (timeoutCts.IsCancellationRequested)
        {
            result.Status = "Timed out (1 minute limit)";
            result.SearchPhase = "Timeout";
        }
        catch (OperationCanceledException)
        {
            result.Status = "Cancelled";
            result.SearchPhase = "Cancelled";
        }
        catch (Exception ex)
        {
            result.Status = $"Error: {ex.Message}";
            result.SearchPhase = "Error";
        }

        result.ElapsedSeconds = sw.Elapsed.TotalSeconds;
        return result;
    }

    private enum MacroOperation { Add, Remove, ReplaceValue }

    private class OneOffResult
    {
        public string ChangedMacro = "";
        public (string Name, string Definition)[] FinalMacros = [];
    }

    /// <summary>
    /// Probes macros one at a time, either adding to or removing from the base set.
    /// Uses multithreading to test candidates in parallel.
    /// </summary>
    private OneOffResult? ProbeOneOff(
        List<(string Name, string Definition)> baseMacros,
        List<(string Name, string Definition)> candidates,
        bool isAdd,
        string baseShaderName, string materialHlsl, string vfName,
        string entryPoint, string shaderProfile, string[] referenceLines,
        CancellationToken token)
    {
        OneOffResult? found = null;
        int maxConc = Math.Max(1, Environment.ProcessorCount / 2);
        var semaphore = new SemaphoreSlim(maxConc);

        var tasks = candidates.Select(async candidate =>
        {
            if (found != null) return; // Early exit if already found
            await semaphore.WaitAsync(token).ConfigureAwait(false);
            try
            {
                if (found != null) return;
                token.ThrowIfCancellationRequested();

                (string Name, string Definition)[] testMacros;
                CompileMatchResult matchResult;

                if (isAdd && IsNumericalMacro(candidate.Name))
                {
                    (matchResult, _, testMacros) = TryNumericalMacroValues(
                        [.. baseMacros], candidate.Name,
                        baseShaderName, materialHlsl, vfName,
                        entryPoint, shaderProfile, referenceLines);
                }
                else
                {
                    testMacros = isAdd
                        ? [.. baseMacros, candidate]
                        : baseMacros.Where(m => m.Name != candidate.Name).ToArray();
                    matchResult = TryCompileAndMatch(baseShaderName, materialHlsl, vfName,
                        testMacros, entryPoint, shaderProfile, referenceLines);
                }

                if (matchResult.IsMatch)
                {
                    Interlocked.CompareExchange(ref found,
                        new OneOffResult { ChangedMacro = candidate.Name, FinalMacros = testMacros },
                        null);
                }
            }
            finally
            {
                semaphore.Release();
            }
        });

        Task.WhenAll(tasks).GetAwaiter().GetResult();
        return found;
    }

    /// <summary>
    /// For each NUM_* macro already in <paramref name="baseMacros"/>, tries replacing its
    /// current value with each of 1–4 (skipping the current value). Macros are probed in
    /// parallel; values for each macro are tried in order, stopping on the first exact match.
    /// </summary>
    private OneOffResult? ProbeOneOffValueChange(
        List<(string Name, string Definition)> baseMacros,
        string baseShaderName, string materialHlsl, string vfName,
        string entryPoint, string shaderProfile, string[] referenceLines,
        CancellationToken token)
    {
        var numericalMacros = baseMacros.Where(m => IsNumericalMacro(m.Name)).ToList();
        if (numericalMacros.Count == 0)
            return null;

        OneOffResult? found = null;
        int maxConc = Math.Max(1, Environment.ProcessorCount / 2);
        var semaphore = new SemaphoreSlim(maxConc);

        var tasks = numericalMacros.Select(async macro =>
        {
            if (found != null) return;
            await semaphore.WaitAsync(token).ConfigureAwait(false);
            try
            {
                if (found != null) return;
                token.ThrowIfCancellationRequested();

                int currentVal = int.TryParse(macro.Definition, out int cv) ? cv : 0;
                (string Name, string Definition)[] baseWithout = baseMacros
                    .Where(m => m.Name != macro.Name).ToArray();

                for (int v = 1; v <= 4; v++)
                {
                    if (v == currentVal) continue;
                    if (found != null) break;
                    (string Name, string Definition)[] testMacros = [.. baseWithout, (macro.Name, v.ToString())];
                    var r = TryCompileAndMatch(baseShaderName, materialHlsl, vfName,
                        testMacros, entryPoint, shaderProfile, referenceLines);
                    if (r.IsMatch)
                    {
                        Interlocked.CompareExchange(ref found,
                            new OneOffResult { ChangedMacro = macro.Name, FinalMacros = testMacros },
                            null);
                    }
                }
            }
            finally
            {
                semaphore.Release();
            }
        });

        Task.WhenAll(tasks).GetAwaiter().GetResult();
        return found;
    }

    private struct GreedyResult
    {
        public (string Name, string Definition)[] FinalMacros;
        public int Iterations;
    }

    /// <summary>
    /// Greedy search: iteratively apply the single-macro change (add or remove) that
    /// maximizes line-similarity to the reference, until a match or timeout.
    /// </summary>
    private GreedyResult? GreedySearch(
        List<(string Name, string Definition)> baseMacros,
        List<(string Name, string Definition)> candidateAdditions,
        string baseShaderName, string materialHlsl, string vfName,
        string entryPoint, string shaderProfile, string[] referenceLines,
        IProgress<MacroSetFinderProgress> progress,
        string vertexFactoryName, string shaderTypeName,
        int totalShaders, int completedSoFar,
        CancellationToken token)
    {
        var currentMacros = new List<(string Name, string Definition)>(baseMacros);
        var currentNames = new HashSet<string>(currentMacros.Select(m => m.Name));
        var availableAdditions = new List<(string Name, string Definition)>(candidateAdditions);

        // Compute baseline similarity
        var baselineMatch = TryCompileAndMatch(baseShaderName, materialHlsl, vfName,
            currentMacros.ToArray(), entryPoint, shaderProfile, referenceLines);
        double bestSimilarity = baselineMatch.Similarity;

        int iteration = 0;
        const int maxIterations = 50;

        while (iteration < maxIterations)
        {
            token.ThrowIfCancellationRequested();
            iteration++;

            progress.Report(new MacroSetFinderProgress
            {
                TotalShaders = totalShaders,
                CompletedShaders = completedSoFar,
                CurrentShader = $"{vertexFactoryName}/{shaderTypeName}",
                CurrentPhase = $"Greedy iter {iteration}",
                Message = $"Greedy iteration {iteration}, best similarity: {bestSimilarity:P1}"
            });

            // Evaluate all possible single-step changes in parallel
            var changes = new ConcurrentBag<(string MacroName, string MacroDefinition, MacroOperation Op, double Similarity, bool IsMatch, (string Name, string Definition)[] Macros)>();
            int maxConc = Math.Max(1, Environment.ProcessorCount / 2);
            var semaphore = new SemaphoreSlim(maxConc);

            var allCandidates = new List<(string Name, string Definition, MacroOperation Op)>();

            // Additions
            foreach (var c in availableAdditions)
                allCandidates.Add((c.Name, c.Definition, MacroOperation.Add));

            // Removals
            foreach (var c in currentMacros)
                allCandidates.Add((c.Name, c.Definition, MacroOperation.Remove));

            // Value replacements for existing NUM_* macros
            foreach (var c in currentMacros.Where(m => IsNumericalMacro(m.Name)))
            {
                int currentVal = int.TryParse(c.Definition, out int cv) ? cv : 0;
                for (int v = 1; v <= 4; v++)
                    if (v != currentVal)
                        allCandidates.Add((c.Name, v.ToString(), MacroOperation.ReplaceValue));
            }

            var tasks = allCandidates.Select(async candidate =>
            {
                await semaphore.WaitAsync(token).ConfigureAwait(false);
                try
                {
                    token.ThrowIfCancellationRequested();

                    (string Name, string Definition)[] testMacros;
                    CompileMatchResult matchResult;
                    string effectiveDef = candidate.Definition;

                    if (candidate.Op == MacroOperation.Add && IsNumericalMacro(candidate.Name))
                    {
                        string winDef;
                        (matchResult, winDef, testMacros) = TryNumericalMacroValues(
                            [.. currentMacros], candidate.Name,
                            baseShaderName, materialHlsl, vfName,
                            entryPoint, shaderProfile, referenceLines);
                        effectiveDef = winDef;
                    }
                    else if (candidate.Op == MacroOperation.ReplaceValue)
                    {
                        testMacros = currentMacros
                            .Select(m => m.Name == candidate.Name ? (m.Name, candidate.Definition) : m)
                            .ToArray();
                        matchResult = TryCompileAndMatch(baseShaderName, materialHlsl, vfName,
                            testMacros, entryPoint, shaderProfile, referenceLines);
                    }
                    else
                    {
                        testMacros = candidate.Op == MacroOperation.Add
                            ? [.. currentMacros, (candidate.Name, candidate.Definition)]
                            : currentMacros.Where(m => m.Name != candidate.Name).ToArray();
                        matchResult = TryCompileAndMatch(baseShaderName, materialHlsl, vfName,
                            testMacros, entryPoint, shaderProfile, referenceLines);
                    }

                    changes.Add((candidate.Name, effectiveDef, candidate.Op, matchResult.Similarity, matchResult.IsMatch, testMacros));
                }
                finally
                {
                    semaphore.Release();
                }
            });

            Task.WhenAll(tasks).GetAwaiter().GetResult();

            // Check if any change produces an exact match
            var exactMatch = changes.FirstOrDefault(c => c.IsMatch);
            if (exactMatch.IsMatch)
            {
                return new GreedyResult { FinalMacros = exactMatch.Macros, Iterations = iteration };
            }

            // Find the best improvement
            var best = changes.OrderByDescending(c => c.Similarity).FirstOrDefault();
            if (best.Similarity <= bestSimilarity)
            {
                // No improvement possible — stuck
                break;
            }

            // Apply the best change
            bestSimilarity = best.Similarity;
            if (best.Op == MacroOperation.Add)
            {
                currentMacros.Add((best.MacroName, best.MacroDefinition));
                currentNames.Add(best.MacroName);
                availableAdditions.RemoveAll(a => a.Name == best.MacroName);
            }
            else if (best.Op == MacroOperation.ReplaceValue)
            {
                var idx = currentMacros.FindIndex(m => m.Name == best.MacroName);
                if (idx >= 0) currentMacros[idx] = (best.MacroName, best.MacroDefinition);
            }
            else
            {
                currentMacros.RemoveAll(m => m.Name == best.MacroName);
                currentNames.Remove(best.MacroName);
                // Put it back in the available additions pool
                availableAdditions.Add((best.MacroName, "1"));
            }
        }

        return null;
    }

    /// <summary>
    /// For a NUM_* macro being added to <paramref name="baseMacros"/>, probes values 1–4
    /// in order. Returns on the first exact match; otherwise returns the highest-similarity
    /// result across all values along with the definition that produced it.
    /// </summary>
    private (CompileMatchResult Result, string WinningDefinition, (string Name, string Definition)[] FinalMacros)
        TryNumericalMacroValues(
            (string Name, string Definition)[] baseMacros,
            string macroName,
            string baseShaderName, string materialHlsl, string vfName,
            string entryPoint, string shaderProfile, string[] referenceLines)
    {
        CompileMatchResult best = default;
        string bestDef = "1";
        (string Name, string Definition)[] bestMacros = [.. baseMacros, (macroName, "1")];

        for (int v = 1; v <= 4; v++)
        {
            var def = v.ToString();
            (string Name, string Definition)[] testMacros = [.. baseMacros, (macroName, def)];
            var r = TryCompileAndMatch(baseShaderName, materialHlsl, vfName,
                testMacros, entryPoint, shaderProfile, referenceLines);
            if (r.IsMatch)
                return (r, def, testMacros);
            if (r.Similarity > best.Similarity)
            {
                best = r;
                bestDef = def;
                bestMacros = testMacros;
            }
        }

        return (best, bestDef, bestMacros);
    }

    private struct CompileMatchResult
    {
        public bool IsMatch;
        public double Similarity;
        public bool Compiled;
    }

    /// <summary>
    /// Compiles with the given macros (trying both normal and prefer-flow-control flags)
    /// and compares decompiled output against reference lines.
    /// </summary>
    private CompileMatchResult TryCompileAndMatch(
        string baseShaderName, string materialHlsl, string vfName,
        (string Name, string Definition)[] macros,
        string entryPoint, string shaderProfile, string[] referenceLines)
    {
        var result = new CompileMatchResult();

        // Try normal flags
        TryCompileWithFlags(baseShaderName, materialHlsl, vfName, macros,
            entryPoint, shaderProfile, BaseCompileFlags, referenceLines, ref result);

        if (result.IsMatch)
            return result;

        // Try with prefer flow control
        TryCompileWithFlags(baseShaderName, materialHlsl, vfName, macros,
            entryPoint, shaderProfile, BaseCompileFlags | PreferFlowFlag, referenceLines, ref result);

        return result;
    }

    private void TryCompileWithFlags(
        string baseShaderName, string materialHlsl, string vfName,
        (string Name, string Definition)[] macros,
        string entryPoint, string shaderProfile, int flags, string[] referenceLines,
        ref CompileMatchResult result)
    {
        try
        {
            var (hresult, shaderBytes, _) = _compileShader(
                baseShaderName, materialHlsl, vfName, _includesDirectory,
                macros, entryPoint, shaderProfile, flags);

            if (hresult != 0 || shaderBytes.Length == 0)
                return;

            result.Compiled = true;

            var decompiled = DecompileShader(shaderBytes);
            if (string.IsNullOrEmpty(decompiled) || decompiled.StartsWith("Decompilation failed"))
                return;

            var candidateLines = NormalizeDecompiled(decompiled);
            double similarity = ComputeLineSimilarity(referenceLines, candidateLines);

            if (similarity > result.Similarity)
                result.Similarity = similarity;

            if (similarity >= 1.0)
                result.IsMatch = true;
        }
        catch
        {
            // Compilation failure
        }
    }

    private static string DecompileShader(byte[] bytecode)
    {
        return HLSLDecompiler.DecompileShader(bytecode, false);
    }

    /// <summary>
    /// Normalizes decompiled HLSL into comparable lines (trims whitespace, removes empty lines).
    /// </summary>
    private static string[] NormalizeDecompiled(string decompiled)
    {
        return decompiled
            .Split('\n')
            .Select(l => l.Trim())
            .Where(l => l.Length > 0)
            .ToArray();
    }

    /// <summary>
    /// Computes line-based similarity ratio between reference and candidate.
    /// Returns 1.0 for identical, 0.0 for completely different.
    /// </summary>
    private static double ComputeLineSimilarity(string[] reference, string[] candidate)
    {
        if (reference.Length == 0 && candidate.Length == 0)
            return 1.0;

        // Quick check for exact match
        if (reference.Length == candidate.Length)
        {
            bool allMatch = true;
            for (int i = 0; i < reference.Length; i++)
            {
                if (reference[i] != candidate[i])
                {
                    allMatch = false;
                    break;
                }
            }
            if (allMatch) return 1.0;
        }

        // Count matching lines using a set-based approach for similarity
        int maxLen = Math.Max(reference.Length, candidate.Length);
        int matching = 0;

        // Use positional matching for ordered similarity
        int minLen = Math.Min(reference.Length, candidate.Length);
        for (int i = 0; i < minLen; i++)
        {
            if (reference[i] == candidate[i])
                matching++;
        }

        return (double)matching / maxLen;
    }

    /// <summary>
    /// Macros that should never be enabled (platform-specific, etc.)
    /// </summary>
    private static bool IsExcludedMacro(string macroName)
    {
        return macroName switch
        {
            "__ORBIS__" or "PS3" or "ORBIS" or "DINGO" or "XBOX"
                or "SM2_PROFILE" or "SM3_PROFILE" => true,
            _ => false
        };
    }

    /// <summary>
    /// Returns true for macros that define a numerical value and should be tested
    /// with values 1–4 (e.g. NUM_LIGHTMAP_COEFFICIENTS). NUM_SAMPLES is excluded
    /// because it has a fixed range unrelated to this search.
    /// </summary>
    private static bool IsNumericalMacro(string macroName)
    {
        return macroName.StartsWith("NUM_", StringComparison.Ordinal) && macroName != "NUM_SAMPLES";
    }

    /// <summary>
    /// Saves results to a JSON file.
    /// </summary>
    public static void SaveResultsToJson(List<ShaderMacroSearchResult> results, string outputPath)
    {
        var options = new JsonSerializerOptions
        {
            WriteIndented = true,
            PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        };
        var json = JsonSerializer.Serialize(results, options);
        File.WriteAllText(outputPath, json);
    }
}
