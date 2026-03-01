using LegendaryExplorerCore.GameFilesystem;
using LegendaryExplorerCore.Helpers;
using LegendaryExplorerCore.Misc;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Packages.CloningImportingAndRelinking;
using LegendaryExplorerCore.Pathing;
using LegendaryExplorerCore.Shaders;
using LegendaryExplorerCore.UDK;
using LegendaryExplorerCore.Unreal;
using LegendaryExplorerCore.Unreal.BinaryConverters;
using LegendaryExplorerCore.Unreal.BinaryConverters.Shaders;
using LegendaryExplorerCore.Unreal.Classes;
using LegendaryExplorerCore.Unreal.Collections;
using LegendaryExplorerCore.Unreal.ObjectInfo;
using ProjectMilan.MilanUDK;
using ProjectMilan.Pipelines.StaticLighting;
using ProjectMilanCore;

namespace ProjectMilan.Utility
{
    /// <summary>
    /// Contains utility research methods. It's going to be LEX experiments all over again.
    /// </summary>
    internal static class Research
    {
#if DEBUG
        public static void SlashShaderCache(MEGame game)
        {
            Console.WriteLine($"Finding shaders to keep for {game}");
            List<string> filesToKeepShadersFor = new List<string>();
            filesToKeepShadersFor.Add(@"entry.pcc");
            filesToKeepShadersFor.Add(@"entrymenu.pcc");
            filesToKeepShadersFor.Add(@"BIOG_HMM_ARM_SHP_R.pcc");
            filesToKeepShadersFor.Add(@"BIOG_HMM_HED_Alignment.pcc");
            filesToKeepShadersFor.Add(@"SFXGameEffects.pcc");
            filesToKeepShadersFor.Add(@"SFXWeapon_Pistol_Predator.pcc");

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

            // ME3_OPAQUE_MM 

            var files = EntryImporter.FilesSafeToImportFrom(game).Concat(EntryImporter.FilesSafeToImportFromPostLoad(game));
            filesToKeepShadersFor.AddRange(files);
            var lFiles = MELoadedFiles.GetFilesLoadedInGame(game);
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
                    } else
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

                        } else
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

        public static void TestSFARTextureDecompression()
        {
            for (int i = 1; i < 5; i++)
            {
                var sfarPath = $@"E:\EAGames\Mass Effect 3\BIOGame\DLC\DLC_CON_MP{i}\CookedPCConsole\Default.sfar";
                var dlc = new DLCPackage(sfarPath);

                foreach (var ent in dlc.Files.Where(x => x.isActualFile && x.FileName.RepresentsPackageFilePath()))
                {
                    using var stream = dlc.DecompressEntry(ent);
                    using var package = MEPackageHandler.OpenMEPackageFromStream(stream);
                    foreach (var tex in package.Exports.Where(x => x.IsTexture()))
                    {
                        // This will throw exception on decompression failure.
                        MilanLog.Information($"Reading texture {tex.InstancedFullPath} in {ent.FileName}");
                        var t2d = new Texture2D(tex);
                        var top = t2d.GetImageBytesForMip(t2d.GetTopMip(), MEGame.ME3, false, out var mip);
                    }
                }
            }
        }

        public static void GenerateLightingForLevel()
        {
            var levelPathBase = @"Z:\ModLibrary\LMP\Project Milan\DLC_MOD_ProjectMilan\CookedPCConsole\Levels";
            string[] levels = [
                "BioP_MPGeth",
                "BioP_MPMoon",
                "BioP_MPThes",
                "BioP_MPJngl"
                //"BioP_MPOcean",
                //"BioP_MPRoad"
            ];

            foreach (var l in levels)
            {
                var level = $@"{levelPathBase}\{l}\{l}.pcc";
                if (!File.Exists(level))
                {
                    MilanLog.Warning($"Level file not present: {level}");
                    continue;
                }
                MilanLog.Information($"Generating static lighting for {level}");
                using var levelP = MEPackageHandler.OpenMEPackage(level);
                StaticLightingExport.ExportLevelToUDK(levelP);
            }
        }

        /// <summary>
        /// Calculates texture to instances map for a folder
        /// </summary>
        public static void TestTextureToInstancesMap()
        {
            // Runs on BioP_MPGeth folder in game.
            var dir = Path.Combine(LE3Directory.DLCPath, @"DLC_MOD_ProjectMilan\CookedPCConsole\Levels\BioP_MPMoon");
            foreach (var pcc in Directory.GetFiles(dir))
            {
                var package = MEPackageHandler.OpenMEPackage(pcc);
                LevelTools.CalculateTextureToInstancesMap(package, TieredPackageCache.GetGlobalPackageCache(MEGame.LE3));
                //package.Save();
            }
        }

        public static void DumpRefShaderNames()
        {
            var shaderCacheF = @"S:\SteamLibrary\steamapps\common\Mass Effect Legendary Edition\Game\ME3\BioGame\CookedPCConsole\RefShaderCache-PC-D3D-SM5.upk";
            MilanLog.Information("Loading RefShaderCache");
            var shaderCacheP = MEPackageHandler.OpenMEPackage(shaderCacheF);
            MilanLog.Information("Parsing RefShaderCache");
            var shaderCache = ObjectBinary.From<ShaderCache>(shaderCacheP.Exports.FirstOrDefault());
            MilanLog.Information("Dumping materials");
            SortedSet<string> matNames = new SortedSet<string>();
            foreach (var sm in shaderCache.MaterialShaderMaps)
            {
                matNames.Add($"{sm.Value.FriendlyName} {sm.Value.ID}");
            }

            var outP = @"C:\users\public\refshadermaterials.txt";
            File.WriteAllLines(outP, matNames);
        }

