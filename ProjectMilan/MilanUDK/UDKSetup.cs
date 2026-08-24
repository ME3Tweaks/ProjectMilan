using System.Diagnostics;
using LegendaryExplorerCore.GameFilesystem;
using LegendaryExplorerCore.Gammtek.Extensions.Collections.Generic;
using LegendaryExplorerCore.Helpers;
using LegendaryExplorerCore.Misc;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Packages.CloningImportingAndRelinking;
using LegendaryExplorerCore.UDK;
using LegendaryExplorerCore.Unreal;
using LegendaryExplorerCore.Unreal.BinaryConverters;
using LegendaryExplorerCore.Unreal.Classes;
using LegendaryExplorerCore.Unreal.ObjectInfo;
using ProjectMilan.Pipelines.StaticLighting;

namespace ProjectMilan.MilanUDK
{
    // DEPRECATED - USE UDKSetupT3D.

    /// <summary>
    /// Sets up UDK for use with Milan. It is best to make a brand new installation of UDK, separate from the one you use for LEX.
    /// </summary>
    internal class UDKSetup
    {
        public static void EnsureUDK()
        {
            var udkDir = Program.Settings.MilanUDKPath;
            if (string.IsNullOrWhiteSpace(udkDir) || !Directory.Exists(udkDir))
            {
                MilanLog.Error($"UDK Directory is not specified or is null: {udkDir}");
                Environment.Exit(1);
            }

            UDKDirectory.DefaultGamePath = udkDir;

            // UDK properties so it doesn't run in parallel
            UDKUnrealObjectInfo.ObjectInfo.LoadData();
        }

        public static void SetupUDK()
        {
            EnsureUDK();

            // See what we have performed
            DuplicatingIni config = null;
            var configPath = Path.Combine(UDKDirectory.DefaultGamePath, "MilanConfig.ini");
            if (File.Exists(configPath))
            {
                // Read configuration
                config = DuplicatingIni.LoadIni(configPath);
            }
            else
            {
                config = new DuplicatingIni();
            }

            var setup = config.GetOrAddSection("Setup");
            if (!setup.TryGetValue("bSetupLightingIni", out var value) || !value.CaseInsensitiveEquals("true"))
            {
                // Set up lighting in the ini files.
                // Todo: Copy from LE3.
                ConfigureLightmass();
                setup["bSetupLightingIni"].Value = "true";
            }

            // Save settings of what we've performed
            config.WriteToFile(configPath);
        }

        private static void ConfigureLightmass()
        {
            var defaultIniPath = Path.Combine(UDKDirectory.UDKGamePath, "Config", "DefaultLightmass.ini");
            var defaultIni = File.Exists(defaultIniPath) ? DuplicatingIni.LoadIni(defaultIniPath) : new DuplicatingIni();

            var sl = defaultIni.GetOrAddSection("DevOptions.StaticLighting");
            sl.SetSingleEntry("bAllowLightmapCompression", "False"); // We will handle lightmap compression ourselves.
            sl.SetSingleEntry("DefaultStaticMeshLightingRes", 128); // Default is 32. Lets make default a bit higher res.

            var ss = defaultIni.GetOrAddSection("DevOptions.StaticShadows");
            ss.SetSingleEntry("bFilterShadowFactor", "False"); // BioWare sets this (from True)
            ss.SetSingleEntry("minunoccludedfraction", 0.01f); // BioWare sets this (from 0.005)
            ss.SetSingleEntry("NumBounceShadowRays", 4); // BioWare sets this (from 1)

            var pcdol = defaultIni.GetOrAddSection("DevOptions.PrecomputedDynamicObjectLighting");
            pcdol.SetSingleEntry("bvisualizevolumelightsamples", "True"); // BioWare sets this (from False) - probably editor only
            pcdol.SetSingleEntry("surfacelightsamplespacing", 750); // BioWare sets this (from 210)


            defaultIni.WriteToFile(defaultIniPath);
        }

