using LegendaryExplorerCore.Misc;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Packages.CloningImportingAndRelinking;
using LegendaryExplorerCore.Shaders;
using LegendaryExplorerCore.Unreal;
using LegendaryExplorerCore.Unreal.BinaryConverters;
using LegendaryExplorerCore.Unreal.ObjectInfo;
using ProjectMilan;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;

namespace ProjectMilanCore
{
    public static class MilanShaders
    {
        /// <summary>
        /// Maps old material <c>InstancedFullPath</c> values to new ones for cases where a developer renamed
        /// a material between builds of the game. The key is the old path as it appears in the ported content
        /// (e.g. <c>"BIOA_STA60_T.TRIMS02"</c>) and the value is the corresponding path in the compiled
        /// shader packages (e.g. <c>"BIOA_STA60_02_T.TRIMS02"</c>). The linker for the compiled package
        /// lookup is derived from the first dot-separated segment of the remapped path.
        /// </summary>
        public static Dictionary<string, string> MaterialPathRemap { get; } = new(StringComparer.OrdinalIgnoreCase)
        {
            // Crossgen, LE1:
            // BioWare in LE1 renamed some packages (going from ME1 -> LE1) and split them into new ones, possibly because they got too big for Unreal in source side.
            // We manually fixed this in crossgen but we have to manually fix it again here
            // Making our lives miserable
            { "BIOA_STA60_T.STA60_TRIMS02", "BIOA_STA60_02_T.STA60_TRIMS02" },
            { "BIOA_STA60_T.STA60_WALL02", "BIOA_STA60_02_T.STA60_WALL02" },
            { "CROSSGENV.BlackTextureMat", "BIOA_PRC2_MatFX.BlackOut_MAT" }, // This is effectively a donor material, but it's a black material, so I really don't care. A donor of a donor if you will.
            { "BIOA_JUG80_T.JUG80_SAIL_mat", "BIOA_JUG80_T.JUG80_SAIL" }, // This god damn material has been such a pain for YEARS 
            { "BIOA_PRC2_T.LAVCubemap.LAV60_PANNELWALL03_Dup", "BIOA_DLC_UNC52_T.LAV60_PANNELWALL03_Dup" }, // Lava - donors in Crossgen
            { "BIOA_PRC2_T.LAVCubemap.LAV60_PANNELWALL02_Dup", "BIOA_LAV60_T.LAV60_PANNELWALL02" }, // Lava - donors in Crossgen
            { "BIOA_PRC2_T.LAVCubemap.LAV60_SILO01_Dup" , "BIOA_DLC_UNC52_T.LAV60_SILO01_Dup" }, // Lava - donors in Crossgen
            { "BIOA_JUG80_T.JUG80_POD01_CROSSGEN", "BIOA_LOS10_T.LOS10_Gethlamp" }, // Custom Audemus lightpost thing used in Tropical to fix the emis
            { "BIOA_ICE60_T.checker_mat", "BIOA_ICE60_T.checker" }, // we renamed this in crossgen cause of name collision
        };

        /// <summary>
        /// True for a MaterialInstance that owns a static permutation, i.e. one the engine compiles a
        /// separate shader map for instead of reusing its parent's.
        /// </summary>
        /// <remarks>
        /// Static switch, component mask and normal parameters are compile-time, so an instance that
        /// overrides any of them cannot share the parent's shaders. Instances without a permutation
        /// render through the parent's map and need nothing installed.
        /// </remarks>
        private static bool IsPermutationInstance(ExportEntry export) =>
            export.IsA("MaterialInstance")
            && export.GetProperty<BoolProperty>("bHasStaticPermutationResource")?.Value == true;

