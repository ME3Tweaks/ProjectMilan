#nullable disable
using System.Collections.Concurrent;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.UnrealScript;
using ProjectMilanCore;

namespace ProjectMilan.Pipelines.Slash
{
    // Vtables of the packages copied from LE3
    internal partial class SlashGenerator
    {
        /// <summary>
        /// Package cache for the game being slashed that also takes paths relative to the game root, which is how the compiler
        /// asks for things when it's pointed at a game folder.
        /// </summary>
        private class GamePackageCache : PackageCache
        {
            public string RootPath { get; init; }

            public override IMEPackage GetCachedPackage(string packagePath, bool openIfNotInCache = true, Func<string, IMEPackage> openPackageMethod = null)
            {
                if (packagePath != null && RootPath != null && !Path.IsPathRooted(packagePath))
                    packagePath = Path.Combine(RootPath, packagePath);
                return base.GetCachedPackage(packagePath, openIfNotInCache, openPackageMethod ?? (x => MEPackageHandler.OpenMEPackage(x, forceLoadFromDisk: true)));
            }
        }

        /// <summary>
        /// The decompiler's comment on a call whose vtable index doesn't name the function it calls.
        /// </summary>
        private const string StaleCallMarker = "Recompilation of this function is required";

        /// <summary>
        /// Every class in the game, partially loaded with only class data, so their vtables can be read and rebuilt in memory.
        /// </summary>
        private class ClassIndex
        {
            /// <summary>Each package with classes, by game-relative path.</summary>
            public Dictionary<string, IMEPackage> Packages { get; } = new(StringComparer.OrdinalIgnoreCase);

            /// <summary>
            /// Classes by memory path. A class in several packages (a forced export) resolves to the Project Milan mod's copy if
            /// it has one, as its DLC mounts above the basegame.
            /// </summary>
            public Dictionary<string, ExportEntry> Classes { get; } = new(StringComparer.OrdinalIgnoreCase);

            public ExportEntry Resolve(ImportEntry import) => Classes.GetValueOrDefault(import.InstancedFullPath);

            /// <summary>
            /// The vtable indexes each function name has, across every class in the game.
            /// </summary>
            public Dictionary<string, HashSet<int>> GetVTableIndexes()
            {
                var indexes = new Dictionary<string, HashSet<int>>(StringComparer.OrdinalIgnoreCase);
                foreach (var classExport in Packages.Values.SelectMany(x => x.Exports).Where(x => x.IsClass))
                {
                    var slots = VTableCascade.ReadSlots(classExport);
                    for (int i = 0; i < slots.Count; i++)
                    {
                        if (!indexes.TryGetValue(slots[i].Name, out var set))
                            indexes[slots[i].Name] = set = new HashSet<int>();
                        set.Add(i);
                    }
                }
                return indexes;
            }
        }

        private ClassIndex LoadClassIndex()
        {
            var index = new ClassIndex();
            var paths = snapshot.EnumerateGameFiles().Where(x => IsPackage(x) && !IsRefShaderCache(x)).ToList();
            var loaded = new ConcurrentDictionary<string, IMEPackage>(StringComparer.OrdinalIgnoreCase);
            Parallel.ForEach(paths, new ParallelOptions { MaxDegreeOfParallelism = NetIndexParallelism }, relativePath =>
            {
                var package = MEPackageHandler.UnsafePartialLoad(snapshot.GetGamePath(relativePath), x => x.IsClass);
                if (package.Exports.Any(x => x.IsClass))
                    loaded[relativePath] = package;
                else
                    package.Dispose();
            });

            foreach (var (relativePath, package) in loaded.OrderBy(x => modOutputs.Contains(x.Key) ? 0 : 1).ThenBy(x => x.Key, StringComparer.OrdinalIgnoreCase))
            {
                index.Packages[relativePath] = package;
                foreach (var classExport in package.Exports.Where(x => x.IsClass))
                    index.Classes.TryAdd(classExport.MemoryFullPath, classExport);
            }
            return index;
        }

        private static void DisposeClassIndex(ClassIndex index)
        {
            foreach (var package in index.Packages.Values)
                package.Dispose();
        }

