using LegendaryExplorerCore.GameFilesystem;
using LegendaryExplorerCore.Gammtek.Extensions;
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
using ME3Tweaks.Wwiser;
using ME3Tweaks.Wwiser.BankConversion;
using ProjectMilan.MilanUDK;
using ProjectMilan.Pipelines.Audio;
using ProjectMilan.Pipelines.StaticLighting;
using ProjectMilanCore;
using System.Diagnostics;

namespace ProjectMilan.Utility
{
    /// <summary>
    /// Contains utility research methods. It's going to be LEX experiments all over again.
    /// </summary>
    internal static class Research
    {
#if DEBUG
        public static void GetMissingShaderPackages(string folder)
        {
            HashSet<string> brokenMaterialPackages = new HashSet<string>();
            foreach (var f in Directory.GetFiles(folder, "*.pcc", SearchOption.AllDirectories))
            {
                using var p = MEPackageHandler.OpenMEPackage(f);
                var brokenMats = ShaderCacheManipulator.GetBrokenMaterials(p);
                foreach (var mat in brokenMats)
                {
                    brokenMaterialPackages.Add(mat.GetLinker());
                }
            }

            foreach (var pkg in brokenMaterialPackages)
            {
                Console.WriteLine(pkg);
            }
        }

        public static void InstallCompiledShaders(string folder)
        {
            var compiled = @"E:\CompiledShaderPackages";
            var cache = new PackageCache();
            HashSet<string> mergedShaderCaches = new HashSet<string>();
            foreach (var f in Directory.GetFiles(folder, "*.pcc", SearchOption.AllDirectories))
            {
                bool needsSaved = false;
                using var p = MEPackageHandler.OpenMEPackage(f);
                var brokenMats = ShaderCacheManipulator.GetBrokenMaterials(p);
                foreach (var mat in brokenMats)
                {
                    var linker = mat.GetLinker();
                    var fname = linker + ".pcc";
                    var fullPath = Path.Combine(compiled, fname);
                    var compiledPackage = cache.GetCachedPackage(fullPath, true);
                    if (compiledPackage != null)
                    {
                        var compiledMaterial = compiledPackage.FindExport(mat.InstancedFullPath) ?? compiledPackage.FindExport(mat.MemoryFullPath);
                        if (compiledMaterial == null)
                        {
                            MilanLog.Error($"Could not find our compiled shader for {mat.InstancedFullPath}");
                            continue;
                        }

                        // Port the material over.
                        EntryImporter.ImportAndRelinkEntries(EntryImporter.PortingOption.ReplaceSingularWithRelink, compiledMaterial, p, mat, true, new RelinkerOptionsPackage() { Cache = cache }, out var _);

                        // ... and merge the shader cache while we're at it.
                        if (mergedShaderCaches.Contains(linker))
                        {
                            continue;
                        }
                        var sc = compiledPackage.FindExport("SeekFreeShaderCache");
                        var scBin = ObjectBinary.From<ShaderCache>(sc);

                        var localCache = ShaderCacheManipulator.CreateShaderCache(p);
                        var localCacheBin = ObjectBinary.From<ShaderCache>(localCache);

                        scBin.MergeInto(localCacheBin);
                        localCache.WriteBinary(localCacheBin);
                        needsSaved = true;
                        mergedShaderCaches.Add(linker);
                    }
                }

                if (needsSaved)
                {
                    p.Save();
                }
            }
        }

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
                "BioP_MPJngl",
                "BioP_MPOcean",
                "BioP_MPRoad"
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
                // using var levelP = MEPackageHandler.OpenMEPackage(level);
                //StaticLightingExport.ExportLevelToUDK(level);
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
                LevelTools.CalculateTextureToInstancesMap(package, TieredPackageCache.GetGlobalPackageCache(MEGame.LE3, debugName: "Research.TestTextureToInstancesMap cache"));
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

        internal static void CopyPreview()
        {
            using var p = MEPackageHandler.OpenMEPackage(@"S:\SteamLibrary\steamapps\common\Mass Effect Legendary Edition\Game\ME3\BioGame\CookedPCConsole\shaderpreview.pcc");
            var inputf = @"S:\SteamLibrary\steamapps\common\Mass Effect Legendary Edition\Game\LMP\BioGame\DLC\DLC_MOD_PMR3\CookedPCConsole\Levels\BioP_MPPSTropical";
            foreach (var file in Directory.GetFiles(inputf, "*.pcc"))
            {
                var psf = MEPackageHandler.OpenMEPackage(file);

                foreach (var mat in p.Exports.Where(x => x.IsA("Material")))
                {
                    var matInDest = psf.FindExport(mat.InstancedFullPath, mat.ClassName);
                    if (matInDest != null)
                    {
                        Console.WriteLine($"Copying {mat.InstancedFullPath} to {file}");
                        EntryImporter.ImportAndRelinkEntries(EntryImporter.PortingOption.ReplaceSingularWithRelink, mat, psf, matInDest, true, new RelinkerOptionsPackage() { Cache = new PackageCache() }, out var _);
                    }
                }

                var shaderCacheInSource = p.FindExport("SeekFreeShaderCache");
                var shaderCacheInDest = psf.FindExport("SeekFreeShaderCache");

                if (shaderCacheInSource != null && shaderCacheInDest != null)
                {
                    Console.WriteLine($"Merging shader cache to {file}");
                    var shaderCacheSourceBin = ObjectBinary.From<ShaderCache>(shaderCacheInSource);
                    var shaderCacheDestBin = ObjectBinary.From<ShaderCache>(shaderCacheInDest);
                    shaderCacheSourceBin.MergeInto(shaderCacheDestBin);
                    shaderCacheInDest.WriteBinary(shaderCacheDestBin);
                }
                ShaderCacheManipulator.CompactSeekFreeShaderCaches(psf);

                if (psf.IsModified)
                {
                    psf.Save();
                }
            }
        }