        /// <summary>
        /// Installs shaders to the package for materials that are marked as broken. If a material isn't broken,
        /// this won't update their shaders, unless <paramref name="force"/> is set.
        /// </summary>
        /// <param name="target"></param>
        /// <param name="force">If true, reinstalls every material that has a matching compiled package, regardless of
        /// whether it's currently considered "broken". A material is only "broken" when its shader ID is entirely
        /// absent from the local/ref shader cache, so once a material has been installed once, normal (non-force)
        /// installs will never touch it again even if a newer compile is available. Force bypasses that check and
        /// also overwrites (rather than skips) any existing shader map/shader entries for that material.</param>
        public static void InstallCompiledShadersToPackage(IMEPackage package, string logCategory, bool force = false)
        {
            var decookedPath = @"E:\CompiledShaderPackages";
            var compiledShaderPath = @"E:\CompiledShaderPackages";
            if (Directory.Exists(compiledShaderPath) == false)
            {
                MilanLog.Error($"Compiled shader path not found: {compiledShaderPath} - skipping shader install", customPrefix: logCategory);
                return;
            }
            var compiledShaderPackages = Directory.GetFiles(compiledShaderPath, "*.pcc");
            CaseInsensitiveDictionary<string> packageMap = new();
            var cache = new PackageCache();
            foreach (var p in compiledShaderPackages)
            {
                packageMap[Path.GetFileNameWithoutExtension(p)] = p;
            }

            // MaterialInstances with a static permutation own a shader map of their own, keyed by their
            // SM3StaticParameterSet rather than by a material resource ID. GetBrokenMaterials already
            // returns them; the force path has to ask for them explicitly.
            var materialsToProcess = force
                ? package.Exports.Where(x => x.IsA("Material") || IsPermutationInstance(x)).ToList()
                : ShaderCacheManipulator.GetBrokenMaterials(package);

            // Source shader caches are deserialized once per compiled package and merged into a single
            // accumulator, which is written to the destination package exactly once at the end. Doing this
            // per-material instead (as before) meant repeatedly deserializing/reserializing the destination's
            // SeekFreeShaderCache binary, which grows every iteration - O(n^2) for a package with many broken materials.
            var sourceShaderCaches = new Dictionary<IMEPackage, ShaderCache>();
            var accumulatedCache = ShaderCache.Create();
            bool anyShadersToInstall = false;

            foreach (var brokenMat in materialsToProcess)
            {
                var isInstance = IsPermutationInstance(brokenMat);
                if (!brokenMat.IsA("Material") && !isInstance)
                {
                    continue;
                }

                var linker = brokenMat.GetLinker();
                ExportEntry matchingMat = null;
                IMEPackage shaderSourcePackage = null;

                // Primary lookup: find a compiled package whose filename matches the material's linker.
                if (packageMap.TryGetValue(linker, out var cmp))
                {
                    var compiledPackage = cache.GetCachedPackage(cmp);
                    if (compiledPackage.FindExport("SeekFreeShaderCache") != null)
                    {
                        shaderSourcePackage = compiledPackage;
                        matchingMat = compiledPackage.FindExport(brokenMat.MemoryFullPath, brokenMat.ClassName)
                                   ?? compiledPackage.FindExport(brokenMat.InstancedFullPath, brokenMat.ClassName);

                        if (matchingMat == null)
                        {
                            // Try just finding it by name...
                            var matchingPossibilities = compiledPackage.Exports.Where(x => x.ClassName == brokenMat.ClassName && x.ObjectName.Instanced == brokenMat.ObjectName).ToList();
                            if (matchingPossibilities.Count == 1)
                            {
                                MilanLog.Warning($"Found material using name-match only. Decooker needs nesting fixes most likely.");
                                matchingMat = matchingPossibilities[0];
                            }
                            else if (matchingPossibilities.Count > 0)
                            {
                                MilanLog.Error($"Multiple same-name materials in decooked package for {brokenMat.InstancedFullPath} in {package.FileNameNoExtension}; unable to safely choose, decooker needs fixed", customPrefix: logCategory);
                            }
                        }
                    }
                }

                // Remap fallback: the material was renamed between game builds. Check the explicit remap
                // dictionary and retry against the compiled package for the remapped path's linker.
                if (matchingMat == null && MaterialPathRemap.TryGetValue(brokenMat.InstancedFullPath, out var remappedPath))
                {
                    var remappedLinker = remappedPath.Split('.')[0];
                    if (packageMap.TryGetValue(remappedLinker, out var remappedCmp))
                    {
                        var remappedPackage = cache.GetCachedPackage(remappedCmp);
                        if (remappedPackage.FindExport("SeekFreeShaderCache") != null)
                        {
                            shaderSourcePackage = remappedPackage;
                            matchingMat = remappedPackage.FindExport(remappedPath, brokenMat.ClassName);
                            if (matchingMat != null)
                                MilanLog.Information($"Found material via path remap: {brokenMat.InstancedFullPath} -> {remappedPath}", customPrefix: logCategory);
                            else
                                MilanLog.Warning($"Path remap for {brokenMat.InstancedFullPath} -> {remappedPath} did not find a matching material in the compiled package", customPrefix: logCategory);
                        }
                    }
                    else
                    {
                        MilanLog.Warning($"Path remap for {brokenMat.InstancedFullPath} targets linker '{remappedLinker}' but no compiled package was found for it", customPrefix: logCategory);
                    }
                }

                if (matchingMat == null)
                {
                    // couldn't find the mat
                    MilanLog.Error($"No compiled shaders for {brokenMat.InstancedFullPath} ({brokenMat.ClassName}) in {package.FileNameNoExtension}", customPrefix: logCategory);
                }
                else
                {
                    MilanLog.Information($"Updating shadercache for {brokenMat.InstancedFullPath}", customPrefix: logCategory);
                    if (!sourceShaderCaches.TryGetValue(shaderSourcePackage, out var shaderCache))
                    {
                        var csc = shaderSourcePackage.FindExport("SeekFreeShaderCache");
                        shaderCache = ObjectBinary.From<ShaderCache>(csc);
                        sourceShaderCaches[shaderSourcePackage] = shaderCache;
                        shaderCache.MergeInto(accumulatedCache);
                    }
                    anyShadersToInstall = true;

                    if (isInstance)
                    {
                        // Replace the instance wholesale instead of copying the parameter set and the
                        // resource ID onto whatever binary the destination already had.
                        //
                        // An instance's shader map is keyed by its whole SM3StaticParameterSet (which
                        // carries BaseMaterialId, and that has to match the compiled parent's resource ID.
                        // The Material branch below rewrites exactly that ID, so an instance left on
                        // the old one would key into nothing and render the engine's fallback). The
                        // compiled permutation resource that goes with it holds uniform expressions whose
                        // texture references are UIndexes into the *compiled* package, so hand-copying the
                        // binary would leave them pointing at whatever sits at those indexes here.
                        // Relinking translates them and adds the cross-imports.
                        //
                        // Taking the compiled resource wholesale is also the point, not a side effect.
                        // LE3 itself produced this blob, for these exact shaders. Whatever the destination
                        // is carrying came from ME3 by way of the port, and ME3 and LE3 can differ subtly
                        // in what the resource holds, so the game's own output is the one to trust.
                        //
                        // Replacing the properties along with the binary is safe under engine rules: a
                        // dependency that already exists under the same name is the same object, so the
                        // relinked Parent resolves to the parent already in this package rather than
                        // duplicating it.
                        var badLinks = EntryImporter.ImportAndRelinkEntries(
                            EntryImporter.PortingOption.ReplaceSingularWithRelink, matchingMat, package, brokenMat,
                            true, new RelinkerOptionsPackage()
                            {
                                Cache = cache,
                                // Both sides are LE3 here: the compiled shader packages are built from the
                                // decooked LE3 output, not from ME3 donors.
                                SourceCustomImportFileResolver = MilanShared.LE3PackageResolver,
                                DestinationCustomImportFileResolver = MilanShared.LE3PackageResolver,
                                TargetGameDonorDB = MilanShared.LE3ObjectDB,
                                PortExportsAsImportsWhenPossible = true,
                            }, out _);

                        foreach (var badLink in badLinks)
                        {
                            MilanLog.Error($"Relink issue installing permutation for {brokenMat.InstancedFullPath}: {badLink.Message}", customPrefix: logCategory);
                        }

                        // The installed map is only reachable if the instance still asks for one. The
                        // replace brings the flag across with the rest of the properties; writing it
                        // anyway means a compiled package that somehow lacks it cannot produce a silently
                        // dead install.
                        brokenMat.WriteProperty(new BoolProperty(true, "bHasStaticPermutationResource"));

                        // No bUsedWith* here: those are UMaterial fields. The parent carries them.
                        continue;
                    }

                    // update the id of the material to match the compiled version
                    var matchingMatBin = ObjectBinary.From<Material>(matchingMat);
                    ObjectBinary.EditBinary<Material>(brokenMat, x => x.SM3MaterialResource.ID = matchingMatBin.SM3MaterialResource.ID);

                    brokenMat.WriteProperty(new BoolProperty(true, "bUsedWithStaticLighting"));
                    brokenMat.WriteProperty(new BoolProperty(true, "bUsedWithVectorLightMaps"));
                    brokenMat.WriteProperty(new BoolProperty(true, "bUsedWithSimpleLightMaps"));
                }
            }

            if (anyShadersToInstall)
            {
                ShaderCacheManipulator.AddShadersToFile(package, accumulatedCache, overwrite: force);
            }

            MilanLog.Information($"Compacting ShaderCache ({package.FileNameNoExtension})", customPrefix: logCategory);
            ShaderCacheManipulator.CompactSeekFreeShaderCaches(package);
#if DEBUG
            // Disabled for now, we know a bunch will be broken
            if (false)
            {
                var brokenMaterials = ShaderCacheManipulator.GetBrokenMaterials(package);
                foreach (var mat in brokenMaterials)
                {
                    MilanLog.Error($@"  Shader still broken for {mat.InstancedFullPath}");
                }
            }

#endif
        }