        /// <summary>
        /// Decooks game materials and textures into source-side packages that can be used by UDK. This will take a long time.
        /// </summary>
        public static void DecookGameToUDK()
        {
            var game = MEGame.LE3;
            EnsureUDK();
            var loadedFiles = MELoadedFiles.GetFilesLoadedInGame(game, true, includeModDLC: false);
            addExtraFilesToLoadedFiles(loadedFiles);

            var stagingPath = GetMilanDecookedMaterialsStagingDirectory();
            // Global Cache
            var globalTierCache = TieredPackageCache.GetGlobalPackageCache(game);

            // Remove existing files in decook folder
            var existingFiles = Directory.GetFiles(stagingPath);
            foreach (var file in existingFiles)
            {
                File.Delete(file);
            }

            // This process is pretty complicated, but flows like this:
            // Stage 1: Group materials and textures by linker
            CaseInsensitiveDictionary<CaseInsensitiveDictionary<LEXOpenable>> linkerMap = GenerateLinkerMap(loadedFiles);
            GC.Collect(GC.MaxGeneration, GCCollectionMode.Aggressive, true, true);

            // Stage 2: Begin decook by porting materials to their specified packages (same game)
            InitialDecookv2(linkerMap, stagingPath, globalTierCache.ChainNewCache(canPromoteInto: true));
            GC.Collect(GC.MaxGeneration, GCCollectionMode.Aggressive, true, true);

            if (game == MEGame.LE3)
            {
                StripRvrEffectMaterialsFromPackages(stagingPath, globalTierCache.ChainNewCache());
            }

            // Stage 3: Regenerate packages by converting exports dependencies to imports
            SecondStageDecook(stagingPath, globalTierCache.ChainNewCache(canPromoteInto: true)); // Could technically be combined with Stage 4 but for debug its best to have intermediate
            GC.Collect(GC.MaxGeneration, GCCollectionMode.Aggressive, true, true);

            // Stage 4: (TEMPORARY) - Substitute in material expressions so they can be rendered in UDK, even if inaccurate
            InsertMaterialExpressions(stagingPath, globalTierCache.ChainNewCache(canPromoteInto: true));

            // Stage 5: Decook package again to dump out unused imports and exports
            ThirdStageDecook(stagingPath, globalTierCache.ChainNewCache(canPromoteInto: true));
            GC.Collect(GC.MaxGeneration, GCCollectionMode.Aggressive, true, true);

            // Stage 5: Port items to UDK
            PortMaterialsToUDK(stagingPath, globalTierCache.ChainNewCache(canPromoteInto: true));
        }

        private static void StripRvrEffectMaterialsFromPackages(string stagingPath, TieredPackageCache chainNewCache)
        {
            var files = Directory.GetFiles(stagingPath).Where(x => x.RepresentsPackageFilePath()).ToList();
            int numDone = 0;
            int numTotal = files.Count;
            foreach (var file in files)
            {
                // We create new package, as modifying object name to TEMP will cause lookup tree to constantly be invalidated
                // which is really bad for performance
                var package = MEPackageHandler.OpenMEPackage(file);
                StripRvrEffectMaterials(package, chainNewCache);
                Interlocked.Increment(ref numDone);
                var percentDone = 100.0f * numDone / numTotal;

                if (package.IsModified)
                {
                    // Overwrite the original.
                    MilanLog.Information($"Saving RvrEffectMaterialsStripped package {package.FileNameNoExtension} - {percentDone}%");
                    package.Save();
                } 
            }
        }

        private static string GetMilanDecookedMaterialsStagingDirectory()
        {
            return Directory.CreateDirectory(Path.Combine(Program.Settings.MilanUDKPath, "MilanMaterialDecook")).FullName;
        }

