using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Shaders;
using LegendaryExplorerCore.Unreal.BinaryConverters;
using static LegendaryExplorerCore.Shaders.LE3MaterialShaderCompiler;

namespace ProjectMilanCore.Shaders.OfflineCompiler;

/// <summary>
/// Seam between the request orchestration and the compiler. <see cref="LE3MaterialShaderCompilerBackend"/>
/// is the only real implementation; tests substitute their own to exercise every outcome without a game
/// installation or the native compiler. The compiler's own result types cannot be constructed outside LEC,
/// so sessions report through the records below.
/// </summary>
public interface IMaterialShaderCompilerBackend
{
    /// <exception cref="ShaderCompilerBackendUnavailableException">The native backend cannot be used.</exception>
    IMaterialShaderCompileSession CreateSession(MaterialShaderCompileSessionContext context);
}

/// <summary>
/// One request's compiler state. Phases are called in order, each at most once, and
/// <see cref="Compile"/> once per planned job index. Not thread-safe.
/// </summary>
public interface IMaterialShaderCompileSession
{
    TranslationPhaseResult Translate();
    PlanningPhaseResult Plan();
    ShaderJobOutcome Compile(int jobIndex);
    AssemblyPhaseResult Assemble();

    /// <summary>The compiler's raw objects so far, or null for a backend that has none.</summary>
    LE3MaterialShaderCompilerArtifacts? Artifacts { get; }
}

public sealed record MaterialShaderCompileSessionContext(
    ResolvedMaterialShaderCompilation Compilation,
    LE3ShaderSourceSnapshot Sources,
    Func<IEntry, TextureCompilationMetadata?> TextureMetadata,
    bool ResourceForcesFloatUsage,
    ShouldCacheEnvironmentContext? EnvironmentContext,
    Func<ResolvedMaterialCompilationInput, ShaderCompileTarget, bool?>? MaterialResourceShouldCache);

public sealed record TranslationPhaseResult(bool Success, IReadOnlyList<string> Errors);

public sealed record PlanningPhaseResult(bool Success, IReadOnlyList<string> Errors,
    IReadOnlyList<ShaderCompileTarget> Jobs, IReadOnlyList<ShaderCompileDecision> Decisions);

public sealed record AssemblyPhaseResult(bool Success, IReadOnlyList<string> Errors, ShaderCache? Cache,
    IReadOnlyList<int> UniformExpressionTextures, bool IsCompleteShaderSet);

/// <summary>The compiler's own result objects from one request, in the order they were produced.</summary>
public sealed record LE3MaterialShaderCompilerArtifacts(
    TranslationResult? Translation,
    ShaderCompilePlan? Plan,
    IReadOnlyList<ShaderCompilationResult> CompiledShaders,
    ShaderCacheFragmentResult? Fragment);

/// <summary>The native compiler (SharpDX.D3DCompiler / d3dcompiler_47) is missing or failed to load.</summary>
public sealed class ShaderCompilerBackendUnavailableException(string message, Exception? innerException = null)
    : Exception(message, innerException);
