using LegendaryExplorerCore.GameFilesystem;
using LegendaryExplorerCore.Helpers;
using LegendaryExplorerCore.Localization;
using LegendaryExplorerCore.Misc;
using LegendaryExplorerCore.Misc.ME3Tweaks;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Packages.CloningImportingAndRelinking;
using LegendaryExplorerCore.Textures;
using LegendaryExplorerCore.Unreal;
using LegendaryExplorerCore.Unreal.BinaryConverters;
using LegendaryExplorerCore.Unreal.Classes;
using LegendaryExplorerCore.Unreal.ObjectInfo;
using LegendaryExplorerCore.UnrealScript;
using LegendaryExplorerCore.UnrealScript.Compiling.Errors;
using Newtonsoft.Json;
using System.Diagnostics;
using System.IO.Compression;

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
            if (CLIOptions.ParsedOptions.Game == MEGame.LE3)
            {
                DecookerShared.OTObjectDB ??= DecookerShared.LoadObjectDB(CLIOptions.ParsedOptions.Game.ToOppositeGeneration());
            }

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

        /// <summary>
        /// Trims specific properties we don't want carried over to UDK
        /// </summary>
        /// <param name="le3P"></param>
        private static void TrimExportToUDKProps(IMEPackage le3P)
        {
            foreach (var exp in le3P.Exports)
            {
                if (exp.IsA("Material") || exp.IsA("MaterialInstance"))
                {
                    exp.RemoveProperty("PhysMaterial");
                }
            }
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