        /// <summary>
        /// Gets path where Milan's decooked materials are stored
        /// </summary>
        /// <returns></returns>
        public static string GetMilanDecookedMaterialsDirectory()
        {
            return Path.Combine(UDKDirectory.GetContentPath(Program.Settings.MilanUDKPath), "Shared", "Decooked", "LE3");
        }

        private static void addExtraFilesToLoadedFiles(CaseInsensitiveDictionary<string> loadedFiles)
        {
            // Blank - DO NOT REMOVE THIS EXISTS FOR A REASON.
        }

        private static void InsertMaterialExpressions(string stagingPath, TieredPackageCache promotableCache)
        {
            var udkResources = MEPackageHandler.OpenMEPackageFromStream(LegendaryExplorerCoreUtilities.GetCustomAppResourceStream(MEGame.UDK));

            // This will replace existing material in-place, we will then fix up the expressions on it
            ExportEntry sourceReplacementMaterial = udkResources.Exports.First(exp => exp.ObjectName == "NormDiffMat");

            foreach (var file in Directory.GetFiles(stagingPath).Where(x => x.RepresentsPackageFilePath()))
            {
                if (!DebugFilterFiles(file))
                    return;

                var sourcePackage = MEPackageHandler.OpenMEPackage(file);
                foreach (var mat in sourcePackage.Exports.Where(x => x.IsA("Material")).ToList())
                {
                    if (mat.GetProperty<BoolProperty>("bCanCompileInUDK") is BoolProperty bp && bp.Value)
                        continue; // Do not modify expressions

                    var textures = new MaterialInstanceConstant(mat, null, false).Textures;

                    // HEURISTIC FOR MATERIALS
                    // Determine norm and diff 
                    IEntry diff = null;
                    foreach (IEntry texEntry in textures)
                    {
                        if (texEntry.ObjectName.Name.Contains("diff", StringComparison.OrdinalIgnoreCase))
                        {
                            if (diff != null)
                            {
                                var currentDiffName = diff.ObjectName.Instanced;
                                var testDiffName = texEntry.ObjectName.Instanced;
                                var currentDist = currentDiffName.LevenshteinDistance(mat.ObjectName.Instanced); // Match to mat
                                var testDist = testDiffName.LevenshteinDistance(mat.ObjectName.Instanced); // Match to mat
                                if (testDist < currentDist)
                                {
                                    // Has closer matching name
                                    MilanLog.Information($"LEV DISTANCE SWAPPING DIFF TO {texEntry.ObjectName.Instanced} to match {mat.ObjectName.Instanced}");
                                    diff = texEntry;
                                }
                                continue;
                            }

                            diff = texEntry;
                            // May be more diffs
                        }
                    }

                    // We do a SECOND pass for norms since we use diff for heuristic.
                    IEntry norm = null;
                    foreach (IEntry texEntry in textures)
                    {
                        if (texEntry.ObjectName.Name.Contains("norm", StringComparison.OrdinalIgnoreCase))
                        {
                            if (diff != null && norm != null)
                            {
                                var currentNormName = norm.ObjectName.Instanced;
                                var testNormName = texEntry.ObjectName.Instanced;
                                var currentDist = currentNormName.LevenshteinDistance(diff.ObjectName.Instanced); // Match to diff
                                var testDist = testNormName.LevenshteinDistance(diff.ObjectName.Instanced); // Match to diff
                                if (testDist < currentDist)
                                {
                                    // Has closer matching name
                                    MilanLog.Information($"LEV DISTANCE SWAPPING NORM TO {texEntry.ObjectName.Instanced} to match {diff.ObjectName.Instanced}");
                                    norm = texEntry;
                                }

                                continue;
                            }
                            // Set if null or take existing
                            norm = texEntry;

                            // We do not break as there may be more than one norm
                        }
                    }


                    // Nuke the expressions
                    EntryPruner.TrashEntries(sourcePackage, sourcePackage.Exports.Where(x => x.Parent == mat));

                    // Replace data of material with ours. This will overwrite expressions list
                    EntryImporter.ImportAndRelinkEntries(EntryImporter.PortingOption.ReplaceSingularWithRelink, sourceReplacementMaterial, sourcePackage, mat, true, new RelinkerOptionsPackage(promotableCache), out _);

                    // START HEURISTIC EXPRESSION REPLACEMENT ----------------------
                    var matBin = ObjectBinary.From<Material>(mat);
                    matBin.SM3MaterialResource.UniformExpressionTextures = new[] { norm?.UIndex ?? 0, diff?.UIndex ?? 0 };
                    mat.WriteBinary(matBin);
                    if (mat.GetProperty<ArrayProperty<ObjectProperty>>("Expressions") is { Count: >= 2 } expressionsProp)
                    {
                        ExportEntry diffExpression = sourcePackage.GetUExport(expressionsProp[0].Value);
                        ExportEntry normExpression = sourcePackage.GetUExport(expressionsProp[1].Value);
                        diffExpression.WriteProperty(new ObjectProperty(diff?.UIndex ?? 0, "Texture"));
                        normExpression.WriteProperty(new ObjectProperty(norm?.UIndex ?? 0, "Texture"));
                    }
                    // END HEURISTIC EXPRESSION REPLACEMENT ------------------------
                }

                MilanLog.Information($"Saving heuristic-modified package {sourcePackage.FileNameNoExtension}");
                sourcePackage.Save();
            }
        }

