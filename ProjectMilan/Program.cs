using System.Diagnostics;
using System.Timers;
using CommandLine;
using LegendaryExplorerCore;
using LegendaryExplorerCore.DebugTools;
using LegendaryExplorerCore.Helpers;
using LegendaryExplorerCore.Misc.ME3Tweaks;
using LegendaryExplorerCore.Packages;
using Newtonsoft.Json;
using ProjectMilan.MilanUDK;
using ProjectMilan.Pipelines;
using ProjectMilan.Pipelines.Audio;
using ProjectMilan.Pipelines.Finalize;
using ProjectMilan.Pipelines.Init;
using ProjectMilan.Pipelines.Kits;
using ProjectMilan.Pipelines.Levels;
using ProjectMilan.Pipelines.Mod;
using ProjectMilan.Pipelines.Mod.BaseDelta;
using ProjectMilan.Pipelines.Startups;
using ProjectMilan.Pipelines.Texture;
using ProjectMilan.Pipelines.Verify;
using ProjectMilan.Pipelines.VTables;
using ProjectMilan.Pipelines.Weapons;
using ProjectMilan.Settings;
using ProjectMilan.Utility;
using ProjectMilan_ExtraContent.Redemption;
using ProjectMilan_ExtraContent.Rejects;
using ProjectMilanCore;
using static ProjectMilanCore.ConsoleHelpers;
using Serilog;
using Timer = System.Timers.Timer;

// MAKE SURE YOU SET YOUR SETTINGS PATH IN YOUR RUN CONFIGURATION
// DO NOT EDIT OTHERS! MAKE YOUR OWN AND SET YOUR SETTINGS PATH.

namespace ProjectMilan
{
    /// <summary>
    /// Main entry point for Project Milan
    /// </summary>
    internal class Program
    {
        /// <summary>
        /// The loaded settings configuration
        /// </summary>
        public static IMilanSettings Settings;

        static void Main(string[] args)
        {
            // Parse command line options. If it succeeds, run the specified delegate
            Parser.Default.ParseArguments<CLIOptions>(args).WithParsed(Init);
        }

        private static Timer _keepAwakeTimer = new Timer(30 * 1000); // 30s interval

        /// <summary>
        /// For printing out at the end
        /// </summary>
        private static Dictionary<string, long> pipelineTimes = new();

        private static bool CreateCheckpointForThisRun;
        private static bool RestoreCheckpointForThisRun;


        /// <summary>
        /// Bump this every time there are changes to MPCommon or NonStartup pipelines. It will invalidate stale checkpoints.
        /// </summary>
        public const int MIN_CHECKPOINT_VERSION = 5;

        /// <summary>
        /// Prefix used for the console window title, so the current status is visible at a glance.
        /// </summary>
        private const string ConsoleTitlePostFix = "Project Milan";

