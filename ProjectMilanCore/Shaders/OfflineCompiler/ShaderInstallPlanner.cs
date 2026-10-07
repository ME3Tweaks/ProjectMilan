using System.Runtime.CompilerServices;
using System.Security.Cryptography;
using System.Text;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Shaders;
using LegendaryExplorerCore.Unreal;
using LegendaryExplorerCore.Unreal.BinaryConverters;
using LegendaryExplorerCore.Unreal.ObjectInfo;
using static LegendaryExplorerCore.Shaders.LE3MaterialShaderCompiler;

namespace ProjectMilanCore.Shaders.OfflineCompiler;

/// <summary>A base Material and what the install does to it.</summary>
/// <param name="Identity">Memory path: the object the game sees, shared by every identical copy.</param>
/// <param name="ModOwned">Lives in the mod's packages and can be edited; otherwise a vanilla object.</param>
/// <param name="NewResourceId">Set when the material changes (usage flags), so it cannot reuse a vanilla map.</param>
/// <param name="Rewrite">Its resource is rewritten in every copy even without a compile: the copies carried different IDs.</param>
public sealed record MaterialInstallPlan(string Identity, bool ModOwned, Guid ResourceId, IReadOnlyList<string> Packages,
    IReadOnlyList<string> FlagsToSet, Guid? NewResourceId, bool Compile, bool Rewrite = false)
{
    public Guid LiveResourceId => NewResourceId ?? ResourceId;
}

/// <summary>A static normal parameter an instance's permutation must carry.</summary>
public sealed record StaticNormalFix(string Parameter, byte CompressionSettings, string CompressionName);

/// <summary>A MaterialInstance and what the install does to it.</summary>
/// <param name="RetargetParentTo">Identity of the variant or chain clone that becomes its parent, if any.</param>
/// <param name="Key">Its static permutation key after the install; null when it has no permutation.</param>
/// <param name="Rewrite">Its permutation is written; false when the key is unchanged and its map already exists.</param>
public sealed record InstanceInstallPlan(string Identity, IReadOnlyList<string> Packages, string? RetargetParentTo,
    IReadOnlyList<StaticNormalFix> StaticNormalFixes, StaticParameterSet? Key, bool Compile, bool Rewrite = true);

/// <summary>One sampler of a parent variant whose default becomes a placeholder of the given metadata.</summary>
public sealed record VariantSamplerSwap(string ExpressionPath, string Parameter, TextureCompilationMetadata Metadata);

/// <summary>A deterministic copy of a parent Material whose swapped samplers decode the overriding textures.</summary>
public sealed record ParentVariantPlan(string Identity, string ObjectName, string SourceIdentity, string SourcePackagePath, Guid ResourceId,
    string Signature, IReadOnlyList<VariantSamplerSwap> Swaps, IReadOnlyList<string> Packages);

/// <summary>A deterministic copy of an intermediate instance, re-parented onto a variant or another clone.</summary>
public sealed record ChainClonePlan(string Identity, string ObjectName, string SourceIdentity, string SourcePackagePath, string ParentIdentity,
    StaticParameterSet? Key, IReadOnlyList<string> Packages);

