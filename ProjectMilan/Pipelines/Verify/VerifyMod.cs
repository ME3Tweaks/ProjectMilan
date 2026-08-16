using CsvHelper.Configuration;
using LegendaryExplorerCore.GameFilesystem;
using LegendaryExplorerCore.Helpers;
using LegendaryExplorerCore.Misc;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Packages.CloningImportingAndRelinking;
using LegendaryExplorerCore.Shaders;
using LegendaryExplorerCore.Unreal;
using LegendaryExplorerCore.Unreal.BinaryConverters;
using LegendaryExplorerCore.UnrealScript;
using ProjectMilan.Pipelines.Finalize;
using ProjectMilanCore;
using CoreVTables = ProjectMilanCore.VTables;
using System.Diagnostics;

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
                    if (Program.Settings.RunConformancePipeline) // If we didn't run conformance this is pointless to check
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
                var linker = exp.GetLinker();
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
            var tpc = TieredPackageCache.GetGlobalPackageCache(MEGame.LE3).ChainNewCache();

            // This should:
            // Check vtable matching
            // Ensure all class virtual function calls are indexed properly by decompiling each class and ensuring there are no errors.
            FileLib fileLib = null;
            foreach (var f in package.Exports.Where(x => x.IsClass).ToList())
            {
                // Verify the decomp
                UnrealScriptOptionsPackage usop = new UnrealScriptOptionsPackage()
                {
                    Cache = tpc,
                    CustomFileResolver = MilanShared.LE3PackageResolver,
                };

                // Initialize filelib if it wasn't.

                if (fileLib == null || !fileLib.IsInitialized)
                {
                    try
                    {
                        fileLib = new FileLib(package);
                        if (!fileLib.Initialize(usop))
                        {
                            MilanShared.LogFailedFileLibInit(fileLib);
                        }
                    }
                    catch
                    {
                        //we're not checking if it failed to initialize because we don't really care, since decompilation doesn't actually need an initialized filelib,
                        //it just makes the output a bit nicer (at the time of this writing all it does is resolve some integer literals into enum values)
                        MilanLog.Error($"Unable to initialize filelib for {package.FileNameNoExtension}");
                    }
                }

                if (fileLib.IsInitialized && fileLib.HadInitializationError)
                {
                    (_, string functionText) = UnrealScriptCompiler.DecompileExport(f, fileLib, usop);
                    if (functionText.Contains("Recompilation of this function is required"))
                    {
                        MilanLog.Error($"Bad VTable references for virtual calls in {f.InstancedFullPath}");
                    }
                }

                CoreVTables.VerifyVTable(f, tpc, true);
            }
        }
    }
}