        /// <summary>
        /// Initialize Project Milan
        /// </summary>
        /// <param name="obj"></param>
        private static void Init(CLIOptions obj)
        {
#if DEBUG
            // Change to true to run the research() method, for quick research tasks. Like LEX experiments.
            bool researchMode = obj.ResearchMode;
#else
            // DO NOT CHANGE.
            bool researchMode = false;
#endif

            SetConsoleTitle(ConsoleTitlePostFix, "Starting");
            MilanLog.CreateLogger();
            MilanLog.Information("Welcome to Project Milan");
            Settings = LoadSettingsConfig(obj);
            VerifySettings();

            if (!researchMode)
            {
                Console.WriteLine("-------------------------------");
                if (Program.Settings.ModInstallPreference == EModInstallPreference.Prompt)
                {

                    Console.WriteLine("Install mod when compiling completes [Y/N]? (5 second timeout)");
                    var input = ConsoleHelpers.ConsoleReadLineWithTimeout(TimeSpan.FromSeconds(5));
                    if ("Y".CaseInsensitiveEquals(input))
                    {
                        InstallModOnCompletion = true;
                        MilanLog.Information("Installing mod on completion of compile");
                    }
                }
                else
                {
                    InstallModOnCompletion = Program.Settings.ModInstallPreference == EModInstallPreference.Install;
                }


                if (Settings.UseCheckpointSystem)
                {
                    // Only ask to restore if the checkpoint folder actually exists
                    var checkpointFolder = Program.Settings.CheckpointFolder;
                    var checkpointExists = !string.IsNullOrWhiteSpace(checkpointFolder) && Directory.Exists(checkpointFolder);

                    if (checkpointExists)
                    {
                        // Read metadata version (missing or unreadable metadata = version 0)
                        var cpVersion = Checkpoint.ReadCheckpointVersion();
                        if (cpVersion < MIN_CHECKPOINT_VERSION)
                        {
                            Console.WriteLine("-------------------------------");
                            Console.WriteLine($"Existing checkpoint is outdated (version {cpVersion}, required {MIN_CHECKPOINT_VERSION}).\nUpdate checkpoint now? [Y/n]");
                            var input = Console.ReadLine();
                            if ("Y".CaseInsensitiveEquals(input) || string.IsNullOrWhiteSpace(input))
                            {
                                CreateCheckpointForThisRun = true;
                                MilanLog.Information("Checkpoint update requested; will create a new checkpoint during this run.");

                                // The checkpoint is stale because MPCommon/NonStartup code changed (that's what bumps
                                // MIN_CHECKPOINT_VERSION), so dump their on-disk caches to force a fully clean
                                // regeneration instead of reusing decompiled classes from before the change.
                                MPCommon.Clean();
                                NonStartupPipeline.Clean();
                            }
                            else
                            {
                                MilanLog.Warning("User chose not to update the checkpoint.");
                            }
                        }
                        else
                        {
                            Console.WriteLine("-------------------------------");
                            Console.WriteLine("Use existing checkpoint and skip pre-NonStartup pipelines [Y/n]? (5 second timeout)");
                            var input = ConsoleHelpers.ConsoleReadLineWithTimeout(TimeSpan.FromSeconds(5));
                            if ("N".CaseInsensitiveEquals(input))
                            {
                                RestoreCheckpointForThisRun = false;
                                MilanLog.Information("Not using checkpoint for this run");
                            }
                            else
                            {
                                RestoreCheckpointForThisRun = true;
                                MilanLog.Information("Using checkpoint for this run");
                            }
                        }
                    }

                    // Always ask whether to create a checkpoint after NonStartup (unless user already chose to update/restore)
                    if (!CreateCheckpointForThisRun && !RestoreCheckpointForThisRun)
                    {
                        Console.WriteLine("-------------------------------");
                        Console.WriteLine("Create checkpoint after NonStartup [y/N]? (5 second timeout)");
                        var input = ConsoleHelpers.ConsoleReadLineWithTimeout(TimeSpan.FromSeconds(5));
                        if ("Y".CaseInsensitiveEquals(input))
                        {
                            CreateCheckpointForThisRun = true;
                            MilanLog.Information("Checkpoint creation enabled for this run");
                        }
                    }
                }
            }

            if (!researchMode)
            {
                // Cleanup output directory before we start
                if (!Settings.DontDeleteModFolder)
                {
                    if (Directory.Exists(Settings.OutputModPath))
                    {
                        Utilities.DeleteFilesAndFoldersRecursively(Settings.OutputModPath,
                            deleteDirectoryItself: false);
                    }
                    else
                    {
                        Directory.CreateDirectory(Settings.OutputModPath);
                    }

                    // Also clean out MilanDelta so a fresh build doesn't ship a stale patch/manifest
                    // (e.g. from a renamed or removed target) alongside the new ones.
                    if (Directory.Exists(BaseDeltaHandler.MilanDeltaFolder))
                    {
                        Utilities.DeleteFilesAndFoldersRecursively(BaseDeltaHandler.MilanDeltaFolder,
                            deleteDirectoryItself: false);
                    }
                }

                // Comment this out when we don't want to clean
                // CleanupMilan();
            }

        lec:
            // Initialize LEC
            LegendaryExplorerCoreLib.InitLib(TaskScheduler.Current, x => MilanLog.Error($"Error saving package: {x}"), Log.Logger, objectDBsToLoad: [MEGame.ME3, MEGame.LE3]);
            MEPackageHandler.GlobalSharedCacheEnabled = false; // Do not use package cache

#if DEBUG
            LECLog.LogDebug = true;
            // For research methods
            if (researchMode)
            {
                RunResearch();
                return;
            }
#endif

            try
            {
                SystemSleepManager.PreventSleep("Compiling");
                _keepAwakeTimer.Elapsed += keepSystemAwake;
                _keepAwakeTimer.Start();
                RunPipelines();
            }
            finally
            {
                _keepAwakeTimer.Elapsed -= keepSystemAwake;
                _keepAwakeTimer.Stop();
                SystemSleepManager.AllowSleep();
            }
        }

