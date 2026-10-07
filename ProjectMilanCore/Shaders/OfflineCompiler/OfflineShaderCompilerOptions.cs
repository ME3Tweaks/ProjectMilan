namespace ProjectMilanCore.Shaders.OfflineCompiler;

/// <summary>
/// Activation gate for the offline LE3 material shader compiler. Off by default: the compiler does not
/// yet produce a complete or runtime-validated shader set. Turning compilation on does not permit
/// installing its output into packages; installation is a separate boundary that does not exist yet.
/// </summary>
public sealed record OfflineShaderCompilerOptions
{
    /// <summary>The production setting. Every compile request returns <see cref="MaterialShaderCompileStatus.Disabled"/>.</summary>
    public static OfflineShaderCompilerOptions Production { get; } = new();

    /// <summary>
    /// When false, requests stop at the gate before resolving the material, capturing shader sources,
    /// reading texture metadata or touching the compiler. Only tests and explicitly invoked offline
    /// harnesses should set this.
    /// </summary>
    public bool CompilationEnabled { get; init; }
}
