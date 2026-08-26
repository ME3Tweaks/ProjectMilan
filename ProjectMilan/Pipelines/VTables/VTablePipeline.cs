using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.UnrealScript;
using ProjectMilan.Utility;
using ProjectMilanCore;
using CoreVTables = ProjectMilanCore.VTables;

namespace ProjectMilan.Pipelines.VTables
{
    /// <summary>
    /// Corrects VTables for classes and fixes virtual function call indexes across the mod
    /// </summary>
    internal class VTablePipeline
    {
        private const string LOG_CATEGORY = @"MILAN-VTables";

        public static void RunPipeline()
        {
            InternalRunPipeline();
        }

        private static void InternalRunPipeline()
        {
            // ---------------------------------------------------------------
            // Pass 1 – Align VTable ordering on all classes so that the parent
            //          vtable functions always occupy the same indices in child
            //          class vtables.  BIOP_MP_COMMON is processed first so its
            //          classes are stable before any child packages are touched.
            //          We loop until no package changes – this handles chains
            //          that span multiple files (parent in one pkg, child in another).
            // ---------------------------------------------------------------

            MilanLog.Information("Pass 1: Aligning VTable ordering across all packages…", customPrefix: LOG_CATEGORY);

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

            var cache = new MilanPackageCache();

            int pass1Iteration = 0;
            bool anyChangeThisPass;
            do
            {
                pass1Iteration++;
                anyChangeThisPass = false;
                MilanLog.Information($"  Pass 1 iteration {pass1Iteration}...", customPrefix: LOG_CATEGORY);

                foreach (var filePath in allFiles)
                {
                    bool fileModified = false;
                    using var package = MEPackageHandler.OpenMEPackage(filePath);
                    FileLib lib = null;

                    foreach (var export in package.Exports)
                    {
                        if (!export.IsClass) continue;

                        try
                        {
                            if (CoreVTables.FixVTableOrder(export, cache, ref lib))
                                fileModified = true;
                        }
                        catch (Exception ex)
                        {
                            MilanLog.Warning($"  Could not fix VTable for {export.InstancedFullPath} in {Path.GetFileName(filePath)}: {ex.Message}", customPrefix: LOG_CATEGORY);
                        }
                    }

                    if (fileModified)
                    {
                        package.Save(diskIOSyncLock: MilanShared.DiskIOSyncLock);
                        anyChangeThisPass = true;
                        MilanLog.Information($"  Saved {Path.GetFileName(filePath)} after VTable order fixes", customPrefix: LOG_CATEGORY);
                    }
                }
            }
            while (anyChangeThisPass);

            MilanLog.Information($"Pass 1 complete after {pass1Iteration} iteration(s).", customPrefix: LOG_CATEGORY);

            // ---------------------------------------------------------------
            // Verify – confirm all class VTables now match their parent.
            // ---------------------------------------------------------------
            MilanLog.Information("Verifying VTables...", customPrefix: LOG_CATEGORY);
            bool anyBad = false;
            foreach (var filePath in allFiles)
            {
                using var package = MEPackageHandler.OpenMEPackage(filePath);
                foreach (var export in package.Exports)
                {
                    if (!export.IsClass) continue;
                    if (!CoreVTables.VerifyVTable(export, cache, logIfBad: true))
                        anyBad = true;
                }
            }
            if (anyBad)
                MilanLog.Error("VTable verification found errors after Pass 1 - review log above.", customPrefix: LOG_CATEGORY);
            else
                MilanLog.Information("All VTables verified OK.", customPrefix: LOG_CATEGORY);

            // ---------------------------------------------------------------
            // Pass 2 – Walk every Function, State, and scripted Class export
            //          and fix stale EX_NamedFunction vtable indices in the
            //          raw bytecode.
            // ---------------------------------------------------------------
            MilanLog.Information("Pass 2: Patching EX_NamedFunction vtable indices...", customPrefix: LOG_CATEGORY);

            foreach (var filePath in allFiles)
            {
                bool fileModified = false;
                using var package = MEPackageHandler.OpenMEPackage(filePath);
                try
                {
                    if (package.Exports.Any(x => x.ClassName == "Class"))
                    {
                        // Only have to fix files that have classes. Asset packages don't have classes so no point doing that.
                        CoreVTables.RecompileAllClasses(package, cache);
                    }
                }
                catch (Exception ex)
                {
                    MilanLog.Exception(ex, $"Error during Pass 2 for {Path.GetFileName(filePath)}", customPrefix: LOG_CATEGORY);
                }
            }

            MilanLog.Information("Pass 2 complete.", customPrefix: LOG_CATEGORY);
        }
    }
}
