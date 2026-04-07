using LegendaryExplorerCore.Helpers;
using LegendaryExplorerCore.Localization;
using LegendaryExplorerCore.Misc;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Packages.CloningImportingAndRelinking;
using LegendaryExplorerCore.Textures;
using LegendaryExplorerCore.Unreal;
using LegendaryExplorerCore.Unreal.BinaryConverters;
using LegendaryExplorerCore.Unreal.Classes;
using LegendaryExplorerCore.Unreal.ObjectInfo;
using System.Diagnostics;

namespace LEDecooker
{
    internal class ConvertToUDK
    {
        public static void ConvertAssetsToUDK()
        {
            // MILAN ONLY ===
            //var inputPath = DecookerPaths.GetAssetOutputPath();

            //// Decooked
            //var outPathS1 = @"S:\Milan\UDK\MilanMaterialDecook_T3D";
            //var outPathS2 = @"S:\Milan\UDK\MilanMaterialDecook_ME3MP";
            //var outPathS3 = @"Z:\ModLibrary\LE3\Project Milan\Extras\Packages\LE3";

            //// Merge (decooked also)
            //var mergePathS1 = @"S:\Milan\UDK\MilanMaterialDecook_ToCombine";

            //var outPathFinal = @"S:\Milan\UDK\UDKGame\Content\MilanAssets";

            //TargetObjectDB ??= LoadObjectDB(MEGame.LE3);
            //OTObjectDB ??= LoadObjectDB(MEGame.ME3);

            //ConvertAssetsToUDK(outPathFinal, [outPathS1, outPathS2, outPathS3], [mergePathS1]);
            // END MILAN ====


            var inputPath = DecookerPaths.GetAssetOutputPath();
            var outputPath = DecookerPaths.GetUDKOutputPath();
            // Todo: Support mergein paths for custom content.
            DecookerShared.TargetObjectDB ??= DecookerShared.LoadObjectDB(CLIOptions.ParsedOptions.Game);
            ConvertAssetsToUDKInternal(outputPath, [inputPath], []);
        }


