using CsvHelper;
using LegendaryExplorerCore.GameFilesystem;
using LegendaryExplorerCore.Helpers;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.UnrealScript;
using LegendaryExplorerCore.UnrealScript.Compiling.Errors;
using ME3TweaksModManager.modmanager.objects.mod.merge;
using ME3TweaksModManager.modmanager.objects.mod.merge.v1;
using Newtonsoft.Json;
using ProjectMilan.Utility;
using ProjectMilanCore;
using System.Diagnostics;

namespace ProjectMilan.Pipelines.Startups
{
    /// <summary>
    /// Pass-throughable settings for MPCommon pipeline
    /// </summary>
    class MPCommonPipelineVars
    {
        public string OutputPath { get; set; }


        // Not used
        /// <summary>
        /// Package file being compiled
        /// </summary>
        //public IMEPackage BuildingPackage { get; set; }
    }

    /// <summary>
    /// Pipeline that converts the 'BIOP_MP_COMMON' package from ME3 to LE3.
    /// </summary>
    internal class MPCommon
    {
        private const string LOG_CATEGORY = @"MILAN-MPCommon";

        // Some notes about MPCommon from ME3.
        // 1. This package is overriden via config files for every MP DLC. They always repoint to MPLobby.pcc which exists in every DLC.
        // 2. Some classes in this are overriden by DLC_TestPatch. We must use those classes instead as they will be patched. 
        // 3. A few of these changes were for native code. We will need to analyze how they changed and make adjustments as necessary.
        // 4. For all ported package exports, we should strive to keep the original GUID on the package. If we 
        //         ever make it to actual MP - e.g. replication - this will be vital as that's how Unreal sends package info
        //         across the network. And it's horrible, nearly impossible to debug. Top level packages must use the same GUID
        //         as OT.

        // Additional notes:
        // MP1, MP2, MP3 did not add much - MP2 added gear.
        // MP4 added challenges which changes a bunch of UIs. Collectors added a new UI that is not present in LE that replaces the cooldown timer
        //         Even in OT Citadel, they didn't properly port this UI so it doesn't properly show the bee swarm.
        // MP5 is a superset of MP4 but doesn't seem to activate the new features if MP4 is not installed... I think.
        // There are some startup files for each MP DLC. They probably will need loaded.

        /// <summary>
        /// Global lookup for LE3
        /// </summary>
        public static MilanPackageCache LE3GlobalCache { get; set; }

        /// <summary>
        /// Global lookup for ME3
        /// </summary>
        public static MilanPackageCache ME3GlobalCache { get; set; }

        public static void RunPipeline()
        {
            // Setup pipeline
            ME3GlobalCache = new MilanPackageCache();
            LE3GlobalCache = new MilanPackageCache();
            MPCommonPipelineVars vars = new MPCommonPipelineVars()
            {
                // This used to be different
                OutputPath = Program.Settings.OutputModPath
            };

            InternalRunPipeline(vars);

            ME3GlobalCache.Dispose();
            LE3GlobalCache.Dispose();

            ME3GlobalCache = null;
            LE3GlobalCache = null;
        }



        private static void InternalRunPipeline(MPCommonPipelineVars vars)
        {
            // Actually run pipeline
            Directory.CreateDirectory(vars.OutputPath);

            if (!CompileMPCommon(vars))
            {
                MilanLog.Fatal($"Failed to compile {MilanShared.MP_STARTUP_NAME}", customPrefix: LOG_CATEGORY);
                Environment.Exit(1);
            }

            BuildMergeMods();
        }

        private static void BuildMergeMods()
        {
            var compilingPath = Path.Combine(MilanShared.PipelineRoot, "Startups", "MPCommon", "MergeMod");
            var stagingPath = Path.Combine(compilingPath, "Staging");
            List<string> mergeModNames = new List<string>();
            Utilities.DeleteFilesAndFoldersRecursively(stagingPath, deleteDirectoryItself: false);
            CopyAssetUpdateMergeMods(compilingPath, stagingPath);

            var mergeModsPath = Path.Combine(Directory.GetParent(Program.Settings.OutputModPath).FullName, "MergeMods");
            Directory.CreateDirectory(mergeModsPath);
            
            BuildMPMergeMod(compilingPath, stagingPath, mergeModsPath);
            
            foreach (var manifest in Directory.GetFiles(stagingPath, "*.json", SearchOption.TopDirectoryOnly))
            {
                var name = Path.GetFileName(manifest);
                if (manifest == "mprequiredchanges.json") {
                    continue;
                }
                MilanLog.Information($"Adding AssetUpdate merge mod: {name}", customPrefix: LOG_CATEGORY);
                var m3mName = $@"{Path.GetFileNameWithoutExtension(name)}.m3m";
                var m3mPath = Path.Combine(mergeModsPath, m3mName);
                var json = File.ReadAllText(manifest);
                using var fs = File.Open(m3mPath, FileMode.Create, FileAccess.ReadWrite);
                MergeModLoader.SerializeManifest(fs, json, stagingPath);
                mergeModNames.Add(m3mName);
            }
            MilanLog.Information($"Updating ModDesc with new merge mods", customPrefix: LOG_CATEGORY);
            // Add in any new mergemods
            string[] moddesc = File.ReadAllLines(Path.Combine(Program.Settings.OutputModPath, "..", "moddesc.ini"));
            for(int idx = 0; idx <= moddesc.Length; idx++)
            {
                if (moddesc[idx].StartsWith("mergemods = "))
                {
                    moddesc[idx] = $"mergemods = {string.Join(";", mergeModNames)}";
                    break;
                }
            }
            File.WriteAllLines(Path.Combine(Program.Settings.OutputModPath, "..", "moddesc.ini"), moddesc);


        }

