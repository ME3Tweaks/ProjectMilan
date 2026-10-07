using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Unreal.ObjectInfo;
using LegendaryExplorerCore.Unreal.BinaryConverters;
using static LegendaryExplorerCore.Shaders.LE3MaterialShaderCompiler;

namespace ProjectMilanCore.Shaders.OfflineCompiler;

/// <summary>
/// Everything the compiler needs for one shader map. <paramref name="MaterialResourceId"/> is the map's
/// resource identity and is deliberately separate from the static key's BaseMaterialId.
/// </summary>
public sealed record ResolvedMaterialShaderCompilation(
    ResolvedMaterialCompilationInput Input,
    MaterialResource Resource,
    Guid MaterialResourceId,
    string FriendlyName);

public enum MaterialResolutionStatus
{
    Resolved,
    Unsupported,
    Failed
}

public sealed record MaterialResolutionOutcome(
    MaterialResolutionStatus Status,
    ResolvedMaterialShaderCompilation? Compilation,
    IReadOnlyList<string> Reasons,
    MaterialInstanceEncodingReport? InstanceEncoding = null)
{
    public static MaterialResolutionOutcome Unsupported(string reason, MaterialInstanceEncodingReport? instanceEncoding = null)
        => new(MaterialResolutionStatus.Unsupported, null, [reason], instanceEncoding);

    public static MaterialResolutionOutcome Failed(string reason) => new(MaterialResolutionStatus.Failed, null, [reason]);
}

/// <summary>
/// Turns a requested export into compiler input. Kept apart from compilation so instance resolution can
/// be added later without the orchestration changing.
/// </summary>
public interface IMaterialCompilationResolver
{
    MaterialResolutionOutcome Resolve(MaterialShaderCompileRequest request);
}

/// <summary>
/// Resolves ordinary LE3 base Materials. MaterialInstances are reported as unsupported, with a read-only
/// texture encoding analysis attached when a parent resolver is supplied; they are never compiled as their
/// parent's defaults. Material subclasses (DecalMaterial and others) are not handled yet.
/// </summary>
public sealed class MaterialCompilationResolver(Func<IEntry, ExportEntry?>? resolveEntry = null) : IMaterialCompilationResolver
{
    public MaterialResolutionOutcome Resolve(MaterialShaderCompileRequest request)
    {
        ArgumentNullException.ThrowIfNull(request);
        var requested = request.Material;
        if (requested.Game != MEGame.LE3)
            return MaterialResolutionOutcome.Unsupported($"Only LE3 is supported; {requested.InstancedFullPath} is from {requested.Game}.");
        if (requested.IsDefaultObject)
            return MaterialResolutionOutcome.Unsupported($"{requested.InstancedFullPath} is a class default object.");

        if (requested.IsA("MaterialInstance"))
        {
            var analysis = resolveEntry == null ? null
                : MaterialInstanceEncodingAnalyzer.Analyze(requested, resolveEntry, request.TextureMetadata);
            return MaterialResolutionOutcome.Unsupported(
                $"MaterialInstance compilation is not implemented yet: {requested.InstancedFullPath}. " +
                "Its parent chain, merged static parameters and texture encodings must be resolved first.", analysis);
        }

        if (requested.ClassName != "Material")
            return MaterialResolutionOutcome.Unsupported($"{requested.ClassName} is not supported yet; only ordinary Materials are: {requested.InstancedFullPath}.");

        MaterialResource resource;
        try
        {
            resource = ObjectBinary.From<Material>(requested).SM3MaterialResource;
        }
        catch (Exception ex)
        {
            return MaterialResolutionOutcome.Failed($"Could not read the material resource of {requested.InstancedFullPath}: {ex.Message}");
        }
        if (resource == null || resource.ID == Guid.Empty)
            return MaterialResolutionOutcome.Failed($"{requested.InstancedFullPath} has no material resource ID.");

        // The object name is assumed to be the native friendly name. Confirm against shipping shader
        // maps before any installation path relies on it.
        var compilation = new ResolvedMaterialShaderCompilation(new ResolvedMaterialCompilationInput(requested),
            resource, resource.ID, requested.ObjectName.Instanced);
        return new(MaterialResolutionStatus.Resolved, compilation, []);
    }
}
