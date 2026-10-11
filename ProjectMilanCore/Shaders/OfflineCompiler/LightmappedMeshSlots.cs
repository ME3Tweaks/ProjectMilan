using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Unreal;
using LegendaryExplorerCore.Unreal.BinaryConverters;
using LegendaryExplorerCore.Unreal.ObjectInfo;

namespace ProjectMilanCore.Shaders.OfflineCompiler;

/// <summary>A material slot of a lightmapped static mesh component.</summary>
/// <param name="Index">The slot in the component's Materials array, which overrides the mesh's material of that index.</param>
/// <param name="Material">What the slot draws: the component's override, else the mesh's own material (an entry of the
/// mesh's package).</param>
public sealed record LightmappedMeshSlot(ExportEntry Component, int Index, IEntry Material);

/// <summary>
/// Finds the exact material slots of the lightmapped static mesh components in a package. The usage scanner says which
/// materials are drawn lightmapped; this says where, so a slot can be pointed at another material.
/// </summary>
public static class LightmappedMeshSlots
{
    /// <param name="resolveImport">Resolves an imported mesh to its export; may return null.</param>
    public static List<LightmappedMeshSlot> Collect(IMEPackage package, Func<ImportEntry, ExportEntry?> resolveImport)
    {
        var slots = new List<LightmappedMeshSlot>();
        var meshSlots = new Dictionary<ExportEntry, Dictionary<int, IEntry?>>();
        foreach (var component in package.Exports)
        {
            // The same components the usage scanner reports as statically lit.
            if (component.IsDefaultObject || !component.IsA("StaticMeshComponent") ||
                component.IsA("InstancedStaticMeshComponent") || component.IsA("SplineMeshComponent")) continue;
            if (!ObjectBinary.From<StaticMeshComponent>(component).LODData.Any(l => (l.LightMap?.LightMapType ?? ELightMapType.LMT_None) != ELightMapType.LMT_None))
                continue;

            var overrides = component.GetProperty<ArrayProperty<ObjectProperty>>("Materials")?.Select(m => m.Value).ToArray() ?? [];
            var mesh = (component.GetProperty<ObjectProperty>("StaticMesh")?.Value ?? 0) is var uIndex and not 0
                ? package.GetEntry(uIndex) switch
                {
                    ExportEntry e => e,
                    ImportEntry i => resolveImport(i),
                    _ => null
                }
                : null;
            var fromMesh = mesh == null ? [] : MeshSlots(mesh, meshSlots);
            foreach (int index in fromMesh.Keys.Concat(Enumerable.Range(0, overrides.Length)).Distinct().Order())
            {
                var material = index < overrides.Length && overrides[index] != 0 ? package.GetEntry(overrides[index]) : fromMesh.GetValueOrDefault(index);
                if (material != null) slots.Add(new LightmappedMeshSlot(component, index, material));
            }
        }
        return slots;
    }

    /// <summary>
    /// Material index -> the mesh's material there. Null where the LODs disagree: an override applies to every LOD, so
    /// such a slot cannot be replaced by one material.
    /// </summary>
    private static Dictionary<int, IEntry?> MeshSlots(ExportEntry mesh, Dictionary<ExportEntry, Dictionary<int, IEntry?>> known)
    {
        if (known.TryGetValue(mesh, out var slots)) return slots;
        known[mesh] = slots = [];
        if (mesh.ClassName is not ("StaticMesh" or "FracturedStaticMesh")) return slots;
        foreach (var lod in ObjectBinary.From<StaticMesh>(mesh).LODModels)
        foreach (var element in lod.Elements)
        {
            // A component draws an element with the material of the element's MaterialIndex.
            int index = element.MaterialIndex;
            int material = index >= 0 && index < lod.Elements.Length ? lod.Elements[index].Material : element.Material;
            var entry = material == 0 ? null : mesh.FileRef.GetEntry(material);
            if (!slots.TryGetValue(index, out var existing)) slots[index] = entry;
            else if (existing?.UIndex != entry?.UIndex) slots[index] = null;
        }
        return slots;
    }
}