        private static void BuildMPMergeMod(string compilingPath, string stagingPath, string mergeModsPath)
        {
            var manifest = Path.Combine(stagingPath, "mprequiredchanges.json");

            MergeMod1 mm1 = new MergeMod1();
            mm1.Game = MEGame.LMP;
            mm1.FilesToMergeInto = new List<MergeFile1>()
            {
                new MergeFile1()
                {
                    ApplyToAllLocalizations = false,
                    FileName = "SFXGame.pcc",
                    MergeChanges = new List<MergeFileChange1>(GetMergeChangesFor("SFXGame", stagingPath))
                },
                //new MergeFile1()
                //{
                //    ApplyToAllLocalizations = false,
                //    FileName = "SFXOnlineFoundation.pcc",
                //    MergeChanges = new List<MergeFileChange1>(GetMergeChangesFor("SFXOnlineFoundation", stagingPath))
                //}
            };

            // Output
            var m3mPath = Path.Combine(mergeModsPath, "mprequiredchanges.m3m");
            using var fs = File.Open(m3mPath, FileMode.Create, FileAccess.ReadWrite);
            var json = JsonConvert.SerializeObject(mm1, Formatting.Indented, new JsonSerializerSettings
            {
                NullValueHandling = NullValueHandling.Ignore
            });
            File.WriteAllText(manifest, json);
            MergeModLoader.SerializeManifest(fs, json, stagingPath);

        }

        // ASSETUPDATE
        // TODO: asset update system
        // TODO: move out into an "extras" pipeline or similar
        private static void CopyAssetUpdateMergeMods(string compilingPath, string stagingPath)
        {
            var assetUpdatePath = Path.Combine(compilingPath, "AssetUpdate");
            var assets = Directory.GetFiles(assetUpdatePath, "*", SearchOption.AllDirectories);
            foreach (var file in assets)
            {
                File.Copy(file, Path.Combine(stagingPath, Path.GetFileName(file)), true);
            }
        }

        /// <summary>
        /// Gets the changes to put into the m3m merge file for Project Milan
        /// </summary>
        /// <param name="packageName">Package to merge into</param>
        /// <param name="stagingPath">Where the contents to merge are stored</param>
        /// <returns></returns>
        private static IEnumerable<MergeFileChange1> GetMergeChangesFor(string packageName, string stagingPath)
        {
            var compilingPath = Path.Combine(MilanShared.PipelineRoot, "Startups", "MPCommon", "MergeMod");
            List<MergeFileChange1> files = new List<MergeFileChange1>();


            // FUNCTIONS
            var functions = Directory.CreateDirectory(Path.Combine(compilingPath, "Functions", packageName)).FullName;
            foreach (var f in Directory.GetFiles(functions, "*.uc", SearchOption.AllDirectories))
            {
                files.Add(AddMergeScriptFileChange(f, stagingPath));
            }

            // ADDTOCLASSORREPLACE
            // Need to split up by class name
            var atcor = Directory.CreateDirectory(Path.Combine(compilingPath, "AddToClassOrReplace", packageName)).FullName;
            var atcorFiles = Directory.GetFiles(atcor, "*.uc", SearchOption.AllDirectories).ToList();
            var atcorClasses = atcorFiles.GroupBy(x => x.Substring(0, x.IndexOf('.')));
            foreach (var classGrouping in atcorClasses)
            {
                files.Add(AddMergeAddToClassOrReplaceChanges(Path.GetFileName(classGrouping.Key), classGrouping.ToList(), stagingPath));
            }

            // PROPERTYUPDATE
            // TODO: move properties to their own json(?) files
            var props = new List<PropertyUpdate1>();
            props.Add(new PropertyUpdate1()
            {
                PropertyName = "aimAssistProfileSettingID",
                PropertyType = "IntProperty",
                PropertyValue = "31"
            });
            files.Add(new MergeFileChange1
            {
                EntryName = "Default__SFXModule_AimAssist",
                PropertyUpdates = props
            });
            
            return files;
        }

