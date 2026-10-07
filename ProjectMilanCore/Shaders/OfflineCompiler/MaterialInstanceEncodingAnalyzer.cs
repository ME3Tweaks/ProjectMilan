using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Unreal;
using LegendaryExplorerCore.Unreal.BinaryConverters;
using LegendaryExplorerCore.Unreal.ObjectInfo;
using static LegendaryExplorerCore.Shaders.LE3MaterialShaderCompiler;

namespace ProjectMilanCore.Shaders.OfflineCompiler;

public enum TextureEncodingRequirement
{
    /// <summary>The compiled decode already matches the texture the instance samples.</summary>
    None,
    /// <summary>
    /// The sampler is a TextureSampleParameterNormal: the instance's own static normal parameter must carry
    /// the effective texture's compression. Fixable on the instance's permutation; no new parent needed.
    /// </summary>
    StaticNormalCompression,
    /// <summary>
    /// A plain texture parameter whose override differs in compile-affecting metadata from the parent's
    /// default. The parent's compile decides the decode, so a parent variant may be needed. Confirm with a
    /// translation comparison first: not every metadata difference changes the generated code.
    /// </summary>
    ParentVariantCandidate,
    /// <summary>Could not be decided; see the reason. Never treat as None.</summary>
    Unresolved
}

public sealed record TextureParameterEncodingFinding(
    string ParameterName,
    string ExpressionClass,
    string ExpressionPath,
    string? DefaultTexture,
    string? EffectiveTexture,
    string? OverriddenBy,
    TextureCompilationMetadata? DefaultMetadata,
    TextureCompilationMetadata? EffectiveMetadata,
    string? StoredNormalCompression,
    TextureEncodingRequirement Requirement,
    string Reason);

public sealed record MaterialInstanceEncodingReport(
    string Instance,
    string? BaseMaterial,
    IReadOnlyList<string> ParentChain,
    string? StaticParametersFrom,
    IReadOnlyList<TextureParameterEncodingFinding> Findings,
    IReadOnlyList<string> Errors)
{
    public bool NeedsStaticNormalChanges => Findings.Any(f => f.Requirement == TextureEncodingRequirement.StaticNormalCompression);
    public bool NeedsParentVariant => Findings.Any(f => f.Requirement == TextureEncodingRequirement.ParentVariantCandidate);

    /// <summary>False when anything could not be decided. An incomplete report must not be acted on.</summary>
    public bool IsComplete => Errors.Count == 0 && Findings.All(f => f.Requirement != TextureEncodingRequirement.Unresolved);
}

/// <summary>
/// Read-only check of whether an instance's texture overrides still match how its shaders decode them.
/// Compares the metadata the compiler itself consumes (<see cref="TextureCompilationMetadata"/>) instead
/// of a hand-made table of format classes. Changes nothing. See SHADER_COMPILER_ENCODING_PLAN.md.
/// </summary>
public static class MaterialInstanceEncodingAnalyzer
{
    private const int MaxChainLength = 64;

