using System.Collections.Concurrent;
using System.Security.Cryptography;
using System.Text;
using LegendaryExplorerCore.Misc;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Packages.CloningImportingAndRelinking;
using LegendaryExplorerCore.Shaders;
using LegendaryExplorerCore.Textures;
using LegendaryExplorerCore.Unreal;
using LegendaryExplorerCore.Unreal.BinaryConverters;
using LegendaryExplorerCore.Unreal.Classes;
using LegendaryExplorerCore.Unreal.ObjectInfo;
using static LegendaryExplorerCore.Shaders.LE3MaterialShaderCompiler;

namespace ProjectMilanCore.Shaders.OfflineCompiler;

/// <summary>Thrown when the install cannot produce correct shaders; the build must stop.</summary>
public sealed class ShaderInstallException(string message) : Exception(message);

/// <summary>
/// The writing half of the shader install. Compiles each unique material, permutation, variant and chain clone
/// of a <see cref="ShaderInstallPlan"/> once, then applies the plan to every output package: usage flags, static
/// normal fixes, parent variants with placeholder textures, retargets, rebuilt material resources and the merged
/// shader cache. Any compile failure, incomplete shader set or material left without shaders throws
/// <see cref="ShaderInstallException"/>, listing every problem found.
/// </summary>
public sealed class OfflineShaderInstaller(OfflineShaderInstallContext context, Action<string> log)
{
    public const string VariantRoot = "MilanMaterialVariants";
    public const string PlaceholderRoot = "MilanShaderPlaceholders";
    private const int PlaceholderSize = 32;

    /// <summary>One shader map to compile, or a resource to rebuild from a translation.</summary>
    private sealed record Unit(string Id, string PackageName, string ExportIdentity, bool IsInstance, StaticParameterSet? Key,
        Guid ResourceId, bool Compile, ParentVariantPlan? Variant, string? SourcePackagePath);

    /// <summary>What a unit produced: a resource with texture paths, and the shaders.</summary>
    private sealed record Compiled(MaterialResource Template, IReadOnlyList<string> TexturePaths, string GraphPackagePath,
        IReadOnlyList<string> ParameterOrder, ShaderCache? Shaders);

    private ShaderInstallPlan plan = null!;
    private readonly ConcurrentDictionary<string, Compiled> compiled = new(StringComparer.Ordinal);
    private readonly ConcurrentBag<string> failures = [];
    private readonly Dictionary<string, byte[]> placeholderMips = new(StringComparer.Ordinal);

    public void Install(ShaderInstallPlan installPlan, int threads)
    {
        plan = installPlan;
        if (!plan.CanInstall)
            throw new ShaderInstallException($"The shader install plan has {plan.Errors.Count} errors:\n" + string.Join("\n", plan.Errors.Take(200)));

        var units = BuildUnits();
        log($"Shader install: {units.Count} units ({units.Count(u => u.Compile)} to compile), {plan.Variants.Count} variants, {plan.ChainClones.Count} chain clones");
        CompileAll(units, threads);
        if (!failures.IsEmpty) Fail("compile");

        // Planning left lazy texture readers open on output files; saving those files needs them closed.
        context.ReleaseOutputFileHandles();
        foreach (var file in context.OutputPackages) ApplyToPackage(file);
        if (!failures.IsEmpty) Fail("install");
    }

    private void Fail(string phase) => throw new ShaderInstallException(
        $"Shader {phase} failed for {failures.Count} items:\n" + string.Join("\n", failures.Order(StringComparer.Ordinal).Take(300)));

