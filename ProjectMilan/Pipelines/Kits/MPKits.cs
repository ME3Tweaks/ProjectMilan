using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Packages.CloningImportingAndRelinking;
using LegendaryExplorerCore.UnrealScript;
using static System.Net.Mime.MediaTypeNames;

namespace ProjectMilan.Pipelines.Kits
{
    /// <summary>
    /// Pipeline for porting MP characters (kits)
    /// </summary>
    internal class MPKits
    {
        private const string LOG_CATEGORY = "MILAN-MPKit";
        public static void RunPipeline()
        {
            var vars = new MPKitVars();
            InternalRunPipeline(vars);
        }

        private static void InternalRunPipeline(MPKitVars vars)
        {
            // Extract TFCs from SFAR
            //ExtractTFCs();
            foreach (var kit in vars.KitPipelines)
            {
                if (!kit.Enabled)
                {
                    // This level is not marked for porting currently.
                    MilanLog.Information($"Skipping kit {kit.PackageName}, pipeline is not enabled", customPrefix: LOG_CATEGORY);
                    continue;
                }

                BeginPorting(kit);
            }
        }

        private static void BeginPorting(KitSpecificPipeline kitPipeline)
        {
            kitPipeline.LogCategory = $"{LOG_CATEGORY}-{kitPipeline.PackageName}";

            // Initialize cache
            kitPipeline.Cache = new PackageCache();

            var outputPath = Path.Combine(Program.Settings.OutputModPath, @"CookedPCConsole", @"Kits");
            Directory.CreateDirectory(outputPath);

            var finalPackagePath = Path.Combine(outputPath, kitPipeline.PackageName + ".pcc");
            var kitDestPackage = MEPackageHandler.CreateAndOpenPackage(finalPackagePath, MEGame.LE3);
            kitDestPackage.LECLTagData.ImportHintFiles.Add(MilanShared.MP_STARTUP_FILENAME); // Hint this for importing.

            var kitSourcePackage = MilanShared.GetME3Package(kitPipeline.PackageName + ".pcc");

            // Port classes first - this works around weird issue in tools where you're porting across games
            // an entirely new class which doesn't exist in the destination game

            //foreach (var cls in kitSourcePackage.Exports.Where(x => x.IsClass))
            //{
            //    if (kitDestPackage.FindExport(cls.InstancedFullPath) == null)
            //    {
            //        var rop2 = new RelinkerOptionsPackage() { Cache = kitPipeline.Cache, TargetGameDonorDB = MilanShared.LE3ObjectDB };
            //        var results2 = EntryImporter.ImportAndRelinkEntries(EntryImporter.PortingOption.CloneAllDependencies, cls,
            //            kitDestPackage, null, true,
            //            rop2,
            //            out var newEntry2);
            //    }
            //}



            var objReferencer = kitSourcePackage.Exports.FirstOrDefault(x => x.ClassName == "ObjectReferencer");

            MilanLog.Information("Porting object referencer", customPrefix: kitPipeline.LogCategory);
            var rop = new RelinkerOptionsPackage()
            {
                Cache = kitPipeline.Cache,
                TargetGameDonorDB = MilanShared.LE3ObjectDB,
                PortExportsAsImportsWhenPossible = true,
                GenerateImportsForGlobalFiles = true
            };
            var results = EntryImporter.ImportAndRelinkEntries(EntryImporter.PortingOption.CloneAllDependencies, objReferencer,
                kitDestPackage, null, true,
                rop,
                out var newEntry);

            // Not sure - do we need to make sure this needs done recursively in order? Topmost to bottommost
            MilanLog.Information("Recompiling ported classes", customPrefix: kitPipeline.LogCategory);
            FileLib lib = new FileLib(kitDestPackage);
            lib.Initialize(kitPipeline.Cache);

            foreach (var f in rop.CrossPackageMap.Values.OfType<ExportEntry>().Where(x => x.IsClass))
            {
                // Recompile all ported classes so vtables are updated
                MilanLog.Information($"  Recompiling {f.ObjectName}", customPrefix: kitPipeline.LogCategory);
                // This is broken!!
                try
                {
                    (_, string text) = UnrealScriptCompiler.DecompileExport(f, lib, kitPipeline.Cache);
                    UnrealScriptCompiler.CompileClass(kitDestPackage, text, lib, f, packageCache: kitPipeline.Cache);
                }
                catch (Exception e)
                {
                    MilanLog.Exception(e, "  Error recompiling function:");
                }
            }

            MilanLog.Information("Saving package", customPrefix: kitPipeline.LogCategory);
            kitDestPackage.Save();

            kitPipeline.Cache.Dispose();
        }
    }

    internal class MPKitVars
    {
        public readonly List<KitSpecificPipeline> KitPipelines = new()
        {
            new KitSpecificPipeline() { PackageName = "HumanMale_Adept_MP", Enabled = true}
        };
    }
}
