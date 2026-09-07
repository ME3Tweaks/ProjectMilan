using System.Diagnostics;
using LegendaryExplorerCore.GameFilesystem;
using LegendaryExplorerCore.Helpers;
using LegendaryExplorerCore.Misc;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Packages.CloningImportingAndRelinking;
using LegendaryExplorerCore.Unreal;
using LegendaryExplorerCore.Unreal.ObjectInfo;
using LegendaryExplorerCore.UnrealScript.Compiling.Errors;
using LegendaryExplorerCore.UnrealScript;
using Newtonsoft.Json;
using ProjectMilanCore;
using LegendaryExplorerCore.Misc.ME3Tweaks;
using ProjectMilan.Pipelines.Init;
using LegendaryExplorerCore.Localization;
using LegendaryExplorerCore.Textures;
using LegendaryExplorerCore.Unreal.Classes;
using LegendaryExplorerCore.Unreal.BinaryConverters;

namespace ProjectMilan.MilanUDK
{
    internal class UDKSetupT3D
    {
        public static void CompileT3Ds()
        {
            //ConvertAssetsToUDK();
            //return;
            MilanShared.LE3ObjectDB = MilanInitShared.LoadObjectDB(MEGame.LE3);
            MilanShared.ME3ObjectDB = MilanInitShared.LoadObjectDB(MEGame.ME3);
            //DecookME3MPDLC();
            //return;


            var outPathS1 = @"S:\Milan\UDK\MilanMaterialDecook_T3D";
            var outPathS2 = @"S:\Milan\UDK\MilanMaterialDecook_Merged_T3D";
            Directory.CreateDirectory(outPathS2);
            CompileGameAssets(outPathS2);
            FixImports(outPathS2);
        }

        /// <summary>
        /// Resolve imports in LE3 packages - test they actually can resolve, move around missing ones.
        /// </summary>
        /// <param name="inPath"></param>
        private static void FixImports(string inPath)
        {
            TieredPackageCache tpc = TieredPackageCache.GetGlobalPackageCache(MEGame.LE3);
            var localFiles = Directory.GetFiles(inPath, "*.pcc");
            foreach (var f in localFiles)
            {
                var cache = tpc.ChainNewCache();
                //var package = MEPackageHandler.UnsafePartialLoad(f, x => false);
                var package = MEPackageHandler.OpenMEPackage(f);

                foreach (var asset in package.Imports.Where(x => x.IsA("Material") || x.IsTexture()))
                {
                    // Check if we are an import that also has an export version available - likely got pulled in as import before we 
                    // we able to generate the export
                    if (asset.Parent == null)
                    {
                        var memoryIFP = $"{package.FileNameNoExtension}.{asset.ObjectName.Instanced}";
                        var export = package.FindExport(memoryIFP, asset.ClassName);
                        if (export != null)
                        {
                            MilanLog.Information($@"Repointing object in package from import to export: {export.InstancedFullPath}");
                            Relinker.RepointObject(asset, export);
                            continue;
                        }

                        // Maybe it's nested...
                        var matchingExp = package.Exports.FirstOrDefault(x => x.ClassName == asset.ClassName && x.ObjectName.Instanced == asset.ObjectName.Instanced);
                        if (matchingExp != null)
                        {
                            MilanLog.Information($@"RISKY Repointing object in package from import to export: {matchingExp.InstancedFullPath}");
                            Relinker.RepointObject(asset, matchingExp);
                            continue;
                        }

                        Debug.WriteLine("Ruh roh");
                    }

                    if (asset.GetLinker() == "MissingTextures")
                        continue; // Don't care.

                    if (!EntryImporter.TryResolveImport(asset, out var resolved, cache, localDirFiles: localFiles))
                    {
                        var lookupName = $"{asset.GetRootName()}.pcc";
                        var lookupPath = Path.Combine(inPath, lookupName);
                        var destPackage = cache.GetCachedPackage(lookupPath);
                        if (destPackage != null)
                        {
                            var misplacedAsset = destPackage.Exports.FirstOrDefault(x => x.ClassName == asset.ClassName && x.ObjectName == asset.ObjectName);
                            if (misplacedAsset != null)
                            {
                                // Generate parents.
                                MilanLog.Information($@"Moving object in {destPackage.FileNameNoExtension}: {misplacedAsset.InstancedFullPath}");
                                MoveToNested(misplacedAsset, asset.InstancedFullPath);
                            }
                            else
                            {
                                MilanLog.Warning($@"Import failed in {package.FileNameNoExtension}: {asset.InstancedFullPath}");
                            }
                        }
                        else
                        {
                            MilanLog.Warning($@"No importable package in {package.FileNameNoExtension}: {asset.InstancedFullPath}");
                        }
                    }
                }

                var cachedPackages = cache.GetPackages().ToList();
                foreach (var p in cachedPackages)
                {
                    if (p.IsModified)
                    {
                        p.Save();
                    }
                }

                if (package.IsModified)
                {
                    package.Save();
                }
            }
        }

