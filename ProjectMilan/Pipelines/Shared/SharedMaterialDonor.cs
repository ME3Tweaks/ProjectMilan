using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Unreal;
using LegendaryExplorerCore.Unreal.BinaryConverters;
using LegendaryExplorerCore.Unreal.ObjectInfo;
using ProjectMilan.Pipelines.Shared.GlobalDonors.Material;

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
            
            // Material swaps directly.
            ShaderMapping = GlobalMaterial.GetMapping(); // This returns a clone

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
        /// Maps shaders between games. This effectively is the material donor.
        /// </summary>
        private static Dictionary<Guid, Guid> ShaderMapping = new();
        public static bool GetDonorForShader(Guid ogShader, out Guid leShader)
        {
            if (ShaderMapping.TryGetValue(ogShader, out leShader))
            {
                return true;
            }

            /*
            if (TemporaryShaderMapping.TryGetValue(ogShader, out var leShader))
            {
                return leShader;
            }*/

            // MilanLog.Warning($"Could not find mapping for OG shader {ogShader}");
            return false;
        }

        /// <summary>
        /// Uses the known direct material shader id converter for materials that support it.
        /// </summary>
        /// <param name="package"></param>
        public static void UpdateMaterialShaders(IMEPackage package)
        {
            MilanLog.Information("Updating shader ids", customPrefix: LOG_CATEGORY);
            foreach (var export in package.Exports.Where(x => !x.IsDefaultObject && x.IsA("MaterialInterface")))
            {
                if (export.ClassName == "Material")
                {
                    var bin = ObjectBinary.From<Material>(export);
                    if (GetDonorForShader(bin.SM3MaterialResource.ID, out var leShader))
                    {
                        MilanLog.Information($"  Updated shader for {export.InstancedFullPath}", customPrefix: LOG_CATEGORY);
                        bin.SM3MaterialResource.ID = leShader;
                        export.WriteBinary(bin);
                    }
                }
                else if (export.IsA("MaterialInstance") && export.GetProperty<BoolProperty>("bHasStaticPermutationResource"))
                {
                    var bin = ObjectBinary.From<MaterialInstance>(export);
                    if (GetDonorForShader(bin.SM3StaticPermutationResource.ID, out var leShader))
                    {
                        MilanLog.Information($"  Updated shader for {export.InstancedFullPath}", customPrefix: LOG_CATEGORY);
                        bin.SM3StaticPermutationResource.ID = leShader;
                        export.WriteBinary(bin);
                    }
                }
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