        private static bool DebugFilterFiles(string inPath)
        {
            // DEBUG: Return false to filter out file
            //return inPath.Contains("SFXGame", StringComparison.OrdinalIgnoreCase)
            ;// || inPath.Contains("BioVFX_Z_TEXTURES", StringComparison.OrdinalIgnoreCase);

            // Always perform work
            return true;
        }

        private static bool ShouldPort(ExportEntry exp, bool packageIsCooked)
        {
            if (exp.GetRootName().CaseInsensitiveEquals("TheWorld"))
                return false; // Port nothing in a level.
            var assetCanPort = IsDecookAsset(exp);
            if (!assetCanPort)
                return false;

            // Separated cause it makes debugging easier
            if (!packageIsCooked)
            {
                // Will not have forced export flags
                // Is not a map
                return true;
            }

            // May be a map (may also not be)
            if (exp.IsA("Texture"))
            {
                return !exp.IsA("ShadowMapTexture2D") && !exp.IsA("LightMapTexture2D");
            }

            var isForcedExport = exp.ExportFlags.Has(UnrealFlags.EExportFlags.ForcedExport);
            return isForcedExport;
        }

        /// <summary>
        /// Maps Linker -> Dictionary of IFP->LEXOpenable so we can port each unique object. We can't use object db, because we don't know the object class, and we only care about some classes.
        /// </summary>
        /// <param name="loadedFiles"></param>
        /// <returns></returns>
        private static CaseInsensitiveDictionary<CaseInsensitiveDictionary<LEXOpenable>> GenerateLinkerMap(CaseInsensitiveDictionary<string> loadedFiles)
        {
            object syncObj = new object();
            var linkerMap = new CaseInsensitiveDictionary<CaseInsensitiveDictionary<LEXOpenable>>();
            int i = 0;
            Parallel.ForEach(loadedFiles, file =>
            {
                if (file.Key is "Core.pcc" or "Engine.pcc")
                    return;

                if (!DebugFilterFiles(file.Value))
                    return;
                var package = MEPackageHandler.UnsafePartialLoad(file.Value, x => false);
                var isCooked = package.Flags.Has(UnrealFlags.EPackageFlags.Cooked);


                var itemsToPort = package.Exports.Where(x => !x.IsDefaultObject && ShouldPort(x, isCooked)).ToList();
                foreach (var mat in itemsToPort)
                {
                    var linker = mat.GetLinker();

                    // This looks like it won't save much performance, but it lets packages load in other threads rather than serially in one. 
                    // Not a ton of improvement, but some.
                    lock (syncObj)
                    {
                        if (!linkerMap.TryGetValue(linker, out var elements))
                        {
                            elements = new CaseInsensitiveDictionary<LEXOpenable>();
                            linkerMap[linker] = elements;
                        }

                        if (elements.TryGetValue(mat.InstancedFullPath, out var existing))
                        {
                            continue;
                        }

                        elements[mat.InstancedFullPath] = new LEXOpenable(mat);
                    }
                }

                Interlocked.Increment(ref i);
                if (i % 100 == 0)
                    MilanLog.Information($"Inventoried {i} files");
            });

            // Print results
            foreach (var linker in linkerMap)
            {
                MilanLog.Information($"{linker.Key} => {linker.Value.Count(x => x.Value.EntryClass.CaseInsensitiveEquals("Material"))} materials, {linker.Value.Count(x => x.Value.EntryClass.Contains("Texture", StringComparison.OrdinalIgnoreCase))} textures");
            }

            return linkerMap;
        }