        private static MergeFileChange1 AddMergeScriptFileChange(string sourceFile, string stagingPath)
        {
            var ucName = Path.GetFileName(sourceFile);
            Directory.CreateDirectory(stagingPath);
            var destFile = Path.Combine(stagingPath, ucName);
            MilanLog.Information($"Adding script to merge mod: {ucName}", customPrefix: LOG_CATEGORY);
            File.Copy(sourceFile, destFile, true);
            return new MergeFileChange1()
            {
                EntryName = Path.GetFileNameWithoutExtension(ucName),
                ScriptUpdate = new ScriptUpdate1()
                {
                    ScriptFileName = ucName,
                }
            };
        }

        /// <summary>
        /// Adds a 'addtoclassoreplace' merge item. Used to add things to a class or update them if they already exist
        /// </summary>
        /// <param name="className">Name of class to merge into</param>
        /// <param name="sourceFiles">uc file sources that exist (full paths)</param>
        /// <param name="stagingPath">Where to copy the files to for compilation</param>
        /// <returns></returns>
        private static MergeFileChange1 AddMergeAddToClassOrReplaceChanges(string className, List<string> sourceFiles, string stagingPath)
        {
            // Copy the individual files to the compiling dir
            Directory.CreateDirectory(stagingPath);
            sourceFiles.Sort();
            foreach (var sourceFile in sourceFiles)
            {
                var ucName = Path.GetFileName(sourceFile);
                var destFile = Path.Combine(stagingPath, ucName);
                MilanLog.Information($"Adding 'addtoclassorreplace' to merge mod: {ucName}", customPrefix: LOG_CATEGORY);
                File.Copy(sourceFile, destFile, true);
            }

            return new MergeFileChange1()
            {
                EntryName = className,
                AddToClassOrReplace = new AddToClassOrReplace1()
                {
                    ScriptFileNames = sourceFiles.Select(x => Path.GetFileName(x)).ToArray()
                }
            };
        }

        /// <summary>
        /// This is required to make the build work. This will eventually need to go into a merge mod or be patched out.
        /// </summary>
        public static void HackPatchParents_Old()
        {
            return;
            // No longer needed

            if (MELoadedFiles.TryGetHighestMountedFile(MEGame.LE3, "SFXGame.pcc", out var sfxGameF))
            {
                var sfxgame = MEPackageHandler.OpenMEPackage(sfxGameF);
                if (sfxgame.FindExport("SFXTelemetryGameSession.SetMPMatchSettings") == null)
                {
                    // Patch class
                    MilanLog.Information("Patching in SFXGame.pcc 'SFXTelemetryGameSession' method stubs", customPrefix: LOG_CATEGORY);
                    var classOverride = File.ReadAllText(MilanShared.GetClassOverride("SFXTelemetryGameSession"));
                    UnrealScriptOptionsPackage usop = new UnrealScriptOptionsPackage()
                    {
                        MissingObjectResolver = MilanShared.MissingObjectResolver,
                        GetVTableFromDonor = MilanShared.GetVTableFromDonor
                    };
                    var lib = new FileLib(sfxgame);
                    lib.Initialize(usop);
                    var messages = UnrealScriptCompiler.CompileClass(sfxgame, classOverride, lib, usop, sfxgame.FindExport("SFXTelemetryGameSession"));
                    sfxgame.Save();
                }
            }
        }


        private static string GetPackageName(string sourceFilePath)
        {
            return Directory.GetParent(sourceFilePath).Name;
        }

        // These have now been dumped, so the code is no longer run... for now, anyways.
        // Mgamerz-specific.