        /// <summary>
        /// Deletes files that can be safely deleted
        /// </summary>
        public static void CleanupMilan()
        {
            MPCommon.Clean();
            AudioPipeline.Clean();
        }

        public static bool InstallModOnCompletion { get; set; }

        private static void keepSystemAwake(object sender, ElapsedEventArgs e)
        {
            SystemSleepManager.PreventSleep(@"Compiling");
        }


        private static void VerifySettings()
        {
            if (Settings.OutputModPath == null || Path.GetFileName(Settings.OutputModPath) != MilanShared.DLC_NAME)
            {
                MilanLog.Error($"Output directory must be named '{MilanShared.DLC_NAME}', point it to the DLC mod folder in your M3 mod library. Invalid value: {Path.GetFileName(Settings.OutputModPath)})");
                Environment.Exit(1);
                return;
            }

            var moddescCheck = Path.Combine(Settings.OutputModPath, "..", "moddesc.ini");
            if (!File.Exists(moddescCheck))
            {
                MilanLog.Error($"Must point your settings at your mod library version of the DLC folder! Make sure you import the template from July 1 2024 (or newer) in #links.");
                Environment.Exit(1);
            }

            // Set up UDK dependencies here
            if (Program.Settings.IsStaticLightingBuild)
            {
                UDKSetup.EnsureUDK();
            }

            // Map settings into Core library.
            MilanPipelinesShared.OutputModPath = Settings.OutputModPath;
        }

        private static IMilanSettings LoadSettingsConfig(CLIOptions cliOptions) => cliOptions.Config.ToLower() switch
        {
            "mgamerz" => new MilanSettingsMgamerz(),
            "sircxyrtyx" => new MilanSettingsSirCxyrtyx(),
            "kinkojiro" => new MilanSettingsKinkojiro(),
            "henbagle" => new MilanSettingsHenBagle(),
            "d00t" => new MilanSettingsd00t(),
            "dropthesquid" => new MilanSettingsDropTheSquid(),
            "beccatoria" => new MilanSettingsbeccatoria(),
            "stumpy" => new IMilanSettingsStumpy(),
            _ => throw new Exception($"Undefined configuration: {cliOptions.Config}")
        };