    /// <param name="resolveEntry">Resolves a parent reference (usually an import) to its export.</param>
    public static MaterialInstanceEncodingReport Analyze(ExportEntry instance, Func<IEntry, ExportEntry?> resolveEntry,
        ITextureCompilationMetadataProvider metadata)
    {
        ArgumentNullException.ThrowIfNull(instance);
        ArgumentNullException.ThrowIfNull(resolveEntry);
        ArgumentNullException.ThrowIfNull(metadata);
        var errors = new List<string>();
        var findings = new List<TextureParameterEncodingFinding>();
        var chain = new List<ExportEntry> { instance };

        MaterialInstanceEncodingReport Report(ExportEntry? baseMaterial = null, string? staticFrom = null) => new(
            instance.InstancedFullPath, baseMaterial?.InstancedFullPath, chain.Select(e => e.InstancedFullPath).ToArray(),
            staticFrom, findings.ToArray(), errors.ToArray());

        if (!instance.IsA("MaterialInstance"))
        {
            errors.Add($"{instance.ClassName} is not a MaterialInstance.");
            return Report();
        }

        // Parent chain up to the material that owns the graph.
        var current = instance;
        var visited = new HashSet<ExportEntry>(ReferenceEqualityComparer.Instance) { instance };
        while (current.IsA("MaterialInstance"))
        {
            var parentIndex = current.GetProperty<ObjectProperty>("Parent")?.Value ?? 0;
            var parentEntry = parentIndex == 0 ? null : current.FileRef.GetEntry(parentIndex);
            if (parentEntry == null)
            {
                errors.Add($"{current.InstancedFullPath} has no Parent.");
                return Report();
            }
            var parent = parentEntry as ExportEntry ?? resolveEntry(parentEntry);
            if (parent == null)
            {
                errors.Add($"Could not resolve parent {parentEntry.InstancedFullPath} of {current.InstancedFullPath}.");
                return Report();
            }
            if (!visited.Add(parent) || chain.Count >= MaxChainLength)
            {
                errors.Add($"Parent chain of {instance.InstancedFullPath} loops or is too long at {parent.InstancedFullPath}.");
                return Report();
            }
            chain.Add(parent);
            current = parent;
        }
        var baseMaterial = current;
        if (!baseMaterial.IsA("Material"))
        {
            errors.Add($"The chain ends at {baseMaterial.ClassName} {baseMaterial.InstancedFullPath}, not a Material.");
            return Report();
        }

        var expressions = baseMaterial.GetProperty<ArrayProperty<ObjectProperty>>("Expressions");
        if (expressions is not { Count: > 0 })
        {
            // Boot-resident cooked parents keep only parameter nodes, or none; they cannot be compiled from.
            errors.Add($"{baseMaterial.InstancedFullPath} has no expression graph. Use the decooked material, not a stripped cooked copy.");
            return Report(baseMaterial);
        }

        var instances = chain.Where(e => e.IsA("MaterialInstance")).ToArray();
        var permutationOwner = instances.FirstOrDefault(e => e.GetProperty<BoolProperty>("bHasStaticPermutationResource")?.Value == true);
        StaticParameterSet? staticSet = null;
        if (permutationOwner != null)
        {
            try
            {
                staticSet = ObjectBinary.From<MaterialInstance>(permutationOwner).SM3StaticParameterSet;
            }
            catch (Exception ex)
            {
                errors.Add($"Could not read the static parameters of {permutationOwner.InstancedFullPath}: {ex.Message}");
                return Report(baseMaterial);
            }
        }
        var compressionNames = GlobalUnrealObjectInfo.GetEnumValues(MEGame.LE3, "TextureCompressionSettings");

        foreach (var reference in expressions)
        {
            // The compiler resolves the graph from the base material's package only.
            if (baseMaterial.FileRef.GetEntry(reference.Value) is not ExportEntry expression)
            {
                if (reference.Value != 0)
                    errors.Add($"Expression {reference.Value} of {baseMaterial.InstancedFullPath} is not a local export.");
                continue;
            }
            // Plain TextureSample nodes cannot be overridden by an instance, so they always match their compile.
            if (!expression.IsA("MaterialExpressionTextureSampleParameter")) continue;
            findings.Add(AnalyzeParameter(expression, baseMaterial, instances, staticSet, compressionNames, metadata));
        }
        return Report(baseMaterial, permutationOwner?.InstancedFullPath);
    }

