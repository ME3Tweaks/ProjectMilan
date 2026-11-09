using LegendaryExplorerCore.Kismet;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Unreal;
using LegendaryExplorerCore.Unreal.BinaryConverters;
using ProjectMilanCore;

namespace ProjectMilan.Pipelines.EntryMenu.MenuScenes
{
    /// <summary>
    /// Level cleanup shared by the menu scene builders
    /// </summary>
    internal static class MenuLevelTools
    {
        /// <summary>
        /// Names the main menu scenes share between the pipeline, their Kismet and the game
        /// </summary>
        public const string ScenePackagePrefix = "EntryMenu_";
        public const string SharedSublevelName = "BioD_MilanMenu";
        public const string TerminalAnchorTag = "MilanMenu_TerminalAnchor";
        public const string VistaCameraTag = "MilanMenu_VistaCam";
        public const string VistaCameraEndTag = "MilanMenu_VistaCamEnd";
        public const string TerminalCameraTag = "MilanMenu_TerminalCam";
        public const string TerminalKeyLightTag = "MilanMenu_TerminalKeyLight";
        public const string TerminalAmbientLightTag = "MilanMenu_TerminalAmbient";

        /// <summary>
        /// Remote event BioD_MilanMenu fires once every level of the scene is loaded
        /// </summary>
        public const string SceneReadyEvent = "MilanMenu_SceneReady";

        /// <summary>
        /// Where this pipeline writes output to
        /// </summary>
        public static string OutputFolder => Path.Combine(Program.Settings.OutputModPath, "CookedPCConsole", "EntryMenu");

        /// <summary>
        /// Creates a sequence action of one of Milan's own Kismet classes
        /// </summary>
        public static ExportEntry CreateMilanAction(ExportEntry sequence, string classPath)
        {
            var package = sequence.FileRef;
            var actionClass = MilanLevelTools.GetOrAddForcedExportClassImport(package, classPath);
            var action = new ExportEntry(package, sequence, package.GetNextIndexedName(actionClass.ObjectName.Name), properties: new PropertyCollection
            {
                new IntProperty(1, "ObjInstanceVersion"),
            })
            {
                Class = actionClass,
            };
            action.ObjectFlags |= UnrealFlags.EObjectFlags.Transactional;
            package.AddExport(action);
            KismetHelper.AddObjectToSequence(action, sequence);
            return action;
        }

        /// <summary>
        /// Sets self-package name in the package
        /// </summary>
        public static void RenameSelfPackage(IMEPackage package, string originalName)
        {
            var self = package.Exports.FirstOrDefault(x => x.idxLink == 0 && x.ClassName == "Package" && x.ObjectName.Instanced.Equals(originalName, StringComparison.OrdinalIgnoreCase));
            if (self != null)
            {
                self.ObjectName = new NameReference(package.FileNameNoExtension);
            }
        }

        /// <summary>
        /// Clear all navigation data from the level
        /// </summary>
        public static void ClearNavigation(Level level)
        {
            level.NavListStart = 0;
            level.NavListEnd = 0;
            level.CoverListStart = 0;
            level.CoverListEnd = 0;
            level.PylonListStart = 0;
            level.PylonListEnd = 0;
            level.CrossLevelCoverGuidRefs?.Clear();
            level.CoverLinkRefs?.Clear();
            level.CoverIndexPairs?.Clear();
            level.CrossLevelNavGuidRefs?.Clear();
            level.NavRefs?.Clear();
            level.NavRefIndicies?.Clear();
            level.CrossLevelActors?.Clear();
        }

        /// <summary>
        /// Trashes unreferenced exports under the given top level packages
        /// </summary>
        /// <returns>
        /// How many exports were trashed
        /// </returns>
        public static int PruneUnreferenced(IMEPackage package, IReadOnlyCollection<string> packageRoots)
        {
            var reachable = package.GetReferencedEntries();
            // Referencers and the shader cache hold things for loading, so they always stay
            var candidates = package.Exports.Where(x => !x.IsTrash() && x.ClassName is not ("Package" or "ObjectReferencer" or "ShaderCache") && !reachable.Contains(x.UIndex)
                    && packageRoots.Contains(x.InstancedFullPath.Split('.')[0], StringComparer.OrdinalIgnoreCase))
                .ToHashSet();

            // Anything outside the candidates keeps what it points at, transitively
            var pending = new Stack<ExportEntry>(package.Exports.Where(x => !x.IsTrash() && !candidates.Contains(x)));
            while (pending.TryPop(out var export))
            {
                foreach (var uIndex in GetDirectReferences(export))
                {
                    if (uIndex > 0 && package.GetUExport(uIndex) is { } referenced && candidates.Remove(referenced))
                    {
                        pending.Push(referenced);
                    }
                }
            }

            if (candidates.Count == 0)
            {
                return 0;
            }

            EntryPruner.TrashEntries(package, candidates);

            // Then packages left empty, innermost first
            var emptyPackages = package.Exports
                .Where(x => !x.IsTrash() && x.ClassName == "Package"
                    && packageRoots.Contains(x.InstancedFullPath.Split('.')[0], StringComparer.OrdinalIgnoreCase))
                .OrderByDescending(x => x.InstancedFullPath.Count(c => c == '.'))
                .Where(x => !package.Exports.Any(child => child.Parent == x && !child.IsTrash()))
                .ToList();
            EntryPruner.TrashEntries(package, emptyPackages);
            return candidates.Count + emptyPackages.Count;
        }

