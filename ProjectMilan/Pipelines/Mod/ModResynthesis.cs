using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using LegendaryExplorerCore.Helpers;
using LegendaryExplorerCore.Packages;

namespace ProjectMilan.Pipelines.Mod
{

    public static class ModResynthesis
    {
        private const string LOG_CATEGORY = @"Milan-Resynthesis";

        public static void RunPipeline()
        {
            InternalRunPipeline();
        }

        private static void InternalRunPipeline()
        {
            var files = Directory.GetFiles(Program.Settings.OutputModPath, "*.pcc", SearchOption.AllDirectories);
            Parallel.ForEach(files, new ParallelOptions() { MaxDegreeOfParallelism = Program.Settings.MaxThreads },
                file =>
                {
                    MilanLog.Information($"Reconstructing {Path.GetFileName(file)}", customPrefix: LOG_CATEGORY);
                    var package = MEPackageHandler.OpenMEPackage(file);
                    try
                    {
                        var newPackage = PackageResynthesizer.ResynthesizePackage(package);
                        newPackage.Save();

                        // Save as different package for analysis
                        //var outP = Path.Combine(Directory.GetParent(package.FilePath).FullName, $"{package.FileNameNoExtension}_RESYNTH.pcc");
                        //newPackage.Save(outP);

                        // Some verification
                        foreach (var exp in package.Exports)
                        {
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