/// <summary>Everything the shader install will do, decided over all packages at once.</summary>
public sealed record ShaderInstallPlan(IReadOnlyList<MaterialInstallPlan> Materials, IReadOnlyList<InstanceInstallPlan> Instances,
    IReadOnlyList<ParentVariantPlan> Variants, IReadOnlyList<ChainClonePlan> ChainClones, IReadOnlyList<string> Errors,
    IReadOnlyList<string> Reports)
{
    /// <summary>Errors fail the build; the install must not start.</summary>
    public bool CanInstall => Errors.Count == 0;

    /// <summary>Stable text form, for logs and determinism checks.</summary>
    public string Describe()
    {
        var sb = new StringBuilder();
        foreach (var m in Materials)
            sb.AppendLine($"material {m.Identity} owned={m.ModOwned} id={m.ResourceId} new={m.NewResourceId} compile={m.Compile} rewrite={m.Rewrite} flags=[{string.Join(",", m.FlagsToSet)}] packages=[{string.Join(",", m.Packages)}]");
        foreach (var i in Instances)
            sb.AppendLine($"instance {i.Identity} parent->{i.RetargetParentTo} compile={i.Compile} rewrite={i.Rewrite} key={DescribeKey(i.Key)} normals=[{string.Join(",", i.StaticNormalFixes.Select(f => f.Parameter + "=" + f.CompressionName))}] packages=[{string.Join(",", i.Packages)}]");
        foreach (var v in Variants)
            sb.AppendLine($"variant {v.Identity} from {v.SourceIdentity} id={v.ResourceId} sig={v.Signature} packages=[{string.Join(",", v.Packages)}]");
        foreach (var c in ChainClones)
            sb.AppendLine($"clone {c.Identity} from {c.SourceIdentity} parent->{c.ParentIdentity} key={DescribeKey(c.Key)} packages=[{string.Join(",", c.Packages)}]");
        foreach (var e in Errors) sb.AppendLine("error " + e);
        foreach (var r in Reports) sb.AppendLine("report " + r);
        return sb.ToString();
    }

    public static string DescribeKey(StaticParameterSet? key) => key == null ? "-" :
        $"{key.BaseMaterialId}|{string.Join(";", key.StaticSwitchParameters.Select(p => $"{p.ParameterName.Instanced}={p.Value}"))}" +
        $"|{string.Join(";", key.StaticComponentMaskParameters.Select(p => $"{p.ParameterName.Instanced}={p.R}{p.G}{p.B}{p.A}"))}" +
        $"|{string.Join(";", key.NormalParameters.Select(p => $"{p.ParameterName.Instanced}={p.CompressionSettings}"))}";
}

/// <summary>Inputs the planner needs from the build.</summary>
public sealed class ShaderInstallPlannerOptions
{
    /// <summary>Every package of the mod output, as full paths. Objects in them are mod-owned.</summary>
    public required IReadOnlyCollection<string> ModPackagePaths { get; init; }
    /// <summary>Resolves an import the way the game would; mod output first. May return null.</summary>
    public required Func<ImportEntry, ExportEntry?> ResolveImport { get; init; }
    /// <summary>Final (post-texture-pipeline) texture metadata.</summary>
    public required ITextureCompilationMetadataProvider TextureMetadata { get; init; }
    /// <summary>The copy of a Material whose expression graph can be compiled, for cooked parents stripped to their
    /// parameter nodes. Null keeps the material itself.</summary>
    public Func<ExportEntry, ExportEntry?>? GraphSource { get; init; }
    /// <summary>Returns the subset of the keys that the game's RefShaderCache already has.</summary>
    public required Func<IReadOnlyCollection<StaticParameterSet>, ISet<StaticParameterSet>> KeysInRefShaderCache { get; init; }
    /// <summary>True when compiling <paramref name="graph"/> with the swapped samplers changes its HLSL. Null treats
    /// every candidate as real.</summary>
    public Func<ExportEntry, IReadOnlyList<VariantSamplerSwap>, bool>? ConfirmVariant { get; init; }
}

/// <summary>
/// The read-only half of the shader install: walks every output package after the texture pipeline and decides,
/// for the whole mod at once, which usage flags each material needs, which instances need a static normal fix or a
/// parent variant, and which shader maps must be compiled. Decisions are global because the same memory path in
/// several packages must stay one object at runtime: every copy gets the same edits. Packages may be disposed as
/// soon as they have been passed to <see cref="AddPackage"/>.
/// </summary>
public sealed class ShaderInstallPlanner(ShaderInstallPlannerOptions options)
{
    private const int MaxChain = 64;
    private readonly HashSet<string> modPackages = new(options.ModPackagePaths.Select(Path.GetFullPath), StringComparer.OrdinalIgnoreCase);
    private readonly SortedDictionary<string, MaterialRecord> materials = new(StringComparer.Ordinal);
    private readonly SortedDictionary<string, InstanceRecord> instances = new(StringComparer.Ordinal);
    private readonly SortedSet<string> errors = new(StringComparer.Ordinal);
    private readonly SortedSet<string> reports = new(StringComparer.Ordinal);
    private readonly ConditionalWeakTable<ExportEntry, StrongBox<bool>> shipsEmpty = new(); // reads the binary once
    private readonly Dictionary<string, bool> confirmed = new(StringComparer.Ordinal);
    private readonly HashSet<string> effectsUsers = new(StringComparer.Ordinal); // effects user and multiplexor links seen in chains
    private readonly Dictionary<string, HashSet<StaticParameterSet>> localKeys = new(StringComparer.OrdinalIgnoreCase); // package -> its own shader maps

