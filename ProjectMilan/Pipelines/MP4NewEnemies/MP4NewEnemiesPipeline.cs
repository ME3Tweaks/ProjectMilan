using System.Diagnostics;
using LegendaryExplorerCore.GameFilesystem;
using LegendaryExplorerCore.Gammtek.Extensions.Collections.Generic;
using LegendaryExplorerCore.Helpers;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Unreal;
using LegendaryExplorerCore.Unreal.ObjectInfo;
using LegendaryExplorerCore.UnrealScript;
using LegendaryExplorerCore.UnrealScript.Compiling.Errors;
using ProjectMilan.Pipelines.MP4NewEnemies;
using ProjectMilan.Pipelines.Startups;
using ProjectMilan.Utility;
using ProjectMilanCore;

namespace ProjectMilan.Pipelines.Weapons
{
    /// <summary>
    /// Pipeline for porting the new enemies from MP4 (Collectors, Dragoon, Geth Bomber)
    /// </summary>
    internal class MP4NewEnemiesPipeline
    {
        private const string LOG_CATEGORY = "MILAN-MP4Enemies";
        public static void RunPipeline()
        {
            var vars = new MP4EnemyPipelineVars();
            InternalRunPipeline(vars);
        }

        // These packages seem to be opened a lot
        // This list will be cached in an intermediate tiered cache
        // Don't put too many in here
        private static string[] commonlyOpenedPackages = new string[]
        {
            //"BioP_ProEar.pcc",
            //"BioD_ProEar.pcc",
            //"BioD_MPCer_100SP.pcc",
            //"BioP_Gth002.pcc",
            //"BioD_Gth002.pcc"
        };

        private static void InternalRunPipeline(MP4EnemyPipelineVars vars)
        {
            //DotTrace.EnsurePrerequisite();
            //DotTrace.Attach();
            // foreach (var kit in vars.KitPipelines)

            using TieredPackageCache parentCache = MilanShared.GetMPCommonTieredPackageCache().ChainNewCache();

            foreach (var v in commonlyOpenedPackages)
            {
                MELoadedFiles.GetFilesLoadedInGame(MEGame.LE3).TryGetValue(v, out var commonPackage);
                MilanLog.Information($"Caching commonly opened package: {commonPackage}", customPrefix: LOG_CATEGORY);
                parentCache.GetCachedPackage(commonPackage);
            }

            Parallel.ForEach(vars.EnemyPipelines.OrderBy(x => x.Enabled).AsParallel().AsOrdered(), new ParallelOptions() { MaxDegreeOfParallelism = 1 /* Program.Settings.MaxThreads*/ }, enemy =>
            {
                // Uncomment this to port everything
                if (/*false && */!enemy.Enabled)
                {
                    // This level is not marked for porting currently.
                    MilanLog.Information($"Skipping enemy {enemy.PackageName}, pipeline is not enabled", customPrefix: LOG_CATEGORY);
                    return;
                }

                BeginPorting(enemy, parentCache);
            });
            // }
        }

        private static object _weaponSyncObj = new object();