        private static void PregeneratePackage(IMEPackage package, CaseInsensitiveDictionary<LEXOpenable> linkerItems)
        {
            //if (package.FileNameNoExtension != "BioVFX_Z_TEXTURES")
            //    return;

            foreach (var linkerItem in linkerItems)
            {
                var externalPackage = MEPackageHandler.OpenMEPackage(linkerItem.Value.FilePath);
                var exp = externalPackage.GetUExport(linkerItem.Value.EntryUIndex);
                ConvertToUDK.PortNonLinkerReferencesAsImports(package, exp);
            }
            //package.Save();
        }

        private static void InitialDecookv2(CaseInsensitiveDictionary<CaseInsensitiveDictionary<LEXOpenable>> linkerMap, string stagingPath, TieredPackageCache promotableCache)
        {
            var syncObj = new object();
            promotableCache.PackagePromotionThreshold = 8;
            promotableCache.CacheMaxSize = 22; // We have to limit the size of this as decooking uses a ton of memory.
            int numDone = 0;
            int numTotal = linkerMap.Count;
            Parallel.ForEach(linkerMap.OrderByDescending(x => x.Value.Count), new ParallelOptions() { MaxDegreeOfParallelism = 8 }, matList =>
            {
                // Linker map was computed with package list.
                // We don't want to filter it here or it will not find exports from other packages.
                //if (!DebugFilterFiles(matList.Key))
                //    return;

                // Only generates specific package
                //if (!matList.Key.CaseInsensitiveEquals("bioapl_ind_gethpod01"))
                //    return;

                using var localCache = promotableCache.ChainNewCache();
                using var package = MEPackageHandler.CreateAndOpenPackage(Path.Combine(stagingPath, matList.Key + ".pcc"), MEGame.LE3);
                var linkerPackage = ExportCreator.CreatePackageExport(package, matList.Key);
                PregeneratePackage(package, matList.Value);
                // package.Save();

                foreach (var mat in matList.Value)
                {
                    var fPath = mat.Value.FilePath;

                    IMEPackage sourcePackage = null;
                    var fileName = Path.GetFileName(fPath);
                    bool isGlobalFileSource = EntryImporter.IsSafeToImportFrom(fPath, MEGame.LE3, null) && !fileName.CaseInsensitiveEquals("Engine.pcc"); // we want imports from engine as they will also be in UDK
                    if (isGlobalFileSource)
                    {
                        // We are going to be porting out of a global file.
                        // We should open a copy, so we don't get a cached version,
                        // and before porting, we should rename the object, so any children of it don't get pulled in as imports
                        // This is a bit of a hack; this will not cover anything beyond children of this object.
                        sourcePackage = MEPackageHandler.OpenMEPackage(fPath, forceLoadFromDisk: true);
                        sourcePackage.SetInternalFilepath("EXPORTABLE_GLOBALFILE.pcc");
                    }
                    else
                    {
                        sourcePackage = localCache.GetCachedPackage(fPath, openPackageMethod: x =>
                        {
                            lock (syncObj)
                            {
                                return MEPackageHandler.OpenMEPackage(x);
                            }
                        });
                    }

                    var sourceExp = sourcePackage.GetUExport(mat.Value.EntryUIndex);

                    // This will mess up import resolution. We should probably not do it until later
                    // TODO
                    if (sourceExp.GetLinker() == sourcePackage.FileNameNoExtension && sourceExp.GetRootName() != sourcePackage.FileNameNoExtension)
                    {
                        EntryExporter.PrepareGlobalFileForPorting(sourcePackage, sourcePackage.FileNameNoExtension);
                    }

                    sourceExp.RemoveProperty("PhysMaterial"); // Often brings in things like Wwise which is not supported by UDK
                    ConvertToUDK.PortNonLinkerReferencesAsImports(package, sourceExp);
                    EntryExporter.ExportExportToPackage(sourceExp, package, out var portedObj, localCache, new RelinkerOptionsPackage() { Cache = localCache, PortImportsMemorySafe = true, });
                }

                // package.Save();
                ConvertToUDK.ConvertImportsToExportsUnderLinker(package, localCache);

                // Clean up forced export and move up to linker so memory path is correct
                foreach (var exp in package.Exports.Where(x => x.GetLinker() == package.FileNameNoExtension))
                {
                    exp.ExportFlags &= ~UnrealFlags.EExportFlags.ForcedExport; // Remove forced export
                    exp.RemoveProperty("PhysMaterial"); // Often brings in things like Wwise which is not supported by UDK.
                }

                // Move items under linker package up to the root
                foreach (var exp in package.Exports.Where(x => x.Parent == linkerPackage))
                {
                    exp.Parent = null;
                }

                // Get rid of linker package now
                EntryPruner.TrashEntries(package, [linkerPackage]);

                // Hint source-side style individual files for importing during decook
                List<string> leclHints = new List<string>();
                foreach (var imp in package.Imports.Where(x => x.idxLink == 0 && x.ClassName == "Package"))
                {
                    leclHints.Add(imp.ObjectName.Instanced + ".pcc"); // PCC in LE
                }
                package.LECLTagData.ImportHintFiles.ReplaceAll(leclHints);


                Interlocked.Increment(ref numDone);
                var percentDone = 100.0f * numDone / numTotal;
                MilanLog.Information($"Saving package {package.FileNameNoExtension} - {percentDone}%");
                package.Save();
            });

            promotableCache.Dispose();
        }