        /// <summary>
        /// The EX_NamedFunction calls in a package's functions and states, by export UIndex. Only function and state data is loaded.
        /// </summary>
        private Dictionary<int, List<(string Name, int Index)>> ReadNamedFunctionCalls(string relativePath)
        {
            using var package = MEPackageHandler.UnsafePartialLoad(snapshot.GetGamePath(relativePath), x => x.ClassName is "Function" or "State");
            return package.Exports.Where(x => x.ClassName is "Function" or "State")
                .Select(x => (x.UIndex, Calls: VTableCascade.ReadNamedFunctionCalls(x)))
                .Where(x => x.Calls.Count > 0)
                .ToDictionary(x => x.UIndex, x => x.Calls);
        }

        /// <summary>
        /// The vtables LE3's script was compiled against, by class memory path: those of the given packages as LE3 ships them.
        /// </summary>
        private Dictionary<string, List<VTableCascade.VTableSlot>> ReadVanillaVTables(IEnumerable<string> relativePaths)
        {
            var vtables = new ConcurrentDictionary<string, List<VTableCascade.VTableSlot>>(StringComparer.OrdinalIgnoreCase);
            Parallel.ForEach(relativePaths, new ParallelOptions { MaxDegreeOfParallelism = NetIndexParallelism }, relativePath =>
            {
                // A file MilanDelta patched has to come from LE3; everything else was copied as it is
                using var package = MEPackageHandler.UnsafePartialLoad(getVanillaOfPatched(relativePath) ?? GetOriginalPath(relativePath), x => x.IsClass);
                foreach (var (classPath, slots) in VTableCascade.ReadAllSlots(package))
                    vtables.TryAdd(classPath, slots);
            });
            return new Dictionary<string, List<VTableCascade.VTableSlot>>(vtables, StringComparer.OrdinalIgnoreCase);
        }

        /// <summary>
        /// Brings the script of the packages copied from LE3 in line with the classes Project Milan changed. Adding a function to
        /// a class shifts the functions of its subclasses up a slot, and LE3's packages are full of subclasses of SFXGame's
        /// classes (every weapon, for one). So:
        /// <list type="number">
        /// <item>Each class's vtable is rebuilt as its parent's followed by its own new functions, parents first, the same way
        /// Project Milan's BaseDelta does it for the packages it patches.</item>
        /// <item>Comparing each class's vtable with LE3's gives where every function moved. Each function that makes an
        /// EX_NamedFunction call to one of them is decompiled, which checks every call's index against the class it's called on.</item>
        /// <item>In a function the decompiler flags, the calls are moved to their function's new index in place, so the rest of
        /// LE3's bytecode stays as it is. A function that's still wrong after that is recompiled.</item>
        /// </list>
        /// The changes become slash patches like any other. <see cref="CheckVTables"/> checks the whole game afterwards.
        /// </summary>
        private void CascadeVTables()
        {
            setStatus?.Invoke("Rebuilding vtables");
            var le3Packages = EnumerateLE3Packages().ToHashSet(StringComparer.OrdinalIgnoreCase);
            var index = LoadClassIndex();
            try
            {
                var le3ClassPackages = index.Packages.Where(x => le3Packages.Contains(x.Key)).ToList();
                var vanilla = ReadVanillaVTables(le3ClassPackages.Select(x => x.Key));

                // Rebuilt in memory first, repeated until nothing changes, so a class's parent in another package is rebuilt
                // before it is read, whatever order the packages are in
                var rebuiltPackages = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
                int rebuiltClasses = 0;
                for (int pass = 1; ; pass++)
                {
                    int changed = 0;
                    foreach (var (relativePath, package) in le3ClassPackages)
                    {
                        var rebuilt = VTableCascade.Rebuild(package, index.Resolve);
                        if (rebuilt.Count > 0)
                        {
                            rebuiltPackages.Add(relativePath);
                            changed += rebuilt.Count;
                        }
                    }

                    rebuiltClasses += changed;
                    if (changed == 0)
                        break;
                    if (pass == 10)
                        throw new Exception("Vtables were still changing after 10 passes over the LE3 packages");
                }

                var final = new Dictionary<string, List<VTableCascade.VTableSlot>>(StringComparer.OrdinalIgnoreCase);
                foreach (var (_, package) in le3ClassPackages)
                {
                    foreach (var (classPath, slots) in VTableCascade.ReadAllSlots(package))
                        final.TryAdd(classPath, slots);
                }

                var shifts = VTableCascade.FindShifts(vanilla, final).ToList();
                if (shifts.Count == 0)
                {
                    MilanLog.Information("Slash: every LE3 class has the vtable LE3 gives it");
                    return;
                }

                // Write the rebuilt vtables into the game's files
                foreach (var relativePath in rebuiltPackages.OrderBy(x => x, StringComparer.OrdinalIgnoreCase))
                {
                    setStatus?.Invoke($"Rebuilding vtables: {GetFileName(relativePath)}");
                    var path = snapshot.GetGamePath(relativePath);
                    using var package = MEPackageHandler.OpenMEPackage(path, forceLoadFromDisk: true);
                    if (VTableCascade.Rebuild(package, index.Resolve).Count > 0)
                        SavePackage(package, path);
                }

                // Functions that might call a function that moved
                var movedNames = shifts.Select(x => x.Name).ToHashSet(StringComparer.OrdinalIgnoreCase);
                var callers = new ConcurrentDictionary<string, List<int>>(StringComparer.OrdinalIgnoreCase);
                Parallel.ForEach(le3Packages, new ParallelOptions { MaxDegreeOfParallelism = NetIndexParallelism }, relativePath =>
                {
                    using var package = MEPackageHandler.UnsafePartialLoad(snapshot.GetGamePath(relativePath), x => x.ClassName is "Function" or "State");
                    var found = VTableCascade.FindNamedFunctionCallers(package, movedNames);
                    if (found.Count > 0)
                        callers[relativePath] = found.Select(x => x.UIndex).ToList();
                });

                var (moved, recompiled) = FixCalls(callers, VTableCascade.GetMoves(shifts));
                MilanLog.Information($"Slash: rebuilt {rebuiltClasses} vtable(s) in {rebuiltPackages.Count} LE3 package(s), moving {movedNames.Count} function(s); " +
                                  $"checked {callers.Sum(x => x.Value.Count)} function(s) in {callers.Count} package(s) that call them, moved the index of {moved} call(s) and recompiled {recompiled} function(s)");
            }
            finally
            {
                DisposeClassIndex(index);
            }
        }

