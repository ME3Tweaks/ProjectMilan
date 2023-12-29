using System.Diagnostics;
using LegendaryExplorerCore.GameFilesystem;
using LegendaryExplorerCore.Gammtek.Extensions.Collections.Generic;
using LegendaryExplorerCore.Helpers;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Unreal;
using LegendaryExplorerCore.Unreal.ObjectInfo;
using LegendaryExplorerCore.UnrealScript;
using LegendaryExplorerCore.UnrealScript.Compiling.Errors;
using ProjectMilan.Pipelines.Kits;
using ProjectMilan.Utility;

namespace ProjectMilan.Pipelines.Weapons
{
    /// <summary>
    /// Pipeline for porting MP characters (kits)
    /// </summary>
    internal class SFXWeapons
    {
        private const string LOG_CATEGORY = "MILAN-Weapon";
        public static void RunPipeline()
        {
            var vars = new MPWeaponVars();
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

        private static void InternalRunPipeline(MPWeaponVars vars)
        {
            //DotTrace.EnsurePrerequisite();
            //DotTrace.Attach();
            // foreach (var kit in vars.KitPipelines)

            using TieredPackageCache parentCache = TieredPackageCache.GetGlobalPackageCache(MEGame.LE3).ChainNewCache();

            foreach (var v in commonlyOpenedPackages)
            {
                MELoadedFiles.GetFilesLoadedInGame(MEGame.LE3).TryGetValue(v, out var commonPackage);
                MilanLog.Information($"Caching commonly opened package: {commonPackage}", customPrefix: LOG_CATEGORY);
                parentCache.GetCachedPackage(commonPackage);
            }

            Parallel.ForEach(vars.WeaponPipelines.OrderBy(x => x.Enabled).AsParallel().AsOrdered(), new ParallelOptions() { MaxDegreeOfParallelism = 1 /* Program.Settings.MaxThreads*/ }, weapon =>
            {
                // Uncomment this to port everything
                if (/*false && */!weapon.Enabled)
                {
                    // This level is not marked for porting currently.
                    MilanLog.Information($"Skipping weapon {weapon.PackageName}, pipeline is not enabled", customPrefix: LOG_CATEGORY);
                    return;
                }

                BeginPorting(weapon, parentCache);
            });
            // }
        }

        private static object _weaponSyncObj = new object();

        private static void BeginPorting(WeaponSpecificPipeline weaponPipeline, TieredPackageCache parentCache)
        {
            weaponPipeline.LogCategory = $"{LOG_CATEGORY}-{weaponPipeline.PackageName}";

            // Initialize cache
            weaponPipeline.Cache = parentCache.ChainNewCache();
            weaponPipeline.Cache.InsertIntoCache(MilanShared.GetLE3GlobalPackages());

            var outputPath = Path.Combine(Program.Settings.OutputModPath, @"CookedPCConsole", @"DLCWeapons");
            Directory.CreateDirectory(outputPath);
            var finalPackagePath = Path.Combine(outputPath, weaponPipeline.PackageName + ".pcc");

            // Find modified source text.
            string file;
            lock (_weaponSyncObj) // Prevent multithread enumeration issues 
            {
                file = Directory.GetFiles(Path.Combine(MilanShared.PipelineRoot, "Weapons", "Modified"),
                    $"{weaponPipeline.WeaponClassName}.uc", SearchOption.AllDirectories).First();
            }

            var package = GetPackageName(file);
            var sourceclassText = File.ReadAllText(file);

            var looseClassPackages = new List<UnrealScriptCompiler.LooseClassPackage>();

            // Add main class
            UnrealScriptCompiler.LooseClassPackage lp = new UnrealScriptCompiler.LooseClassPackage(package,
                new List<UnrealScriptCompiler.LooseClass>()
                {
                    new UnrealScriptCompiler.LooseClass(weaponPipeline.WeaponClassName,sourceclassText)
                });
            looseClassPackages.Add(lp);

            var milanBase = Path.Combine(MilanShared.PipelineRoot, "Weapons", "Modified", package, Path.GetFileNameWithoutExtension(file));
            if (Directory.Exists(milanBase))
            {
                // Add custom other classes that we need to compile as well.
                var customClasses = Directory.GetFileSystemEntries(milanBase, "*.uc", SearchOption.AllDirectories);
                foreach (var cc in customClasses)
                {
                    AddClassToCompilation(looseClassPackages, GetPackageName(cc), new UnrealScriptCompiler.LooseClass(Path.GetFileNameWithoutExtension(cc), File.ReadAllText(cc)));
                }
            }

            if (weaponPipeline.LE3PackageName != null)
            {
                var le3SourcePackage = MilanShared.GetLE3Package($"{weaponPipeline.LE3PackageName}.pcc");
                weaponPipeline.BaseObjectPaths.ReplaceAll(le3SourcePackage.Exports
                    .Where(x => x.ClassName == "Package" && x.idxLink == 0)
                    .Select(x => x.InstancedFullPath));
            }

            var me3SourcePackage = MilanShared.GetME3Package($"{weaponPipeline.PackageName}.pcc");
            weaponPipeline.BaseObjectPaths.AddRange(me3SourcePackage.Exports.Where(x => x.ClassName == "Package" && x.idxLink == 0 && !weaponPipeline.BaseObjectPaths.Contains(x.InstancedFullPath))
                .Select(x => x.InstancedFullPath));
            while (!CompileWeapon(finalPackagePath, looseClassPackages, weaponPipeline))
            {

            }

            /*
            if (false)
            {
                MilanShared.PortObjectReferencer(kitSourcePackage, weaponDestPackage, weaponPipeline.Cache, weaponPipeline.LogCategory);
            }*/

            weaponPipeline.Cache.Dispose();
        }

        private static void AddClassToCompilation(List<UnrealScriptCompiler.LooseClassPackage> looseClassPackages, string packageName, UnrealScriptCompiler.LooseClass looseClass)
        {
            var classList = looseClassPackages.Find(x => x.PackageName == packageName);
            if (classList == null)
            {
                classList = new UnrealScriptCompiler.LooseClassPackage(packageName, new List<UnrealScriptCompiler.LooseClass>());
                looseClassPackages.Add(classList);
            }
            classList.Classes.Add(looseClass);
        }

        private static bool CompileWeapon(string finalPackagePath, List<UnrealScriptCompiler.LooseClassPackage> classes, WeaponSpecificPipeline pipeline)
        {
            //foreach (string ucFilePath in GetMPCommonClassFiles())
            //{
            //    var overridePath = MilanShared.GetClassOverride(Path.GetFileNameWithoutExtension(ucFilePath));
            //    string source = File.ReadAllText(overridePath ?? ucFilePath);
            //    //files must be named Classname.uc
            //    classes.Add(new UnrealScriptCompiler.LooseClass(Path.GetFileNameWithoutExtension(ucFilePath), source, ucFilePath)); // Always use ucFilePath as it will be in the proper package folder, even if it goes unused.
            //}

            var weaponDestPackage = MEPackageHandler.CreateAndOpenPackage(finalPackagePath, MEGame.LE3);
            weaponDestPackage.LECLTagData.ImportHintFiles.Add(MilanShared.MP_STARTUP_FILENAME); // Hint this for importing.
            weaponDestPackage.LECLTagData.IsPostLoadFile = false; // Do not allow using 

            UnrealScriptOptionsPackage usop = new UnrealScriptOptionsPackage()
            {
                Cache = pipeline.Cache,
                MissingObjectResolver = MilanShared.MissingObjectResolverExportsAsImports,
                GetVTableFromDonor = MilanShared.GetVTableFromDonor
            };
            // Different forced export packages



            MilanLog.Information(@"Compiling LE3 class package", customPrefix: LOG_CATEGORY);
            MessageLog log = UnrealScriptCompiler.CompileLooseClasses(weaponDestPackage, classes, usop);

            if (log.HasErrors)
            {
                if (AttemptToFindMissingClasses(log, pipeline, out var containingPackage, out var lClass))
                {
                    AddClassToCompilation(classes, containingPackage, lClass);
                    return false; // False - forces recomp
                }
                MilanLog.Error("COMPILATION OF CUSTOM CLASSES FAILED: ", customPrefix: LOG_CATEGORY);
                foreach (var error in log.AllErrors)
                {
                    MilanLog.Error($"  {error}", customPrefix: LOG_CATEGORY);
                }

                return false;
            }

            FileLib lib = null;
            foreach (var clsIFP in MilanShared.ClassesToDoubleRecompile)
            {
                var classX = weaponDestPackage.FindExport(clsIFP);
                if (classX == null)
                    continue;

                if (lib == null)
                {
                    lib = new FileLib(weaponDestPackage);
                    lib.Initialize(usop);
                }
                MilanLog.Information($"  Double recompiling {classX.ObjectName}", customPrefix: LOG_CATEGORY);
                (_, string text) = UnrealScriptCompiler.DecompileExport(classX, lib, usop);
                UnrealScriptCompiler.CompileClass(weaponDestPackage, text, lib, usop, classX);
            }

            MilanLog.Information(@"Loose class compilation succeeded!", customPrefix: LOG_CATEGORY);

            MilanLog.Information(@"Creating object referencer", customPrefix: LOG_CATEGORY);
            PackageTools.CreateObjectReferencer(weaponDestPackage, false);
            foreach (var classExp in weaponDestPackage.Exports.Where(x => x.IsClass))
            {
                // Yeah this is inefficient. 
                PackageTools.AddToObjectReferencer(classExp);
            }

            weaponDestPackage.Save();
            return true;
        }

        private static string GetPackageName(string sourceFilePath)
        {
            return Directory.GetParent(sourceFilePath).Name;
        }

        public static string DecompileClass(ExportEntry classExp, FileLib fileLib, PackageCache cache)
        {
            if (classExp.ObjectName == "DamageType")
                Debug.WriteLine("");
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
                    fileLib.Initialize(usop);
                }
                catch
                {
                    //we're not checking if it failed to initialize because we don't really care, since decompilation doesn't actually need an initialized filelib,
                    //it just makes the output a bit nicer (at the time of this writing all it does is resolve some integer literals into enum values)
                }
            }