        internal static void CopyPreview2()
        {
            using var p = MEPackageHandler.OpenMEPackage(@"S:\SteamLibrary\steamapps\common\Mass Effect Legendary Edition\Game\ME3\BioGame\CookedPCConsole\shaderpreview.pcc");
            var inputf = @"S:\SteamLibrary\steamapps\common\Mass Effect Legendary Edition\Game\LMP\BioGame\DLC\DLC_MOD_PMR3\CookedPCConsole\Levels\BioP_MPPSTropical\BioP_MPPS.pcc";
            var psf = MEPackageHandler.OpenMEPackage(inputf);

            foreach (var mat in p.Exports.Where(x => x.IsA("StaticMeshActor")))
            {
                Console.WriteLine($"Copying {mat.InstancedFullPath} to {psf.FileNameNoExtension}");
                EntryExporter.ExportExportToPackage(mat, psf, out var ported);
            }

            LevelTools.RebuildPersistentLevelChildren(psf.GetLevel());

            var shaderCacheInSource = ShaderCacheManipulator.CreateShaderCache(p);
            var shaderCacheInDest = ShaderCacheManipulator.CreateShaderCache(psf);

            if (shaderCacheInSource != null && shaderCacheInDest != null)
            {
                Console.WriteLine($"Merging shader cache");
                var shaderCacheSourceBin = ObjectBinary.From<ShaderCache>(shaderCacheInSource);
                var shaderCacheDestBin = ObjectBinary.From<ShaderCache>(shaderCacheInDest);
                shaderCacheSourceBin.MergeInto(shaderCacheDestBin);
                shaderCacheInDest.WriteBinary(shaderCacheDestBin);
            }
            ShaderCacheManipulator.CompactSeekFreeShaderCaches(psf);

            if (psf.IsModified)
            {
                psf.Save();
            }
        }


