using System.Collections.Concurrent;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Packages.CloningImportingAndRelinking;
using LegendaryExplorerCore.UnrealScript;
using ProjectMilan.Utility;
using ProjectMilanCore;

namespace ProjectMilan.Pipelines.VTables
{
    /// <summary>
    /// Corrects VTables for classes and fixes virtual function call indexes across the mod
    /// </summary>
    internal class VTablePipeline
    {
        private const string LOG_CATEGORY = @"MILAN-VTables";

        /// <summary>
        /// Safety cap on Pass 1. Parent/child chains across files need a few iterations to settle; anything
        /// beyond this means a class keeps reporting a change that never takes effect.
        /// </summary>
        private const int MAX_PASS1_ITERATIONS = 10;

        public static void RunPipeline()
        {
            InternalRunPipeline();
        }

        private static void InternalRunPipeline()
        {
            var allFiles = Directory.GetFiles(Program.Settings.OutputModPath, "*.pcc", SearchOption.AllDirectories)
                .OrderBy(f => !Path.GetFileNameWithoutExtension(f)
                    .Equals(MilanShared.MP_STARTUP_NAME, StringComparison.OrdinalIgnoreCase))
                .ThenBy(f => f)
                .ToList();

            if (allFiles.Count == 0)
            {
                MilanLog.Warning("No .pcc files found – VTablePipeline has nothing to do.", customPrefix: LOG_CATEGORY);
                return;
            }

            var moves = AlignVTables(allFiles, new MilanPackageCache());

            // A fresh cache, so nothing loaded before Pass 1 wrote its files is reused
            var cache = new MilanPackageCache();

            // ---------------------------------------------------------------
            // Pass 2 – Fix EX_NamedFunction calls whose vtable index no longer
            //          names the function they call.
            // ---------------------------------------------------------------
            MilanLog.Information("Pass 2: Fixing EX_NamedFunction vtable indices...", customPrefix: LOG_CATEGORY);
            int moved = 0, recompiled = 0, failed = 0;
            foreach (var filePath in allFiles)
            {
                try
                {
                    var (fileMoved, fileRecompiled, fileFailed) = FixCalls(filePath, cache, moves);
                    moved += fileMoved;
                    recompiled += fileRecompiled;
                    failed += fileFailed;
                }
                catch (Exception ex)
                {
                    MilanLog.Exception(ex, $"Error during Pass 2 for {Path.GetFileName(filePath)}", customPrefix: LOG_CATEGORY);
                    failed++;
                }
            }

            if (failed > 0)
                MilanLog.Error($"Pass 2: {failed} function(s) or class(es) still call with a wrong vtable index - review log above.", customPrefix: LOG_CATEGORY);
            MilanLog.Information($"Pass 2 complete: moved the index of {moved} call(s) in place, recompiled {recompiled} function(s) or class(es).", customPrefix: LOG_CATEGORY);
        }