        /// <summary>
        /// Converts packages to UPKs
        /// </summary>
        /// <param name="outPathFinal"></param>
        /// <param name="packagePaths"></param>
        /// <param name="mergePaths"></param>
        private static void ConvertAssetsToUDKInternal(string outPathFinal, string[] packagePaths, string[] mergePaths)
        {
            // goto end;
            Directory.CreateDirectory(outPathFinal);
            DecookerLog.Information("Clearing Final Result UPK packages");
            foreach (var file in Directory.GetFiles(outPathFinal))
            {
                File.Delete(file);
            }

            // Convert each MEGame package to UDK. This is the first pass.
            foreach (var inputFolder in packagePaths)
            {
                var packages = Directory.GetFiles(inputFolder, "*.pcc");
                Parallel.ForEach(packages, packageF =>
                {
                    //foreach (var packageF in packages)
                    //{
                    using var le3P = MEPackageHandler.OpenMEPackage(packageF);
                    if (le3P.FileNameNoExtension == "BioS_Matrix") // bugged atm
                        return;
                    /*if (le3P.FileNameNoExtension != "BioTemp_Lev004")
                        // Skip
                        return;*/

                    //if (le3P.FileNameNoExtension != "BioT_MPThes") 
                    //    && le3P.FileNameNoExtension != "biog_rpr_can_nkd_r") // debug filter
                    //    return;

                    if (le3P.FileNameNoExtension.StartsWith("Engine", StringComparison.OrdinalIgnoreCase))
                        return;
                    if (le3P.FileNameNoExtension.StartsWith("Editor", StringComparison.OrdinalIgnoreCase))
                        return;
                    if (le3P.FileNameNoExtension.StartsWith("NodeBuddies", StringComparison.OrdinalIgnoreCase))
                        return;
                    if (le3P.FileNameNoExtension.StartsWith("MaterialTemplates", StringComparison.OrdinalIgnoreCase))
                        return;
                    if (le3P.FileNameNoExtension.StartsWith("MobileEmulation", StringComparison.OrdinalIgnoreCase))
                        return;

                    DecookerLog.Information($"Converting {le3P.FileNameNoExtension} to UPK");

                    var outPath = Path.Combine(outPathFinal, $"{le3P.FileNameNoExtension}.upk");
                    using var udkP = MEPackageHandler.CreateAndOpenPackage(outPath, MEGame.UDK);

                    le3P.ConvertPackageToUncooked();
                    TrimExportToUDKProps(le3P);

                    // referencer will already exist, this will return it
                    var referencer = le3P.CreateObjectReferencer();


                    var rop = new RelinkerOptionsPackage()
                    {
                        CustomRelinkUIndex = ConvertBioMaterialExpressionForUDK
                    };

                    EntryImporter.ImportAndRelinkEntries(EntryImporter.PortingOption.CloneAllDependencies, referencer,
                        udkP, null, true, rop, out var uReferencer);

                    foreach (var exp in udkP.Exports)
                    {
                        UDKExportFixup(exp);
                    }

                    udkP.Save();

                    var rcp = new ReferenceCheckPackage();
                    EntryChecker.CheckReferences(rcp, udkP, LECLocalizationShim.GetString);
                    foreach (var v in rcp.GetBlockingErrors().Concat(rcp.GetSignificantIssues()))
                    {
                        DecookerLog.Error($"{udkP.FileNameNoExtension} - {v.Entry?.InstancedFullPath} {v.Message}");
                    }

                    //}
                });
            }

            DecookerLog.Information("Merging additional assets in...");
            // Merge in files in the merge paths. These are to add additional objects to the UDK packages - e.g. assets that exist in shipped packages (not MP exclusive), but the assets were only used in MP.
            foreach (var mergePath in mergePaths)
            {
                var packages = Directory.GetFiles(mergePath, "*.pcc");
                foreach (var packageF in packages)
                {
                    using var sourcePackage = MEPackageHandler.OpenMEPackage(packageF);
                    var ifp = sourcePackage.FileNameNoExtension;
                    var destPackageName = sourcePackage.FileNameNoExtension[..sourcePackage.FileNameNoExtension.IndexOf('.')]; // Names will be IFPs.

                    // We use this to trick some memory code.
                    sourcePackage.SetInternalFilepath(destPackageName);

                    DecookerLog.Information($"Merging {sourcePackage.FileNameNoExtension}");

                    var outPath = Path.Combine(outPathFinal, $"{destPackageName}.upk");
                    if (!File.Exists(outPath))
                    {
                        // This should only occur when we're doing dev work to fix bugs...
                        DecookerLog.Warning($"Package to merge into doesn't exist: {outPath}");
                        continue;
                    }
                    using var udkP = MEPackageHandler.OpenMEPackage(outPath);

                    var portObj = sourcePackage.FindExport(ifp);

                    // Prepare package for exporting from.
                    sourcePackage.ConvertPackageToUncooked();

                    var rop = new RelinkerOptionsPackage()
                    {
                        // Prevents pulling in external resources
                        CustomRelinkUIndex = DecookerShared.ImportOutsideOfPackageRelink
                    };


                    EntryExporter.ExportExportToPackage(portObj, udkP, out var portedObj, customROP: rop);

                    foreach (var exp in udkP.Exports)
                    {
                        UDKExportFixup(exp);
                    }

                    udkP.Save();

                    var rcp = new ReferenceCheckPackage();
                    EntryChecker.CheckReferences(rcp, udkP, LECLocalizationShim.GetString);
                    foreach (var v in rcp.GetBlockingErrors().Concat(rcp.GetSignificantIssues()))
                    {
                        DecookerLog.Error($"{udkP.FileNameNoExtension} - {v.Entry?.InstancedFullPath} {v.Message}");
                    }

                    //}
                }
            }

        end:
            GenerateMissingTexturePackage(outPathFinal);
        }

        private static IMEPackage localFileResolver(string packageName, PackageCache cache)
        {
            var testPath = Path.Combine(DecookerPaths.GetAssetOutputPath(), packageName);
            return cache.GetCachedPackage(testPath);
        }

