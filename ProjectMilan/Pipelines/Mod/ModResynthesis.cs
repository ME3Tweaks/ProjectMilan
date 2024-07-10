using System.Diagnostics;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Unreal.BinaryConverters;

namespace ProjectMilan.Pipelines.Mod
{

    public static class ModResynthesis
    {
        private const string LOG_CATEGORY = @"MILAN-Resynthesis";

        public static void RunPipeline()
        {
            InternalRunPipeline();
        }

        private static void InternalRunPipeline()
        {
            var files = Directory.GetFiles(Program.Settings.OutputModPath, "*.pcc", SearchOption.AllDirectories);
            TieredPackageCache cache = TieredPackageCache.GetGlobalPackageCache(MEGame.LE3); // Do not use the MPCommon cache as we will be modifying that package.
            Parallel.ForEach(files, new ParallelOptions() { MaxDegreeOfParallelism = Program.Settings.MaxThreads },
                file =>
                {
                    MilanLog.Information($"Reconstructing {Path.GetFileName(file)}", customPrefix: LOG_CATEGORY);
                    var package = MEPackageHandler.OpenMEPackage(file);
                    try
                    {
                        // Custom fix for loose class comp
                        var sfxEPackage = package.FindExport("SFXGame", "Package");
                        var sfxIPackage = package.FindImport("SFXGame", "Package");
                        if (sfxEPackage != null && sfxIPackage != null)
                        {
                            foreach (var entry in sfxIPackage.GetChildren())
                            {
                                entry.Parent = sfxEPackage;
                            }
                            EntryPruner.TrashEntryAndDescendants(sfxIPackage); // Get rid of this pre-porting.
                        }

                        var newPackage = PackageResynthesizer.ResynthesizePackage(package, cache.ChainNewCache());
                        newPackage.Save();

                        // Save as different package for analysis
                        //var outP = Path.Combine(Directory.GetParent(package.FilePath).FullName, $"{package.FileNameNoExtension}_RESYNTH.pcc");
                        //newPackage.Save(outP);

                        // Some verification
                        foreach (var exp in package.Exports)
                        {
                            if (exp.IsTrash())
                                continue; // We don't care
                            var nExp = newPackage.FindExport(exp.InstancedFullPath);
                            if (nExp == null)
                                Debugger.Break();

                            if (nExp.DataSize != exp.DataSize)
                                MilanLog.Error($"Size of export changed in resynthesis: {nExp.InstancedFullPath}", customPrefix: LOG_CATEGORY);

                            if (nExp.ClassName != exp.ClassName)
                                MilanLog.Error($"Class changed of export : {nExp.InstancedFullPath} to {nExp.ClassName}", customPrefix: LOG_CATEGORY);

                            if (nExp.Archetype?.InstancedFullPath != exp.Archetype?.InstancedFullPath)
                                MilanLog.Error($"Archetype changed of export : {nExp.InstancedFullPath} to {nExp.Archetype?.InstancedFullPath} from {exp.Archetype?.InstancedFullPath}", customPrefix: LOG_CATEGORY);

                            if (nExp.SuperClassName != exp.SuperClassName)
                                MilanLog.Error($"SuperClass changed of export : {nExp.InstancedFullPath} to {nExp.SuperClassName} from {exp.SuperClassName}", customPrefix: LOG_CATEGORY);

                            if (nExp.ObjectFlags != exp.ObjectFlags)
                                MilanLog.Error($"ObjectFlags changed of export : {nExp.InstancedFullPath} to {nExp.ObjectFlags} from {exp.ObjectFlags}", customPrefix: LOG_CATEGORY);

                            if (nExp.SuperClassName != exp.SuperClassName)
                                MilanLog.Error($"SuperClass changed of export : {nExp.InstancedFullPath} to {nExp.SuperClassName} from {exp.SuperClassName}", customPrefix: LOG_CATEGORY);

                            if (nExp.ExportFlags != exp.ExportFlags)
                                MilanLog.Error($"ExportFlags changed of export : {nExp.InstancedFullPath} to {nExp.ExportFlags} from {exp.ExportFlags}", customPrefix: LOG_CATEGORY);

                            if (nExp.PackageGUID != exp.PackageGUID)
                                MilanLog.Error($"PackageGuid changed of export : {nExp.InstancedFullPath} to {nExp.PackageGUID} from {exp.PackageGUID}", customPrefix: LOG_CATEGORY);

                        }
                    }
                    catch (Exception ex)
                    {
                        MilanLog.Exception(ex, $"Error resynthesizing package: {package.FileNameNoExtension}");
                    }
                });
        }
    }
}