        /// <summary>
        /// Drops trashed members from each prefab instance's maps. Call after trashing actors, or resynthesis turns the stale
        /// references into indexes past the export table and the game crashes loading the level.
        /// </summary>
        /// <returns>The prefab instances with no members left, for the caller to trash</returns>
        public static List<ExportEntry> PrunePrefabInstances(IMEPackage package)
        {
            bool IsLive(int uIndex)
            {
                if (uIndex == 0)
                {
                    return true;
                }
                if (!package.TryGetEntry(uIndex, out var entry))
                {
                    return false;
                }
                return entry is not ExportEntry export || !export.IsTrash();
            }

            var emptied = new List<ExportEntry>();
            foreach (var prefabInstance in package.Exports.Where(x => x.ClassName == "PrefabInstance" && !x.IsTrash()).ToList())
            {
                var binary = ObjectBinary.From<PrefabInstance>(prefabInstance);
                var members = binary.ArchetypeToInstanceMap.Where(x => IsLive(x.Value)).ToList();
                var objects = binary.ObjectMap.Where(x => IsLive(x.Key)).ToList();
                if (members.Count == binary.ArchetypeToInstanceMap.Count && objects.Count == binary.ObjectMap.Count)
                {
                    continue;
                }

                if (members.Count == 0)
                {
                    emptied.Add(prefabInstance);
                    continue;
                }

                binary.ArchetypeToInstanceMap = new(members);
                binary.ObjectMap = new(objects);
                prefabInstance.WriteBinary(binary);
            }
            return emptied;
        }

        /// <summary>
        /// Fails if anything kept still points at a trashed export, as the game reads that as whatever lands at the index
        /// once the trash is dropped
        /// </summary>
        public static void VerifyNoTrashReferences(IMEPackage package)
        {
            var problems = new List<string>();
            foreach (var export in package.Exports.Where(x => !x.IsTrash()))
            {
                foreach (var uIndex in GetDirectReferences(export).Distinct())
                {
                    if (uIndex > 0 && (!package.IsUExport(uIndex) || package.GetUExport(uIndex).IsTrash()))
                    {
                        problems.Add($"{export.InstancedFullPath} -> {uIndex}");
                    }
                }
            }

            if (problems.Count > 0)
            {
                throw new InvalidDataException($"{package.FileNameNoExtension} still references trashed exports:\n{string.Join("\n", problems.Take(20))}");
            }
        }

        /// <summary>
        /// The UIndexes an export points at directly: header, properties and binary
        /// </summary>
        public static List<int> GetDirectReferences(ExportEntry export)
        {
            var references = new List<int> { export.idxLink, export.idxClass, export.idxSuperClass, export.idxArchetype };
            CollectPropertyReferences(export.GetProperties(), references);
            if (!export.IsDefaultObject && ObjectBinary.From(export) is { } binary)
            {
                binary.ForEachUIndex(export.Game, new UIndexCollector(references));
            }

            return references;
        }

        private static void CollectPropertyReferences(PropertyCollection properties, List<int> references)
        {
            foreach (var property in properties)
            {
                switch (property)
                {
                    case ObjectProperty objectProperty:
                        references.Add(objectProperty.Value);
                        break;
                    case DelegateProperty delegateProperty:
                        references.Add(delegateProperty.Value.ContainingObjectUIndex);
                        break;
                    case StructProperty structProperty:
                        CollectPropertyReferences(structProperty.Properties, references);
                        break;
                    case ArrayProperty<ObjectProperty> objectArray:
                        references.AddRange(objectArray.Select(x => x.Value));
                        break;
                    case ArrayProperty<StructProperty> structArray:
                        foreach (var item in structArray)
                        {
                            CollectPropertyReferences(item.Properties, references);
                        }
                        break;
                }
            }
        }
    }
}