        static void RunPipelines()
        {
            MilanInit.Init(); // Initialize shared pipeline data

            // You can uncomment these (along with DontDeleteModFolder) to skip to a specific step.
            //goto licensee;

            // TD conversation - do not commit
            //RunPipeline(true, MaterialExpressionPipeline.RunPipeline, "MaterialExpression");
            //return;

            if (RestoreCheckpointForThisRun)
            {
                SetConsoleTitle(ConsoleTitlePostFix, "Restoring checkpoint");
                if (Checkpoint.RestoreCheckpoint())
                {
                    BaseDeltaHandler.PrepareForCheckpointRestore();

                    // MPCommon.RunPipeline is skipped on this path (its output was already captured
                    // into the checkpoint), so nothing has loaded BIOP_MP_COMMON.pcc into memory or
                    // built the shared MPCommon FileLib tier yet - do that now instead.
                    var restoredMpCommonPath = Path.Combine(MilanPipelinesShared.OutputModPath, "CookedPCConsole", MilanShared.MP_STARTUP_FILENAME);
                    if (File.Exists(restoredMpCommonPath))
                    {
                        var restoredMpCommonPkg = MEPackageHandler.OpenMEPackage(restoredMpCommonPath);
                        MilanShared.AddGlobalCachedPackage(restoredMpCommonPkg);
                        LE3FileLibCache.InitializeMPCommonFileLib(restoredMpCommonPkg);
                    }

                    // HATE goto statements
                    // But it makes it less ugly here...
                    goto postMpCommon;
                }

                MilanLog.Error("Could not use checkpoint; continuing with full pipeline run.");
            }

            // Build/cache patch targets (e.g. SFXGame) before anything that might import from them.
            BaseDeltaHandler.PrepareForFreshBuild(CreateCheckpointForThisRun);

            // Pre-build pipelines
            RunPipeline(true, ModBuilder.RunPipeline, "ModBuild"); // This is always run

            RunPipeline(Settings.RunMPCommonPipeline, MPCommon.RunPipeline, "MPCommon"); // Builds the BIOP_MP_COMMON package that is used by all BioP_MP files
            RunPipeline(Settings.RunNonStartupPipeline, NonStartupPipeline.RunPipeline, "NonStartup"); // Ports packages that are not kits, levels, BIOP_MP_COMMON, etc. Things like images, objectives
            if (CreateCheckpointForThisRun && Settings.RunNonStartupPipeline)
            {
                Checkpoint.CreateCheckpoint();
            }
            // goto end;

        postMpCommon:
            // Content build pipelines

            if (!MilanShared.EnsureMPCommonInGame(out var mpCommonPath)) // These require BIOP_MP_COMMON
                return;
            MilanShared.InstallMPCommonClassInfo(mpCommonPath);
            MilanShared.PromoteMPCommonIntoCacheChain(); // BIOP_MP_COMMON now exists on disk - splice it into the shared cache chain (Global -> MPCommon -> Warm) before content pipelines run

            // Content pipelines will use the milan ME3 cache
            MilanShared.EnsureTFCsAvailable();
            MilanShared.EnsureAFCsAvailable();
            if (Settings.RunAudioPipeline)
            {
                AudioPipeline.EnsureWwise7110();
            }

            // skip to pipeline you want
            //goto levelBuild;

        kitsBuild:
            RunPipeline(Settings.RunKitsPipeline, MPKits.RunPipeline, "Kits"); // Builds character packages
        weaponsBuild:
            RunPipeline(Settings.RunWeaponsPipeline, SFXWeapons.RunPipeline, "Weapons"); // Builds DLC weapon packages

            // This pipeline must come after weapons as it depends on Collector SMG.
            if (Settings.RunWeaponsPipeline)
            {
                RunPipeline(Settings.RunMP4EnemiesPipeline, MP4NewEnemiesPipeline.RunPipeline, "MP4Enemies"); // Ports MP4 enemies that need custom code handling
            }
            else if (Settings.RunMP4EnemiesPipeline)
            {
                MilanLog.Error(@"MP4Enemies pipeline cannot run without SFXWeapons, pipeline being skipped.");
            }

        levelBuild:
            RunPipeline(Settings.RunLevelsPipeline, MPLevels.RunPipeline, "Levels"); // Builds level packages

        rejectionBuild:
            RunPipeline(Settings.RunRejectionPipeline, RejectsPipeline.RunPipeline, "Rejection"); // Builds Rejection Enemies
        redemptionBuild:
            RunPipeline(Settings.RunRedemptionPipeline, RedemptionPipeline.RunPipeline, "Redemption"); // Builds Redemption Maps


            // MIDWAY POINT - We should no longer be porting content, so we can
            // drop some caches to release memory.
            MilanShared.DropPortingCaches();


            // Post-build pipelines
            RunPipeline(Settings.RunTexturePipeline, TFCBuild.RunPipeline, "Texture"); // Performs TFC compaction and texture upgrades

        audio:
            RunPipeline(Settings.RunAudioPipeline, AudioPipeline.RunPipeline, "Audio"); // Converts audio



            // Drop all extra packages from database. Conformance depends on vanilla DB.
            MilanShared.UnregisterObjectDBPackages();

        resynthesis:
            // Package resynthesis
            RunPipeline(Settings.RunResynthesis, ModResynthesis.RunPipeline, "Resynthesis");

        shaders:
            // Shader install
            RunPipeline(Settings.RunShaderPipeline, ShaderPipeline.RunPipeline, "Shaders");

            // Fix up vtables.
        vtables:
            RunPipeline(true, VTablePipeline.RunPipeline, "VTables");

            // Conformance
        conformance:
            if (Settings.RunConformancePipeline)
            {
                RunPipeline(true, Conformance.RunPipeline, "Conformance");
            }


            // Verification
            RunPipeline(true, VerifyMod.RunPipeline, "Verify");

        licensee:
            // Licensee conversion
            // Don't enable until we get stuff working in LEX
            RunPipeline(true, LicenseePipeline.RunPipeline, "Licensee");

            // Patch for multi instance
            MultiInstance.PatchForMultiInstance();

        end:
            // The build succeeded end-to-end - safe to publish the BaseDelta patches + manifest now.
            BaseDeltaHandler.WriteMilanDeltaOutput();

            PrintSummaryInformation();

            if (InstallModOnCompletion)
                ModManagerIntegration.RequestModInstallation(Path.Combine(Settings.OutputModPath, "..", "moddesc.ini"));

            SetConsoleTitle(ConsoleTitlePostFix, "Build complete");
        }

