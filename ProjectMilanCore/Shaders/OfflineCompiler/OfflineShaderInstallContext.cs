using LegendaryExplorerCore.GameFilesystem;
using LegendaryExplorerCore.Misc;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Packages.CloningImportingAndRelinking;
using LegendaryExplorerCore.Shaders;
using LegendaryExplorerCore.Unreal;
using LegendaryExplorerCore.Unreal.BinaryConverters;
using static LegendaryExplorerCore.Shaders.LE3MaterialShaderCompiler;

namespace ProjectMilanCore.Shaders.OfflineCompiler;

/// <summary>
/// The build-side services the offline shader install needs: import resolution with the mod output first, final
/// texture metadata, decooked graphs for stripped parents, the RefShaderCache key check, the game's own copies of
/// materials the mod also holds, and the shader sources.
/// One per install run; not thread-safe.
/// </summary>
public sealed class OfflineShaderInstallContext : IDisposable
{
    public string OutputFolder { get; }
    public string GameRoot { get; }
    public string? DecookedLE3Folder { get; }
    public IReadOnlyList<string> OutputPackages { get; }
    public TieredPackageCache Cache { get; } = new(null, "Offline shader shared donors") { CacheMaxSize = 200 };
    public PackageTextureMetadataProvider TextureMetadata { get; }
    public LE3ShaderSourceSnapshot Sources { get; }
    private readonly Dictionary<string, string> outputByName;
    // Instanced full path -> output files holding it as an export. Level packages are not in the object database,
    // so objects that exist only in another output file (forced exports) are found here.
    private readonly Dictionary<string, List<string>> outputExports;
    private readonly Dictionary<string, IMEPackage?> decooked = new(StringComparer.OrdinalIgnoreCase);
    private readonly TextureDonorLocator donors;
    private readonly string? decookedRoot;
    private readonly ObjectInstanceDB? objectDatabase;
    private readonly string outputRoot, gameRoot;
    private readonly Dictionary<string, VanillaMaterialInfo?> vanillaMaterials = new(StringComparer.Ordinal);
    private ShaderPlanningDiagnostics? planningDiagnostics;
    private TieredPackageCache? planningPackageCache;
    // Scoped to one read-only package scan. Keep importer identity in the key: local import resolution can differ
    // between packages even when the imported path is identical. Never carry these results into installation.
    private readonly Dictionary<ImportEntry, ExportEntry?> resolvedPlanningImports = new();
    // A forced export is in every file that uses it; one of the first few holds a copy at the same memory path.
    private const int MaxVanillaFilesTried = 16;

    /// <summary>A separate provider, for another thread.</summary>
    /// <remarks>Textures of a decooked graph are read from what the game loads (the converted output copy, else the
    /// game's), since the texture pipeline may have converted or upscaled them; the decooked copy is the last resort.</remarks>
    public PackageTextureMetadataProvider CreateTextureMetadataProvider() => new(donors, IsDecooked);

    private bool IsDecooked(ExportEntry export) => decookedRoot != null && export.FileRef.FilePath is { } path &&
        Path.GetFullPath(path).StartsWith(decookedRoot, StringComparison.OrdinalIgnoreCase);

    public string OutputPath(string fileName) => outputByName[fileName];

    /// <summary>The output packages' game, whose RefShaderCache their maps are checked against (LE3 while the build
    /// runs; the build marks them LMP only at the end).</summary>
    public MEGame PackageGame { get; private set; } = MEGame.LE3;

