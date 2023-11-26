using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using LegendaryExplorerCore.Packages;

namespace ProjectMilan.Pipelines.Shared
{
    internal static class SharedMaterialDonor
    {
        private const string LOG_CATEGORY = @"MILAN-Donor";

        public static void RegisterLocalDonors(string donorPath)
        {
            if (!Directory.Exists(donorPath))
            {
                // Make donor path but there is nothing to load
                Directory.CreateDirectory(donorPath);
                return;
            }

            var files = Directory.GetFiles(donorPath, "*.pcc", SearchOption.AllDirectories);
            foreach (var file in files)
            {
                MilanLog.Information($"Registering temporary donor package {file}", customPrefix: LOG_CATEGORY);
                var package = MEPackageHandler.UnsafePartialLoad(file, x => false);
                MilanShared.LE3ObjectDB.AddFileToDB(package, package.FilePath);
            }
        }

        public static void UnregisterLocalDonors(string donorPath)
        {
            var files = Directory.GetFiles(donorPath, "*.pcc", SearchOption.AllDirectories);
            foreach (var file in files)
            {
                MilanLog.Information($"Unregistering temporary donor package {file}", customPrefix: LOG_CATEGORY);
                var package = MEPackageHandler.UnsafePartialLoad(file, x => false);
                MilanShared.LE3ObjectDB.AddFileToDB(package, package.FilePath);
            }
        }

        public static void RegisterSharedDonors()
        {
            MilanLog.Information($"Registering global donor packages", customPrefix: LOG_CATEGORY);

            // Add global donors
            var globalPath = Directory.CreateDirectory(GetGlobalDonorPath()).FullName;

            foreach (var donorF in Directory.GetFiles(globalPath, "*.pcc", SearchOption.AllDirectories))
            {
                MilanLog.Information($"  Registering global donor package {Path.GetFileName(donorF)}", customPrefix: LOG_CATEGORY);
                var donorP = MEPackageHandler.UnsafePartialLoad(donorF, x => false);
                MilanShared.LE3ObjectDB.AddFileToDB(donorP, donorF);
            }
        }

        public static string GetGlobalDonorPath()
        {
            return Path.Combine(MilanShared.PipelineRoot, "Shared", "GlobalDonors");
        }

        public static void TryFindDonorsFor(ExportEntry matExp)
        {
            if (matExp.Game != MEGame.ME3)
            {
                // We dont need donors
                throw new Exception("Don't need donors except for ME3!");
            }


        }
    }
}