        private static void PrintSummaryInformation()
        {
            // Timings
            MilanLog.Information($"Pipeline timings:");
            foreach (var stat in pipelineTimes)
            {
                MilanLog.Information($"\t{stat.Key.PadRight(pipelineTimes.Keys.MaxBy(x => x.Length).Length + 3)}{stat.Value / 1000}s");
            }
            MilanLog.Information($"\tTotal:\t{pipelineTimes.Sum(x => x.Value) / 1000}s");

            // Tiered cache usage
#if DEBUG
            MilanLog.Information($"TieredPackageCache HeatMap for multiple same-file loads");
            var gameMap = TieredPackageCache.StaticTieredHeatMap[MEGame.LE3];
            var padWidth = gameMap.Values.Max() + 3;

            foreach (var heatIndex in gameMap.OrderByDescending(x => x.Value))
            {
                if (heatIndex.Value == 1)
                    continue; // These don't provide any benefit.
                MilanLog.Information($"\t{heatIndex.Key.PadRight(padWidth)}{heatIndex.Value} loads");

            }

            DumpHeatMapCallStacks();
#endif

            DumpAliveCacheReport();
        }

        /// <summary>
        /// Logs every <see cref="PackageCache"/> (including <see cref="TieredPackageCache"/>) that is still reachable
        /// (i.e. not yet garbage collected) at this point in the run, along with whether it was ever Dispose()'d and
        /// how many packages it's currently holding onto. Caches that are NOT disposed and still hold packages are
        /// the ones worth investigating for memory leaks - use their debug name to trace back to the code that
        /// created them. A full dump (including every cached package path) is written to a JSON file alongside the
        /// summary log line for detailed inspection.
        /// </summary>
        private static void DumpAliveCacheReport()
        {
            // Force a full collection first so anything that's merely pending finalization (properly disposed and
            // fully dereferenced) doesn't show up as noise - what's left after this is either still rooted
            // somewhere, or legitimately still alive.
            GC.Collect();
            GC.WaitForPendingFinalizers();
            GC.Collect();

            var report = PackageCache.GetTrackedCacheReport();
            if (report.Count == 0)
                return;

            MilanLog.Information($"PackageCache alive/disposed report ({report.Count} caches still reachable):");
            foreach (var info in report.OrderByDescending(x => x.PackageCount))
            {
                if (info.PackageCount == 0 && info.IsDisposed)
                    continue; // Nothing interesting to report - cleanly disposed and empty.

                MilanLog.Information($"\t[{(info.IsDisposed ? "DISPOSED" : "ALIVE")}] {info.DebugName} ({info.TypeName}, {info.Guid}) - {info.PackageCount} packages cached");
            }

            var outPath = Path.Combine(Settings.OutputModPath, "AliveCacheReport.json");
            File.WriteAllText(outPath, JsonConvert.SerializeObject(report, Formatting.Indented));
            MilanLog.Information($"Wrote full PackageCache alive/disposed report to {outPath}");
        }

#if DEBUG
        /// <summary>
        /// Writes out the call stacks that caused each repeated TieredPackageCache disk load, so a hot file can be traced back to what keeps opening it.
        /// </summary>
        private static void DumpHeatMapCallStacks()
        {
            var result = new Dictionary<string, Dictionary<string, object>>();
            foreach (var (game, fileMap) in TieredPackageCache.StaticTieredHeatMapCallStacks)
            {
                var gameResult = new Dictionary<string, object>();
                foreach (var (fname, traceCounts) in fileMap)
                {
                    var totalLoads = traceCounts.Values.Sum();
                    if (totalLoads <= 1)
                        continue; // Only loaded once - not useful for tracking down repeat loads.

                    gameResult[fname] = new
                    {
                        totalLoads,
                        callStacks = traceCounts.OrderByDescending(x => x.Value)
                            .Select(x => new { count = x.Value, stackTrace = x.Key })
                            .ToList()
                    };
                }

                if (gameResult.Count > 0)
                    result[game.ToString()] = gameResult;
            }

            if (result.Count == 0)
                return;

            var outPath = Path.Combine(Settings.OutputModPath, "TieredCacheHeatMapCallStacks.json");
            File.WriteAllText(outPath, JsonConvert.SerializeObject(result, Formatting.Indented));
            MilanLog.Information($"Wrote TieredPackageCache call stack heatmap to {outPath}");
        }
#endif