    /// <param name="objectDatabase">LE3 object database, for texture metadata donors outside the mod and for finding
    /// the game's own copy of a material the mod also holds.</param>
    public OfflineShaderInstallContext(string outputFolder, string gameRoot, string? decookedLE3Folder, ObjectInstanceDB? objectDatabase)
    {
        OutputFolder = Path.GetFullPath(outputFolder);
        GameRoot = gameRoot;
        this.objectDatabase = objectDatabase;
        outputRoot = OutputFolder.TrimEnd('\\', '/') + Path.DirectorySeparatorChar;
        this.gameRoot = Path.GetFullPath(gameRoot).TrimEnd('\\', '/') + Path.DirectorySeparatorChar;
        DecookedLE3Folder = decookedLE3Folder;
        decookedRoot = decookedLE3Folder == null ? null : Path.GetFullPath(decookedLE3Folder).TrimEnd('\\', '/') + Path.DirectorySeparatorChar;
        OutputPackages = Directory.GetFiles(OutputFolder, "*.pcc", SearchOption.AllDirectories).Order(StringComparer.OrdinalIgnoreCase).ToList();
        outputByName = OutputPackages.GroupBy(Path.GetFileName, StringComparer.OrdinalIgnoreCase)
            .ToDictionary(g => g.Key!, g => g.First(), StringComparer.OrdinalIgnoreCase);
        outputExports = IndexOutputExports(OutputPackages);
        TextureDonorLocator fromOutput = import => OutputFilesWith(import)
            .Concat(outputByName.TryGetValue(RootName(import) + ".pcc", out var file) ? [file] : []);
        donors = objectDatabase == null ? fromOutput
            : TextureDonorLocators.Concat(fromOutput, TextureDonorLocators.FromObjectDatabase(objectDatabase, gameRoot, [OutputFolder]));
        TextureMetadata = CreateTextureMetadataProvider();
        Sources = LE3ShaderSourceSnapshot.FromDirectory(Path.Combine(gameRoot, "Engine", "Shaders"), 1252);
    }

    private static Dictionary<string, List<string>> IndexOutputExports(IReadOnlyList<string> files)
    {
        var perFile = new (string File, string[] Paths)[files.Count];
        Parallel.For(0, files.Count, new ParallelOptions { MaxDegreeOfParallelism = 8 }, i =>
        {
            using var package = MEPackageHandler.UnsafePartialLoad(files[i], _ => false);
            perFile[i] = (files[i], package.Exports.Where(e => e.ClassName != "Package").Select(e => e.InstancedFullPath).ToArray());
        });
        var index = new Dictionary<string, List<string>>(StringComparer.OrdinalIgnoreCase);
        foreach (var (file, paths) in perFile)
        foreach (var path in paths)
        {
            if (!index.TryGetValue(path, out var list)) index[path] = list = [];
            if (list.Count == 0 || list[^1] != file) list.Add(file);
        }
        return index;
    }

    /// <summary>Output files holding the import's object as an export, in path order.</summary>
    public IReadOnlyList<string> OutputFilesWith(IEntry import) => OutputFilesWith(import.InstancedFullPath);

    /// <summary>Output files holding an export at this instanced full path, in path order.</summary>
    public IReadOnlyList<string> OutputFilesWith(string instancedFullPath) =>
        outputExports.TryGetValue(instancedFullPath, out var files) ? files : [];

    internal static string RootName(IEntry entry)
    {
        while (entry.Parent != null) entry = entry.Parent;
        return entry.ObjectName.Instanced;
    }

    /// <summary>Opens a package by file name: the mod output first, then the game.</summary>
    public IMEPackage? OpenByFileName(string fileName, PackageCache cache)
    {
        if (outputByName.TryGetValue(fileName, out var output)) return OpenCached(output, cache);
        var loaded = MELoadedFiles.GetFilesLoadedInGame(MEGame.LE3, gameRootOverride: GameRoot);
        return loaded.TryGetValue(fileName, out var game) ? OpenCached(game, cache) : null;
    }

    private IMEPackage? OpenCached(string file, PackageCache cache)
    {
        if (cache.GetCachedPackage(file, openIfNotInCache: false) is { } cached)
        {
            planningDiagnostics?.Count("resolver-package-cache-hits");
            return cached;
        }
        // The package being scanned lives in the child; donors live in the shared parent across package scans.
        var owner = ReferenceEquals(cache, planningPackageCache) ? Cache : cache;
        return owner.GetCachedPackage(file, openPackageMethod: path =>
        {
            using var timing = planningDiagnostics?.Measure("resolver-package-open", path);
            return MEPackageHandler.OpenMEPackage(path, forceLoadFromDisk: true, diskIOSyncLock: owner.DiskIOSyncLock);
        });
    }

