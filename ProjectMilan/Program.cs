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
using ProjectMilan.Pipelines.TLK;
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
using ProjectMilan.Pipelines.Shaders;
using ProjectMilan.Pipelines.StaticLighting;

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

        /// <summary>
        /// If static lighting should be baked in UDK this run. A production build always bakes, regardless of
        /// <see cref="IMilanSettings.IsStaticLightingBuild"/>. Check this rather than the setting directly.
        /// </summary>
        public static bool BuildStaticLighting => Settings.IsStaticLightingBuild || Settings.ProductionBuild;

        /// <summary>Keep exported UDK maps before Lightmass changes them during a static lighting build.</summary>
        public static bool KeepPreBakeMaps { get; private set; }

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

        /// <summary>
        /// Pipeline to create a checkpoint at once it finishes, or <see cref="ECheckpointStage.None"/> to not create one.
        /// </summary>
        private static ECheckpointStage CreateStage;

        /// <summary>
        /// Pipeline a restored checkpoint covers - every pipeline up to and including this one is skipped -
        /// or <see cref="ECheckpointStage.None"/> when not restoring.
        /// </summary>
        private static ECheckpointStage RestoreStage;

        /// <summary>
        /// The pipelines a checkpoint can be taken at, in run order, paired with the setting that decides
        /// whether each one runs. Drives the checkpoint stage menu and the "your checkpoint won't contain X"
        /// warnings; <see cref="RunPipelines"/> still gates each pipeline with the same setting inline, and
        /// <see cref="RunPipeline(ECheckpointStage,bool,Action,string)"/> asserts the two agree.
        /// </summary>
        private static readonly (ECheckpointStage Stage, string Name, Func<bool> Enabled)[] CheckpointStages =
        [
            (ECheckpointStage.MPCommon, "MPCommon", () => Settings.RunMPCommonPipeline),
            (ECheckpointStage.NonStartup, "NonStartup", () => Settings.RunNonStartupPipeline),
            (ECheckpointStage.Kits, "Kits", () => ShouldRunKitsPipeline),
            (ECheckpointStage.Weapons, "Weapons", () => ShouldRunWeaponsPipeline),
            (ECheckpointStage.MP4Enemies, "MP4Enemies", () => ShouldRunWeaponsPipeline && Settings.RunMP4EnemiesPipeline),
            (ECheckpointStage.Levels, "Levels", () => ShouldRunLevelsPipeline),
            (ECheckpointStage.Rejection, "Rejection", () => Settings.RunRejectionPipeline),
            (ECheckpointStage.Redemption, "Redemption", () => Settings.RunRedemptionPipeline),
            (ECheckpointStage.Texture, "Texture", () => Settings.RunTexturePipeline),
        ];

        /// <summary>
        /// The stages a checkpoint may be created at this run: all of <see cref="CheckpointStages"/>, except
        /// <see cref="ECheckpointStage.Texture"/> for a production build.
        /// </summary>
        private static (ECheckpointStage Stage, string Name, Func<bool> Enabled)[] OfferedCheckpointStages =>
            CheckpointStages.Where(x => x.Stage != ECheckpointStage.Texture || !Settings.ProductionBuild).ToArray();

        /// <summary>
        /// A production build always builds kits, regardless of <see cref="IMilanSettings.RunKitsPipeline"/>.
        /// </summary>
        private static bool ShouldRunKitsPipeline => Settings.RunKitsPipeline || Settings.ProductionBuild;

        /// <summary>
        /// A production build always builds weapons, regardless of <see cref="IMilanSettings.RunWeaponsPipeline"/>.
        /// </summary>
        private static bool ShouldRunWeaponsPipeline => Settings.RunWeaponsPipeline || Settings.ProductionBuild;

        /// <summary>
        /// A production build always builds levels, regardless of <see cref="IMilanSettings.RunLevelsPipeline"/>.
        /// </summary>
        private static bool ShouldRunLevelsPipeline => Settings.RunLevelsPipeline || Settings.ProductionBuild;

        /// <summary>
        /// Pipelines that publish process-global in-memory state which later pipelines depend on. When a
        /// restored checkpoint means one of these never runs, its output is on disk but nothing has loaded
        /// it into memory, so the registration has to be replayed instead. Every other pipeline is disk-only
        /// and needs no entry here - if you add a global registration to one, add it here too.
        /// </summary>
        private static readonly Dictionary<ECheckpointStage, Action> CheckpointRehydrators = new()
        {
            [ECheckpointStage.ModBuild] = ModBuilder.RehydrateFromCheckpoint,
            [ECheckpointStage.MPCommon] = MPCommon.RehydrateFromCheckpoint,
            [ECheckpointStage.NonStartup] = NonStartupPipeline.RehydrateFromCheckpoint,
            [ECheckpointStage.Weapons] = SFXWeapons.RehydrateFromCheckpoint,
        };


        /// <summary>
        /// Bump this every time there are changes to a pipeline that can be checkpointed (MPCommon through
        /// Redemption - see <see cref="ECheckpointStage"/>). It invalidates every existing checkpoint,
        /// regardless of which stage it was taken at, forcing a complete rebuild.
        /// </summary>
        public const int MIN_CHECKPOINT_VERSION = 9; // 9: BaseDelta gained the Startup.pcc target (Scaleform UI) and SFXGame PropertyUpdate (GUI WwiseBank), which older checkpoints' patches don't contain. 8: Levels checks its image references against the built image packages (MilanWavelist\Wavelists\Coalition), which older NonStartup checkpoints don't contain. 7: NonStartup builds GUI_Images_MP* image packages and registers the online banners/store packs, and checkpoints now carry their dynamically assigned TLK strings - old checkpoints have none of these

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
            KeepPreBakeMaps = obj.KeepPreBakeMaps;
