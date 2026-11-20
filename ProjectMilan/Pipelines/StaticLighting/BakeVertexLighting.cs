using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Packages.CloningImportingAndRelinking;
using LegendaryExplorerCore.Unreal;
using LegendaryExplorerCore.Unreal.BinaryConverters;
using ProjectMilan.Pipelines.Levels;
using ProjectMilanCore;

namespace ProjectMilan.Pipelines.StaticLighting
{
    /// <summary>
    /// Bakes specific parts of levels with vertex lighting
    /// </summary>
    internal static class BakeVertexLighting
    {
        private const string LOG_CATEGORY = @"MILAN-StaticLightingExport";
        private const string CopySuffix = "_VertexLit";

        /// <summary>
        /// Prepares a UDK package to bake with vertex lighting
        /// </summary>
        internal static void Apply(LevelSpecificPipeline level, IMEPackage udk)
        {
            if (level.SpecialFixes == null)
            {
                return;
            }

            using var cache = new PackageCache();
            var copies = new Dictionary<int, ExportEntry>();
            int changed = 0;
            foreach (var sma in udk.Exports.Where(x => x.ClassName == "StaticMeshActor").ToList())
            {
                // Ignore things that can't be looked up
                if (sma.GetProperty<NameProperty>("Tag") is not { } tag)
                {
                    continue;
                }
                if (sma.GetProperty<ObjectProperty>("StaticMeshComponent")?.ResolveToEntry(udk) is not ExportEntry smc)
                {
                    continue;
                }
                if (smc.GetProperty<ObjectProperty>("StaticMesh") is not { Value: not 0 } meshProp)
                {
                    continue;
                }
                var mesh = udk.GetEntry(meshProp.Value);
                if (!level.SpecialFixes.BakeWithVertexLighting(udk.FileNameNoExtension, tag.Value.Name, mesh.InstancedFullPath))
                {
                    // Doesn't apply here
                    continue;
                }

                if (!copies.TryGetValue(mesh.UIndex, out var copy))
                {
                    // Cache
                    copy = CopyAsVertexLit(udk, mesh, cache);
                    copies[mesh.UIndex] = copy;
                }

                if (copy == null)
                {
                    continue;
                }

                smc.WriteProperty(new ObjectProperty(copy, "StaticMesh"));
                smc.RemoveProperty("bOverrideLightMapRes");
                smc.RemoveProperty("OverriddenLightMapRes");
                changed++;
            }

            if (changed > 0)
            {
                MilanLog.Information($"{udk.FileNameNoExtension}: {changed} components changed to vertex lighting", customPrefix: LOG_CATEGORY);
            }
        }

        /// <summary>
        /// Copies a mesh into the UDK package with its lightmap UV index past its last UV channel which triggers vertex lighting
        /// </summary>
        /// <returns>The copy, or null if the mesh couldn't be read</returns>
        private static ExportEntry CopyAsVertexLit(IMEPackage udk, IEntry mesh, PackageCache cache)
        {
            var source = mesh as ExportEntry ?? EntryImporter.ResolveImport((ImportEntry)mesh, cache);
            if (source == null)
            {
                MilanLog.Error($"{udk.FileNameNoExtension}: can't resolve {mesh.InstancedFullPath} to bake it with vertex lighting", customPrefix: LOG_CATEGORY);
                return null;
            }

            var copyName = source.ObjectName.Name + CopySuffix;
            if (udk.FindExport(copyName, "StaticMesh") is { } existing)
            {
                return existing; // Already copied
            }
            var report = EntryImporter.ImportAndRelinkEntries(EntryImporter.PortingOption.CloneTreeAsChild, source, udk, null, true, new RelinkerOptionsPackage(cache), out var newEntry);
            foreach (var problem in report)
            {
                MilanLog.Warning($"{udk.FileNameNoExtension}: copying {mesh.InstancedFullPath}: {problem.Message}", customPrefix: LOG_CATEGORY);
            }
            var copy = (ExportEntry)newEntry;
            copy.ObjectName = new NameReference(copyName);

            var bin = ObjectBinary.From<StaticMesh>(copy);
            // Lighting for this mesh has changed, change guid for lightmass
            bin.LightingGuid = Guid.NewGuid();
            copy.WriteBinary(bin);

            var uvChannels = (int)bin.LODModels[0].VertexBuffer.NumTexCoords;
            copy.WriteProperty(new IntProperty(uvChannels, "LightMapCoordinateIndex"));
            return copy;
        }
    }
}