    private List<Unit> BuildUnits()
    {
        var variantsById = plan.Variants.ToDictionary(v => v.ResourceId);
        var units = new List<Unit>();
        // Only materials whose shaders change; an unchanged one keeps its resource and may have no graph to translate.
        foreach (var m in plan.Materials.Where(m => m.ModOwned && (m.Compile || m.Rewrite)))
            units.Add(new Unit("M:" + m.Identity, m.Packages[0], m.Identity, false, null, m.LiveResourceId, m.Compile, null, null));
        foreach (var i in plan.Instances.Where(i => i.Key != null && i.Rewrite))
            units.Add(new Unit("I:" + i.Identity, i.Packages[0], i.Identity, true, i.Key, InstanceResourceId(i.Identity, i.Key!),
                i.Compile, variantsById.GetValueOrDefault(i.Key!.BaseMaterialId), null));
        foreach (var v in plan.Variants)
            units.Add(new Unit("V:" + v.Identity, v.Packages[0], v.SourceIdentity, false, null, v.ResourceId, true, v, v.SourcePackagePath));
        foreach (var c in plan.ChainClones.Where(c => c.Key != null))
            units.Add(new Unit("C:" + c.Identity, c.Packages[0], c.SourceIdentity, true, c.Key, InstanceResourceId(c.Identity, c.Key!), true,
                variantsById[c.Key!.BaseMaterialId], c.SourcePackagePath));
        return units.OrderBy(u => u.PackageName, StringComparer.OrdinalIgnoreCase).ThenBy(u => u.Id, StringComparer.Ordinal).ToList();
    }

    private static Guid InstanceResourceId(string identity, StaticParameterSet key) => new(SHA256.HashData(Encoding.UTF8.GetBytes(
        "instance\n" + identity.ToLowerInvariant() + "\n" + ShaderInstallPlan.DescribeKey(key))).AsSpan(0, 16));

    // ---------------------------------------------------------------- compile

    private sealed class Worker : IDisposable
    {
        public readonly PackageCache Cache = new() { CacheMaxSize = 30 };
        public readonly Dictionary<string, IMEPackage?> Decooked = new(StringComparer.OrdinalIgnoreCase);
        public required PackageTextureMetadataProvider Metadata;
        public void Dispose()
        {
            Metadata.Dispose();
            foreach (var p in Decooked.Values) p?.Dispose();
            Cache.Dispose();
        }
    }

    private void CompileAll(List<Unit> units, int threads)
    {
        int done = 0;
        Parallel.ForEach(Partitioner.Create(units, EnumerablePartitionerOptions.NoBuffering),
            new ParallelOptions { MaxDegreeOfParallelism = Math.Max(1, threads) },
            () => new Worker { Metadata = context.CreateTextureMetadataProvider() },
            (unit, _, worker) =>
            {
                try
                {
                    var result = CompileUnit(unit, worker);
                    if (result != null) compiled[unit.Id] = result;
                }
                catch (Exception e)
                {
                    failures.Add($"{unit.Id}: {e.GetType().Name}: {e.Message}");
                }
                int n = Interlocked.Increment(ref done);
                if (n % 100 == 0 || n == units.Count) log($"Shader install: {n}/{units.Count} units processed, {failures.Count} failures");
                return worker;
            },
            worker => worker.Dispose());
    }

    private static ExportEntry? FindByIdentity(IMEPackage package, string identity)
    {
        var export = PathLookup.FindExport(package, identity, PathLookup.IsMaterialObject);
        if (export != null && export.MemoryFullPath == identity) return export;
        string prefix = package.FileNameNoExtension.StripUnrealLocalization() + ".";
        if (identity.StartsWith(prefix, StringComparison.OrdinalIgnoreCase))
        {
            export = PathLookup.FindExport(package, identity[prefix.Length..], PathLookup.IsMaterialObject);
            if (export != null && export.MemoryFullPath == identity) return export;
        }
        return null;
    }

    private ExportEntry WithGraph(ExportEntry material, Worker worker)
    {
        // Cooked copies are always stripped: only the decooked graph, or a material shipped or authored empty, is compiled.
        if (MaterialChain.ShipsEmpty(material)) return material;
        if (context.GraphSource(material, worker.Decooked) is { } decooked) return decooked;
        if (MaterialChain.IsEmptyByDesign(material)) return material;
        throw new ShaderInstallException($"{material.InstancedFullPath} has no decooked graph (cooked copies are stripped).");
    }