    public ExportEntry? ResolveImport(ImportEntry import)
    {
        if (planningPackageCache == null) return ResolveImport(import, Cache);
        if (resolvedPlanningImports.TryGetValue(import, out var cached))
        {
            planningDiagnostics?.Count("import-result-cache-hits");
            return cached;
        }
        return resolvedPlanningImports[import] = ResolveImport(import, planningPackageCache);
    }

    /// <summary>
    /// An output copy of the object first (it is what the mod loads, and copies are checked to be identical), then the
    /// importer's own resolution through the output and game files.
    /// </summary>
    public ExportEntry? ResolveImport(ImportEntry import, PackageCache cache)
    {
        using var timing = planningDiagnostics?.Measure("import-resolution", import.InstancedFullPath);
        var files = OutputFilesWith(import);
        // Prefer a file the cache already holds, so resolving does not open another level package.
        foreach (var file in files.OrderBy(f => cache.GetCachedPackage(f, openIfNotInCache: false) != null ? 0 : 1))
        {
            try
            {
                var export = OpenCached(file, cache)?.FindExport(import.InstancedFullPath, import.ClassName);
                if (export != null) return export;
            }
            catch
            {
                // Try the next copy.
            }
        }
        try { return EntryImporter.ResolveImport(import, cache, fileResolver: OpenByFileName); }
        catch { return null; }
    }

    /// <summary>The decooked copy of a stripped LE3 material, which still has its expression graph.</summary>
    public ExportEntry? GraphSource(ExportEntry material) => GraphSource(material, decooked);

    /// <summary>
    /// Output materials (instanced full paths) compiled from their own expression graphs, before any decooked copy: those
    /// authored or rebuilt uncooked, like the LE2 materials a heavy weapon package rebuilds. Every other output
    /// material is treated as cooked. A cooked material keeps its parameter expressions and sometimes an input wired to one
    /// (Strings_Glow's EmissiveColor to its Color parameter), so it can look complete while its graph is stripped.
    /// </summary>
    public IReadOnlySet<string>? OutputMaterialsWithOwnGraphs { get; init; }

    /// <summary>
    /// Output material path to the path of the decooked material whose graph it compiles from: for a cooked copy of a
    /// game material under a new name (a standalone port's usage copy, <c>X_LE2</c> of <c>X</c>), whose own expressions
    /// are stripped and whose path the decooked corpus doesn't have.
    /// </summary>
    public IReadOnlyDictionary<string, string>? GraphAliases { get; init; }

    /// <param name="opened">Decooked packages opened so far by the calling thread.</param>
    public ExportEntry? GraphSource(ExportEntry material, Dictionary<string, IMEPackage?> opened)
    {
        using var timing = planningDiagnostics?.Measure("graph-source", material.InstancedFullPath);
        string? alias = GraphAliases?.GetValueOrDefault(material.InstancedFullPath);
        if (alias == null && OutputMaterialsWithOwnGraphs?.Contains(material.InstancedFullPath) == true && IsOutputFile(material.FileRef.FilePath))
        {
            return material;
        }
        if (DecookedLE3Folder != null)
        {
            string graphPath = alias ?? material.InstancedFullPath;
            string root = alias != null ? graphPath.Split('.')[0] : RootName(material);
            if (!opened.TryGetValue(root, out var package))
            {
                string path = Path.Combine(DecookedLE3Folder, root + ".pcc");
                using var opening = planningDiagnostics?.Measure("decooked-open", path);
                opened[root] = package = File.Exists(path) ? MEPackageHandler.OpenMEPackage(path) : null;
                if (package != null) MaterialGraphOverrides.AddTuningParameters(package);
            }
            var decooked = package == null ? null : PathLookup.FindExport(package, graphPath, PathLookup.IsMaterialObject);
            if (decooked?.GetProperty<ArrayProperty<ObjectProperty>>("Expressions") is { Count: > 0 }) return decooked;
        }
        if (alias != null) return null;
        // No decooked copy: an output material LE3 never had may still hold its authored graph, like the LE2 materials a
        // standalone port (SFXHeavyWeapon_Blackstorm) rebuilt from T3D
        return IsOutputFile(material.FileRef.FilePath) && MaterialChain.HoldsCompleteGraph(material) ? material : null;
    }