        /// <summary>
        /// Runs a single pipeline
        /// </summary>
        /// <param name="shouldRunPipeline"></param>
        /// <param name="runPipeline"></param>
        /// <param name="pipelineName"></param>
        /// <exception cref="NotImplementedException"></exception>
        private static void RunPipeline(bool shouldRunPipeline, Action runPipeline, string pipelineName)
        {
            if (shouldRunPipeline)
            {
                MilanLog.Information($"Running pipeline: {pipelineName}");
                SetConsoleTitle(ConsoleTitlePostFix, $"Running {pipelineName}");
                Stopwatch sw = Stopwatch.StartNew();
                runPipeline();
                MilanShared.DropMissingObjectCaches(); // Unbounded for the whole process otherwise - flush between pipelines so they don't accumulate all run.
                sw.Stop();
                MilanLog.Information($"Pipeline finished: {pipelineName} took {sw.ElapsedMilliseconds}ms");
                pipelineTimes[pipelineName] = sw.ElapsedMilliseconds;
                GC.Collect();
            }
            else
            {
                MilanLog.Information($"Skipping pipeline: {pipelineName}, not selected for running in settings");
            }
        }

        private static void RunResearch()
        {
#if DEBUG

            DynamicMixinResearch.RunDynamicMixinInventory(@"B:\UserProfile\Desktop\dynamicmixins.csv", @"B:\UserProfile\Desktop\dynamicmixins_inventory.json");
            return;

            Research.TestBuildLavaTerrainSetup();
            return;
            Research.TestBuildTerrainPackage();
            return;
            // Put your method in Research class and call it here.
            //Research.CopyPreview2();
            //return;
            Research.GetMissingShaderPackages(@"S:\SteamLibrary\steamapps\common\Mass Effect Legendary Edition\Game\LMP\BioGame\DLC\DLC_MOD_PMR3\CookedPCConsole\Levels");
            return;

            Research.InstallCompiledShaders(force: true);// @"S:\SteamLibrary\steamapps\common\Mass Effect Legendary Edition\Game\LMP\BioGame\DLC\DLC_MOD_PMR3\CookedPCConsole\Levels\BioP_MPPSTropical");
            return;

            //return;
            //Research.SlashShaderCache(MEGame.LE3);
            //return;
            //Research.TestSFARTextureDecompression();
            //return;
            //Research.GenerateLightingForLevel();
            //return;
            // Research.ImportStaticLightingForLevel();
            return;
            // Research.TestTextureToInstancesMap();
            // Research.DumpRefShaderNames();
            //UDKSetup.DecookGameToUDK();
            //MELoadedFiles.InvalidateCaches();
            //UDKSetup.TestConvertToUDK();
            //UDKSetup.TestFixingUDKCrash();

            //UDKSetupT3D.GeneratePackageInfos();

            //Research.GeneratePerPackageNesting();
            //UDKSetupT3D.DecookME3MPDLC();
            //UDKSetupT3D.CompileT3Ds();
            // UDKSetupT3D.ConvertAssetsToUDK();
            //Research.LightingBake();
            // Research.ScanForShaderCompPackages();
            Research.InstallCompiledShaders();
#endif
        }
    }
}