        private static void BeginPorting(MP4EnemySpecificPipeline enemyPipeline, TieredPackageCache parentCache)
        {
            enemyPipeline.LogCategory = $"{LOG_CATEGORY}-{enemyPipeline.PackageName}";
            MilanLog.Information($"Porting MP4Enemy {enemyPipeline.PackageName}", customPrefix: enemyPipeline.LogCategory);
            // Initialize cache
            enemyPipeline.Cache = parentCache.ChainNewCache();
            enemyPipeline.Cache.InsertIntoCache(MilanShared.GetLE3GlobalPackages());

            var outputPath = Path.Combine(Program.Settings.OutputModPath, @"CookedPCConsole", @"MP4Enemies");
            Directory.CreateDirectory(outputPath);
            var finalPackagePath = Path.Combine(outputPath, enemyPipeline.PackageName + ".pcc");

            var enemyPackage = MEPackageHandler.CreateAndOpenPackage(finalPackagePath, MEGame.LE3);
            enemyPackage.LECLTagData.ImportHintFiles.Add(MilanShared.MP_STARTUP_FILENAME); // Hint this for importing.
            enemyPackage.LECLTagData.IsPostLoadFile = false; // Do not allow using 

            UnrealScriptOptionsPackage usop = new UnrealScriptOptionsPackage()
            {
                Cache = enemyPipeline.Cache,
                MissingObjectResolver = MilanShared.MissingObjectResolverExportsAsImports,
                GetVTableFromDonor = MilanShared.GetVTableFromDonor
            };

            // Different forced export packages
            var otFile = MilanShared.GetME3Package($"{enemyPipeline.PackageName}.pcc");
            MilanShared.PortObjectReferencer(otFile, enemyPackage, enemyPipeline.Cache, enemyPipeline.LogCategory);
            enemyPackage.Save();


            return;


            // Find modified source text.
            string file;
            lock (_weaponSyncObj) // Prevent multithread enumeration issues 
            {
                file = Directory.GetFiles(Path.Combine(MilanShared.PipelineRoot, "MP4NewEnemies", "Modified"),
                    $"{enemyPipeline.EnemyClassName}.uc", SearchOption.AllDirectories).FirstOrDefault();
            }

            FileLib fl = new FileLib(otFile);
            fl.Initialize(new UnrealScriptOptionsPackage() { Cache = enemyPipeline.Cache, CustomFileResolver = MilanShared.ME3PackageResolver }); // Use ME3 resolver as this is from ME3


            string package = "SFXGameContentDLC_CON_MP4";
            string sourceClassText = null;
            if (file == null)
            {
                // Decompile from ME3. We don't have changed stuff in the base class
                var sourceClass = otFile.Exports.First(x => x.IsClass && x.ObjectName == enemyPipeline.EnemyClassName);
                sourceClassText = DecompileClass(sourceClass, fl, enemyPipeline.Cache);
            }
            else
            {
                // Use modified source
                sourceClassText = File.ReadAllText(file);
            }

            var looseClassPackages = new List<UnrealScriptCompiler.LooseClassPackage>();

            // Add main class and supporting classes
            var classes = new List<UnrealScriptCompiler.LooseClass>();
            classes.Add(new UnrealScriptCompiler.LooseClass(enemyPipeline.EnemyClassName, sourceClassText));
            if (enemyPipeline.ExtraLinkedInClasses != null)
            {
                // This needs changed if there are other custom class locations
                var weapons = Directory.GetFileSystemEntries(Path.Combine(MilanShared.PipelineRoot, "Weapons"), "*.uc", SearchOption.AllDirectories);
                foreach (var extraClassName in enemyPipeline.ExtraLinkedInClasses)
                {
                    var weaponFName = weapons.First(x => Path.GetFileNameWithoutExtension(x) == extraClassName);
                    classes.Add(new UnrealScriptCompiler.LooseClass(extraClassName, File.ReadAllText(weaponFName)));
                }
            }
            UnrealScriptCompiler.LooseClassPackage lp = new UnrealScriptCompiler.LooseClassPackage(package, classes);
            looseClassPackages.Add(lp);

            // Speeds up compilation by taking stuff from original file instead of having to open a ton of packages.
            foreach (var extraClassName in otFile.Exports.Where(x => x.IsClass))
            {
                var lc = new UnrealScriptCompiler.LooseClass(extraClassName.ObjectName, DecompileClass(extraClassName, fl, enemyPipeline.Cache));
                AddClassToCompilation(looseClassPackages, extraClassName.ParentName, lc);
            }

            //var milanBase = Path.Combine(MilanShared.PipelineRoot, "Weapons", "Modified", package, Path.GetFileNameWithoutExtension(file));
            //if (Directory.Exists(milanBase))
            //{
            //    // Add custom other classes that we need to compile as well.
            //    var customClasses = Directory.GetFileSystemEntries(milanBase, "*.uc", SearchOption.AllDirectories);
            //    foreach (var cc in customClasses)
            //    {
            //        AddClassToCompilation(looseClassPackages, GetPackageName(cc), new UnrealScriptCompiler.LooseClass(Path.GetFileNameWithoutExtension(cc), File.ReadAllText(cc)));
            //    }
            //}

            if (enemyPipeline.LE3PackageName != null)
            {
                var le3SourcePackage = MilanShared.GetLE3Package($"{enemyPipeline.LE3PackageName}.pcc");
                enemyPipeline.BaseObjectPaths.ReplaceAll(le3SourcePackage.Exports
                    .Where(x => x.ClassName == "Package" && x.idxLink == 0)
                    .Select(x => x.InstancedFullPath));
            }

            var me3SourcePackage = MilanShared.GetME3Package($"{enemyPipeline.PackageName}.pcc");
            enemyPipeline.BaseObjectPaths.AddRange(me3SourcePackage.Exports.Where(x => x.ClassName == "Package" && x.idxLink == 0 && !enemyPipeline.BaseObjectPaths.Contains(x.InstancedFullPath)).Select(x => x.InstancedFullPath));
            while (!CompileEnemy(finalPackagePath, looseClassPackages, enemyPipeline))
            {

            }

            /*
            if (false)
            {
                MilanShared.PortObjectReferencer(kitSourcePackage, weaponDestPackage, enemyPipeline.Cache, enemyPipeline.LogCategory);
            }*/

            enemyPipeline.Cache.Dispose();
        }