        /// <summary>
        /// Trims specific properties we don't want carried over to UDK, also corrects them. This may modify the source package!
        /// </summary>
        /// <param name="le3P"></param>
        private static void TrimExportToUDKProps(IMEPackage le3P)
        {
            foreach (var exp in le3P.Exports.ToList())
            {
                if (exp.IsA("Material") || exp.IsA("MaterialInstance"))
                {
                    exp.RemoveProperty("PhysMaterial");
                }
                if (exp.IsA("MaterialInstance"))
                {
                    // Parent should not be a RvrEffectsMaterialUser

                    var parent = exp.GetProperty<ObjectProperty>("Parent");
                    if (parent == null)
                    {
                        // This is probably not valid, but this happens
                        // in a few materials
                        continue;
                    }
                    if (parent.ResolveToEntry(exp.FileRef) is var parentEntry)
                    {
                        // Check if the parent is a RvrEffectsMaterialUser - UDK does not support this
                        // We will relink parent up the parent material instead
                        if (parentEntry.ClassName.CaseInsensitiveEquals("RvrEffectsMaterialUser"))
                        {
                            // Parent is a RvrMaterialUser
                            // Get property on it and relink to it instead.
                            PackageCache pc = new PackageCache();

                            DecookerLog.Information("\t\t\tPassing through parent of RvrEffectsMaterialUser");

                            // This export must be resolved!
                            ExportEntry rvr = parentEntry as ExportEntry;
                            if (parentEntry is ImportEntry imp)
                            {
                                var resolved = EntryImporter.ResolveImport(imp, pc);
                                if (resolved == null)
                                {
                                    // About to die
                                    // Debugger.Break();
                                    DecookerLog.Error($"\t\tCould not resolve parent {imp.InstancedFullPath}");
                                }
                                else
                                {
                                    if (resolved.ClassName != imp.ClassName)
                                    {
                                        // We resolved... something...
                                        if (resolved.ClassName == "Package")
                                        {
                                            // We don't know what this is!
                                            // How can we figure it out...?

                                        }
                                        Debugger.Break();
                                    }
                                    rvr = resolved; // This is from another package! The UIndex will be for that package!
                                }
                            }

                            if (rvr != null)
                            {
                                var baseMatObj = rvr.GetProperty<ObjectProperty>("m_pBaseMaterial");
                                var baseMatRef = baseMatObj.ResolveToExport(rvr.FileRef, pc, localFileResolver);
                                if (baseMatRef.FileRef == exp.FileRef || baseMatRef.FileRef.FilePath.Equals(exp.FileRef.FilePath, StringComparison.OrdinalIgnoreCase))
                                {
                                    // Update the parent to skip Rvr
                                    parent.Value = baseMatRef.UIndex;
                                }
                                else
                                {
                                    // This is an import
                                    var pentry = CreateParentImports(exp.FileRef, baseMatRef.MemoryFullPath);
                                    parent.Value = exp.FileRef.CreateImport("Material", baseMatRef.ObjectName, pentry).UIndex;
                                }
                            } else
                            {
                                // We couldn't figure out the parent. We may not have access to it
                                var engineMaterials = exp.FileRef.CreateImport("Package", "EngineMaterials");
                                parent.Value = exp.FileRef.CreateImport("Material", "DefaultMaterial", engineMaterials).UIndex;
                            }

                            exp.WriteProperty(parent);
                        }
                    }

                }
            }

            // Gets the referencer
            var referencer = le3P.CreateObjectReferencer();

            // Ensure we have no objects that won't work in UDK
            var referencedObjects = referencer.GetProperty<ArrayProperty<ObjectProperty>>("ReferencedObjects");
            var count = referencedObjects.Count;
            referencedObjects.RemoveAll(x =>
            {
                var obj = le3P.GetUExport(x.Value);
                // Debug.WriteLine($"{obj.InstancedFullPath} | {obj.ClassName} | {obj.Class.GetLinker()}");
                var tempObj = obj;
                while (tempObj != null)
                {
                    // Debug.WriteLine($"\t{tempObj.InstancedFullPath} | {tempObj.ClassName}");
                    if (tempObj.Class.GetLinker() == "SFXGame" && !tempObj.ClassName.StartsWith("BioMaterialExpression"))
                    {
                        // We convert BioMaterialExpressions, but other SFXGame classes are not supported in UDK,
                        // so we trim the reference
                        DecookerLog.Information($"\tTrimming ObjectReferencer reference to {obj.InstancedFullPath} as it has class not supported in UDK");
                        return true;
                    }
                 
                    tempObj = tempObj.Parent as ExportEntry;
                }
                return false;
            });

            if (referencedObjects.Count != count)
            {
                // Write back changes to referencer
                referencer.WriteProperty(referencedObjects);
            }
        }


        /// <summary>
        /// Creates parents of the object as package imports
        /// </summary>
        /// <param name="package"></param>
        /// <param name="ifp"></param>
        /// <returns></returns>
        private static IEntry CreateParentImports(IMEPackage package, string ifp)
        {
            var pieces = ifp.Split('.').ToList();
            pieces.RemoveAt(pieces.Count - 1);

            IEntry parent = null;
            foreach (var piece in pieces)
            {
                var tifp = parent?.InstancedFullPath;
                if (tifp != null) tifp += ".";
                tifp += piece;

                var tparent = package.FindExport(tifp, "Package");
                if (parent == null)
                {
                    parent = package.CreatePackageExport(piece, parent);
                }
                else
                {
                    parent = tparent;
                }
            }

            return parent;
        }