    private sealed class MaterialRecord
    {
        public required string Identity;
        public bool ModOwned;
        public Guid ResourceId;
        public string ClassName = "Material";
        public string SourcePackagePath = "";
        public string? Hash, FullHash;
        public bool HasGraph = true; // false: no decooked graph and not authored empty, so it cannot be compiled
        public bool EmptyByDesign; // shipped empty, or authored empty with no decooked graph: compiled as authored
        public readonly Dictionary<string, Guid> CopyIds = new(StringComparer.Ordinal); // package -> that copy's resource ID
        public readonly SortedSet<string> Packages = new(StringComparer.Ordinal);
        public readonly SortedSet<string> SetFlags = new(StringComparer.Ordinal);
        public readonly SortedSet<string> FlagsToSet = new(StringComparer.Ordinal);
        public readonly HashSet<LE3MaterialUsage> Uses = [];
    }

    private sealed class InstanceRecord
    {
        public required string Identity;
        public required string ObjectName;
        public string SourcePackagePath = "";
        public string? Hash, FullHash;
        public readonly SortedSet<string> Packages = new(StringComparer.Ordinal);
        /// <summary>Ancestor identities, nearest first, ending at the base Material.</summary>
        public List<string> Chain = [];
        public StaticParameterSet? StoredKey;
        public readonly List<StaticNormalFix> NormalFixes = [];
        /// <summary>Confirmed variant swaps this instance needs, when it owns at least one of the overrides.</summary>
        public List<VariantSamplerSwap>? OwnedVariant;
    }

    private static string Identity(ExportEntry export) => export.MemoryFullPath;

    /// <summary>Scans one output package. Only data is kept; the package can be disposed afterwards.</summary>
    public void AddPackage(IMEPackage package)
    {
        string name = Path.GetFileName(package.FilePath);
        // Maps the package already carries count like RefShaderCache maps: compaction keeps them for its materials.
        if (package.FindExport("SeekFreeShaderCache") is { } localCache)
            localKeys[name] = localCache.GetBinaryData<ShaderCache>().MaterialShaderMaps.Keys.ToHashSet();
        try
        {
            foreach (var use in LE3MaterialUsageScanner.Collect(package, i => options.ResolveImport(i)))
            {
                if (use.BaseMaterial == null)
                {
                    reports.Add($"unresolved material {use.ReferencePath} ({use.Usage}) used by {use.Source} in {name}");
                    continue;
                }
                RecordMaterial(use.BaseMaterial, null).Uses.Add(use.Usage);
            }
        }
        catch (Exception e)
        {
            errors.Add($"usage scan of {name} failed: {e.Message}");
        }

        foreach (var export in package.Exports)
        {
            try
            {
                if (export.IsA("Material")) RecordMaterial(export, name);
                else if (export.IsA("MaterialInstance")) RecordInstance(export, name);
            }
            catch (Exception e)
            {
                errors.Add($"{export.InstancedFullPath} in {name}: {e.Message}");
            }
        }
    }

    private bool IsModOwned(ExportEntry export) => export.FileRef.FilePath is { } path && modPackages.Contains(Path.GetFullPath(path));

    private MaterialRecord RecordMaterial(ExportEntry material, string? package)
    {
        string identity = Identity(material);
        if (!materials.TryGetValue(identity, out var record))
        {
            materials[identity] = record = new MaterialRecord
            {
                Identity = identity, ModOwned = IsModOwned(material), ClassName = material.ClassName, SourcePackagePath = material.FileRef.FilePath ?? "",
                ResourceId = ObjectBinary.From<Material>(material).SM3MaterialResource.ID
            };
        }
        // Copies are compared and their flags merged only when seen as exports of a scanned package.
        if (package != null && record.Packages.Add(package))
        {
            // First seen through an import resolved into another file; this is a mod export, so the mod owns it.
            if (!record.ModOwned) (record.ModOwned, record.SourcePackagePath) = (true, material.FileRef.FilePath ?? "");
            var props = material.GetProperties();
            foreach (var flag in props.OfType<BoolProperty>().Where(b => b.Value && b.Name.Name.StartsWith("bUsed", StringComparison.Ordinal)))
                record.SetFlags.Add(flag.Name.Name);
            // The resource ID is compared separately: copies that differ only there are normalized, not failed.
            record.CopyIds[package] = ObjectBinary.From<Material>(material).SM3MaterialResource.ID;
            string hash = CopyHash(material, "", true), fullHash = CopyHash(material, "", false);
            if (record.Hash == null)
            {
                (record.Hash, record.FullHash) = (hash, fullHash);
                var graph = ResolveForGraph(material);
                record.HasGraph = graph != null;
                record.EmptyByDesign = graph != null && ReferenceEquals(graph, material);
            }
            else CompareCopies(identity, record.Packages, record.Hash, record.FullHash!, hash, fullHash);
        }
        return record;
    }

