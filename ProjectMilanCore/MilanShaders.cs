using LegendaryExplorerCore.Misc;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Shaders;
using LegendaryExplorerCore.Unreal;
using LegendaryExplorerCore.Unreal.BinaryConverters;
using ProjectMilan;
using System;
using System.Collections.Generic;
using System.Text;

namespace ProjectMilanCore
{
    public static class MilanShaders
    {
        /// <summary>
        /// Installs shaders to the package for materials that are marked as broken. If a material isn't broken,
        /// this won't update their shaders!
        /// </summary>
        /// <param name="target"></param>
        public static void InstallCompiledShadersToPackage(IMEPackage package, string logCategory)
        {
            var decookedPath = @"E:\CompiledShaderPackages";
            var compiledShaderPath = @"E:\CompiledShaderPackages";
            var compiledShaderPackages = Directory.GetFiles(compiledShaderPath, "*.pcc");
            CaseInsensitiveDictionary<string> packageMap = new();
            var cache = new PackageCache();
            foreach (var p in compiledShaderPackages)
            {
                packageMap[Path.GetFileNameWithoutExtension(p)] = p;
            }

            var brokenMaterials = ShaderCacheManipulator.GetBrokenMaterials(package);
            foreach (var brokenMat in brokenMaterials)
            {
                var linker = brokenMat.GetLinker();
                if (packageMap.TryGetValue(linker, out var cmp))
                {
                    var compiledPackage = cache.GetCachedPackage(cmp);
                    var csc = compiledPackage.FindExport("SeekFreeShaderCache");
                    if (csc == null)
                        // dunno what happened here.
                        continue;

                    var matchingMat = compiledPackage.FindExport(brokenMat.MemoryFullPath, brokenMat.ClassName) ?? compiledPackage.FindExport(brokenMat.InstancedFullPath, brokenMat.ClassName);
                    if (matchingMat == null)
                    {
                        // couldn't find the mat
                        MilanLog.Warning($"No compiled shaders for {brokenMat.InstancedFullPath} in {package.FileNameNoExtension}", customPrefix: logCategory);
                    }
                    else
                    {
                        MilanLog.Information($"Updating shadercache for {brokenMat.InstancedFullPath}", customPrefix: logCategory);
                        var shaderCache = ObjectBinary.From<ShaderCache>(csc);
                        ShaderCacheManipulator.AddShadersToFile(package, shaderCache);
                        // update the id of the material to match the compiled version
                        var matchingMatBin = ObjectBinary.From<Material>(matchingMat);
                        ObjectBinary.EditBinary<Material>(brokenMat, x => x.SM3MaterialResource.ID = matchingMatBin.SM3MaterialResource.ID);

                        brokenMat.WriteProperty(new BoolProperty(true, "bUsedWithStaticLighting"));
                        brokenMat.WriteProperty(new BoolProperty(true, "bUsedWithVectorLightMaps"));
                        brokenMat.WriteProperty(new BoolProperty(true, "bUsedWithSimpleLightMaps"));
                    }
                }
            }

            MilanLog.Information($"Compacting ShaderCache", customPrefix: logCategory);
            ShaderCacheManipulator.CompactSeekFreeShaderCaches(package);
#if DEBUG
            // Disabled for now, we know a bunch will be broken
            if (false)
            {
                brokenMaterials = ShaderCacheManipulator.GetBrokenMaterials(package);
                foreach (var mat in brokenMaterials)
                {
                    MilanLog.Error($@"  Shader still broken for {mat.InstancedFullPath}");
                }
            }

#endif
        }
    }
}
