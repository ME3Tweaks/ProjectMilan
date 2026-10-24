using LegendaryExplorerCore.GameFilesystem;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Packages.CloningImportingAndRelinking;
using LegendaryExplorerCore.Unreal.ObjectInfo;
using LegendaryExplorerCore.UnrealScript;
using ProjectMilanCore;

namespace ProjectMilan.Pipelines.Mod.BaseDelta
{
    /// <summary>
    /// Keeps vtables right when BaseDelta changes a class's functions. Adding a function to a class shifts its subclasses' own
    /// functions up a slot, so each patched package has its vtables rebuilt parents first and the calls that use a moved index
    /// fixed. LE3 packages BaseDelta doesn't patch are only checked, and what they need is logged: Mod Manager's slash
    /// generation fixes them in the LMP install.
    /// </summary>
    internal static class BaseDeltaVTables
    {
        private const string LOG_CATEGORY = "Milan-BaseDeltaVTables";

        /// <summary>How many problems the unpatched-package check lists.</summary>
        private const int LoggedProblems = 100;

        /// <summary>
        /// Classes whose vtable a patched package changed from vanilla, by class memory path. Filled by <see cref="Observe"/>
        /// for fresh builds and checkpoint restores alike, since both go through the patched bytes.
        /// </summary>
        internal static readonly Dictionary<string, VTableCascade.ClassChange> ChangedClasses = new(StringComparer.OrdinalIgnoreCase);

        /// <summary>
        /// Rebuilds the vtables of <paramref name="package"/> parents first, then fixes the calls that use an index that moved,
        /// compared to <paramref name="vanillaVTables"/>, to the cascade, or in an earlier patched package.
        /// Call after all UnrealScript has been compiled into the package.
        /// </summary>
        /// <param name="vanillaVTables">The package's vtables before any edit, from <see cref="VTableCascade.ReadAllSlots"/>.</param>
        internal static void Apply(IMEPackage package, FileLib fileLib, UnrealScriptOptionsPackage usop, Dictionary<string, List<VTableCascade.VTableSlot>> vanillaVTables, string logCategory)
        {
            var compiledVTables = VTableCascade.ReadAllSlots(package);
            var rebuilt = VTableCascade.Rebuild(package, import => EntryImporter.ResolveImport(import, usop.Cache, fileResolver: MilanShared.LE3PackageResolver));
            foreach (var classExport in rebuilt)
                MilanLog.Information($"Rebuilt vtable of {classExport.InstancedFullPath} to match its parent", customPrefix: logCategory);

            var finalVTables = VTableCascade.ReadAllSlots(package);
            var shifts = VTableCascade.FindShifts(vanillaVTables, finalVTables)
                .Concat(VTableCascade.FindShifts(compiledVTables, finalVTables))
                .Concat(ChangedClasses.Values.SelectMany(x => VTableCascade.FindShifts(x.ClassPath, x.Before, x.After)))
                .ToList();
            if (shifts.Count == 0)
                return;

            // The decompiler and compiler read vtables through the FileLib
            if (!fileLib.ReInitializeFile(usop))
            {
                MilanShared.LogFailedFileLibInit(fileLib);
                MilanLog.Fatal($"Unable to re-initialize the FileLib for {package.FileNameNoExtension} after rebuilding vtables - this is a fatal error.", customPrefix: logCategory);
                Environment.Exit(1);
            }

            // The decompiler flags a call whose index doesn't name the function it calls. Moving the index in place keeps the rest
            // of the vanilla bytecode as it is; recompiling is only for calls that can't be fixed from the index alone.
            var moves = VTableCascade.GetMoves(shifts);
            int patched = 0, recompiled = 0;
            foreach (var caller in VTableCascade.FindNamedFunctionCallers(package, shifts.Select(x => x.Name)))
            {
                if (!IsStale(caller, fileLib, usop, out var source))
                    continue;

                int calls = VTableCascade.PatchNamedFunctionCalls(caller, moves);
                if (calls > 0 && !IsStale(caller, fileLib, usop, out _))
                {
                    MilanLog.Information($"Moved the vtable index of {calls} call(s) in {caller.InstancedFullPath}", customPrefix: logCategory);
                    patched++;
                    continue;
                }

                if (caller.ClassName != "Function")
                {
                    MilanLog.Fatal($"{caller.InstancedFullPath} in {package.FileNameNoExtension} is state code that calls a function whose vtable index moved, and moving the index didn't fix it. Recompiling state code isn't supported - this is a fatal error.", customPrefix: logCategory);
                    Environment.Exit(1);
                }

                MilanLog.Information($"Recompiling {caller.InstancedFullPath}: it calls a function whose vtable index moved, and moving the index didn't fix it", customPrefix: logCategory);
                var (_, log) = UnrealScriptCompiler.CompileFunction(caller, source, fileLib, usop);
                if (log.HasErrors)
                {
                    MilanLog.LogUSCErrors(log);
                    MilanLog.Fatal($"Failed to recompile {caller.InstancedFullPath} in {package.FileNameNoExtension} - this is a fatal error.", customPrefix: logCategory);
                    Environment.Exit(1);
                }

                if (IsStale(caller, fileLib, usop, out _))
                {
                    MilanLog.Fatal($"{caller.InstancedFullPath} in {package.FileNameNoExtension} still calls a function with the wrong vtable index after recompiling - this is a fatal error.", customPrefix: logCategory);
                    Environment.Exit(1);
                }

                recompiled++;
            }

            MilanLog.Information($"Rebuilt {rebuilt.Count} vtable(s), moved call indexes in {patched} function(s) and recompiled {recompiled} for moved vtable indexes", customPrefix: logCategory);
        }

