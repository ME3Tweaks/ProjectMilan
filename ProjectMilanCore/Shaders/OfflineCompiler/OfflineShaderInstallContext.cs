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
/// texture metadata, decooked graphs for stripped parents, the RefShaderCache key check and the shader sources.
/// One per install run; not thread-safe.
/// </summary>
public sealed class OfflineShaderInstallContext : IDisposable
{
    public string OutputFolder { get; }
    public string GameRoot { get; }
    public string? DecookedLE3Folder { get; }
    public IReadOnlyList<string> OutputPackages { get; }
    public PackageCache Cache { get; } = new() { CacheMaxSize = 200 };
    public PackageTextureMetadataProvider TextureMetadata { get; }
    public LE3ShaderSourceSnapshot Sources { get; }
    private readonly Dictionary<string, string> outputByName;
    // Instanced full path -> output files holding it as an export. Level packages are not in the object database,
    // so objects that exist only in another output file (forced exports) are found here.
    private readonly Dictionary<string, List<string>> outputExports;
    private readonly Dictionary<string, IMEPackage?> decooked = new(StringComparer.OrdinalIgnoreCase);
    private readonly TextureDonorLocator donors;
    private readonly string? decookedRoot;

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

    /// <param name="objectDatabase">LE3 object database, for texture metadata donors outside the mod.</param>
    public OfflineShaderInstallContext(string outputFolder, string gameRoot, string? decookedLE3Folder, ObjectInstanceDB? objectDatabase)
    {
        OutputFolder = Path.GetFullPath(outputFolder);
        GameRoot = gameRoot;
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
        if (outputByName.TryGetValue(fileName, out var output)) return cache.GetCachedPackage(output);
        var loaded = MELoadedFiles.GetFilesLoadedInGame(MEGame.LE3, gameRootOverride: GameRoot);
        return loaded.TryGetValue(fileName, out var game) ? cache.GetCachedPackage(game) : null;
    }

    public ExportEntry? ResolveImport(ImportEntry import) => ResolveImport(import, Cache);

    /// <summary>
    /// An output copy of the object first (it is what the mod loads, and copies are checked to be identical), then the
    /// importer's own resolution through the output and game files.
    /// </summary>
    public ExportEntry? ResolveImport(ImportEntry import, PackageCache cache)
    {
        var files = OutputFilesWith(import);
        // Prefer a file the cache already holds, so resolving does not open another level package.
        foreach (var file in files.OrderBy(f => cache.Cache.ContainsKey(f) ? 0 : 1))
        {
            try
            {
                var export = cache.GetCachedPackage(file)?.FindExport(import.InstancedFullPath, import.ClassName);
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

    /// <param name="opened">Decooked packages opened so far by the calling thread.</param>
    public ExportEntry? GraphSource(ExportEntry material, Dictionary<string, IMEPackage?> opened)
    {
        if (DecookedLE3Folder == null) return null;
        string root = RootName(material);
        if (!opened.TryGetValue(root, out var package))
        {
            string path = Path.Combine(DecookedLE3Folder, root + ".pcc");
            opened[root] = package = File.Exists(path) ? MEPackageHandler.OpenMEPackage(path) : null;
        }
        var decooked = package == null ? null : PathLookup.FindExport(package, material.InstancedFullPath, PathLookup.IsMaterialObject);
        return decooked?.GetProperty<ArrayProperty<ObjectProperty>>("Expressions") is { Count: > 0 } ? decooked : null;
    }

    public ISet<StaticParameterSet> KeysInRefShaderCache(IReadOnlyCollection<StaticParameterSet> keys)
    {
        var missing = keys.ToHashSet();
        RefShaderCacheReader.RemoveStaticParameterSetsThatAreInTheGlobalCache(missing, PackageGame, GameRoot);
        return keys.Where(k => !missing.Contains(k)).ToHashSet();
    }

    /// <summary>Translates the graph as-is and with the swapped samplers; true when the HLSL differs.</summary>
    public bool ConfirmVariant(ExportEntry graph, IReadOnlyList<VariantSamplerSwap> swaps)
    {
        var overrides = new Dictionary<int, TextureCompilationMetadata>();
        foreach (var swap in swaps)
        {
            var expression = graph.FileRef.FindExport(swap.ExpressionPath);
            int texture = expression?.GetProperty<ObjectProperty>("Texture")?.Value ?? 0;
            if (texture == 0) return true;
            if (overrides.TryGetValue(texture, out var other) && other != swap.Metadata) return true; // shared default: cannot tell, keep it
            overrides[texture] = swap.Metadata;
        }
        string? Translate(Func<IEntry, TextureCompilationMetadata?> metadata)
        {
            try
            {
                var result = new LE3MaterialShaderCompiler(new ResolvedMaterialCompilationInput(graph), getTextureMetadata: e => metadata(e)!)
                    .TranslateMaterialResourceHlsl(Sources);
                return result.Success ? result.MaterialHlsl : null;
            }
            catch { return null; }
        }
        string? original = Translate(TextureMetadata.GetMetadata);
        string? swapped = Translate(e => overrides.TryGetValue(e.UIndex, out var m) ? m : TextureMetadata.GetMetadata(e));
        return original == null || swapped == null || original != swapped;
    }

    public ShaderInstallPlannerOptions PlannerOptions() => new()
    {
        ModPackagePaths = OutputPackages,
        ResolveImport = ResolveImport,
        TextureMetadata = TextureMetadata,
        GraphSource = GraphSource,
        KeysInRefShaderCache = KeysInRefShaderCache,
        ConfirmVariant = ConfirmVariant
    };

    /// <summary>Plans over every output package, opening each read-only and releasing it after.</summary>
    /// <param name="include">Optional file filter, for diagnosing a subset; the plan is then partial.</param>
    public ShaderInstallPlan Plan(Action<string>? progress = null, Func<string, bool>? include = null)
    {
        var planner = new ShaderInstallPlanner(PlannerOptions());
        bool first = true;
        foreach (var file in OutputPackages.Where(f => include?.Invoke(f) ?? true))
        {
            progress?.Invoke(file);
            using var package = MEPackageHandler.OpenMEPackage(file, forceLoadFromDisk: true);
            if (first) (PackageGame, first) = (package.Game, false);
            planner.AddPackage(package);
        }
        return planner.Build();
    }

    /// <summary>Closes everything that holds output files open or caches their old contents, before they are rewritten.</summary>
    public void ReleaseOutputFileHandles()
    {
        TextureMetadata.CloseReaders();
        Cache.ReleasePackages();
    }

    public void Dispose()
    {
        foreach (var p in decooked.Values) p?.Dispose();
        TextureMetadata.Dispose();
        Cache.Dispose();
    }
}
