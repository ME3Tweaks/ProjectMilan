using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Packages.CloningImportingAndRelinking;
using LegendaryExplorerCore.Unreal;
using LegendaryExplorerCore.Unreal.BinaryConverters;

namespace ShaderResearchTool;

/// <summary>
/// Looks up objects in the shipping game by instanced full path, using the prebuilt
/// ObjectInstanceDB rather than scanning all ~9400 cooked packages.
///
/// Lookups are resolved in two grouped phases (materials, then the textures they bind) so each
/// shipping package is opened at most once per phase and never held open afterwards.
/// </summary>
public sealed class ShippingMaterialResolver
{
    private readonly ObjectInstanceDB _db;
    private readonly string _gameRoot;

    private ShippingMaterialResolver(ObjectInstanceDB db, string gameRoot)
    {
        _db = db;
        _gameRoot = gameRoot;
    }

    public static ShippingMaterialResolver Load(string objectDbPath, string gameRoot)
    {
        using var fs = File.OpenRead(objectDbPath);
        var db = ObjectInstanceDB.Deserialize(MEGame.LE3, fs);
        return new ShippingMaterialResolver(db, gameRoot);
    }

    /// <summary>Absolute path of the first existing package containing <paramref name="ifp"/>, or null.</summary>
    private string? FirstFileContaining(string ifp)
    {
        var relatives = _db.GetFilesContainingObject(ifp);
        if (relatives == null) return null;

        foreach (var relative in relatives)
        {
            var full = Path.Combine(_gameRoot, relative);
            if (File.Exists(full)) return full;
        }
        return null;
    }

    /// <summary>
    /// Resolves texture bindings for each requested material path. Materials absent from the
    /// shipping game are simply missing from the result.
    /// </summary>
    public Dictionary<string, MaterialTextureBindings> GetMaterials(
        IReadOnlyCollection<string> materialPaths, Action<string>? log = null)
    {
        var byFile = GroupByContainingFile(materialPaths, out int unresolved);
        log?.Invoke($"  {materialPaths.Count} materials -> {byFile.Count} shipping packages ({unresolved} not in game)");

        var result = new Dictionary<string, MaterialTextureBindings>(StringComparer.OrdinalIgnoreCase);
        int done = 0;

        foreach (var (file, wanted) in byFile)
        {
            done++;
            if (log != null && done % 250 == 0) log($"  opened {done}/{byFile.Count} packages");

            ForEachExport(file, wanted, (export, pkg) =>
            {
                var bindings = ExtractBindings(export, pkg, file);
                if (bindings != null) result[export.InstancedFullPath] = bindings;
            });
        }

        return result;
    }

    /// <summary>Pixel format of each requested texture path, for those present in the shipping game.</summary>
    public Dictionary<string, string> GetTextureFormats(
        IReadOnlyCollection<string> texturePaths, Action<string>? log = null)
    {
        var byFile = GroupByContainingFile(texturePaths, out int unresolved);
        log?.Invoke($"  {texturePaths.Count} textures -> {byFile.Count} shipping packages ({unresolved} not in game)");

        var result = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
        int done = 0;

        foreach (var (file, wanted) in byFile)
        {
            done++;
            if (log != null && done % 250 == 0) log($"  opened {done}/{byFile.Count} packages");

            ForEachExport(file, wanted, (export, _) =>
            {
                var format = export.GetProperty<EnumProperty>("Format")?.Value.Name;
                if (format != null) result[export.InstancedFullPath] = format;
            });
        }

        return result;
    }

    private Dictionary<string, HashSet<string>> GroupByContainingFile(
        IReadOnlyCollection<string> paths, out int unresolved)
    {
        var byFile = new Dictionary<string, HashSet<string>>(StringComparer.OrdinalIgnoreCase);
        unresolved = 0;

        foreach (var ifp in paths)
        {
            if (ifp.Length == 0) continue;
            var file = FirstFileContaining(ifp);
            if (file == null)
            {
                unresolved++;
                continue;
            }

            if (!byFile.TryGetValue(file, out var set))
            {
                set = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
                byFile[file] = set;
            }
            set.Add(ifp);
        }

        return byFile;
    }

    private static void ForEachExport(string file, HashSet<string> wantedPaths, Action<ExportEntry, IMEPackage> action)
    {
        IMEPackage? pkg = null;
        try
        {
            pkg = MEPackageHandler.OpenMEPackage(file);
        }
        catch
        {
            return; // Unreadable shipping package; treated the same as a missing object.
        }

        try
        {
            foreach (var export in pkg.Exports)
            {
                if (!wantedPaths.Contains(export.InstancedFullPath)) continue;
                action(export, pkg);
            }
        }
        finally
        {
            pkg.Dispose();
        }
    }

    private static MaterialTextureBindings? ExtractBindings(ExportEntry export, IMEPackage pkg, string file)
    {
        var className = export.ClassName;
        // Material only — see PackageObjectIndex.MaterialClasses.
        if (!className.Equals("Material", StringComparison.OrdinalIgnoreCase)) return null;

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
                bindings.Textures.Add(pkg.GetEntry(uIndex)?.InstancedFullPath ?? "");
            }
        }
        catch (Exception ex)
        {
            bindings.Error = ex.Message;
        }

        return bindings;
    }
}