        private static void StripRvrEffectMaterials(IMEPackage udkPackage, TieredPackageCache localCache)
        {
            // Must remove RvrEffectMaterialsUser here as we will be unable to resolve imports once we lose track of what object ports in MICs
            // This will have poor performance, will have to optimize later
            // Material Instance Constant: If parent is a RvrEffectsMaterialUser, this doesn't exist in UDK and may crash lightmass
            // Repoint parent to parent of the effects material

            foreach (var exp in udkPackage.Exports.Where(x => !x.IsDefaultObject && x.IsA("MaterialInstance")).ToList())
            {
                var parent = exp.GetProperty<ObjectProperty>("Parent");
                if (parent == null)
                    continue; // Edge cases in game
                var parentObj = udkPackage.GetEntry(parent.Value);
                if (parentObj != null)
                {
                    if (parentObj.ClassName.CaseInsensitiveEquals("RvrEffectsMaterialUser"))
                    {
                        // UDK DOES NOT SUPPORT THIS
                        if (parentObj is ExportEntry parentExp)
                        {
                            var baseMat = parentExp.GetProperty<ObjectProperty>("m_pBaseMaterial");
                            exp.WriteProperty(new ObjectProperty(baseMat.Value, "Parent")); // Skip to parent.
                        }
                        else if (parentObj is ImportEntry parentImp)
                        {
                            var resolvedImport = EntryImporter.ResolveImport(parentImp, localCache);
                            if (resolvedImport != null)
                            {
                                var baseMat = resolvedImport.GetProperty<ObjectProperty>("m_pBaseMaterial");
                                var baseEntry = resolvedImport.FileRef.GetEntry(baseMat.Value);
                                var existingEntry = udkPackage.FindEntry(baseEntry.MemoryFullPath, baseEntry.ClassName);
                                if (existingEntry == null)
                                {
                                    if (baseEntry is ImportEntry baseImport)
                                    {
                                        var parentTemp = EntryExporter.PortParents(baseEntry, udkPackage, true);
                                        EntryImporter.ImportAndRelinkEntries(
                                            EntryImporter.PortingOption.AddSingularAsChild, baseImport, udkPackage,
                                            parentTemp, true, new RelinkerOptionsPackage(), out existingEntry);
                                    }
                                }

                                exp.WriteProperty(new ObjectProperty(existingEntry, "Parent")); // Skip to parent.
                            }
                            else
                            {
                                Debug.WriteLine("COULD NOT RESOLVE PARENT!");
                            }
                        }
                    }
                }
            }
        }


