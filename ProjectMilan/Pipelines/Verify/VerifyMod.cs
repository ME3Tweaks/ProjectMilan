using System.Diagnostics;
using LegendaryExplorerCore.GameFilesystem;
using LegendaryExplorerCore.Helpers;
using LegendaryExplorerCore.Misc;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Packages.CloningImportingAndRelinking;
using LegendaryExplorerCore.Shaders;
using LegendaryExplorerCore.Unreal;
using LegendaryExplorerCore.Unreal.BinaryConverters;
using ProjectMilan.Pipelines.Finalize;
using ProjectMilanCore;

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
            var afcFilesReferenced = new HashSet<string>();

            // Map of Package -> Map of IFP -> NetIndex
            var netIndexes = new CaseInsensitiveDictionary<CaseInsensitiveDictionary<int>>();
            foreach (var f in Directory.GetFiles(Program.Settings.OutputModPath, "*", SearchOption.AllDirectories))
            {
                MilanLog.Information($"Verifying {Path.GetFileName(f)}", customPrefix: LOG_CATEGORY);
                if (f.RepresentsPackageFilePath())
                {
                    // Package file checks
                    var package = MEPackageHandler.OpenMEPackage(f);
                    VerifyVTables(package);
                    RunEntryChecks(package);
                    NetIndexCheck(package, netIndexes);
                    CollectAFCFileNames(package, afcFilesReferenced);
                }
            }

            LogAFCsNotInModOrBasegame(afcFilesReferenced);
        }

        private static void NetIndexCheck(IMEPackage package, CaseInsensitiveDictionary<CaseInsensitiveDictionary<int>> netIndexes)
        {
            foreach (var exp in package.Exports)
            {
                var linker = Conformance.GetLinker(exp);
                if (!netIndexes.TryGetValue(linker, out var indicesUnderLinker))
                {
                    indicesUnderLinker = new CaseInsensitiveDictionary<int>();
                    netIndexes[linker] = indicesUnderLinker;
                }

                var netIndex = exp.NetIndex;
                if (netIndex != -1)
                {
                    if (indicesUnderLinker.TryGetValue(exp.InstancedFullPath, out var existing))
                    {
                        if (existing != netIndex)
                        {
                            MilanLog.Error($"NetIndex does not match other exports in another package: {exp.InstancedFullPath}. Already found one with NetIndex {existing} but this one has NetIndex {netIndex}", customPrefix: LOG_CATEGORY);
                        }
                    }
                    else
                    {
                        indicesUnderLinker[exp.InstancedFullPath] = netIndex;
                    }
                }
                else if (exp.ClassName != "Package")
                {
                    // Todo: This needs fleshed out for proper cases. 
                    // Check if there are -1 NetIndexes that are not package
                    // MilanLog.Warning($"NetIndex is -1: {exp.InstancedFullPath}", customPrefix: LOG_CATEGORY);
                }

            }
        }

        private static void CollectAFCFileNames(IMEPackage package, HashSet<string> afcSet)
        {
            foreach (var exp in package.Exports.Where(x => x.ClassName == @"WwiseStream"))
            {
                var filename = exp.GetProperties().GetProp<NameProperty>("Filename").Value;
                afcSet.Add(Path.ChangeExtension(filename, ".afc"));
            }
        }

        private static void LogAFCsNotInModOrBasegame(HashSet<string> afcFilesReferenced)
        {
            var le3LoadedFiles = MELoadedFiles.GetFilesLoadedInGame(MEGame.LE3, includeAFCs: true);

            var afcsInMod = Directory.GetFileSystemEntries(Program.Settings.OutputModPath, "*.afc",
                SearchOption.AllDirectories).Select(e => Path.GetFileName(e)).ToList();

            foreach (var afc in afcFilesReferenced)
            {
                if (!le3LoadedFiles.ContainsKey(afc) && !afcsInMod.Contains(afc))
                {
                    MilanLog.Error($"  Missing referenced AFC file: {afc}", customPrefix: LOG_CATEGORY);
                }
            }
        }

        private static void RunEntryChecks(IMEPackage package)
        {
            var dupes = EntryChecker.CheckForDuplicateIndices(package);
            foreach (var dupe in dupes)
            {
                MilanLog.Error($"  Duplicate object found: {dupe.Entry?.InstancedFullPath}", customPrefix: LOG_CATEGORY);
            }

            var brokenMaterials = ShaderCacheManipulator.GetBrokenMaterials(package);
            foreach (var v in brokenMaterials)
            {
                MilanLog.Error($"  Material has no shader: {v.InstancedFullPath}", customPrefix: LOG_CATEGORY);

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
                    parent = EntryImporter.ResolveImport(imp, cache, fileResolver: MilanShared.LE3PackageResolver);
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