        public static void InstallTerrainShadersToPackage(IMEPackage package, string terrainFolder, string logCategory)
        {
            var terrains = package.Exports.Where(x => x.ClassName == "Terrain").ToList();
            if (terrains.Count == 0)
            {
                // Nothing to do here
                return;
            }

            var terrainShaderPath = $@"{terrainFolder}\{package.FileNameNoExtension}.pcc";
            if (File.Exists(terrainShaderPath) == false)
            {
                MilanLog.Error($"Terrain shader package not found: {terrainShaderPath} - skipping shader install", customPrefix: logCategory);
                return;
            }

            using var terrainShaderPackage = MEPackageHandler.OpenMEPackage(terrainShaderPath);
            foreach (var targetTerrain in terrains)
            {
                // 1. Find matching terrain in the compiled shader package
                var matchingTerrain = terrainShaderPackage.FindExport(targetTerrain.InstancedFullPath, targetTerrain.ClassName);
                if (matchingTerrain == null)
                {
                    MilanLog.Error($"No compiled shaders for {targetTerrain.InstancedFullPath} ({targetTerrain.ClassName}) in {terrainShaderPackage.FileNameNoExtension}", customPrefix: logCategory);
                    continue;
                }

                // 2. Copy it over wholesale; it should bring the shaders over to the cache.
                var rop = new RelinkerOptionsPackage();
                MilanLog.Information($"Installing Terrain shaders for {targetTerrain.InstancedFullPath}", customPrefix: logCategory);
                EntryImporter.ImportAndRelinkEntries(EntryImporter.PortingOption.ReplaceSingularWithRelink, matchingTerrain, targetTerrain.FileRef, targetTerrain, true, rop, out _);
            }

            if (package.IsModified)
            {
                package.Save();
            }
        }
    }
}
