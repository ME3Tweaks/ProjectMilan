using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using LegendaryExplorerCore.Helpers;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Packages.CloningImportingAndRelinking;
using LegendaryExplorerCore.Unreal.BinaryConverters;

namespace ProjectMilan.Pipelines.Verify
{
    internal class VerifyMod
    {
        private const string LOG_CATEGORY = @"MILAN-Verify";
        public static void RunPipeline()
        {
            InternalRunPipeline();
        }

        private static void InternalRunPipeline()
        {
            foreach (var f in Directory.GetFiles(Program.Settings.OutputModPath, "*", SearchOption.AllDirectories))
            {
                MilanLog.Information($"Verifying {Path.GetFileName(f)}", customPrefix: LOG_CATEGORY);
                if (f.RepresentsPackageFilePath())
                {
                    // Package file checks
                    var package = MEPackageHandler.OpenMEPackage(f);
                    VerifyVTables(package);
                    CheckForDuplicates(package);
                }
            }
        }

        private static void CheckForDuplicates(IMEPackage package)
        {
            var dupes = EntryChecker.CheckForDuplicateIndices(package);
            foreach (var dupe in dupes)
            {
                MilanLog.Error($"  Duplicate object found: {dupe.Entry?.InstancedFullPath}", customPrefix: LOG_CATEGORY);
            }
        }

        private static void VerifyVTables(IMEPackage package)
        {
            PackageCache cache = new PackageCache();
            foreach (var f in package.Exports.Where(x => x.IsClass))
            {
                if (f.SuperClass == null)
                {
                    continue;
                }
                ExportEntry parent = null;
                if (f.SuperClass is ImportEntry imp)
                {
                    parent = EntryImporter.ResolveImport(imp, cache, fileResolver: MilanShared.LE3ImportResolver);
                }
                else
                {
                    parent = f.SuperClass as ExportEntry;
                }

                if (parent == null)
                    Debugger.Break();
                var vTable = GetVTable(f);
                var parentVTable = GetVTable(parent);

                if (vTable.Count < parentVTable.Count)
                {
                    MilanLog.Error($@"  Invalid VTable size detected in {f.InstancedFullPath}: local count = {vTable.Count}, parent count = {parentVTable.Count}", customPrefix: LOG_CATEGORY);
                }
                int i = 0;
                for (; i < parentVTable.Count; i++)
                {
                    if (i < vTable.Count && !vTable[i].CaseInsensitiveEquals(parentVTable[i]))
                    {
                        MilanLog.Error($@"  Bad VTable detected in {f.InstancedFullPath}: Local[{i}] = {vTable[i]}, Parent[{i}]={parentVTable[i]}", customPrefix: LOG_CATEGORY);
                    }
                }
            }
        }



        private static List<string> GetVTable(ExportEntry export)
        {
            var obj = export.GetBinaryData<UClass>();
            return obj.VirtualFunctionTable.Select(uIdx => export.FileRef.GetEntry(uIdx).ObjectName.Name).ToList();
        }
    }
}
