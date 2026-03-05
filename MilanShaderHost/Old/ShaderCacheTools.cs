using LegendaryExplorerCore.GameFilesystem;
using LegendaryExplorerCore.Helpers;
using LegendaryExplorerCore.Misc.ME3Tweaks;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Packages.CloningImportingAndRelinking;
using LegendaryExplorerCore.Unreal;
using LegendaryExplorerCore.Unreal.BinaryConverters;
using LegendaryExplorerCore.Unreal.BinaryConverters.Shaders;
using LegendaryExplorerCore.Unreal.Collections;
using LegendaryExplorerCore.Unreal.ObjectInfo;
namespace MilanShaderHost.Old
{
    internal class ShaderCacheTools
    {
        /// <summary>
        /// Checks if the ref shader cache is less than 700MiB, indicating it has been slashed down.
        /// </summary>
        /// <param name="game">The game for which the shader cache is being checked.</param>
        /// <param name="gamePathOverride">An optional path to override the default game directory. If provided, this path is used to locate game files
        /// instead of the default location.</param>
        /// <returns>True if the shader cache is slashed, false otherwise.</returns>
        public static bool IsCacheSlashed(MEGame game, string gamePathOverride = null)
        {
            var refShaderCacheF = Path.Combine(gamePathOverride ?? MEDirectories.GetDefaultGamePath(game), @"BioGame\CookedPCConsole\RefShaderCache-PC-D3D-SM5.upk");
            return new FileInfo(refShaderCacheF).Length < 700 * FileSize.MebiByte; // Basic check. 
        }

