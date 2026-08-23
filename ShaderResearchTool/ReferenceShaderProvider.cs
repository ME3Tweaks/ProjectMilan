using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Packages.CloningImportingAndRelinking;
using LegendaryExplorerCore.Shaders;
using LegendaryExplorerCore.Unreal;
using LegendaryExplorerCore.Unreal.BinaryConverters;

namespace ShaderResearchTool;

/// <summary>One shipping shader: the compiled bytecode LE3 actually ships for a material permutation.</summary>
public sealed class ReferenceShader
{
    public string VertexFactory { get; init; } = "";
    public string ShaderType { get; init; } = "";
    public Guid Id { get; init; }
    public byte[] ByteCode { get; init; } = [];
    /// <summary>Where the bytecode came from: the package's own ShaderCache, or RefShaderCache.</summary>
    public string Source { get; init; } = "";
}

/// <summary>Every shipping shader for one material, keyed by (vertex factory, shader type).</summary>
public sealed class ReferenceShaderSet
{
    public string MaterialPath { get; init; } = "";
    public string ShippingFile { get; init; } = "";
    public Dictionary<(string vf, string type), ReferenceShader> Shaders { get; } = [];
    public string? Error { get; init; }

    /// <summary>
    /// The material-level properties that drive per-material macros (blend mode, lighting model,
    /// two-sided, decal usage). Shader-type coverage does not imply coverage of these, so the
    /// capture plan has to span them as a second axis.
    /// </summary>
    public string FlagSignature { get; set; } = "";

    /// <summary>Vertex factory name used for shaders that are not mesh-material shaders.</summary>
    public const string NoVertexFactory = "None";
}

/// <summary>
/// Resolves the shipping LE3 bytecode for a material's shader permutations.
///
/// A material's shader map lives either in its own package's ShaderCache export or in the global
/// RefShaderCache, keyed by the material's StaticParameterSet. Both are checked, local first.
/// </summary>
public sealed class ReferenceShaderProvider
{
    private readonly ObjectInstanceDB _db;
    private readonly string _gameRoot;

    // Single-entry cache. Callers that process materials grouped by containing file get all the
    // benefit of a full cache without holding thousands of packages alive.
    private string? _cachedFile;
    private IMEPackage? _cachedPackage;
    private ShaderCache? _cachedShaderCache;

    public ReferenceShaderProvider(ObjectInstanceDB db, string gameRoot)
    {
        _db = db;
        _gameRoot = gameRoot;
    }

    public static ReferenceShaderProvider Load(string objectDbPath, string gameRoot)
    {
        using var fs = File.OpenRead(objectDbPath);
        return new ReferenceShaderProvider(ObjectInstanceDB.Deserialize(MEGame.LE3, fs), gameRoot);
    }

    /// <summary>Files in the shipping game containing this object, most preferred first.</summary>
    public List<string> FilesContaining(string ifp)
    {
        var relatives = _db.GetFilesContainingObject(ifp);
        if (relatives == null) return [];

        var result = new List<string>();
        foreach (var relative in relatives)
        {
            var full = Path.Combine(_gameRoot, relative);
            if (File.Exists(full)) result.Add(full);
        }
        return result;
    }

    /// <summary>
    /// Resolves against the first candidate path that exists in the shipping game. ShaderClient
    /// records materials without their root package prefix, so the caller supplies both the
    /// prefixed and bare forms.
    /// </summary>
    public ReferenceShaderSet GetShaders(IReadOnlyList<string> candidateIfps)
    {
        ReferenceShaderSet? last = null;
        foreach (var candidate in candidateIfps)
        {
            var set = GetShaders(candidate);
            if (set.Shaders.Count > 0) return set;
            last ??= set;
        }
        return last ?? new ReferenceShaderSet { Error = "no candidate paths supplied" };
    }

    public ReferenceShaderSet GetShaders(string materialIfp)
    {
        var files = FilesContaining(materialIfp);
        if (files.Count == 0)
        {
            return new ReferenceShaderSet { MaterialPath = materialIfp, Error = "material not found in shipping game" };
        }

        foreach (var file in files)
        {
            var set = TryGetFromFile(file, materialIfp);
            if (set is { Shaders.Count: > 0 }) return set;
        }

        return new ReferenceShaderSet
        {
            MaterialPath = materialIfp,
            ShippingFile = Path.GetFileName(files[0]),
            Error = "no shader map found for material's static parameter set"
        };
    }

    /// <summary>Releases the cached package. Call when moving off a file for good.</summary>
    public void ReleaseCache()
    {
        _cachedPackage?.Dispose();
        _cachedPackage = null;
        _cachedShaderCache = null;
        _cachedFile = null;
    }

    private IMEPackage? OpenCached(string file)
    {
        if (_cachedFile == file && _cachedPackage != null) return _cachedPackage;

        ReleaseCache();
        try
        {
            _cachedPackage = MEPackageHandler.OpenMEPackage(file);
            _cachedFile = file;
            return _cachedPackage;
        }
        catch
        {
            return null;
        }
    }