    private Compiled? CompileUnit(Unit unit, Worker worker)
    {
        var package = worker.Cache.GetCachedPackage(unit.SourcePackagePath is { Length: > 0 } source ? source : context.OutputPath(unit.PackageName));
        var export = FindByIdentity(package, unit.ExportIdentity)
                     ?? throw new ShaderInstallException($"{unit.ExportIdentity} is not in {Path.GetFileName(package.FilePath)}");

        // The graph: the material itself, or the base Material at the end of an instance's chain.
        var baseMaterial = export;
        for (int depth = 0; depth < 64 && MaterialChain.IsLink(baseMaterial); depth++)
        {
            int parent = MaterialChain.NextReference(baseMaterial);
            baseMaterial = baseMaterial.FileRef.GetEntry(parent) switch
            {
                ExportEntry e => e,
                ImportEntry i => context.ResolveImport(i, worker.Cache),
                _ => null
            } ?? throw new ShaderInstallException($"{unit.ExportIdentity}: the parent chain does not resolve");
        }
        if (!baseMaterial.IsA("Material")) throw new ShaderInstallException($"{unit.ExportIdentity}: the chain does not end at a Material");
        var graph = WithGraph(baseMaterial, worker);

        // Usage flags the plan adds to the base apply to its compile too (and to its variants').
        var basePlan = plan.Materials.FirstOrDefault(m => m.Identity == baseMaterial.MemoryFullPath);
        foreach (var flag in basePlan?.FlagsToSet ?? []) graph.WriteProperty(new BoolProperty(true, flag));

        // A variant compiles exactly what is installed: the swapped samplers point at placeholder textures of the override's
        // kind. It works on a private copy of the graph's package, so a default shared with an unswapped sampler stays a
        // separate texture and the cached packages other units read are untouched.
        var overrides = new Dictionary<int, TextureCompilationMetadata>();
        using var variantPackage = unit.Variant == null ? null : MEPackageHandler.OpenMEPackage(graph.FileRef.FilePath, forceLoadFromDisk: true);
        if (unit.Variant != null)
        {
            graph = PathLookup.FindExport(variantPackage!, graph.InstancedFullPath, PathLookup.IsMaterialObject)
                    ?? throw new ShaderInstallException($"{unit.Id}: {graph.InstancedFullPath} is not in {Path.GetFileName(graph.FileRef.FilePath)}");
            foreach (var flag in basePlan?.FlagsToSet ?? []) graph.WriteProperty(new BoolProperty(true, flag));
            foreach (var swap in unit.Variant.Swaps)
            {
                var expression = variantPackage.Exports.FirstOrDefault(e => e.Parent == graph && e.ObjectName.Instanced == LastSegment(swap.ExpressionPath))
                                 ?? throw new ShaderInstallException($"{unit.Id}: {swap.ExpressionPath} is not in the graph");
                if ((expression.GetProperty<ObjectProperty>("Texture")?.Value ?? 0) == 0)
                    throw new ShaderInstallException($"{unit.Id}: {swap.ExpressionPath} has no default texture");
                var placeholder = PlaceholderImport(variantPackage, swap.Metadata);
                overrides[placeholder.UIndex] = swap.Metadata;
                expression.WriteProperty(new ObjectProperty(placeholder.UIndex, "Texture"));
            }
        }

        string friendlyName = unit.Variant?.ObjectName ?? graph.ObjectName.Instanced;
        var resource = ObjectBinary.From<Material>(graph).SM3MaterialResource ?? MaterialResource.Create();
        var compilation = new ResolvedMaterialShaderCompilation(new ResolvedMaterialCompilationInput(graph, unit.Key),
            resource, unit.Key?.BaseMaterialId ?? unit.ResourceId, friendlyName);
        var session = new LE3MaterialShaderCompilerBackend().CreateSession(new MaterialShaderCompileSessionContext(compilation,
            context.Sources, e => overrides.TryGetValue(e.UIndex, out var m) ? m : worker.Metadata.GetMetadata(e), false, null, null));

        var translated = session.Translate();
        if (!translated.Success) throw new ShaderInstallException("translation failed: " + string.Join("; ", translated.Errors));
        ShaderCache? shaders = null;
        if (unit.Compile)
        {
            var planned = session.Plan();
            if (!planned.Success) throw new ShaderInstallException("planning failed: " + string.Join("; ", planned.Errors));
            for (int i = 0; i < planned.Jobs.Count; i++)
            {
                var job = session.Compile(i);
                if (!job.Success) throw new ShaderInstallException($"{job.Target} failed to compile: {job.Diagnostics}");
            }
            var assembled = session.Assemble();
            if (!assembled.Success || assembled.Cache == null) throw new ShaderInstallException("assembly failed: " + string.Join("; ", assembled.Errors));
            if (!assembled.IsCompleteShaderSet) throw new ShaderInstallException("the compiled shader set is incomplete");
            shaders = assembled.Cache;
        }

        var translation = session.Artifacts!.Translation!;
        var template = LE3MaterialResourceBuilder.Build(translation, unit.ResourceId);
        var paths = LE3MaterialResourceBuilder.GetUniformExpressionTexturePaths(translation).ToList();
        return new Compiled(template, paths, graph.FileRef.FilePath, LE3MaterialResourceBuilder.GetInstanceTextureParameterOrder(translation), shaders);
    }