        public static void ConvertAssetsToUDK()
        {
            // Decooked
            var outPathS1 = @"S:\Milan\UDK\MilanMaterialDecook_Merged_T3D";
            //var outPathS2 = @"S:\Milan\UDK\MilanMaterialDecook_ME3MP";
            //var outPathS3 = @"Z:\ModLibrary\LE3\Project Milan\Extras\Packages\LE3";

            // Merge (decooked also)
            var mergePathS1 = @"S:\Milan\UDK\MilanMaterialDecook_ToCombine";

            var outPathFinal = @"S:\Milan\UDK\UDKGame\Content\MilanAssets";

            MilanShared.LE3ObjectDB ??= MilanInitShared.LoadObjectDB(MEGame.LE3);
            MilanShared.ME3ObjectDB ??= MilanInitShared.LoadObjectDB(MEGame.ME3);

            ConvertAssetsToUDK(outPathFinal, [outPathS1 /*, outPathS2, outPathS3*/], [mergePathS1]);
        }

        /// <summary>
        /// Converts packages to UPKs
        /// </summary>
        /// <param name="outPathFinal"></param>
        /// <param name="packagePaths"></param>
        /// <param name="mergePaths"></param>
        private static void ConvertAssetsToUDK(string outPathFinal, string[] packagePaths, string[] mergePaths)
        {
            // goto end;

            MilanLog.Information("Clearing Final Result UPK packages");
            foreach (var file in Directory.GetFiles(outPathFinal))
            {
                File.Delete(file);
            }

            // Convert each MEGame package to UDK. This is the first pass.
            foreach (var inputFolder in packagePaths)
            {
                var packages = Directory.GetFiles(inputFolder, "*.pcc");
                Parallel.ForEach(packages, new() { /*MaxDegreeOfParallelism=1*/},packageF =>
                {
                    //foreach (var packageF in packages)
                    //{
                    using var le3P = MEPackageHandler.OpenMEPackage(packageF);
                    if (le3P.FileNameNoExtension == "BioS_Matrix") // bugged atm
                        return;

                    //if (le3P.FileNameNoExtension != "BioApl_Ind_BreedingTank01") 
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

                    MilanLog.Information($"Converting {le3P.FileNameNoExtension} to UPK");

                    var outPath = Path.Combine(outPathFinal, $"{le3P.FileNameNoExtension}.upk");
                    using var udkP = MEPackageHandler.CreateAndOpenPackage(outPath, MEGame.UDK);

                    ConvertPackageToUncooked(le3P);
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
                        MilanLog.Error($"{udkP.FileNameNoExtension} - {v.Entry?.InstancedFullPath} {v.Message}");
                    }

                    //}
                });
            }

            MilanLog.Information("Merging additional assets in...");
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

                    MilanLog.Information($"Merging {sourcePackage.FileNameNoExtension}");

                    var outPath = Path.Combine(outPathFinal, $"{destPackageName}.upk");
                    if (!File.Exists(outPath))
                    {
                        // This should only occur when we're doing dev work to fix bugs...
                        MilanLog.Warning($"Package to merge into doesn't exist: {outPath}");
                        continue;
                    }
                    using var udkP = MEPackageHandler.OpenMEPackage(outPath);

                    var portObj = sourcePackage.FindExport(ifp);

                    // Prepare package for exporting from.
                    ConvertPackageToUncooked(sourcePackage);

