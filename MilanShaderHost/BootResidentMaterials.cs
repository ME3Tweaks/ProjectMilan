using LegendaryExplorerCore.GameFilesystem;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Packages.CloningImportingAndRelinking;
using LegendaryExplorerCore.Unreal;
using LegendaryExplorerCore.Unreal.BinaryConverters;
using LegendaryExplorerCore.Unreal.ObjectInfo;

namespace MilanShaderHost
{
    /// <summary>
    /// Materials and material instances the game already holds in memory at boot, and the renaming
    /// that keeps our full-graph copies of them from losing the load in the compiler level.
    /// </summary>
    /// <remarks>
    /// <para>The boot-resident copies are cooked, and cooking strips a material's graph down to its
    /// parameter nodes. SFXGame's <c>BioG_MasterMats.Material_Parents.ME3_OPAQUE_MM</c> keeps its 21
    /// static switches, 14 scalars, 7 vectors and 8 texture parameters and loses every Multiply, Add,
    /// Constant, VertexColor, TextureCoordinate and ComponentMask (118 expressions in the decooked
    /// copy, 50 in SFXGame's); <c>BIOG_APL_MASTER_MATERIAL.Placeable_MM</c> goes from 24 to 11. Shipping
    /// never notices: every permutation it ships was compiled from the full graph before cooking.</para>
    ///
    /// <para>We compile <em>new</em> permutations. <see cref="CapturePackageNaming"/> renames the input
    /// package when it is boot-resident, but an instance's <em>parent</em> arrives in the compiler level
    /// as a forced export under its own root (<c>BioG_MasterMats</c>, <c>BIOG_APL_MASTER_MATERIAL</c>),
    /// collides with the boot copy, and loses. The permutation is then translated from the stripped
    /// graph and renders black. Found 2026-09-27 on BioA_MPOcean_100 (floors, towers, gratings) and the
    /// BioT_GthMP icebergs, all parented to SFXGame's ME3_OPAQUE_MM; every key and texture binding
    /// checked out, so nothing downstream could see it.</para>
    ///
    /// <para>The fix renames the colliding objects themselves -- not their root package. Results come
    /// back as object paths resolved against the output package, so renaming a whole root would null
    /// every default texture under it; renaming only materials and instances leaves textures on their
    /// real paths. A renamed material also takes the shipping copy's resource ID, so the permutations
    /// it compiles are keyed by the ID the game will look them up under.</para>
    /// </remarks>
    internal static class BootResidentMaterials
    {
        /// <summary>Instanced full path of every boot-resident Material or MaterialInstance, mapped to
        /// the Material's SM3 resource ID (<see cref="Guid.Empty"/> for instances).</summary>
        private static Dictionary<string, Guid>? index;
        private static readonly object indexLock = new();

        private static Dictionary<string, Guid> Index
        {
            get
            {
                lock (indexLock)
                {
                    return index ??= BuildIndex();
                }
            }
        }

        private static Dictionary<string, Guid> BuildIndex()
        {
            var result = new Dictionary<string, Guid>(StringComparer.OrdinalIgnoreCase);
            var gameRoot = Program.ParsedOptions?.GamePath ?? LE3Directory.DefaultGamePath;
            var cooked = Path.Combine(gameRoot, "BioGame", "CookedPCConsole");

            foreach (var fileName in EntryImporter.FilesSafeToImportFrom(MEGame.LE3))
            {
                // Same exclusion as ShaderResearchTool's startup-collisions scan: the Startup.pcc in
                // CookedPCConsole is not the one the game loads and yields false collisions.
                if (fileName.Equals("Startup.pcc", StringComparison.OrdinalIgnoreCase)) continue;

                var file = Path.Combine(cooked, fileName);
                if (!File.Exists(file)) continue;

                using var package = MEPackageHandler.OpenMEPackage(file);
                foreach (var export in package.Exports)
                {
                    if (export.IsA("Material"))
                    {
                        Guid id;
                        try
                        {
                            id = ObjectBinary.From<Material>(export).SM3MaterialResource.ID;
                        }
                        catch
                        {
                            id = Guid.Empty;
                        }
                        result.TryAdd(export.InstancedFullPath, id);
                    }
                    else if (export.IsA("MaterialInstance"))
                    {
                        result.TryAdd(export.InstancedFullPath, Guid.Empty);
                    }
                }
            }

            Console.WriteLine($"[{DateTime.Now:HH:mm:ss}] Indexed {result.Count:N0} boot-resident materials and instances.");
            return result;
        }

