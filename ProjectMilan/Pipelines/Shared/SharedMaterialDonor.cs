using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Unreal;
using LegendaryExplorerCore.Unreal.BinaryConverters;
using LegendaryExplorerCore.Unreal.ObjectInfo;
using ProjectMilanCore;

namespace ProjectMilan.Pipelines.Shared
{
    internal static class SharedMaterialDonor
    {
        internal const string LOG_CATEGORY = @"MILAN-Donor";

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
                var package = MEPackageHandler.OpenMEPackage(file);
                MilanShared.RegisterObjectDBPackage(package);
            }
        }

        public static void UnregisterLocalDonors(string donorPath)
        {
            var files = Directory.GetFiles(donorPath, "*.pcc", SearchOption.AllDirectories);
            foreach (var file in files)
            {
                MilanLog.Information($"Unregistering temporary donor package {file}", customPrefix: LOG_CATEGORY);
                var package = MEPackageHandler.UnsafePartialLoad(file, x => false);
                MilanShared.LE3ObjectDB.RemoveFileFromDB(package);
            }
        }

        public static void RegisterSharedDonors()
        {
            MilanLog.Information($"Registering global donors", customPrefix: LOG_CATEGORY);
            
            // Add global donor packages
            var globalPath = Directory.CreateDirectory(GetGlobalDonorPath()).FullName;

            foreach (var donorF in Directory.GetFiles(globalPath, "*.pcc", SearchOption.AllDirectories))
            {
                MilanLog.Information($"  Registering global donor package {Path.GetFileName(donorF)}", customPrefix: LOG_CATEGORY);
                var donorP = MEPackageHandler.OpenMEPackage(donorF);
                MilanShared.RegisterObjectDBPackage(donorP);
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

        /// <summary>
        /// Gets the shader ID of the given material in string form.
        /// </summary>
        /// <param name="export"></param>
        /// <returns></returns>
        public static string GetShaderIdString(ExportEntry export)
        {
            if (export.ClassName == "Material")
            {
                var bin = ObjectBinary.From<Material>(export);
                return bin.SM3MaterialResource.ID.ToString().Replace(" ", "");
            }

            if (export.IsA("MaterialInstance") && export.GetProperty<BoolProperty>("bHasStaticPermutationResource"))
            {
                var bin = ObjectBinary.From<MaterialInstance>(export);
                return bin.SM3StaticPermutationResource.ID.ToString().Replace(" ", "");
            }

            return null;
        }
    }
}