        /// <summary>
        /// returns true if a class was emitted that was decompiled from ME3
        /// </summary>
        /// <param name="classFolder"></param>
        /// <param name="packagePath"></param>
        /// <param name="packageCache"></param>
        /// <returns></returns>
        private static bool CompileMPCommonPackage(string packagePath, PackageCache cache)
        {
            MilanLog.Information("Compiling loose classes", customPrefix: LOG_CATEGORY);
            var classes = new List<UnrealScriptCompiler.LooseClass>();
            foreach (string ucFilePath in GetMPCommonClassFiles())
            {
                var overridePath = MilanShared.GetClassOverride(Path.GetFileNameWithoutExtension(ucFilePath));
                string source = File.ReadAllText(overridePath ?? ucFilePath);

                // 03/22/2026 - Strip out var delegate usages from old decomp as it breaks new recomp
                source = source.Replace("var delegate<", "//var delegate<");

                //files must be named Classname.uc
                classes.Add(new UnrealScriptCompiler.LooseClass(Path.GetFileNameWithoutExtension(ucFilePath), source, ucFilePath)); // Always use ucFilePath as it will be in the proper package folder, even if it goes unused.
            }

            using IMEPackage pcc = MEPackageHandler.CreateAndOpenPackage(packagePath, MEGame.LE3);
            pcc.LECLTagData.IsPostLoadFile = false;

            UnrealScriptOptionsPackage usop = new UnrealScriptOptionsPackage()
            {
                Cache = cache,
                MissingObjectResolver = MilanShared.MissingObjectResolver,
                GetVTableFromDonor = MilanShared.GetVTableFromDonor
            };
            // Different forced export packages
            var looseClassPackages = new List<UnrealScriptCompiler.LooseClassPackage>();
            foreach (var classEx in classes)
            {
                var packageFile = GetPackageName(classEx.SourceFilePath);
                var classList = looseClassPackages.Find(x => x.PackageName == packageFile);
                if (classList == null)
                {
                    classList = new UnrealScriptCompiler.LooseClassPackage(packageFile, new List<UnrealScriptCompiler.LooseClass>());
                    looseClassPackages.Add(classList);
                }
                classList.Classes.Add(classEx);
            }

            MilanLog.Information(@"Compiling LE3 class package", customPrefix: LOG_CATEGORY);
            MessageLog log = UnrealScriptCompiler.CompileLooseClasses(pcc, looseClassPackages, usop);

            if (log.HasErrors)
            {
                if (AttemptToFindMissingClasses(log, cache))
                    return true;
                MilanLog.Error("COMPILATION OF CUSTOM CLASSES FAILED: ", customPrefix: LOG_CATEGORY);
                foreach (var error in log.AllErrors)
                {
                    MilanLog.Error($"  {error}", customPrefix: LOG_CATEGORY);
                }

                return false;
            }
            MilanLog.Information(@"Loose class compilation succeeded!", customPrefix: LOG_CATEGORY);

            MilanLog.Information(@"Creating object referencer", customPrefix: LOG_CATEGORY);
            PackageTools.CreateObjectReferencer(pcc, false);
            foreach (var classExp in pcc.Exports.Where(x => x.IsClass))
            {
                // Yeah this is inefficient. 
                PackageTools.AddToObjectReferencer(classExp);
            }

            // Override functions - this is because some classes are huge
            // and we just want to change small segments. Due to patch function
            // This is more desirable for large classes that just need some functions patched
            FileLib fl = new FileLib(pcc);
            if (!fl.Initialize(usop))
            {
                MilanShared.LogFailedFileLibInit(fl, "Failed to initialize MPCommon FileLib for function overrides!", LOG_CATEGORY);
            }
            foreach (var file in Directory.GetFiles(GetMPCommonFunctionOverrideFolder(), "*.uc", SearchOption.AllDirectories))
            {
                var funcName = Path.GetFileNameWithoutExtension(file);
                var className = Directory.GetParent(file).Name;
                var classToUpdate = pcc.Exports.FirstOrDefault(x => x.ObjectName == className && x.IsClass);
                MilanLog.Information($"Overriding function {funcName} in class {className} with override", customPrefix: LOG_CATEGORY);
                var ucText = File.ReadAllText(file);
                var periodCount = funcName.Split('.').Length;

                if (periodCount > 1)
                {
                    // It's a sub function like a in a state
                    var function = pcc.FindExport($"{classToUpdate.InstancedFullPath}.{funcName}");
                    UnrealScriptCompiler.CompileFunction(function, ucText, fl, usop);
                }
                else
                {
                    // Add or replace to class
                    UnrealScriptCompiler.AddOrReplaceInClass(classToUpdate, ucText, fl, usop);
                }
            }


            // Inject additional assets via object referencer merge
            foreach (var file in Directory.GetFiles(GetMPCommonAddinFolder(), "*.pcc", SearchOption.AllDirectories))
            {
                MilanLog.Information($"Merging Milan MPCommon Addin {Path.GetFileName(file)}", customPrefix: LOG_CATEGORY);
                var mPackage = MEPackageHandler.OpenMEPackage(file);
                MilanShared.MergeObjectReferencers(mPackage, pcc);
            }

            MilanLog.Information($@"Saving {pcc.FileNameNoExtension}.pcc", customPrefix: LOG_CATEGORY);
            pcc.Save();
            MilanShared.AddGlobalCachedPackage(pcc);
            MilanShared.RefreshMilanFiles = true;
            return false;
        }


        private static string GetMPCommonFunctionOverrideFolder()
        {
            return Directory.CreateDirectory(Path.Combine(MilanShared.PipelineRoot, @"Shared", @"Compiling", @"FunctionOverride")).FullName;
        }


        private static string GetMPCommonAddinFolder()
        {
            return Directory.CreateDirectory(Path.Combine(MilanShared.PipelineRoot, @"Shared", @"Compiling", @"MPCommonAddins")).FullName;
        }


        /// <summary>
        /// Gets a list of files to compile into the MPCommon package
        /// </summary>
        /// <returns></returns>
        private static IEnumerable<string> GetMPCommonClassFiles()
        {
            return GetCleanableMPCommonClassFiles().Concat(
                Directory.EnumerateFiles(MilanShared.GetMilanNewMPCommonClassesPath(), "*.uc", SearchOption.AllDirectories));

        }