        /// <summary>
        /// Renames every material and instance in <paramref name="package"/> that the game already holds
        /// at boot, outside the package being compiled, so our full-graph copy is the one that loads.
        /// Renamed materials take the boot copy's resource ID. Returns the original paths renamed.
        /// </summary>
        public static List<string> RenameCollisions(IMEPackage package, string captureRoot)
        {
            var renamed = new List<string>();
            // Parents before children would change the children's paths mid-scan, so decide first.
            var targets = package.Exports
                .Where(x => (x.IsA("Material") || x.IsA("MaterialInstance"))
                            && !IsUnderRoot(x, captureRoot)
                            && Index.ContainsKey(x.InstancedFullPath))
                .Select(x => (export: x, path: x.InstancedFullPath))
                .ToList();

            foreach (var (export, path) in targets)
            {
                if (export.IsA("Material") && Index[path] != Guid.Empty)
                {
                    var shippingId = Index[path];
                    ObjectBinary.EditBinary<Material>(export, x => x.SM3MaterialResource.ID = shippingId);
                }
                export.ObjectName = new NameReference(export.ObjectName.Name + CapturePackageNaming.RenameSuffix, export.ObjectName.Number);
                renamed.Add(path);
            }

            if (renamed.Count > 0)
            {
                Console.WriteLine($"[{DateTime.Now:HH:mm:ss}] {renamed.Count} parent material(s) are resident at boot as stripped cooked copies; " +
                                  $"compiling ours under a '{CapturePackageNaming.RenameSuffix}' suffix so the full graph is the one that loads:");
                foreach (var path in renamed)
                {
                    Console.WriteLine($"    {path}");
                }
            }
            return renamed;
        }

        /// <summary>
        /// Strips the rename from every export in <paramref name="package"/> that <see cref="RenameCollisions"/>
        /// renamed, so the result carries the real names. Stateless: an export qualifies when it ends in
        /// the suffix and its unsuffixed path is boot-resident.
        /// </summary>
        public static void RestoreNames(IMEPackage package)
        {
            var suffix = CapturePackageNaming.RenameSuffix;
            // Collect first: renaming a parent changes its children's paths.
            var toRestore = package.Exports
                .Where(x => (x.IsA("Material") || x.IsA("MaterialInstance"))
                            && x.ObjectName.Name.EndsWith(suffix, StringComparison.Ordinal)
                            && x.ObjectName.Name.Length > suffix.Length)
                .Select(x => (export: x, original: new NameReference(x.ObjectName.Name[..^suffix.Length], x.ObjectName.Number)))
                .Where(x => Index.ContainsKey(OriginalPath(x.export, x.original)))
                .ToList();

            foreach (var (export, original) in toRestore)
            {
                export.ObjectName = original;
            }
            if (toRestore.Count > 0)
            {
                Console.WriteLine($"Restored {toRestore.Count} boot-resident parent material name(s) before saving.");
            }
        }

        private static string OriginalPath(ExportEntry export, NameReference originalName)
        {
            var parentPath = export.Parent?.InstancedFullPath;
            return parentPath == null ? originalName.Instanced : parentPath + "." + originalName.Instanced;
        }

        private static bool IsUnderRoot(IEntry entry, string root)
        {
            var top = entry;
            while (top.Parent != null) top = top.Parent;
            return top.ObjectName.Instanced.Equals(root, StringComparison.OrdinalIgnoreCase);
        }
    }
}
