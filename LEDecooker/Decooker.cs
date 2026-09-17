using LegendaryExplorerCore.GameFilesystem;
using LegendaryExplorerCore.Helpers;
using LegendaryExplorerCore.Misc;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Packages.CloningImportingAndRelinking;
using LegendaryExplorerCore.Unreal;
using LegendaryExplorerCore.Unreal.BinaryConverters;
using LegendaryExplorerCore.Unreal.ObjectInfo;
using LegendaryExplorerCore.UnrealScript;
using LegendaryExplorerCore.UnrealScript.Compiling.Errors;
using Newtonsoft.Json;
using System.Diagnostics;
using System.IO.Compression;
using System.Text;
using static LegendaryExplorerCore.Unreal.UnrealFlags;

namespace LEDecooker
{
    /// <summary>
    /// Decooks game, making it ready for use in UDK.
    /// </summary>
    internal static class Decooker
    {
        private static CaseInsensitiveDictionary<CaseInsensitiveDictionary<string>> MaterialIFPDB;
        private static CaseInsensitiveDictionary<ObjectLocation> TextureLookupDB;
        private static CaseInsensitiveDictionary<ObjectLocation> OppositeTextureLookupDB;
        private static CaseInsensitiveDictionary<CaseInsensitiveDictionary<string>> StaticMeshLookupDB;
        private static CaseInsensitiveDictionary<CaseInsensitiveDictionary<string>> MaterialInstanceConstantLookupDB;
        private static CaseInsensitiveDictionary<CaseInsensitiveDictionary<string>> RvrEffectsMaterialUserLookupDB;
        private static CaseInsensitiveDictionary<CaseInsensitiveDictionary<string>> TerrainMaterialLookupDB;
        private static CaseInsensitiveConcurrentDictionary<string> PortingItems = new();

        /// <summary>
        /// Every object path in the target game, grouped by its leaf object name. Built once from the
        /// ObjectInstanceDB, which indexes by instanced full path only; T3D material data names a
        /// texture without its package, so resolving one needs the reverse lookup.
        /// </summary>
        private static CaseInsensitiveDictionary<List<string>> ObjectPathsByName;

        /// <summary>Class name per object path, for databases with no class table.</summary>
        private static readonly CaseInsensitiveDictionary<string> CandidateClassCache = new();

        /// <summary>
        /// Exact shipping texture bindings, recovered lazily per material while compiling an LE3
        /// T3D. T3D texture fields carry only a leaf name, so this is the one source of truth that
        /// can distinguish two same-named textures living in different packages.
        /// </summary>
        private static readonly CaseInsensitiveDictionary<CaseInsensitiveDictionary<ObjectLocation>> ShippingTextureBindingsByMaterial = new();

        /// <summary>
        /// Source games whose T3D batch encodes package nesting directly in the filename, e.g.
        /// "Materials.EMT_FaceSplash.T3D" means object EMT_FaceSplash nested under a package export
        /// named "Materials". The last dot-separated segment is always the object's own name; every
        /// segment before it is a package export to create/reuse as a parent, in order.
        ///
        /// This includes materials whose real parent is an RvrEffectsMaterialUser (a CombinedEffect_*
        /// sibling of one) -- no special-casing is needed for that here. MoveToNested just creates a
        /// plain Package placeholder for every segment, and the CopyProperties(RvrEffectsMaterialUserLookupDB)
        /// pass later in CompileGameAssets promotes any placeholder whose full path matches that DB into
        /// the real class, exactly as it already does today for MaterialInstanceConstant parents.
        ///
        /// Games not listed here fall back to the old system (matIfpDb, built by scanning the original
        /// game). Add a game here once its T3D batch has been regenerated with nesting info in the
        /// filename; remove it from the old batch's reliance as new batches arrive.
        /// </summary>
        private static readonly HashSet<MEGame> FilenameNestedGames = new() { MEGame.LE3 };

        /// <summary>
        /// Compiles the T3D files for the specified game, generating packages with material expression data. It also generates the 
        /// source style packages for supporting assets that are needed for other things such as StaticMeshes, Material Instance Constants,
        /// and Textures.
        /// </summary>
        /// <param name="targetGame">The game to compile assets for</param>
        public static void CompileT3Ds()
        {
            var compiledOutputFolder = Path.Combine(CLIOptions.ParsedOptions.CompiledAssetsOutputFolder, CLIOptions.ParsedOptions.Game.ToString());
            Directory.CreateDirectory(compiledOutputFolder);

            // Compile LE
            bool clearOutput = false;
            CompileGameAssets(compiledOutputFolder, CLIOptions.ParsedOptions.Game, CLIOptions.ParsedOptions.Game, clearOutput);
            // Compile OT -> LE
            if (CLIOptions.ParsedOptions.Game != MEGame.LE2)
            {
                // Port in the content from the opposite generation as well.
                DecookerLog.Information($"------ Layering {CLIOptions.ParsedOptions.Game.ToOppositeGeneration()} assets into decooked files");
                CompileGameAssets(compiledOutputFolder, CLIOptions.ParsedOptions.Game.ToOppositeGeneration(), CLIOptions.ParsedOptions.Game, false);
            }

            FixImports(CLIOptions.ParsedOptions.CompiledAssetsOutputFolder, CLIOptions.ParsedOptions.Game);
        }

        /// <summary>
        /// Resolve imports in LE3 packages - test they actually can resolve, move around missing ones.
        /// </summary>
        /// <param name="inPath"></param>
        private static void FixImports(string inPath, MEGame game)
        {
            TieredPackageCache tpc = TieredPackageCache.GetGlobalPackageCache(game);
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
                            DecookerLog.Information($@"Repointing object in package from import to export: {export.InstancedFullPath}");
                            Relinker.RepointObject(asset, export);
                            continue;
                        }

