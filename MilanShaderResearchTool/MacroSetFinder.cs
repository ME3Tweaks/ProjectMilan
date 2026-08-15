using LegendaryExplorerCore.Shaders;
using MilanShaderHost;
using System.Collections.Concurrent;
using System.Diagnostics;
using System.IO;
using System.Security.Cryptography;
using System.Text.Json;
using System.Text.Json.Serialization;

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
    public bool HasReferenceBytecode { get; set; } = true;

    /// <summary>
    /// Path to the debug package JSON file this result was produced from.
    /// </summary>
    public string JsonPath { get; set; } = "";

    /// <summary>
    /// Material name derived from the JsonPath structure: .../<MATERIALNAME>/<VF>/<ShaderType>.json
    /// </summary>
    public string MaterialName => string.IsNullOrEmpty(JsonPath)
        ? ""
        : Path.GetFileName(Path.GetDirectoryName(Path.GetDirectoryName(JsonPath))) ?? "";

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
    /// jsonPath is the path to the debug package JSON being tested.
    /// vertexFactoryName is null if there is no vertex factory.
    /// </summary>
    public delegate byte[]? GetReferenceBytecodeDelegate(string jsonPath, string shaderTypeName, string? vertexFactoryName);

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

    private ExternalMacrosJson? _externalMacros;
    private bool _externalMacrosLoaded;
    private readonly object _externalMacrosLock = new();

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

    /// <summary>
    /// Searches for the macro set for a single shader with a custom timeout and greedy iteration limit.
    /// </summary>
    public async Task<ShaderMacroSearchResult> FindMacroSetForSingleShaderAsync(
        string jsonPath, string vertexFactoryName, string shaderTypeName,
        GetReferenceBytecodeDelegate getReferenceBytecode,
        IProgress<MacroSetFinderProgress> progress,
        CancellationToken cancellationToken,
        TimeSpan timeout,
        int maxGreedyIterations = int.MaxValue)
    {
        return await Task.Run(() =>
            FindMacroSetForShader(vertexFactoryName, shaderTypeName, jsonPath,
                getReferenceBytecode, progress, 1, 0, cancellationToken, timeout, maxGreedyIterations),
            cancellationToken);
    }

    private ShaderMacroSearchResult FindMacroSetForShader(
        string vertexFactoryName, string shaderTypeName, string jsonPath,
        GetReferenceBytecodeDelegate getReferenceBytecode,
        IProgress<MacroSetFinderProgress> progress,
        int totalShaders, int completedSoFar,
        CancellationToken cancellationToken,
        TimeSpan? timeout = null,
        int maxGreedyIterations = 50)
    {
        var sw = System.Diagnostics.Stopwatch.StartNew();
        using var timeoutCts = new CancellationTokenSource(timeout ?? PerShaderTimeout);
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
            var referenceBytecode = getReferenceBytecode(jsonPath, shaderTypeName, vfForDelegate);
            if (referenceBytecode == null || referenceBytecode.Length == 0)
            {
                result.Status = "No reference bytecode available";
                result.HasReferenceBytecode = false;
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

            // Expand candidates using the transitive include graph and external_macros.json
            var expandedCandidates = BuildExpandedCandidateMacros(baseShaderName, baseNames);
            var candidateNameSet = new HashSet<string>(candidateMacros.Select(m => m.Name), StringComparer.Ordinal);
            foreach (var m in expandedCandidates)
            {
                if (candidateNameSet.Add(m.Name))
                    candidateMacros.Add(m);
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
                result.Status = addResult.ChangedMacros.Count == 1
                    ? $"Matched by adding macro '{addResult.ChangedMacros[0]}'"
                    : $"Matched by adding any of: {string.Join(", ", addResult.ChangedMacros)}";
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
                result.Status = valueChangeResult.ChangedMacros.Count == 1
                    ? $"Matched by changing value of '{valueChangeResult.ChangedMacros[0]}'"
                    : $"Matched by changing value of any of: {string.Join(", ", valueChangeResult.ChangedMacros)}";
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
                result.Status = removeResult.ChangedMacros.Count == 1
                    ? $"Matched by removing macro '{removeResult.ChangedMacros[0]}'"
                    : $"Matched by removing any of: {string.Join(", ", removeResult.ChangedMacros)}";
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
                progress, vertexFactoryName, shaderTypeName, totalShaders, completedSoFar, token, maxGreedyIterations);

            if (greedyResult != null)
            {
                result.Found = true;
                result.SearchPhase = "Phase 3 (Greedy)";
                result.Macros = greedyResult.Value.FinalMacros.Select(m => new ShaderMacroSearchResult.MacroResult
                    { Name = m.Name, Definition = m.Definition }).ToList();

                // Allow duplicate macro names; build dictionaries by overwriting earlier entries
                // so the last occurrence wins instead of throwing an exception.
                var baseDict = new Dictionary<string, string>(StringComparer.Ordinal);
                foreach (var m in baseMacros)
                    baseDict[m.Name] = m.Definition;

                var finalDict = new Dictionary<string, string>(StringComparer.Ordinal);
                foreach (var m in greedyResult.Value.FinalMacros)
                    finalDict[m.Name] = m.Definition;
                var added = finalDict.Where(kv => !baseDict.ContainsKey(kv.Key)).Select(kv => $"+{kv.Key}={kv.Value}");
                var removed = baseDict.Where(kv => !finalDict.ContainsKey(kv.Key)).Select(kv => $"-{kv.Key}");
                var changed = baseDict
                    .Where(kv => finalDict.TryGetValue(kv.Key, out var newDef) && newDef != kv.Value)
                    .Select(kv => $"~{kv.Key}: {kv.Value}\u2192{finalDict[kv.Key]}");
                var changes = string.Join(", ", added.Concat(removed).Concat(changed));
                result.Status = $"Matched via greedy search ({greedyResult.Value.Iterations} iterations)"
                    + (string.IsNullOrEmpty(changes) ? "" : $"\n{changes}");

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
        /// <summary>All macro names that independently produced a match in this one-off probe.</summary>
        public List<string> ChangedMacros = [];
        /// <summary>The final macro set from the first match (representative; all alternatives compile to the same result).</summary>
        public (string Name, string Definition)[] FinalMacros = [];
    }

    /// <summary>
    /// Probes macros one at a time, either adding to or removing from the base set.
    /// Uses multithreading to test candidates in parallel.
    /// All candidates that independently produce a match are collected so the caller
    /// can report every equivalent alternative (not just the first one found).
    /// </summary>
    private OneOffResult? ProbeOneOff(
        List<(string Name, string Definition)> baseMacros,
        List<(string Name, string Definition)> candidates,
        bool isAdd,
        string baseShaderName, string materialHlsl, string vfName,
        string entryPoint, string shaderProfile, string[] referenceLines,
        CancellationToken token)
    {
        var allMatches = new ConcurrentBag<(string MacroName, (string Name, string Definition)[] FinalMacros)>();
        int maxConc = Math.Max(1, Environment.ProcessorCount / 2);
        var semaphore = new SemaphoreSlim(maxConc);

        var tasks = candidates.Select(async candidate =>
        {
            await semaphore.WaitAsync(token).ConfigureAwait(false);
            try
            {
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
                    allMatches.Add((candidate.Name, testMacros));
            }
            finally
            {
                semaphore.Release();
            }
        });

        Task.WhenAll(tasks).GetAwaiter().GetResult();

        if (allMatches.IsEmpty)
            return null;

        var matchList = allMatches.ToList();
        return new OneOffResult
        {
            ChangedMacros = matchList.ConvertAll(m => m.MacroName),
            FinalMacros = matchList[0].FinalMacros
        };
    }

    /// <summary>
    /// For each NUM_* macro already in <paramref name="baseMacros"/>, tries replacing its
    /// current value with each of 1–4 (skipping the current value). Macros are probed in
    /// parallel; all macros whose value change produces an exact match are collected so the
    /// caller can report every equivalent alternative.
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

        var allMatches = new ConcurrentBag<(string MacroName, (string Name, string Definition)[] FinalMacros)>();
        int maxConc = Math.Max(1, Environment.ProcessorCount / 2);
        var semaphore = new SemaphoreSlim(maxConc);

        var tasks = numericalMacros.Select(async macro =>
        {
            await semaphore.WaitAsync(token).ConfigureAwait(false);
            try
            {
                token.ThrowIfCancellationRequested();

                int currentVal = int.TryParse(macro.Definition, out int cv) ? cv : 0;
                (string Name, string Definition)[] baseWithout = baseMacros
                    .Where(m => m.Name != macro.Name).ToArray();

                for (int v = 1; v <= 4; v++)
                {
                    if (v == currentVal) continue;
                    (string Name, string Definition)[] testMacros = [.. baseWithout, (macro.Name, v.ToString())];
                    var r = TryCompileAndMatch(baseShaderName, materialHlsl, vfName,
                        testMacros, entryPoint, shaderProfile, referenceLines);
                    if (r.IsMatch)
                    {
                        allMatches.Add((macro.Name, testMacros));
                        break; // One winning value per macro is enough
                    }
                }
            }
            finally
            {
                semaphore.Release();
            }
        });

        Task.WhenAll(tasks).GetAwaiter().GetResult();

        if (allMatches.IsEmpty)
            return null;

        var matchList = allMatches.ToList();
        return new OneOffResult
        {
            ChangedMacros = matchList.ConvertAll(m => m.MacroName),
            FinalMacros = matchList[0].FinalMacros
        };
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
        CancellationToken token,
        int maxIterations = 50)
    {
        var currentMacros = new List<(string Name, string Definition)>(baseMacros);
        var currentNames = new HashSet<string>(currentMacros.Select(m => m.Name));
        var availableAdditions = new List<(string Name, string Definition)>(candidateAdditions);

        // Compute baseline similarity
        var baselineMatch = TryCompileAndMatch(baseShaderName, materialHlsl, vfName,
            currentMacros.ToArray(), entryPoint, shaderProfile, referenceLines);
        double bestSimilarity = baselineMatch.Similarity;

        int iteration = 0;

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
    /// Loads and caches the <c>external_macros.json</c> file. Searches the application base
    /// directory and directories relative to the includes path. Returns <see langword="null"/> if
    /// the file cannot be found or parsed.
    /// </summary>
    private ExternalMacrosJson? GetExternalMacros()
    {
        if (_externalMacrosLoaded) return _externalMacros;
        lock (_externalMacrosLock)
        {
            if (_externalMacrosLoaded) return _externalMacros;

            string[] searchPaths =
            [
                Path.Combine(AppContext.BaseDirectory, "external_macros.json"),
                Path.Combine(_includesDirectory, "external_macros.json"),
                Path.Combine(Path.GetDirectoryName(_includesDirectory) ?? string.Empty, "external_macros.json"),
            ];

            foreach (var path in searchPaths)
            {
                if (!File.Exists(path)) continue;
                try
                {
                    var json = File.ReadAllText(path);
                    var loaded = JsonSerializer.Deserialize<ExternalMacrosJson>(json);
                    if (loaded != null)
                    {
                        // Re-wrap PerFile with a case-insensitive comparer for reliable lookups
                        _externalMacros = new ExternalMacrosJson
                        {
                            PerFile = new Dictionary<string, List<string>>(
                                loaded.PerFile, StringComparer.OrdinalIgnoreCase)
                        };
                        break;
                    }
                }
                catch { }
            }

            _externalMacrosLoaded = true;
            return _externalMacros;
        }
    }

    /// <summary>
    /// Performs a static scan of USF files starting from <paramref name="baseShaderFileName"/>,
    /// following <c>#include</c> directives recursively. Returns the set of all reachable base
    /// filenames — the same files the D3D compiler would read during a single test compile.
    /// </summary>
    private HashSet<string> ScanUsfIncludes(string baseShaderFileName)
    {
        // Ensure extension.
        baseShaderFileName = Path.ChangeExtension(baseShaderFileName, ".usf");
        var visited = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        var queue = new Queue<string>();
        queue.Enqueue(Path.GetFileName(baseShaderFileName));

        while (queue.Count > 0)
        {
            var filename = queue.Dequeue();
            if (!visited.Add(filename))
                continue;

            var fullPath = Path.Combine(_includesDirectory, filename);
            if (!File.Exists(fullPath))
                continue;

            try
            {
                foreach (var line in File.ReadLines(fullPath))
                {
                    var trimmed = line.TrimStart();
                    if (!trimmed.StartsWith("#include", StringComparison.Ordinal))
                        continue;

                    int start = trimmed.IndexOfAny(['"', '<']);
                    if (start < 0) continue;
                    char terminator = trimmed[start] == '"' ? '"' : '>';
                    int end = trimmed.IndexOf(terminator, start + 1);
                    if (end < 0) continue;

                    var includedFilename = Path.GetFileName(trimmed.Substring(start + 1, end - start - 1));
                    if (!string.IsNullOrEmpty(includedFilename))
                        queue.Enqueue(includedFilename);
                }
            }
            catch { /* Skip unreadable files */ }
        }

        return visited;
    }

    /// <summary>
    /// Builds an expanded set of candidate macros for a shader by scanning its transitive
    /// USF include tree (via a single test compile worth of file reads) and collecting all
    /// macros associated with those files from <c>external_macros.json</c>. This provides a
    /// comprehensive candidate set for the search phases, beyond what the debug package's
    /// <c>possibleMacros</c> list alone contains.
    /// </summary>
    /// <param name="baseShaderFileName">The base .usf filename (e.g. "BasePassPixelShader.usf").</param>
    /// <param name="baseNames">Macro names already active in the current set; excluded from the result.</param>
    /// <returns>Expanded candidate macros with default definition "1".</returns>
    private List<(string Name, string Definition)> BuildExpandedCandidateMacros(
        string baseShaderFileName,
        HashSet<string> baseNames)
    {
        var externalMacros = GetExternalMacros();
        if (externalMacros == null) return [];

        var includedFiles = ScanUsfIncludes(baseShaderFileName);

        var macroNames = new HashSet<string>(StringComparer.Ordinal);
        foreach (var file in includedFiles)
        {
            if (externalMacros.PerFile.TryGetValue(file, out var fileMacros))
            {
                foreach (var macro in fileMacros)
                    macroNames.Add(macro);
            }
        }

        return [.. macroNames
            .Where(m => !baseNames.Contains(m) && !IsExcludedMacro(m))
            .Select(m => (m, "1"))];
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

    private sealed class ExternalMacrosJson
    {
        [JsonPropertyName("per_file")]
        public Dictionary<string, List<string>> PerFile { get; set; } = [];
    }
}