        /// <summary>
        /// Decompiles the given functions and states, by package, which checks every call's index against the class it's called
        /// on. In one that's wrong, the calls are moved to their function's new index; if that doesn't fix it, it is recompiled
        /// from its decompiled source.
        /// </summary>
        /// <returns>The number of calls moved, and of functions recompiled.</returns>
        private (int Moved, int Recompiled) FixCalls(IReadOnlyDictionary<string, List<int>> exports, Func<string, int, int?> moves)
        {
            var usop = new UnrealScriptOptionsPackage
            {
                Cache = new GamePackageCache { RootPath = bioGame },
                GamePathOverride = gameRoot
            };

            int moved = 0, recompiled = 0;
            var problems = new List<string>();
            foreach (var (relativePath, uIndexes) in exports.OrderBy(x => x.Key, StringComparer.OrdinalIgnoreCase))
            {
                setStatus?.Invoke($"Checking script: {GetFileName(relativePath)}");
                var path = snapshot.GetGamePath(relativePath);
                using var package = MEPackageHandler.OpenMEPackage(path, forceLoadFromDisk: true);
                var lib = new FileLib(package);
                if (!lib.Initialize(usop))
                    throw new Exception($"Unable to load the script symbols for {relativePath}: {string.Join("; ", lib.InitializationLog.AllErrors.Select(x => x.Message))}");

                bool changed = false;
                foreach (var export in uIndexes.Select(package.GetUExport))
                {
                    var (_, text) = UnrealScriptCompiler.DecompileExport(export, lib, usop);
                    if (!text.Contains(StaleCallMarker))
                        continue;

                    changed = true;
                    int calls = VTableCascade.PatchNamedFunctionCalls(export, moves);
                    if (calls > 0 && !UnrealScriptCompiler.DecompileExport(export, lib, usop).text.Contains(StaleCallMarker))
                    {
                        moved += calls;
                        continue;
                    }

                    if (export.ClassName != "Function")
                    {
                        problems.Add($"{relativePath}: {export.InstancedFullPath} is state code with a call the vtables no longer match, and moving its index didn't fix it");
                        continue;
                    }

                    MilanLog.Information($"Slash: recompiling {export.InstancedFullPath} in {relativePath}: moving its call indexes didn't fix it");
                    var source = string.Join("\n", text.Split('\n').Where(x => !x.Contains(StaleCallMarker)));
                    var (_, log) = UnrealScriptCompiler.CompileFunction(export, source, lib, usop);
                    if (log.HasErrors)
                    {
                        problems.Add($"{relativePath}: {export.InstancedFullPath} doesn't recompile: {string.Join("; ", log.AllErrors.Select(x => x.Message))}");
                        continue;
                    }

                    if (UnrealScriptCompiler.DecompileExport(export, lib, usop).text.Contains(StaleCallMarker))
                    {
                        problems.Add($"{relativePath}: {export.InstancedFullPath} still has a call the vtables don't match after recompiling");
                        continue;
                    }

                    recompiled++;
                }

                if (changed)
                    SavePackage(package, path);
            }

            if (problems.Count > 0)
            {
                foreach (var problem in problems)
                    MilanLog.Error($"Slash: {problem}");
                throw new Exception($"{problems.Count} function(s) in LE3 packages couldn't be fixed for the vtables Project Milan changed. First: {problems[0]}");
            }
            return (moved, recompiled);
        }

