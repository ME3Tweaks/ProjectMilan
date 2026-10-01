using System.Diagnostics;
using LegendaryExplorerCore.GameFilesystem;
using LegendaryExplorerCore.Helpers;
using LegendaryExplorerCore.Misc;
using LegendaryExplorerCore.Misc.ME3Tweaks;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Packages.CloningImportingAndRelinking;
using LegendaryExplorerCore.Unreal;
using LegendaryExplorerCore.Unreal.ObjectInfo;
using ProjectMilan.Pipelines.Init;
using ProjectMilanCore;

namespace ProjectMilan.MilanUDK
{
    /// <summary>
    /// Relink policy used when porting Milan content into UDK packages.
    /// </summary>
    /// <remarks>
    /// This is the surviving piece of the old UDKSetupT3D, which was a pre-split copy of the decooker
    /// that now lives in the LEDecooker project (split at 7b02041). The two copies had drifted, and
    /// having both meant every search for a decooker symbol returned two different implementations -
    /// which is how a bug in the real one went unnoticed. The rest of that class was only reachable
    /// from commented-out lines in Program.cs and has been removed; this method is the only part still
    /// called, by StaticLightingExportPipeline as RelinkerOptionsPackage.CustomRelinkUIndex.
    /// </remarks>
    internal class UDKRelinker
    {
        /// <summary>
        /// Relinks as imports for things outside of the linker. If the package that the linker references doesn't exist, this doesn't do anything - unless it is a static mesh, it will probably kill UDK
        /// </summary>
        /// <param name="importingpcc"></param>
        /// <param name="relinkingexport"></param>
        /// <param name="uindex"></param>
        /// <param name="propertyname"></param>
        /// <param name="prefix"></param>
        /// <param name="rop"></param>
        /// <param name="result"></param>
        /// <returns></returns>
        public static bool ImportOutsideOfPackageRelink(IMEPackage importingpcc, ExportEntry relinkingexport, ref int uindex, string propertyname, string prefix, RelinkerOptionsPackage rop, out EntryStringPair result)
        {
            result = null;

            if (uindex == 0)
                return false;

            // Relink to 0, we don't want this
            if (propertyname.CaseInsensitiveEquals("PhysMaterial"))
            {
                uindex = 0;
                return true;
            }

            var localCache = (rop?.Cache as TieredPackageCache)?.ChainNewCache();

            if (propertyname.CaseInsensitiveEquals("Parent") && relinkingexport.IsA("MaterialInstance"))
            {
                // Check if the parent is a RvrEffectsMaterialUser - UDK does not support this
                // We will relink parent up the parent material instead
                if (importingpcc.GetEntry(uindex) is IEntry parentEntry && parentEntry.ClassName.CaseInsensitiveEquals("RvrEffectsMaterialUser") && relinkingexport.IsA("MaterialInstance"))
                {
                    // Parent is a RvrMaterialUser
                    // Get property on it and relink to it instead.

                    MilanLog.Information("\t\t\tPassing through parent of RvrEffectsMaterialUser");

                    // This export must be resolved!
                    ExportEntry rvr = parentEntry as ExportEntry;
                    if (parentEntry is ImportEntry imp)
                    {
                        var resolved = EntryImporter.ResolveImport(imp, rop.Cache);
                        rvr = resolved; // This is from another package!
                    }

                    bool fromAnotherPackage = false;

                    var baseMatObj = rvr.GetProperty<ObjectProperty>("m_pBaseMaterial");
                    var baseMatRef = baseMatObj.ResolveToExport(rvr.FileRef, rop.Cache);
                    uindex = baseMatRef.UIndex; // We're going to retrigger this method but use a different source export.

                    if (ImportOutsideOfPackageRelink(baseMatRef.FileRef, relinkingexport, ref uindex, propertyname, prefix, rop, out result))
                    {
                        return true; // We took care of this
                    }
                }
            }

            var sourceEntry = importingpcc.GetEntry(uindex);
            var linker = sourceEntry.GetLinker();
            if (!linker.CaseInsensitiveEquals(relinkingexport.FileRef.FileNameNoExtension))
            {
                // Outside of package! Make sure it exists so we can add an import to it
                if (relinkingexport.FileRef.Game == MEGame.UDK)
                {
                    var testPath = Path.Combine(UDKSetup.GetMilanDecookedMaterialsDirectory(), linker + ".upk");
                    
                    // Basegame UDK material packages - always make an import for them
                    var trustAnyways = false;
                    if (!trustAnyways && linker.CaseInsensitiveEquals("EngineMaterials")) trustAnyways = true;
                    if (!trustAnyways && linker.CaseInsensitiveEquals("EngineDebugMaterials")) trustAnyways = true;
                    if (!trustAnyways && linker.CaseInsensitiveEquals("EngineResources")) trustAnyways = true;
                    if (trustAnyways || File.Exists(testPath))
                    {
                        // Generate imports for this object
                        // We're going to trust that if the package exists this specific object will be in it
                        uindex = GenerateImportForObject(sourceEntry, relinkingexport.FileRef).UIndex;
                        return true;
                    }

                    if (!HasParentOfClassOrIs(sourceEntry, "StaticMesh"))
                    {
                        // You need to make a manual decooked package for this or find a way to register temporary upks for UDK
                        throw new Exception($"Did not find a decooked package for linker {linker} for export {sourceEntry.InstancedFullPath} ({sourceEntry.ClassName}), and it is not static mesh (or child of) - UDK will probably die, this needs fixed");
                    }
                    return false;
                }
                else
                {
                    // Generate imports for this object
                uindex = GenerateImportForObject(sourceEntry, relinkingexport.FileRef).UIndex;
                return true;
            }
            }
            else
            {
                // Inside this package

                // Maybe the path is wrong from T3D. Do we have an export with same name and class under the root, since we don't have path info?
                var existingDiffLevel = relinkingexport.FileRef.FindExport($"{relinkingexport.FileRef.FileNameNoExtension}.{sourceEntry.ObjectName.Instanced}", sourceEntry.ClassName);
                if (existingDiffLevel != null)
                {
                    uindex = existingDiffLevel.UIndex;

                    if (sourceEntry.HasParent)
                    {
                        // Try to move object to where it should be...
                        var parent = relinkingexport.FileRef.FindExport(sourceEntry.Parent.MemoryFullPath,
                                         sourceEntry.Parent.ClassName)
                                     ?? relinkingexport.FileRef.FindExport(
                                         sourceEntry.Parent.MemoryFullPath.Substring(sourceEntry.GetLinker().Length +
                                             1), sourceEntry.Parent.ClassName);


                        if (parent != null)
                        {
                            // Do not move a copy under if it already exists. We probably DO want the root obj.
                            // This is true for LE3 biot_rubble.Rubble_Decal_MM which has 2 same-named items in package at different levels with same classname.

                            var testIFP = $"{parent.InstancedFullPath}.{sourceEntry.ObjectName.Instanced}";
                            var testObj = relinkingexport.FileRef.FindExport(testIFP, sourceEntry.ClassName);

                            if (testObj == null)
                            {
                                // Nest under correct path.
                                existingDiffLevel.idxLink = parent.UIndex;
                            }
                        }
                    }

                    return true;
                }

                // We must check it isn't an import - we MUST use exports
                if (sourceEntry is ImportEntry ie)
                {
                    // We cannot have imports inside of ourself!
                    // Try linker.
                    if (MELoadedFiles.GetFilesLoadedInGame(ie.Game).TryGetValue($"{linker}.pcc", out var selfPackage))
                    {
                        if (ImportObject(selfPackage, ie, ref uindex, null, localCache))
                        {
                            return true;
                        }
                    }

                    // We still don't have anything!
                    var objDb = sourceEntry.Game == MEGame.LE3 ? MilanShared.LE3ObjectDB : MilanShared.ME3ObjectDB;
                    var sourceObj = objDb.GetFilesContainingObject(sourceEntry.InstancedFullPath);
                    if (sourceObj != null)
                    {
                        var firstFile = Path.Combine(ME3TweaksBackups.GetGameBackupPath(MEGame.LE3), sourceObj[0]);
                        if (ImportObject(firstFile, ie, ref uindex, null, localCache))
                        {
                            return true;
                        }
                    }

                    // We cannot use this import
                    Debugger.Break();
                }

                // An export being ported in within our linker might be coming from a global-only package, which will trigger it to port as an import
                // We do not want that

                if (sourceEntry is ExportEntry ee)
                {
                    if (EntryImporter.IsSafeToImportFrom(ee.FileRef.FilePath, relinkingexport.FileRef, false))
                    {
                        // We must not allow imports to be generated here
                        var origName = ee.FileRef.FileNameNoExtension;
                        ee.FileRef.SetInternalFilepath($@"NOIMPORT_{origName}.pcc");

                        // This may trigger a double relink
                        EntryExporter.ExportExportToPackage(ee, relinkingexport.FileRef, out var ported, rop.Cache, rop);
                        rop?.CrossPackageMap.Clear(); // Do not persist this value, we do not want double relink
                        uindex = ported.UIndex;
                        ee.FileRef.SetInternalFilepath(origName);
                        return true;
                    }
                }
                return false;
            }

            return true;


            bool ImportObject(string sPackagePath, IEntry sIe, ref int sUIndex, IMEPackage tempPackage, PackageCache cache)
            {
                // looks like a seek free

                bool restoreName = EntryImporter.IsSafeToImportFrom(sIe.FileRef.FilePath, relinkingexport.FileRef, false);
                string origName = sIe.FileRef.FileNameNoExtension;
                if (restoreName)
                {
                    // We must not allow imports to be generated here
                    sIe.FileRef.SetInternalFilepath($@"NOIMPORT_{origName}.pcc");
                }

                if (tempPackage == null)
                {
                    var fullLoad = sIe.ClassName != "Texture2D" || Path.GetFileNameWithoutExtension(sPackagePath).StartsWith("BIOG_");
                    if (!fullLoad)
                    {
                        tempPackage = MEPackageHandler.UnsafePartialLoad(sPackagePath,
                            x => x.MemoryFullPath == sIe.MemoryFullPath || x.ClassName is "TextureCube" or "Package"); // Or for parent porting.
                    }
                    else
                    {
                        if (cache != null)
                        {
                            var cachedPackage = cache?.GetCachedPackage(sPackagePath, false);
                            if (cachedPackage != null)
                            {
                                tempPackage = cachedPackage;
                                // Already converted
                            }
                            else
                            {
                                tempPackage = cache.GetCachedPackage(sPackagePath);
                                // Prepare file for porting, ONCE.
                                EntryExporter.PrepareGlobalFileForPorting(tempPackage, tempPackage.FileNameNoExtension);

                            }
                        }
                        else
                        {
                            // Open without cache. This will be slow if it's a big file.
                            tempPackage = cache != null ? cache.GetCachedPackage(sPackagePath) : MEPackageHandler.OpenMEPackage(sPackagePath);
                            EntryExporter.PrepareGlobalFileForPorting(tempPackage, tempPackage.FileNameNoExtension);
                        }
                       
                    }
                }

                var exp = tempPackage.FindExport(sIe.InstancedFullPath, sIe.ClassName) ?? tempPackage.FindExport(sIe.InstancedFullPath.Substring(tempPackage.FileNameNoExtension.Length + 1), sIe.ClassName);
                if (exp != null)
                {
                    // This may trigger a double relink
                    EntryExporter.ExportExportToPackage(exp, relinkingexport.FileRef, out var ported, rop.Cache, rop);
                    rop?.CrossPackageMap.Clear(); // Do not persist this value, we do not want double relink
                    sUIndex = ported.UIndex;

                    if (restoreName)
                    {
                        sIe.FileRef.SetInternalFilepath(origName);
                    }

                    return true;
                }

                // Object not found :(
                if (restoreName)
                {
                    sIe.FileRef.SetInternalFilepath(origName);
                }
                return false;
            }
        }

