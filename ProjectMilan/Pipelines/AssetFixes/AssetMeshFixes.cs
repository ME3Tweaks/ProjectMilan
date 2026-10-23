using LegendaryExplorerCore.Helpers;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Unreal;
using LegendaryExplorerCore.Unreal.BinaryConverters;
using SharpGLTF.Schema2;
using SharpGLTF.Validation;

namespace ProjectMilan.Pipelines;

internal static class AssetMeshFixes
{
    internal static Dictionary<string, string> DiscoverFixes(string folder)
    {
        var fixes = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
        if (Directory.Exists(folder))
        {
            foreach (var file in Directory.EnumerateFiles(folder, "*.glb", SearchOption.AllDirectories).Order(StringComparer.OrdinalIgnoreCase))
            {
                // The filename is the full instanced path; subfolders only organize files
                var path = Path.GetFileNameWithoutExtension(file);
                if (!fixes.TryAdd(path, file))
                {
                    throw new InvalidDataException($"Duplicate mesh asset fix for {path}: {file}");
                }
            }
        }
        return fixes;
    }

    /// <summary>
    /// Applies a glb fix to the given export
    /// </summary>
    /// <param name="export"></param>
    /// <param name="file"></param>
    /// <returns></returns>
    /// <exception cref="InvalidDataException"></exception>
    internal static bool ApplyFix(ExportEntry export, string file)
    {
        if (export.ClassName != "SkeletalMesh")
        {
            throw new InvalidDataException($"GLB asset fixes require a SkeletalMesh: {export.InstancedFullPath} in {export.FileRef.FilePath}");
        }

        // 10/22/2026 - Try/catch so this not working doesn't kill builds
        ModelRoot model;
        IEnumerable<string> skeletalMeshes;
        try
        {
            model = ModelRoot.Load(file, ValidationMode.Skip);
            GLTF.QueryMeshes(model, out skeletalMeshes, out _);
        } catch (Exception ex)
        {
#if SHIPPING_RELEASE
            MilanLog.Fatal($"Unable to load GLTF: {ex}");
            throw;
#endif
            MilanLog.Error($"Unable to load GLTF: - this should be a blocking error in final release! {ex}");
            return false;

        }
        if (skeletalMeshes.Count() != 1)
        {
            throw new InvalidDataException($"Mesh asset fix must contain exactly one skeletal mesh (with any LODs): {file}");
        }

        var originalData = export.Data.ToArray();
        var materials = ObjectBinary.From<SkeletalMesh>(export).Materials.ToArray();
        try
        {
            GLTF.ConvertGltfToMesh(model, export.FileRef, existingMesh: export);
            var mesh = ObjectBinary.From<SkeletalMesh>(export);
            if (mesh.LODModels.Any(lod => lod.Sections.Any(section => section.MaterialIndex >= materials.Length)))
            {
                throw new InvalidDataException($"Mesh asset fix uses more material slots than the existing mesh: {file} for {export.InstancedFullPath}");
            }
            // Ignore GLB material assignments, including absent materials and names that resolve in this package.
            mesh.Materials = materials;
            export.WriteBinary(mesh);
            export.WriteProperty(MeshHelper.GetLodInfoForSkeletalMesh(mesh, export.Game));
            return !originalData.AsSpan().SequenceEqual(export.Data);
        }
        catch
        {
            export.Data = originalData;
            // The caller leaves the package unsaved if import failed, including any socket export changes.
            throw;
        }
    }
}