        private static bool ConvertBioMaterialExpressionForUDK(IMEPackage importingpcc, ExportEntry relinkingexport, ref int uindex, string propertyname, string prefix, RelinkerOptionsPackage rop, out EntryStringPair result)
        {
            result = null;

            var sourceExport = importingpcc.GetEntry(uindex);
            if (sourceExport is ExportEntry exp)
            {
                if (rop.CrossPackageMap.TryGetValue(sourceExport, out var newEntry))
                {
                    // Previously relinked
                    uindex = newEntry.UIndex;
                    return true;
                }
                var converter = BioMaterialExpressionConverters.GetConverter(exp);
                if (converter != null)
                {
                    // This should get the parent as it is 1:1 pathing
                    var destParent = relinkingexport.FileRef.FindExport(sourceExport.Parent.InstancedFullPath);
                    var converted = converter.ConvertExpression(destParent, rop);
                    uindex = converted.UIndex;
                    rop.CrossPackageMap[sourceExport] = converted;

                    return true;
                }
            }

            return false;
        }


        /// <summary>
        /// Scans imports in a folder, and sees if they resolve. If they don't, they are converted to a missing textures import, where a missing texture object is placed.
        /// </summary>
        /// <param name="outPathFinal"></param>
        private static void GenerateMissingTexturePackage(string outPathFinal)
        {
            // Todo: see if we can use object redirectors instead to reduce file size of this upk.
            var files = Directory.GetFiles(outPathFinal);
            ExportEntry clonable = null;
            var missingTexPackage = MEPackageHandler.CreateAndOpenPackage(Path.Combine(outPathFinal, "MissingTextures.upk"), MEGame.UDK);
            foreach (var f in files)
            {
                var package = MEPackageHandler.UnsafePartialLoad(f, x => false);
                var missingTexturesImp = package.FindImport("MissingTextures");
                if (missingTexturesImp == null)
                    continue;

                DecookerLog.Information($"MissingTextures build for {package.FileNameNoExtension}");
                foreach (var item in package.Imports.Where(x => x.idxLink == missingTexturesImp.UIndex))
                {
                    if (missingTexPackage.FindExport(item.ObjectName, item.ClassName) == null)
                    {
                        if (item.ClassName == "Texture2D")
                        {
                            if (clonable == null)
                            {
                                clonable = Texture2D.CreateTexture(missingTexPackage, item.ObjectName, 512, 512, PixelFormat.DXT1, true, null);
                                var t2d = new Texture2D(clonable);
                                var im = Image.LoadFromFileMemory(DecookerShared.ExtractResource("LEDecooker.missingtexture.png"), 2, PixelFormat.DXT1);
                                t2d.Replace(im, clonable.GetProperties(), isPackageStored: true);
                                clonable.ObjectFlags |= UnrealFlags.EObjectFlags.Standalone; // Keep if unreferenced.
                            }
                            else
                            {
                                var newExp = EntryCloner.CloneEntry(clonable);
                                newExp.ObjectName = item.ObjectName;
                            }
                        }
                        else if (item.ClassName == "TextureCube")
                        {
                            // Do this thing
                        }
                    }
                }
            }

            foreach (var tex in missingTexPackage.Exports)
            {
                // Make all objects public so they can be reliably imported.
                tex.ObjectFlags |= UnrealFlags.EObjectFlags.Public;

                // TFC name will break UDK's editor interface for some reason.
                if (tex.IsTexture())
                {
                    tex.RemoveProperty("TextureFileCacheName");
                }
            }
            missingTexPackage.Save();
        }

        /// <summary>
        /// Fixes up a UDK export so it works properly in UDK.
        /// </summary>
        /// <param name="exp"></param>
        private static void UDKExportFixup(ExportEntry exp)
        {
            // Make all objects public so they can be reliably imported.
            exp.ObjectFlags |= UnrealFlags.EObjectFlags.Public;

            // TFC name will break UDK's editor interface for some reason.
            if (exp.IsTexture())
            {
                exp.RemoveProperty("TextureFileCacheName");
            }

            // Static Meshes need the correct material indexes or UDK will rebuild them,
            // resulting in a 0 tri mesh.
            if (exp.ClassName == "StaticMesh")
            {
                bool save = false;
                var sm = ObjectBinary.From<StaticMesh>(exp);
                for (int i = 0; i < sm.LODModels.Length; i++)
                {
                    for (int k = 0; k < sm.LODModels[i].Elements.Length; k++)
                    {
                        if (sm.LODModels[i].Elements[k].MaterialIndex != k)
                        {
                            DecookerLog.Information($"  Fixing {exp.ObjectName}'s incorrect material indexing from {sm.LODModels[i].Elements[k].MaterialIndex} to {k}");
                            sm.LODModels[i].Elements[k].MaterialIndex = k;
                            save = true;
                        }
                    }
                }

                if (save)
                {
                    // Commit result back.
                    exp.WriteBinary(sm);
                }
            }
        }
    }
}