#if DEBUG
            // Change to true to run the research() method, for quick research tasks. Like LEX experiments.
            bool researchMode = obj.ResearchMode;
#else
            // DO NOT CHANGE.
            bool researchMode = false;
#endif

            SetConsoleTitle(ConsoleTitlePostFix, "Starting");
            MilanLog.CreateLogger();

            // An unhandled exception otherwise only reaches the console, which is gone once the window closes.
            AppDomain.CurrentDomain.UnhandledException += (_, e) =>
            {
                if (e.ExceptionObject is Exception ex)
                    MilanLog.Exception(ex, "Unhandled exception - Project Milan is exiting", fatal: true);
                else
                    MilanLog.Fatal($"Unhandled exception - Project Milan is exiting: {e.ExceptionObject}");
                MilanLog.LogSessionSummary();
                MilanLog.CloseAndFlush();
            };

            MilanLog.Information("Welcome to Project Milan");
            Settings = LoadSettingsConfig(obj);

            // A read-only report. It runs before VerifySettings, which sets up UDK for lighting builds, and
            // returns before anything below cleans the output folder.
            if (obj.CompareLighting?.Any() == true)
            {
                LegendaryExplorerCoreLib.InitLib(TaskScheduler.Current, x => MilanLog.Error($"Error saving package: {x}"), Log.Logger);
                MEPackageHandler.GlobalSharedCacheEnabled = false;
                LightmapComparison.Run(obj.CompareLighting,
                    obj.CompareLightingLevels ?? Path.Combine(Settings.OutputModPath, "CookedPCConsole", "Levels"),
                    Path.Combine(Path.GetDirectoryName(Settings.OutputModPath)!, "LightingReports"),
                    obj.CompareLightingME3);
                MilanLog.CloseAndFlush();
                return;
            }

            VerifySettings();
            if (KeepPreBakeMaps && !BuildStaticLighting)
                MilanLog.Warning("--keep-prebake-maps has no effect because IsStaticLightingBuild is disabled in this configuration.");
            if (Settings.ProductionBuild)
                MilanLog.Information("PRODUCTION BUILD: all kits, weapons and levels will be built, lighting baked at Production quality");

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


                if (Settings.UseCheckpointSystem || Settings.ProductionBuild)
                {
                    // Only ask to restore if the checkpoint folder actually exists
                    var checkpointFolder = Program.Settings.CheckpointFolder;
                    var checkpointExists = !string.IsNullOrWhiteSpace(checkpointFolder) && Directory.Exists(checkpointFolder);

                    if (Settings.ProductionBuild)
                    {
                        ConfigureProductionCheckpoint(checkpointExists);
                    }
                    else if (checkpointExists)
                    {
                        // Missing or unreadable metadata reads back as version 0, so it fails the check below.
                        var checkpointInfo = Checkpoint.ReadCheckpointMetadata();
                        if (checkpointInfo.Version < MIN_CHECKPOINT_VERSION)
                        {
                            Console.WriteLine("-------------------------------");
                            Console.WriteLine($"Existing checkpoint is outdated (version {checkpointInfo.Version}, required {MIN_CHECKPOINT_VERSION}).");
                            Console.WriteLine($"It was taken at the {checkpointInfo.Stage} pipeline{DescribeCheckpointAge(checkpointInfo.CreatedUtc)}.");
                            Console.WriteLine("Update checkpoint now? [Y/n]");
                            var input = Console.ReadLine();
                            if ("Y".CaseInsensitiveEquals(input) || string.IsNullOrWhiteSpace(input))
                            {
                                // Default the menu to the stage the stale checkpoint used, since that's
                                // almost always what the user wants to end up with again.
                                CreateStage = PromptForCheckpointStage(checkpointInfo.Stage);
                                MilanLog.Information($"Checkpoint update requested; will create a new checkpoint at the {CreateStage} pipeline during this run.");

                                // The checkpoint is stale because pipeline code changed (that's what bumps
                                // MIN_CHECKPOINT_VERSION), so dump the on-disk caches to force a fully clean
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
                            Console.WriteLine($"Existing checkpoint was taken at the {checkpointInfo.Stage} pipeline{DescribeCheckpointAge(checkpointInfo.CreatedUtc)}.");
                            Console.WriteLine($"Use it and skip all pipelines through {checkpointInfo.Stage} [Y/n]? (5 second timeout)");
                            var input = ConsoleHelpers.ConsoleReadLineWithTimeout(TimeSpan.FromSeconds(5));
                            if ("N".CaseInsensitiveEquals(input))
                            {
                                MilanLog.Information("Not using checkpoint for this run");
                            }
                            else
                            {
                                RestoreStage = checkpointInfo.Stage;
                                MilanLog.Information($"Using checkpoint for this run; skipping all pipelines through {RestoreStage}");
                                WarnAboutPipelinesMissingFromCheckpoint(checkpointInfo);

                                // The one case where a run restores and creates: retaking the checkpoint after the
                                // texture pipeline, so it doesn't need a full rebuild to get one.
                                if (RestoreStage < ECheckpointStage.Texture && Settings.RunTexturePipeline)
                                {
                                    Console.WriteLine("-------------------------------");
                                    Console.WriteLine("Replace the checkpoint with one taken after the Texture pipeline [y/N]? (5 second timeout)");
                                    var retake = ConsoleHelpers.ConsoleReadLineWithTimeout(TimeSpan.FromSeconds(5));
                                    if ("Y".CaseInsensitiveEquals(retake))
                                    {
                                        CreateStage = ECheckpointStage.Texture;
                                        MilanLog.Information("Will replace the checkpoint with one taken after the Texture pipeline");
                                    }
                                }
                            }
                        }
                    }

                    // Always ask whether to create a checkpoint (unless the user already chose to update/restore).
                    // A run either restores or creates, never both.
                    if (!Settings.ProductionBuild && CreateStage == ECheckpointStage.None && RestoreStage == ECheckpointStage.None)
                    {
                        Console.WriteLine("-------------------------------");
                        Console.WriteLine("Create a checkpoint during this run [y/N]? (5 second timeout)");
                        var input = ConsoleHelpers.ConsoleReadLineWithTimeout(TimeSpan.FromSeconds(5));
                        if ("Y".CaseInsensitiveEquals(input))
                        {
                            CreateStage = PromptForCheckpointStage(ECheckpointStage.NonStartup);
                            MilanLog.Information($"Checkpoint creation enabled for this run at the {CreateStage} pipeline");
                        }
                    }

                    // The converted-WEM cache is keyed by source ID alone and records nothing about which tools
                    // produced each entry, so anything converted under an older toolchain (e.g. the wrong ww2ogg
                    // codebook pack) survives every "clean" build forever and ships corrupt audio. Purging it
                    // forces every WEM to be reconverted, which is slow - so a production build always does it
                    // (that's the build that would actually ship the bad audio), while a dev build only does it
                    // on request, since most dev runs aren't touching audio at all.
                    if (Settings.ProductionBuild)
                    {
                        MilanLog.Information("Production build: purging the converted-WEM cache so audio is regenerated from source");
                        AudioPipeline.Clean();
                    }
                    else if (RestoreStage == ECheckpointStage.None)
                    {
                        Console.WriteLine("-------------------------------");
                        Console.WriteLine("Purging the converted-WEM cache reconverts all audio from source. Slow, but it's the");
                        Console.WriteLine("only way to clear audio that was converted by an older or broken toolchain.");
                        Console.WriteLine("Purge the converted-WEM cache [y/N]? (5 second timeout)");
                        var input = ConsoleHelpers.ConsoleReadLineWithTimeout(TimeSpan.FromSeconds(5));
                        if ("Y".CaseInsensitiveEquals(input))
                        {
                            MilanLog.Information("Purging the converted-WEM cache so audio is regenerated from source");
                            AudioPipeline.Clean();
                        }
                        else
                        {
                            MilanLog.Information("Keeping the converted-WEM cache for this run");
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
        /// TEMP - while iterating on the Levels pipeline (lighting bakes). When true, production builds take their
        /// checkpoint right before Levels instead of at the last stage, and offer to restore an up-to-date
        /// production checkpoint taken before Levels, so each attempt doesn't rebuild kits/weapons/etc. Set back to
        /// false for real release builds, which must build everything from scratch.
        /// </summary>
        private const bool ProductionCheckpointBeforeLevels = false;

        /// <summary>
        /// Production builds never restore a checkpoint - they always build from scratch - but they do
        /// write a fresh one at the last checkpointable pipeline that runs this build, so later dev
        /// builds can pick up from the release's output. See <see cref="ProductionCheckpointBeforeLevels"/>
        /// for the temporary exception.
        /// </summary>
        /// <param name="checkpointExists">If there is an existing checkpoint folder on disk.</param>
        private static void ConfigureProductionCheckpoint(bool checkpointExists)
        {
            var checkpointInfo = checkpointExists ? Checkpoint.ReadCheckpointMetadata() : null;

            // Same reasoning as the outdated-checkpoint prompt: a stale checkpoint means pipeline code
            // changed, so the on-disk class caches from before the change can't be trusted either.
            if (checkpointInfo != null && checkpointInfo.Version < MIN_CHECKPOINT_VERSION)
            {
                MilanLog.Information("Production build: existing checkpoint is outdated - cleaning MPCommon/NonStartup caches");
                MPCommon.Clean();
                NonStartupPipeline.Clean();
            }

            // Only reuse a checkpoint a production build wrote: a dev one may be missing kits/weapons/levels that
            // were disabled per-entry, which production forces on.
            if (ProductionCheckpointBeforeLevels && checkpointInfo != null && checkpointInfo.Version >= MIN_CHECKPOINT_VERSION
                && checkpointInfo.ProductionBuild && checkpointInfo.Stage < ECheckpointStage.Levels)
            {
                Console.WriteLine("-------------------------------");
                Console.WriteLine($"Production checkpoint exists at the {checkpointInfo.Stage} pipeline{DescribeCheckpointAge(checkpointInfo.CreatedUtc)}.");
                Console.WriteLine($"Use it and skip all pipelines through {checkpointInfo.Stage} [Y/n]? (5 second timeout)");
                var input = ConsoleHelpers.ConsoleReadLineWithTimeout(TimeSpan.FromSeconds(5));
                if (!"N".CaseInsensitiveEquals(input))
                {
                    RestoreStage = checkpointInfo.Stage;
                    MilanLog.Information($"Production build: using checkpoint; skipping all pipelines through {RestoreStage}");
                    WarnAboutPipelinesMissingFromCheckpoint(checkpointInfo);
                    return; // A run either restores or creates, never both
                }
            }

            MilanLog.Information("Production build: not restoring a checkpoint");

            if (string.IsNullOrWhiteSpace(Settings.CheckpointFolder))
            {
                MilanLog.Warning("Production build: CheckpointFolder is not configured, no checkpoint will be created.");
                return;
            }

            var lastEnabledStage = OfferedCheckpointStages.LastOrDefault(x => x.Enabled() && (!ProductionCheckpointBeforeLevels || x.Stage < ECheckpointStage.Levels));
            if (lastEnabledStage.Name == null)
            {
                MilanLog.Warning("Production build: no checkpointable pipelines are enabled, no checkpoint will be created.");
                return;
            }

            CreateStage = lastEnabledStage.Stage;
            MilanLog.Information($"Production build: will create a new checkpoint at the {CreateStage} pipeline");
        }

        /// <summary>
        /// Shows the checkpoint stage menu and returns the pipeline the user picked. Stages whose
        /// pipeline (or an earlier one) is turned off in settings are flagged in the list, and picking
        /// one logs a warning rather than blocking - a developer may have deliberately disabled a
        /// pipeline they never build - but the checkpoint will not contain that pipeline's output.
        /// </summary>
        /// <param name="defaultStage">Stage selected if the user just presses enter.</param>
        private static ECheckpointStage PromptForCheckpointStage(ECheckpointStage defaultStage)
        {
            var stages = OfferedCheckpointStages;
            var labels = new List<string>();
            for (int i = 0; i < stages.Length; i++)
            {
                var missing = GetDisabledPipelinesThrough(stages[i].Stage);
                labels.Add(missing.Count == 0
                    ? stages[i].Name
                    : $"{stages[i].Name}  [will not contain: {string.Join(", ", missing)}]");
            }

            var defaultIndex = Array.FindIndex(stages, x => x.Stage == defaultStage);
            var selectedIndex = ConsoleHelpers.PromptForMenuSelection(
                "Which pipeline should the checkpoint be taken after?", labels, defaultIndex);

            var selected = stages[selectedIndex].Stage;
            var disabled = GetDisabledPipelinesThrough(selected);
            if (disabled.Count > 0)
            {
                MilanLog.Warning($"Checkpoint at {selected} will not contain output from these pipelines, which are disabled in settings: {string.Join(", ", disabled)}");
            }

            return selected;
        }

        /// <summary>
        /// Names of the pipelines at or before <paramref name="stage"/> that are turned off in settings,
        /// and so will contribute nothing to a checkpoint taken at that stage.
        /// </summary>
        private static List<string> GetDisabledPipelinesThrough(ECheckpointStage stage)
        {
            return CheckpointStages.Where(x => x.Stage <= stage && !x.Enabled()).Select(x => x.Name).ToList();
        }

        /// <summary>
        /// Warns about pipelines that are enabled in the current settings but were disabled when the
        /// checkpoint being restored was built. Restoring skips them, so despite the setting they will
        /// not run and their content will be missing from this build.
        /// </summary>
        private static void WarnAboutPipelinesMissingFromCheckpoint(Checkpoint.CheckpointInfo checkpointInfo)
        {
            if (checkpointInfo.SkippedPipelines == null || checkpointInfo.SkippedPipelines.Count == 0)
                return;

            foreach (var stage in CheckpointStages.Where(x => x.Stage <= checkpointInfo.Stage && x.Enabled()))
            {
                if (checkpointInfo.SkippedPipelines.Contains(stage.Name, StringComparer.OrdinalIgnoreCase))
                {
                    MilanLog.Warning($"Pipeline {stage.Name} is enabled in settings, but the checkpoint being restored was built without it - it will NOT run this build. Rebuild the checkpoint if you need it.");
                }
            }
        }

        /// <summary>
        /// Renders a checkpoint's creation time as ", created N days ago (date)", or an empty string
        /// for a checkpoint that didn't record one.
        /// </summary>
        private static string DescribeCheckpointAge(DateTime createdUtc)
        {
            if (createdUtc == default)
                return string.Empty;

            var age = DateTime.UtcNow - createdUtc;
            var ageText = age.TotalDays >= 1 ? $"{(int)age.TotalDays}d ago" : $"{(int)age.TotalHours}h ago";
            return $", created {ageText} ({createdUtc.ToLocalTime()})";
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
            if (BuildStaticLighting)
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

            if (RestoreStage != ECheckpointStage.None)
            {
                SetConsoleTitle(ConsoleTitlePostFix, "Restoring checkpoint");
                if (Checkpoint.RestoreCheckpoint())
                {
                    // The output folder's contents just changed wholesale - make LE3PackageResolver
                    // enumerate it again rather than trusting a listing from before the restore.
                    MilanShared.RefreshMilanFiles = true;
                    BaseDeltaHandler.PrepareForCheckpointRestore();
                }
                else
                {
                    MilanLog.Error("Could not use checkpoint; continuing with full pipeline run.");
                    RestoreStage = ECheckpointStage.None;
                }
            }

            if (RestoreStage == ECheckpointStage.None)
            {
                // Build/cache patch targets (e.g. SFXGame) before anything that might import from them.
                BaseDeltaHandler.PrepareForFreshBuild(CreateStage != ECheckpointStage.None);
            }

            // Pre-build pipelines
            RunPipeline(ECheckpointStage.ModBuild, true, ModBuilder.RunPipeline, "ModBuild"); // Always run, unless a restored checkpoint already contains its output

            // Every pipeline from here through Redemption is checkpointable: passing its stage lets
            // RunPipeline skip it when a restored checkpoint already covers it (replaying any global
            // state it publishes), and write the checkpoint once it's done when it's the chosen stage.
            RunPipeline(ECheckpointStage.MPCommon, Settings.RunMPCommonPipeline, MPCommon.RunPipeline, "MPCommon"); // Builds the BIOP_MP_COMMON package that is used by all BioP_MP files
            RunPipeline(ECheckpointStage.NonStartup, Settings.RunNonStartupPipeline, NonStartupPipeline.RunPipeline, "NonStartup"); // Ports packages that are not kits, levels, BIOP_MP_COMMON, etc. Things like images, objectives
            // goto end;

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
            RunPipeline(ECheckpointStage.Kits, ShouldRunKitsPipeline, MPKits.RunPipeline, "Kits"); // Builds character packages
        weaponsBuild:
            RunPipeline(ECheckpointStage.Weapons, ShouldRunWeaponsPipeline, SFXWeapons.RunPipeline, "Weapons"); // Builds DLC weapon packages

            // This pipeline must come after weapons as it depends on Collector SMG.
            if (Settings.RunMP4EnemiesPipeline && !ShouldRunWeaponsPipeline)
            {
                MilanLog.Error(@"MP4Enemies pipeline cannot run without SFXWeapons, pipeline being skipped.");
            }
            // The weapons dependency is folded into the gate rather than wrapped around the call so this
            // stage is always reached - a checkpoint chosen at MP4Enemies still gets written when it's skipped.
            RunPipeline(ECheckpointStage.MP4Enemies, ShouldRunWeaponsPipeline && Settings.RunMP4EnemiesPipeline, MP4NewEnemiesPipeline.RunPipeline, "MP4Enemies"); // Ports MP4 enemies that need custom code handling

        levelBuild:
            RunPipeline(ECheckpointStage.Levels, ShouldRunLevelsPipeline, MPLevels.RunPipeline, "Levels"); // Builds level packages

        rejectionBuild:
            RunPipeline(ECheckpointStage.Rejection, Settings.RunRejectionPipeline, RejectsPipeline.RunPipeline, "Rejection"); // Builds Rejection Enemies
        redemptionBuild:
            RunPipeline(ECheckpointStage.Redemption, Settings.RunRedemptionPipeline, RedemptionPipeline.RunPipeline, "Redemption"); // Builds Redemption Maps

            // Finalize the dynamic TLK range: every stage that could call AssignTLK (Kits through
            // Redemption, including Rejection/Redemption running in-process) has now either run, or
            // been skipped and rehydrated via ModBuilder.RehydrateFromCheckpoint. A (dev-only) Texture
            // checkpoint was taken after this point and already holds the finalized TLKs; finalizing
            // again would append the starter kit strings a second time.
            SetConsoleTitle(ConsoleTitlePostFix, "Finalizing TLK");
            if (RestoreStage >= ECheckpointStage.Texture)
                TLKPipeline.CloseForRestoredCheckpoint();
            else
                TLKPipeline.FinalizePipeline();

        // EVERYTHING AFTER THIS IS NON-CONTENT PORTING. ONLY TEXTURE MAY BE CHECKPOINTED, IN DEV BUILDS ---------

            // MIDWAY POINT - We should no longer be porting content, so we can
            // drop some caches to release memory.
            MilanShared.DropPortingCaches();


            // Post-build pipelines
            RunPipeline(ECheckpointStage.Texture, Settings.RunTexturePipeline, TFCBuild.RunPipeline, "Texture"); // Performs TFC compaction and texture upgrades

        shaders:
            // Shader install, with the offline compiler.
            //
            // Runs after the texture pipeline, the last step that changes textures: a texture's compression
            // and unpack range are compiled into the shaders that sample it, so compiling earlier would bake
            // in the pre-conversion decode. Runs before the object database is unregistered (imports resolve
            // through it) and before Resynthesis, which compacts each shader cache against the final
            // material set. Any material left without shaders fails the build.
            RunPipeline(Settings.RunShaderPipeline, ShaderPipeline.RunPipeline, "Shaders");

        audio:
            RunPipeline(Settings.RunAudioPipeline, AudioPipeline.RunPipeline, "Audio"); // Converts audio



            // Drop all extra packages from database. Conformance depends on vanilla DB.
            MilanShared.UnregisterObjectDBPackages();

        resynthesis:
            // Package resynthesis
            RunPipeline(Settings.RunResynthesis, ModResynthesis.RunPipeline, "Resynthesis");

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

            // Last, so errors from hours earlier in a long build end the log where they'll be seen.
            MilanLog.LogSessionSummary();
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
        /// Runs a single pipeline that cannot be checkpointed.
        /// </summary>
        /// <param name="shouldRunPipeline"></param>
        /// <param name="runPipeline"></param>
        /// <param name="pipelineName"></param>
        private static void RunPipeline(bool shouldRunPipeline, Action runPipeline, string pipelineName)
            => RunPipeline(ECheckpointStage.None, shouldRunPipeline, runPipeline, pipelineName);

        /// <summary>
        /// Runs a single checkpointable pipeline. If a restored checkpoint already covers
        /// <paramref name="stage"/>, the pipeline is skipped and any global state it publishes is
        /// replayed from the restored output instead. If <paramref name="stage"/> is the stage the user
        /// chose to checkpoint at, the checkpoint is written once the slot completes.
        /// </summary>
        /// <param name="stage">Which checkpoint stage this pipeline is, or <see cref="ECheckpointStage.None"/> for a pipeline that can't be checkpointed.</param>
        /// <param name="shouldRunPipeline"></param>
        /// <param name="runPipeline"></param>
        /// <param name="pipelineName"></param>
        private static void RunPipeline(ECheckpointStage stage, bool shouldRunPipeline, Action runPipeline, string pipelineName)
        {
            // The gate here and the CheckpointStages table both decide whether this pipeline runs; if they
            // ever disagree the stage menu would be lying about what a checkpoint contains. Stages that
            // aren't offered in the menu (ModBuild) have no table entry and nothing to cross-check.
            var tableEntry = CheckpointStages.FirstOrDefault(x => x.Stage == stage);
            Debug.Assert(tableEntry.Name == null || tableEntry.Enabled() == shouldRunPipeline,
                $"CheckpointStages table disagrees with the inline setting for pipeline {pipelineName}");

            if (stage != ECheckpointStage.None && RestoreStage != ECheckpointStage.None && stage <= RestoreStage)
            {
                MilanLog.Information($"Skipping pipeline: {pipelineName}, already covered by the restored checkpoint (stage {RestoreStage})");

                // Output is on disk, but nothing has loaded it into memory - replay whatever global
                // registrations the pipeline would have made.
                if (CheckpointRehydrators.TryGetValue(stage, out var rehydrate))
                {
                    SetConsoleTitle(ConsoleTitlePostFix, $"Rehydrating {pipelineName}");
                    rehydrate();
                }

                MaybeCreateCheckpoint(stage);
                return;
            }

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

            MaybeCreateCheckpoint(stage);
        }

        /// <summary>
        /// Writes the checkpoint if <paramref name="completedStage"/> is the stage the user chose to take it
        /// at. Called whether or not the stage's pipeline actually ran - a checkpoint at a stage whose pipeline
        /// is disabled in settings is still written (the user was warned when they picked it), it just won't
        /// contain that pipeline's output.
        /// </summary>
        private static void MaybeCreateCheckpoint(ECheckpointStage completedStage)
        {
            if (completedStage == ECheckpointStage.None || completedStage != CreateStage)
                return;

            SetConsoleTitle(ConsoleTitlePostFix, "Creating checkpoint");
            TLKPipeline.CommitPendingStrings(); // Config is already on disk - the TLK strings it references must be too
            Checkpoint.CreateCheckpoint(completedStage, GetDisabledPipelinesThrough(completedStage));
        }

        private static void RunResearch()
        {
#if DEBUG
            // MP maps that get a UDK lighting bake (BuildLighting = true in MPLevelsVars)
            //LightmapResolutionScan.Run([
            //    "BioP_MPTowr3", "BioP_MPCer3", "BioP_MPNov3", "BioP_MPMoon", "BioP_MPGeth", "BioP_MPJngl", "BioP_MPThes",
            //    "BioP_MPOcean", "BioP_MPHosp", "BioP_MPRoad", "BioP_MPCer2", "BioP_MPDish2", "BioP_MPNov2", "BioP_MPRctr2",
            //    "BioP_MPSlum2", "BioP_MPTowr2"
            //], @"B:\UserProfile\Desktop\LightmapResolutionScan");
            //return;

            //Research.FixWwiseStreamDonors();
            //return;

            //Research.GetMissingShaderPackages("S:\\SteamLibrary\\steamapps\\common\\Mass Effect Legendary Edition\\Game\\LMP\\BioGame\\DLC\\DLC_MOD_ProjectMilan\\CookedPCConsole");
            //return;

            //DynamicMixinResearch.RunDynamicMixinInventory(@"B:\UserProfile\Desktop\dynamicmixins.csv", @"B:\UserProfile\Desktop\dynamicmixins_inventory.json");
            //return;

            //Research.TestBuildLavaTerrainSetup();
            //return;
            //Research.TestBuildTerrainPackage();
            //return;

            //TextureResearch.FindUniqueLMPTextures(@"S:\Milan\Textures");
            //return;

            //Research.InstallCompiledShaders(force: true);// @"S:\SteamLibrary\steamapps\common\Mass Effect Legendary Edition\Game\LMP\BioGame\DLC\DLC_MOD_PMR3\CookedPCConsole\Levels\BioP_MPPSTropical");
            //return;

            //return;
            //Research.SlashShaderCache(MEGame.LE3);
            //return;
            //Research.TestSFARTextureDecompression();
            //return;
            //Research.GenerateLightingForLevel();
            //return;
            Research.ImportStaticLightingForLevel();
            return;
            // Research.TestTextureToInstancesMap();
            // Research.DumpRefShaderNames();
            //UDKSetup.DecookGameToUDK();
            //MELoadedFiles.InvalidateCaches();
            //UDKSetup.TestConvertToUDK();
            //UDKSetup.TestFixingUDKCrash();

            //Research.GeneratePerPackageNesting();
            //Research.LightingBake();
            // Research.ScanForShaderCompPackages();
            Research.InstallCompiledShaders();
#endif
        }
    }
}
