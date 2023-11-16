using CommandLine;
using LegendaryExplorerCore;
using Newtonsoft.Json;
using ProjectMilan.Pipelines.Config;
using ProjectMilan.Pipelines.Kits;
using ProjectMilan.Pipelines.Levels;
using ProjectMilan.Pipelines.Startups;
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
            Settings = LoadSettingsConfig(obj);

            // Cleanup output directory before we start
            if (Directory.Exists(Settings.OutputPath))
            {
                Utilities.DeleteFilesAndFoldersRecursively(Settings.OutputPath, deleteDirectoryItself: false);
            }
            else
            {
                Directory.CreateDirectory(Settings.OutputPath);
            }

            // Initialize LEC
            LegendaryExplorerCoreLib.InitLib(TaskScheduler.Current, x => MilanLog.Error($"Error saving package: {x}"));

            RunPipelines();
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
            RunPipeline(Settings.RunConfigPipeline, MPConfig.RunPipeline, "Config");
            RunPipeline(Settings.RunMPLobbyClassesPipeline, MPCommon.RunPipeline, "MPLobby");
            RunPipeline(Settings.RunKitsPipeline, MPKits.RunPipeline, "Kits");
            RunPipeline(Settings.RunLevelsPipeline, MPLevels.RunPipeline, "Levels");

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