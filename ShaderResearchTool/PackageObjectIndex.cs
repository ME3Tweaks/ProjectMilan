using System.Text.Json;
using System.Text.Json.Serialization;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Unreal;
using LegendaryExplorerCore.Unreal.BinaryConverters;

namespace ShaderResearchTool;

/// <summary>
/// A single material's ordered texture bindings, as recorded in its compiled MaterialResource.
/// Order is significant: it is the sampler binding order that the generated Material.usf is built
/// against, so slot N here corresponds to slot N in the other package set.
/// </summary>
public sealed class MaterialTextureBindings
{
    public string MaterialPath { get; set; } = "";
    public string SourceFile { get; set; } = "";
    public string ClassName { get; set; } = "";

    /// <summary>
    /// Instanced full paths of UniformExpressionTextures, in binding order.
    /// An empty string means the UIndex did not resolve to an entry in the package.
    /// </summary>
    public List<string> Textures { get; set; } = [];

    /// <summary>Set when the MaterialResource could not be deserialized.</summary>
    public string? Error { get; set; }
}

/// <summary>
/// Index of one package set (the decooked rebuild, or the shipping game): every material's
/// texture bindings plus every texture object's pixel format.
///
/// Built in a single pass and cached to disk, because a full scan of either set takes minutes.
/// Texture identity is resolved by instanced path rather than by following imports across
/// packages, which keeps the scan to one open per file.
/// </summary>
public sealed class PackageObjectIndex
{
    /// <summary>Materials and material instances, keyed by instanced full path.</summary>
    public Dictionary<string, MaterialTextureBindings> Materials { get; set; } = new(StringComparer.OrdinalIgnoreCase);

    /// <summary>Pixel format (e.g. PF_DXT1, PF_BC5) of every texture object, keyed by instanced full path.</summary>
    public Dictionary<string, string> TextureFormats { get; set; } = new(StringComparer.OrdinalIgnoreCase);

    /// <summary>Files that failed to open at all.</summary>
    public List<string> FailedFiles { get; set; } = [];

    // Material only. Milan strips the StaticPermutationResource from MaterialInstanceConstants and
    // lets the game rebuild it at runtime, so instances are out of scope for shader calibration.
    private static readonly HashSet<string> MaterialClasses = new(StringComparer.OrdinalIgnoreCase)
    {
        "Material"
    };

    private static readonly HashSet<string> TextureClasses = new(StringComparer.OrdinalIgnoreCase)
    {
        "Texture2D", "TextureCube", "TextureMovie", "TextureFlipBook",
        "LightMapTexture2D", "ShadowMapTexture2D", "TerrainWeightMapTexture", "TextureRenderTarget2D"
    };

    public static PackageObjectIndex Build(IReadOnlyList<string> packageFiles, Action<string>? log = null)
    {
        var index = new PackageObjectIndex();
        int done = 0;

        foreach (var file in packageFiles)
        {
            done++;
            if (log != null && (done % 100 == 0 || done == packageFiles.Count))
            {
                log($"  scanned {done}/{packageFiles.Count} packages");
            }

            IMEPackage? pkg = null;
            try
            {
                pkg = MEPackageHandler.OpenMEPackage(file);
            }
            catch (Exception ex)
            {
                index.FailedFiles.Add($"{file}: {ex.Message}");
                continue;
            }

            try
            {
                foreach (var export in pkg.Exports)
                {
                    var className = export.ClassName;

                    if (TextureClasses.Contains(className))
                    {
                        var format = export.GetProperty<EnumProperty>("Format")?.Value.Name;
                        if (format != null)
                        {
                            // Later sets win; duplicates across a decooked set should not exist by construction.
                            index.TextureFormats[export.InstancedFullPath] = format;
                        }
                        continue;
                    }

                    if (!MaterialClasses.Contains(className)) continue;

                    var bindings = new MaterialTextureBindings
                    {
                        MaterialPath = export.InstancedFullPath,
                        SourceFile = Path.GetFileName(file),
                        ClassName = className
                    };

                    try
                    {
                        var resource = ObjectBinary.From<Material>(export).SM3MaterialResource;

                        foreach (var uIndex in resource.UniformExpressionTextures)
                        {
                            var entry = pkg.GetEntry(uIndex);
                            bindings.Textures.Add(entry?.InstancedFullPath ?? "");
                        }
                    }
                    catch (Exception ex)
                    {
                        bindings.Error = ex.Message;
                    }

                    index.Materials[bindings.MaterialPath] = bindings;
                }
            }
            finally
            {
                pkg.Dispose();
            }
        }

        return index;
    }

    private static readonly JsonSerializerOptions JsonOpts = new()
    {
        WriteIndented = false,
        DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull
    };

    public void Save(string path)
    {
        Directory.CreateDirectory(Path.GetDirectoryName(path)!);
        using var fs = File.Create(path);
        JsonSerializer.Serialize(fs, this, JsonOpts);
    }

    public static PackageObjectIndex? Load(string path)
    {
        if (!File.Exists(path)) return null;
        using var fs = File.OpenRead(path);
        return JsonSerializer.Deserialize<PackageObjectIndex>(fs, JsonOpts);
    }

    /// <summary>Format of a bound texture, or null when the texture is not present in this set.</summary>
    public string? FormatOf(string texturePath) =>
        texturePath.Length > 0 && TextureFormats.TryGetValue(texturePath, out var f) ? f : null;
}