    private bool IsOutputFile(string? filePath) => filePath != null && outputByName.TryGetValue(Path.GetFileName(filePath), out var outputPath)
        && string.Equals(Path.GetFullPath(filePath), outputPath, StringComparison.OrdinalIgnoreCase);

    /// <summary>A file of the game itself: under the game root, and neither the mod's output nor another mod's DLC.</summary>
    private bool IsGameFile(string path)
    {
        path = Path.GetFullPath(path);
        return path.StartsWith(gameRoot, StringComparison.OrdinalIgnoreCase) && !path.StartsWith(outputRoot, StringComparison.OrdinalIgnoreCase) &&
               !path.Contains(Path.DirectorySeparatorChar + "DLC_MOD_", StringComparison.OrdinalIgnoreCase);
    }

    /// <summary>
    /// The game's own copy of a material: the object the game holds at the same memory path, so the one a copy in the
    /// mod's packages shares its identity with at runtime. Null when the game has no such object.
    /// </summary>
    public VanillaMaterialInfo? VanillaMaterial(ExportEntry material)
    {
        string identity = material.MemoryFullPath;
        if (vanillaMaterials.TryGetValue(identity, out var info))
        {
            planningDiagnostics?.Count("vanilla-cache-hits");
            return info;
        }
        using var timing = planningDiagnostics?.Measure("vanilla-lookup", identity);
        vanillaMaterials[identity] = info = FindVanillaMaterial(material, identity);
        planningDiagnostics?.Count(info == null ? "vanilla-not-found" : "vanilla-found");
        return info;
    }

    private VanillaMaterialInfo? FindVanillaMaterial(ExportEntry material, string identity)
    {
        static VanillaMaterialInfo Describe(ExportEntry copy) => new(ObjectBinary.From<Material>(copy).SM3MaterialResource.ID,
            copy.GetProperties().OfType<BoolProperty>().Where(b => b.Value && b.Name.Name.StartsWith("bUsed", StringComparison.Ordinal))
                .Select(b => b.Name.Name).ToHashSet(StringComparer.Ordinal));

        if (material.FileRef.FilePath is { } own && IsGameFile(own)) return Describe(material);
        List<string>? files;
        using (planningDiagnostics?.Measure("object-db-query", material.InstancedFullPath))
            files = objectDatabase?.GetFilesContainingObject(material.InstancedFullPath);
        if (files == null) return null;

        string name = material.ObjectName.Instanced, className = material.ClassName;
        string fileName = material.FileRef.FileNameNoExtension.StripUnrealLocalization();
        int tried = 0;
        // Database paths are relative to the game root; packages registered at runtime (the mod's) may be absolute.
        foreach (var file in files.Select(f => Path.GetFullPath(Path.Combine(GameRoot, f))).Distinct(StringComparer.OrdinalIgnoreCase))
        {
            if (!IsGameFile(file) || !File.Exists(file)) continue;
            // A copy that is not a forced export has its file's name in its memory path: only a same-named file shares it.
            if (!material.IsForcedExport && !string.Equals(Path.GetFileNameWithoutExtension(file).StripUnrealLocalization(), fileName, StringComparison.OrdinalIgnoreCase))
                continue;
            if (++tried > MaxVanillaFilesTried) break;
            try
            {
                planningDiagnostics?.CountDistinct("vanilla-donor-files", file);
                using var reading = planningDiagnostics?.Measure("vanilla-donor-read", file);
                using var package = MEPackageHandler.UnsafePartialLoad(file, e => e.ClassName == className && e.ObjectName.Instanced == name);
                var copy = package.Exports.FirstOrDefault(e => e.ClassName == className && e.ObjectName.Instanced == name &&
                                                               string.Equals(e.MemoryFullPath, identity, StringComparison.OrdinalIgnoreCase));
                if (copy != null) return Describe(copy);
            }
            catch
            {
                // Try the next file.
            }
        }
        return null;
    }

