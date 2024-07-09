using System.Diagnostics;
using CommandLine;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore;
using ProjectMilan;
using ProjectMilan.Pipelines;
using ProjectMilan.Utility;
using ProjectMilan_ExtraContent.Settings;
using Serilog;
using Timer = System.Timers.Timer;
using System.Timers;
using ProjectMilan_ExtraContent.Redemption;
using ProjectMilan_ExtraContent.Rejects;
using ProjectMilanCore;

namespace ProjectMilan_ExtraContent
{
    /// <summary>
    /// Wrapper for standalone extra-content build
    /// </summary>
    internal class Program
    {
        /// <summary>
        /// The loaded settings configuration
        /// </summary>
        public static IMilanECSettings Settings;


        /// <summary>
        /// Keeps system from falling asleep
        /// </summary>
        private static Timer _keepAwakeTimer = new Timer(30 * 1000); // 30s interval

        static void Main(string[] args)
        {
            // Parse command line options. If it succeeds, run the specified delegate
            Parser.Default.ParseArguments<CLIOptions>(args).WithParsed(Init);
        }

        private static void Init(CLIOptions obj)
        {
            MilanLog.CreateLogger();
            MilanLog.Information("Welcome to Project Milan - Extra Content");

            Settings = LoadSettingsConfig(obj);
            VerifySettings();

            // Cleanup output directory before we start
            if (!Settings.DontDeleteModFolder)
            {
                // Cleanup Rejection.
                if (Settings.RunRejectionPipeline)
                {
                    if (Directory.Exists(Settings.OutputModPathREJ))
                    {
                        Utilities.DeleteFilesAndFoldersRecursively(Settings.OutputModPathREJ, deleteDirectoryItself: false);
                    }
                    else
                    {
                        Directory.CreateDirectory(Settings.OutputModPathREJ);
                    }
                }

                // Cleanup Redemption.
                if (Settings.RunRedemptionPipeline)
                {
                    if (Directory.Exists(Settings.OutputModPathRED))
                    {
                        Utilities.DeleteFilesAndFoldersRecursively(Settings.OutputModPathRED, deleteDirectoryItself: false);
                    }
                    else
                    {
                        Directory.CreateDirectory(Settings.OutputModPathRED);
                    }
                }
            }

            // Initialize LEC
            LegendaryExplorerCoreLib.InitLib(TaskScheduler.Current, x => MilanLog.Error($"Error saving package: {x}"), Log.Logger, objectDBsToLoad: [MEGame.LE3]);
            MEPackageHandler.GlobalSharedCacheEnabled = false; // Do not use package cache
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

        private static void keepSystemAwake(object sender, ElapsedEventArgs e)
        {
            SystemSleepManager.PreventSleep(@"Compiling");
        }

        /// <summary>
        /// For printing out at the end
        /// </summary>
        private static Dictionary<string, long> pipelineTimes = new();

        /// <summary>
        /// Executes the pipelines for Milan - Extra Content
        /// </summary>
        private static void RunPipelines()
        {
            // if statements are here because we don't want to change output paths unless necessary.
            if (Settings.RunRejectionPipeline)
            {
                BaseBuildSettings.OutputModPath = Settings.OutputModPathREJ;
                RunPipeline(Settings.RunRejectionPipeline, RejectsPipeline.RunPipelineEC, @"Rejection");
            }

            if (Settings.RunRedemptionPipeline)
            {
                BaseBuildSettings.OutputModPath = Settings.OutputModPathRED;
                RunPipeline(Settings.RunRedemptionPipeline, RedemptionPipeline.RunPipelineEC, @"Redemption");
            }

            MilanLog.Information($"Pipeline timings:");
            foreach (var stat in pipelineTimes)
            {
                MilanLog.Information($"\t{stat.Key.PadRight(pipelineTimes.Keys.MaxBy(x=>x.Length).Length + 3)}{stat.Value}ms");
            }
            MilanLog.Information($"\tTotal:\t{pipelineTimes.Sum(x => x.Value)}ms");
        }

        /// <summary>
        /// Runs a single pipeline
        /// </summary>
        /// <param name="shouldRunPipeline"></param>
        /// <param name="runPipeline"></param>
        /// <param name="pipelineName"></param>
        private static void RunPipeline(bool shouldRunPipeline, Action runPipeline, string pipelineName)
        {
            if (shouldRunPipeline)
            {
                MilanLog.Information($"Running pipeline: {pipelineName}");
                var sw = Stopwatch.StartNew();
                runPipeline();
                sw.Stop();
                MilanLog.Information($"Pipeline finished: {pipelineName}");
                pipelineTimes[pipelineName] = sw.ElapsedMilliseconds;
            }
            else
            {
                MilanLog.Information($"Skipping pipeline: {pipelineName}, not selected for running in settings");
            }
        }

        private static IMilanECSettings LoadSettingsConfig(CLIOptions cliOptions) => cliOptions.Config.ToLower() switch
        {
            "mgamerz" => new MilanECSettingsMgamerz(),
            "sircxyrtyx" => new MilanECSettingsSirCxyrtyx(),
            "kinkojiro" => new MilanECSettingsKinkojiro(),
            "henbagle" => new MilanECSettingsHenBagle(),
            "d00t" => new MilanECSettingsd00t(),
            "dropthesquid" => new MilanECSettingsDropTheSquid(),
            _ => throw new Exception($"Undefined configuration: {cliOptions.Config}")
        };

        private static void VerifySettings()
        {
            if (Program.Settings.RunRejectionPipeline)
            {
                if (Program.Settings.OutputModPathREJ == null || !Directory.Exists(Program.Settings.OutputModPathREJ))
                {
                    MilanLog.Error(@"You must specify an output path for REJECTION content in your settings class.");
                    Environment.Exit(1);
                    return;
                }
                var moddescCheck = Path.Combine(Settings.OutputModPathREJ, "..", "moddesc.ini");
                if (!File.Exists(moddescCheck))
                {
                    MilanLog.Error($"Must point your settings at your mod library version of the Rejects DLC development folder ({MilanShared.REJECTS_DLC_NAME})!");
                    Environment.Exit(1);
                }
            }

            if (Program.Settings.RunRedemptionPipeline)
            {
                if (Program.Settings.OutputModPathRED == null || !Directory.Exists(Program.Settings.OutputModPathRED))
                {
                    MilanLog.Error(@"You must specify an output path for REDEMPTION content in your settings class.");
                    Environment.Exit(1);
                    return;
                }
                var moddescCheck = Path.Combine(Settings.OutputModPathRED, "..", "moddesc.ini");
                if (!File.Exists(moddescCheck))
                {
                    MilanLog.Error($"Must point your settings at your mod library version of the Redemption DLC development folder ({MilanShared.REDEMPTION_DLC_NAME})!");
                    Environment.Exit(1);
                }
            }
        }
    }
}