        private static void AddClassToCompilation(List<UnrealScriptCompiler.LooseClassPackage> looseClassPackages, string packageName, UnrealScriptCompiler.LooseClass looseClass)
        {
            var classList = looseClassPackages.Find(x => x.PackageName == packageName);
            if (classList == null)
            {
                classList = new UnrealScriptCompiler.LooseClassPackage(packageName, new List<UnrealScriptCompiler.LooseClass>());
                looseClassPackages.Add(classList);
            }

            // only add if none are already here for compilation.
            if (!classList.Classes.Any(x => x.ClassName.CaseInsensitiveEquals(looseClass.ClassName)))
            {
                classList.Classes.Add(looseClass);
            }
        }

        private static bool CompileEnemy(string finalPackagePath, List<UnrealScriptCompiler.LooseClassPackage> classes, MP4EnemySpecificPipeline pipeline)
        {
            var enemyPackage = MEPackageHandler.CreateAndOpenPackage(finalPackagePath, MEGame.LE3);
            enemyPackage.LECLTagData.ImportHintFiles.Add(MilanShared.MP_STARTUP_FILENAME); // Hint this for importing.
            enemyPackage.LECLTagData.IsPostLoadFile = false; // Do not allow using 

            UnrealScriptOptionsPackage usop = new UnrealScriptOptionsPackage()
            {
                Cache = pipeline.Cache,
                MissingObjectResolver = MilanShared.MissingObjectResolverExportsAsImports,
                GetVTableFromDonor = MilanShared.GetVTableFromDonor
            };

            // Different forced export packages
            var otFile = MilanShared.GetME3Package($"{pipeline.PackageName}.pcc");
            MilanShared.PortObjectReferencer(otFile, enemyPackage, pipeline.Cache, pipeline.LogCategory);
            enemyPackage.Save();
            return true;
        }

        private static string GetPackageName(string sourceFilePath)
        {
            return Directory.GetParent(sourceFilePath).Name;
        }

        public static string DecompileClass(ExportEntry classExp, FileLib fileLib, PackageCache cache)
        {
            var usingTestPatch = false;
            if (classExp.Game == MEGame.ME3)
            {
                // We must first see if this is in testpatch!!
                var testPatchClass = MilanShared.GetTestPatchClass(classExp);
                if (testPatchClass != null)
                {
                    usingTestPatch = true;
                    classExp = testPatchClass;
                    fileLib = null; // Must re-init
                }
            }


            //var baseOutputPath = toShared ? MilanShared.GetAutoDonorClassesPath() : GetMPClassesFolder();
            //var packageOutputPath = Path.Combine(baseOutputPath, classExp.HasParent ? classExp.ParentName : classExp.FileRef.FileNameNoExtension);
            //Directory.CreateDirectory(packageOutputPath);
            //var ucOutPath = Path.Combine(packageOutputPath, $"{classExp.ObjectName}.uc");

            // Check if override exists
            //var overridePath = MilanShared.GetClassOverride(classExp.ObjectName);
            //if (overridePath != null)
            //{
            //    MilanLog.Information($"Using Milan class override for {classExp.ObjectName}", customPrefix: LOG_CATEGORY);
            //    File.Copy(overridePath, ucOutPath, true);
            //    return;
            //}

            MilanLog.Information($"Decompiling {classExp.FileRef.Game} {classExp.InstancedFullPath}", customPrefix: LOG_CATEGORY);
            if (usingTestPatch)
            {
                MilanLog.Information($@"  Using DLC_TestPatch version of {classExp.InstancedFullPath}", customPrefix: LOG_CATEGORY);
            }
            UnrealScriptOptionsPackage usop = new UnrealScriptOptionsPackage()
            {
                Cache = cache,
                CustomFileResolver = MilanShared.ME3PackageResolver,
            };

            if (fileLib == null)
            {
                // Initialize filelib if it wasn't.
                try
                {

                    fileLib = new FileLib(classExp.FileRef);
                    if (!fileLib.Initialize(usop))
                    {
                        MilanShared.LogFailedFileLibInit(fileLib);
                    }
                }
                catch
                {
                    //we're not checking if it failed to initialize because we don't really care, since decompilation doesn't actually need an initialized filelib,
                    //it just makes the output a bit nicer (at the time of this writing all it does is resolve some integer literals into enum values)
                }
            }

            (_, string functionText) = UnrealScriptCompiler.DecompileExport(classExp, fileLib, usop);

            // FUNCTION PATCHES
            List<string> newFunction = MPCommon.PatchFunction(classExp.ObjectName, functionText);

            // Insert metadata about autogen
            //newFunction.Insert(0, $"// Source: {classExp.FileRef.Game}, {classExp.FileRef.FileNameNoExtension}");
            //newFunction.Insert(1, $"// Initial decompilation: {DateTime.Now}");
            return string.Join('\n', newFunction);
            //File.WriteAllLines(ucOutPath, newFunction);
        }