        /// <summary>
        /// Pass 1 – rebuilds the vtable of every class in the mod as its parent's followed by its own new functions, in the
        /// class binary (see <see cref="VTableCascade"/>). Every class is loaded once and rebuilt in memory until nothing
        /// changes, so a parent in another file is always current when a child reads it; then the changed files are written.
        /// Nothing is recompiled, so forced export copies of a class, and classes the compiler can't fully resolve, are fixed too.
        /// </summary>
        /// <returns>Where each function that moved went, for fixing the calls to it in Pass 2.</returns>
        private static Func<string, int, int?> AlignVTables(List<string> allFiles, PackageCache cache)
        {
            MilanLog.Information("Pass 1: Aligning VTables across all packages…", customPrefix: LOG_CATEGORY);

            // Every class in the mod, with only class data loaded. A class in several files (a forced export) resolves to the
            // copy in the file that sorts first, which puts BIOP_MP_COMMON's first.
            var loaded = new ConcurrentDictionary<string, IMEPackage>(StringComparer.OrdinalIgnoreCase);
            Parallel.ForEach(allFiles, filePath =>
            {
                var package = MEPackageHandler.UnsafePartialLoad(filePath, x => x.IsClass);
                if (package.Exports.Any(x => x.IsClass))
                    loaded[filePath] = package;
                else
                    package.Dispose();
            });
            var packages = allFiles.Where(loaded.ContainsKey).Select(x => (Path: x, Package: loaded[x])).ToList();

            try
            {
                var classes = new Dictionary<string, ExportEntry>(StringComparer.OrdinalIgnoreCase);
                var before = new Dictionary<string, List<VTableCascade.VTableSlot>>(StringComparer.OrdinalIgnoreCase);
                foreach (var (_, package) in packages)
                {
                    foreach (var classExport in package.Exports.Where(x => x.IsClass))
                        classes.TryAdd(classExport.MemoryFullPath, classExport);
                    foreach (var (classPath, slots) in VTableCascade.ReadAllSlots(package))
                        before.TryAdd(classPath, slots);
                }

                // Parents in the mod come from the classes above; anything else (SFXGame and the rest of LE3, as BaseDelta patched it) from the LE3 cache
                ExportEntry? Resolve(ImportEntry import) => classes.GetValueOrDefault(import.InstancedFullPath)
                                                            ?? EntryImporter.ResolveImport(import, cache, fileResolver: MilanShared.LE3PackageResolver);

                var changedFiles = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
                var unfixable = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
                int iteration = 0;
                bool anyChange;
                do
                {
                    iteration++;
                    anyChange = false;
                    foreach (var (filePath, package) in packages)
                    {
                        if (unfixable.Contains(filePath))
                            continue;
                        try
                        {
                            var rebuilt = VTableCascade.Rebuild(package, Resolve);
                            if (rebuilt.Count > 0)
                            {
                                changedFiles.Add(filePath);
                                anyChange = true;
                                foreach (var classExport in rebuilt)
                                    MilanLog.Information($"  Rebuilding VTable of {classExport.InstancedFullPath} ({Path.GetFileNameWithoutExtension(filePath)})", customPrefix: LOG_CATEGORY);
                            }
                        }
                        catch (Exception ex)
                        {
                            MilanLog.Error($"  Could not rebuild VTables in {Path.GetFileName(filePath)}: {ex.Message}", customPrefix: LOG_CATEGORY);
                            unfixable.Add(filePath);
                        }
                    }
                }
                while (anyChange && iteration < MAX_PASS1_ITERATIONS);

                if (anyChange)
                    MilanLog.Error($"Pass 1 did not converge after {MAX_PASS1_ITERATIONS} iterations - some VTables are still being changed every pass. Verification below will list what is wrong.", customPrefix: LOG_CATEGORY);

                // Write the rebuilt vtables into the files
                foreach (var filePath in changedFiles.Except(unfixable).OrderBy(x => x, StringComparer.OrdinalIgnoreCase))
                {
                    using var package = MEPackageHandler.OpenMEPackage(filePath);
                    if (VTableCascade.Rebuild(package, Resolve).Count > 0)
                    {
                        package.Save(diskIOSyncLock: MilanShared.DiskIOSyncLock);
                        MilanLog.Information($"  Saved {Path.GetFileName(filePath)} after VTable fixes", customPrefix: LOG_CATEGORY);
                    }
                }

                var after = new Dictionary<string, List<VTableCascade.VTableSlot>>(StringComparer.OrdinalIgnoreCase);
                foreach (var (_, package) in packages)
                {
                    foreach (var (classPath, slots) in VTableCascade.ReadAllSlots(package))
                        after.TryAdd(classPath, slots);
                }

                var shifts = VTableCascade.FindShifts(before, after).ToList();
                MilanLog.Information($"Pass 1 complete after {iteration} iteration(s): {changedFiles.Count} file(s) changed, {shifts.Count} function index(es) moved.", customPrefix: LOG_CATEGORY);

                // The mod's script was ported against LE3's vtables, so the calls into classes BaseDelta changed moved too
                shifts.AddRange(Mod.BaseDelta.BaseDeltaVTables.ChangedClasses.Values.SelectMany(x => VTableCascade.FindShifts(x.ClassPath, x.Before, x.After)));

                // Verify – every class's vtable starts with its parent's, resolving parents the same way they were rebuilt. A
                // forced export class resolves to the mod's copy, as the game loads it; LE3's own copies are for the slash to fix.
                MilanLog.Information("Verifying VTables...", customPrefix: LOG_CATEGORY);
                int bad = 0;
                foreach (var (filePath, package) in packages)
                {
                    foreach (var classExport in package.Exports.Where(x => x.IsClass && x.SuperClass != null && !VTableCascade.IsInterface(x)))
                    {
                        var parent = classExport.SuperClass as ExportEntry ?? Resolve((ImportEntry)classExport.SuperClass);
                        if (parent == null)
                        {
                            MilanLog.Error($"  {classExport.InstancedFullPath} ({Path.GetFileNameWithoutExtension(filePath)}): parent {classExport.SuperClass.InstancedFullPath} could not be found", customPrefix: LOG_CATEGORY);
                            bad++;
                            continue;
                        }

                        var names = VTableCascade.ReadSlots(classExport).Select(x => x.Name).ToList();
                        var parentNames = VTableCascade.ReadSlots(parent).Select(x => x.Name).ToList();
                        int mismatch = Enumerable.Range(0, parentNames.Count).FirstOrDefault(i => i >= names.Count || !names[i].Equals(parentNames[i], StringComparison.OrdinalIgnoreCase), -1);
                        if (mismatch >= 0)
                        {
                            MilanLog.Error($"  Bad VTable in {classExport.InstancedFullPath} ({Path.GetFileNameWithoutExtension(filePath)}): [{mismatch}] is {(mismatch < names.Count ? names[mismatch] : "missing")}, but its parent {parent.InstancedFullPath} ({parent.FileRef.FileNameNoExtension}) has {parentNames[mismatch]}", customPrefix: LOG_CATEGORY);
                            bad++;
                        }
                    }
                }
                if (bad > 0)
                    MilanLog.Error($"VTable verification found {bad} class(es) whose vtable doesn't start with their parent's - review log above.", customPrefix: LOG_CATEGORY);
                else
                    MilanLog.Information("All VTables verified OK.", customPrefix: LOG_CATEGORY);

                return VTableCascade.GetMoves(shifts);
            }
            finally
            {
                foreach (var (_, package) in packages)
                    package.Dispose();
            }
        }