        /// <summary>
        /// Scans the output directory for broken materials. Attempts to merge shader caches from our custom compiled versions and link them up.
        /// </summary>
        /// <param name="force">If true, reinstalls every material with a matching compiled package and overwrites its
        /// existing shader data, rather than only touching materials with no shader data at all. Use this after
        /// recompiling shaders you already had a (working or not) install for previously.</param>
        internal static void InstallCompiledShaders(bool force = false)
        {
            var path = @"S:\SteamLibrary\steamapps\common\Mass Effect Legendary Edition\Game\LMP\BioGame\DLC\DLC_MOD_ProjectMilan";
            if (Directory.Exists(path) == false)
            {
                MilanLog.Error($"Shader install target path not found: {path}");
                return;
            }
            var packages = Directory.GetFiles(path, "*.pcc", SearchOption.AllDirectories);

            foreach (var gamePackagePath in packages)
            {
                var gamePackage = MEPackageHandler.OpenMEPackage(gamePackagePath);
                MilanShaders.InstallCompiledShadersToPackage(gamePackage, "MilanResearch", force);

                var brokenMaterials = ShaderCacheManipulator.GetBrokenMaterials(gamePackage);
                foreach (var brokenMat in brokenMaterials)
                {
                    if (brokenMat.IsA("MaterialInstance") && brokenMat.GetProperty<BoolProperty>("bHasStaticPermutationResource")?.Value == true)
                    {
                        brokenMat.RemoveProperty("bHasStaticPermutationResource");
                        brokenMat.WriteBinary([]);
                    }
                }
                if (gamePackage.IsModified)
                {
                    gamePackage.Save();
                }
            }
            //var decookedPath = @"E:\CompiledShaderPackages";
            //var compiledShaderPath = @"E:\CompiledShaderPackages";
            //var compiledShaderPackages = Directory.GetFiles(compiledShaderPath, "*.pcc");
            //CaseInsensitiveDictionary<string> packageMap = new();
            //var cache = new PackageCache();
            //// var packages = Directory.GetFiles(Program.Settings.OutputModPath, "*.pcc", SearchOption.AllDirectories);
            //var packages = Directory.GetFiles(@"S:\SteamLibrary\steamapps\common\Mass Effect Legendary Edition\Game\LMP\BioGame\DLC\DLC_MOD_PMR3\CookedPCConsole\Levels\BioP_MPPSTropical");
            //foreach (var p in compiledShaderPackages)
            //{
            //    packageMap[Path.GetFileNameWithoutExtension(p)] = p;
            //}

            //foreach (var gamePackagePath in packages)
            //{
            //    if (!gamePackagePath.RepresentsPackageFilePath())
            //    {
            //        continue;
            //    }
            //    var gamePackage = MEPackageHandler.OpenMEPackage(gamePackagePath);

            //    var brokenMaterials = ShaderCacheManipulator.GetBrokenMaterials(gamePackage);
            //    foreach (var brokenMat in brokenMaterials)
            //    {
            //        var linker = brokenMat.GetLinker();
            //        if (packageMap.TryGetValue(linker, out var cmp))
            //        {
            //            var compiledPackage = cache.GetCachedPackage(cmp);
            //            var csc = compiledPackage.FindExport("SeekFreeShaderCache");
            //            if (csc == null)
            //                // dunno what happened here.
            //                continue;

            //            var matchingMat = compiledPackage.FindExport(brokenMat.MemoryFullPath, brokenMat.ClassName) ?? compiledPackage.FindExport(brokenMat.InstancedFullPath, brokenMat.ClassName);
            //            if (matchingMat == null)
            //            {
            //                // couldn't find the mat
            //                MilanLog.Information($"No compiled shaders for {brokenMat.InstancedFullPath} in {gamePackage.FileNameNoExtension}");
            //            }
            //            else
            //            {
            //                MilanLog.Information($"Update shadercache for {brokenMat.InstancedFullPath} in {gamePackage.FileNameNoExtension}");
            //                var shaderCache = ObjectBinary.From<ShaderCache>(csc);
            //                ShaderCacheManipulator.AddShadersToFile(gamePackage, shaderCache);
            //                // update the id of the material to match the compiled version
            //                var matchingMatBin = ObjectBinary.From<Material>(matchingMat);
            //                ObjectBinary.EditBinary<Material>(brokenMat, x => x.SM3MaterialResource.ID = matchingMatBin.SM3MaterialResource.ID);
            //                brokenMat.WriteProperty(new BoolProperty(true, "bUsedWithStaticLighting"));
            //                brokenMat.WriteProperty(new BoolProperty(true, "bUsedWithVectorLightMaps"));
            //            }
            //        }
            //    }

            //    ShaderCacheManipulator.CompactSeekFreeShaderCaches(gamePackage);
            //    if (gamePackage.IsModified)
            //    {
            //        gamePackage.Save();
            //    }
            //    brokenMaterials = ShaderCacheManipulator.GetBrokenMaterials(gamePackage);
            //    foreach (var mat in brokenMaterials)
            //    {
            //        MilanLog.Error($@"  Shader still broken for {mat.InstancedFullPath}");
            //    }
            //}
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

        internal static void DumpME3WwiseBanks()
        {
            var outputPath = @"S:\Milan\Audio\BankDump";
            var packages = Program.Settings.OutputModPath;
            foreach (var packagePath in Directory.GetFiles(packages, "*.pcc", SearchOption.AllDirectories))
            {
                if (packagePath.GetUnrealLocalization() != MELocalization.INT)
                {
                    // Skipping not-INT audio for now.
                    continue;
                }
                using var package = MEPackageHandler.OpenMEPackage(packagePath);
                foreach (var bankExport in package.Exports.Where(x => x.ClassName == "WwiseBank"))
                {
                    var extractPath = Path.Combine(outputPath, bankExport.ObjectName.Instanced + ".bnk");
                    var wwiseBin = ObjectBinary.From<LegendaryExplorerCore.Unreal.BinaryConverters.WwiseBank>(bankExport);
                    var bankVersion = WwiseBankParser.GetWwiseBankVersion(new MemoryStream(wwiseBin.BnkFile));
                    if (bankVersion == 56)
                    {
                        Console.WriteLine($"Extracting {bankExport.InstancedFullPath} (version {bankVersion}) to {extractPath}");
                        File.WriteAllBytes(extractPath, wwiseBin.BnkFile);
                    }
                }
            }
        }

        internal static void ConvertME3WwiseBanks()
        {
            var inputPath = @"S:\Milan\Audio\BankDump";
            var outputPath = @"S:\Milan\Audio\BankConvert";
            Parallel.ForEach(Directory.GetFiles(inputPath, "*.bnk"), new ParallelOptions { MaxDegreeOfParallelism = 6 }, bnkFile =>
            {
                {
                    var bankVersion = WwiseBankParser.GetWwiseBankVersion(new MemoryStream(File.ReadAllBytes(bnkFile)));
                    if (bankVersion == 56)
                    {
                        Console.WriteLine($"Converting {Path.GetFileName(bnkFile)} (version {bankVersion})");
                        var me3Bank = WwiseBankParser.Deserialize(new MemoryStream(File.ReadAllBytes(bnkFile)));

                        WwiseBankConverter.ConvertBank(me3Bank, 134);
                        var outFile = Path.Combine(outputPath, Path.GetFileName(bnkFile));
                        using var outFs = new FileStream(outFile, FileMode.Create, FileAccess.Write);
                        ME3Tweaks.Wwiser.WwiseBankParser.Serialize(me3Bank, outFs);
                        Console.WriteLine($"  Conversion complete for {Path.GetFileName(bnkFile)}");
                    }
                    else
                    {
                        Console.WriteLine($"Skipping {Path.GetFileName(bnkFile)} (version {bankVersion})");
                    }
                }
            });
        }

        /// <summary>
        /// Installs a single bank into the game
        /// </summary>
        internal static void TestWwiseBank()
        {
            var convertedPath = @"S:\Milan\Audio\BankConvert";
            var testBankFile = Path.Combine(convertedPath, "ss_mp_asari1_player.bnk");
            var targetPackage = Path.Combine(LMPDirectory.DefaultGamePath, @"BioGame\DLC\DLC_MOD_ProjectMilan\CookedPCConsole\Kits\Asari_Adept_MP_LOC_INT.pcc");

            var bankName = Path.GetFileNameWithoutExtension(testBankFile);
            using var package = MEPackageHandler.OpenMEPackage(targetPackage);

            var export = package.Exports.FirstOrDefault(x => x.ClassName == "WwiseBank" && x.ObjectName.Instanced == bankName);
            ObjectBinary.EditBinary<LegendaryExplorerCore.Unreal.BinaryConverters.WwiseBank>(export, x => x.BnkFile = File.ReadAllBytes(testBankFile));
            package.Save();
        }

        /// <summary>
        /// Dumps all LE3 banks, then enumerates ME3 and dumps matching banks
        /// </summary>
        internal static void DumpAllBanks()
        {
            var inputFolder = @"Z:\Mass Effect Builds\Legendary\2.0.0.48602\ME3\BioGame\CookedPCConsole";
            var le3OutputFolder = @"S:\Milan\Audio\LE3Banks";
            Dictionary<string, string> dumpedBanks = new Dictionary<string, string>(); // Map BankName -> SourceFileName

            Console.WriteLine(@"------ DUMPING LE3 BANKS -------");
            foreach (var le3PackageP in Directory.GetFiles(inputFolder, "*.pcc", SearchOption.AllDirectories))
            {
                var loc = le3PackageP.GetUnrealLocalization();
                if (loc != MELocalization.None && loc != MELocalization.INT)
                {
                    continue; // INT or NONE for now
                }

                using var le3Package = MEPackageHandler.OpenMEPackage(le3PackageP);
                foreach (var bankExport in le3Package.Exports.Where(x => !x.IsDefaultObject && x.ClassName == "WwiseBank" && !dumpedBanks.ContainsKey(x.ObjectName.Instanced)))
                {
                    var bankName = bankExport.ObjectName.Instanced;
                    Console.WriteLine($"Dumping bank {bankName} from {Path.GetFileName(le3PackageP)}");
                    var outFile = Path.Combine(le3OutputFolder, bankName + ".bnk");
                    var wwiseBin = ObjectBinary.From<LegendaryExplorerCore.Unreal.BinaryConverters.WwiseBank>(bankExport);
                    File.WriteAllBytes(outFile, wwiseBin.BnkFile);
                    dumpedBanks[bankName] = le3PackageP;
                }
            }

            // Now do the same for ME3
            // But we're actually just going to dump evertyhign
            Console.WriteLine(@"------ DUMPING ME3 BANKS -------");
            dumpedBanks.Clear(); // Clear the map for ME3
            var me3InputFolder = @"Z:\Mass Effect Builds\ME3\PC\Retail\BIOGame\CookedPCConsole";
            var me3OutputFolder = @"S:\Milan\Audio\ME3Banks";
            foreach (var me3PackageP in Directory.GetFiles(me3InputFolder, "*.pcc", SearchOption.AllDirectories))
            {
                var loc = me3PackageP.GetUnrealLocalization();
                if (loc != MELocalization.None && loc != MELocalization.INT)
                {
                    continue; // INT or NONE for now
                }
                using var me3Package = MEPackageHandler.OpenMEPackage(me3PackageP);
                foreach (var bankExport in me3Package.Exports.Where(x => !x.IsDefaultObject && x.ClassName == "WwiseBank" && !dumpedBanks.ContainsKey(x.ObjectName.Instanced)))
                {
                    var bankName = bankExport.ObjectName.Instanced;
                    Console.WriteLine($"Dumping bank {bankName} from {Path.GetFileName(me3PackageP)}");
                    var outFile = Path.Combine(me3OutputFolder, bankName + ".bnk");
                    var wwiseBin = ObjectBinary.From<LegendaryExplorerCore.Unreal.BinaryConverters.WwiseBank>(bankExport);
                    File.WriteAllBytes(outFile, wwiseBin.BnkFile);
                    dumpedBanks[bankName] = me3PackageP;
                }
            }
        }

        internal static void ConvertBanks()
        {
            var inputDir = @"S:\Milan\Audio\ME3Banks";
            var outputDir = @"S:\Milan\Audio\BankConvert";
            Parallel.ForEach(Directory.GetFiles(inputDir, "*.bnk"), new ParallelOptions { MaxDegreeOfParallelism = 8 }, bankFile =>
            {
                if (Path.GetFileNameWithoutExtension(bankFile) == "Init")
                    return; // We do not convert Init

                var outFile = Path.Combine(outputDir, Path.GetFileName(bankFile));
                if (File.Exists(outFile))
                {
                    return; // Skip
                }
                try
                {
                    var bankVersion = WwiseBankParser.GetWwiseBankVersion(new MemoryStream(File.ReadAllBytes(bankFile)));
                    if (bankVersion == 56)
                    {
                        Console.WriteLine($"Converting {Path.GetFileName(bankFile)} (version {bankVersion})");
                        var me3Bank = WwiseBankParser.Deserialize(new MemoryStream(File.ReadAllBytes(bankFile)));
                        WwiseBankConverter.ConvertBank(me3Bank, 134);
                        using var outFs = new FileStream(outFile, FileMode.Create, FileAccess.Write);
                        ME3Tweaks.Wwiser.WwiseBankParser.Serialize(me3Bank, outFs);
                        Console.WriteLine($"  Conversion complete for {Path.GetFileName(bankFile)}");
                    }
                    else
                    {
                        Console.WriteLine($"Skipping {Path.GetFileName(bankFile)} (version {bankVersion})");
                    }
                }
                catch (Exception ex)
                {
                    Console.WriteLine($">>> ERROR GETTING BANK VERSION FOR {bankFile} {ex}");
                }
            });
        }

        private static string ResolveWwiseHookExecutable()
        {
            var searchDirectory = new DirectoryInfo(AppContext.BaseDirectory);
            var checkedCandidates = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            while (searchDirectory != null)
            {
                var candidatePaths = new[]
                {
                    Path.Combine(searchDirectory.FullName, "WwiseHook.exe"),
                    Path.Combine(searchDirectory.FullName, "WwiseHook", "x64", "Debug", "WwiseHook.exe"),
                    Path.Combine(searchDirectory.FullName, "WwiseHook", "x64", "Release", "WwiseHook.exe")
                };

                foreach (var candidatePath in candidatePaths)
                {
                    if (checkedCandidates.Add(candidatePath) && File.Exists(candidatePath))
                    {
                        return candidatePath;
                    }
                }

                searchDirectory = searchDirectory.Parent;
            }

            throw new FileNotFoundException("Could not locate WwiseHook.exe. Build the WwiseHook project first.");
        }

        private static string ParseAkResultToken(string stdOut, int exitCode)
        {
            using var reader = new StringReader(stdOut);
            string? line;
            while ((line = reader.ReadLine()) != null)
            {
                // Debug.WriteLine(line);
                const string resultPrefix = "RESULT_TOKEN:";
                if (line.StartsWith(resultPrefix, StringComparison.Ordinal))
                {
                    return line[resultPrefix.Length..].Trim();
                }
            }

            return $"AK_Unknown({exitCode})";
        }

        internal static void AnalyzeBanks()
        {
            var inputDir = @"S:\Milan\Audio\BankConvert";
            var wwiseHookExe = ResolveWwiseHookExecutable();
            Console.WriteLine($"Using WwiseHook at: {wwiseHookExe}");

            foreach (var bankFile in Directory.GetFiles(inputDir, "*.bnk"))
            {
                var bankVersion = WwiseBankParser.GetWwiseBankVersion(new MemoryStream(File.ReadAllBytes(bankFile)));
                if (bankVersion != 134)
                {
                    Console.Error.WriteLine($"Bank {Path.GetFileName(bankFile)} has incorrect version {bankVersion}!");
                    continue;
                }

                var startInfo = new System.Diagnostics.ProcessStartInfo
                {
                    FileName = wwiseHookExe,
                    Arguments = $"--file \"{bankFile}\"",
                    UseShellExecute = false,
                    RedirectStandardOutput = true,
                    RedirectStandardError = true,
                    CreateNoWindow = true
                };

                using var process = System.Diagnostics.Process.Start(startInfo);
                if (process == null)
                {
                    Console.Error.WriteLine($"Failed to start WwiseHook for {Path.GetFileName(bankFile)}");
                    continue;
                }

                var stdOut = process.StandardOutput.ReadToEnd();
                var stdErr = process.StandardError.ReadToEnd();
                process.WaitForExit();

                var akResultString = ParseAkResultToken(stdOut, process.ExitCode);
                Console.WriteLine($"{Path.GetFileName(bankFile)} => {akResultString} ({process.ExitCode})");
                //if (!string.IsNullOrWhiteSpace(stdErr))
                //{
                //    Console.Error.WriteLine(stdErr.Trim());
                //}
            }
        }

        /// <summary>
        /// Peak sample amplitude below which a captured event is reported as silent. 16-bit PCM full scale is
        /// 32767 - real (even quiet) dialogue/SFX peaks are almost always at least a few hundred; this is set low
        /// enough to only flag genuine silence/near-silence, not just quiet audio.
        /// </summary>
        private const short SilentPeakThreshold = 80;

        private readonly record struct WavStats(int SampleCount, double Rms, double PeakAbs, bool IsSilent);

        /// <summary>
        /// Reads a PCM or IEEE-float WAV file (as produced by AK::SoundEngine::StartOutputCapture) and computes
        /// peak/RMS amplitude, normalized to a 16-bit-equivalent scale regardless of source bit depth/format.
        /// </summary>
        private static WavStats AnalyzeWavSilence(string wavPath)
        {
            var bytes = File.ReadAllBytes(wavPath);
            if (bytes.Length < 12 || bytes[0] != 'R' || bytes[1] != 'I' || bytes[2] != 'F' || bytes[3] != 'F')
            {
                throw new InvalidDataException($"{wavPath} is not a valid RIFF/WAV file");
            }

            ushort audioFormat = 0, bitsPerSample = 0;
            int dataOffset = -1, dataSize = 0;

            var pos = 12;
            while (pos + 8 <= bytes.Length)
            {
                var tag = System.Text.Encoding.ASCII.GetString(bytes, pos, 4);
                var chunkSize = BitConverter.ToUInt32(bytes, pos + 4);
                var chunkStart = pos + 8;

                if (tag == "fmt ")
                {
                    audioFormat = BitConverter.ToUInt16(bytes, chunkStart);
                    bitsPerSample = BitConverter.ToUInt16(bytes, chunkStart + 14);
                }
                else if (tag == "data")
                {
                    dataOffset = chunkStart;
                    dataSize = (int)Math.Min(chunkSize, (uint)(bytes.Length - chunkStart));
                }

                pos = chunkStart + (int)chunkSize + (chunkSize % 2 == 1 ? 1 : 0);
            }

            if (dataOffset < 0 || bitsPerSample == 0)
            {
                return new WavStats(0, 0, 0, true); // no data chunk at all - treat as silent/empty capture
            }

            double sumSq = 0, peak = 0;
            int sampleCount;

            if (audioFormat == 3 && bitsPerSample == 32) // IEEE float
            {
                sampleCount = dataSize / 4;
                for (var i = 0; i < sampleCount; i++)
                {
                    var f = BitConverter.ToSingle(bytes, dataOffset + i * 4);
                    var scaled = f * 32768.0; // normalize to 16-bit-equivalent scale for a consistent threshold
                    sumSq += scaled * scaled;
                    peak = Math.Max(peak, Math.Abs(scaled));
                }
            }
            else if (audioFormat == 1 && bitsPerSample == 16) // 16-bit PCM
            {
                sampleCount = dataSize / 2;
                for (var i = 0; i < sampleCount; i++)
                {
                    var s = BitConverter.ToInt16(bytes, dataOffset + i * 2);
                    sumSq += (double)s * s;
                    peak = Math.Max(peak, Math.Abs((double)s));
                }
            }
            else
            {
                throw new NotSupportedException($"{wavPath}: unsupported WAV format (audioFormat={audioFormat}, bitsPerSample={bitsPerSample})");
            }

            var rms = sampleCount > 0 ? Math.Sqrt(sumSq / sampleCount) : 0;
            return new WavStats(sampleCount, rms, peak, peak < SilentPeakThreshold);
        }

        private static string? _cachedLE3InitBankPath;

        /// <summary>
        /// WwiseHook requires a real Init.bnk next to whatever bank it loads, and there's no converted one lying
        /// around anywhere in this pipeline - Init.bnk is LE3's own base engine setup (buses, etc.), not ME3
        /// content, so it's never touched by AudioPipeline at all. Extracts it once (cached for the rest of the
        /// process) from the actual LE3 game install's SFXWwise_Init package - same source BusIdMap.cs's
        /// hand-exported text dumps came from - and writes it to a stable location for reuse.
        /// </summary>
        private static string EnsureLE3InitBank()
        {
            if (_cachedLE3InitBankPath != null && File.Exists(_cachedLE3InitBankPath))
                return _cachedLE3InitBankPath;

            if (!MELoadedFiles.TryGetHighestMountedFile(MEGame.LE3, "WwiseAudio.pcc", out var pccPath))
            {
                throw new FileNotFoundException("Could not find WwiseAudio.pcc in the mounted LE3 game - is the LE3 install/target set up correctly?");
            }

            using var package = MEPackageHandler.OpenMEPackage(pccPath, forceLoadFromDisk: true);
            var bankExport = package.Exports.FirstOrDefault(x => x.ClassName == "WwiseBank" && x.ObjectName == "Init")
                ?? throw new InvalidOperationException($"No Init WwiseBank export found in {pccPath}");

            var bin = ObjectBinary.From<LegendaryExplorerCore.Unreal.BinaryConverters.WwiseBank>(bankExport);
            if (bin.BnkFile.Length == 0)
            {
                throw new InvalidOperationException($"{bankExport.InstancedFullPath} in {pccPath} is a 0-byte bank");
            }

            var cacheDir = Path.Combine(MilanShared.PipelineRoot, "Audio", "Wwise");
            Directory.CreateDirectory(cacheDir);
            var outPath = Path.Combine(cacheDir, "Init.bnk");
            File.WriteAllBytes(outPath, bin.BnkFile);

            Console.WriteLine($"Extracted LE3 Init.bnk from {bankExport.InstancedFullPath} ({pccPath}) -> {outPath}");
            _cachedLE3InitBankPath = outPath;
            return outPath;
        }

        /// <summary>
        /// Dumps every WwiseBank export from an already-built output package (i.e. a .pcc that's been through
        /// AudioPipeline - there is no standalone "converted bank" file anywhere; the converted bytes are written
        /// straight into the export in memory during ConvertBankBodiesInPackages and only ever exist on disk
        /// embedded in the package) to standalone .bnk files under <paramref name="outputDir"/>, alongside a copy
        /// of the real LE3 Init.bnk (see <see cref="EnsureLE3InitBank"/>) so the result is directly loadable by
        /// <see cref="TestBankAudio"/>/WwiseHook.exe.
        ///
        /// Also stages every WEM from <see cref="AFCHandler.WemDiskCacheFolder"/> (named "&lt;sourceId&gt;.wem",
        /// same as the cache) into <paramref name="outputDir"/>. Most game audio is streamed, not embedded - WwiseHook
        /// uses the Wwise SDK's unmodified default low-level I/O sample, which resolves a streamed source by opening
        /// "&lt;sourceId&gt;.wem" straight out of the bank's own directory (confirmed against the actual SDK sample
        /// source, AkFileLocationBase.cpp's ID_TO_STRING_FORMAT_WEM). It has no idea about the combined-AFC-with-
        /// byte-offsets scheme Unreal's own Wwise integration uses at runtime - that redirection is custom engine
        /// code this harness doesn't have - so without this, every streamed event would fail to open its audio and
        /// only genuinely-embedded (Data-type) sources would play. This copies the *entire* cache indiscriminately
        /// (scoping it to just this bank's referenced IDs would need a v134-aware HIRC source scan that doesn't exist
        /// in BankConverter yet - it only reads v56 for the conversion direction it actually needs) - expect this to
        /// take a while / use real disk space the first time, proportional to how much audio the pipeline has
        /// converted and cached so far.
        /// </summary>
        /// <param name="pccPath">Path to a package from the OUTPUT mod (post-pipeline), not the source ME3 game.</param>
        /// <param name="outputDir">Where to write the extracted .bnk file(s), Init.bnk, and staged WEMs.</param>
        /// <returns>Paths to every extracted (non-Init) .bnk file.</returns>
        internal static List<string> ExtractConvertedBanksForTesting(string pccPath, string outputDir)
        {
            Directory.CreateDirectory(outputDir);
            File.Copy(EnsureLE3InitBank(), Path.Combine(outputDir, "Init.bnk"), overwrite: true);

            var wemFiles = Directory.GetFiles(AFCHandler.WemDiskCacheFolder, "*.wem");
            Console.WriteLine($"Staging {wemFiles.Length} cached WEM(s) into {outputDir} (for streamed source lookups)...");
            var stagedCount = 0;
            foreach (var wemFile in wemFiles)
            {
                var dest = Path.Combine(outputDir, Path.GetFileName(wemFile));
                if (File.Exists(dest)) continue; // already staged from a previous call into this same dir
                File.Copy(wemFile, dest);
                stagedCount++;
            }
            Console.WriteLine($"  Staged {stagedCount} new WEM(s) ({wemFiles.Length - stagedCount} already present).");

            var extractedPaths = new List<string>();
            using var package = MEPackageHandler.OpenMEPackage(pccPath, forceLoadFromDisk: true);
            foreach (var exp in package.Exports.Where(x => x.ClassName == "WwiseBank"))
            {
                var bin = ObjectBinary.From<LegendaryExplorerCore.Unreal.BinaryConverters.WwiseBank>(exp);
                if (bin.BnkFile.Length == 0)
                {
                    Console.WriteLine($"  Skipping {exp.InstancedFullPath} - 0-byte bank");
                    continue;
                }

                var bankVersion = WwiseBankParser.GetWwiseBankVersion(new MemoryStream(bin.BnkFile));
                if (bankVersion != 134)
                {
                    Console.WriteLine($"  Skipping {exp.InstancedFullPath} - version {bankVersion}, not 134 (this package hasn't been through AudioPipeline, or this bank was left unconverted)");
                    continue;
                }

                var outPath = Path.Combine(outputDir, exp.ObjectName.Instanced + ".bnk");
                File.WriteAllBytes(outPath, bin.BnkFile);
                Console.WriteLine($"  Extracted {exp.InstancedFullPath} -> {outPath}");
                extractedPaths.Add(outPath);
            }

            return extractedPaths;
        }

        /// <summary>
        /// Loads <paramref name="bankFilePath"/> (must be a v134/LE-era bank - see
        /// <see cref="ExtractConvertedBanksForTesting"/> to get one out of an already-built output package) in the
        /// real Wwise 2019.1.6 runtime via WwiseHook.exe, posts every event found in its HIRC, captures each one's
        /// actual mixed audio output to a WAV, and reports which ones came out silent. This is the concrete way to
        /// find out whether "no sound" for a given event is real (HIRC object dropped during conversion, wrong bus
        /// routing, etc.) rather than just suspected - see AudioPipeline's HIRC-skip/bus-fallback diagnostics for
        /// the most likely *causes* once you know *which* events are actually silent here.
        /// </summary>
        /// <param name="bankFilePath">Path to a v134 .bnk file. Its Init.bnk must exist in the same directory - see <see cref="ExtractConvertedBanksForTesting"/>, which places one automatically.</param>
        /// <param name="captureDir">Where to write event_&lt;id&gt;.wav files. Defaults to a fresh temp folder (printed, not auto-deleted, so you can listen to the results afterward).</param>
        /// <param name="capturePumpMs">How long to let each event play before stopping it. Should comfortably exceed the longest event's real duration.</param>
        internal static void TestBankAudio(string bankFilePath, string? captureDir = null, int capturePumpMs = 4000)
        {
            var bankVersion = WwiseBankParser.GetWwiseBankVersion(new MemoryStream(File.ReadAllBytes(bankFilePath)));
            if (bankVersion != 134)
            {
                Console.Error.WriteLine($"{Path.GetFileName(bankFilePath)} is version {bankVersion}, not 134 - WwiseHook needs a real v134 bank loadable by the actual Wwise 2019.1.6 runtime.");
                return;
            }

            captureDir ??= Path.Combine(Path.GetTempPath(), "MilanBankAudioTest_" + Guid.NewGuid().ToString("N")[..8]);
            Directory.CreateDirectory(captureDir);

            var wwiseHookExe = ResolveWwiseHookExecutable();
            Console.WriteLine($"Using WwiseHook at: {wwiseHookExe}");
            Console.WriteLine($"Capturing event audio to: {captureDir}");

            var startInfo = new ProcessStartInfo
            {
                FileName = wwiseHookExe,
                Arguments = $"--file \"{bankFilePath}\" --capture-dir \"{captureDir}\" --capture-ms {capturePumpMs}",
                UseShellExecute = false,
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                CreateNoWindow = true
            };

            using var process = Process.Start(startInfo);
            if (process == null)
            {
                Console.Error.WriteLine($"Failed to start WwiseHook for {Path.GetFileName(bankFilePath)}");
                return;
            }

            var stdOut = process.StandardOutput.ReadToEnd();
            var stdErr = process.StandardError.ReadToEnd();
            process.WaitForExit();

            var akResultString = ParseAkResultToken(stdOut, process.ExitCode);
            Console.WriteLine($"LoadBank result: {akResultString} (exit {process.ExitCode})");
            if (!string.IsNullOrWhiteSpace(stdErr))
            {
                Console.Error.WriteLine(stdErr.Trim());
            }

            var capturedIds = stdOut.Split('\n')
                .Where(l => l.StartsWith("EVENT_CAPTURE:", StringComparison.Ordinal))
                .Select(l => l["EVENT_CAPTURE:".Length..].Trim())
                .ToList();

            if (capturedIds.Count == 0)
            {
                Console.WriteLine("No events were captured (bank failed to load, had no events, or StartOutputCapture never succeeded - check the log above).");
                return;
            }

            Console.WriteLine($"\n--- {capturedIds.Count} event(s) captured - analyzing for silence ---");
            var silentCount = 0;
            foreach (var eventId in capturedIds)
            {
                var wavPath = Path.Combine(captureDir, $"event_{eventId}.wav");
                if (!File.Exists(wavPath))
                {
                    Console.WriteLine($"  {eventId}: NO WAV PRODUCED (capture said it started but no file exists)");
                    continue;
                }

                try
                {
                    var stats = AnalyzeWavSilence(wavPath);
                    var verdict = stats.IsSilent ? "SILENT" : "audible";
                    if (stats.IsSilent) silentCount++;
                    Console.WriteLine($"  {eventId}: {verdict} (peak={stats.PeakAbs:F0}, rms={stats.Rms:F1}, {stats.SampleCount} samples) - {wavPath}");
                }
                catch (Exception ex)
                {
                    Console.WriteLine($"  {eventId}: FAILED TO ANALYZE ({ex.Message}) - {wavPath}");
                }
            }

            Console.WriteLine($"\n{silentCount}/{capturedIds.Count} event(s) were silent. Captures kept at: {captureDir}");
        }

        internal static void InstallSoundBanks()
        {
            var convertedDir = @"S:\Milan\Audio\BankDump\ClaudeConverted";
            var modDir = Path.Combine(LMPDirectory.DefaultGamePath, @"BioGame\DLC\DLC_MOD_ProjectMilan\CookedPCConsole");
            foreach (var f in Directory.GetFiles(modDir, "*.pcc", SearchOption.AllDirectories))
            {
                using var package = MEPackageHandler.OpenMEPackage(f);
                foreach (var bankExport in package.Exports.Where(x => x.ClassName == "WwiseBank"))
                {
                    var bankName = bankExport.ObjectName.Instanced;
                    var convertedBankPath = Path.Combine(convertedDir, bankName + ".bnk");
                    if (File.Exists(convertedBankPath))
                    {
                        Console.WriteLine($"Installing {bankName} into {package.FileNameNoExtension}");
                        ObjectBinary.EditBinary<LegendaryExplorerCore.Unreal.BinaryConverters.WwiseBank>(bankExport, x => x.BnkFile = File.ReadAllBytes(convertedBankPath));
                    }
                }
                if (package.IsModified)
                {
                    package.Save();
                }
            }
        }

        internal static void TestBankAudio()
        {
            throw new NotImplementedException();
        }

        internal static void TestSilent()
        {
            var banks = Research.ExtractConvertedBanksForTesting(@"S:\SteamLibrary\steamapps\common\Mass Effect Legendary Edition\Game\LMP\BioGame\DLC\DLC_MOD_ProjectMilan\CookedPCConsole\Kits\Asari_Adept_MP_LOC_INT.pcc", @"C:\temp\bnktest");
            foreach (var bank in banks) Research.TestBankAudio(bank);
        }

        internal static void TestBuildLavaTerrainSetup()
        {
            // target file should contain terrain without 'Layers' property
            var ahernMap = true;
            var lavaFile = @"S:\SteamLibrary\steamapps\common\Mass Effect Legendary Edition\Game\LMP\BioGame\DLC\DLC_MOD_PMR3\CookedPCConsole\Levels\BioP_MPPSAhern\BioA_MPPSAhern_TERRAIN.pcc";
            var targetTerrainSetupFile = @"S:\SteamLibrary\steamapps\common\Mass Effect Legendary Edition\Game\ME1\BioGame\CookedPCConsole\BIOA_LAV60_00_LAY.pcc";

            // ahernMap = false;
            //var lavaFile = @"S:\SteamLibrary\steamapps\common\Mass Effect Legendary Edition\Game\LMP\BioGame\DLC\DLC_MOD_PMR3\CookedPCConsole\Levels\BioP_MPPSLava\BioA_MPPSLava_TERRAIN.pcc";
            //var targetTerrainSetupFile = @"S:\SteamLibrary\steamapps\common\Mass Effect Legendary Edition\Game\ME1\BioGame\CookedPCConsole\BIOA_LAV60_00_LAY.pcc";


            using var lavaPackage = MEPackageHandler.OpenMEPackage(lavaFile);
            using var terrainSetupPackage = MEPackageHandler.OpenMEPackage(targetTerrainSetupFile);

            MilanLog.Information($"Porting terrain layer setup from {terrainSetupPackage.FileNameNoExtension} to {lavaPackage.FileNameNoExtension}");


            var terrainExport = terrainSetupPackage.Exports.FirstOrDefault(x => x.ClassName == "Terrain");
            if (terrainExport == null)
            {
                throw new InvalidOperationException($"No Terrain export found in {terrainSetupPackage.FileNameNoExtension}");
            }

            // Strip everything but 'Layers'. Must stay on terrain as this struct property must remain parsable as it is an array.
            var olayers = terrainExport.GetProperty<ArrayProperty<StructProperty>>("Layers");
            if (ahernMap)
            {
                // Ahern map has only one alpha map, if we don't remove the layers and correct the index
                // compiler crashes accessing OOB alpha map index
                olayers = new ArrayProperty<StructProperty>("Layers") { olayers[3] };
                olayers[0].Properties.AddOrReplaceProp(new IntProperty(0, "AlphaMapIndex"));
            }
            terrainExport.WriteProperties([olayers]);
            terrainExport.WriteBinary(Terrain.Create());
            terrainExport.ObjectName = "LayerSetupTemp";
            terrainExport.Parent = null;


            // Port to target file so it drags the terrain setups over
            EntryExporter.ExportExportToPackage(terrainExport, lavaPackage, out var layerTerrain);
            var layerTerrainExport = layerTerrain as ExportEntry;

            ArrayProperty<StructProperty> layers = layerTerrainExport.GetProperty<ArrayProperty<StructProperty>>("Layers");
            var lavaterrainExport = lavaPackage.Exports.FirstOrDefault(x => x.ClassName == "Terrain");
            if (lavaterrainExport == null)
            {
                throw new InvalidOperationException($"No Terrain export found in {lavaPackage.FileNameNoExtension}");
            }


            // Overwrite terrain setups
            lavaterrainExport.WriteProperty(layers);
            ObjectBinary.EditBinary<Terrain>(terrainExport, x => x.CachedTerrainMaterials = []); // Strip the cached materials.

            // Get rid of the temp ported object
            EntryPruner.TrashEntryAndDescendants(layerTerrainExport);

            // Required for shader host... Will have to remove later
            ConvertMaterialsToDecooked(lavaPackage, @"E:\Decooked\LE1");

            lavaPackage.Save();
            MilanLog.Information("Done");

            //MilanShaders.InstallTerrainShadersToPackage();
        }

        internal static void TestBuildTerrainPackage()
        {
            var decookedPath = @"E:\Decooked\LE1";

            // Move terrain to target file
            var inputTerrainPackage = @"S:\SteamLibrary\steamapps\common\Mass Effect Legendary Edition\Game\ME1\BioGame\CookedPCConsole\BIOA_LAV60_00_LAY.pcc";
            var outPath = $@"B:\UserProfile\source\repos\ME3Tweaks\ProjectMilan\MilanShaderHost\Test\{Path.GetFileNameWithoutExtension(inputTerrainPackage)}_terrain.pcc";

            MilanLog.Information($"Creating empty level package at {outPath}");
            MEPackageHandler.CreateEmptyLevel(outPath, MEGame.LE3);
            using var package = MEPackageHandler.OpenMEPackage(outPath);

            using var inTerrainPackage = MEPackageHandler.OpenMEPackage(inputTerrainPackage);
            var terrainExport = inTerrainPackage.Exports.FirstOrDefault(x => x.ClassName == "Terrain");
            if (terrainExport == null)
            {
                throw new InvalidOperationException($"No Terrain export found in {inputTerrainPackage}");
            }

            terrainExport.Parent = null;
            MilanLog.Information($"Exporting Terrain {terrainExport.InstancedFullPath} from {inputTerrainPackage} to {outPath}");
            EntryExporter.ExportExportToPackage(terrainExport, package, out var newTerrainExport, null, null);
            newTerrainExport.Parent = package.GetLevel();

            ConvertMaterialsToDecooked(package, decookedPath);
            package.Save();
            MilanLog.Information($"Saved modified package to {outPath}");
        }

        private static void ConvertMaterialsToDecooked(IMEPackage package, string decookedPath)
        {
            // Delete all material children and do a relink against decooked versions
            foreach (var mat in package.Exports.Where(x => x.ClassName == "Material").ToList())
            {
                var linker = mat.GetLinker();
                var file = Path.Combine(decookedPath, linker + ".pcc");
                if (File.Exists(file))
                {
                    using var decookedPackage = MEPackageHandler.OpenMEPackage(file);
                    var decookedMat = decookedPackage.FindExport(mat.InstancedFullPath, "Material");
                    if (decookedMat != null)
                    {
                        MilanLog.Information($"Relinking {mat.InstancedFullPath} to decooked version from {file}");
                        var expressions = package.Exports.Where(x => x.idxLink == decookedMat.UIndex).ToList();
                        EntryPruner.TrashEntries(package, expressions);
                        EntryImporter.ImportAndRelinkEntries(EntryImporter.PortingOption.ReplaceSingularWithRelink, decookedMat, mat.FileRef, mat, true, new RelinkerOptionsPackage(), out _);
                    }
                    else
                    {
                        MilanLog.Warning($"Decooked package {file} does not contain {mat.InstancedFullPath} - leaving original");
                    }
                }
                else
                {
                    MilanLog.Warning($"Decooked package {file} not found for {mat.InstancedFullPath} - leaving original");
                }
            }
        }
        /// <summary>
        /// Dumps the m_aWeapons array of the Data (SFXWeaponUIData) export from every SP and MP weapon UI data
        /// donor package, so the actual struct layout and content can be inspected to build the merge mapping
        /// used by NonStartupPipeline.PortWeaponDataPackage().
        /// </summary>
        internal static void DumpWeaponUIData()
        {
            var spFiles = new[]
            {
                "SFXGUI_WeaponUIDataSF.pcc",
                "SFXGUI_WeaponUIDataDLC_HEN_PRSF.pcc",
                "SFXGUI_WeaponUIDataDLC_CON_GUN01SF.pcc",
                "SFXGUI_WeaponUIDataDLC_CON_GUN02SF.pcc",
                "SFXGUI_WeaponUIDataDLC_SharedSF.pcc",
            };

            var mpFiles = new[]
            {
                "SFXGUI_WeaponUIDataDLC_CON_MP1SF.pcc",
                "SFXGUI_WeaponUIDataDLC_CON_MP2SF.pcc",
                "SFXGUI_WeaponUIDataDLC_CON_MP3SF.pcc",
                "SFXGUI_WeaponUIDataDLC_CON_MP4SF.pcc",
                "SFXGUI_WeaponUIDataDLC_CON_MP5SF.pcc",
                "SFXGUI_WeaponUIDataDLC_SharedSF.pcc",
            };

            Console.WriteLine("======== SP (LE3) FILES ========");
            foreach (var f in spFiles)
            {
                DumpWeaponUIDataFile(MilanShared.GetLE3Package(f), f);
            }

            Console.WriteLine("======== MP (ME3) FILES ========");
            foreach (var f in mpFiles)
            {
                DumpWeaponUIDataFile(MilanShared.GetME3Package(f), f);
            }
        }

        private static void DumpWeaponUIDataFile(IMEPackage package, string fileName)
        {
            Console.WriteLine($"---- {fileName} ----");
            if (package == null)
            {
                Console.WriteLine("  !! COULD NOT LOAD FILE");
                return;
            }

            var dataExports = package.Exports.Where(x => x.ClassName == "SFXWeaponUIData").ToList();
            if (dataExports.Count == 0)
            {
                Console.WriteLine("  !! No SFXWeaponUIData export found. Exports in file:");
                foreach (var e in package.Exports)
                {
                    Console.WriteLine($"    {e.UIndex} {e.InstancedFullPath} ({e.ClassName})");
                }
                return;
            }

            foreach (var dataExport in dataExports)
            {
                Console.WriteLine($"  Export: {dataExport.InstancedFullPath}");
                var weapons = dataExport.GetProperty<ArrayProperty<StructProperty>>("m_aWeapons");
                if (weapons == null)
                {
                    Console.WriteLine("    !! No m_aWeapons property found. All properties:");
                    foreach (var prop in dataExport.GetProperties())
                    {
                        Console.WriteLine($"      {prop.Name} ({prop.PropType})");
                    }
                    continue;
                }

                Console.WriteLine($"    m_aWeapons: {weapons.Count} entries");
                for (var i = 0; i < weapons.Count; i++)
                {
                    Console.WriteLine($"    [{i}]");
                    DumpStruct(package, weapons[i], "      ");
                }
            }
        }

        private static void DumpStruct(IMEPackage package, StructProperty structProp, string indent)
        {
            foreach (var prop in structProp.Properties)
            {
                switch (prop)
                {
                    case ObjectProperty op:
                        var entry = op.Value != 0 ? package.GetEntry(op.Value) : null;
                        Console.WriteLine($"{indent}{prop.Name} (Object) = {entry?.InstancedFullPath ?? "None"}");
                        break;
                    case StructProperty sp:
                        Console.WriteLine($"{indent}{prop.Name} (Struct:{sp.StructType})");
                        DumpStruct(package, sp, indent + "  ");
                        break;
                    case ArrayProperty<StructProperty> asp:
                        Console.WriteLine($"{indent}{prop.Name} (Array<Struct>, {asp.Count} entries)");
                        for (var i = 0; i < asp.Count; i++)
                        {
                            Console.WriteLine($"{indent}  [{i}]");
                            DumpStruct(package, asp[i], indent + "    ");
                        }
                        break;
                    case StringRefProperty srp:
                        Console.WriteLine($"{indent}{prop.Name} (StringRef) = {srp.Value}");
                        break;
                    default:
                        Console.WriteLine($"{indent}{prop.Name} ({prop.PropType}) = {prop}");
                        break;
                }
            }
        }
#endif
    }
}