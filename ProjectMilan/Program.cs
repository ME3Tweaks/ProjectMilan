using CommandLine;
using Newtonsoft.Json;
using ProjectMilan.Pipelines.Startups;

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
        /// The parsed pipeline settings.
        /// </summary>
        public static MilanSettings Settings;

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
            // Maybe use ini files so it's easy to comment things out?
            // More pain to set up but easier to work with than JSON...
            if (File.Exists(obj.SettingsPath))
            {
                MilanLog.Information($"Loading settings from {obj.SettingsPath}");
                Settings = JsonConvert.DeserializeObject<MilanSettings>(File.ReadAllText(obj.SettingsPath));
                
                // Update settings file to ensure it has all the content needed as we add more settings
                // and pipelines.
                //File.WriteAllText(obj.SettingsPath, JsonConvert.SerializeObject(Settings));
            }
            else
            {
                // Write blank settings file out.
                try
                {
                    File.WriteAllText(obj.SettingsPath, JsonConvert.SerializeObject(new MilanSettings()));
                    MilanLog.Information($"A blank settings file has been generated at {obj.SettingsPath}");
                    Environment.Exit(0);
                    return;
                }
                catch (Exception ex)
                {
                    // App has died
                    MilanLog.Exception(ex, $"Unable to write blank settings file to {obj.SettingsPath}:");
                    Environment.Exit(1);
                    return;
                }
            }

            RunPipelines();
        }

        static void RunPipelines()
        {
            RunPipeline(Settings.RunSFXGameMPContentPipeline, MPCommon.RunPipeline, "SFXGameMPContent");
            
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
            }
            else
            {
                MilanLog.Information($"Skipping pipeline: {pipelineName}, not selected for running in settings");
            }

        }
    }
}