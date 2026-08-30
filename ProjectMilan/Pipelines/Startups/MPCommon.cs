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
using System.Text.RegularExpressions;

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
            MPMerge.RunPipeline();
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
        private static bool CompileMPCommonPackage(string packagePath, PackageCache cache, HashSet<string> discoveredAutoDonorClasses)
        {
            MilanLog.Information("Compiling loose classes", customPrefix: LOG_CATEGORY);
            var classes = new List<UnrealScriptCompiler.LooseClass>();
            foreach (string ucFilePath in GetMPCommonClassFiles())
            {
                var overridePath = MilanShared.GetClassOverride(Path.GetFileNameWithoutExtension(ucFilePath));
                string source = File.ReadAllText(overridePath ?? ucFilePath);

                // 03/22/2026 - Strip out var delegate usages from old decomp as it breaks new recomp
                var preLen = source.Length;
                source = source.Replace("var delegate<", "//var delegate<");
                var postLen = source.Length;
                if (preLen != postLen)
                {
                    MilanLog.Information($"  Stripped out delegate(s) from decompiled class {Path.GetFileName(ucFilePath)}", customPrefix: LOG_CATEGORY);
                }

                //files must be named Classname.uc
                classes.Add(new UnrealScriptCompiler.LooseClass(Path.GetFileNameWithoutExtension(ucFilePath), source, ucFilePath)); // Always use ucFilePath as it will be in the proper package folder, even if it goes unused.
            }

            using IMEPackage pcc = MEPackageHandler.CreateAndOpenPackage(packagePath, MEGame.LE3);
            pcc.LECLTagData.IsPostLoadFile = false;

            UnrealScriptOptionsPackage usop = new UnrealScriptOptionsPackage()
            {
                Cache = cache,
                MissingObjectResolver = MilanShared.MissingObjectResolver,
                GetVTableFromDonor = MilanShared.GetVTableFromDonor,
                // Without this, FileLib's base-file resolution (Core/Engine/SFXGame/etc, needed to
                // resolve types referenced by the loose classes) loads straight from the live mounted
                // game path via usop.Cache, bypassing BaseDeltaHandler's patched packages entirely.
                // LE3PackageResolver checks MilanShared's patched global cache first.
                CustomFileResolver = MilanShared.LE3PackageResolver
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
                if (AttemptToFindMissingClasses(log, cache, discoveredAutoDonorClasses))
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
            foreach (var file in MilanShared.GetAllFunctionOverrides())
            {
                var className = Directory.GetParent(file).Name;
                var classToUpdate = pcc.Exports.FirstOrDefault(x => x.ObjectName == className && x.IsClass);
                if (classToUpdate != null)
                {
                    MilanShared.CompileFunctionOverride(pcc, classToUpdate, file, fl, usop, LOG_CATEGORY);
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
            pcc.Save(diskIOSyncLock: MilanShared.DiskIOSyncLock);
            MilanShared.AddGlobalCachedPackage(pcc);
            LE3FileLibCache.InitializeMPCommonFileLib(pcc);
            MilanShared.RefreshMilanFiles = true;
            return false;
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

        /// <summary>
        /// Package name prefixes tried, in order, when resolving a bare class name to a fully-qualified
        /// instanced full path. Shared between the reactive (compile-error-driven) and proactive
        /// (manifest-driven) resolution paths.
        /// </summary>
        private static readonly string[] CommonBasePackages =
        {
            null,
            "SFXGame",
            "SFXGameContent",
            "SFXGameMPContent",
        };

        private static bool AttemptToFindMissingClasses(MessageLog log, PackageCache cache, HashSet<string> discoveredAutoDonorClasses)
        {
            List<string> decompiledClasses = new List<string>();
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
                if (TryResolveAndDecompileClassByName(className, cache, "missing class"))
                {
                    decompiledClasses.Add(className);
                    discoveredAutoDonorClasses.Add(className);
                }
            }
            return decompiledClasses.Any();
        }

        /// <summary>
        /// Resolves a bare class name to a fully-qualified instanced full path by searching LE3 first, then
        /// falling back to ME3 for crossgen, across <see cref="CommonBasePackages"/>, and decompiles it into
        /// the autodonor folder (<see cref="MilanShared.GetAutoDonorClassesPath"/>) if found. Returns true if
        /// the class was located and decompiled.
        /// </summary>
        private static bool TryResolveAndDecompileClassByName(string className, PackageCache cache, string logContext)
        {
            foreach (var cbp in CommonBasePackages)
            {
                var ifp = cbp == null ? className : $"{cbp}.{className}";

                // Look in LE3 for donor
                var foundObjs = MilanShared.LE3ObjectDB.GetFilesContainingObject(ifp);
                if (foundObjs != null)
                {
                    foreach (var foundObj in foundObjs)
                    {
                        var sourceFileName = Path.GetFileName(foundObj);
                        var package = MilanShared.GetLE3Package(sourceFileName);

                        // DLC system Milan uses doesn't look in SP files
                        // So if obj database has SP stuff this will fail
                        // Just keep going.
                        if (package != null)
                        {
                            var export = package.FindExport(ifp);
                            if (export != null)
                            {
                                MilanLog.Information($@"Found {logContext} '{className}' in LE3: {foundObj}", customPrefix: LOG_CATEGORY);
                                DecompileClass(export, null, true, cache);
                                return true;
                            }

                            MilanLog.Warning($"Export did not reside in package, perhaps the wrong one was found? Could be overridden by DLC", customPrefix: LOG_CATEGORY);
                        }
                    }
                }

                // Looking ME3 for crossgen
                foundObjs = MilanShared.ME3ObjectDB.GetFilesContainingObject(ifp);
                if (foundObjs != null)
                {
                    foreach (var foundObj in foundObjs)
                    {
                        var sourceFileName = Path.GetFileName(foundObj);
                        var package = MilanShared.GetME3Package(sourceFileName);

                        // DLC system Milan uses doesn't look in SP files
                        // So if obj database has SP stuff this will fail
                        // Just keep going.
                        if (package != null)
                        {
                            var export = package.FindExport(ifp);
                            if (export != null)
                            {
                                MilanLog.Information($@"Found {logContext} '{className}' in ME3: {foundObj}", customPrefix: LOG_CATEGORY);
                                DecompileClass(export, null, true, cache);
                                return true;
                            }

                            MilanLog.Warning($"Export did not reside in package, perhaps the wrong one was found? Could be overridden by DLC", customPrefix: LOG_CATEGORY);
                        }
                    }
                }
            }

            return false;
        }

        /// <summary>
        /// Additional classes to hoist out of specific ME3 files and fold into BIOP_MP_COMMON, keyed by the
        /// ME3 source filename they should be pulled from. Use this for classes that are duplicated across
        /// many files (e.g. objective classes that every kit carries a copy of) but are otherwise identical -
        /// hoisting them here means they get decompiled/compiled once instead of once per file that has them.
        ///
        /// Only list classes here that are safe to share across every consumer (kit-local classes like
        /// character-specific animations/abilities should NOT be hoisted).
        /// </summary>
        private static readonly Dictionary<string, string[]> AdditionalHoistedClasses = new()
        {
            ["Asari_Adept_MP.pcc"] = new[]
            {
                // Objective classes are duplicated into every single kit's package.
                "SFXGameMPContent.SFXObjective_Disarm_Base",
                "SFXGameMPContent.SFXObjective_Retrieve_DropOffLocation",
                "SFXGameMPContent.SFXObjective_Retrieve_PickupObject",

                // Generic player mechanics (cover, melee reactions, evade, ladders, mantling, etc.) - identical
                // in every one of the 26 basegame kit files.
                "SFXGameContent.SFXCharacterClass_Content",
                "SFXGameContent.SFXCustomAction_ActivateWeaponFlashlight",
                "SFXGameContent.SFXCustomAction_CoverMeleeLeft",
                "SFXGameContent.SFXCustomAction_CoverMeleeRight",
                "SFXGameContent.SFXCustomAction_CoverSlipLookAt",
                "SFXGameContent.SFXCustomAction_FlinchBase",
                "SFXGameContent.SFXCustomAction_FlinchHeavy",
                "SFXGameContent.SFXCustomAction_FlinchLight",
                "SFXGameContent.SFXCustomAction_GapJump",
                "SFXGameContent.SFXCustomAction_HvyCoverMeleeLeft",
                "SFXGameContent.SFXCustomAction_HvyCoverMeleeRight",
                "SFXGameContent.SFXCustomAction_HvyStdCoverMeleeLeft",
                "SFXGameContent.SFXCustomAction_HvyStdCoverMeleeRight",
                "SFXGameContent.SFXCustomAction_JumpDown",
                "SFXGameContent.SFXCustomAction_KnockbackImpact",
                "SFXGameContent.SFXCustomAction_KnockbackImpactForward",
                "SFXGameContent.SFXCustomAction_KnockbackImpactLeft",
                "SFXGameContent.SFXCustomAction_KnockbackImpactRight",
                "SFXGameContent.SFXCustomAction_MantleLookAt",
                "SFXGameContent.SFXCustomAction_MantleMelee",
                "SFXGameContent.SFXCustomAction_Meleed",
                "SFXGameContent.SFXCustomAction_MeleedForward",
                "SFXGameContent.SFXCustomAction_MeleedLeft",
                "SFXGameContent.SFXCustomAction_MeleedRight",
                "SFXGameContent.SFXCustomAction_PistolMeleeOne",
                "SFXGameContent.SFXCustomAction_PistolMeleeThree",
                "SFXGameContent.SFXCustomAction_PistolMeleeTwo",
                "SFXGameContent.SFXCustomAction_PlayerCoverSlipLeft",
                "SFXGameContent.SFXCustomAction_PlayerCoverSlipLeftStanding",
                "SFXGameContent.SFXCustomAction_PlayerCoverSlipRight",
                "SFXGameContent.SFXCustomAction_PlayerCoverSlipRightStanding",
                "SFXGameContent.SFXCustomAction_PlayerEvadeBackwards",
                "SFXGameContent.SFXCustomAction_PlayerEvadeForward",
                "SFXGameContent.SFXCustomAction_PlayerEvadeLeft",
                "SFXGameContent.SFXCustomAction_PlayerEvadeRight",
                "SFXGameContent.SFXCustomAction_PlayerKnockbackImpact",
                "SFXGameContent.SFXCustomAction_PlayerLadderClimbDown",
                "SFXGameContent.SFXCustomAction_PlayerLadderClimbUp",
                "SFXGameContent.SFXCustomAction_PlayerMantleOverCover",
                "SFXGameContent.SFXCustomAction_PlayerMantleUp",
                "SFXGameContent.SFXCustomAction_PlayerMeleed",
                "SFXGameContent.SFXCustomAction_PlayerOnFire",
                "SFXGameContent.SFXCustomAction_PlayerStaggerImpact",
                "SFXGameContent.SFXCustomAction_PlayerStandardImpact",
                "SFXGameContent.SFXCustomAction_PlayerStandardImpactForward",
                "SFXGameContent.SFXCustomAction_PlayerStandardImpactLeft",
                "SFXGameContent.SFXCustomAction_PlayerStandardImpactRight",
                "SFXGameContent.SFXCustomAction_Reload",
                "SFXGameContent.SFXCustomAction_Revive",
                "SFXGameContent.SFXCustomAction_RifleMeleeOne",
                "SFXGameContent.SFXCustomAction_RifleMeleeThree",
                "SFXGameContent.SFXCustomAction_RifleMeleeTwo",
                "SFXGameContent.SFXCustomAction_SimpleMoveBase",
                "SFXGameContent.SFXCustomAction_StandingGapJump",
                "SFXGameContent.SFXCustomAction_StdCoverMeleeLeft",
                "SFXGameContent.SFXCustomAction_StdCoverMeleeRight",
                "SFXGameContent.SFXCustomAction_StdCoverSlipLookAt",
                "SFXGameContent.SFXCustomAction_StdSwatTurnLookAt",
                "SFXGameContent.SFXCustomAction_SwatTurnLookAt",
                "SFXGameContent.SFXCustomAction_SyncCoverGrab",
                "SFXGameContent.SFXCustomAction_SyncCoverMelee",
                "SFXGameContent.SFXGameEffect_DisableAI",
                "SFXGameContent.SFXGameEffect_PartBasedDamageBonus",
                "SFXGameContent.SFXGameEffect_WeaponWeightModifier",
                "SFXGameContent.SFXGameEffect_WeightCapacity",
                "SFXGameContent.SFXSeqEvt_PerformedMeleeOverCover",

                // MP-specific generic mechanics - also identical in every kit file.
                "SFXGameMPContent.SFXCharacterClass_ContentMP",
                "SFXGameMPContent.SFXCustomAction_DisarmObject",
                "SFXGameMPContent.SFXCustomAction_PickupRetrieveObject",
                "SFXGameMPContent.SFXCustomAction_PlayerStaggerMP",
                "SFXGameMPContent.SFXGameEffect_MatchConsumable_AmmoPower",
                "SFXGameMPContent.SFXGameEffect_MatchConsumable_AmmoPower_Cryo",
                "SFXGameMPContent.SFXGameEffect_MatchConsumable_AmmoPower_Disruptor",
                "SFXGameMPContent.SFXPowerCustomActionMP_ConsumableAmmoPower",
                "SFXGameMPContent.SFXPowerCustomActionMP_MeleePassiveBase",
                "SFXGameMPContent.SFXPowerCustomActionMP_PassiveBase",

                // Near-universal (present in all but a couple of kit files) - still worth hoisting out to avoid duplication.
                "SFXGameContent.SFXRumble_Power_HeavyImpact",
                "SFXGameContent.SFXShake_Power_HeavyImpact",
                "SFXGameContent.SFXProjectile_PowerCustomAction_SuperSeeking",
                "SFXGameContent.SFXWeapon_AssaultRifle_Avenger",
            },

            // SFXShield_Energy_Player is in another kit because asari have barriers not shields
            ["HumanFemale_Engineer_MP.pcc"] = new[]
            {
                "SFXGameContent.SFXShield_Energy_Player",
            },
        };

        /// <summary>
        /// Decompiles a class export, preferring an already-ported LE3 donor version of the class if one can
        /// be found (so we inherit any prior LE3 fixups), falling back to decompiling straight from the
        /// source (ME3) export otherwise.
        /// </summary>
        private static void DecompileClassPreferringLE3(ExportEntry classExp, PackageCache cache)
        {
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
                            return;
                        }
                    }
                }
            }

            DecompileClass(classExp, null, false, cache);
        }

        /// <summary>
        /// Decompiles the classes listed in <see cref="AdditionalHoistedClasses"/> out of their source ME3
        /// files and into the MPCommon loose class folder, so they get folded into BIOP_MP_COMMON instead of
        /// being duplicated in every file that otherwise carries them.
        /// </summary>
        private static void HoistAdditionalClasses(PackageCache cache)
        {
            foreach (var (fileName, classIfps) in AdditionalHoistedClasses)
            {
                MilanLog.Information($"Hoisting classes out of {fileName} --------------------", customPrefix: LOG_CATEGORY);
                var parsingPackage = MilanShared.GetME3Package(fileName);
                if (parsingPackage == null)
                {
                    MilanLog.Error($"Could not open {fileName} to hoist classes out of it", customPrefix: LOG_CATEGORY);
                    continue;
                }

                foreach (var ifp in classIfps)
                {
                    var classExp = parsingPackage.FindExport(ifp);
                    if (classExp == null)
                    {
                        MilanLog.Error($"Hoisted class not found in {fileName}: {ifp}", customPrefix: LOG_CATEGORY);
                        continue;
                    }

                    if (!ClassNeedsDecompiled(classExp))
                        continue;

                    DecompileClassPreferringLE3(classExp, cache);
                }
            }
        }

        /// <summary>
        /// Checked-in list of class names previously discovered by <see cref="AttemptToFindMissingClasses"/>
        /// and known to need decompiling into the autodonor folder. One class name per line.
        /// </summary>
        private static string GetAutoDonorManifestPath()
        {
            return Path.Combine(MilanShared.PipelineRoot, @"Shared", @"Compiling", @"LooseClasses", @"MPCommonAutoDonorManifest.txt");
        }

        private static HashSet<string> LoadAutoDonorManifest()
        {
            var path = GetAutoDonorManifestPath();
            if (!File.Exists(path))
                return new HashSet<string>(StringComparer.OrdinalIgnoreCase);

            return File.ReadAllLines(path)
                .Select(l => l.Trim())
                .Where(l => l.Length > 0 && !l.StartsWith("//"))
                .ToHashSet(StringComparer.OrdinalIgnoreCase);
        }

        private static void SaveAutoDonorManifest(IEnumerable<string> classNames)
        {
            var path = GetAutoDonorManifestPath();
            Directory.CreateDirectory(Path.GetDirectoryName(path)!);
            var sorted = classNames.Distinct(StringComparer.OrdinalIgnoreCase).OrderBy(x => x, StringComparer.OrdinalIgnoreCase);
            File.WriteAllLines(path, sorted);
        }

        /// <summary>
        /// Returns true if a class by this name already has a decompiled .uc file somewhere under the
        /// autodonor folder (regardless of which package folder it landed in).
        /// </summary>
        private static bool AutoDonorClassAlreadyDecompiled(string className)
        {
            return Directory.EnumerateFiles(MilanShared.GetAutoDonorClassesPath(), $"{className}.uc", SearchOption.AllDirectories).Any();
        }

        /// <summary>
        /// Pre-decompiles every class listed in the autodonor manifest directly into the autodonor folder,
        /// before the first compile attempt. This is what lets a fresh/clean build skip the slow
        /// discover-one-class-per-recompile loop in <see cref="AttemptToFindMissingClasses"/>: on a clean
        /// checkout the manifest already lists (almost) everything that loop would otherwise have to
        /// rediscover one class at a time, each rediscovery costing a full recompile of the growing loose
        /// class set. The reactive loop still runs afterwards as a safety net for anything the manifest
        /// doesn't yet know about (e.g. a new class introduced by a game update).
        /// </summary>
        private static void DecompileManifestedAutoDonorClasses(TieredPackageCache cache)
        {
            var manifest = LoadAutoDonorManifest();
            if (manifest.Count == 0)
                return;

            MilanLog.Information($"Pre-decompiling {manifest.Count} known autodonor dependencies from manifest", customPrefix: LOG_CATEGORY);
            Parallel.ForEach(manifest, new ParallelOptions() { MaxDegreeOfParallelism = Program.Settings.MaxThreads }, className =>
            {
                if (AutoDonorClassAlreadyDecompiled(className))
                    return;

                using var threadCache = cache.ChainNewCache(debugName: $"MPCommon manifested autodonor thread cache ({className})");
                if (!TryResolveAndDecompileClassByName(className, threadCache, "manifested class"))
                {
                    MilanLog.Warning($"  Manifested autodonor class '{className}' could not be resolved in LE3 or ME3 - it may have been renamed or removed upstream, dropping it from the manifest", customPrefix: LOG_CATEGORY);
                }
            });
        }

        /// <summary>
        /// Merges any classes discovered by the reactive loop this run into the autodonor manifest, then
        /// prunes entries that no longer appear to be referenced by anything else being compiled (a class
        /// that stopped being needed after a code change). Pruning is a heuristic textual reference scan,
        /// not a real dependency analysis - if it's ever wrong and drops something still needed, the
        /// reactive loop in <see cref="AttemptToFindMissingClasses"/> will simply rediscover and re-add it
        /// on the next run, at the cost of one extra recompile iteration. Classes pruned from the manifest
        /// are left on disk in the autodonor folder (only <see cref="Clean"/> removes them) so re-adding
        /// them later doesn't require decompiling again.
        /// </summary>
        private static void UpdateAutoDonorManifest(HashSet<string> discoveredThisRun)
        {
            var manifest = LoadAutoDonorManifest();
            var before = manifest.Count;
            manifest.UnionWith(discoveredThisRun);

            if (manifest.Count == 0)
                return;

            // Heuristic staleness scan: does any OTHER currently-compiled class still mention this class
            // name anywhere in its source? If not, nothing requires it to be part of the compile anymore.
            var allSources = GetMPCommonClassFiles()
                .Select(f => (FileName: Path.GetFileNameWithoutExtension(f), Text: File.ReadAllText(f)))
                .ToList();

            var pruned = new List<string>();
            foreach (var className in manifest.ToList())
            {
                var stillReferenced = allSources.Any(s =>
                    !s.FileName.Equals(className, StringComparison.OrdinalIgnoreCase) &&
                    Regex.IsMatch(s.Text, $@"\b{Regex.Escape(className)}\b"));

                if (!stillReferenced)
                {
                    manifest.Remove(className);
                    pruned.Add(className);
                }
            }

            if (pruned.Count > 0)
            {
                MilanLog.Information($"Pruning {pruned.Count} no-longer-referenced class(es) from autodonor manifest: {string.Join(", ", pruned)}", customPrefix: LOG_CATEGORY);
            }

            if (manifest.Count != before || pruned.Count > 0)
            {
                SaveAutoDonorManifest(manifest);
            }
        }

        /// <summary>
        /// Prepares classes for porting by reading their data out of ME3
        /// </summary>
        private static bool CompileMPCommon(MPCommonPipelineVars vars)
        {
            // NOTE: This cache is never explicitly Dispose()'d anywhere in this method - see memory investigation.
            var cache = TieredPackageCache.GetGlobalPackageCache(MEGame.ME3, false, true, debugName: "MPCommon global ME3 root").ChainNewCache(false, debugName: "MPCommon CompileMPCommon cache (NEVER DISPOSED)");
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

            MilanLog.LogDonorMessages = false; // Suppress spammy messages
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
                    DecompileClassPreferringLE3(classExp, cache);
                }
            }

            HoistAdditionalClasses(cache);
            DecompileManifestedAutoDonorClasses(cache);

            // Attempt compile
            var outPackage = Path.Combine(Program.Settings.OutputModPath, Path.Combine(vars.OutputPath, @"CookedPCConsole", MilanShared.MP_STARTUP_FILENAME));

            var discoveredAutoDonorClasses = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            while (CompileMPCommonPackage(outPackage, cache, discoveredAutoDonorClasses))
            {
                MilanLog.Information("Attempting recompile with new class data----------------------", customPrefix: LOG_CATEGORY);
            }

            MilanLog.LogDonorMessages = false; // Turn on donor messaging.

            if (!File.Exists(outPackage) || new FileInfo(outPackage).Length < 4096)
                return false;

            UpdateAutoDonorManifest(discoveredAutoDonorClasses);
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
                BaseFilesFileLib = classExp.Game == MEGame.LE3 ? LE3FileLibCache.GetBaseFilesFileLibFor(classExp.FileRef) : null,
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

        /// <summary>
        /// Path to the merge mod staging cache used by <see cref="MPMerge"/>. Self-cleared at the start of every
        /// MPMerge run, but included here too so Clean() remains the single source of truth for every
        /// MPCommon-owned on-disk cache.
        /// </summary>
        private static string GetMergeModStagingFolder()
        {
            return Path.Combine(MilanShared.PipelineRoot, @"Startups", @"MPCommon", @"MergeMod", @"Staging");
        }

        /// <summary>
        /// Deletes every on-disk cache owned by the MPCommon pipeline: decompiled MPCommon classes, decompiled
        /// autodonor dependency classes, and the merge mod staging cache. Does NOT touch hand-authored content
        /// such as MPCommonAdditionalClasses, FunctionOverride, MPCommonAddins, or InjectedFunctions.
        /// </summary>
        internal static void Clean()
        {
            MilanLog.Information("Cleaning MPCommon caches", customPrefix: LOG_CATEGORY);
            Utilities.DeleteFilesAndFoldersRecursively(GetMPClassesFolder(), deleteDirectoryItself: false);
            Utilities.DeleteFilesAndFoldersRecursively(MilanShared.GetAutoDonorClassesPath(), deleteDirectoryItself: false);
            Utilities.DeleteFilesAndFoldersRecursively(GetMergeModStagingFolder(), deleteDirectoryItself: false);
        }
    }
}