                    var rop = new RelinkerOptionsPackage()
                    {
                        // Prevents pulling in external resources
                        CustomRelinkUIndex = ImportOutsideOfPackageRelink
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
                        MilanLog.Error($"{udkP.FileNameNoExtension} - {v.Entry?.InstancedFullPath} {v.Message}");
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
                            MilanLog.Information($"  Fixing {exp.ObjectName}'s incorrect material indexing from {sm.LODModels[i].Elements[k].MaterialIndex} to {k}");
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

        /// <summary>
        /// Scans imports in a folder, and sees if they resolve. If they don't, they are convereted to a missing textures import, where a missing texture object is placed.
        /// </summary>
        /// <param name="outPathFinal"></param>
        private static void GenerateMissingTexturePackage(string outPathFinal)
        {

            var files = Directory.GetFiles(outPathFinal);
            ExportEntry clonable = null;
            var missingTexPackage = MEPackageHandler.CreateAndOpenPackage(Path.Combine(outPathFinal, "MissingTextures.upk"), MEGame.UDK);
            foreach (var f in files)
            {
                var package = MEPackageHandler.UnsafePartialLoad(f, x => false);
                var missingTexturesImp = package.FindImport("MissingTextures");
                if (missingTexturesImp == null)
                    continue;

                MilanLog.Information($"MissingTextures build for {package.FileNameNoExtension}");
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
                                var im = Image.LoadFromFile(Path.Combine(MilanShared.PipelineRoot, "..", "MilanUDK", "MissingTexture.png"), PixelFormat.DXT1);
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
        /// Takes a forced-export package and converts it to not-self export, like source side packages are laid out
        /// </summary>
        /// <param name="le3P"></param>
        private static void ConvertPackageToUncooked(IMEPackage le3P, string packageName = null)
        {
            // Strip off extra stuff if we're entering this method out of main order. (development)
            PreparePackageForUDKify(le3P, packageName);

            var selfExp = le3P.FindExport(packageName ?? le3P.FileNameNoExtension);

            // Reference objects - we will port the referencer
            var referencedObjects = le3P.Exports.Where(x => x != selfExp && x.ClassName != "Package").ToList();
            var referencer = le3P.CreateObjectReferencer();
            referencer.WriteProperty(new ArrayProperty<ObjectProperty>(referencedObjects.Select(x => new ObjectProperty(x)), "ReferencedObjects"));

            // If object is not directly referenced, keep it in package anyways.
            // UDK doesn't use object referencer, we just use it to pull everything in.
            foreach (var obj in referencedObjects.Where(x => x.Parent == null || x.Parent.ClassName == "Package"))
            {
                if (obj.Parent == null || obj.Parent.ClassName == "Package")
                {
                    obj.ObjectFlags |= UnrealFlags.EObjectFlags.Standalone;
                }

                // Objects are transacational... whatever that means. Seems to be used by the editor.
                obj.ObjectFlags |= UnrealFlags.EObjectFlags.Transactional;
            }

            if (selfExp != null)
            {
                // Objects will be lifted out of forced export state
                SetForcedExportFlag(selfExp, false);

                foreach (var obj in le3P.Exports.Where(x => x.idxLink == selfExp.UIndex).ToList())
                {
                    // Move to top level
                    obj.idxLink = 0;
                }
            }
        }

        /// <summary>
        /// Where to find an object
        /// </summary>
        class ObjectLocation
        {
            public string packagefile { get; set; }
            public string memoryfullpath { get; set; }
            public string classname { get; set; }
        }

        // Textures
        private static CaseInsensitiveDictionary<ObjectLocation> texDb = new();
        private static CaseInsensitiveDictionary<ObjectLocation> texDbME3 = new();
        //private static CaseInsensitiveDictionary<string> ifpDb = new();

        /// <summary>
        /// Decooks ME3 MP DLC content to packages for use in UDK
        /// </summary>
        public static void DecookME3MPDLC()
        {
            var inputFolder = @"Z:\Mass Effect Builds\ME3\PC\Retail\BIOGame\DLC";
            var le3Milan = @"S:\Milan\UDK\MilanMaterialDecook_T3D";
            var me3mmMilan = @"S:\Milan\UDK\MilanMaterialDecook_ME3MP";

            // essentially a toc
            var le3Files = Directory.GetFiles(le3Milan).Select(Path.GetFileNameWithoutExtension).ToList();

            var smDb = JsonConvert.DeserializeObject<CaseInsensitiveDictionary<CaseInsensitiveDictionary<string>>>(File.ReadAllText(@"S:\Milan\UDK\ME3MPDLCPackageMappingForStaticMesh.json"));

            foreach (var mPackage in smDb)
            {
                IMEPackage decookedPackage = null;
                if (le3Files.Contains(mPackage.Key, StringComparer.OrdinalIgnoreCase))
                {
                    // Adding assets to package
                    continue;
                    //decookedPackage = MEPackageHandler.OpenMEPackage(Path.Combine(le3Milan, $"{mPackage.Key}.pcc"));
                }
                else
                {
                    // Making new package
                    decookedPackage = MEPackageHandler.CreateAndOpenPackage(Path.Combine(me3mmMilan, $"{mPackage.Key}.pcc"), MEGame.LE3);
                }

                AddObjects(decookedPackage, "StaticMesh", smDb);

                decookedPackage.Save();
                /*
                foreach (var meshEntry in mPackage.Value)
                {
                    var ifp = meshEntry.Key[(meshEntry.Key.IndexOf('.') + 1)..];
                    if (decookedPackage.FindExport(ifp) == null)
                    {
                        // Asset does not exist in package.

                    }
                }*/
            }

            FixImports(me3mmMilan);
        }

        /// <summary>
        /// Generates LE3 packages that will later be converted to UPKs
        /// </summary>
        /// <param name="outputFolder"></param>
        public static void CompileGameAssets(string outputFolder)
        {
            // MilanLog.Information("Clearing Stage 1 T3D packages");
            foreach (var file in Directory.GetFiles(outputFolder))
            {
                // File.Delete(file);
            }

            var inputFolder = @"Z:\MaterialExport\Merged";

            var matIfpDb = JsonConvert.DeserializeObject<CaseInsensitiveDictionary<CaseInsensitiveDictionary<string>>>(File.ReadAllText(@"S:\Milan\UDK\matifps.json"));
            texDb = JsonConvert.DeserializeObject<CaseInsensitiveDictionary<ObjectLocation>>(File.ReadAllText(@"S:\Milan\UDK\TextureDBforT3D.json"));
            texDbME3 = JsonConvert.DeserializeObject<CaseInsensitiveDictionary<ObjectLocation>>(File.ReadAllText(@"S:\Milan\UDK\TextureDBforT3D_ME3.json"));

            var smDb = JsonConvert.DeserializeObject<CaseInsensitiveDictionary<CaseInsensitiveDictionary<string>>>(File.ReadAllText(@"S:\Milan\UDK\PackageMappingForStaticMesh.json"));
            var micDb = JsonConvert.DeserializeObject<CaseInsensitiveDictionary<CaseInsensitiveDictionary<string>>>(File.ReadAllText(@"S:\Milan\UDK\PackageMappingForMaterialInstanceConstant.json"));

            // All packages that will be generated
            var allPackageNames = new CaseInsensitiveDictionary<string>();

            foreach (var p in Directory.GetDirectories(inputFolder).Select(Path.GetFileName))
            {
                allPackageNames.Add(p, p);
            }

            // We also want to add texture and mesh-only packages
            AddPackagesToList(allPackageNames, smDb);
            AddPackagesToList(allPackageNames, texDb);
            var packages = allPackageNames.Select(x => x.Key).OrderBy(x => x).ToList();

            File.WriteAllLines(@"S:\Milan\UDK\packagelist.txt", packages);

            // Used to restart from specific position.
            bool bypass = false;
            foreach (var packageName in packages)
            {
                Debug.WriteLine($"{packageName}");

                var folder = Path.Combine(inputFolder, packageName);
                if (!packageName.CaseInsensitiveEquals("BioS_Geth")
                //    // && !packagename.caseinsensitiveequals("biod_cithub_wards")
                //    && !bypass // debug filter
                    )
                    continue;

                bypass = true;

                if (packageName.StartsWith("Engine", StringComparison.OrdinalIgnoreCase))
                    continue;
                if (packageName.StartsWith("Editor", StringComparison.OrdinalIgnoreCase))
                    continue;
                if (packageName.StartsWith("NodeBuddies", StringComparison.OrdinalIgnoreCase))
                    continue;
                if (packageName.StartsWith("MaterialTemplates", StringComparison.OrdinalIgnoreCase))
                    continue;
                if (packageName.StartsWith("MobileEmulation", StringComparison.OrdinalIgnoreCase))
                    continue;

                var packagePath = Path.Combine(outputFolder, $"{packageName}.pcc");

                // TEMP - DO NOT WIPE EXISTING
                //if (File.Exists(packagePath))
                //    continue;
                // END TEMP

                using var package = MEPackageHandler.CreateAndOpenPackage(packagePath, MEGame.LE3);
                MilanLog.Information($"Compiling package {package.FileNameNoExtension}");
                CompilePackageMaterials(package, folder, matIfpDb);
                package.Save();
                AddTextures(package, texDb);
                AddTextures(package, texDbME3);
                PreparePackageForUDKify(package);
                AddObjects(package, "MaterialInstanceConstant", micDb);
                PreparePackageForUDKify(package);
                AddObjects(package, "StaticMesh", smDb);
                PreparePackageForUDKify(package);

                // NestObjects(package);

                if (package.Exports.All(x => x.ClassName == "Package")) // UDK prep will add package name export so we only check if we have a non-package export
                {
                    File.Delete(packagePath);
                }
                else
                {
                    var duplicates = EntryChecker.CheckForDuplicateIndices(package);
                    if (duplicates.Any())
                    {
                        foreach (var dup in duplicates)
                        {
                            MilanLog.Error($"Duplicate object found in {package.FileNameNoExtension}: {dup.Entry.InstancedFullPath}");
                        }
                        Debugger.Break();
                    }

                    // Set flags to match what source side package would. This affects import resolution code.
                    package.setFlags(UnrealFlags.EPackageFlags.AllowDownload | UnrealFlags.EPackageFlags.NoExportsData);
                    package.Save();
                }
            }

        }

        //private static void NestObjects(IMEPackage package)
        //{
        //    foreach (var exp in package.Exports.Where(x => x.IsA("Material")).ToList())
        //    {
        //        if (ifpDb.TryGetValue(exp.ObjectName.Instanced, out var outPath) && outPath.StartsWith(package.FileNameNoExtension, StringComparison.OrdinalIgnoreCase))
        //        {
        //            if (!exp.InstancedFullPath.CaseInsensitiveEquals(outPath))
        //            {
        //                MoveToNested(exp, outPath);
        //            }
        //        }
        //    }
        //}

        /// <summary>
        /// Moves an export under another package export in the file to build the listed path
        /// </summary>
        /// <param name="exp"></param>
        /// <param name="outPath">Instanced full path we want it to ultimately resolve</param>
        private static void MoveToNested(ExportEntry exp, string outPath)
        {
            var currentPath = @"";
            var parts = outPath.Split('.');
            ExportEntry newParent = null;
            foreach (var part in parts[..^1])
            {
                if (currentPath != "")
                    currentPath += ".";

                currentPath += part;

                var test = exp.FileRef.FindExport(currentPath, "Package");
                if (test == null)
                {
                    test = ExportCreator.CreatePackageExport(exp.FileRef, part, newParent, forcedExport: true);
                }

                newParent = test;
            }

            exp.Parent = newParent;
        }

        /// <summary>
        /// For porting in textures
        /// </summary>
        /// <param name="package"></param>
        /// <param name="assetMap"></param>
        private static void AddTextures(IMEPackage package, CaseInsensitiveDictionary<ObjectLocation> assetMap)
        {
            var packageName = package.FileNameNoExtension;
            var assets = assetMap.Where(x => x.Value.memoryfullpath.StartsWith(packageName + ".", StringComparison.OrdinalIgnoreCase));
            if (assets.Any())
            {
                MilanLog.Information($"\tAdding asset type '(Textures)' to package");
                using PackageCache cache = new PackageCache();
                foreach (var asset in assets)
                {
                    if (asset.Value.classname == "TerrainWeightMapTexture")
                        continue; // We don't care.

                    var memoryifp = asset.Value.memoryfullpath;
                    var ifp = memoryifp.Substring(memoryifp.IndexOf('.') + 1);

                    // Does this already exist in the package?
                    if (package.FindExport(ifp) is ExportEntry iex && iex.IsTexture())
                    {
                        // Already in the package
                        continue;
                    }

                    if (package.FindExport(memoryifp) is ExportEntry mex && mex.IsTexture())
                    {
                        // Already in the package
                        continue;
                    }

                    // We know it exists
                    MilanLog.Information($"\t\tPorting asset in: {memoryifp}");

                    using var sourcePackage = cache.GetCachedPackage(asset.Value.packagefile);
                    var sourceAsset = sourcePackage.FindExport(memoryifp) ?? sourcePackage.FindExport(ifp);

                    RelinkerOptionsPackage rop = new RelinkerOptionsPackage()
                    {
                        Cache = cache,
                        CustomRelinkUIndex = ImportOutsideOfPackageRelink,
                        CustomImportDependency = ImportDependencyOutsideOfPackage,
                    };

                    // Convert to cooked-format before porting.
                    if (!sourceAsset.IsForcedExport)
                    {
                        EntryExporter.PrepareGlobalFileForPorting(sourceAsset.FileRef, sourceAsset.FileRef.FileNameNoExtension);
                    }

                    EntryExporter.ExportExportToPackage(sourceAsset, package, out var ported, customROP: rop);
                }
            }
        }

        private static void AddPackagesToList(CaseInsensitiveDictionary<string> allPackageNames, CaseInsensitiveDictionary<ObjectLocation> db)
        {
            foreach (var item in db)
            {
                var mfp = item.Value.memoryfullpath;
                var packageName = mfp[..mfp.IndexOf('.')];
                allPackageNames.TryAdd(packageName, packageName); // BioT_Thessia.Texture -> BioT_Thessia
            }
        }

        private static void AddPackagesToList(CaseInsensitiveDictionary<string> allPackageNames, CaseInsensitiveDictionary<CaseInsensitiveDictionary<string>> db)
        {
            // Just add to list
            foreach (var item in db)
            {
                allPackageNames.TryAdd(item.Key, item.Key);
            }
        }

        private static void AddObjects(IMEPackage package, string classType, CaseInsensitiveDictionary<CaseInsensitiveDictionary<string>> assetMap)
        {
            if (assetMap.TryGetValue(package.FileNameNoExtension, out var assetList))
            {
                MilanLog.Information($"\tAdding asset type '{classType}' to package");
                using var cache = new TieredPackageCache(null);
                foreach (var asset in assetList)
                {
                    // Does this already exist in the package?
                    if (package.FindExport(asset.Key, classType) != null)
                    {
                        // Already in the package
                        continue;
                    }

                    // We know it exists

                    MilanLog.Information($"\t\tPorting asset in: {asset.Key}");

                    using var sourcePackage = cache.GetCachedPackage(asset.Value);
                    var sourceAsset = sourcePackage.FindExport(asset.Key) ?? sourcePackage.FindExport(asset.Key.Substring(asset.Key.IndexOf('.') + 1));

                    // Convert to cooked-format before porting.
                    if (!sourceAsset.IsForcedExport)
                    {
                        EntryExporter.PrepareGlobalFileForPorting(sourceAsset.FileRef, sourceAsset.FileRef.FileNameNoExtension);
                    }

                    RelinkerOptionsPackage rop = new RelinkerOptionsPackage()
                    {
                        Cache = cache,
                        CustomRelinkUIndex = ImportOutsideOfPackageRelink,
                        CustomImportDependency = ImportDependencyOutsideOfPackage,
                    };


                    EntryExporter.ExportExportToPackage(sourceAsset, package, out var ported, customROP: rop);
                }
            }
        }

        private static bool ImportDependencyOutsideOfPackage(ExportEntry sourceEntry, IMEPackage targetpackage, RelinkerOptionsPackage customrop, out List<EntryStringPair> entrystringpairs)
        {
            entrystringpairs = new List<EntryStringPair>(0);

            if (!sourceEntry.GetLinker().CaseInsensitiveEquals(targetpackage.FileNameNoExtension))
            {
                // Outside of package!
                // Generate imports for this object...
                GenerateImportForObject(sourceEntry, targetpackage);
                return true;
            }
            else
            {
                // Inside this package
                // Maybe the path is wrong from T3D. Do we have an export with same name and class under teh root, since we don't have path info?
                var existingDiffLevel = targetpackage.FindExport($"{targetpackage.FileNameNoExtension}.{sourceEntry.ObjectName.Instanced}", sourceEntry.ClassName);
                if (existingDiffLevel != null)
                {
                    // Dependency already in package, same MemoryFullPath but differing IFP.
                    return true;
                }

                // Just import like normal
                return false;
            }

            return true;
        }

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

            if (propertyname.CaseInsensitiveEquals("Parent") && relinkingexport.ClassName.CaseInsensitiveEquals("MaterialInstanceConstant"))
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

        // COMPILE HACKS
        // Hacks to fix issues due to BioWare naming systems.

        private static bool CompiledLE3_Rubble_Decal_MM_Once = false;

        // END COMPILE HACKS

        private static void CompilePackageMaterials(IMEPackage package, string folder, CaseInsensitiveDictionary<CaseInsensitiveDictionary<string>> matIfpDb)
        {
            if (!Directory.Exists(folder))
                return; // This folder doesn't exist

            using var cache = new TieredPackageCache(null);
            var usop = new UnrealScriptOptionsPackage
            {
                MissingObjectResolver = MissingObjectResolver,
                Cache = cache
            };

            var result = CompileFolder(folder, null);

            // We align to cooked version for now.
            PreparePackageForUDKify(package);

            if (result != null)
            {
                MilanLog.Error("Error preparing UDK packages:");
                foreach (var msg in result.AllErrors.Select(msg => msg.ToString()))
                {
                    MilanLog.Error(msg);
                }
            }

            return;

            MessageLog CompileFolder(string folder, IEntry parent)
            {
                var packageName = Path.GetFileName(folder);
                foreach (string t3dFilePath in Directory.EnumerateFiles(folder, "*.t3d",
                             SearchOption.TopDirectoryOnly))
                {
                    var matName = Path.GetFileNameWithoutExtension(t3dFilePath);
                    //if (matName != "PhotoMode_Filter_RetroLCD")
                    //    continue;

                    CompileSingleMaterial(matName, t3dFilePath, package, parent, usop);

                    var obj = package.FindExport(matName);

                    // 04/18/2025 - check mat ifp db to see if it needs to be nested.
                    if (matIfpDb.TryGetValue(packageName, out var packageInfo) && packageInfo.TryGetValue(matName, out var matIfp))
                    {
                        // NESTED - we must do parents.
                        MilanLog.Information($"\t\t-> Nesting material at {matIfp}");

                        // We nest under packagename as it doesn't make us deal with dupes of bringing in forced exports under their 
                        // nested parent. We will convert to that anyways after this step finishes
                        MoveToNested(obj, $"{packageName}.{matIfp}");
                    }
                }

                // Special compilation hacks.
                if (packageName == "biot_rubble")
                {
                    // Has a duplicate material in it.
                    // Compile it in proper place so we don't port it in and try to re-nest it over and over as other objects come in, as it has a dupe.
                    CompileSingleMaterial("Rubble_Decal_MM", Path.Combine(folder, "Rubble_Decal_MM.t3d"), package, package.FindExport(package.FileNameNoExtension, "Package"), usop);
                    package.Save();
                }

                // we don't compile subfolders
                //foreach (string subFolder in Directory.EnumerateDirectories(folder))
                //{
                //    var packageExport = ExportCreator.CreatePackageExport(package, Path.GetFileName(subFolder), parent);
                //    MessageLog log = CompileFolder(subFolder, packageExport);
                //    if (log is not null && log.HasErrors)
                //    {
                //        return log;
                //    }
                //}

                return null;
            }

            IEntry MissingObjectResolver(IMEPackage sourcepackage, string instancedfullpath, string classname)
            {
                // Resolve texture references
                if (classname
                is not "Texture2D"
                //and not "LightMapTexture2D"
                //and not "ShadowMapTexture2D"
                //and not "TerrainWeightMapTexture"
                and not "TextureFlipBook"
                and not "TextureCube")
                {
                    // Use default importer
                    return null;
                }

                var lookupName = instancedfullpath;
                if (instancedfullpath.Contains("."))
                {
                    lookupName = instancedfullpath.Substring(instancedfullpath.LastIndexOf('.') + 1);
                }

                if (texDb.TryGetValue(lookupName, out var info))
                {
                    // Does this already exist in the package?
                    if (package.FindEntry(info.memoryfullpath, info.classname) != null)
                    {
                        return package.FindEntry(info.memoryfullpath, info.classname);
                    }

                    // Is this outside of our package?
                    if (!info.memoryfullpath.StartsWith(sourcepackage.FileNameNoExtension + ".", StringComparison.OrdinalIgnoreCase))
                    {
                        // Debug.WriteLine($"Generating import for {info.memoryfullpath}");
                        return GenerateTextureImport(package, info.classname, info.memoryfullpath);
                    }

                    // We know it exists
                    // We have to do IsClass or some objects don't properly load when getting dependencies.
                    var sourcePackage = MEPackageHandler.UnsafePartialLoad(info.packagefile, x => x.ClassName is "Package" or "TextureCube" || x.IsTexture() || x.IsClass);
                    var sourceTex = sourcePackage.Exports.First(x => x.MemoryFullPath.CaseInsensitiveEquals(info.memoryfullpath) && x.ClassName.CaseInsensitiveEquals(classname));
                    if (!sourceTex.IsDataLoaded())
                    {
                        Debugger.Break();
                    }

                    // If not forced export, we have to load data for the package, as we are going to move objects before port
                    if (!sourceTex.IsForcedExport)
                    {
                        // Fully load
                        sourcePackage = MEPackageHandler.OpenMEPackage(info.packagefile);
                        sourceTex = sourcePackage.FindExport(sourceTex.InstancedFullPath);

                        // Prepare for cooked-style
                        EntryExporter.PrepareGlobalFileForPorting(sourcePackage, sourcePackage.FileNameNoExtension);
                    }

                    RelinkerOptionsPackage rop = new RelinkerOptionsPackage()
                    {
                        // Cache?
                        Cache = new TieredPackageCache(null),
                        CustomRelinkUIndex = ImportOutsideOfPackageRelink,
                        CustomImportDependency = ImportDependencyOutsideOfPackage,
                        CheckImportsWhenExportingToPackage = false
                    };

                    EntryExporter.ExportExportToPackage(sourceTex, package, out var ported, customROP: rop);
                    return ported;
                }

                Debug.WriteLine($"Texture not found: {instancedfullpath}");
                return null;
            }
        }

        private static MessageLog CompileSingleMaterial(string matName, string t3dFilePath, IMEPackage package, IEntry parent, UnrealScriptOptionsPackage usop)
        {
            var sourceLines = File.ReadAllLines(t3dFilePath);
            sourceLines = sourceLines.Where(x =>
                !x.Trim().StartsWith("ReferencedTextureGuids") &&
                !x.Trim().StartsWith("EditorComments") && // This will be important to keep later
                true
                ).ToArray();

            //if (sourceLines.Any(x => x.Contains("BioMaterialExpression", StringComparison.OrdinalIgnoreCase)))
            //{
            //    // We cannot compile this in UDK currently.
            //    continue;
            //}

            MilanLog.Information($"\tCompiling material {matName}");
            MessageLog log = UnrealScriptCompiler.CompileT3D(string.Join('\n', sourceLines), package, parent, usop);
            if (log.HasLexErrors || log.HasErrors)
            {
                log.LogError($"Failed to compile {t3dFilePath}");
                return log;
            }

            return null;
        }

        private static void PreparePackageForUDKify(IMEPackage package, string packageName = null)
        {
            // Move all unfound textures to a single package
            var nonshippingTextures = package.Imports.Where(x => x.idxLink == 0 && x.IsTexture()).ToList();
            if (nonshippingTextures.Any())
            {
                var nonship = ExportCreator.CreatePackageImport(package, "MissingTextures");
                foreach (var tex in nonshippingTextures)
                {
                    tex.idxLink = nonship.UIndex;
                }
            }

            var pPackage = ExportCreator.CreatePackageExport(package, packageName ?? package.FileNameNoExtension);
            var rootExports = package.Exports.Where(x => x != pPackage && x.idxLink == 0);
            foreach (var rootExport in rootExports)
            {
                rootExport.idxLink = pPackage.UIndex;
            }

            SetForcedExportFlag(pPackage, true);


            // MIC - Remove static permutations
            foreach (var mic in package.Exports.Where(x => x.IsA("MaterialInstance")))
            {
                var hasPerm = mic.GetProperty<BoolProperty>("bHasStaticPermutationResource");
                if (hasPerm?.Value == true)
                {
                    mic.RemoveProperty("bHasStaticPermutationResource");
                    mic.WriteBinary([]);
                }
            }

            foreach (var mat in package.Exports.Where(x => x.IsA("Material")))
            {
                // These won't exist in UDK.
                mat.RemoveProperty("PhysMaterial");
            }
        }

        public static void SetForcedExportFlag(ExportEntry exp, bool set)
        {

            List<IEntry> entries = exp.GetAllDescendants();
            entries.Add(exp);

            foreach (IEntry entry in entries)
            {
                if (entry is not ExportEntry export) { continue; }

                if (export.ClassName == "ObjectReferencer") { continue; }

                if (set)
                {
                    // Set
                    export.ExportFlags |= UnrealFlags.EExportFlags.ForcedExport;
                }
                else
                {
                    // Strip
                    export.ExportFlags &= ~UnrealFlags.EExportFlags.ForcedExport;
                }
            }
        }

        private static IEntry GenerateTextureImport(IMEPackage package, string className, string instancedfullpath)
        {
            var parts = instancedfullpath.Split('.');
            IEntry currentParent = null;
            var currentPath = "";

            for (int i = 0; i < parts.Length; i++)
            {
                if (i < parts.Length - 1)
                {
                    // Parents of texture
                    currentPath += $".{parts[i]}";
                    currentPath = currentPath.Trim('.'); // Just for first loop.

                    // Check if parent already exists in package
                    // These will never be exports, so we only check imports
                    IEntry tempParent = package.FindImport(currentPath, "Package");
                    if (tempParent != null)
                    {
                        currentParent = tempParent;
                        continue;
                    }

                    // Package parent
                    ImportEntry packageImp = new ImportEntry(package)
                    {
                        ClassName = "Package",
                        PackageFile = "Core",
                        ObjectName = NameReference.FromInstancedString(parts[i]),
                        idxLink = currentParent?.UIndex ?? 0
                    };
                    package.AddImport(packageImp);
                    currentParent = packageImp;
                    continue;
                }
                else
                {
                    // Texture itself
                    ImportEntry texImp = new ImportEntry(package)
                    {
                        ClassName = className,
                        PackageFile = ImportEntry.GetPackageFile(MEGame.LE3, className),
                        ObjectName = NameReference.FromInstancedString(parts[i]),
                        idxLink = currentParent?.UIndex ?? 0
                    };
                    package.AddImport(texImp);
                    return texImp;
                }
            }

            // Shouldn't hit this, hopefully.
            return null;
        }

        public static void GeneratePackageInfos()
        {
            // Maps a texture's instance object name to the path of a package that contains it's export data
            var MatToMFP = new CaseInsensitiveConcurrentDictionary<string>();

            // var compiledFile = MEPackageHandler.OpenMEPackage(@"S:\Milan\UDK\LE3_Mats.pcc", forceLoadFromDisk: true);


            var backupPath = ME3TweaksBackups.GetGameBackupPath(MEGame.LE3);
            var files = Directory.GetFiles(backupPath, "*.pcc", SearchOption.AllDirectories);
            var set = new SortedSet<string>();

            Parallel.ForEach(files, packageF =>
            {
                var package = MEPackageHandler.UnsafePartialLoad(packageF, x => false);

                // imports
                foreach (var mat in package.Imports.Where(x => x.IsA("Material"))) // This might need changed later.
                {
                    if (mat.Parent != mat.GetRoot())
                    {
                        // Nested deeper into package than the root.
                        MatToMFP[mat.ObjectName.Instanced] = mat.MemoryFullPath;
                    }
                }

                // Need to get list of IFPs for remaking BioGs, I think...
                // exports
                foreach (var mat in package.Exports.Where(x => x.IsA("Material"))) // This might need changed later.
                {
                    if (mat.Parent != mat.GetRoot())
                    {
                        // Nested deeper into package than the root.
                        MatToMFP[mat.ObjectName.Instanced] = mat.MemoryFullPath;
                    }
                }

            });
            var outJ = JsonConvert.SerializeObject(MatToMFP, Formatting.Indented);
            File.WriteAllText(@"S:\Milan\UDK\MFPDBForT3D.json", outJ);
            Debug.WriteLine(string.Join('\n', set));
        }
    }
}