    /// <summary>
    /// Compile every output material and permutation into its package's own cache, and keep those maps through
    /// compaction, even when the game's RefShaderCache has them. For standalone packages that must not depend on a
    /// RefShaderCache (a slashed one, or another game's, such as LMP running an LE3-built package).
    /// </summary>
    public bool IgnoreRefShaderCache { get; init; }

    public ISet<StaticParameterSet> KeysInRefShaderCache(IReadOnlyCollection<StaticParameterSet> keys)
    {
        if (IgnoreRefShaderCache) return new HashSet<StaticParameterSet>();
        var missing = keys.ToHashSet();
        RefShaderCacheReader.RemoveStaticParameterSetsThatAreInTheGlobalCache(missing, PackageGame, GameRoot);
        return keys.Where(k => !missing.Contains(k)).ToHashSet();
    }

    /// <summary>Translates the graph as-is and with the swapped samplers; true when the HLSL differs and so do the
    /// compiled shaders.</summary>
    public bool ConfirmVariant(ExportEntry graph, IReadOnlyList<VariantSamplerSwap> swaps)
    {
        using var timing = planningDiagnostics?.Measure("variant-confirmation", graph.InstancedFullPath);
        // Default texture -> the distinct metadata its samplers are swapped to. Samplers sharing a default can be swapped to
        // different textures (WPN_MOD_MASTER_MAT's Diff and Spec stacks), and metadata is keyed by texture, so each
        // alternative is tried in its own translation. A sampler's code depends only on its texture's metadata, so when
        // every alternative leaves the HLSL unchanged, any mix of them does too.
        var alternatives = new Dictionary<int, List<TextureCompilationMetadata>>();
        foreach (var swap in swaps)
        {
            var expression = graph.FileRef.FindExport(swap.ExpressionPath);
            int texture = expression?.GetProperty<ObjectProperty>("Texture")?.Value ?? 0;
            if (texture == 0) return true;
            if (!alternatives.TryGetValue(texture, out var list)) alternatives[texture] = list = [];
            if (!list.Any(m => SameMetadata(m, swap.Metadata))) list.Add(swap.Metadata);
        }
        Translation? Translate(Func<IEntry, TextureCompilationMetadata?> metadata)
        {
            try
            {
                var compiler = new LE3MaterialShaderCompiler(new ResolvedMaterialCompilationInput(graph), getTextureMetadata: e => metadata(e)!);
                var result = compiler.TranslateMaterialResourceHlsl(Sources);
                return result.Success ? new Translation(compiler, result) : null;
            }
            catch { return null; }
        }
        var original = Translate(TextureMetadata.GetMetadata);
        if (original == null) return true;
        int rounds = alternatives.Values.Max(l => l.Count);
        for (int round = 0; round < rounds; round++)
        {
            var overrides = alternatives.ToDictionary(a => a.Key, a => a.Value[Math.Min(round, a.Value.Count - 1)]);
            var swapped = Translate(e => overrides.TryGetValue(e.UIndex, out var m) ? m : TextureMetadata.GetMetadata(e));
            if (swapped == null) return true;
            if (swapped.Result.MaterialHlsl != original.Result.MaterialHlsl && !SameBytecode(graph, original, swapped)) return true;
        }
        return false;
    }

    private sealed record Translation(LE3MaterialShaderCompiler Compiler, TranslationResult Result);

