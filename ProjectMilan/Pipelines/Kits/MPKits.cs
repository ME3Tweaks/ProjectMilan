using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Packages.CloningImportingAndRelinking;

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

            if (!MilanShared.EnsureMPCommonInGame())
                return;

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

            var outputPath = Path.Combine(Program.Settings.OutputPath, @"LE3", @"Kits");
            Directory.CreateDirectory(outputPath);

            var finalPackagePath = Path.Combine(outputPath, kitPipeline.PackageName + ".pcc");
            var kitDestPackage = MEPackageHandler.CreateAndOpenPackage(finalPackagePath, MEGame.LE3);

            var kitSourcePackage = MilanShared.GetME3Package(kitPipeline.PackageName + ".pcc");

            var objReferencer = kitSourcePackage.Exports.FirstOrDefault(x => x.ClassName == "ObjectReferencer");

            MilanLog.Information("Porting object referencer", customPrefix: kitPipeline.LogCategory);
            var results = EntryImporter.ImportAndRelinkEntries(EntryImporter.PortingOption.CloneAllDependencies, objReferencer,
                kitDestPackage, null, true,
                new RelinkerOptionsPackage() { Cache = kitPipeline.Cache, TargetGameDonorDB = MilanShared.LE3ObjectDB },
                out var newEntry);

            MilanLog.Information("Saving package", customPrefix: kitPipeline.LogCategory);
            kitDestPackage.Save();

            kitPipeline.Cache.Dispose();
        }
    }

    internal class MPKitVars
    {
        public readonly List<KitSpecificPipeline> KitPipelines = new()
        {
            new KitSpecificPipeline() { PackageName="HumanMale_Adept_MP", Enabled=true}
        };
    }
}