    private static string LastSegment(string path) => path[(path.LastIndexOf('.') + 1)..];

    /// <summary>An import of the placeholder for this decode, for compiling only; installed packages get the real export.</summary>
    private static IEntry PlaceholderImport(IMEPackage package, TextureCompilationMetadata m)
    {
        if (package.FindEntry(PlaceholderPath(m)) is { } existing) return existing;
        var root = package.FindEntry(PlaceholderRoot);
        if (root == null)
        {
            var rootImport = new ImportEntry(package, null, PlaceholderRoot) { ClassName = "Package", PackageFile = "Core" };
            package.AddImport(rootImport);
            root = rootImport;
        }
        var texture = new ImportEntry(package, root, PlaceholderName(m)) { ClassName = "Texture2D", PackageFile = "Engine" };
        package.AddImport(texture);
        return texture;
    }

    // ---------------------------------------------------------------- apply

    private void ApplyToPackage(string file)
    {
        string name = Path.GetFileName(file);
        var materials = plan.Materials.Where(m => m.ModOwned && m.Packages.Contains(name)).ToList();
        var instances = plan.Instances.Where(i => i.Packages.Contains(name)).ToList();
        var variants = plan.Variants.Where(v => v.Packages.Contains(name)).ToList();
        var clones = plan.ChainClones.Where(c => c.Packages.Contains(name)).ToList();
        if (materials.Count + instances.Count + variants.Count + clones.Count == 0) return;

        using var package = MEPackageHandler.OpenMEPackage(file, forceLoadFromDisk: true);
        using var cache = new PackageCache { CacheMaxSize = 30 };
        var rop = new RelinkerOptionsPackage(cache)
        {
            SourceCustomImportFileResolver = context.OpenByFileName,
            DestinationCustomImportFileResolver = context.OpenByFileName,
            PortExportsAsImportsWhenPossible = true,
            TargetGameDonorDB = MilanShared.LE3ObjectDB
        };
        var merged = ShaderCache.Create();
        void Merge(string unitId) { if (compiled.TryGetValue(unitId, out var c) && c.Shaders != null) c.Shaders.MergeInto(merged); }

        try
        {
            foreach (var m in materials)
            {
                var export = FindByIdentity(package, m.Identity) ?? throw new ShaderInstallException($"{m.Identity} is missing");
                foreach (var flag in m.FlagsToSet) export.WriteProperty(new BoolProperty(true, flag));
                if (compiled.TryGetValue("M:" + m.Identity, out var c))
                    ObjectBinary.EditBinary<Material>(export, b => b.SM3MaterialResource = Resolve(c, package, rop, m.LiveResourceId, null));
                Merge("M:" + m.Identity);
            }
            foreach (var v in variants.OrderBy(v => v.Identity, StringComparer.Ordinal))
            {
                CreateVariant(v, package, cache, rop);
                Merge("V:" + v.Identity);
            }
            // Clones nearest the variant first, so each parent exists before its child.
            foreach (var c in clones.OrderBy(c => Depth(c.Identity)))
            {
                CreateClone(c, package, cache, rop);
                Merge("C:" + c.Identity);
            }
            foreach (var i in instances)
            {
                var export = FindByIdentity(package, i.Identity) ?? throw new ShaderInstallException($"{i.Identity} is missing");
                if (i.RetargetParentTo != null)
                    export.WriteProperty(new ObjectProperty(FindByIdentity(package, i.RetargetParentTo)!.UIndex, "Parent"));
                if (i.Rewrite) ApplyPermutation(export, i.Key, "I:" + i.Identity, package, cache, rop);
                Merge("I:" + i.Identity);
            }

            ShaderCacheManipulator.AddShadersToFile(package, merged, overwrite: true);
            ShaderCacheManipulator.CompactSeekFreeShaderCaches(package, context.GameRoot);
            foreach (var broken in ShaderCacheManipulator.GetBrokenMaterials(package, context.GameRoot).Where(e => !e.IsA("Terrain")).Distinct())
                failures.Add($"{name}: {broken.InstancedFullPath} has no shader map after the install");
            package.Save();
            log($"Shader install: {name}: {materials.Count} materials, {instances.Count} instances, {variants.Count} variants, {clones.Count} clones");
        }
        catch (Exception e)
        {
            failures.Add($"{name}: {e.GetType().Name}: {e.Message} @ {string.Join(" < ", (e.StackTrace ?? "").Split((char)10).Take(3).Select(l => l.Trim()))}");
        }
    }

