using System.Text.Json;
using LegendaryExplorerCore.Packages;
using ProjectMilanCore;
using ProjectMilanCore.Shaders.OfflineCompiler;

namespace ProjectMilan.Pipelines.Shaders;

/// <summary>Repairs material controllers after shader installation has split their instance chains.</summary>
public static class PostShaderPipeline
{
    /// <summary>
    /// Used for rehydrating from checkpoints.
    /// </summary>
    internal const string CloneManifestName = "MilanShaderClones.json";
    private const string LogCategory = "MILAN-PostShaders";

    public static void RunPipeline()
    {
        string root = Program.Settings.OutputModPath;
        var files = Directory.GetFiles(root, "*.pcc", SearchOption.AllDirectories).Order(StringComparer.OrdinalIgnoreCase).ToArray();
        string manifest = Path.Combine(root, CloneManifestName);
        if (!File.Exists(manifest))
        {
            foreach (var file in files)
            {
                using var package = MEPackageHandler.UnsafePartialLoad(file, _ => false);
                if (package.Exports.Any(e => e.InstancedFullPath.StartsWith(OfflineShaderInstaller.VariantRoot + ".", StringComparison.Ordinal)))
                    throw new InvalidDataException("Shader clone manifest is missing. Re-run Shaders or retake the Shaders checkpoint.");
            }
            return;
        }
        var bindings = JsonSerializer.Deserialize<List<MaterialCloneBinding>>(File.ReadAllText(manifest))
            ?? throw new InvalidDataException("Shader clone manifest is empty.");
        if (bindings.Count == 0)
        {
            // Nothing to do
            return;
        }

        var bySource = bindings.GroupBy(b => b.SourceIdentity, StringComparer.OrdinalIgnoreCase)
        .ToDictionary(g => g.Key, g => g.DistinctBy(b => b.CloneIdentity).ToArray(), StringComparer.OrdinalIgnoreCase);

        // Don't get too fat
        using var cache = new PackageCache { CacheMaxSize = 20 };


        IReadOnlyList<ExportEntry> FindClones(string identity) => bySource.TryGetValue(identity, out var clones)
            ? clones.Select(c => cache.GetCachedPackage(Path.Combine(root, c.PackagePath)).FindExport(c.CloneIdentity)
                ?? throw new InvalidDataException($"Missing shader clone {c.CloneIdentity} in {c.PackagePath}.")).ToArray()
            : [];

        int total = 0;
        foreach (var file in files)
        {
            using (var header = MEPackageHandler.UnsafePartialLoad(file, _ => false))
            {
                if (!header.Exports.Any(e => e.ClassName == "MaterialInstanceActor" && !e.IsDefaultObject))
                {
                    continue;
                }
                using var package = MEPackageHandler.OpenMEPackage(file, forceLoadFromDisk: true);
                int count = MatineeMaterialCloneRepair.Repair(package, FindClones, cache);
                if (count == 0)
                {
                    continue;
                }
                package.Save();
                total += count;
                MilanLog.Information($"{package.FileNameNoExtension}: added {count} material bindings", customPrefix: LogCategory);
            }
        }
        MilanLog.Information($"Added {total} material bindings", customPrefix: LogCategory);
    }
}