        /// <summary>
        /// Whether the decompiler finds a call in <paramref name="export"/> whose vtable index doesn't name the function it calls.
        /// </summary>
        /// <param name="source">The decompiled source without the decompiler's error lines.</param>
        private static bool IsStale(ExportEntry export, FileLib fileLib, UnrealScriptOptionsPackage usop, out string source)
        {
            var (_, text) = UnrealScriptCompiler.DecompileExport(export, fileLib, usop);
            source = MilanShared.CleanErrorComments(text, out bool stale);
            return stale;
        }

        /// <summary>
        /// Records the classes whose vtable a patched package changed from vanilla, for <see cref="Apply"/> on later packages
        /// and for <see cref="CheckUnpatchedPackages"/>.
        /// </summary>
        internal static void Observe(string gameFile, byte[] vanilla, byte[] patched)
        {
            using var vanillaPackage = MEPackageHandler.UnsafePartialLoadFromStream(new MemoryStream(vanilla), gameFile, x => x.IsClass);
            using var patchedPackage = MEPackageHandler.UnsafePartialLoadFromStream(new MemoryStream(patched), gameFile, x => x.IsClass);
            foreach (var change in VTableCascade.FindChanges(VTableCascade.ReadAllSlots(vanillaPackage), VTableCascade.ReadAllSlots(patchedPackage)))
                ChangedClasses[change.ClassPath] = change;
        }

        /// <summary>
        /// Logs the classes and calls in LE3 packages LMP ships (<see cref="LMPShippedPackages"/>) that BaseDelta doesn't patch
        /// which the vtable changes leave stale. Mod Manager's slash generation fixes them in the LMP install, so this doesn't fail
        /// the build; it shows what the slash will have to change.
        /// Call once every patched package is built.
        /// </summary>
        /// <param name="patchedFiles">File names of the packages BaseDelta patches, which <see cref="Apply"/> already fixed.</param>
        internal static void CheckUnpatchedPackages(IEnumerable<string> patchedFiles)
        {
            if (ChangedClasses.Count == 0)
            {
                MilanLog.Information("BaseDelta doesn't change any LE3 class's vtable", customPrefix: LOG_CATEGORY);
                return;
            }

            foreach (var change in ChangedClasses.Values.OrderBy(x => x.ClassPath, StringComparer.OrdinalIgnoreCase))
                MilanLog.Information($"BaseDelta changes the vtable of {change.ClassPath} ({change.Before.Count} -> {change.After.Count} entries)", customPrefix: LOG_CATEGORY);

            // Resolved like Mod Manager does: the highest-mounted copy across the basegame and official DLC
            var skip = patchedFiles.ToHashSet(StringComparer.OrdinalIgnoreCase);
            var gameRoot = Path.GetDirectoryName(Path.GetDirectoryName(Path.GetDirectoryName(BaseDeltaHandler.GetVanillaCookedFilePath("SFXGame.pcc"))))!;
            var loadedFiles = MELoadedFiles.GetFilesLoadedInGame(MEGame.LE3, forceReload: true, gameRootOverride: gameRoot, includeModDLC: false);
            var files = new List<string>();
            foreach (var file in LMPShippedPackages.Files.Where(x => !skip.Contains(x)))
            {
                if (loadedFiles.TryGetValue(file, out var path))
                {
                    files.Add(path);
                }
                else if (!loadedFiles.Keys.Any(x => Path.GetFileNameWithoutExtension(x).StartsWith(Path.GetFileNameWithoutExtension(file) + "_", StringComparison.OrdinalIgnoreCase)))
                {
                    // Mod Manager falls back to a package's localized versions, which have no script
                    MilanLog.Fatal($"LMP ships {file}, but LE3 at {gameRoot} has no such package - this is a fatal error.", customPrefix: LOG_CATEGORY);
                    Environment.Exit(1);
                }
            }
            MilanLog.Information($"Checking {files.Count} unpatched LE3 packages LMP ships for script those changes leave stale...", customPrefix: LOG_CATEGORY);

            var baseClasses = GlobalUnrealObjectInfo.GetClasses(MEGame.LE3).ToDictionary(x => x.Key, x => x.Value.baseClass, StringComparer.OrdinalIgnoreCase);
            var problems = VTableCascade.FindStaleScript(files, ChangedClasses.Values, baseClasses);
            if (problems.Count == 0)
            {
                MilanLog.Information("No unpatched LE3 package LMP ships needs a vtable fix", customPrefix: LOG_CATEGORY);
                return;
            }

            MilanLog.Warning($"{problems.Count} class(es) and call(s) in {problems.Select(x => x.Split(':')[0]).Distinct(StringComparer.OrdinalIgnoreCase).Count()} LE3 package(s) LMP ships rely on vtables BaseDelta changed. Mod Manager's slash generation rebuilds their vtables and fixes their calls:", customPrefix: LOG_CATEGORY);
            foreach (var problem in problems.Take(LoggedProblems))
                MilanLog.Warning(problem, customPrefix: LOG_CATEGORY);
            if (problems.Count > LoggedProblems)
                MilanLog.Warning($"... and {problems.Count - LoggedProblems} more", customPrefix: LOG_CATEGORY);
        }
    }
}