    private int Depth(string cloneIdentity)
    {
        int depth = 0;
        for (var c = plan.ChainClones.FirstOrDefault(x => x.Identity == cloneIdentity); c != null;
             c = plan.ChainClones.FirstOrDefault(x => x.Identity == c.ParentIdentity)) depth++;
        return depth;
    }

    /// <summary>The template with its textures (and, for an instance, its effective parameter textures) in this package.</summary>
    private MaterialResource Resolve(Compiled c, IMEPackage package, RelinkerOptionsPackage rop, Guid id, ExportEntry? instance)
    {
        var graphPackage = rop.Cache.GetCachedPackage(c.GraphPackagePath);
        var textures = c.TexturePaths.Select(p => EnsureEntry(package, p, graphPackage, rop)).ToList();
        if (instance != null)
        {
            foreach (string parameter in c.ParameterOrder)
                if (EffectiveTexture(instance, parameter, rop) is { } effective)
                {
                    int uIndex = EnsureEntry(package, effective.InstancedFullPath, effective.FileRef, rop);
                    if (!textures.Contains(uIndex)) textures.Add(uIndex);
                }
        }
        var resource = CloneResource(c.Template);
        resource.ID = id;
        resource.UniformExpressionTextures = textures.ToArray();
        return resource;
    }

    private static MaterialResource CloneResource(MaterialResource t)
    {
        var r = MaterialResource.Create();
        r.NumUserTexCoords = t.NumUserTexCoords;
        r.bUsesSceneColor = t.bUsesSceneColor;
        r.bUsesSceneDepth = t.bUsesSceneDepth;
        r.bUsesDynamicParameter = t.bUsesDynamicParameter;
        r.bUsesLightmapUVs = t.bUsesLightmapUVs;
        r.bUsesMaterialVertexPositionOffset = t.bUsesMaterialVertexPositionOffset;
        r.bUsesVertexColor = t.bUsesVertexColor;
        r.UsingTransforms = t.UsingTransforms;
        r.MaxTextureDependencyLength = t.MaxTextureDependencyLength;
        r.TextureLookups = t.TextureLookups.Select(l => new MaterialResource.TextureLookup
            { TexCoordIndex = l.TexCoordIndex, TextureIndex = l.TextureIndex, UScale = l.UScale, VScale = l.VScale, Unk = l.Unk }).ToArray();
        return r;
    }

