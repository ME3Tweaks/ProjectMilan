using LegendaryExplorerCore.Unreal.BinaryConverters;
using static LegendaryExplorerCore.Shaders.LE3MaterialShaderCompiler;

namespace ProjectMilanCore.Shaders.OfflineCompiler;

public enum MaterialShaderCompileStatus
{
    /// <summary>The activation gate is off. Nothing was resolved, read or compiled.</summary>
    Disabled,
    /// <summary>The request is outside what the consumer supports yet (wrong game, instances, material subclasses).</summary>
    Unsupported,
    /// <summary>The native compiler backend (SharpDX / d3dcompiler) could not be loaded. Not a material problem.</summary>
    BackendUnavailable,
    /// <summary>A phase reported errors or threw. See <see cref="MaterialShaderCompileOutcome.Phase"/>.</summary>
    Failed,
    Cancelled,
    /// <summary>Planning succeeded but selected no jobs. This is not an empty, complete shader set.</summary>
    EmptyPlan,
    /// <summary>A detached shader cache fragment was built. Says nothing about completeness or installability.</summary>
    SucceededFragment
}

public enum MaterialShaderCompilePhase
{
    ActivationGate,
    Resolution,
    SourceCapture,
    BackendCreation,
    Translation,
    Planning,
    Compilation,
    Assembly,
    Completed
}

/// <summary>One compiled job. Diagnostics are kept on success too, since they carry compiler warnings.</summary>
public sealed record ShaderJobOutcome(ShaderCompileTarget Target, bool Success, string? Diagnostics, int InstructionCount);

/// <summary>Reported before each job and after the last one. Total is the number of planned jobs.</summary>
public sealed record MaterialShaderCompileProgress(MaterialShaderCompilePhase Phase, int CompletedJobs, int TotalJobs,
    ShaderCompileTarget? CurrentTarget);

/// <summary>
/// Result of one compile request. Everything gathered up to the stopping point is kept, including
/// planner decisions and per-job diagnostics of a failed request. A successful outcome is a detached
/// fragment only: <see cref="IsCompleteShaderSet"/> is reported separately and nothing was installed.
/// </summary>
public sealed class MaterialShaderCompileOutcome
{
    public MaterialShaderCompileStatus Status { get; init; }

    /// <summary>The phase that stopped the request, or <see cref="MaterialShaderCompilePhase.Completed"/>.</summary>
    public MaterialShaderCompilePhase Phase { get; init; }

    /// <summary>The job target that failed or was about to run when the request was cancelled.</summary>
    public ShaderCompileTarget? FailedTarget { get; init; }

    public IReadOnlyList<string> Errors { get; init; } = [];

    /// <summary>Set when a phase threw instead of returning errors (bad input, I/O, callbacks, backend).</summary>
    public Exception? Exception { get; init; }

    public MaterialResolutionOutcome? Resolution { get; init; }
    public ResolvedMaterialShaderCompilation? Compilation { get; init; }
    public IReadOnlyList<ShaderCompileDecision> Decisions { get; init; } = [];
    public IReadOnlyList<ShaderCompileTarget> PlannedJobs { get; init; } = [];
    public IReadOnlyList<ShaderJobOutcome> Jobs { get; init; } = [];

    /// <summary>Texture metadata lookups made for this request, including failed ones.</summary>
    public IReadOnlyList<TextureMetadataResolution> TextureMetadata { get; init; } = [];

    /// <summary>Detached cache subset. Not installed anywhere and not proof of a complete shader set.</summary>
    public ShaderCache? Fragment { get; init; }

    /// <summary>Texture references in uniform order, as UIndexes relative to the base material's package.</summary>
    public IReadOnlyList<int> UniformExpressionTextures { get; init; } = [];

    /// <summary>The compiler's own completeness flag. Currently always false.</summary>
    public bool IsCompleteShaderSet { get; init; }

    /// <summary>The compiler's raw objects, when the LEC backend ran. Do not mutate them.</summary>
    public LE3MaterialShaderCompilerArtifacts? Artifacts { get; init; }

    public bool IsSuccess => Status == MaterialShaderCompileStatus.SucceededFragment;
}
