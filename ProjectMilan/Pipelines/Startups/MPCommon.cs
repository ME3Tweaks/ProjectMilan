using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using LegendaryExplorerCore.GameFilesystem;
using LegendaryExplorerCore.Helpers;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Packages.CloningImportingAndRelinking;
using LegendaryExplorerCore.Unreal;
using LegendaryExplorerCore.Unreal.BinaryConverters;
using LegendaryExplorerCore.Unreal.ObjectInfo;
using LegendaryExplorerCore.UnrealScript;
using LegendaryExplorerCore.UnrealScript.Compiling.Errors;
using ProjectMilan.Utility;
using Serilog;

namespace ProjectMilan.Pipelines.Startups
{
    /// <summary>
    /// Pass-throughable settings for MPCommon pipelne
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

            // Prepare classes for porting
            HackPatchParents(); // Eventually this will be moved to a merge mod. But for compilation purposes, it needs to be done here.


            if (!CompileMPCommon(vars))
            {
                MilanLog.Fatal($"Failed to compile {MilanShared.MP_STARTUP_NAME}", customPrefix: LOG_CATEGORY);
                Environment.Exit(1);
            }
        }

        /// <summary>
        /// This is required to make the build work. This will eventually need to go into a merge mod or be patched out.
        /// </summary>
        public static void HackPatchParents()
        {
            if (MELoadedFiles.TryGetHighestMountedFile(MEGame.LE3, "SFXGame.pcc", out var sfxGameF))
            {
                var sfxgame = MEPackageHandler.OpenMEPackage(sfxGameF);
                if (sfxgame.FindExport("SFXTelemetryGameSession.SetMPMatchSettings") == null)
                {
                    // Patch class
                    MilanLog.Information("Patching in SFXGame.pcc 'SFXTelemetryGameSession' method stubs", customPrefix: LOG_CATEGORY);
                    var classOverride = File.ReadAllText(MilanShared.GetClassOverride("SFXTelemetryGameSession"));
                    var lib = new FileLib(sfxgame);
                    lib.Initialize();
                    var messages = UnrealScriptCompiler.CompileClass(sfxgame, classOverride, lib, sfxgame.FindExport("SFXTelemetryGameSession"));
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
                //files must be named Classname.uc
                classes.Add(new UnrealScriptCompiler.LooseClass(Path.GetFileNameWithoutExtension(ucFilePath), source, ucFilePath)); // Always use ucFilePath as it will be in the proper package folder, even if it goes unused.
            }

            using IMEPackage pcc = MEPackageHandler.CreateAndOpenPackage(packagePath, MEGame.LE3);

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
            MessageLog log = UnrealScriptCompiler.CompileLooseClasses(pcc, looseClassPackages, MissingObjectResolver, vtableDonorGetter: VTableDonorGetter, cache: cache);

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
            MilanLog.Information(@"Compilation succeeded!", customPrefix: LOG_CATEGORY);


            MilanLog.Information(@"Creating object referencer", customPrefix: LOG_CATEGORY);
            PackageTools.CreateObjectReferencer(pcc, false);
            foreach (var classExp in pcc.Exports.Where(x => x.IsClass))
            {
                // Yeah this is inefficient. 
                PackageTools.AddToObjectReferencer(classExp);
            }

            MilanLog.Information($@"Saving {pcc.FileNameNoExtension}.pcc", customPrefix: LOG_CATEGORY);
            pcc.Save();
            MilanShared.RefreshMilanFiles = true;
            return false;
        }

        //terrible function, there are better ways of implementing it.
        private static List<string> VTableDonorGetter(string className)
        {

            var classInfo = GlobalUnrealObjectInfo.GetClassOrStructInfo(MEGame.LE3, className);
            if (classInfo is not null)
            {
                string path = Path.Combine(MEDirectories.GetBioGamePath(MEGame.LE3), classInfo.pccPath);
                if (File.Exists(path))
                {
                    IMEPackage partialLoad = MEPackageHandler.UnsafePartialLoad(path, exp => exp.IsClass && exp.ObjectName == className);
                    foreach (ExportEntry export in partialLoad.Exports)
                    {
                        if (export.IsClass && export.ObjectName == className)
                        {
                            var obj = export.GetBinaryData<UClass>();
                            var list = obj.VirtualFunctionTable.Select(uIdx => partialLoad.GetEntry(uIdx).ObjectName.Name).ToList();
                            if (className == "SFXProjectile_PowerCustomAction_SuperSeeking")
                            {
                                // Debugger.Break();
                            }

                            return list;
                        }
                    }
                }
            }

            return null;
        }

        /// <summary>
        /// Gets a list of files to compile into the MPCommon package
        /// </summary>
        /// <returns></returns>
        private static IEnumerable<string> GetMPCommonClassFiles()
        {
            return Directory.EnumerateFiles(GetMPClassesFolder(), "*.uc", SearchOption.AllDirectories).Concat(
                Directory.EnumerateFiles(MilanShared.GetAutoDonorClassesPath(), "*.uc", SearchOption.AllDirectories)).Concat(
                Directory.EnumerateFiles(MilanShared.GetMilanNewMPCommonClassesPath(), "*.uc", SearchOption.AllDirectories));

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

        private static IEntry MissingObjectResolver(IMEPackage package, string ifp)
        {
            var possibleDonors = MilanShared.LE3ObjectDB.GetFilesContainingObject(ifp, package.Localization);
            if (possibleDonors == null)
            {
                // ME3 port
                MilanLog.Error($"Object '{ifp}' does not exist in LE3! We need to make a donor for this.", customPrefix: LOG_CATEGORY);
                var originalGameDonors = MilanShared.ME3ObjectDB.GetFilesContainingObject(ifp, package.Localization);
                originalGameDonors = originalGameDonors.Select(x => Path.GetFileName(x)).ToList(); // we don't care about paths.
                originalGameDonors.Sort(new ObjectSourceTierComparer(MEGame.ME3, package.FilePath));
                foreach (var possibleDonor in originalGameDonors)
                {
                    var donorP = MilanShared.GetME3Package(possibleDonor);
                    if (donorP != null)
                    {
                        var donorEntry = donorP.FindEntry(ifp);
                        if (donorEntry != null)
                        {
                            MilanLog.Warning($"  Using ME3 donor object {ifp} from {possibleDonor}", customPrefix: LOG_CATEGORY);
                            return PortDonorIntoPackage(ME3GlobalCache, donorEntry, package);
                        }
                    }
                }

                MilanLog.Error($"  No donor! Returning null!!", customPrefix: LOG_CATEGORY);
                return null;
            }

            // Sort by higher tier first
            possibleDonors.Sort(new ObjectSourceTierComparer(MEGame.LE3, package.FilePath));

            foreach (var possibleDonor in possibleDonors)
            {
                // Todo: Maybe use cache for this - with a max size
                var donorP = LE3GlobalCache.GetCachedPackage(Path.Combine(LE3Directory.DefaultGamePath, possibleDonor), openPackageMethod: MilanShared.GetLE3Package);
                if (donorP != null)
                {
                    var donorEntry = donorP.FindEntry(ifp);
                    if (donorEntry != null)
                    {
                        MilanLog.Information($"  Using donor object {ifp} from {possibleDonor}", customPrefix: LOG_CATEGORY);
                        return PortDonorIntoPackage(LE3GlobalCache, donorEntry, package);
                    }
                    else
                    {
                        MilanLog.Warning($"  LE3 donor package {possibleDonor} does not contain {ifp}", customPrefix: LOG_CATEGORY);
                    }
                }
            }
            MilanLog.Error($"Unable to find object {ifp} in {possibleDonors.Count} packages!", customPrefix: LOG_CATEGORY);
            return null;
        }

        private static IEntry PortDonorIntoPackage(PackageCache globalCache, IEntry donorEntry, IMEPackage package)
        {
            if (donorEntry is ImportEntry donorImport)
            {
                // uh
                Debug.WriteLine("Uh oh");
            }
            else if (donorEntry is ExportEntry donorExport)
            {
                if (EntryImporter.IsSafeToImportFrom(donorEntry.FileRef.FilePath, MEGame.LE3, package.FilePath))
                {
                    // Create parents
                    MilanLog.Information($"    Porting as import", customPrefix: LOG_CATEGORY);
                    var parent = EntryExporter.PortParents(donorEntry, package, true);
                    ImportEntry imp = new ImportEntry(donorExport, parent.UIndex, package);
                    package.AddImport(imp);
                    return imp; // Adding as import
                }
                if (donorExport.FileRef.FileNameNoExtension == "SFXGame")
                    Debugger.Break();
                MilanLog.Information($"    Porting from {donorExport.FileRef.FileNameNoExtension}", customPrefix: LOG_CATEGORY);
                var errors = EntryExporter.ExportExportToPackage(donorExport, package, out var newExp, packageCache: globalCache);
                return newExp;
            }

            return null;
        }

        private static void SortDonors(List<string> possibleDonors)
        {

        }

        /// <summary>
        /// Prepares classes for porting by reading their data out of ME3
        /// </summary>
        private static bool CompileMPCommon(MPCommonPipelineVars vars)
        {
            var cache = new PackageCache();
            var dlcInFile = Path.Combine(ME3Directory.DLCPath, "DLC_CON_MP5", MEGame.ME3.CookedDirName(),
                "Default.sfar");
            if (!File.Exists(dlcInFile))
            {
                throw new Exception(
                    "MP5 is not installed in ME3 (Reckoning DLC). Please install it. It does not need to be unpacked.");
            }

            // Go in from latest DLC to earlier
            var me3Packages = new[]
            {
                "MPLobby.pcc", // Holds pretty much all MP classes
                "Startup_DLC_CON_MP4_INT.pcc", // Collector HUD, Faction
                // "SFXMobileAnnex.pcc", // Extra stuff
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
                FileLib fileLib = new FileLib(parsingPackage);
                try
                {
                    fileLib.Initialize(cache);
                }
                catch
                {
                    //we're not checking if it failed to initialize because we don't really care, since decompilation doesn't actually need an initialized filelib,
                    //it just makes the output a bit nicer (at the time of this writing all it does is resolve some integer literals into enum values)
                }

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

        private static void DecompileClass(ExportEntry classExp, FileLib fileLib, bool toShared, PackageCache cache)
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
            if (fileLib == null)
            {
                // Initialize filelib if it wasn't.
                try
                {
                    fileLib = new FileLib(classExp.FileRef);
                    fileLib.Initialize(cache);
                }
                catch
                {
                    //we're not checking if it failed to initialize because we don't really care, since decompilation doesn't actually need an initialized filelib,
                    //it just makes the output a bit nicer (at the time of this writing all it does is resolve some integer literals into enum values)
                }
            }

            (_, string functionText) = UnrealScriptCompiler.DecompileExport(classExp, fileLib, cache);

            // FUNCTION PATCHES
            List<string> newFunction = PatchFunction(classExp.ObjectName, functionText);

            // Insert metadata about autogen
            newFunction.Insert(0, $"// Source: {classExp.FileRef.Game}, {classExp.FileRef.FileNameNoExtension}");
            newFunction.Insert(1, $"// Decompiled {DateTime.Now}");

            File.WriteAllLines(ucOutPath, newFunction);
        }

        /// <summary>
        /// Makes corrections for ME3 -> LE3
        /// </summary>
        /// <param name="functionText"></param>
        /// <returns></returns>
        /// <exception cref="NotImplementedException"></exception>
        private static List<string> PatchFunction(string className, string functionText)
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
                            if (modeIdx >= 14)
                            {
                                // This is kind of a weak way of doing this and could easily break
                                // Needs patched to increment by 1 - skip photo mode.
                                MilanLog.Information($"  Patching SetGameMode index +1 for {line}", customPrefix: LOG_CATEGORY);
                                newClassText[i] = line.Replace(modeIdx.ToString(), (modeIdx + 1).ToString()) + " // MILAN Patched: GameMode Enum Index";
                            }
                        }
                        //Debug.WriteLine(subl);
                    }
                }
                else if (line.Contains("GameModeManager2.EnableMode(") || line.Contains("GameModeManager2.DisabledMode("))
                {
                    var idx = line.IndexOf(@"Mode(") + @"Mode(".Length;
                    var subl = line.Substring(idx);
                    subl = subl.Substring(0, subl.IndexOf(')')); // should now start with a number
                    if (int.TryParse(subl, out var modeIdx))
                    {
                        if (modeIdx >= 14)
                        {
                            // This is kind of a weak way of doing this and could easily break
                            // Needs patched to increment by 1 - skip photo mode.
                            MilanLog.Information($"  Patching Enable/DisableMode index +1 for {line}", customPrefix: LOG_CATEGORY);
                            newClassText[i] = line.Replace(modeIdx.ToString(), (modeIdx + 1).ToString()) + " // MILAN Patched: GameMode Enum Index";
                        }
                    }
                    //Debug.WriteLine(subl);
                }
                if (line.Contains("GameModeManager2.IsActive(") || line.Contains("GameModeManager2.IsActive("))
                {
                    var idx = line.IndexOf(@"IsActive(") + @"IsActive(".Length;
                    var subl = line.Substring(idx);
                    subl = subl.Substring(0, subl.IndexOf(')')); // should now start with a number
                    if (int.TryParse(subl, out var modeIdx))
                    {
                        if (modeIdx >= 14)
                        {
                            // This is kind of a weak way of doing this and could easily break
                            // Needs patched to increment by 1 - skip photo mode.
                            MilanLog.Information($"  Patching IsActive(mode) index +1 for {line}", customPrefix: LOG_CATEGORY);
                            newClassText[i] = line.Replace(modeIdx.ToString(), (modeIdx + 1).ToString()) + " // MILAN Patched: GameMode Enum Index";
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
    }
}
