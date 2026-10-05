using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Packages.CloningImportingAndRelinking;
using LegendaryExplorerCore.Unreal;
using LegendaryExplorerCore.Unreal.BinaryConverters;
using LegendaryExplorerCore.Unreal.ObjectInfo;
using ProjectMilanCore;

namespace ProjectMilan.Pipelines.Levels
{
    /// <summary>
    /// Stops level geometry from drawing over fog volumes when LE3 made its base material translucent.
    /// <para/>
    /// A fog volume is applied inside the translucency pass, as one more translucent primitive sorted with the rest
    /// (TranslucencySortPriority first, then depth). ME3 MP fog volumes sort ahead of everything at the default
    /// priority and ship with bAffectsTranslucency off, so every translucent primitive in the fog draws on top of it,
    /// unfogged. Several shared parents that are BLEND_Masked in ME3 are BLEND_Translucent in LE3
    /// (ME3_GUI_Lit_MM sign text, Placeable_Decal_MM shuttle text, the Alliance dropship decals), so on MPNov2 they
    /// popped through the storm. Sorting those components ahead of the fog lets it cover them like it covered the
    /// masked originals. The fog uses the depth of the opaque surface behind them, which is right for text and
    /// decals lying on a surface.
    /// </summary>
    internal static class FogTranslucencySortFix
    {
        /// <summary>
        /// BioP names this runs on. Empty runs it on every ported level - it changes nothing in a level without fog volumes.
        /// </summary>
        internal static readonly string[] LevelScope = [];

        private const string TranslucencySortPriority = "TranslucencySortPriority";

        public static void Apply(LevelSpecificPipeline levelPipeline)
        {
            if (LevelScope.Length > 0 && !LevelScope.Contains(levelPipeline.BioP, StringComparer.OrdinalIgnoreCase))
                return;

            var fogPriority = GetLowestFogVolumeSortPriority(levelPipeline);
            if (fogPriority == null)
                return;

            var targetPriority = fogPriority.Value - 1;
            var le3Resolver = new BaseMaterialResolver(levelPipeline.Cache, MilanShared.LE3PackageResolver);
            var me3Resolver = new BaseMaterialResolver(levelPipeline.Cache, MilanShared.ME3PackageResolver);

            foreach (var (packageName, le3Package) in levelPipeline.LE3Packages)
            {
                if (!levelPipeline.ME3Packages.TryGetValue(packageName, out var me3Package))
                    continue;

                var changed = 0;
                var materialsSeen = new SortedSet<string>(StringComparer.OrdinalIgnoreCase);
                foreach (var component in le3Package.Exports.Where(x => !x.IsDefaultObject && x.IsA("MeshComponent") && x.InstancedFullPath.StartsWith("TheWorld.", StringComparison.OrdinalIgnoreCase)))
                {
                    if ((component.GetProperty<IntProperty>(TranslucencySortPriority)?.Value ?? 0) <= targetPriority)
                        continue;

                    var me3Component = me3Package.FindExport(component.InstancedFullPath);
                    if (me3Component == null)
                        continue;

                    // Base material path -> blend mode, as ME3 had this component
                    var me3BlendModes = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
                    foreach (var material in me3Resolver.GetBaseMaterials(me3Component))
                    {
                        me3BlendModes[material.InstancedFullPath] = GetBlendMode(material);
                    }

                    var newlyTranslucent = le3Resolver.GetBaseMaterials(component)
                        .Where(x => IsTranslucent(GetBlendMode(x)) && me3BlendModes.TryGetValue(x.InstancedFullPath, out var me3BlendMode) && !IsTranslucent(me3BlendMode))
                        .Select(x => x.InstancedFullPath)
                        .ToList();
                    if (newlyTranslucent.Count == 0)
                        continue;

                    component.WriteProperty(new IntProperty(targetPriority, TranslucencySortPriority));
                    materialsSeen.UnionWith(newlyTranslucent);
                    changed++;
                }

                if (changed > 0)
                {
                    MilanLog.Information($"  {packageName}: sorted {changed} component(s) ahead of fog volumes (TranslucencySortPriority {targetPriority}); LE3 made these ME3 opaque/masked materials translucent: {string.Join(", ", materialsSeen)}",
                        customPrefix: levelPipeline.LogCategory);
                }
            }
        }

