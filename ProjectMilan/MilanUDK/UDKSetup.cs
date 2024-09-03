using LegendaryExplorerCore.GameFilesystem;
using LegendaryExplorerCore.Helpers;
using LegendaryExplorerCore.Misc;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Packages.CloningImportingAndRelinking;
using LegendaryExplorerCore.UDK;
using LegendaryExplorerCore.Unreal;
using LegendaryExplorerCore.Unreal.BinaryConverters;
using LegendaryExplorerCore.Unreal.Classes;
using LegendaryExplorerCore.Unreal.ObjectInfo;

namespace ProjectMilan.MilanUDK
{
    /// <summary>
    /// Sets up UDK for use with Milan. It is best to make a brand new installation of UDK, separate from the one you use for LEX.
    /// </summary>
    internal class UDKSetup
    {
        private static void EnsureUDK()
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

                setup["bSetupLightingIni"].Value = "true";
            }

            // Save settings of what we've performed
            config.WriteToFile(configPath);
        }

        /// <summary>
        /// Decooks game materials and textures into source-side packages that can be used by UDK. This will take a long time.
        /// </summary>
        public static void DecookMaterials()
        {
            EnsureUDK();
            var loadedFiles = MELoadedFiles.GetFilesLoadedInGame(MEGame.LE3, true, includeModDLC: false);
            addExtraFilesToLoadedFiles(loadedFiles);

            var stagingPath = Directory.CreateDirectory(Path.Combine(UDKDirectory.DefaultGamePath, "MilanMaterialDecook")).FullName;

            // Remove existing files in decook folder
            var existingFiles = Directory.GetFiles(stagingPath);
            foreach (var file in existingFiles)
            {
                File.Delete(file);
            }

            // Global Cache
            var globalTierCache = TieredPackageCache.GetGlobalPackageCache(MEGame.LE3);

            // This process is pretty complicated, but flows like this:
            // Stage 1: Group materials and textures by linker
            CaseInsensitiveDictionary<CaseInsensitiveDictionary<LEXOpenable>> linkerMap = GenerateLinkerMap(loadedFiles);

            // Stage 2: Begin decook by porting materials to their specified packages (same game). We will generate best-effort materials.
            InitialDecook(linkerMap, stagingPath, globalTierCache.ChainNewCache(canPromoteInto: true));
            GC.Collect();

            // Stage 3: Regenerate packages by converting exports dependencies to imports
            SecondStageDecook(stagingPath, globalTierCache.ChainNewCache(canPromoteInto: true)); // Could technically be combined with Stage 4 but for debug its best to have intermediate
            GC.Collect();

            // Stage 4: (TEMPORARY) - Substitute in material expressions so they can be rendered in UDK, even if inaccurate
            InsertMaterialExpressions(stagingPath, globalTierCache.ChainNewCache(canPromoteInto: true));

            // Stage 5: Decook package again to dump out unused imports and exports
            ThirdStageDecook(stagingPath, globalTierCache.ChainNewCache(canPromoteInto: true));
            GC.Collect();

            // Stage 5: Port items to UDK
            PortMaterialsToUDK(stagingPath, globalTierCache.ChainNewCache(canPromoteInto: true));
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

                    List<IEntry> textures = new MaterialInstanceConstant(mat, null, false).Textures;

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
            var isTexture = exp.IsA("Texture");
            var assetCanPort = isTexture || exp.IsA("Material") || exp.ClassName == "MaterialInstanceConstant";
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
            if (isTexture)
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
                if (i % 25 == 0)
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
                PortNonLinkerReferencesAsImports(package, exp);
            }
            //package.Save();
        }

        private static void PortNonLinkerReferencesAsImports(IMEPackage package, ExportEntry exp)
        {
            if (package.FindEntry(exp.InstancedFullPath) != null)
                return; // Object is already in the package

            var references = EntryImporter.GetAllReferencesOfExport(exp);
            var externalToLinkerReferences = references.Where(x => !x.GetLinker().CaseInsensitiveEquals(package.FileNameNoExtension)).ToList();

            // Generate all items external to the link as imports so we don't port them
            var topDownOrdering = externalToLinkerReferences.OrderBy(x => x.InstancedFullPath.Count(x => x == '.')).ToList();
            foreach (var eRef in topDownOrdering)
            {
                if (package.FindEntry(eRef.InstancedFullPath, eRef.ClassName) != null)
                    continue; // Object is already in the package

                IEntry parent = eRef.Parent != null ? package.FindImport(eRef.Parent.InstancedFullPath) : null;
                if (eRef.Parent != null && parent == null)
                {
                    // Doesn't exist yet. Port it in
                    parent = EntryExporter.PortParents(eRef, package, true);
                }
                ImportEntry imp = null;
                if (eRef is ExportEntry exRef)
                {
                    imp = new ImportEntry(exRef, parent?.UIndex ?? 0, package);
                    package.AddImport(imp);
                }
                else if (eRef is ImportEntry exImpRef)
                {
                    EntryImporter.ImportAndRelinkEntries(EntryImporter.PortingOption.CloneAllDependencies, eRef, package, parent, true, new RelinkerOptionsPackage(), out _);
                }
            }
        }

        /// <summary>
        /// Generates the initial packages that contain all materials and sets the ones for the linker to not be ForcedExport once completed
        /// </summary>
        /// <param name="linkerMap"></param>
        private static void InitialDecook(CaseInsensitiveDictionary<CaseInsensitiveDictionary<LEXOpenable>> linkerMap, string stagingPath, TieredPackageCache promotableCache)
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
                //if (matList.Key != "BioT_Human_Ext")
                //    return;

                using var localCache = promotableCache.ChainNewCache();
                using var package = MEPackageHandler.CreateAndOpenPackage(Path.Combine(stagingPath, matList.Key + ".pcc"), MEGame.LE3);
                PregeneratePackage(package, matList.Value);
                package.Save();

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
                    sourceExp.RemoveProperty("PhysMaterial"); // Often brings in things like Wwise which is not supported by UDK
                    PortNonLinkerReferencesAsImports(package, sourceExp);
                    EntryExporter.ExportExportToPackage(sourceExp, package, out var portedObj, localCache, new RelinkerOptionsPackage() { Cache = localCache, PortImportsMemorySafe = true, });
                }

                // package.Save();

                // If resources are stored in globally importable files we have to convert these imports to exports.
                var relinkMap = new ListenableDictionary<IEntry, IEntry>();

                // We cannot trash as we go because .RemoveTrailingTrash() will delete stuff, and that will cause invalid references
                // We cannot have invalid references until relink is completed so we track what we're going to trash and then trash it
                List<IEntry> trashItems = new List<IEntry>();

                // Fix up any imports that came over under the linker. 
                var linkerPackage = package.FindEntry(package.FileNameNoExtension);
                var importsToConvert = package.Imports.Where(x => x.GetRoot() == linkerPackage
                                                                  && !x.ObjectName.Name.StartsWith("PENDINGTRASH_")).ToList();
                while (importsToConvert.Any())
                {
                    foreach (var imp in importsToConvert)
                    {
                        var exp = EntryImporter.ResolveImport(imp, localCache,
                            instancedFullPathOverride: imp.InstancedFullPath.Replace("PENDINGTRASH_", ""));
                        // EntryPruner.TrashEntries(package, [imp]); // Get rid of this
                        imp.ObjectName = $"PENDINGTRASH_{imp.ObjectName}";
                        trashItems.Add(imp);
                        EntryExporter.ExportExportToPackage(exp, package, out var portedSingle, localCache,
                            new RelinkerOptionsPackage() { Cache = localCache });
                        var portedExp = (ExportEntry)portedSingle;
                        portedExp.ExportFlags &= ~UnrealFlags.EExportFlags.ForcedExport; // Remove forced export
                        relinkMap[imp] = portedExp;
                        foreach (var child in package.Tree.GetDirectChildrenOf(imp))
                        {
                            // Reparent children which can happen in multi-nested packages
                            var ifpTest = portedExp.InstancedFullPath + "." + child.ObjectName.Instanced;
                            if (package.FindExport(ifpTest, child.ClassName) == null)
                            {
                                // Move out from under object that is going to be trashed
                                child.Parent = portedExp;
                            }
                        }
                    }

                    // Loop this to convert dependencies that came in
                    importsToConvert = package.Imports.Where(x => x.GetRoot() == linkerPackage
                        && !x.ObjectName.Name.StartsWith("PENDINGTRASH_")).ToList();
                }

                // Clean up forced export and move up to linker so memory path is correct
                linkerPackage = package.FindEntry(package.FileNameNoExtension);
                foreach (var exp in package.Exports.Where(x => x.GetLinker() == package.FileNameNoExtension))
                {
                    exp.ExportFlags &= ~UnrealFlags.EExportFlags.ForcedExport; // Remove forced export
                }

                linkerPackage = package.FindEntry(package.FileNameNoExtension); // Re-fetch linker package as it may be export now instead of import
                var exportsToReparent = package.Exports.Where(x => x.Parent == linkerPackage).ToList();
                foreach (var exp in exportsToReparent)
                {
                    exp.Parent = null;
                }


                package.Save();
                foreach (var imp in package.Imports.Where(x => x.GetRoot() == linkerPackage && x.ClassName != "Package").ToList())
                {
                    var exp = EntryImporter.ResolveImport(imp, localCache, instancedFullPathOverride: imp.InstancedFullPath.Replace("PENDINGTRASH_", ""));
                    if (exp == null)
                    {

                    }
                    // EntryPruner.TrashEntries(package, [imp]); // Get rid of this
                    imp.ObjectName = $"PENDINGTRASH_{imp.ObjectName}";
                    trashItems.Add(imp);
                    EntryExporter.ExportExportToPackage(exp, package, out var portedSingle, localCache, new RelinkerOptionsPackage() { Cache = localCache });
                    var portedExp = (ExportEntry)portedSingle;
                    portedExp.ExportFlags &= ~UnrealFlags.EExportFlags.ForcedExport; // Remove forced export
                    portedExp.Parent = null; // Move to root
                    relinkMap[imp] = portedExp;
                    foreach (var child in package.Tree.GetDirectChildrenOf(imp))
                    {
                        // Reparent children which can happen in multi-nested packages
                        var ifpTest = portedExp.InstancedFullPath + "." + child.ObjectName.Instanced;
                        if (package.FindExport(ifpTest, child.ClassName) == null)
                        {
                            // Move out from under object that is going to be trashed
                            child.Parent = portedExp;
                        }
                    }
                }

                // Pass for reparenting after conversion. There should be new exports so this should 
                // allow us to find new parent packages
                foreach (var exp in package.Exports.Where(x => x != linkerPackage && x.GetRoot() == linkerPackage))
                {
                    if (exp.Parent.HasParent)
                    {
                        // Nested
                        var parentIFP = exp.ParentInstancedFullPath.Substring(linkerPackage.ObjectName.Instanced.Length + 1);
                        var newParent = package.FindExport(parentIFP);
                        if (newParent == null)
                        {

                        }
                        exp.Parent = newParent;
                    }
                    else
                    {
                        // Parent is linker package
                        exp.Parent = null;
                    }
                }

                // package.Save();
                if (relinkMap.Any())
                {
                    // Relink required
                    Relinker.RelinkSamePackage(package, relinkMap);
                }

                EntryPruner.TrashEntries(package, trashItems);

                Interlocked.Increment(ref numDone);
                var percentDone = 100.0f * numDone / numTotal;
                MilanLog.Information($"Saving package {package.FileNameNoExtension} - {percentDone}%");
                package.Save();
            });

            promotableCache.Dispose();
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
                        EntryExporter.ExportExportToPackage(exp, tempPackage, out _, cache);
                    }
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
                foreach (var mat in sourcePackage.Exports.Where(x => x.IsA("Material") || x.IsA("Texture")))
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


        private static void PortMaterialsToUDK(string stagingPath, TieredPackageCache chainNewCache)
        {
            UDKMaterialPort.PortMaterialsIntoUDK(MEGame.LE3, stagingPath, "MilanMaterials", Program.Settings.MilanUDKPath);
        }
    }
}