    private static int EnsureEntry(IMEPackage package, string path, IMEPackage source, RelinkerOptionsPackage rop)
    {
        var existing = PathLookup.FindEntry(package, path, PathLookup.IsTexture);
        if (existing != null) return existing.UIndex;
        if (ReferenceEquals(source, package) || source.FilePath == package.FilePath)
            throw new ShaderInstallException($"{path} is missing from {Path.GetFileName(package.FilePath)}");
        return EntryImporter.GetOrAddCrossImportOrPackage(path, source, package, rop)?.UIndex
               ?? throw new ShaderInstallException($"{path} could not be imported into {Path.GetFileName(package.FilePath)}");
    }

    /// <summary>Nearest non-null override of a texture parameter up the instance chain; null when none overrides it.</summary>
    private IEntry? EffectiveTexture(ExportEntry instance, string parameter, RelinkerOptionsPackage rop)
    {
        var current = instance;
        for (int depth = 0; depth < 64 && current != null && MaterialChain.IsLink(current); depth++)
        {
            foreach (var value in (IEnumerable<StructProperty>?)current.GetProperty<ArrayProperty<StructProperty>>("TextureParameterValues") ?? [])
                if (string.Equals(value.GetProp<NameProperty>("ParameterName")?.Value.Instanced, parameter, StringComparison.OrdinalIgnoreCase) &&
                    value.GetProp<ObjectProperty>("ParameterValue")?.Value is int v && v != 0)
                    return current.FileRef.GetEntry(v);
            int parent = MaterialChain.NextReference(current);
            current = current.FileRef.GetEntry(parent) switch
            {
                ExportEntry e => e,
                ImportEntry i => context.ResolveImport(i, rop.Cache),
                _ => null
            };
        }
        return null;
    }

    private void ApplyPermutation(ExportEntry instance, StaticParameterSet? key, string unitId, IMEPackage package,
        PackageCache cache, RelinkerOptionsPackage rop)
    {
        if (key == null) return;
        if (!compiled.TryGetValue(unitId, out var c)) throw new ShaderInstallException($"{unitId} was not compiled");
        var resource = Resolve(c, package, rop, c.Template.ID, instance);
        // The binary layout follows the flag: read it under the old flag (an instance gaining its first permutation
        // has none to read), then set the flag and write the permutation.
        bool hadPermutation = instance.GetProperty<BoolProperty>("bHasStaticPermutationResource")?.Value == true;
        var binary = hadPermutation ? ObjectBinary.From<MaterialInstance>(instance) : MaterialInstance.Create();
        binary.SM3StaticParameterSet = key;
        binary.SM3StaticPermutationResource = resource;
        instance.WriteProperty(new BoolProperty(true, "bHasStaticPermutationResource"));
        instance.WriteBinary(binary);
    }

    private ExportEntry Root(IMEPackage package, string name) =>
        package.FindExport(name) ?? ExportCreator.CreatePackageExport(package, name, forcedExport: true);

    private ExportEntry CopyInto(string sourceIdentity, string sourcePackagePath, string objectName, IMEPackage package,
        PackageCache cache, RelinkerOptionsPackage rop)
    {
        var root = Root(package, VariantRoot);
        var local = FindByIdentity(package, sourceIdentity);
        ExportEntry copy;
        if (local != null)
        {
            copy = EntryCloner.CloneTree(local, incrementIndex: false);
            copy.idxLink = root.UIndex;
        }
        else
        {
            var sourcePackage = cache.GetCachedPackage(sourcePackagePath);
            var source = FindByIdentity(sourcePackage, sourceIdentity) ?? throw new ShaderInstallException($"{sourceIdentity} is not in {sourcePackagePath}");
            copy = PortCopy(source, package, root, rop);
        }
        copy.ObjectName = new NameReference(objectName);
        return copy;
    }