                        // Maybe it's nested...
                        var matchingExp = package.Exports.FirstOrDefault(x => x.ClassName == asset.ClassName && x.ObjectName.Instanced == asset.ObjectName.Instanced);
                        if (matchingExp != null)
                        {
                            DecookerLog.Information($@"RISKY Repointing object in package from import to export: {matchingExp.InstancedFullPath}");
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
                                DecookerLog.Information($@"Moving object in {destPackage.FileNameNoExtension}: {misplacedAsset.InstancedFullPath}");
                                MoveToNested(misplacedAsset, asset.InstancedFullPath);
                            }
                            else
                            {
                                DecookerLog.Warning($@"Import failed in {package.FileNameNoExtension}: {asset.InstancedFullPath}");
                            }
                        }
                        else
                        {
                            DecookerLog.Warning($@"No importable package in {package.FileNameNoExtension}: {asset.InstancedFullPath}");
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

        /// <summary>
        /// Where to find an object
        /// </summary>
        class ObjectLocation
        {
            public string packagefile { get; set; }
            public string memoryfullpath { get; set; }
            public string classname { get; set; }
        }

#if MP
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
#endif

        /// <summary>
        /// Generates decooked packages that will later be converted to UPKs
        /// </summary>
        /// <param name="outputFolder"></param>
        public static void CompileGameAssets(string outputFolder, MEGame sourceGame, MEGame targetGame, bool clearOutput)
        {
            // Turn this on to save packages as the files are compiled - letting you see intermediate steps, but at a performance cost.
            bool debugPackages = false;

            DecookerShared.TargetObjectDB = DecookerShared.LoadObjectDB(sourceGame);

            if (clearOutput)
            {
                DecookerLog.Information("Clearing Stage 1 T3D packages");
                foreach (var file in Directory.GetFiles(outputFolder))
                {
                    File.Delete(file);
                }
            }

            DecookerLog.Information("Loading material data...");
            var t3dZipB = DecookerShared.ExtractResource("LEDecooker.materials.materials.zip");
            var t3dZipM = new MemoryStream(t3dZipB);
            var t3dZip = new ZipArchive(t3dZipM);
            LoadExtraData(sourceGame);

            // Index the archive once. CompilePackageMaterials used to scan every entry in the
            // materials zip for every output package; a full game has enough packages and T3Ds for
            // that to become a substantial amount of otherwise useless string comparison work.
            // Keep the archive order within each list, so compilation and its trace logging remain
            // deterministic and in the same order as before.
            var materialEntriesByPackage = IndexMaterialEntries(t3dZip, sourceGame);

            // All packages that will be generated
            var allPackageNames = new CaseInsensitiveDictionary<string>();

            foreach (var packageName in materialEntriesByPackage.Keys)
            {
                allPackageNames[packageName] = packageName;
            }

            //foreach (var p in Directory.GetDirectories(inputFolder).Select(Path.GetFileName))
            //{
            //    allPackageNames.Add(p, p);
            //}

            // We also want to add texture and mesh-only packages
            AddPackagesToList(allPackageNames, StaticMeshLookupDB);
            AddPackagesToList(allPackageNames, TextureLookupDB);
            AddPackagesToList(allPackageNames, TerrainMaterialLookupDB);
            var packages = allPackageNames.Select(x => x.Key).OrderBy(x => x).ToList();

            // Used to restart from specific position.
            bool bypass = false;


            // FILTERING FOR DEBUGGING
            packages = filterPackages(packages);

            int done = 0;
            int total = packages.Count;

            foreach (var packageName in packages)
            {
                done++;
                // Debug skip to number
                //if (done < 500)
                //    continue;

                bypass = true;

                if (packageName.StartsWith("Engine", StringComparison.OrdinalIgnoreCase) && !packageName.Contains("EngineDebugMaterials", StringComparison.OrdinalIgnoreCase))
                    continue;
                if (packageName.StartsWith("Editor", StringComparison.OrdinalIgnoreCase))
                    continue;
                if (packageName.StartsWith("NodeBuddies", StringComparison.OrdinalIgnoreCase))
                    continue;
                if (packageName.StartsWith("MaterialTemplates", StringComparison.OrdinalIgnoreCase))
                    continue;
                if (packageName.StartsWith("MobileEmulation", StringComparison.OrdinalIgnoreCase))
                    continue;
                if (packageName.StartsWith("TestOneOfEveryResource", StringComparison.OrdinalIgnoreCase))
                    continue;

                //if (!packageName.StartsWith("BioApl_Veh_OculonA", StringComparison.OrdinalIgnoreCase))
                //    continue;

                var packagePath = Path.Combine(outputFolder, $"{packageName}.pcc");

                // TEMP - DO NOT WIPE EXISTING
                //if (File.Exists(packagePath))
                //    continue;
                // END TEMP

                IMEPackage package;
                if (clearOutput)
                {
                    package = MEPackageHandler.CreateAndOpenPackage(packagePath, targetGame);
                }
                else
                {
                    if (File.Exists(packagePath))
                    {
                        // Open the existing package
                        package = MEPackageHandler.OpenMEPackage(packagePath);
                    }
                    else
                    {
                        // Make new one
                        package = MEPackageHandler.CreateAndOpenPackage(packagePath, targetGame);
                    }
                }

                DecookerLog.Information($"Compiling package {package.FileNameNoExtension} [{done}/{total}]");
                IReadOnlyList<ZipArchiveEntry> materialEntries = materialEntriesByPackage.TryGetValue(packageName, out var entries)
                    ? entries //.Take(1).ToList()
                    : Array.Empty<ZipArchiveEntry>();
                CompilePackageMaterials(package, sourceGame, materialEntries, MaterialIFPDB);
                AddTextures(package, sourceGame, TextureLookupDB);
                package.PreparePackageForUDKify();
                // We must do this to ensure we have the RVR stuff set up as the MaterialInstanceConstant may reference it as a parent
                CopyProperties(package, sourceGame, "RvrEffectsMaterialUser", RvrEffectsMaterialUserLookupDB);
                package.PreparePackageForUDKify();
                VerifyCombinedEffectParents(package);
                AddObjects(package, sourceGame, "MaterialInstanceConstant", MaterialInstanceConstantLookupDB);
                if (debugPackages) { package.Save(); }

                AddObjects(package, sourceGame, "StaticMesh", StaticMeshLookupDB);
                AddObjects(package, sourceGame, "TerrainMaterial", TerrainMaterialLookupDB);
                package.PreparePackageForUDKify();

                if (debugPackages) { package.Save(); }
                SpecialFixes(package, sourceGame);
                if (debugPackages) { package.Save(); }
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
                            DecookerLog.Error($"Duplicate object found in {package.FileNameNoExtension}: {dup.Entry.InstancedFullPath}");
                        }
                        package.Save();
                        Debugger.Break();
                    }

                    // Set flags to match what source side package would. This affects import resolution code.
                    package.setFlags(UnrealFlags.EPackageFlags.AllowDownload | UnrealFlags.EPackageFlags.NoExportsData);
                    package.Save();
                    /*if (package.IsModified)
                    {
                        package.Save(ChangeDirectory(package.FilePath, @"E:\Decooked\LE3ME3"));
                    }*/
                }
            }

            foreach (var f in PortingItems)
            {
                Debug.WriteLine($"{f.Key}\t\t{f.Value}");
            }
        }

        private static List<string> filterPackages(List<string> packages)
        {
            // Duplicates: 
            //   BioD_MPRctr_100SP
            //   BioD_Omg02A_400CntrlRm
            //   biog_wpn_hvy_r
            //   biot_rubble -> bioware screwed this one up.

            // Crash out:
            //   BIOG_WPN_SNP_M_CON_MP4 FIXED per import
            //   BioS_MPJungle 
            //   BioVFX_Env_Hologram
            return packages.Where(packageName =>
            {
                // Uncomment to disable filtering.
                // return true;

                // Put filename here and anything not matching it will be skipped
                if (!packageName.CaseInsensitiveEquals("EffectsMaterials"))
                {
                    return false;
                }

                // Allowed
                return true;
            }).ToList();

        }

        private static void SpecialFixes(IMEPackage package, MEGame sourceGame)
        {
            if (package.Game == MEGame.LE3 && package.FileNameNoExtension == "BIOG_HMM_HED_PROMorph")
            {
                // We don't have T3D for the duplicate illusave man B face (reaperized)
                // We are just going to clone the existing one cause it has the same name.
                if (package.FindExport("BIOG_HMM_HED_PROMorph.IllusiveMan.Illb.HMM_HED_PROIllusiveMan_Face_MASTER_MAT", "Material") == null)
                {
                    // Needs cloned - package hasn't been lifted to non-forced export yet
                    var original = package.FindExport("BIOG_HMM_HED_PROMorph.IllusiveMan.HMM_HED_PROIllusiveMan_Face_MASTER_MAT");
                    var targetLink = package.FindExport("BIOG_HMM_HED_PROMorph.IllusiveMan.Illb");
                    IEntry newTreeRoot = EntryCloner.CloneTree(original, false);
                    newTreeRoot.Parent = targetLink;
                    DecookerLog.Information($"\t\tMade clone of IllusiveManB Face material");
                }
            }
        }

        private static string ChangeDirectory(string filePath, string newDirectory)
        {
            return Path.Combine(newDirectory, Path.GetFileName(filePath));
        }

        /// <summary>
        /// Loads extra supporting data
        /// </summary>
        private static void LoadExtraData(MEGame game)
        {
            using var ms = new MemoryStream(DecookerShared.ExtractResource($@"LEDecooker.supportfiles.supportdbs.zip"));
            using var zip = new ZipArchive(ms);

            var oppositeGame = game.ToOppositeGeneration();

            // T3D doesnt contain in-package pathing. This DB is used to try to fix that
            var supportData = DecookerShared.ReadSupportFileString(zip, $"materialifps_{game}.json");
            MaterialIFPDB = JsonConvert.DeserializeObject<CaseInsensitiveDictionary<CaseInsensitiveDictionary<string>>>(supportData);

            // List of all textures. We use this to make sure we just pull in all game textures
            supportData = DecookerShared.ReadSupportFileString(zip, $"texturedb_{game}.json");
            TextureLookupDB = JsonConvert.DeserializeObject<CaseInsensitiveDictionary<ObjectLocation>>(supportData);

            supportData = DecookerShared.ReadSupportFileString(zip, $"texturedb_{oppositeGame}.json");
            OppositeTextureLookupDB = JsonConvert.DeserializeObject<CaseInsensitiveDictionary<ObjectLocation>>(supportData);

            // Static meshes are used during lighting and udk export, so we pull them in
            supportData = DecookerShared.ReadSupportFileString(zip, $"staticmeshdb_{game}.json");
            StaticMeshLookupDB = JsonConvert.DeserializeObject<CaseInsensitiveDictionary<CaseInsensitiveDictionary<string>>>(supportData);

            // Material Instance Constants are very often assigned to static meshes in udk, so we pull them in here
            supportData = DecookerShared.ReadSupportFileString(zip, $"materialinstanceconstantdb_{game}.json");
            MaterialInstanceConstantLookupDB = JsonConvert.DeserializeObject<CaseInsensitiveDictionary<CaseInsensitiveDictionary<string>>>(supportData);

            // RVR - Referenced by material instance parents
            supportData = DecookerShared.ReadSupportFileString(zip, $"rvreffectsmaterialuserdb_{game}.json");
            RvrEffectsMaterialUserLookupDB = JsonConvert.DeserializeObject<CaseInsensitiveDictionary<CaseInsensitiveDictionary<string>>>(supportData);

            // Terrain materials are package-root assets (like Materials), not nested under TheWorld, so
            // they get their own lookup database the same way. Needed for MilanShaderHost to be able to
            // find and compile them.
            supportData = DecookerShared.ReadSupportFileString(zip, $"terrainmaterialdb_{game}.json");
            TerrainMaterialLookupDB = JsonConvert.DeserializeObject<CaseInsensitiveDictionary<CaseInsensitiveDictionary<string>>>(supportData);

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
        /// Sanity check for the RvrEffectsMaterialUser wrinkle: a CombinedEffect_* material's direct
        /// parent is supposed to end up as a real RvrEffectsMaterialUser, promoted from the plain
        /// Package placeholder that nesting creates by the CopyProperties(RvrEffectsMaterialUserLookupDB)
        /// call just above this. That promotion only happens when the placeholder's full path matches an
        /// entry in the RVR support DB -- if the T3D's encoded nesting path is wrong, or the DB is simply
        /// missing that object (the game scan that builds it can only find what actually shipped), the
        /// parent silently stays a Package and the material ends up decooked with the wrong parent type.
        /// With hundreds of these files per batch that's easy to miss without an explicit log line.
        /// </summary>
        private static void VerifyCombinedEffectParents(IMEPackage package)
        {
            foreach (var mat in package.Exports.Where(x => x.IsA("Material") && x.ObjectName.Instanced.StartsWith("CombinedEffect_", StringComparison.OrdinalIgnoreCase)))
            {
                if (mat.Parent is not { ClassName: "RvrEffectsMaterialUser" })
                {
                    DecookerLog.Warning($"\t\tCombinedEffect material's parent was not promoted to RvrEffectsMaterialUser: {mat.InstancedFullPath} (parent class: {mat.Parent?.ClassName ?? "<none>"})");
                }
            }
        }

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
        private static void AddTextures(IMEPackage package, MEGame sourceGame, CaseInsensitiveDictionary<ObjectLocation> assetMap)
        {
            var packageName = package.FileNameNoExtension;
            var assets = assetMap.Where(x => x.Value.memoryfullpath.StartsWith(packageName + ".", StringComparison.OrdinalIgnoreCase));
            if (assets.Any())
            {
                DecookerLog.Information($"\tAdding asset type 'Textures' to package");
                using SFARPackageCache cache = new SFARPackageCache();
                foreach (var asset in assets)
                {
                    if (asset.Value.classname == "TerrainWeightMapTexture")
                    {
                        // This brings in parents which and is under TheWorld
                        continue;
                    }
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
                    DecookerLog.Information($"\t\tPorting asset in: {memoryifp}");
                    var path = Path.Combine(DecookerShared.GetCachedGameBackupPath(sourceGame), asset.Value.packagefile.TrimStart('\\', '/'));
                    using var sourcePackage = cache.GetCachedPackage(path, openIfNotInCache: true);
                    PortingItems[asset.Key] = path;

                    var sourceAsset = sourcePackage.FindExport(memoryifp) ?? sourcePackage.FindExport(ifp);
                    // These are nested under terrain; IDK how we could decook that without bringing in levels
                    //if (sourceAsset.ClassName == "TerrainWeightMapTexture")
                    //{
                    //    // Get rid of this or it'll bring all sorts of garbage in.
                    //    sourceAsset.RemoveProperty("ParentTerrain");
                    //}


                    RelinkerOptionsPackage rop = new RelinkerOptionsPackage()
                    {
                        Cache = cache,
                        CustomRelinkUIndex = DecookerShared.ImportOutsideOfPackageRelink,
                        CustomImportDependency = ImportDependencyOutsideOfPackage,
                        PortParentAsPackage = parent =>
                        {
                            var shouldDoAsPackage = parent.ClassName == "Prefab";
                            return shouldDoAsPackage;
                        },
                        AllowMemoryPathLookups = true, // Prevents duplicate object porting in the OT layering step, especially for ME1 to LE1 as has natively uncooked packages.
                    };

                    // Convert to Seek Free porting
                    if (sourceAsset.FileRef.FileNameNoExtension.StartsWith("BIOG_") || !sourceAsset.FileRef.Flags.HasFlag(EPackageFlags.RequireImportsAlreadyLoaded))
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

        /// <summary>
        /// Groups material T3Ds by their output package. ZipArchive only provides a flat entry list,
        /// so doing this once avoids re-walking the complete archive for every package we compile.
        /// </summary>
        private static Dictionary<string, List<ZipArchiveEntry>> IndexMaterialEntries(ZipArchive archive, MEGame sourceGame)
        {
            var entriesByPackage = new Dictionary<string, List<ZipArchiveEntry>>(StringComparer.OrdinalIgnoreCase);
            var gamePrefix = sourceGame + "/";

            foreach (var entry in archive.Entries)
            {
                if (!entry.FullName.StartsWith(gamePrefix, StringComparison.OrdinalIgnoreCase))
                    continue;

                var packageNameEnd = entry.FullName.IndexOf('/', gamePrefix.Length);
                if (packageNameEnd <= gamePrefix.Length)
                    continue; // Game-level directory entry or malformed resource path.
                if (entry.FullName.Length <= packageNameEnd + 1)
                    continue; // Package directory entry; the former prefix/length filter excluded it.

                var packageName = entry.FullName.Substring(gamePrefix.Length, packageNameEnd - gamePrefix.Length);
                if (!entriesByPackage.TryGetValue(packageName, out var entries))
                {
                    entriesByPackage.Add(packageName, entries = new List<ZipArchiveEntry>());
                }
                entries.Add(entry);
            }

            return entriesByPackage;
        }

        private static void AddObjects(IMEPackage package, MEGame sourceGame, string classType, CaseInsensitiveDictionary<CaseInsensitiveDictionary<string>> assetMap)
        {
            if (assetMap.TryGetValue(package.FileNameNoExtension, out var assetList))
            {
                DecookerLog.Information($"\tAdding asset type '{classType}' to package");
                using SFARPackageCache cache = new SFARPackageCache();
                foreach (var asset in assetList)
                {
                    // Does this already exist in the package?
                    if (package.FindExport(asset.Key, classType) != null)
                    {
                        // Already in the package
                        continue;
                    }

                    // We know it exists

                    DecookerLog.Information($"\t\tPorting asset in: {asset.Key}");
                    var path = Path.Combine(DecookerShared.GetCachedGameBackupPath(sourceGame), asset.Value.TrimStart('\\', '/'));
                    using var sourcePackage = cache.GetCachedPackage(path, openIfNotInCache: true);
                    var sourceAsset = sourcePackage.FindExport(asset.Key) ?? sourcePackage.FindExport(asset.Key.Substring(asset.Key.IndexOf('.') + 1));

                    PortingItems[asset.Key] = path;

                    // Convert to Seek Free porting
                    if (sourceAsset.FileRef.FileNameNoExtension.StartsWith("BIOG_"))
                    {
                        EntryExporter.PrepareGlobalFileForPorting(sourceAsset.FileRef, sourceAsset.FileRef.FileNameNoExtension);
                    }

                    RelinkerOptionsPackage rop = new RelinkerOptionsPackage()
                    {
                        Cache = cache,
                        CustomRelinkUIndex = DecookerShared.ImportOutsideOfPackageRelink,
                        CustomImportDependency = ImportDependencyOutsideOfPackage,
                        AllowMemoryPathLookups = true, // helps prevent dupes after prepare for UDKify
                    };


                    EntryExporter.ExportExportToPackage(sourceAsset, package, out var ported, customROP: rop);
                }
            }
        }

        private static void CopyProperties(IMEPackage package, MEGame sourceGame, string classType, CaseInsensitiveDictionary<CaseInsensitiveDictionary<string>> assetMap)
        {
            if (classType == "RvrEffectsMaterialUser")
            {
                // This is a special case where we want to copy properties but not the actual object. The RVR effect materials are nested under the package root and are used as parents for CombinedEffect_* materials. We only want to copy the properties of these RVR effect materials to the package, but we don't want to port the actual RVR effect material objects themselves.
                //DecookerLog.Information($"\tCopying properties for asset type '{classType}' to package (special case)");
                Debug.WriteLine("Test");
            }

            if (assetMap.TryGetValue(package.FileNameNoExtension, out var assetList))
            {
                DecookerLog.Information($"\tCopying properties for asset type '{classType}' to package");
                using SFARPackageCache cache = new SFARPackageCache();
                foreach (var asset in assetList)
                {
                    // Does this already exist in the package?
                    var targetAsset = package.FindExport(asset.Key, @"Package");

                    if (targetAsset == null)
                    {
                        // Nothing to update
                        continue;
                    }
                    // We know it exists
                    DecookerLog.Information($"\t\tCopying properties for asset in: {asset.Key}");
                    var path = Path.Combine(DecookerShared.GetCachedGameBackupPath(sourceGame), asset.Value.TrimStart('\\', '/'));
                    using var sourcePackage = cache.GetCachedPackage(path, openIfNotInCache: true);
                    var sourceAsset = sourcePackage.FindExport(asset.Key) ?? sourcePackage.FindExport(asset.Key.Substring(asset.Key.IndexOf('.') + 1));

                    PortingItems[asset.Key] = path;

                    // Convert to Seek Free porting
                    if (sourceAsset.FileRef.FileNameNoExtension.StartsWith("BIOG_") || (sourceAsset.FileRef.Flags & EPackageFlags.RequireImportsAlreadyLoaded) != 0)
                    {
                        EntryExporter.PrepareGlobalFileForPorting(sourceAsset.FileRef, sourceAsset.FileRef.FileNameNoExtension);
                    }

                    RelinkerOptionsPackage rop = new RelinkerOptionsPackage()
                    {
                        Cache = cache,
                        CustomRelinkUIndex = DecookerShared.ImportOutsideOfPackageRelink,
                        CustomImportDependency = ImportDependencyOutsideOfPackage,
                        AllowMemoryPathLookups = true
                    };


                    var classX = EntryImporter.EnsureClassIsInFile(package, classType, rop, DecookerShared.GetCachedGameBackupPath(sourceGame));
                    targetAsset.Class = classX;
                    EntryImporter.ImportAndRelinkEntries(EntryImporter.PortingOption.ReplaceSingularWithRelink, sourceAsset, package, targetAsset, true, rop, out var _);
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
                DecookerShared.GenerateImportForObject(sourceEntry, targetpackage);
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
        /// Compiles material assets from a package using data from a source game and a provided archive, updating the
        /// package with the compiled materials and handling any necessary nesting or property alignment.
        /// </summary>
        /// <remarks>This method prepares the package for use with UDK by aligning material properties and
        /// compiling materials from the provided archive. Any errors encountered during compilation are logged.
        /// Material nesting is performed based on the provided mapping to ensure correct package structure.</remarks>
        /// <param name="package">The package to which compiled material assets will be added or updated.</param>
        /// <param name="sourceGame">The source game from which material data and context are derived.</param>
        /// <param name="materialEntries">The material definitions from the archive that belong to this package.</param>
        /// <param name="matIfpDb">A mapping of package and material names to their intended nesting paths, used to determine if materials
        /// should be nested within the package structure.</param>
        private static void CompilePackageMaterials(IMEPackage package, MEGame sourceGame, IReadOnlyList<ZipArchiveEntry> materialEntries, CaseInsensitiveDictionary<CaseInsensitiveDictionary<string>> matIfpDb)
        {
            using SFARPackageCache cache = new SFARPackageCache();

            // CompileT3D only supplies the missing-object callback with a bare texture name. Keep
            // the material currently being compiled so that callback can consult the corresponding
            // shipped MaterialResource before attempting a game-wide leaf-name guess.
            string activeMaterialPath = null;

            var usop = new UnrealScriptOptionsPackage
            {
                MissingObjectResolver = MissingObjectResolver,
                Cache = cache
            };

            var compilationTimer = Stopwatch.StartNew();
            var result = CompileFolder(package, sourceGame, materialEntries, null);
            compilationTimer.Stop();
            if (materialEntries.Count > 0)
            {
                DecookerLog.Information($"\tCompiled {materialEntries.Count} material T3D(s) in {compilationTimer.ElapsedMilliseconds:N0} ms");
            }

            // We align to cooked version for now.
            package.PreparePackageForUDKify();

            if (result != null)
            {
                DecookerLog.Error("Error preparing UDK packages:");
                foreach (var msg in result.AllErrors.Select(msg => msg.ToString()))
                {
                    DecookerLog.Error(msg);
                }
            }


            // 03/22/2026
            // Update the bUsedWith properties to match the original object so we compile the correct shader set.
            var usageFlagsTimer = Stopwatch.StartNew();
            foreach (var mat in package.Exports.Where(x => x.IsA("Material")))
            {
                var candidates = DecookerShared.TargetObjectDB.GetFilesContainingObject(mat.InstancedFullPath);
                bool writtenProps = false;

                if (candidates != null)
                {
                    foreach (var c in candidates)
                    {
                        // Todo: Need to support this also doing other generation of game.
                        var fullPath = Path.Combine(MEDirectories.GetDefaultGamePath(sourceGame), c.TrimStart('\\', '/'));
                        //if (File.Exists(fullPath))
                        {
                            var sPackage = cache.GetCachedPackage(fullPath, openIfNotInCache: true);
                            if (sPackage != null)
                            {
                                var exp = sPackage.FindExport(mat.InstancedFullPath);
                                if (exp.IsA("Material"))
                                {
                                    // Copy over bUsedWith properties
                                    var props = exp.GetProperties();
                                    foreach (var p in props.Where(x => x is BoolProperty && x.Name.Name.StartsWith("bUsed")))
                                    {
                                        mat.WriteProperty(p);
                                    }
                                    writtenProps = true;
                                    break;
                                }
                            }
                            else
                            {
                                Debug.WriteLine($"Package not found: {fullPath}");
                            }
                        }
                    }
                }

                if (!writtenProps)
                {
                    //DecookerLog.Information($"Did not set bUsedWith properties on {mat.MemoryFullPath} - might not exist");
                }
            }
            usageFlagsTimer.Stop();
            if (package.Exports.Any(x => x.IsA("Material")))
            {
                DecookerLog.Information($"\tSynchronized material usage flags in {usageFlagsTimer.ElapsedMilliseconds:N0} ms");
            }

            return;

            MessageLog CompileFolder(IMEPackage _package, MEGame sourceGame, IReadOnlyList<ZipArchiveEntry> entries, IEntry parent)
            {
                bool filenameEncodesNesting = FilenameNestedGames.Contains(sourceGame);

                foreach (var entry in entries ?? Array.Empty<ZipArchiveEntry>())
                {
                    var rawName = Path.GetFileNameWithoutExtension(entry.FullName);
                    var matName = rawName;

                    // Package-relative dotted path (parents + leaf), when the filename encodes nesting.
                    string nestedPath = null;
                    if (filenameEncodesNesting)
                    {
                        var nameParts = rawName.Split('.');
                        if (nameParts.Length > 1)
                        {
                            matName = nameParts[^1];
                            nestedPath = rawName;
                        }
                    }

                    // Already in package? Nested materials must be checked by their full eventual path --
                    // this batch legitimately has different materials sharing a leaf name under different
                    // parents in the same package (e.g. two "CombinedEffect_Decoy", one under a stale
                    // "..._old" RvrEffectsMaterialUser and one under the live one), so a bare-name check
                    // would wrongly skip the second one as a duplicate of the first.
                    var alreadyCompiled = nestedPath != null
                        ? package.FindExport($"{_package.FileNameNoExtension}.{nestedPath}", "Material") != null
                        : _package.Exports.FirstOrDefault(x => x.ObjectName.Instanced == matName && x.IsA("Material")) != null;
                    if (alreadyCompiled)
                    {
                        continue;
                    }

                    // Pretty inefficient...
                    var source = new StreamReader(entry.Open(), Encoding.Default).ReadToEnd();
                    var sourceLines = source.SplitLines();
                    sourceLines = sourceLines.Where(x =>
                        !x.Trim().StartsWith("ReferencedTextureGuids") &&
                        !x.Trim().StartsWith("EditorComments") && // This will be important to keep later
                        true
                        ).ToArray();

                    DecookerLog.Information($"\tCompiling material {matName}");
                    activeMaterialPath = nestedPath != null
                        ? $"{package.FileNameNoExtension}.{nestedPath}"
                        : $"{package.FileNameNoExtension}.{matName}";
                    MessageLog log;
                    try
                    {
                        log = UnrealScriptCompiler.CompileT3D(string.Join('\n', sourceLines), package, parent, usop);
                    }
                    finally
                    {
                        activeMaterialPath = null;
                    }
                    if (log.HasLexErrors || log.HasErrors)
                    {
                        log.LogError($"Failed to compile {entry.FullName}");
                        return log;
                    }

                    if (nestedPath != null)
                    {
                        // New system: nesting comes straight from the T3D's own filename.
                        DecookerLog.Information($"\t\t-> Nesting material at {nestedPath}");
                        var obj = package.FindExport(matName);
                        MoveToNested(obj, $"{_package.FileNameNoExtension}.{nestedPath}");
                    }
                    // 04/18/2025 - check mat ifp db to see if it needs to be nested.
                    else if (!filenameEncodesNesting && matIfpDb.TryGetValue(_package.FileNameNoExtension, out var packageInfo) && packageInfo.TryGetValue(matName, out var matIfp))
                    {
                        // Old system - we must do parents.
                        DecookerLog.Information($"\t\t-> Nesting material at {matIfp}");
                        var obj = package.FindExport(matName);

                        // We nest under packagename as it doesn't make us deal with dupes of bringing in forced exports under their
                        // nested parent. We will convert to that anyways after this step finishes
                        MoveToNested(obj, $"{_package.FileNameNoExtension}.{matIfp}");
                    }
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
                if (classname != "Texture2D" && classname != "TextureCube")
                {
                    return null;
                }

                var lookupName = instancedfullpath;
                if (instancedfullpath.Contains("."))
                {
                    lookupName = instancedfullpath.Substring(instancedfullpath.LastIndexOf('.') + 1);
                }

                // The texture DB is keyed by bare object name, and several packages can own a texture
                // with the same name -- often the same art at a different compression. Whichever copy
                // that DB happens to hold then decides the pixel format, and format changes the
                // generated shader: a two channel normal map (BC5/V8U8) makes the material reconstruct
                // Z, a three channel one (DXT1/BC7) does not, so the bytecode stops matching what the
                // game shipped. Resolve the exact shipping binding for this material first. The
                // same-package preference remains a useful fallback for materials not present in the
                // shipping database, but EffectsMaterials is an assembly package: its CombinedEffect
                // materials commonly bind textures from their external base-material package instead.
                var shippingMatch = sourceGame == package.Game
                    ? TryResolveTextureFromShippingMaterial(activeMaterialPath, lookupName, classname, sourceGame, cache)
                    : null;
                var ownPackageMatch = shippingMatch == null
                    ? TryResolveTextureInOwnPackage(sourcepackage, lookupName, classname, sourceGame)
                    : null;
                var selectedMatch = shippingMatch ?? ownPackageMatch;
                var portedItem = selectedMatch != null
                    ? PortTextureFromLocation(package, sourcepackage, sourceGame, selectedMatch, classname, cache)
                    : null;

                portedItem ??= TryPortTexture(package, sourcepackage, sourceGame, lookupName, classname, TextureLookupDB, cache);
                if (portedItem == null && OppositeTextureLookupDB != null)
                {
                    var oppositeGame = sourceGame.ToOppositeGeneration();
                    portedItem = TryPortTexture(package, sourcepackage, oppositeGame, lookupName, classname, OppositeTextureLookupDB, cache);
                }

                if (portedItem == null)
                {
                    Debug.WriteLine($"Texture not found: {instancedfullpath}");
                }
                return portedItem;
            }
        }

        /// <summary>
        /// Tries to port a texture by name from the given db to the package object
        /// </summary>
        /// <param name="package"></param>
        /// <param name="sourcepackage"></param>
        /// <param name="lookupName"></param>
        /// <param name="db"></param>
        /// <returns></returns>
        private static IEntry TryPortTexture(IMEPackage package, IMEPackage sourcepackage, MEGame sourceGame, string lookupName, string classname, CaseInsensitiveDictionary<ObjectLocation> db, PackageCache cache)
        {
            if (db.TryGetValue(lookupName, out var info))
            {
                return PortTextureFromLocation(package, sourcepackage, sourceGame, info, classname, cache);
            }

            return null;
        }

        /// <summary>
        /// Resolves a bare T3D texture name through the shipping MaterialResource of the material
        /// currently being rebuilt. The source T3D does not retain a package-qualified texture IFP,
        /// whereas the cooked resource does. Only a unique leaf-name match is accepted; an absent or
        /// ambiguous binding deliberately falls back to the older package/name policies.
        /// </summary>
        private static ObjectLocation TryResolveTextureFromShippingMaterial(string materialPath, string lookupName,
            string classname, MEGame sourceGame, PackageCache cache)
        {
            if (string.IsNullOrWhiteSpace(materialPath) || DecookerShared.TargetObjectDB == null)
                return null;

            if (!ShippingTextureBindingsByMaterial.TryGetValue(materialPath, out var bindings))
            {
                bindings = new CaseInsensitiveDictionary<ObjectLocation>();
                var boundTextures = new Dictionary<string, HashSet<string>>(StringComparer.OrdinalIgnoreCase);
                var materialFiles = DecookerShared.TargetObjectDB.GetFilesContainingObject(materialPath);

                if (materialFiles != null)
                {
                    foreach (var relativePath in materialFiles)
                    {
                        try
                        {
                            var fullPath = Path.Combine(MEDirectories.GetDefaultGamePath(sourceGame), relativePath.TrimStart('\\', '/'));
                            var shippingPackage = cache.GetCachedPackage(fullPath, openIfNotInCache: true);
                            var shippingMaterial = shippingPackage?.FindExport(materialPath, "Material");
                            if (shippingMaterial == null)
                                continue;

                            var resource = ObjectBinary.From<Material>(shippingMaterial).SM3MaterialResource;
                            foreach (var textureUIndex in resource.UniformExpressionTextures)
                            {
                                var texture = shippingPackage.GetEntry(textureUIndex);
                                if (texture == null || !texture.ClassName.CaseInsensitiveEquals(classname))
                                    continue;

                                var texturePath = texture.InstancedFullPath;
                                var dot = texturePath.LastIndexOf('.');
                                var leaf = dot < 0 ? texturePath : texturePath[(dot + 1)..];
                                if (!boundTextures.TryGetValue(leaf, out var paths))
                                    boundTextures[leaf] = paths = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
                                paths.Add(texturePath);
                            }

                            // The first readable forced-export copy is sufficient: all copies are
                            // source-equivalent, while continuing across every level package would
                            // turn an otherwise small per-material lookup into a scan.
                            break;
                        }
                        catch
                        {
                            // Treat an unreadable cooked copy as absent and try the next one.
                        }
                    }
                }

                foreach (var (leaf, paths) in boundTextures)
                {
                    if (paths.Count != 1)
                        continue;

                    var texturePath = paths.Single();
                    var textureFiles = DecookerShared.TargetObjectDB.GetFilesContainingObject(texturePath);
                    if (textureFiles == null || textureFiles.Count == 0)
                        continue;

                    bindings[leaf] = new ObjectLocation
                    {
                        packagefile = textureFiles[0],
                        memoryfullpath = texturePath,
                        classname = classname
                    };
                }

                ShippingTextureBindingsByMaterial[materialPath] = bindings;
            }

            return bindings.TryGetValue(lookupName, out var binding) ? binding : null;
        }

        /// <summary>
        /// Finds a texture of the given object name that lives in the package currently being decooked,
        /// preferring it over any same-named texture elsewhere in the game. Returns null when this
        /// package owns no such object, which is the common case.
        /// </summary>
        private static ObjectLocation TryResolveTextureInOwnPackage(IMEPackage sourcepackage, string lookupName, string classname, MEGame sourceGame)
        {
            if (DecookerShared.TargetObjectDB == null)
                return null;

            if (ObjectPathsByName == null)
            {
                var map = new CaseInsensitiveDictionary<List<string>>();
                foreach (var objectPath in DecookerShared.TargetObjectDB.GetAllObjectPaths(false))
                {
                    var dotIndex = objectPath.LastIndexOf('.');
                    var leaf = dotIndex < 0 ? objectPath : objectPath.Substring(dotIndex + 1);
                    if (!map.TryGetValue(leaf, out var bucket))
                    {
                        map[leaf] = bucket = new List<string>();
                    }
                    bucket.Add(objectPath);
                }
                ObjectPathsByName = map;
            }

            if (!ObjectPathsByName.TryGetValue(lookupName, out var candidates))
                return null;

            var ownPackagePrefix = sourcepackage.FileNameNoExtension + ".";

            // Ordered so that an ambiguous name inside one package still resolves the same way on
            // every run; the DB build itself races, which is what made bad picks look arbitrary.
            foreach (var candidate in candidates
                         .Where(x => x.StartsWith(ownPackagePrefix, StringComparison.OrdinalIgnoreCase))
                         .OrderBy(x => x, StringComparer.OrdinalIgnoreCase))
            {
                // The name index covers every object, not just textures, so a Material can share a
                // name with the texture being resolved -- BioG_VfxMaterials has a material and a
                // texture both called RealFire_GroundFire_Wide. Without this check the material wins
                // and a texture reference is silently bound to a material.
                if (!CandidateIsClass(candidate, classname, sourceGame))
                    continue;

                var files = DecookerShared.TargetObjectDB.GetFilesContainingObject(candidate);
                if (files == null || files.Count == 0)
                    continue;

                return new ObjectLocation
                {
                    packagefile = files[0],
                    memoryfullpath = candidate,
                    classname = classname
                };
            }

            return null;
        }

        /// <summary>
        /// Whether an indexed object is actually of the wanted class.
        ///
        /// Uses the ObjectInstanceDB's class table when present. Databases serialized before
        /// version 3 have none, so this falls back to reading the class out of the package once per
        /// object and caching it -- correct with existing databases, just slower on first touch.
        /// </summary>
        private static bool CandidateIsClass(string candidate, string classname, MEGame sourceGame)
        {
            var known = DecookerShared.TargetObjectDB.GetClassName(candidate);
            if (known != null)
                return known.CaseInsensitiveEquals(classname);

            if (!CandidateClassCache.TryGetValue(candidate, out var cached))
            {
                cached = "";
                var files = DecookerShared.TargetObjectDB.GetFilesContainingObject(candidate);
                if (files != null && files.Count > 0)
                {
                    try
                    {
                        using var candidatePackage = DecookerShared.OpenPackage(files[0], sourceGame);
                        cached = candidatePackage.FindExport(candidate)?.ClassName ?? "";
                    }
                    catch
                    {
                        // Unreadable package; treat the class as unknown so the caller falls through
                        // to the by-name DB rather than binding something wrong.
                        cached = "";
                    }
                }
                CandidateClassCache[candidate] = cached;
            }

            return cached.CaseInsensitiveEquals(classname);
        }

        private static IEntry PortTextureFromLocation(IMEPackage package, IMEPackage sourcepackage, MEGame sourceGame, ObjectLocation info, string classname, PackageCache cache)
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
            // A material commonly references several textures from its own cooked package. Reusing
            // the compilation cache avoids reopening and reparsing that source package for each one.
            var sourcePath = Path.Combine(DecookerShared.GetCachedGameBackupPath(sourceGame), info.packagefile.TrimStart('\\', '/'));
            var sourcePackage = cache.GetCachedPackage(sourcePath);
            var sourceTex = sourcePackage.Exports.First(x => x.MemoryFullPath.CaseInsensitiveEquals(info.memoryfullpath) && x.ClassName.CaseInsensitiveEquals(classname));
            if (!sourceTex.IsDataLoaded())
            {
                Debugger.Break();
            }

            if (sourceTex.FileRef.FileNameNoExtension.StartsWith("BIOG_"))
            {
                // Fully load
                // sourcePackage = MEPackageHandler.OpenMEPackage(info.packagefile);
                sourceTex = sourcePackage.FindExport(sourceTex.InstancedFullPath);
            }

            RelinkerOptionsPackage rop = new RelinkerOptionsPackage()
            {
                // Cache?
                CustomRelinkUIndex = DecookerShared.ImportOutsideOfPackageRelink,
                CustomImportDependency = ImportDependencyOutsideOfPackage,
                AllowMemoryPathLookups = true,
            };

            if (!sourceTex.IsForcedExport)
            {
                // Move to forced export to reduce number of name collisions
                EntryExporter.PrepareGlobalFileForPorting(sourceTex.FileRef, sourceTex.FileRef.FileNameNoExtension);
            }


            EntryExporter.ExportExportToPackage(sourceTex, package, out var ported, customROP: rop);
            return ported;
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


            var backupPath = DecookerShared.GetCachedGameBackupPath(MEGame.LE3);
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

        public static void LayerGeneration(MEGame game)
        {

        }
    }
}