    private static TextureParameterEncodingFinding AnalyzeParameter(ExportEntry expression, ExportEntry baseMaterial,
        IReadOnlyList<ExportEntry> instances, StaticParameterSet? staticSet, List<NameReference>? compressionNames,
        ITextureCompilationMetadataProvider metadata)
    {
        string name = expression.GetProperty<NameProperty>("ParameterName")?.Value.Instanced ?? "";
        bool isNormal = expression.IsA("MaterialExpressionTextureSampleParameterNormal");
        var defaultEntry = baseMaterial.FileRef.GetEntry(expression.GetProperty<ObjectProperty>("Texture")?.Value ?? 0);

        TextureParameterEncodingFinding Finding(TextureEncodingRequirement requirement, string reason,
            IEntry? effective = null, string? overriddenBy = null, TextureCompilationMetadata? defaultMetadata = null,
            TextureCompilationMetadata? effectiveMetadata = null, string? stored = null) => new(
            name, expression.ClassName, expression.InstancedFullPath, defaultEntry?.InstancedFullPath,
            effective?.InstancedFullPath, overriddenBy, defaultMetadata, effectiveMetadata, stored, requirement, reason);

        if (name.Length == 0) return Finding(TextureEncodingRequirement.Unresolved, "The expression has no ParameterName.");

        // Nearest override wins, walking from the requested instance up.
        IEntry? overrideEntry = null;
        string? overriddenBy = null;
        var notes = new List<string>();
        foreach (var instance in instances)
        {
            var values = instance.GetProperty<ArrayProperty<StructProperty>>("TextureParameterValues")?
                .Where(v => string.Equals(v.GetProp<NameProperty>("ParameterName")?.Value.Instanced, name, StringComparison.OrdinalIgnoreCase))
                .ToArray() ?? [];
            if (values.Length == 0) continue;
            if (values.Length > 1)
                return Finding(TextureEncodingRequirement.Unresolved, $"{instance.InstancedFullPath} sets {name} more than once.");
            var value = values[0].GetProp<ObjectProperty>("ParameterValue");
            if (value == null)
                return Finding(TextureEncodingRequirement.Unresolved, $"{instance.InstancedFullPath} sets {name} without a ParameterValue.");
            if (value.Value == 0)
            {
                // Assumed to fall through to the parent, as LE3 constant instances appear to. Unverified.
                notes.Add($"null override in {instance.InstancedFullPath} assumed to fall through");
                continue;
            }
            overrideEntry = instance.FileRef.GetEntry(value.Value);
            if (overrideEntry == null)
                return Finding(TextureEncodingRequirement.Unresolved, $"{instance.InstancedFullPath} sets {name} to an invalid reference.");
            overriddenBy = instance.InstancedFullPath;
            break;
        }
        string Note(string reason) => notes.Count == 0 ? reason : $"{reason} ({string.Join("; ", notes)})";

        var effectiveEntry = overrideEntry ?? defaultEntry;
        if (!isNormal && overrideEntry == null)
            return Finding(TextureEncodingRequirement.None, Note("Not overridden; samples the compile-time default."), effectiveEntry);
        if (defaultEntry == null)
            return Finding(TextureEncodingRequirement.Unresolved, Note("The expression has no default texture to compare with."), effectiveEntry, overriddenBy);

        var defaultMetadata = metadata.GetMetadata(defaultEntry);
        var effectiveMetadata = effectiveEntry == null ? null : metadata.GetMetadata(effectiveEntry);
        if (defaultMetadata == null || effectiveMetadata == null)
            return Finding(TextureEncodingRequirement.Unresolved, Note("Texture metadata unavailable; see the metadata resolutions."),
                effectiveEntry, overriddenBy, defaultMetadata, effectiveMetadata);

        if (isNormal)
        {
            // The compiler binds static normal entries by first full-name match.
            var stored = staticSet?.NormalParameters?.FirstOrDefault(p =>
                string.Equals(p.ParameterName.Instanced, name, StringComparison.OrdinalIgnoreCase));
            string? storedName = null;
            if (stored != null)
            {
                if (compressionNames == null || stored.CompressionSettings >= compressionNames.Count)
                    return Finding(TextureEncodingRequirement.Unresolved, Note($"Stored normal compression {stored.CompressionSettings} has no LE3 enum name."),
                        effectiveEntry, overriddenBy, defaultMetadata, effectiveMetadata);
                storedName = compressionNames[stored.CompressionSettings].Instanced;
            }
            string decodedAs = storedName ?? defaultMetadata.CompressionSettings;
            if (!string.Equals(decodedAs, effectiveMetadata.CompressionSettings, StringComparison.OrdinalIgnoreCase))
                return Finding(TextureEncodingRequirement.StaticNormalCompression,
                    Note($"Decoded as {decodedAs} ({(storedName != null ? "static normal parameter" : "no static entry; parent default")}) but the effective texture is {effectiveMetadata.CompressionSettings}."),
                    effectiveEntry, overriddenBy, defaultMetadata, effectiveMetadata, storedName);
            if (overrideEntry != null && !SameRangeAndDimension(defaultMetadata, effectiveMetadata))
                return Finding(TextureEncodingRequirement.ParentVariantCandidate,
                    Note("Compression matches, but dimension or unpack range differs from the parent's default."),
                    effectiveEntry, overriddenBy, defaultMetadata, effectiveMetadata, storedName);
            return Finding(TextureEncodingRequirement.None, Note("Static normal compression matches the effective texture."),
                effectiveEntry, overriddenBy, defaultMetadata, effectiveMetadata, storedName);
        }

        if (SameCompileMetadata(defaultMetadata, effectiveMetadata))
            return Finding(TextureEncodingRequirement.None, Note("Override has the same compile-affecting metadata as the default."),
                effectiveEntry, overriddenBy, defaultMetadata, effectiveMetadata);
        return Finding(TextureEncodingRequirement.ParentVariantCandidate,
            Note($"Parent compiled against {Describe(defaultMetadata)}; override is {Describe(effectiveMetadata)}."),
            effectiveEntry, overriddenBy, defaultMetadata, effectiveMetadata);
    }

    public static bool SameCompileMetadata(TextureCompilationMetadata a, TextureCompilationMetadata b)
        => string.Equals(a.CompressionSettings, b.CompressionSettings, StringComparison.OrdinalIgnoreCase) && SameRangeAndDimension(a, b);

    private static bool SameRangeAndDimension(TextureCompilationMetadata a, TextureCompilationMetadata b)
        => a.Dimension == b.Dimension && a.UnpackMin == b.UnpackMin && a.UnpackMax == b.UnpackMax;

    private static string Describe(TextureCompilationMetadata m) => $"{m.Dimension} {m.CompressionSettings} unpack {m.UnpackMin}..{m.UnpackMax}";
}