    /// <summary>Ports a copy of <paramref name="source"/>'s tree under <paramref name="root"/> as new exports.</summary>
    /// <remarks>The porter reuses any entry already at the source's path, and the package usually imports the original
    /// (its instances point at it), so that import is renamed aside while the copy is made.</remarks>
    public static ExportEntry PortCopy(ExportEntry source, IMEPackage package, IEntry root, RelinkerOptionsPackage rop)
    {
        var clash = package.FindEntry(source.InstancedFullPath) as ImportEntry;
        var clashName = clash?.ObjectName;
        if (clash != null) clash.ObjectName = new NameReference(clash.ObjectName.Name + "_MilanPortAside", clash.ObjectName.Number);
        List<EntryStringPair> bad;
        IEntry newEntry;
        try
        {
            bad = EntryImporter.ImportAndRelinkEntries(EntryImporter.PortingOption.CloneTreeAsChild, source, package, root, true, rop, out newEntry);
        }
        finally
        {
            if (clash != null) clash.ObjectName = clashName!.Value;
        }
        if (bad.Count > 0) throw new ShaderInstallException($"porting {source.InstancedFullPath}: {string.Join("; ", bad.Select(b => b.Message))}");
        return newEntry as ExportEntry ?? throw new ShaderInstallException(
            $"porting {source.InstancedFullPath} into {package.FileNameNoExtension} gave {newEntry?.ClassName} {newEntry?.InstancedFullPath}, not a copy");
    }

    private void CreateVariant(ParentVariantPlan v, IMEPackage package, PackageCache cache, RelinkerOptionsPackage rop)
    {
        if (FindByIdentity(package, v.Identity) != null) return;
        var variant = CopyInto(v.SourceIdentity, v.SourcePackagePath, v.ObjectName, package, cache, rop);
        var sourcePlan = plan.Materials.FirstOrDefault(m => m.Identity == v.SourceIdentity);
        foreach (var flag in sourcePlan?.FlagsToSet ?? []) variant.WriteProperty(new BoolProperty(true, flag));
        foreach (var swap in v.Swaps)
        {
            var expression = package.Exports.FirstOrDefault(e => e.Parent == variant && e.ObjectName.Instanced == LastSegment(swap.ExpressionPath))
                             ?? throw new ShaderInstallException($"{v.Identity}: {swap.ExpressionPath} was not copied");
            expression.WriteProperty(new ObjectProperty(Placeholder(package, swap.Metadata).UIndex, "Texture"));
        }
        if (!compiled.TryGetValue("V:" + v.Identity, out var c)) throw new ShaderInstallException($"{v.Identity} was not compiled");
        ObjectBinary.EditBinary<Material>(variant, b => b.SM3MaterialResource = Resolve(c, package, rop, v.ResourceId, null));
    }

    private void CreateClone(ChainClonePlan c, IMEPackage package, PackageCache cache, RelinkerOptionsPackage rop)
    {
        if (FindByIdentity(package, c.Identity) != null) return;
        var clone = CopyInto(c.SourceIdentity, c.SourcePackagePath, c.ObjectName, package, cache, rop);
        clone.WriteProperty(new ObjectProperty(FindByIdentity(package, c.ParentIdentity)!.UIndex, "Parent"));
        if (c.Key == null)
        {
            clone.RemoveProperty("bHasStaticPermutationResource");
            clone.WriteBinary(MaterialInstance.Create());
        }
        else ApplyPermutation(clone, c.Key, "C:" + c.Identity, package, cache, rop);
    }

    // ---------------------------------------------------------------- placeholders

