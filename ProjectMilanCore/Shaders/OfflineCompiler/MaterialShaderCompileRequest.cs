using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Shaders;
using static LegendaryExplorerCore.Shaders.LE3MaterialShaderCompiler;

namespace ProjectMilanCore.Shaders.OfflineCompiler;

/// <summary>
/// One material to compile. Constructing a request reads nothing: the material is resolved, sources
/// are captured and texture metadata is read only after the activation gate has passed.
/// </summary>
public sealed class MaterialShaderCompileRequest
{
    public MaterialShaderCompileRequest(ExportEntry material, LE3ShaderSourceSession sources,
        ITextureCompilationMetadataProvider textureMetadata)
    {
        Material = material ?? throw new ArgumentNullException(nameof(material));
        Sources = sources ?? throw new ArgumentNullException(nameof(sources));
        TextureMetadata = textureMetadata ?? throw new ArgumentNullException(nameof(textureMetadata));
    }

    /// <summary>The requested Material or MaterialInstance. The caller keeps its package alive and unchanged for the request.</summary>
    public ExportEntry Material { get; }

    public LE3ShaderSourceSession Sources { get; }

    public ITextureCompilationMetadataProvider TextureMetadata { get; }

    /// <summary>Resource-local precision requirement passed to translation. SM5 never uses the half-type path.</summary>
    public bool ResourceForcesFloatUsage { get; init; }

    /// <summary>Optional planning environment. Ordinary materials use the planner defaults.</summary>
    public ShouldCacheEnvironmentContext? EnvironmentContext { get; init; }

    /// <summary>
    /// Optional evidence-backed resource ShouldCache hook. Return null for unknown; never turn unknown into true.
    /// </summary>
    public Func<ResolvedMaterialCompilationInput, ShaderCompileTarget, bool?>? MaterialResourceShouldCache { get; init; }
}

/// <summary>
/// Hands out one immutable <see cref="LE3ShaderSourceSnapshot"/>, captured on first use. Every phase of
/// every request using this session gets the same object, which the compiler requires. A failed capture
/// is not cached, so a later request retries it. Create a new session to pick up changed sources.
/// </summary>
public sealed class LE3ShaderSourceSession
{
    private readonly Func<LE3ShaderSourceSnapshot> capture;
    private readonly object captureLock = new();
    private LE3ShaderSourceSnapshot? snapshot;

    private LE3ShaderSourceSession(Func<LE3ShaderSourceSnapshot> capture) => this.capture = capture;

    /// <summary>
    /// Captures the installed game's .usf files on first use. Pass the Windows ANSI code page used to decode
    /// untagged text explicitly (1252 is the tested setting, not a guarantee). The sources belong to the
    /// game installation and must not be shipped.
    /// </summary>
    public static LE3ShaderSourceSession FromDirectory(string shaderDirectory, int windowsAnsiCodePage)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(shaderDirectory);
        return new(() => LE3ShaderSourceSnapshot.FromDirectory(shaderDirectory, windowsAnsiCodePage));
    }

    public static LE3ShaderSourceSession FromSnapshot(LE3ShaderSourceSnapshot snapshot)
    {
        ArgumentNullException.ThrowIfNull(snapshot);
        return new(() => snapshot);
    }

    public bool IsCaptured
    {
        get { lock (captureLock) return snapshot != null; }
    }

    public LE3ShaderSourceSnapshot GetSnapshot()
    {
        lock (captureLock)
        {
            return snapshot ??= capture() ?? throw new InvalidOperationException("Shader source capture returned no snapshot.");
        }
    }
}
