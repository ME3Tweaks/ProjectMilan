using CommandLine;
using LegendaryExplorerCore;
using LegendaryExplorerCore.Packages;
using Newtonsoft.Json;
using ProjectMilan.Pipelines.Audio;
using ProjectMilan.Pipelines.Init;
using ProjectMilan.Pipelines.Kits;
using ProjectMilan.Pipelines.Levels;
using ProjectMilan.Pipelines.Mod;
using ProjectMilan.Pipelines.Startups;
using ProjectMilan.Pipelines.Texture;
using ProjectMilan.Settings;
using ProjectMilan.Utility;

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

        /// <summary>
        /// Initialize Project Milan
        /// </summary>
        /// <param name="obj"></param>
        /// <exception cref="NotImplementedException"></exception>
        private static void Init(CLIOptions obj)
        {
            MilanLog.CreateLogger();
            MilanLog.Information("Welcome to Project Milan");
            Settings = LoadSettingsConfig(obj);

            VerifySettings();

            // Cleanup output directory before we start
            if (Directory.Exists(Settings.OutputModPath))
            {
                Utilities.DeleteFilesAndFoldersRecursively(Settings.OutputModPath, deleteDirectoryItself: false);
            }
            else
            {
                Directory.CreateDirectory(Settings.OutputModPath);
            }

            // Initialize LEC
            LegendaryExplorerCoreLib.InitLib(TaskScheduler.Current, x => MilanLog.Error($"Error saving package: {x}"));
            MEPackageHandler.GlobalSharedCacheEnabled = false; // Do not use package cache

            RunPipelines();
        }

        private static void VerifySettings()
        {
            if (Settings.OutputModPath == null || Path.GetFileName(Settings.OutputModPath) != @"DLC_MOD_ProjectMilan")
            {
                MilanLog.Error($"Output directory must be named 'DLC_MOD_ProjectMilan', point it to either mod in M3 mod library or DLC folder in-game (yours: {Path.GetFileName(Settings.OutputModPath)})");
                Environment.Exit(1);
                return;
            }
        }

        private static IMilanSettings LoadSettingsConfig(CLIOptions cliOptions) => cliOptions.Config.ToLower() switch
        {
            "mgamerz" => new MilanSettingsMgamerz(),
            "sircxyrtyx" => new MilanSettingsSirCxyrtyx(),
            "kinkojiro" => new MilanSettingsKinkojiro(),
            "henbagle" => new MilanSettingsHenBagle(),
            "doot" => new MilanSettingsd00t(),
            _ => throw new Exception($"Undefined configuration: {cliOptions.Config}")
        };

        static void RunPipelines()
        {
            MilanInit.Init(); // Initialize shared pipeline data

            // Pre-build pipelines
            RunPipeline(true, ModBuilder.RunPipeline, "ModBuild"); // This is always run
            RunPipeline(Settings.RunMPCommonPipeline, MPCommon.RunPipeline, "MPCommon"); // Builds the BIOP_MP_COMMON package that is used by all BioP_MP files

            // Content build pipelines
            RunPipeline(Settings.RunKitsPipeline, MPKits.RunPipeline, "Kits"); // Builds character packages
            RunPipeline(Settings.RunLevelsPipeline, MPLevels.RunPipeline, "Levels"); // Builds level packages

            // Post-build pipelines
            RunPipeline(Settings.RunTexturePipeline, TFCBuild.RunPipeline, "Texture"); // Performs TFC compaction and texture upgrades
            RunPipeline(Settings.RunAudioPipeline, AudioRebuild.RunPipeline, "Audio"); // Fixes audio
        }

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
                runPipeline();
                MilanLog.Information($"Pipeline finished: {pipelineName}");
            }
            else
            {
                MilanLog.Information($"Skipping pipeline: {pipelineName}, not selected for running in settings");
            }
        }
    }
}