    // HLSL can differ in spelling only: a BC7 normal goes through Common.usf's BiasNormalizeNormalMap_BC7, the same *2-1
    // bias a TC_NormalmapHQ default gets inline, and MultiPlayer_MASTER_MAT compiles byte-identical either way. So compile
    // every planned job of both; any failure counts as a difference.
    private bool SameBytecode(ExportEntry graph, Translation a, Translation b)
    {
        try
        {
            var resource = ObjectBinary.From<Material>(graph).SM3MaterialResource;
            var planA = a.Compiler.BuildKnownSubsetCompilePlan(a.Result, resource);
            var planB = b.Compiler.BuildKnownSubsetCompilePlan(b.Result, resource);
            if (!planA.Success || !planB.Success || planA.Jobs.Count != planB.Jobs.Count) return false;
            for (int i = 0; i < planA.Jobs.Count; i++)
            {
                if (planA.Jobs[i].Target != planB.Jobs[i].Target) return false;
                var compiledA = a.Compiler.CompileShader(planA.Jobs[i], Sources);
                var compiledB = b.Compiler.CompileShader(planB.Jobs[i], Sources);
                if (!compiledA.Success || !compiledB.Success || !compiledA.Bytecode.AsSpan().SequenceEqual(compiledB.Bytecode)) return false;
            }
            return true;
        }
        catch { return false; }
    }

    private static bool SameMetadata(TextureCompilationMetadata a, TextureCompilationMetadata b) =>
        a.Dimension == b.Dimension && a.CompressionSettings == b.CompressionSettings && a.UnpackMin == b.UnpackMin &&
        a.UnpackMax == b.UnpackMax && a.FlipBookScale == b.FlipBookScale;

    public ShaderInstallPlannerOptions PlannerOptions() => new()
    {
        ModPackagePaths = OutputPackages,
        ResolveImport = ResolveImport,
        TextureMetadata = TextureMetadata,
        GraphSource = GraphSource,
        KeysInRefShaderCache = KeysInRefShaderCache,
        ConfirmVariant = ConfirmVariant,
        VanillaMaterial = VanillaMaterial,
        ForceRecompile = MaterialGraphOverrides.NeedsRecompile,
        Diagnostics = planningDiagnostics
    };

    /// <summary>Plans over every output package, opening each read-only and releasing it after.</summary>
    /// <param name="include">Optional file filter, for diagnosing a subset; the plan is then partial.</param>
    /// <param name="diagnostics">Optional phase, slow-operation and aggregate timing/counter log.</param>
    public ShaderInstallPlan Plan(Action<string>? progress = null, Func<string, bool>? include = null, Action<string>? diagnostics = null)
    {
        planningDiagnostics = diagnostics == null ? null : new ShaderPlanningDiagnostics(diagnostics);
        try
        {
            var planner = new ShaderInstallPlanner(PlannerOptions());
            bool first = true;
            foreach (var file in OutputPackages.Where(f => include?.Invoke(f) ?? true))
            {
                progress?.Invoke(file);
                planningDiagnostics?.BeginPackage(file);
                IMEPackage package;
                using (planningDiagnostics?.Measure("package-open", file))
                    package = MEPackageHandler.OpenMEPackage(file, forceLoadFromDisk: true);
                using (package)
                using (var localCache = Cache.ChainNewCache(debugName: "Offline shader current package"))
                {
                    // Use this exact package for local donors, without reopening it through import resolution.
                    Cache.ReleasePackage(file);
                    localCache.InsertIntoCache(package);
                    planningPackageCache = localCache;
                    try
                    {
                        if (first) (PackageGame, first) = (package.Game, false);
                        planner.AddPackage(package);
                    }
                    finally
                    {
                        resolvedPlanningImports.Clear();
                        planningPackageCache = null;
                        localCache.ReleasePackage(file); // The outer using owns the current package.
                    }
                }
                planningDiagnostics?.CompletePackage();
            }
            ShaderInstallPlan plan;
            planningDiagnostics?.BeginPackage("global plan");
            using (planningDiagnostics?.Phase("global plan finalization")) plan = planner.Build();
            planningDiagnostics?.CompletePlan();
            return plan;
        }
        finally
        {
            resolvedPlanningImports.Clear();
            planningPackageCache = null;
            planningDiagnostics = null;
        }
    }

    /// <summary>Closes everything that holds output files open or caches their old contents, before they are rewritten.</summary>
    public void ReleaseOutputFileHandles()
    {
        TextureMetadata.CloseReaders();
        resolvedPlanningImports.Clear();
        Cache.ReleasePackages();
    }

    public void Dispose()
    {
        foreach (var p in decooked.Values) p?.Dispose();
        TextureMetadata.Dispose();
        Cache.Dispose();
    }
}