            (_, string functionText) = UnrealScriptCompiler.DecompileExport(classExp, fileLib, usop);

            return functionText;
            // FUNCTION PATCHES
            //List<string> newFunction = PatchFunction(classExp.ObjectName, functionText);

            // Insert metadata about autogen
            //newFunction.Insert(0, $"// Source: {classExp.FileRef.Game}, {classExp.FileRef.FileNameNoExtension}");
            //newFunction.Insert(1, $"// Decompiled {DateTime.Now}");

            //File.WriteAllLines(ucOutPath, newFunction);
        }

        private static bool AttemptToFindMissingClasses(MessageLog log, WeaponSpecificPipeline pipeline, out string containingPackage, out UnrealScriptCompiler.LooseClass lClass)
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
    }



    internal class MPWeaponVars
    {
        public readonly List<WeaponSpecificPipeline> WeaponPipelines = new()
        {
            // MP1
            new WeaponSpecificPipeline()
            {
                // Kishock Harpoon Gun
                WeaponClassName = "SFXWeapon_SniperRifle_Batarian",
                PackageName = "SFXWeapon_SniperRifle_BatarianDLC",
                LE3PackageName = "SFXWeapon_SniperRifle_Batarian_GUN02",
                Enabled  = true
            },
            new WeaponSpecificPipeline()
            { 
                // Geth Plasma SMG
                WeaponClassName = "SFXWeapon_SMG_Geth",
                PackageName = "SFXWeapon_SMG_GethDLC",
                LE3PackageName = "SFXWeapon_SMG_Geth_GUN01",
                Enabled  = true
            },
            new WeaponSpecificPipeline()
            { 
                // Striker Assault Rifle
                WeaponClassName = "SFXWeapon_AssaultRifle_Krogan",
                PackageName = "SFXWeapon_AssaultRifles_KroganDLC",
                LE3PackageName = "SFXWeapon_AssaultRifle_Krogan_GUN02",
                Enabled  = true
            },

            // MP2
            new WeaponSpecificPipeline()
            { 
                // Cerberus Harrier Assault Rifle
                WeaponClassName = "SFXWeapon_AssaultRifle_Cerberus",
                PackageName = "SFXWeapon_AssaultRifle_CerberusDLC",
                LE3PackageName = "SFXWeapon_AssaultRifle_Cerb_GUN01",
                Enabled  = true
            },
            new WeaponSpecificPipeline()
            { 
                // Prothean Particle Rifle
                WeaponClassName = "SFXWeapon_AssaultRifle_Prothean_MP",
                PackageName = "SFXWeapon_AssaultRifle_ProtheanDLC",
                LE3PackageName = "SFXWeapon_AssaultRifles_DLC1",
                Enabled  = true
            },
            new WeaponSpecificPipeline()
            { 
                // Reegar Carbine Shotgun
                WeaponClassName = "SFXWeapon_Shotgun_Quarian",
                PackageName = "SFXWeapon_Shotgun_QuarianDLC",
                LE3PackageName = "SFXWeapon_Shotgun_Quarian_GUN01",
                Enabled  = true
            },
            new WeaponSpecificPipeline()
            { 
                // Krysae Sniper Rifle
                WeaponClassName = "SFXWeapon_SniperRifle_Turian",
                PackageName = "SFXWeapon_SniperRifle_TurianDLC",
                LE3PackageName = "SFXWeapon_SniperRifle_Turian_GUN01",
                Enabled  = true
            },

            // MP3
            new WeaponSpecificPipeline()
            { 
                // N7 Typhoon
                WeaponClassName = "SFXWeapon_AssaultRifle_LMG",
                PackageName = "SFXWeapon_AssaultRifle_LMGDLC",
                LE3PackageName = "SFXWeapon_AssaultRifle_LMG_GUN02",
                Enabled  = true
            },
            new WeaponSpecificPipeline()
            { 
                // Acolyte Pistol
                WeaponClassName = "SFXWeapon_Pistol_Asari",
                PackageName = "SFXWeapon_Pistol_AsariDLC",
                LE3PackageName = "SFXWeapon_Pistol_Asari_GUN02",
                Enabled  = true
            },
            new WeaponSpecificPipeline()
            { 
                // N7 Piranha
                WeaponClassName = "SFXWeapon_Shotgun_Assault",
                PackageName = "SFXWeapon_Shotgun_AssaultDLC",
                LE3PackageName = "SFXWeapon_Shotgun_Assault_GUN02",
                Enabled  = true
            },

            // MP4
            new WeaponSpecificPipeline()
            {
                // Collector SMG
                WeaponClassName = "SFXWeapon_SMG_Collector",
                PackageName = "SFXWeapon_SMG_Collector",
                LE3PackageName = "BioD_CitSim_CllctrB", // There is no direct LE3 version of this package. It uses a _Shared version
                Enabled  = true
            },
            new WeaponSpecificPipeline()
            {
                // Collector Sniper Rifle
                WeaponClassName = "SFXWeapon_SniperRifle_Collector",
                PackageName = "SFXWeapon_SniperRifle_Collector",
                LE3PackageName = null, // There is no LE3 version of this package.
                Enabled  = true
            },

            // MP5
            new WeaponSpecificPipeline()
            {
                // Adas Assault Rifle
                WeaponClassName = "SFXWeapon_AssaultRifle_Adas_MP",
                PackageName = "SFXWeapon_AssaultRifle_Adas_MP",
                LE3PackageName = "SFXWeapon_AssaultRifle_Quarian",
                Enabled  = true
            },
            new WeaponSpecificPipeline()
            {
                // M-7 Lancer
                WeaponClassName = "SFXWeapon_AssaultRifle_Lancer_MP",
                PackageName = "SFXWeapon_AssaultRifle_Lancer_MP",
                LE3PackageName = "SFXWeapon_AssaultRifle_Lancer",
                Enabled  = true
            },
            new WeaponSpecificPipeline()
            {
                // Geth Spitfire
                WeaponClassName = "SFXWeapon_AssaultRifle_Spitfire",
                PackageName = "SFXWeapon_AssaultRifle_Spitfire",
                LE3PackageName = "SFXWeapon_AssaultRifle_Spitfire", // There is no direct LE3 version of this package. It is a heavy weapon version. Looks like maybe it was going to be a normal weapon though
                Enabled  = true
            },
            new WeaponSpecificPipeline()
            {
                // Bloodpack Executioner
                WeaponClassName = "SFXWeapon_Pistol_Bloodpack_MP",
                PackageName = "SFXWeapon_Pistol_Bloodpack_MP",
                LE3PackageName = "SFXWeapon_Pistol_Bloodpack",
                Enabled  = true
            },
            new WeaponSpecificPipeline()
            {
                // Silencer Pistol
                WeaponClassName = "SFXWeapon_Pistol_Silencer_MP",
                PackageName = "SFXWeapon_Pistol_Silencer_MP",
                LE3PackageName = "SFXWeapon_Pistol_Silencer",
                Enabled  = true
            },
            new WeaponSpecificPipeline()
            {
                // Venom Shotgun
                WeaponClassName = "SFXWeapon_Shotgun_Salarian_MP",
                PackageName = "SFXWeapon_Shotgun_Salarian_MP",
                LE3PackageName = "SFXWeapon_Shotgun_Salarian",
                Enabled  = true
            },
            new WeaponSpecificPipeline()
            {
                // Bloodpack Punisher
                WeaponClassName = "SFXWeapon_SMG_Bloodpack_MP",
                PackageName = "SFXWeapon_SMG_Bloodpack_MP",
                LE3PackageName = "SFXWeapon_SMG_Bloodpack",
                Enabled  = true
            },
        };
    }
}