        public static void LightingBake()
        {
            UDKSetup.SetupUDK();
            StaticLightingCompute.ComputeLighting("BioP_MPGeth");
        }

        private static IMEPackage GenerateLevelMaster(string basePath, string level)
        {
            var path = Path.Combine(basePath, $"BioP_UDKLighting_{level.UpperFirst()}.pcc");
            MEPackageHandler.CreateEmptyLevel(path, MEGame.LE3);
            using var destPackage = (MEPackage)MEPackageHandler.OpenMEPackage(path);

            destPackage.AdditionalPackagesToCook.AddRange(new List<string>([
                "BioP_CitHub",
                "BioA_CitHub",
                "BioA_CitHub_Temple",
                "BioA_CitHub_Temple_Vista",
            ]));

            destPackage.Save();
            return destPackage;
        }

        internal static void ScanForShaderCompPackages()
        {
            SortedSet<string> packagesToCompile = new SortedSet<string>();
            var packages = Directory.GetFiles(Program.Settings.OutputModPath, "*.pcc", SearchOption.AllDirectories);
            foreach (var p in packages)
            {
                var package = MEPackageHandler.OpenMEPackage(p);
                var brokenMaterials = ShaderCacheManipulator.GetBrokenMaterials(package);
                foreach (var mat in brokenMaterials)
                {
                    packagesToCompile.Add(mat.GetLinker());
                }
            }

            foreach (var p in packagesToCompile)
            {
                Console.WriteLine(p);
            }
        }

        /// <summary>
        /// Scans the output directory for broken materials. Attempts to merge shader caches from our custom compiled versions and link them up.
        /// </summary>
        internal static void InstallCompiledShaders()
        {
            var compiledShaderPath = @"S:\Milan\ShaderResearch\CompiledShaderPackages";
            var compiledShaderPackages = Directory.GetFiles(compiledShaderPath, "*.pcc");
            CaseInsensitiveDictionary<string> packageMap = new();
            var cache = new PackageCache();
            // var packages = Directory.GetFiles(Program.Settings.OutputModPath, "*.pcc", SearchOption.AllDirectories);
            var packages = Directory.GetFiles(@"S:\SteamLibrary\steamapps\common\Mass Effect Legendary Edition\Game\LMP\BioGame\DLC\DLC_MOD_ProjectMilan", "*.pcc", SearchOption.AllDirectories);
            foreach (var p in compiledShaderPackages)
            {
                packageMap[Path.GetFileNameWithoutExtension(p)] = p;
            }

            foreach (var gamePackagePath in packages)
            {
                var gamePackage = MEPackageHandler.OpenMEPackage(gamePackagePath);

                var brokenMaterials = ShaderCacheManipulator.GetBrokenMaterials(gamePackage);
                foreach (var mat in brokenMaterials)
                {
                    var linker = mat.GetLinker();
                    if (packageMap.TryGetValue(linker, out var cmp))
                    {
                        var compiledPackage = cache.GetCachedPackage(cmp);
                        var csc = compiledPackage.FindExport("SeekFreeShaderCache");
                        if (csc == null)
                            // dunno what happened here.
                            continue;

                        var matchingMat = compiledPackage.Exports.FirstOrDefault(x => x.ClassName == mat.ClassName && x.ObjectName.Instanced == x.ObjectName.Instanced);
                        if (matchingMat == null)
                        {
                            // couldn't find the mat
                            MilanLog.Information($"No compiled shaders for {mat.InstancedFullPath} in {gamePackage.FileNameNoExtension}");
                        }
                        else
                        {
                            MilanLog.Information($"Update shadercache for {mat.InstancedFullPath} in {gamePackage.FileNameNoExtension}");
                            var shaderCache = ObjectBinary.From<ShaderCache>(csc);
                            ShaderCacheManipulator.AddShadersToFile(gamePackage, shaderCache);
                            // update the id of the material to match the compiled version
                            var matchingMatBin = ObjectBinary.From<Material>(matchingMat);
                            ObjectBinary.EditBinary<Material>(mat, x => x.SM3MaterialResource.ID = matchingMatBin.SM3MaterialResource.ID);
                        }
                    }
                }

                ShaderCacheManipulator.CompactSeekFreeShaderCaches(gamePackage);
                if (gamePackage.IsModified)
                {
                    gamePackage.Save();
                }
                brokenMaterials = ShaderCacheManipulator.GetBrokenMaterials(gamePackage);
                foreach (var mat in brokenMaterials)
                {
                    MilanLog.Error($@"  Shader still broken for {mat.InstancedFullPath}");
                }
            }
        }

        internal static void ImportStaticLightingForLevel()
        {
            var level = @"Z:\ModLibrary\LMP\Project Milan\DLC_MOD_ProjectMilan\CookedPCConsole\Levels";
            foreach (var levelF in Directory.GetDirectories(level))
            {
                var levelName = Path.GetFileName(levelF);
                var lmpMasterF = Path.Combine(level, levelName, $"{levelName}.pcc");
                var lmpMaster = MEPackageHandler.OpenMEPackage(lmpMasterF);
                var staticLightingPath = Path.Combine(MilanShared.PipelineRoot, "StaticLighting", "Levels", levelName, $"{levelName}.udk");
                if (File.Exists(staticLightingPath))
                {
                    // Import static lighting
                    LightingImportSetup setup = new LightingImportSetup()
                    {
                        IncludeSubLevels = true,
                        UDKMapsBasePath = Directory.GetParent(staticLightingPath).FullName
                    };

                    StaticLightingImporter.ImportStaticLighting(lmpMaster, setup);
                }
            }
        }
#endif
    }
}