        /// <summary>
        /// Returns files that can be deleted as they will be regenerated automatically
        /// </summary>
        /// <returns></returns>
        public static IEnumerable<string> GetCleanableMPCommonClassFiles()
        {
            return Directory.EnumerateFiles(GetMPClassesFolder(), "*.uc", SearchOption.AllDirectories).Concat(
                Directory.EnumerateFiles(MilanShared.GetAutoDonorClassesPath(), "*.uc", SearchOption.AllDirectories));
        }

        private static bool AttemptToFindMissingClasses(MessageLog log, PackageCache cache)
        {
            List<string> decompiledClasses = new List<string>();
            var commonBasePackages = new[]
            {
                null,
                "SFXGame",
                "SFXGameContent",
                "SFXGameMPContent",
            };
            // Code: Find class
            foreach (var m in log.AllErrors)
            {
                string className = null;

                if (m.Message.Contains("but the function at that index in class"))
                {
                    // We don't care about VTable issues.
                    continue;
                }

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
                        false // multiline - add more here if needed
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


                // We need to find it and decompile it
                foreach (var cbp in commonBasePackages)
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
                                    DecompileClass(export, null, true, cache);
                                    decompiledClasses.Add(export.ObjectName);
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
                                    DecompileClass(export, null, true, cache);
                                    decompiledClasses.Add(export.ObjectName);
                                    keepSearching = false;
                                    continue;
                                }

                                MilanLog.Warning($"Export did not reside in package, perhaps the wrong one was found? Could be overridden by DLC", customPrefix: LOG_CATEGORY);
                            }
                        }
                    }
                }
            }
            return decompiledClasses.Any();
        }

        /// <summary>
        /// Prepares classes for porting by reading their data out of ME3
        /// </summary>
        private static bool CompileMPCommon(MPCommonPipelineVars vars)
        {
            var cache = TieredPackageCache.GetGlobalPackageCache(MEGame.ME3, false, true).ChainNewCache(false);
            var dlcInFile = Path.Combine(ME3Directory.DLCPath, "DLC_CON_MP5", MEGame.ME3.CookedDirName(), "Default.sfar");
            if (!File.Exists(dlcInFile))
            {
                throw new Exception("MP5 is not installed in ME3 (Reckoning DLC). Please install it. It does not need to be unpacked.");
            }

            // Go in from latest DLC to earlier
            var me3Packages = new[]
            {
                "MPLobby.pcc", // Holds pretty much all MP classes
                "Startup_DLC_CON_MP4_INT.pcc", // Collector HUD, Faction
                "Startup_DLC_CON_MP3_INT.pcc", // MobileAnnex
                "Startup_DLC_CON_MP2_INT.pcc", // Retrieve
                "BioP_MPCer.pcc", // SFXGameType_Horde_Operation
            };

            cache.InsertIntoCache(MilanShared.GetME3Package("Startup.pcc")); // This significantly improves performance by preventing opening it a ton

            foreach (var package in me3Packages)
            {
                MilanLog.Information($"Decompiling MP classes in {package} --------------------");
                var parsingPackage = MilanShared.GetME3Package(package);

                //initing filelib is expensive, so we only want to do it for files that have script
                var usop = new UnrealScriptOptionsPackage
                {
                    Cache = cache,
                    CustomFileResolver = MilanShared.ME3PackageResolver,
                };

                // List of package level exports to port (ForcedExport)
                // These can be null depending on what package they resolve on. That's fine.
                var packagesToPort = new[]
                {
                    parsingPackage.FindExport("SFXGameMPContent"),
                    parsingPackage.FindExport(
                        "SFXGameMPContentDLC_Shared_MP"), // This adds stuff for challenges in MP4. It is referenced by BioWorldInfo's game modes supported for Lobby DLC.

                    // These are in startup files.
                    parsingPackage.FindExport(
                        "SFXGameContentDLC_CON_MP2_Retrieve"), // Retrieve Objective was added in MP2
                    parsingPackage.FindExport(
                        "SFXGameContentDLC_CON_MP3_MobileAnnex"), // Mobile Annex Objective was added in MP3. Oh, the PTSD from this thing...
                    parsingPackage.FindExport(
                        "SFXGameContentDLC_CON_MP4_Horde"), // Adds CollectorHUDOverlay GUI class, Cerberus2/Geth2/Reaper2 faction classes (for config) and new collector faction class.
                    parsingPackage.FindExport(
                        "SFXGameContentDLC_CON_MP3"), // Some mobile annex stuff. Not sure if it's actually used. It gets patched though.
                };

                foreach (var classExp in parsingPackage.Exports.Where(x =>
                             x.IsClass && x.Parent != null && packagesToPort.Contains(x.Parent) &&
                             ClassNeedsDecompiled(x)))
                {
                    bool decompiled = false;
                    // Find LE3 version
                    var foundObjs = MilanShared.LE3ObjectDB.GetFilesContainingObject(classExp.InstancedFullPath);
                    if (foundObjs != null)
                    {
                        foreach (var foundObj in foundObjs)
                        {
                            var sourceFileName = Path.GetFileName(foundObj);
                            var le3package = MilanShared.GetLE3Package(sourceFileName);

                            // DLC system Milan uses doesn't look in SP files
                            // So if obj database has SP stuff this will fail
                            // Just keep going.
                            if (le3package != null)
                            {
                                var export = le3package.FindExport(classExp.InstancedFullPath);
                                if (export != null)
                                {
                                    DecompileClass(export, null, false, cache);
                                    decompiled = true;
                                    break;
                                }
                            }
                        }
                    }

                    if (!decompiled)
                    {
                        DecompileClass(classExp, null, false, cache);
                    }
                }
            }

            // Attempt compile
            var outPackage = Path.Combine(Program.Settings.OutputModPath, Path.Combine(vars.OutputPath, @"CookedPCConsole", MilanShared.MP_STARTUP_FILENAME));

            while (CompileMPCommonPackage(outPackage, cache))
            {
                MilanLog.Information("Attempting recompile with new class data----------------------", customPrefix: LOG_CATEGORY);
            }

            if (!File.Exists(outPackage) || new FileInfo(outPackage).Length < 4096)
                return false;
            return true;
        }

        private static bool ClassNeedsDecompiled(ExportEntry classExp)
        {
            var packageOutputPath = Path.Combine(GetMPClassesFolder(), classExp.HasParent ? classExp.ParentName : classExp.FileRef.FileNameNoExtension);
            var ucPath = Path.Combine(packageOutputPath, $"{classExp.ObjectName}.uc");
            var needsDecompiled = !File.Exists(ucPath);
            return needsDecompiled;
        }

        /// <summary>
        /// Decompiles the class export to disk
        /// </summary>
        /// <param name="classExp"></param>
        /// <param name="fileLib"></param>
        /// <param name="toShared"></param>
        /// <param name="cache"></param>
        public static void DecompileClass(ExportEntry classExp, FileLib fileLib, bool toShared, PackageCache cache)
        {
            //if (classExp.ObjectName == "DamageType")
            //    Debug.WriteLine("");
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


            var baseOutputPath = toShared ? MilanShared.GetAutoDonorClassesPath() : GetMPClassesFolder();
            var packageOutputPath = Path.Combine(baseOutputPath, classExp.HasParent ? classExp.ParentName : classExp.FileRef.FileNameNoExtension);
            Directory.CreateDirectory(packageOutputPath);
            var ucOutPath = Path.Combine(packageOutputPath, $"{classExp.ObjectName}.uc");

            // Check if override exists
            var overridePath = MilanShared.GetClassOverride(classExp.ObjectName);
            if (overridePath != null)
            {
                MilanLog.Information($"Using Milan class override for {classExp.ObjectName}", customPrefix: LOG_CATEGORY);
                File.Copy(overridePath, ucOutPath, true);
                return;
            }

            MilanLog.Information($"Decompiling {classExp.FileRef.Game} {classExp.InstancedFullPath}", customPrefix: LOG_CATEGORY);
            if (usingTestPatch)
            {
                MilanLog.Information($@"  Using DLC_TestPatch version of {classExp.InstancedFullPath}", customPrefix: LOG_CATEGORY);
            }
            UnrealScriptOptionsPackage usop = new UnrealScriptOptionsPackage()
            {
                Cache = cache,
                CustomFileResolver = classExp.Game == MEGame.LE3 ? MilanShared.LE3PackageResolver : MilanShared.ME3PackageResolver,
            };

            fileLib ??= new FileLib(classExp.FileRef);
            if (!fileLib.IsInitialized)
            {
                if (!fileLib.Initialize(usop))
                {
                    MilanLog.Error($"FileLib initialization failed for {classExp.FileRef.FilePath}:", customPrefix: LOG_CATEGORY);
                    foreach (var f in fileLib.InitializationLog.AllErrors)
                    {
                        MilanLog.Error($"  {f.Message}");
                    }
                    // Debugger.Break(); // Filelib failed to initialize!!
                }
            }

            (_, string functionText) = UnrealScriptCompiler.DecompileExport(classExp, fileLib, usop);

            // FUNCTION PATCHES
            List<string> newFunction = PatchFunction(classExp.ObjectName, functionText);

            // Insert metadata about autogen
            newFunction.Insert(0, $"// Source: {classExp.FileRef.Game}, {classExp.FileRef.FileNameNoExtension}");
            newFunction.Insert(1, $"// Decompiled {DateTime.Now}");

            var cleaned = MilanShared.CleanErrorComments(string.Join("\n", newFunction), out _);
            File.WriteAllText(ucOutPath, cleaned);
        }

        /// <summary>
        /// Photo mode was inserted at this index into EGameModes enum for LE3
        /// </summary>
        private const int PHOTO_MODE_LE3_GAMEMODEIDX = 14;

        /// <summary>
        /// Makes corrections for ME3 -> LE3
        /// </summary>
        /// <param name="functionText"></param>
        /// <returns></returns>
        /// <exception cref="NotImplementedException"></exception>
        public static List<string> PatchFunction(string className, string functionText)
        {
            var newClassText = functionText.Split('\n').ToList();
            for (int i = newClassText.Count - 1; i > 0; i--)
            {
                var line = newClassText[i].Trim();

                // TELEMETRY ========================================
                if (line.StartsWith("Class'SFXTelemetry'.static.Send") || line.StartsWith("Class'SFXTelemetry'.static.AddAttributeToArray"))
                {
                    MilanLog.Information($"  Patching out telemetry call {line}", customPrefix: LOG_CATEGORY);
                    newClassText[i] = GetWhiteSpaceStart(newClassText[i]) + " // MILAN Patched: Remove calls to SFXTelemetry";
                    continue;
                }

                if (line.StartsWith("SFXEngine(Class'Engine'.static.GetEngine()).Telemetry.GameSession.SetMPMatchSettings"))
                {
                    MilanLog.Information($"  Patching out telemetry call {line}", customPrefix: LOG_CATEGORY);
                    newClassText[i] = GetWhiteSpaceStart(newClassText[i]) + " // MILAN Patched: Remove calls to Engine.Telemetry.GameSession.SetMPMatchSettings()";
                    continue;
                }

                // HINT SYSTEM =======================================
                // Hint system now uses console and pc strings.
                if (line == "oGuiMgr.ShowHint(srStrictNatError, NatWarningShowDuration);")
                {
                    MilanLog.Information($"  Patching ShowHint {line}", customPrefix: LOG_CATEGORY);
                    newClassText[i] = GetWhiteSpaceStart(newClassText[i]) + "oGuiMgr.ShowHint(srStrictNatError, srStrictNatError, NatWarningShowDuration); // MILAN Patched: Change method signature for controller/KBM strings";
                    continue;
                }

                // To be fixed in LEX compiler =========================
                //if (line == "KeepDecimal ? pos++ : pos--;")
                //{
                //    MilanLog.Information($"  Patching temporary LEX compiler issue {line}");
                //    newFunction[i] = "if (KeepDecimal) { pos = pos + 1; } else { pos = pos - 1; }";
                //    continue;
                //}

                // FIX LATER ============================================
                // That's why it's warnings
                if (line is "GAWAssetHandler.Cleanup();" or "GAWAssetHandler.RequestGAWRatings(OnGAWRequestFinished);")
                {
                    MilanLog.Warning($"  Patching out GAWAssetHandler reference {line}", customPrefix: LOG_CATEGORY);
                    newClassText[i] = GetWhiteSpaceStart(newClassText[i]) + $"//{line.Trim()} // MILAN Patched: Remove Galaxy At War calls";
                    continue;
                }

                if (line is "return GAWAssetsHandler.CachedGAWRatings[int(MatchResults.CurrentMatchData.ZoneID)] + MatchResults.CurrentMatchData.ZoneRatingIncrease;")
                {
                    MilanLog.Warning($"  Patching out GAWAssetHandler reference {line}", customPrefix: LOG_CATEGORY);
                    // Need to implement GAW system that can change zones
                    newClassText[i] = GetWhiteSpaceStart(newClassText[i]) + "return 50 + MatchResults.CurrentMatchData.ZoneRatingIncrease; // MILAN Patched: Remove Galaxy At War calls";
                    continue;
                }

                if (line is "if (Class'SFXGAWAssetsHandler'.static.GetGAWHandler().CachedGAWRatings[int(MatchResults.CurrentMatchData.ZoneID)] >= 100)")
                {
                    MilanLog.Warning($"  Patching out GAWAssetHandler reference {line}", customPrefix: LOG_CATEGORY);
                    // Need to implement GAW system that can change zones
                    newClassText[i] = GetWhiteSpaceStart(newClassText[i]) + "if (true) // MILAN Patched: Remove Galaxy At War calls";
                    continue;
                }

                if (line.StartsWith("Class'SFXGAWAssetsHandler'.static.UpdateSecurityRating"))
                {
                    MilanLog.Warning($"  Patching out GAWAssetHandler reference {line}", customPrefix: LOG_CATEGORY);
                    // Need to implement GAW system that can change zones
                    newClassText[i] = GetWhiteSpaceStart(newClassText[i]) + "// MILAN Patched: Remove Galaxy At War calls";
                    continue;
                }



                if (line.Contains(".ShowHint("))
                {
                    MilanLog.Warning($@"Needs patched: {line}", customPrefix: LOG_CATEGORY);
                }

                // PHOTO GAME MODE ----------------------------------------------------------------
                // Not sure if this covers if there's any variable versions.
                if (line.Contains("SetGameMode(TRUE, ") || line.Contains("SetGameMode(FALSE, "))
                {
                    var idx = line.IndexOf(@"SetGameMode(") + @"SetGameMode(".Length;
                    var subl = line.Substring(idx);
                    idx = subl.IndexOf(",");
                    if (idx > 0)
                    {
                        subl = subl.Substring(idx + 1).Trim(); // should now start with a number
                        subl = subl.Substring(0, subl.IndexOf(')'));
                        if (int.TryParse(subl, out var modeIdx))
                        {
                            if (modeIdx >= PHOTO_MODE_LE3_GAMEMODEIDX)
                            {
                                // This is kind of a weak way of doing this and could easily break
                                // Needs patched to increment by 1 - skip photo mode.
                                MilanLog.Information($"  Patching SetGameMode index +1 for {line}", customPrefix: LOG_CATEGORY);
                                newClassText[i] = GetWhiteSpaceStart(newClassText[i]) + line.Replace(modeIdx.ToString(), (modeIdx + 1).ToString()) + " // MILAN Patched: GameMode Enum Index";
                            }
                        }
                        //Debug.WriteLine(subl);
                    }
                }
                else if (line.Contains("GameModeManager2.EnableMode(") || line.Contains("GameModeManager2.DisableMode("))
                {
                    var idx = line.IndexOf(@"Mode(") + @"Mode(".Length;
                    var subl = line.Substring(idx);
                    subl = subl.Substring(0, subl.IndexOf(')')); // should now start with a number
                    if (int.TryParse(subl, out var modeIdx))
                    {
                        if (modeIdx >= PHOTO_MODE_LE3_GAMEMODEIDX)
                        {
                            // This is kind of a weak way of doing this and could easily break
                            // Needs patched to increment by 1 - skip photo mode.
                            MilanLog.Information($"  Patching Enable/DisableMode index +1 for {line}", customPrefix: LOG_CATEGORY);
                            newClassText[i] = GetWhiteSpaceStart(newClassText[i]) + line.Replace(modeIdx.ToString(), (modeIdx + 1).ToString()) + " // MILAN Patched: GameMode Enum Index";
                        }
                    }
                    //Debug.WriteLine(subl);
                }
                if (line.Contains("GameModeManager2.IsActive("))
                {
                    var idx = line.IndexOf(@"IsActive(") + @"IsActive(".Length;
                    var subl = line.Substring(idx);
                    subl = subl.Substring(0, subl.IndexOf(')')); // should now start with a number
                    if (int.TryParse(subl, out var modeIdx))
                    {
                        if (modeIdx >= PHOTO_MODE_LE3_GAMEMODEIDX)
                        {
                            // This is kind of a weak way of doing this and could easily break
                            // Needs patched to increment by 1 - skip photo mode.
                            MilanLog.Information($"  Patching IsActive(mode) index +1 for {line}", customPrefix: LOG_CATEGORY);
                            newClassText[i] = GetWhiteSpaceStart(newClassText[i]) + line.Replace(modeIdx.ToString(), (modeIdx + 1).ToString()) + " // MILAN Patched: GameMode Enum Index";
                        }
                    }
                    //Debug.WriteLine(subl);
                }
            }

            // Inject any additional functions
            var injectionFolder = MilanShared.GetInjectedFunctionsPath(className);
            if (Directory.Exists(injectionFolder))
            {
                // We need to inject above 'defaultproperties'
                var defaultPropertiesIdx = newClassText.IndexOf("defaultproperties");

                foreach (var file in Directory.GetFiles(injectionFolder, "*.uc", SearchOption.TopDirectoryOnly))
                {
                    MilanLog.Information($"   Injecting function {Path.GetFileNameWithoutExtension(file)} into class {className}", customPrefix: LOG_CATEGORY);
                    var iFunction = File.ReadAllLines(file);
                    newClassText.InsertRange(defaultPropertiesIdx - 1, iFunction);
                }
            }

            return newClassText;

        }

        /// <summary>
        /// Generates a blank string representing the beginning of a line of text that may be trimmed
        /// </summary>
        /// <param name="line"></param>
        /// <returns></returns>
        private static string GetWhiteSpaceStart(string line)
        {
            int numWhiteSpace = 0;
            while (numWhiteSpace < line.Length)
            {
                if (line[numWhiteSpace] == ' ')
                {
                    numWhiteSpace++;
                }
                else
                {
                    break;
                }
            }

            return "".PadLeft(numWhiteSpace);
        }

        /// <summary>
        /// Contains the path where classes directly pulled from BIOP_MP_Common are housed. Autodonors (dependencies of these classes) are not put here
        /// </summary>
        /// <returns></returns>
        private static string GetMPClassesFolder()
        {
            return Directory.CreateDirectory(Path.Combine(MilanShared.PipelineRoot, @"Shared", @"Compiling", @"LooseClasses", @"MPCommon")).FullName;
        }

        internal static void Clean()
        {
            var files = GetCleanableMPCommonClassFiles();
            foreach (var f in files)
            {
                MilanLog.Information($"Clean() on {f}", customPrefix: LOG_CATEGORY);
                File.Delete(f);
            }
        }
    }
}