    private ReferenceShaderSet? TryGetFromFile(string file, string materialIfp)
    {
        var pkg = OpenCached(file);
        if (pkg == null) return null;

        {
            var export = pkg.Exports.FirstOrDefault(e =>
                e.ClassName.Equals("Material", StringComparison.OrdinalIgnoreCase) &&
                e.InstancedFullPath.Equals(materialIfp, StringComparison.OrdinalIgnoreCase));
            if (export == null) return null;

            StaticParameterSet staticParams;
            try
            {
                // A base Material has no static switches, so its shader map is keyed by a
                // StaticParameterSet carrying only the MaterialResource's ID.
                staticParams = (StaticParameterSet)ObjectBinary.From<Material>(export).SM3MaterialResource.ID;
            }
            catch (Exception ex)
            {
                return new ReferenceShaderSet { MaterialPath = materialIfp, ShippingFile = Path.GetFileName(file), Error = ex.Message };
            }

            var set = new ReferenceShaderSet
            {
                MaterialPath = materialIfp,
                ShippingFile = Path.GetFileName(file),
                FlagSignature = BuildFlagSignature(export)
            };

            // Local ShaderCache in the material's own package takes precedence over the global one.
            var localCacheExport = pkg.Exports.FirstOrDefault(e =>
                e.ClassName.Equals("ShaderCache", StringComparison.OrdinalIgnoreCase));

            if (localCacheExport != null)
            {
                try
                {
                    // Parsing a package's ShaderCache is expensive, so keep it with the package.
                    var cache = _cachedShaderCache ??= ObjectBinary.From<ShaderCache>(localCacheExport);
                    if (cache.MaterialShaderMaps.TryGetValue(staticParams, out var localMap))
                    {
                        Populate(set, localMap, guid => cache.Shaders.TryGetValue(guid, out var s) ? s.ShaderByteCode : null, "local");
                        if (set.Shaders.Count > 0) return set;
                    }
                }
                catch
                {
                    // Fall through to the global cache.
                }
            }

            var refMap = RefShaderCacheReader.GetMaterialShaderMap(MEGame.LE3, staticParams, out _, _gameRoot);
            if (refMap != null)
            {
                Populate(set, refMap, guid => RefShaderCacheReader.GetShaderBytecode(MEGame.LE3, guid), "ref");
            }

            return set;
        }
    }

    /// <summary>
    /// Mirrors the material-driven half of ShaderClient's AddCustomMacros: blend mode and lighting
    /// model each select a MATERIALBLENDING_*/MATERIAL_LIGHTINGMODEL_* macro, and the booleans gate
    /// MATERIAL_TWOSIDED / MATERIAL_DECAL and friends. Defaults match UMaterial's own defaults.
    /// </summary>
    private static string BuildFlagSignature(ExportEntry export)
    {
        string Enum(string name, string fallback) =>
            export.GetProperty<EnumProperty>(name)?.Value.Name ?? fallback;

        bool Bool(string name) => export.GetProperty<BoolProperty>(name)?.Value ?? false;

        var parts = new List<string>
        {
            Enum("BlendMode", "BLEND_Opaque"),
            Enum("LightingModel", "MLM_Phong")
        };

        foreach (var flag in new[]
                 {
                     "TwoSided", "bUsedWithDecals", "bUsedWithSkeletalMesh", "bUsedWithFoliage",
                     "bUsedWithSpeedTree", "bUsedWithParticleSystem", "bUsedWithTerrain",
                     "bUsedWithFracturedMeshes", "bUsedWithSimpleLightMaps", "bUsedWithVectorLightMaps",
                     "bUsedAsLightFunction", "Wireframe"
                 })
        {
            if (Bool(flag)) parts.Add(flag);
        }

        return string.Join(",", parts);
    }

    private static void Populate(
        ReferenceShaderSet set,
        MaterialShaderMap map,
        Func<Guid, byte[]?> bytecodeLookup,
        string source)
    {
        // Material shaders (no vertex factory).
        foreach (var (typeName, shaderRef) in map.Shaders)
        {
            Add(set, ReferenceShaderSet.NoVertexFactory, typeName.Name, shaderRef.Id, bytecodeLookup, source);
        }

        // Mesh material shaders, one group per vertex factory.
        foreach (var meshMap in map.MeshShaderMaps)
        {
            var vf = meshMap.VertexFactoryType.Name;
            foreach (var (typeName, shaderRef) in meshMap.Shaders)
            {
                Add(set, vf, typeName.Name, shaderRef.Id, bytecodeLookup, source);
            }
        }
    }

    private static void Add(
        ReferenceShaderSet set,
        string vf,
        string shaderType,
        Guid id,
        Func<Guid, byte[]?> bytecodeLookup,
        string source)
    {
        var key = (vf, shaderType);
        if (set.Shaders.ContainsKey(key)) return;

        byte[]? code;
        try
        {
            code = bytecodeLookup(id);
        }
        catch
        {
            code = null;
        }
        if (code is not { Length: > 0 }) return;

        set.Shaders[key] = new ReferenceShader
        {
            VertexFactory = vf,
            ShaderType = shaderType,
            Id = id,
            ByteCode = code,
            Source = source
        };
    }
}