        /// <summary>
        /// Fails generation if any class in the game has a vtable that isn't its parent's followed by its own functions, or any
        /// EX_NamedFunction call in a package copied from LE3 uses an index no class has that function at.
        /// </summary>
        private void CheckVTables()
        {
            setStatus?.Invoke("Checking vtables");
            var le3Packages = EnumerateLE3Packages().ToHashSet(StringComparer.OrdinalIgnoreCase);
            var index = LoadClassIndex();
            try
            {
                var problems = new List<string>();
                foreach (var (relativePath, package) in index.Packages)
                {
                    string owner = modOutputs.Contains(relativePath) ? " (installed by Project Milan)" : "";
                    foreach (var classExport in package.Exports.Where(x => x.IsClass && x.SuperClass != null && !VTableCascade.IsInterface(x)))
                    {
                        var parent = classExport.SuperClass as ExportEntry ?? index.Resolve((ImportEntry)classExport.SuperClass);
                        if (parent == null)
                        {
                            problems.Add($"{relativePath}{owner}: {classExport.InstancedFullPath}'s parent {classExport.SuperClass.InstancedFullPath} isn't in the game");
                            continue;
                        }

                        var names = VTableCascade.ReadSlots(classExport).Select(x => x.Name).ToList();
                        var parentNames = VTableCascade.ReadSlots(parent).Select(x => x.Name).ToList();
                        if (names.Count < parentNames.Count || !names.Take(parentNames.Count).SequenceEqual(parentNames, StringComparer.OrdinalIgnoreCase))
                            problems.Add($"{relativePath}{owner}: {classExport.InstancedFullPath}'s vtable doesn't start with its parent {parent.InstancedFullPath}'s");
                    }
                }

                var vtableIndexes = index.GetVTableIndexes();
                var badCalls = new ConcurrentBag<string>();
                Parallel.ForEach(le3Packages, new ParallelOptions { MaxDegreeOfParallelism = NetIndexParallelism }, relativePath =>
                {
                    foreach (var (_, calls) in ReadNamedFunctionCalls(relativePath))
                    {
                        foreach (var (name, vtableIndex) in calls)
                        {
                            if (!vtableIndexes.TryGetValue(name, out var indexes) || !indexes.Contains(vtableIndex))
                                badCalls.Add($"{relativePath}: a call to {name} uses vtable index {vtableIndex}, which no class has it at");
                        }
                    }
                });
                problems.AddRange(badCalls.OrderBy(x => x, StringComparer.OrdinalIgnoreCase));

                if (problems.Count > 0)
                {
                    foreach (var problem in problems)
                        MilanLog.Error($"Slash: {problem}");
                    throw new Exception($"{problems.Count} vtable problem(s) remain after slashing. First: {problems[0]}");
                }
            }
            finally
            {
                DisposeClassIndex(index);
            }
        }
    }
}