        /// <summary>
        /// Determines if an entry is, or a has, a parent with the specified class. Useful for things like determing if a RB_BodySetup sits under a static mesh so we know it will be ported over in UDKifyMeshes
        /// </summary>
        /// <param name="entry"></param>
        /// <param name="classParent"></param>
        /// <returns></returns>
        private static bool HasParentOfClassOrIs(IEntry entry, string classParent)
        {
            if (entry == null)
            {
                return false;
            }

            if (entry.ClassName.CaseInsensitiveEquals(classParent))
            {
                return true;
            }
            return HasParentOfClassOrIs(entry.Parent, classParent);
        }

        private static ImportEntry GenerateImportForObject(IEntry sourceEntry, IMEPackage package)
        {
            // Build order to do things
            var objectChain = new List<IEntry>();
            var temp = sourceEntry;
            objectChain.Insert(0, temp);
            while (temp.HasParent)
            {
                temp = temp.Parent;
                objectChain.Insert(0, temp);
            }

            ImportEntry currentParent = null;
            foreach (var obj in objectChain)
            {
                // Check if parent already exists in package
                // These will never be exports, so we only check imports
                ImportEntry tempParent = package.FindImport(obj.InstancedFullPath, obj.ClassName);
                if (tempParent != null)
                {
                    currentParent = tempParent;
                    continue;
                }

                // Creating parent object
                ImportEntry packageImp = new ImportEntry(package)
                {
                    ClassName = obj.ClassName,
                    PackageFile = ImportEntry.GetPackageFile(package.Game, obj.ClassName),
                    ObjectName = obj.ObjectName,
                    idxLink = currentParent?.UIndex ?? 0
                };
                package.AddImport(packageImp);
                currentParent = packageImp;
            }

            return currentParent;
        }
    }
}
