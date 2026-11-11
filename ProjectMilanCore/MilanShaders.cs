using LegendaryExplorerCore.Misc;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Packages.CloningImportingAndRelinking;
using LegendaryExplorerCore.Shaders;
using LegendaryExplorerCore.Unreal;
using LegendaryExplorerCore.Unreal.BinaryConverters;
using LegendaryExplorerCore.Unreal.ObjectInfo;
using MilanShaderHost;
using ProjectMilan;

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
        /// Of <paramref name="brokenMaterials"/>, clears <c>bHasStaticPermutationResource</c> from the
        /// instances whose parameter set overrides nothing, so they render through their parent's shader
        /// map. Returns the instances it cleared.
        /// </summary>
        /// <remarks>
        /// Same rule and reason as the decooker's (<c>DecookerShared.PreparePackageForUDKify</c>): such an
        /// instance has no permutation of its own, so the shader host never compiles one and no compiled
        /// package can supply it. Left flagged, it asks for a map that will never exist and is reported
        /// broken on every install. <c>BioT_MPMoon.Materials.Rocks_MAT_INST</c> and
        /// <c>BioT_MPThes.Materials.Water_Puddle_Flowing_INST02</c> were the cases; TFCBuild strips these too,
        /// but only for the packages its pass covers.
        ///
        /// Only broken ones. A no-override instance whose map *is* reachable is left alone: the game looks
        /// it up by its stored values, and when its live parent is an LE3 material with different defaults
        /// (a different normal compression, say) that map and the parent's own can differ, so stripping it
        /// could change what it renders. BioA_MPMoon has 10 no-override instances and only one was broken.
        /// </remarks>
        public static HashSet<ExportEntry> StripPermutationsThatOverrideNothing(IEnumerable<ExportEntry> brokenMaterials, string logCategory)
        {
            var stripped = new HashSet<ExportEntry>();
            foreach (var export in brokenMaterials.Where(IsPermutationInstance))
            {
                StaticParameterSet set;
                try
                {
                    set = ObjectBinary.From<MaterialInstance>(export).SM3StaticParameterSet;
                }
                catch
                {
                    continue; // Unreadable binary: not ours to judge here.
                }
                if (set == null || StaticPermutationNaming.HasAnyOverride(set)) continue;

                export.RemoveProperty("bHasStaticPermutationResource");
                export.WriteBinary([]);
                MilanLog.Information($"Cleared static permutation flag on {export.InstancedFullPath}: it overrides nothing and has no shader map of its own, so it uses its parent's", customPrefix: logCategory);
                stripped.Add(export);
            }
            return stripped;
        }

        /// <summary>
        /// Rebases each permutation instance's <c>SM3StaticParameterSet</c> onto the base material it will
        /// actually have in game, when a shader map already exists under the rebased key. Returns how many
        /// instances were re-keyed.
        /// </summary>
        /// <remarks>
        /// The engine looks an instance's permutation up by its stored parameter values but with
        /// <c>BaseMaterialId</c> replaced by the live base material's resource ID. LEC's
        /// <see cref="ShaderCacheManipulator.GetBrokenMaterials"/> uses the stored ID. A ported instance
        /// stores ME3's parent ID, so the two disagree whenever the parent resolves to an LE3 material --
        /// typically one that ships in SFXGame, like <c>BIOG_APL_MASTER_MATERIAL.Placeable_MM</c> or
        /// <c>BioG_MasterMats.Material_Parents.ME3_OPAQUE_MM</c>. LE3's RefShaderCache often already holds
        /// the permutation under the LE3 ID; the shader host then compiles nothing, because the game finds
        /// that map and never asks, and the stored key made Milan report the instance broken and TFCBuild
        /// strip it. ShaderResearchTool HANDOFF section 38.
        ///
        /// Only the ID changes. Every stored value is kept, non-overridden ones included -- measured, not
        /// assumed: recompiling BioT_GthMP, the game keyed each ME3_OPAQUE_MM permutation it compiled by
        /// SFXGame's ID plus the instance's stored ME3 normal compressions (7/1/4), not the LE3 parent's
        /// defaults (12/12/4), and the instances it skipped are exactly those whose stored values under
        /// SFXGame's ID are in RefShaderCache. A first version that also re-derived non-overridden values
        /// from the parent missed every one of those.
        ///
        /// The new key is kept only if a map is reachable under it (this package's cache or RefShaderCache).
        /// Anything else is left for the compiled-permutation install, which brings its own key.
        /// </remarks>
        public static int RekeyPermutationsToLiveParent(IMEPackage package, PackageCache cache, string logCategory,
            Func<string, PackageCache, IMEPackage> fileResolver = null)
        {
            var candidates = new List<(ExportEntry instance, StaticParameterSet rekeyed)>();
            foreach (var export in package.Exports.Where(IsPermutationInstance))
            {
                var chain = ResolveParentChain(export, cache, fileResolver);
                if (chain == null) continue;

                var stored = ObjectBinary.From<MaterialInstance>(export).SM3StaticParameterSet;
                if (stored == null) continue;

                var liveId = ObjectBinary.From<Material>(chain[^1]).SM3MaterialResource.ID;
                if (liveId == Guid.Empty || liveId == stored.BaseMaterialId) continue;

                candidates.Add((export, new StaticParameterSet
                {
                    BaseMaterialId = liveId,
                    StaticSwitchParameters = stored.StaticSwitchParameters,
                    StaticComponentMaskParameters = stored.StaticComponentMaskParameters,
                    NormalParameters = stored.NormalParameters,
                    TerrainWeightParameters = stored.TerrainWeightParameters,
                }));
            }

            if (candidates.Count == 0) return 0;

            // Whatever is still in this set afterwards has no map under its new key.
            var unreachable = candidates.Select(x => x.rekeyed).ToHashSet();
            if (package.FindExport("SeekFreeShaderCache") is ExportEntry localCacheExport)
            {
                foreach ((StaticParameterSet key, _) in ObjectBinary.From<ShaderCache>(localCacheExport).MaterialShaderMaps)
                {
                    unreachable.Remove(key);
                }
            }
            if (unreachable.Count > 0)
            {
                RefShaderCacheReader.RemoveStaticParameterSetsThatAreInTheGlobalCache(unreachable, package.Game);
            }

            int rekeyedCount = 0;
            foreach (var (instance, rekeyed) in candidates)
            {
                if (unreachable.Contains(rekeyed)) continue;
                ObjectBinary.EditBinary<MaterialInstance>(instance, x => x.SM3StaticParameterSet = rekeyed);
                MilanLog.Information($"Re-keyed permutation of {instance.InstancedFullPath} to its live base material ({rekeyed.BaseMaterialId}); the game already has this map", customPrefix: logCategory);
                rekeyedCount++;
            }
            return rekeyedCount;
        }

        /// <summary>
        /// The instance's ancestors, nearest first, ending at the UMaterial at the root, with imports resolved
        /// the way the game would. Null if the chain breaks or does not end at a material.
        /// </summary>
        private static List<ExportEntry> ResolveParentChain(ExportEntry instance, PackageCache cache, Func<string, PackageCache, IMEPackage> fileResolver)
        {
            var chain = new List<ExportEntry>();
            var current = instance;
            // Instances chain, but not deeply. The cap only guards against a malformed cycle.
            for (int depth = 0; depth < 32; depth++)
            {
                var parentRef = current.GetProperty<ObjectProperty>("Parent")?.Value ?? 0;
                current = current.FileRef.GetEntry(parentRef) switch
                {
                    ExportEntry parentExport => parentExport,
                    ImportEntry parentImport => EntryImporter.ResolveImport(parentImport, cache, fileResolver: fileResolver),
                    _ => null,
                };
                if (current == null) return null;

                chain.Add(current);
                if (current.IsA("Material")) return chain;
                if (!current.IsA("MaterialInstance")) return null;
            }
            return null;
        }

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

            // Before the broken check, so an instance whose permutation the game already has is not
            // reported broken (and then stripped by TFCBuild) just because its stored key came from ME3.
            RekeyPermutationsToLiveParent(package, cache, logCategory, MilanShared.LE3PackageResolver);

            // MaterialInstances with a static permutation own a shader map of their own, keyed by their
            // SM3StaticParameterSet rather than by a material resource ID. GetBrokenMaterials already
            // returns them; the force path has to ask for them explicitly.
            List<ExportEntry> materialsToProcess;
            if (force)
            {
                materialsToProcess = package.Exports.Where(x => x.IsA("Material") || IsPermutationInstance(x)).ToList();
            }
            else
            {
                materialsToProcess = ShaderCacheManipulator.GetBrokenMaterials(package);
                // Broken instances that override nothing need no compiled permutation; they go back to
                // their parent's map instead of being reported as missing one.
                var stripped = StripPermutationsThatOverrideNothing(materialsToProcess, logCategory);
                materialsToProcess.RemoveAll(stripped.Contains);
            }

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

                    // Set used with flags so compiler doesn't try to recompile things
                    var usedWithFlags = matchingMat.GetProperties().OfType<BoolProperty>().Where(b => b.Value && b.Name.Name.StartsWith("bUsedWith", StringComparison.Ordinal));
                    foreach (var flag in usedWithFlags)
                    {
                        brokenMat.WriteProperty(new BoolProperty(true, flag.Name));
                    }
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