    private void RecordInstance(ExportEntry instance, string package)
    {
        string identity = Identity(instance);
        bool permutation = instance.GetProperty<BoolProperty>("bHasStaticPermutationResource")?.Value == true;
        var stored = permutation ? ObjectBinary.From<MaterialInstance>(instance).SM3StaticParameterSet : null;
        // The stored base ID is left out: every key is re-based on the live base ID.
        string key = ShaderInstallPlan.DescribeKey(stored);
        key = stored == null ? key : key[(key.IndexOf('|') + 1)..];
        string hash = CopyHash(instance, key, true), fullHash = CopyHash(instance, key, false);
        if (instances.TryGetValue(identity, out var existing))
        {
            existing.Packages.Add(package);
            CompareCopies(identity, existing.Packages, existing.Hash!, existing.FullHash!, hash, fullHash);
            return;
        }
        var record = new InstanceRecord { Identity = identity, ObjectName = instance.ObjectName.Instanced, Hash = hash, FullHash = fullHash, StoredKey = stored,
            SourcePackagePath = instance.FileRef.FilePath ?? "" };
        record.Packages.Add(package);
        instances[identity] = record;

        // The live chain decides keys; the graph chain (stripped parents swapped for their decooked graph) decides decode.
        var chain = new List<ExportEntry>();
        var current = instance;
        for (int depth = 0; depth < MaxChain && MaterialChain.IsLink(current); depth++)
        {
            int parent = MaterialChain.NextReference(current);
            var next = parent == 0 ? null : current.FileRef.GetEntry(parent) switch
            {
                ExportEntry e => e,
                ImportEntry i => options.ResolveImport(i),
                _ => null
            };
            if (next == null) { errors.Add($"{identity}: parent of {current.InstancedFullPath} does not resolve"); return; }
            chain.Add(next);
            current = next;
        }
        if (!current.IsA("Material"))
        {
            errors.Add($"{identity}: parent chain does not end at a Material ({string.Join(" -> ", chain.Select(c => $"{c.ClassName} {c.InstancedFullPath} in {Path.GetFileName(c.FileRef.FilePath)}"))})");
            return;
        }
        record.Chain = chain.Select(Identity).ToList();
        foreach (var link in chain.Where(MaterialChain.IsEffectsLink)) effectsUsers.Add(Identity(link));
        RecordMaterial(current, null);
        foreach (var ancestor in chain.Where(a => a.IsA("MaterialInstance")))
            if (!instances.ContainsKey(Identity(ancestor)) && !IsModOwned(ancestor))
                instances[Identity(ancestor)] = new InstanceRecord
                {
                    Identity = Identity(ancestor), ObjectName = ancestor.ObjectName.Instanced, SourcePackagePath = ancestor.FileRef.FilePath ?? "",
                    StoredKey = ancestor.GetProperty<BoolProperty>("bHasStaticPermutationResource")?.Value == true
                        ? ObjectBinary.From<MaterialInstance>(ancestor).SM3StaticParameterSet : null
                };

        // Without a texture override or a permutation anywhere in the chain the instance samples exactly what its base
        // compiles, so there is nothing to analyze, and its base needs no graph (EngineMaterials, which the decooker
        // skips, e.g. FogVolumeMaterial under the levels' fog instances).
        bool overridesOrPermutes = chain.Prepend(instance).Where(e => e.IsA("MaterialInstance")).Any(e =>
            e.GetProperty<ArrayProperty<StructProperty>>("TextureParameterValues") is { Count: > 0 } ||
            e.GetProperty<BoolProperty>("bHasStaticPermutationResource")?.Value == true);
        if (!overridesOrPermutes) return;

        var report = MaterialInstanceEncodingAnalyzer.Analyze(instance, ResolveForGraph, options.TextureMetadata);
        if (!report.IsComplete)
        {
            // Lookups are cached, so search every failed resolution for the unresolved findings' textures.
            var unresolved = report.Findings.Where(f => f.Requirement == TextureEncodingRequirement.Unresolved).ToList();
            var textures = unresolved.SelectMany(f => new[] { f.DefaultTexture, f.EffectiveTexture }).OfType<string>().ToHashSet(StringComparer.OrdinalIgnoreCase);
            var failed = options.TextureMetadata.Resolutions.Where(r => r.Metadata == null && textures.Contains(r.Reference))
                .Select(r => $"{r.Reference}: {r.Failure}").Distinct().ToList();
            errors.Add($"{identity}: encoding analysis incomplete: {string.Join("; ", report.Errors.Concat(unresolved
                .Select(f => f.ParameterName + ": " + f.Reason)).Distinct())}" + (failed.Count > 0 ? " [" + string.Join("; ", failed) + "]" : ""));
            return;
        }
        var names = GlobalUnrealObjectInfo.GetEnumValues(MEGame.LE3, "TextureCompressionSettings");
        foreach (var finding in report.Findings.Where(f => f.Requirement == TextureEncodingRequirement.StaticNormalCompression))
        {
            string compression = finding.EffectiveMetadata!.CompressionSettings;
            int index = names.FindIndex(n => string.Equals(n.Instanced, compression, StringComparison.OrdinalIgnoreCase));
            if (index < 0) { errors.Add($"{identity}: {compression} is not an LE3 compression setting"); continue; }
            record.NormalFixes.Add(new StaticNormalFix(finding.ParameterName, (byte)index, compression));
        }
        foreach (var finding in report.Findings.Where(f => f.Requirement == TextureEncodingRequirement.DimensionMismatch))
            reports.Add($"{finding.OverriddenBy} overrides {finding.ParameterName} ({finding.DefaultMetadata!.Dimension}) with " +
                $"{finding.EffectiveTexture} ({finding.EffectiveMetadata!.Dimension}); left as authored");
        var candidates = report.Findings.Where(f => f.Requirement == TextureEncodingRequirement.ParentVariantCandidate).ToList();
        if (candidates.Any(f => f.OverriddenBy == instance.InstancedFullPath))
        {
            var swaps = candidates.Select(f => new VariantSamplerSwap(f.ExpressionPath, f.ParameterName, f.EffectiveMetadata!))
                .OrderBy(s => s.Parameter, StringComparer.OrdinalIgnoreCase).ToList();
            var graph = ResolveForGraph(chain[^1])!;
            string confirmKey = Identity(chain[^1]) + "\n" + string.Join("\n", swaps.Select(s => s.ExpressionPath + "=" + Describe(s.Metadata)));
            if (!confirmed.TryGetValue(confirmKey, out bool real))
                confirmed[confirmKey] = real = options.ConfirmVariant?.Invoke(graph, swaps) ?? true;
            if (real) record.OwnedVariant = swaps;
        }
    }

    // Parents for analysis: imports resolved, stripped materials swapped for a compilable graph.
    // Instances resolve as themselves. A Material resolves to its decooked graph: cooked copies are always stripped (SFXGame's
    // ME3_OPAQUE_MM keeps 50 of 118 expressions and no texture samples), so they are never compiled or analyzed. A material
    // authored empty (MPLobby.Black) is its own graph. Anything else has no graph: null.
    private ExportEntry? ResolveForGraph(IEntry entry)
    {
        var export = entry as ExportEntry ?? (entry is ImportEntry i ? options.ResolveImport(i) : null);
        if (export == null || !export.IsA("Material") || options.GraphSource == null) return export;
        if (shipsEmpty.GetValue(export, e => new StrongBox<bool>(MaterialChain.ShipsEmpty(e))).Value) return export;
        return options.GraphSource(export) ?? (MaterialChain.IsEmptyByDesign(export) ? export : null);
    }

    /// <summary>Makes the global decisions. Call once, after every package was added.</summary>
    public ShaderInstallPlan Build()
    {
        // One resource ID per material: the copy in the first package (ordinal), so every copy is rewritten to match.
        foreach (var m in materials.Values.Where(m => m.CopyIds.Count > 0)) m.ResourceId = m.CopyIds[m.Packages.First()];
        bool InLocal(StaticParameterSet key, IReadOnlyCollection<string> packages) =>
            packages.Count > 0 && packages.All(p => localKeys.TryGetValue(p, out var keys) && keys.Contains(key));

        // Usage flags on mod-owned materials; vanilla gaps are reported.
        foreach (var m in materials.Values)
        {
            if (m.Uses.Count == 0) continue;
            var props = new PropertyCollection();
            foreach (var flag in m.SetFlags) props.Add(new BoolProperty(true, flag));
            var check = LE3MaterialUsageAdvisor.Check(props, m.Uses, m.ClassName);
            foreach (var vetoed in check.Vetoed) (m.ModOwned ? errors : reports).Add($"{m.Identity} is used as {vetoed}, which its decal/fog use forbids");
            if (check.MissingFlags.Count == 0) continue;
            if (m.ModOwned && !m.HasGraph)
                reports.Add($"{m.Identity} lacks {string.Join(", ", check.MissingFlags)} but has no decooked graph to recompile; left unchanged");
            else if (m.ModOwned) m.FlagsToSet.UnionWith(check.MissingFlags);
            else reports.Add($"vanilla {m.Identity} lacks {string.Join(", ", check.MissingFlags)}");
        }

        Guid LiveId(string materialIdentity)
        {
            var m = materials[materialIdentity];
            return m.FlagsToSet.Count == 0 ? m.ResourceId : NewId(m);
        }

        // Variants and chain clones, keyed deterministically by (base, signature).
        var variants = new SortedDictionary<string, ParentVariantPlan>(StringComparer.Ordinal);
        var clones = new SortedDictionary<string, ChainClonePlan>(StringComparer.Ordinal);
        var retarget = new Dictionary<string, string>(StringComparer.Ordinal);
        var baseOverride = new Dictionary<string, Guid>(StringComparer.Ordinal); // instance identity -> its live base id
        foreach (var owner in instances.Values.Where(i => i.OwnedVariant != null))
        {
            string baseIdentity = owner.Chain[^1];
            var source = materials[baseIdentity];
            if (owner.Chain.Any(effectsUsers.Contains))
            {
                errors.Add($"{owner.Identity}: needs a parent variant, but its chain passes through an effects material user, which cannot be cloned");
                continue;
            }
            // Several sampler nodes can share one parameter; they decode the same effective texture.
            var defaults = owner.OwnedVariant!.GroupBy(s => s.Parameter, StringComparer.OrdinalIgnoreCase).ToList();
            if (defaults.Any(g => g.Select(s => Describe(s.Metadata)).Distinct().Count() > 1))
            {
                errors.Add($"{owner.Identity}: samplers of one parameter need different decodes");
                continue;
            }
            var identity = ParentVariantIdentity.Create(baseIdentity, LastSegment(baseIdentity), LiveId(baseIdentity),
                defaults.Select(g => (g.First().Parameter, g.First().Metadata)));
            string variantPath = "MilanMaterialVariants." + identity.ObjectName;
            variants[variantPath] = variants.TryGetValue(variantPath, out var existing)
                ? existing with { Packages = existing.Packages.Union(owner.Packages).Order(StringComparer.Ordinal).ToList() }
                : new ParentVariantPlan(variantPath, identity.ObjectName, source.Identity, source.SourcePackagePath, identity.MaterialResourceId, identity.Signature,
                    owner.OwnedVariant!, owner.Packages.ToList());

            // Ancestors between the owner and the base become clones, nearest-to-base first.
            string parent = variantPath;
            for (int i = owner.Chain.Count - 2; i >= 0; i--)
            {
                var ancestor = instances[owner.Chain[i]];
                string cloneName = ancestor.ObjectName + "_MV" + Convert.ToHexString(SHA256.HashData(
                    Encoding.UTF8.GetBytes(ancestor.Identity.ToLowerInvariant() + "\n" + identity.MaterialResourceId.ToString("D"))), 0, 4);
                string clonePath = "MilanMaterialVariants." + cloneName;
                var key = ancestor.StoredKey == null ? null : Rekey(ancestor.StoredKey, identity.MaterialResourceId, []);
                clones[clonePath] = clones.TryGetValue(clonePath, out var c)
                    ? c with { Packages = c.Packages.Union(owner.Packages).Order(StringComparer.Ordinal).ToList() }
                    : new ChainClonePlan(clonePath, cloneName, ancestor.Identity, ancestor.SourcePackagePath, parent, key, owner.Packages.ToList());
                parent = clonePath;
            }
            retarget[owner.Identity] = parent;
            baseOverride[owner.Identity] = identity.MaterialResourceId;
        }

        // Every instance's key under its live base: the nearest owner's variant, else the (possibly re-identified) base.
        var plans = new List<InstanceInstallPlan>();
        var keys = new List<StaticParameterSet>();
        var pending = new List<(InstanceRecord Record, StaticParameterSet? Key)>();
        foreach (var record in instances.Values.Where(i => i.Packages.Count > 0))
        {
            if (record.Chain.Count == 0) continue;
            Guid live = baseOverride.TryGetValue(record.Identity, out var own) ? own
                : record.Chain.Select(a => baseOverride.TryGetValue(a, out var id) ? id : (Guid?)null).FirstOrDefault(id => id != null)
                  ?? LiveId(record.Chain[^1]);
            StaticParameterSet? key = record.StoredKey != null || record.NormalFixes.Count > 0
                ? Rekey(record.StoredKey ?? MaterialInstance.Create().SM3StaticParameterSet, live, record.NormalFixes) : null;
            if (key != null) keys.Add(key);
            pending.Add((record, key));
        }
        var materialKeys = materials.Values.Where(m => m.ModOwned).Select(m => (StaticParameterSet)m.ResourceId).ToList();
        var inRef = options.KeysInRefShaderCache(keys.Concat(materialKeys).Concat(clones.Values.Where(c => c.Key != null).Select(c => c.Key!)).ToList());

        foreach (var (record, key) in pending)
        {
            bool compile = key != null && !inRef.Contains(key) && !InLocal(key, record.Packages);
            // A key that did not change and whose map already exists needs nothing: its resource stays as cooked.
            bool rewrite = compile || retarget.ContainsKey(record.Identity) || key != null && !key.Equals(record.StoredKey);
            plans.Add(new InstanceInstallPlan(record.Identity, record.Packages.ToList(), retarget.GetValueOrDefault(record.Identity),
                record.NormalFixes.ToList(), key, compile, rewrite));
        }

        var materialPlans = materials.Values.Where(m => m.Packages.Count > 0).Select(m =>
        {
            Guid? newId = m.FlagsToSet.Count > 0 ? NewId(m) : null;
            bool normalize = m.ModOwned && m.CopyIds.Values.Distinct().Count() > 1;
            var key = (StaticParameterSet)(newId ?? m.ResourceId);
            // Normalized copies may lack the chosen ID's map locally, so only the RefShaderCache spares their compile.
            bool compile = m.ModOwned && (newId != null || !(inRef.Contains(key) || (!normalize && InLocal(key, m.Packages))));
            if ((compile || normalize) && m.EmptyByDesign)
                reports.Add($"{m.Identity} is empty as shipped or authored (no connected inputs, no decooked graph or an empty shipped compile); compiled as authored");
            if ((compile || normalize) && !m.HasGraph)
                errors.Add($"{m.Identity} must be {(compile ? "compiled (its shader map is in neither the RefShaderCache nor its packages)" : "rewritten (its copies carry different resource IDs)")} but has no decooked graph (cooked copies are stripped)");
            return new MaterialInstallPlan(m.Identity, m.ModOwned, m.ResourceId, m.Packages.ToList(), m.FlagsToSet.ToList(), newId, compile, normalize);
        }).ToList();

        return new ShaderInstallPlan(materialPlans, plans, variants.Values.ToList(), clones.Values.ToList(), errors.ToList(), reports.ToList());
    }

    // Deterministic: the same material and added flags give the same ID in every package and build.
    private static Guid NewId(MaterialRecord m) => new(SHA256.HashData(Encoding.UTF8.GetBytes(
        $"{m.Identity.ToLowerInvariant()}\n{m.ResourceId:D}\n{string.Join(",", m.SetFlags.Union(m.FlagsToSet).Order(StringComparer.Ordinal))}")).AsSpan(0, 16));

    private static StaticParameterSet Rekey(StaticParameterSet stored, Guid baseId, IReadOnlyList<StaticNormalFix> fixes)
    {
        var normals = stored.NormalParameters.Select(p => new StaticParameterSet.NormalParameter
        {
            ParameterName = p.ParameterName, CompressionSettings = p.CompressionSettings, bOverride = p.bOverride, ExpressionGUID = p.ExpressionGUID
        }).ToList();
        foreach (var fix in fixes)
        {
            var existing = normals.FirstOrDefault(p => string.Equals(p.ParameterName.Instanced, fix.Parameter, StringComparison.OrdinalIgnoreCase));
            if (existing == null) normals.Add(existing = new StaticParameterSet.NormalParameter { ParameterName = fix.Parameter });
            existing.CompressionSettings = fix.CompressionSettings;
            existing.bOverride = true;
        }
        return new StaticParameterSet
        {
            BaseMaterialId = baseId,
            StaticSwitchParameters = stored.StaticSwitchParameters,
            StaticComponentMaskParameters = stored.StaticComponentMaskParameters,
            NormalParameters = normals.ToArray(),
            TerrainWeightParameters = stored.TerrainWeightParameters
        };
    }

    private static string LastSegment(string path) => path[(path.LastIndexOf('.') + 1)..];

    private static string Describe(TextureCompilationMetadata m) => $"{m.Dimension}|{m.CompressionSettings}|{m.UnpackMin}|{m.UnpackMax}";

    // Copies must agree on everything that decides shaders and resources; runtime-only parameter values may differ.
    private void CompareCopies(string identity, IEnumerable<string> packages, string hash, string fullHash, string otherHash, string otherFullHash)
    {
        if (hash != otherHash) errors.Add($"copies of {identity} differ (seen in {string.Join(", ", packages)})");
        else if (fullHash != otherFullHash) reports.Add($"copies of {identity} differ only in scalar/vector parameter values (seen in {string.Join(", ", packages)})");
    }

    private static string CopyHash(ExportEntry export, string binaryIdentity, bool shaderRelevantOnly) =>
        Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(CopyFingerprint(export, binaryIdentity, shaderRelevantOnly))));

    /// <summary>
    /// Package-independent fingerprint: object references become paths; usage flags are merged, not compared; lighting and
    /// object GUIDs are ignored. <paramref name="shaderRelevantOnly"/> also leaves out scalar and vector parameter values,
    /// which are runtime uniforms and change no shader or resource.
    /// </summary>
    public static string CopyFingerprint(ExportEntry export, string binaryIdentity, bool shaderRelevantOnly = false)
    {
        var sb = new StringBuilder(export.ClassName).Append('|').Append(binaryIdentity).Append('|');
        Append(export.GetProperties().Where(p => !shaderRelevantOnly || p.Name.Name is not ("ScalarParameterValues" or "VectorParameterValues")),
            export.FileRef, sb);
        return sb.ToString();

        static void Append(IEnumerable<Property> properties, IMEPackage package, StringBuilder sb)
        {
            foreach (var p in properties)
            {
                if (p.Name.Name?.StartsWith("bUsed", StringComparison.Ordinal) == true) continue;
                // Regenerated per copy; no effect on shaders or rendering (m_Guid feeds effects bookkeeping that cooking strips).
                if (p.Name.Name is "LightingGuid" or "ParentLightingGuid" or "m_Guid") continue;
                sb.Append(p.Name.Instanced).Append('[').Append(p.StaticArrayIndex).Append("]=");
                switch (p)
                {
                    case ObjectProperty o: sb.Append(o.Value == 0 ? "null" : package.GetEntry(o.Value)?.InstancedFullPath ?? "?"); break;
                    case StructProperty s: sb.Append('{'); Append(s.Properties, package, sb); sb.Append('}'); break;
                    case ArrayPropertyBase a: sb.Append('('); Append(a.Properties, package, sb); sb.Append(')'); break;
                    case IntProperty i: sb.Append(i.Value); break;
                    case FloatProperty f: sb.Append(f.Value.ToString("R", System.Globalization.CultureInfo.InvariantCulture)); break;
                    case BoolProperty b: sb.Append(b.Value); break;
                    case NameProperty n: sb.Append(n.Value.Instanced); break;
                    case EnumProperty e: sb.Append(e.Value.Instanced); break;
                    case ByteProperty by: sb.Append(by.Value); break;
                    case StrProperty st: sb.Append(st.Value); break;
                    default: sb.Append(p.GetType().Name); break;
                }
                sb.Append(';');
            }
        }
    }
}