        private static void SecondStageDecook(string stagingPath, TieredPackageCache promotableCache)
        {
            //foreach (var file in Directory.GetFiles(stagingPath).Where(x => x.RepresentsPackageFilePath()))
            var files = Directory.GetFiles(stagingPath).Where(x => x.RepresentsPackageFilePath()).ToList();
            int numDone = 0;
            int numTotal = files.Count;
            Parallel.ForEach(files, file =>
            {
                //if (!DebugFilterFiles(file))
                //    return;

                using var cache = promotableCache.ChainNewCache();

                // We create new package, as modifying object name to TEMP will cause lookup tree to constantly be invalidated
                // which is really bad for performance
                var package = MEPackageHandler.OpenMEPackage(file);
                var tempPackage = MEPackageHandler.CreateMemoryEmptyPackage(file, package.Game);

                // Exports outside of the linker. Ordered by number of packages in heirarchy
                var exportsOutsideOfLinker = package.Exports.OfType<IEntry>()
                    .Where(x => x.GetLinker() != package.FileNameNoExtension).OrderBy(x => x.InstancedFullPath.Count(x => x == '.'))
                    .ToList();

                // Port existing imports first
                foreach (var imp in package.Imports.OrderBy(x => x.InstancedFullPath.Count(y => y == '.')))
                {
                    var parent = imp.HasParent ? tempPackage.FindEntry(imp.ParentInstancedFullPath) : null;

                    // Port import
                    EntryImporter.GetOrAddCrossImportOrPackage(imp.InstancedFullPath, package, tempPackage,
                        new RelinkerOptionsPackage(), forcedLink: parent?.UIndex);

                }

                foreach (var entry in exportsOutsideOfLinker)
                {
                    var parent = entry.HasParent ? tempPackage.FindEntry(entry.ParentInstancedFullPath) : null;
                    if (entry is ExportEntry exp)
                    {
                        // Generate import
                        ImportEntry imp = new ImportEntry(exp, parent?.UIndex ?? 0, tempPackage);
                        tempPackage.AddImport(imp);
                    }
                    else
                    {
                        // Port import
                        EntryImporter.GetOrAddCrossImportOrPackage(entry.InstancedFullPath, package, tempPackage,
                            new RelinkerOptionsPackage(), forcedLink: parent?.UIndex);
                    }
                }

                // Port remaining content
                foreach (var exp in package.Exports)
                {
                    if (tempPackage.FindEntry(exp.InstancedFullPath, exp.ClassName) == null)
                    {
                        if (exp.IsA("RB_BodySetup"))
                        {
                            // Remove any references to physical materials, they almost always will contain Wwise audio
                            exp.RemoveProperty("PhysMaterial");
                        }

                        EntryExporter.ExportExportToPackage(exp, tempPackage, out _, cache);
                    }
                }

                foreach (var exp in tempPackage.Exports.Where(x => x.IsA("MaterialInstance")))
                {
                    // Remove static permutation resource as we don't port the shader bytecode to UDK
                    exp.RemoveProperty("bHasStaticPermutationResource");
                    exp.WriteBinary([]);
                }


                Interlocked.Increment(ref numDone);
                var percentDone = 100.0f * numDone / numTotal;
                MilanLog.Information($"Saving second stage package {package.FileNameNoExtension} - {percentDone}%");
                tempPackage.Save();
            });

            promotableCache.Dispose();
        }