        private static bool AttemptToFindMissingClasses(MessageLog log, MP4EnemySpecificPipeline pipeline, out string containingPackage, out UnrealScriptCompiler.LooseClass lClass)
        {
            lClass = null;
            containingPackage = null;

            List<string> decompiledClasses = new List<string>();

            // Code: Find class
            foreach (var m in log.AllErrors)
            {

                string className = null;

                // Pull missing class name out of error message
                if (m.Message.StartsWith("No class named '"))
                {
                    className = m.Message.Substring(16);
                }
                else if (m.Message.Contains("Unable to resolve class '"))
                {
                    className = m.Message.Substring(m.Message.IndexOf("Unable to resolve class '") + "Unable to resolve class '".Length);
                }
                else if (m.Message.StartsWith("The type '") && m.Message.Contains("' does not exist in the current scope"))
                {
                    className = m.Message.Substring("The type '".Length);
                }
                else if (m.Message.StartsWith("No type named '") && m.Message.Contains("' exists!"))
                {
                    className = m.Message.Substring("No type named '".Length);
                }
                else if (m.Message.Contains(" has no member named '"))
                {
                    if (m.Message.Contains("SFXWeapon_AssaultRifle_SentryTurret") ||
                        false

                        )
                    {
                        className = m.Message.Substring(m.Message.IndexOf(" has no member named '") + " has no member named '".Length);
                    }
                    else
                    {
                        continue; // Something else...
                    }
                }
                else
                {
                    // It's something else...
                    continue;
                }

                className = className.Substring(0, className.IndexOf('\''));

                if (decompiledClasses.Contains(className))
                    continue; // Already pending recompile

                foreach (var cbp in pipeline.BaseObjectPaths)
                {
                    string ifp;
                    if (cbp == null)
                    {
                        ifp = className;
                    }
                    else
                    {
                        ifp = $"{cbp}.{className}";
                    }

                    // Look in LE3 for donor
                    bool keepSearching = true;
                    var foundObjs = MilanShared.LE3ObjectDB.GetFilesContainingObject(ifp);
                    if (foundObjs != null)
                    {
                        foreach (var foundObj in foundObjs)
                        {
                            if (!keepSearching)
                                break;
                            var sourceFileName = Path.GetFileName(foundObj);
                            var package = MilanShared.GetLE3Package(sourceFileName);

                            // DLC system Milan uses doesn't look in SP files
                            // So if obj database has SP stuff this will fail
                            // Just keep going.
                            if (package != null)
                            {
                                MilanLog.Information($@"Found missing class '{className}' in LE3: {foundObj}", customPrefix: LOG_CATEGORY);
                                var export = package.FindExport(ifp);
                                if (export != null)
                                {
                                    var decomp = DecompileClass(export, null, pipeline.Cache);
                                    containingPackage = export.ParentName;
                                    lClass = new UnrealScriptCompiler.LooseClass(export.ObjectName, decomp, sourceFileName);
                                    keepSearching = false;
                                    continue;
                                }

                                MilanLog.Warning($"Export did not reside in package, perhaps the wrong one was found? Could be overridden by DLC", customPrefix: LOG_CATEGORY);

                            }
                        }
                    }

                    // Looking ME3 for crossgen
                    if (!keepSearching)
                        continue; // Go to next error
                    foundObjs = MilanShared.ME3ObjectDB.GetFilesContainingObject(ifp);
                    if (foundObjs != null)
                    {
                        foreach (var foundObj in foundObjs)
                        {
                            if (!keepSearching)
                                break;
                            var sourceFileName = Path.GetFileName(foundObj);
                            var package = MilanShared.GetME3Package(sourceFileName);

                            // DLC system Milan uses doesn't look in SP files
                            // So if obj database has SP stuff this will fail
                            // Just keep going.
                            if (package != null)
                            {
                                MilanLog.Information($@"Found missing class '{className}' in ME3: {foundObj}", customPrefix: LOG_CATEGORY);
                                var export = package.FindExport(ifp);
                                if (export != null)
                                {
                                    var decomp = DecompileClass(export, null, pipeline.Cache);
                                    containingPackage = export.ParentName;
                                    lClass = new UnrealScriptCompiler.LooseClass(export.ObjectName, decomp, sourceFileName);
                                    keepSearching = false;
                                    continue;
                                }

                                MilanLog.Warning($"Export did not reside in package, perhaps the wrong one was found? Could be overridden by DLC", customPrefix: LOG_CATEGORY);
                            }
                        }
                    }

                }
            }

            return lClass != null;
        }