        /// <summary>
        /// Lowest TranslucencySortPriority of any fog volume mesh across the level's packages, or null if it has no
        /// fog volumes. Disabled ones count too, as Kismet can turn them on.
        /// </summary>
        private static int? GetLowestFogVolumeSortPriority(LevelSpecificPipeline levelPipeline)
        {
            int? lowest = null;
            foreach (var package in levelPipeline.LE3Packages.Values)
            {
                foreach (var fogInfo in package.Exports.Where(x => !x.IsDefaultObject && x.IsA("FogVolumeDensityInfo")))
                {
                    var meshComponents = new List<ExportEntry>();
                    if (fogInfo.GetProperty<ObjectProperty>("AutomaticMeshComponent")?.ResolveToEntry(package) is ExportEntry automaticMesh)
                        meshComponents.Add(automaticMesh);

                    // Actors the density component is applied to render the fog with their own meshes
                    var densityComponent = fogInfo.GetProperty<ObjectProperty>("DensityComponent")?.ResolveToEntry(package) as ExportEntry;
                    var fogActors = densityComponent?.GetProperty<ArrayProperty<ObjectProperty>>("FogVolumeActors");
                    if (fogActors != null)
                    {
                        foreach (var fogActor in fogActors.Select(x => x.ResolveToEntry(package)).OfType<ExportEntry>())
                        {
                            if (fogActor.GetProperty<ObjectProperty>("StaticMeshComponent")?.ResolveToEntry(package) is ExportEntry actorMesh)
                                meshComponents.Add(actorMesh);
                        }
                    }

                    foreach (var meshComponent in meshComponents)
                    {
                        var priority = meshComponent.GetProperty<IntProperty>(TranslucencySortPriority)?.Value ?? 0;
                        lowest = lowest == null ? priority : Math.Min(lowest.Value, priority);
                    }
                }
            }
            return lowest;
        }

        private static string GetBlendMode(ExportEntry material) => material.GetProperty<EnumProperty>("BlendMode")?.Value.Name ?? "BLEND_Opaque";

        // Everything else goes through the translucency pass, which is where the fog volume is drawn
        private static bool IsTranslucent(string blendMode) => blendMode is not ("BLEND_Opaque" or "BLEND_Masked");

        /// <summary>
        /// Resolves the root UMaterials a mesh component renders with, following imports the way one game would load them.
        /// </summary>
        private class BaseMaterialResolver(PackageCache cache, Func<string, PackageCache, IMEPackage> fileResolver)
        {
            private readonly Dictionary<string, ExportEntry?> resolvedImports = new(StringComparer.OrdinalIgnoreCase);
            private readonly Dictionary<ExportEntry, ExportEntry?> baseMaterials = new();

            public IEnumerable<ExportEntry> GetBaseMaterials(ExportEntry component)
            {
                var package = component.FileRef;
                var overrides = component.GetProperty<ArrayProperty<ObjectProperty>>("Materials");
                var meshProperty = component.IsA("SkeletalMeshComponent") ? "SkeletalMesh" : "StaticMesh";
                var mesh = Resolve(component.GetProperty<ObjectProperty>(meshProperty)?.ResolveToEntry(package));

                // Mesh material slot index -> the mesh's own material, which a non-null component override replaces
                var slots = new List<(int Index, IEntry? Material)>();
                if (mesh != null && mesh.IsA("StaticMesh"))
                {
                    foreach (var lod in ObjectBinary.From<StaticMesh>(mesh).LODModels)
                    {
                        for (int i = 0; i < lod.Elements.Length; i++)
                            slots.Add((i, mesh.FileRef.GetEntry(lod.Elements[i].Material)));
                    }
                }
                else if (mesh != null && mesh.IsA("SkeletalMesh"))
                {
                    var materials = ObjectBinary.From<SkeletalMesh>(mesh).Materials;
                    for (int i = 0; i < materials.Length; i++)
                        slots.Add((i, mesh.FileRef.GetEntry(materials[i])));
                }

                if (overrides != null)
                {
                    // Still check the overrides when the mesh could not be resolved
                    for (int i = 0; i < overrides.Count; i++)
                    {
                        if (slots.All(x => x.Index != i))
                            slots.Add((i, null));
                    }
                }

                var result = new HashSet<ExportEntry>();
                foreach (var (index, meshMaterial) in slots)
                {
                    var material = overrides != null && index < overrides.Count && overrides[index].Value != 0
                        ? overrides[index].ResolveToEntry(package)
                        : meshMaterial;
                    if (GetBaseMaterial(Resolve(material)) is { } baseMaterial)
                        result.Add(baseMaterial);
                }
                return result;
            }

            private ExportEntry? GetBaseMaterial(ExportEntry? material)
            {
                if (material == null)
                    return null;
                if (baseMaterials.TryGetValue(material, out var cached))
                    return cached;

                var current = material;
                // Instances chain, but not deeply. The cap only guards against a malformed cycle.
                for (int depth = 0; depth < 32 && current != null && !current.IsA("Material"); depth++)
                {
                    current = current.IsA("MaterialInstance") ? Resolve(current.GetProperty<ObjectProperty>("Parent")?.ResolveToEntry(current.FileRef)) : null;
                }

                var baseMaterial = current != null && current.IsA("Material") ? current : null;
                baseMaterials[material] = baseMaterial;
                return baseMaterial;
            }

            private ExportEntry? Resolve(IEntry? entry)
            {
                switch (entry)
                {
                    case ExportEntry export:
                        return export;
                    case ImportEntry import:
                        if (!resolvedImports.TryGetValue(import.InstancedFullPath, out var resolved))
                        {
                            resolved = EntryImporter.ResolveImport(import, cache, fileResolver: fileResolver);
                            resolvedImports[import.InstancedFullPath] = resolved;
                        }
                        return resolved;
                    default:
                        return null;
                }
            }
        }
    }
}
