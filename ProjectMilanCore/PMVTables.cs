using LegendaryExplorerCore.Packages.CloningImportingAndRelinking;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Unreal.BinaryConverters;
using ProjectMilan;
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using LegendaryExplorerCore.Helpers;

namespace ProjectMilanCore
{
    public static class VTables
    {
        private const string LOG_CATEGORY = "MILAN-VTables";
        public static bool VerifyVTable(ExportEntry f, PackageCache cache, bool logIfBad = true)
        {
            if (f.SuperClass == null)
            {
                return true;
            }
            ExportEntry parent = null;
            if (f.SuperClass is ImportEntry imp)
            {
                parent = EntryImporter.ResolveImport(imp, cache, fileResolver: MilanShared.LE3PackageResolver);
            }
            else
            {
                parent = f.SuperClass as ExportEntry;
            }

            if (parent == null)
                Debugger.Break();

            bool vTableBad = false;
            var vTable = GetVTable(f);
            var parentVTable = GetVTable(parent);

            if (vTable.Count < parentVTable.Count)
            {
                MilanLog.Error($@"  Invalid VTable size detected in {f.InstancedFullPath}: local count = {vTable.Count}, parent count = {parentVTable.Count}", shouldLog: logIfBad, customPrefix: LOG_CATEGORY);
                if (!logIfBad)
                    return false; // Don't check the rest if we are not logging the results.
                vTableBad = true;
            }
            int i = 0;
            for (; i < parentVTable.Count; i++)
            {
                if (i < vTable.Count && !vTable[i].CaseInsensitiveEquals(parentVTable[i]))
                {
                    MilanLog.Error($@"  Bad VTable detected in {f.InstancedFullPath}: Local[{i}] = {vTable[i]}, Parent[{i}]={parentVTable[i]}", shouldLog: logIfBad, customPrefix: LOG_CATEGORY);
                    if (!logIfBad)
                        return false; // Don't check the rest if we are not logging the results.
                    vTableBad = true;
                }
            }

            // True = good
            return !vTableBad;
        }


        private static List<string> GetVTable(ExportEntry export)
        {
            var obj = export.GetBinaryData<UClass>();
            return obj.VirtualFunctionTable.Select(uIdx => export.FileRef.GetEntry(uIdx).ObjectName.Name).ToList();
        }
    }
}