    private static string PlaceholderName(TextureCompilationMetadata m) => "P_" + m.CompressionSettings.Replace("TC_", "") + "_" +
        Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes($"{m.Dimension}|{m.CompressionSettings}|{m.UnpackMin}|{m.UnpackMax}")), 0, 4);

    private static string PlaceholderPath(TextureCompilationMetadata m) => PlaceholderRoot + "." + PlaceholderName(m);

    private static PixelFormat PlaceholderFormat(TextureCompilationMetadata m) => m.Dimension != TextureDimension.Texture2D
        ? throw new ShaderInstallException($"No placeholder for a {m.Dimension}")
        : m.CompressionSettings switch
        {
            "TC_Default" or "TC_Normalmap" or "TC_OneBitAlpha" => PixelFormat.DXT1,
            "TC_NormalmapAlpha" => PixelFormat.DXT5,
            "TC_NormalmapBC5" or "TC_NormalmapHQ" => PixelFormat.BC5,
            "TC_NormalmapBC7" or "TC_BC7" => PixelFormat.BC7,
            "TC_NormalmapUncompressed" => PixelFormat.V8U8,
            "TC_Grayscale" => PixelFormat.G8,
            _ => throw new ShaderInstallException($"No placeholder format for {m.CompressionSettings}")
        };

    /// <summary>A 32x32 texture showing a "P", with the metadata the variant was compiled for. Byte-identical everywhere.</summary>
    private ExportEntry Placeholder(IMEPackage package, TextureCompilationMetadata m)
    {
        string name = PlaceholderName(m);
        var root = Root(package, PlaceholderRoot);
        if (package.Exports.FirstOrDefault(e => e.Parent == root && e.ObjectName.Instanced == name) is { } existing) return existing;
        var format = PlaceholderFormat(m);
        var texture = Texture2D.CreateTexture(package, name, PlaceholderSize, PlaceholderSize, format, false, root);
        texture.WriteProperty(new EnumProperty(m.CompressionSettings, "TextureCompressionSettings", package.Game, "CompressionSettings"));
        texture.WriteProperty(new BoolProperty(!m.CompressionSettings.Contains("Normal") && m.CompressionSettings != "TC_Grayscale", "SRGB"));
        for (int i = 0; i < 4; i++)
        {
            texture.WriteProperty(new FloatProperty(m.UnpackMin[i], "UnpackMin") { StaticArrayIndex = i });
            texture.WriteProperty(new FloatProperty(m.UnpackMax[i], "UnpackMax") { StaticArrayIndex = i });
        }
        byte[] mip;
        lock (placeholderMips)
        {
            if (!placeholderMips.TryGetValue(name, out mip!))
            {
                var image = Image.LoadFromRaw(LetterP(), PixelFormat.ARGB, PlaceholderSize, PlaceholderSize);
                image.correctMips(format, false);
                placeholderMips[name] = mip = image.mipMaps[0].data;
            }
        }
        var binary = UTexture2D.Create();
        binary.Mips.Add(new UTexture2D.Texture2DMipMap(mip, PlaceholderSize, PlaceholderSize));
        texture.WriteBinary(binary);
        return texture;
    }

    /// <summary>32x32 BGRA: a white "P" on mid grey.</summary>
    private static byte[] LetterP()
    {
        var pixels = new byte[PlaceholderSize * PlaceholderSize * 4];
        for (int y = 0; y < PlaceholderSize; y++)
        for (int x = 0; x < PlaceholderSize; x++)
        {
            bool stem = x is >= 8 and < 13 && y is >= 4 and < 28;
            int dx = x - 15, dy = y - 11;
            double r = Math.Sqrt(dx * dx + dy * dy);
            bool bowl = x >= 12 && y is >= 4 and < 19 && r is >= 3 and < 8;
            byte v = stem || bowl ? (byte)255 : (byte)128;
            int o = (y * PlaceholderSize + x) * 4;
            pixels[o] = pixels[o + 1] = pixels[o + 2] = v;
            pixels[o + 3] = 255;
        }
        return pixels;
    }
}