        /// <summary>
        /// Pass 2 for one file – decompiles every function and state that makes an EX_NamedFunction call, which checks each
        /// call's index against the class it's called on. In one that's wrong, the calls are moved to the index Pass 1 moved
        /// their function to, in place; if that doesn't fix it, the function is recompiled from its decompiled source (state
        /// code, which can't be compiled on its own, takes its class with it).
        /// </summary>
        /// <returns>Calls moved, functions or classes recompiled, and functions or classes still wrong.</returns>
        private static (int Moved, int Recompiled, int Failed) FixCalls(string filePath, PackageCache cache, Func<string, int, int?> moves)
        {
            using var package = MEPackageHandler.OpenMEPackage(filePath);
            var callers = package.Exports.Where(x => x.ClassName is "Function" or "State" && VTableCascade.ReadNamedFunctionCalls(x).Count > 0).ToList();
            if (callers.Count == 0)
                return (0, 0, 0);

            MilanLog.Information($"Checking {package.FileNameNoExtension}", customPrefix: LOG_CATEGORY);
            var usop = new UnrealScriptOptionsPackage
            {
                Cache = cache,
                CustomFileResolver = MilanShared.LE3PackageResolver,
                BaseFilesFileLib = LE3FileLibCache.GetBaseFilesFileLibFor(package),
            };
            var lib = new FileLib(package);
            if (!lib.Initialize(usop))
            {
                MilanShared.LogFailedFileLibInit(lib);
                return (0, 0, 1);
            }

            bool IsStale(ExportEntry export, out string source)
            {
                var (_, text) = UnrealScriptCompiler.DecompileExport(export, lib, usop);
                source = MilanShared.CleanErrorComments(text, out bool stale);
                return stale;
            }

            int moved = 0, recompiled = 0, failed = 0;
            bool modified = false;
            var stateClasses = new HashSet<ExportEntry>();
            foreach (var export in callers)
            {
                if (!IsStale(export, out var source))
                    continue;

                modified = true;
                int calls = VTableCascade.PatchNamedFunctionCalls(export, moves);
                if (calls > 0 && !IsStale(export, out _))
                {
                    MilanLog.Information($"  Moved the vtable index of {calls} call(s) in {export.InstancedFullPath}", customPrefix: LOG_CATEGORY);
                    moved += calls;
                    continue;
                }

                if (export.ClassName != "Function")
                {
                    // Recompiled with its class below
                    IEntry? owner = export.Parent;
                    while (owner is ExportEntry { IsClass: false } outer)
                        owner = outer.Parent;
                    if (owner is ExportEntry classExport)
                        stateClasses.Add(classExport);
                    continue;
                }

                MilanLog.Information($"  Recompiling {export.InstancedFullPath}: moving its call indexes didn't fix it", customPrefix: LOG_CATEGORY);
                var (_, log) = UnrealScriptCompiler.CompileFunction(export, source, lib, usop);
                if (log.HasErrors || IsStale(export, out _))
                {
                    MilanLog.Error($"  Failed to fix {export.InstancedFullPath} in {package.FileNameNoExtension}", customPrefix: LOG_CATEGORY);
                    MilanLog.LogUSCErrors(log);
                    failed++;
                    continue;
                }
                recompiled++;
            }

            foreach (var classExport in stateClasses)
            {
                MilanLog.Information($"  Recompiling {classExport.InstancedFullPath}: its state code calls with a wrong vtable index", customPrefix: LOG_CATEGORY);
                var (_, classText) = UnrealScriptCompiler.DecompileExport(classExport, lib, usop);
                classText = MilanShared.CleanErrorComments(classText, out _);
                var (_, log) = UnrealScriptCompiler.CompileClass(package, classText, lib, usop, classExport);
                if (log.HasErrors || log.HasLexErrors)
                {
                    MilanLog.Error($"  Failed to recompile {classExport.InstancedFullPath} in {package.FileNameNoExtension}", customPrefix: LOG_CATEGORY);
                    MilanLog.LogUSCErrors(log);
                    failed++;
                    continue;
                }
                recompiled++;
            }

            if (modified)
            {
                MilanLog.Information($"Saving {package.FileNameNoExtension}", customPrefix: LOG_CATEGORY);
                package.Save(diskIOSyncLock: MilanShared.DiskIOSyncLock);
            }
            return (moved, recompiled, failed);
        }
    }
}