        // Used to find weapons
        public static void BuildKitPipelineCode()
        {
            MilanShared.LoadME3DLCTOCs();
            var kits = new List<string>();
            foreach (var f in MilanShared.ME3DLCFileMap)
            {
                if (f.Key.StartsWith("Bio") || !f.Key.RepresentsPackageFilePath())
                    continue;

                MilanLog.Information($"Loading {f.Key}");
                var package = MilanShared.GetME3Package(f.Key);
                var references = package.Exports.Where(x => x.ClassName == "ObjectReferencer");
                foreach (var reference in references)
                {
                    var objRefs = reference.GetProperty<ArrayProperty<ObjectProperty>>("ReferencedObjects");
                    if (objRefs != null)
                    {
                        foreach (var objRef in objRefs)
                        {
                            if (package.TryGetUExport(objRef.Value, out var exp))
                            {
                                if (exp.IsA("SFXPawn_PlayerMP"))
                                {
                                    // Got one
                                    kits.Add($"new KitSpecificPipeline() {{ PackageName = \"{package.FileNameNoExtension}\", Enabled = true}},");
                                }
                            }
                        }
                    }
                }
            }

            foreach (var kit in kits)
            {
                Debug.WriteLine(kit);
            }
        }

        public static void PreCorrect_CollectorTrooperPackage(IMEPackage package, PackageCache cache)
        {
            // Patch telemetry out of SFXPawn_Collector_SMG
            FileLib fl = new FileLib(package);
            fl.Initialize(new UnrealScriptOptionsPackage() { Cache = cache, CustomFileResolver = MilanShared.ME3PackageResolver }); // Use ME3 resolver as this is from ME3

            //var sourceClass = package.Exports.First(x => x.IsClass && x.ObjectName == enemyPipeline.EnemyClassName);


            //sourceClassText = DecompileClass(sourceClass, fl, enemyPipeline.Cache);
        }
    }



    internal class MP4EnemyPipelineVars
    {
        public readonly List<MP4EnemySpecificPipeline> EnemyPipelines = new()
        {
            // Note: Only enemies that require changes are ported in this pipeline.
            // Enemies that can directly transfer use NonStartup

            // Collector Trooper
            new MP4EnemySpecificPipeline()
            {
                // Kishock Harpoon Gun
                EnemyClassName = "SFXPawn_CollectorTrooper",
                PackageName = "SFXPawn_CollectorTrooper",
                LE3PackageName = "BioD_CitSim_CllctrB",
                ExtraLinkedInClasses = new []
                {
                    "SFXWeapon_SMG_Collector" // Fixes compilation due to telemetry call
                },
                Enabled  = true
            },
        };
    }
}
