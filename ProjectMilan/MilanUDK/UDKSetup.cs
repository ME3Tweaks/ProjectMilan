using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using LegendaryExplorerCore.GameFilesystem;
using LegendaryExplorerCore.Helpers;
using LegendaryExplorerCore.Misc;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Packages.CloningImportingAndRelinking;
using LegendaryExplorerCore.UDK;
using LegendaryExplorerCore.Unreal;
using LegendaryExplorerCore.Unreal.BinaryConverters;
using LegendaryExplorerCore.Unreal.ObjectInfo;
using ProjectMilanCore;

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

            // Stage 4: Decook package again to dump out unused imports and exports
            ThirdStageDecook(stagingPath, globalTierCache.ChainNewCache(canPromoteInto: true));
            GC.Collect();

            // Stage 5: Port items to UDK, with heuristic for generating materials that will preview in editor
            PortMaterialsToUDK(stagingPath, globalTierCache.ChainNewCache(canPromoteInto: true));
        }


        private static bool DebugFilterFiles(string inPath)
        {
            // DEBUG: Return false to filter out file
            // return inPath.Contains("BioApl_GUI_terminal", StringComparison.OrdinalIgnoreCase);
            
            // Always perform work
            return true;
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

                var package = MEPackageHandler.UnsafePartialLoad(file.Value, x => false);
                foreach (var mat in package.Exports.Where(x =>
                             !x.IsDefaultObject && (x.IsA("Material") || x.IsA("Texture")) &&
                             Enums.Has(x.ExportFlags, UnrealFlags.EExportFlags.ForcedExport)))
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
                    Debug.WriteLine($"Inventoried {i} files");
            });

            // Print results
            foreach (var linker in linkerMap)
            {
                Debug.WriteLine($"{linker.Key} => {linker.Value.Count} materials");
            }

            return linkerMap;
        }

        /// <summary>
        /// Generates the initial packages that contain all materials and sets the ones for the linker to not be ForcedExport once completed
        /// </summary>
        /// <param name="linkerMap"></param>
        private static void InitialDecook(CaseInsensitiveDictionary<CaseInsensitiveDictionary<LEXOpenable>> linkerMap, string stagingPath, TieredPackageCache promotableCache)
        {
            var syncObj = new object();

            Parallel.ForEach(linkerMap, matList =>
            {
                if (!DebugFilterFiles(matList.Key))
                    return;

                var localCache = promotableCache.ChainNewCache();
                var package = MEPackageHandler.CreateAndOpenPackage(Path.Combine(stagingPath, matList.Key + ".pcc"), MEGame.LE3);
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
                    //int originalIndexValue = sourceExp.indexValue;
                    //if (isGlobalFileSource)
                    //{
                    //    sourceExp.indexValue = 1000000; // This won't be used. I hope!
                    //    // Material params may reference textures, which won't be under material
                    //    // We need to move these over manually
                    //    var extraTextures = EntryImporter.GetAllReferencesOfExport(sourceExp).OfType<ExportEntry>().Where(x => x.Parent != sourceExp && x.IsA("Texture")).ToList();
                    //    foreach (var tex in extraTextures)
                    //    {
                    //        var tiv = tex.indexValue;
                    //        tex.indexValue = 100000;
                    //        EntryExporter.ExportExportToPackage(tex, package, out var portedTex, localCache, new RelinkerOptionsPackage() { Cache = localCache, PortImportsMemorySafe = true });
                    //        tex.indexValue = tiv; // Restore
                    //        portedTex.indexValue = tiv; // Restore ported
                    //    }
                    //}

                    EntryExporter.ExportExportToPackage(sourceExp, package, out var portedObj, localCache, new RelinkerOptionsPackage() { Cache = localCache, PortImportsMemorySafe = true });

                    //if (isGlobalFileSource)
                    //{
                    //    portedObj.indexValue = originalIndexValue; // Restore it

                    //    sourceExp.indexValue = 1000000; // This won't be used. I hope!
                    //                                    // Material params may reference textures, which won't be under material
                    //                                    // We need to move these over manually
                    //    var extraTextures = EntryImporter.GetAllReferencesOfExport(sourceExp).OfType<ExportEntry>().Where(x => x.Parent != sourceExp && x.IsA("Texture")).ToList();
                    //    foreach (var tex in extraTextures)
                    //    {
                    //        var tiv = tex.indexValue;
                    //        tex.indexValue = 100000;
                    //        EntryExporter.ExportExportToPackage(tex, package, out var portedTex, localCache, new RelinkerOptionsPackage() { Cache = localCache, PortImportsMemorySafe = true });
                    //        tex.indexValue = tiv; // Restore
                    //        portedTex.indexValue = tiv; // Restore ported
                    //    }
                    //}
                }

                //package.Save();

                // Clean up forced export and move up to linker so memory path is correct
                var linkerPackage = package.FindExport(package.FileNameNoExtension);
                foreach (var exp in package.Exports.Where(x => x.GetLinker() == package.FileNameNoExtension))
                {
                    exp.ExportFlags &= ~UnrealFlags.EExportFlags.ForcedExport; // Remove forced export
                }

                // If resources are stored in globally importable files we have to convert these imports to exports.
                var relinkMap = new ListenableDictionary<IEntry, IEntry>();

                // We cannot trash as we go because .RemoveTrailingTrash() will delete stuff, and that will cause invalid references
                // We cannot have invalid references until relink is completed so we track what we're going to trash and then trash it
                List<IEntry> trashItems = new List<IEntry>();
                trashItems.Add(linkerPackage); // Don't want this in the final result

                // Fix up any imports that came over under the linker. 
                var importsToConvert = package.Imports.Where(x => x.GetRoot() == linkerPackage 
                                                                  && !x.ObjectName.Name.StartsWith("PENDINGTRASH_")).ToList();
                while (importsToConvert.Any())
                {
                    foreach (var imp in importsToConvert)
                    {
                        var exp = EntryImporter.ResolveImport(imp, localCache, instancedFullPathOverride: imp.InstancedFullPath.Replace("PENDINGTRASH_", ""));
                        // EntryPruner.TrashEntries(package, [imp]); // Get rid of this
                        imp.ObjectName = $"PENDINGTRASH_{imp.ObjectName}";
                        trashItems.Add(imp);
                        EntryExporter.ExportExportToPackage(exp, package, out var portedSingle, localCache, new RelinkerOptionsPackage() { Cache = localCache });
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


                foreach (var exp in package.Exports.Where(x => x.GetRoot() == linkerPackage))
                {
                    exp.Parent = null;
                }


                //package.Save();
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

                package.Save();
                if (relinkMap.Any())
                {
                    // Relink required
                    Relinker.RelinkSamePackage(package, relinkMap);
                }

                EntryPruner.TrashEntries(package, trashItems);

                Debug.WriteLine($"Saving package {package.FileNameNoExtension}");
                package.Save();
            });
        }

        private static void SecondStageDecook(string stagingPath, TieredPackageCache chainNewCache)
        {
            TieredPackageCache cache = TieredPackageCache.GetGlobalPackageCache(MEGame.LE3);

            foreach (var file in Directory.GetFiles(stagingPath).Where(x => x.RepresentsPackageFilePath()))
            {
                if (!DebugFilterFiles(file))
                    return;

                var package = MEPackageHandler.OpenMEPackage(file);


                // Exports outside of the linker - ordered longest IFP to shortest so it goes bottom up
                var exportsOutsideOfLinker =
                    package.Exports.OfType<IEntry>().Where(x => x.GetLinker() != package.FileNameNoExtension)
                        //.Concat(package.Imports.Where(x => x.GetLinker() != package.FileNameNoExtension))
                        .OrderByDescending(x => x.InstancedFullPath.Length).ToList();

                // Manual package relink
                var relinkMap = new ListenableDictionary<IEntry, IEntry>();

                foreach (var entry in exportsOutsideOfLinker)
                {
                    var originalIFP = entry.InstancedFullPath;
                    if (entry is ExportEntry exp)
                    {
                        ImportEntry imp = new ImportEntry(exp, exp.idxLink, exp.FileRef);
                        exp.ObjectName = "TEMP_" + exp.ObjectName;
                        exp.FileRef.AddImport(imp);
                        relinkMap[exp] = imp;
                    }

                    var reParent = package.FindEntry(originalIFP);
                    var children = package.Tree.GetDirectChildrenOf(entry);
                    foreach (var child in children)
                    {
                        child.Parent = reParent; // Reparent to new import so it doesn't get trashed right away.
                    }
                }

                Relinker.RelinkSamePackage(package, relinkMap);

                EntryPruner.TrashEntries(package, exportsOutsideOfLinker.OfType<ExportEntry>());


                Debug.WriteLine($"Saving second stage package {package.FileNameNoExtension}");
                package.Save();
            }
        }

        private static void ThirdStageDecook(string stagingPath, TieredPackageCache promotableCache)
        {
            foreach (var file in Directory.GetFiles(stagingPath).Where(x => x.RepresentsPackageFilePath()))
            {
                if (!DebugFilterFiles(file))
                    return;

                var localCache = promotableCache.ChainNewCache();
                var sourcePackage = MEPackageHandler.OpenMEPackage(file);
                var destPackage = MEPackageHandler.CreateMemoryEmptyPackage(file, MEGame.LE3);
                foreach (var mat in sourcePackage.Exports.Where(x => x.IsA("Material") || x.IsA("Texture")))
                {
                    EntryExporter.ExportExportToPackage(mat, destPackage, out _, localCache);
                }

                // Overwrite the original.
                Debug.WriteLine($"Saving third stage package {sourcePackage.FileNameNoExtension}");
                destPackage.Save(file);
            }
        }


        private static void PortMaterialsToUDK(string stagingPath, TieredPackageCache chainNewCache)
        {
            UDKMaterialPort.PortMaterialsIntoUDK(MEGame.LE3, stagingPath, "MilanMaterials", Program.Settings.MilanUDKPath);
        }
    }
}