        /// <summary>
        /// Slashes down the RefShaderCache to improve game boot speed by only keeping shaders relevant for shader compile.
        /// </summary>
        /// <remarks>This method identifies and retains specific shaders based on the game type and
        /// updates the shader cache accordingly. It logs the process of finding and keeping shaders, as well as any
        /// files that are not found. The method also handles the loading and saving of the shader cache, ensuring that
        /// only the necessary shaders are preserved.</remarks>
        /// <param name="game">The game for which the shader cache is being processed. This parameter determines which shaders are retained
        /// based on the game's requirements.</param>
        /// <param name="gamePathOverride">An optional path to override the default game directory. If provided, this path is used to locate game files
        /// instead of the default location.</param>
        public static void SlashShaderCache(MEGame game, string gamePathOverride = null, string slashLevelName = null)
        {
            Console.WriteLine($"\tFinding shaders to keep for {game}");
            List<string> filesToKeepShadersFor = new List<string>();

            if (game == MEGame.LE3)
            {
                filesToKeepShadersFor.Add(@"entrymenu.pcc");
                filesToKeepShadersFor.Add(@"BIOG_HMM_ARM_SHP_R.pcc");
                filesToKeepShadersFor.Add(@"BIOG_HMM_HED_Alignment.pcc");
                filesToKeepShadersFor.Add(@"SFXGameEffects.pcc");
                filesToKeepShadersFor.Add(@"SFXWeapon_Pistol_Predator.pcc");
                filesToKeepShadersFor.Add(@"Startup.pcc");
                filesToKeepShadersFor.Add(@"SFXGUI_Fonts.pcc");
                filesToKeepShadersFor.Add(@"SFXGUI_A_LegalLogos.pcc");
                filesToKeepShadersFor.Add(@"AreaMap_NumIcon.pcc");
                filesToKeepShadersFor.Add(@"BIOG_UIWorld.pcc");
                filesToKeepShadersFor.Add(@"Startup_HEN_PR.pcc");
                filesToKeepShadersFor.Add(@"Startup_CON_END.pcc");
                filesToKeepShadersFor.Add(@"Startup_EXP_Pack001.pcc");
                filesToKeepShadersFor.Add(@"Startup_EXP_Pack002.pcc");
                filesToKeepShadersFor.Add(@"Startup_EXP_Pack003_Base.pcc");
                filesToKeepShadersFor.Add(@"Startup_EXP_Pack003.pcc");
                filesToKeepShadersFor.Add(@"Startup_CON_DH1.pcc");
                filesToKeepShadersFor.Add(@"SFXGUI_Fonts_DLC.pcc");
                filesToKeepShadersFor.Add(@"SFXCharacterClass_Soldier.pcc");
            }

            if (slashLevelName != null)
            {
                filesToKeepShadersFor.Add(Path.GetFileName(slashLevelName));
            }

            var files = EntryImporter.FilesSafeToImportFrom(game).Concat(EntryImporter.FilesSafeToImportFromPostLoad(game));
            filesToKeepShadersFor.AddRange(files);
            var lFiles = MELoadedFiles.GetFilesLoadedInGame(game, gameRootOverride: gamePathOverride);
            var idsToKeep = new Dictionary<StaticParameterSet, string>();
            foreach (var file in filesToKeepShadersFor)
            {
                Console.WriteLine($"\t{file}");
                if (!lFiles.TryGetValue(file, out var filePath))
                {
                    Console.WriteLine($"File not found: {file}");
                    continue;
                }
                using var package = MEPackageHandler.OpenMEPackage(filePath);
                foreach (var exp in package.Exports)
                {
                    if (exp.IsDefaultObject)
                    {
                        continue;
                    }
                    if (exp.IsA("MaterialInstance"))
                    {
                        var hasStaticParameter = exp.GetProperty<BoolProperty>("bHasStaticPermutationResource");
                        if (hasStaticParameter != null && hasStaticParameter.Value)
                        {
                            var mat = ObjectBinary.From<MaterialInstance>(exp);
                            idsToKeep[mat.SM3StaticParameterSet] = exp.InstancedFullPath;
                            idsToKeep[(StaticParameterSet)mat.SM3StaticPermutationResource.ID] = exp.InstancedFullPath;
                            Console.WriteLine($"\t\t{exp.InstancedFullPath} {exp.ClassName}");
                        }
                    }
                    else if (exp.IsA("Material"))
                    {
                        var mat = ObjectBinary.From<Material>(exp);
                        idsToKeep[(StaticParameterSet)mat.SM3MaterialResource.ID] = exp.InstancedFullPath;
                        Console.WriteLine($"\t\t{exp.InstancedFullPath} {exp.ClassName}");
                    }

                }
            }

            var sparamSets = new HashSet<StaticParameterSet>();
            foreach (var id in idsToKeep)
            {
                sparamSets.Add((StaticParameterSet)id.Key);
            }
            Console.WriteLine($"We are going to keep {idsToKeep.Count} shaders");


            Console.WriteLine($"Loading ref shader cache");
            var refShaderCacheF = Path.Combine(LE3Directory.DefaultGamePath, @"BioGame\CookedPCConsole\RefShaderCache-PC-D3D-SM5.upk");
            using var refShaderCacheP = MEPackageHandler.OpenMEPackage(refShaderCacheF);

            Console.WriteLine($"Parsing CacheObject");
            var shaderCache = ObjectBinary.From<ShaderCache>(refShaderCacheP.Exports.FirstOrDefault());

            Console.WriteLine($"Dumping material shader maps");
            foreach (var ps in idsToKeep)
            {
                if (!shaderCache.MaterialShaderMaps.TryGetValue((StaticParameterSet)ps.Key, out var existing))
                {
                    Console.Error.WriteLine($"\t!!! NOT FOUND: {ps.Value} {ps.Key}");
                }
            }


            var keptShaderMaps = shaderCache.MaterialShaderMaps.Where(x => sparamSets.Contains(x.Key)).ToList();
            UMultiMap<StaticParameterSet, MaterialShaderMap> mm = new();
            foreach (var kvp in keptShaderMaps)
            {
                mm.Add(kvp.Key, kvp.Value);
            }
            shaderCache.MaterialShaderMaps = mm;

            Console.WriteLine($"Kept shader maps ({mm.Count}):");
            foreach (var ksm in mm)
            {
                Console.WriteLine($"\t{ksm.Value.FriendlyName}");
            }

            // Now dump the shaders too
            Console.WriteLine($"Dumping shaders");
            var shaderIdsToKeep = new HashSet<Guid>();
            var keptShaders = new Dictionary<Guid, Shader>();
            foreach (var matMap in shaderCache.MaterialShaderMaps)
            {
                int count = 0;
                Console.WriteLine($"\t{matMap.Value.FriendlyName}");
                foreach (var shaderList in matMap.Value.Shaders)
                {
                    // Console.WriteLine($"\t\t{shaderList.Value.Id}");
                    shaderIdsToKeep.Add(shaderList.Value.Id);
                    if (shaderCache.Shaders.TryGetValue(shaderList.Value.Id, out var shader))
                    {
                        count++;
                        keptShaders[shaderList.Value.Id] = shader;
                    }
                    else
                    {
                        Console.WriteLine($"\t\tNot found: {shaderList.Value.Id}");
                    }
                }

                foreach (var meshShaderMap in matMap.Value.MeshShaderMaps)
                {
                    foreach (var mShader in meshShaderMap.Shaders)
                    {
                        shaderIdsToKeep.Add(mShader.Value.Id);
                        if (shaderCache.Shaders.TryGetValue(mShader.Value.Id, out var shader))
                        {
                            count++;
                            keptShaders[mShader.Value.Id] = shader;

                        }
                        else
                        {
                            Console.WriteLine($"\t\tNot found: {mShader.Value.Id}");
                        }
                    }
                }
                Console.WriteLine($"\t\tCount: {count}");
            }

            UMultiMap<Guid, Shader> s = new();
            foreach (var shader in keptShaders)
            {
                s.Add(shader.Key, shader.Value);
            }
            shaderCache.Shaders = s;

            // Write slashed shader cache
            Console.WriteLine($"Saving cache");
            refShaderCacheP.Exports.FirstOrDefault().WriteBinary(shaderCache);

            // Test load
            ObjectBinary.From<ShaderCache>(refShaderCacheP.Exports.FirstOrDefault());
            refShaderCacheP.Save(compress: false);
        }
    
        /// <summary>
        /// Restores the ref shader cache for a game.
        /// </summary>
        /// <param name="game"></param>
        /// <param name="gamePathOverride"></param>
        public static void RestoreShaderCache(MEGame game, string gamePathOverride = null)
        {
            var backup = ME3TweaksBackups.GetGameBackupPath(game);
            var refBackupPath = Path.Combine(backup, @"BioGame\CookedPCConsole\RefShaderCache-PC-D3D-SM5.upk");
            var targetRefPath = Path.Combine(gamePathOverride ?? MEDirectories.GetDefaultGamePath(game), @"BioGame\CookedPCConsole\RefShaderCache-PC-D3D-SM5.upk");
            Console.WriteLine("Restoring RefShaderCache from backup");
            File.Copy(refBackupPath, targetRefPath, overwrite: true);
        }
    }
}