        private static void ThirdStageDecook(string stagingPath, TieredPackageCache promotableCache)
        {
            var files = Directory.GetFiles(stagingPath).Where(x => x.RepresentsPackageFilePath()).ToList();
            int numDone = 0;
            int numTotal = files.Count;
            foreach (var file in files)
            {
                //if (!DebugFilterFiles(file))
                //    return;

                var localCache = promotableCache.ChainNewCache();
                var sourcePackage = MEPackageHandler.OpenMEPackage(file);
                var destPackage = MEPackageHandler.CreateMemoryEmptyPackage(file, MEGame.LE3);
                foreach (var mat in sourcePackage.Exports.Where(IsDecookAsset))
                {
                    EntryExporter.ExportExportToPackage(mat, destPackage, out _, localCache);
                }

                // Overwrite the original.
                Interlocked.Increment(ref numDone);
                var percentDone = 100.0f * numDone / numTotal;
                MilanLog.Information($"Saving third stage package {destPackage.FileNameNoExtension} - {percentDone}%");
                destPackage.Save(file);
            }
        }

        private static bool IsDecookAsset(ExportEntry x)
        {
            if (x.IsA("Material"))
                return true;
            if (x.IsA("Texture"))
                return true;

            // Don't want bio version
            if (x.ClassName.CaseInsensitiveEquals("MaterialInstanceConstant"))
                return true;

            // Might be IsA()
            if (x.ClassName.CaseInsensitiveEquals("StaticMesh"))
                return true;
            return false;
        }


        private static void PortMaterialsToUDK(string stagingPath, TieredPackageCache chainNewCache)
        {
            UDKMaterialPort.PortMaterialsIntoUDK(MEGame.LE3, stagingPath, "MilanMaterials", Program.Settings.MilanUDKPath, IsDecookAsset);
        }

        public static void TestConvertToUDK()
        {
            // var biop = @"Z:\ModLibrary\LE3\Project Milan\DLC_MOD_ProjectMilan\CookedPCConsole\Levels\BioP_MPMoon\BioP_MPMoon.pcc";
            var biop = @"S:\Milan\Scottina\BioP_UDKLighting_CitHub_Temple.pcc";
            var package = MEPackageHandler.OpenMEPackage(biop);
            StaticLightingExport.ExportLevelToUDK(package);
        }

        public static void TestFixingUDKCrash()
        {
            var stagingPath = GetMilanDecookedMaterialsStagingDirectory();
            foreach (var f in Directory.GetFiles(stagingPath))
            {
                var package = MEPackageHandler.OpenMEPackage(f);
                foreach (var mic in package.Exports.Where(x => x.IsA("MaterialInstanceConstant")))
                {
                    mic.RemoveProperty("VectorParameterValues");
                    mic.RemoveProperty("ScalarParameterValues");
                    mic.RemoveProperty("TextureParameterValues");
                }

                if (package.IsModified)
                {
                    MilanLog.Information($"Saving package {package.FileNameNoExtension}");
                    package.Save();
                }
            }
        }
    }
}
