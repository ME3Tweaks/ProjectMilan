using CommandLine;
using LegendaryExplorerCore;
using LegendaryExplorerCore.Packages;
using ProjectMilan.Pipelines;
using ProjectMilan.Pipelines.Audio;
using ProjectMilan.Pipelines.Finalize;
using ProjectMilan.Pipelines.Init;
using ProjectMilan.Pipelines.Kits;
using ProjectMilan.Pipelines.Levels;
using ProjectMilan.Pipelines.Mod;
using ProjectMilan.Pipelines.Startups;
using ProjectMilan.Pipelines.Texture;
using ProjectMilan.Pipelines.Verify;
using ProjectMilan.Pipelines.Weapons;
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

        public static readonly MELocalization[] SupportedVOLanguages = new[]
        {
            MELocalization.INT,
            MELocalization.FRA,
            MELocalization.DEU,
            MELocalization.ITA,
            // Any other languages that had VO?
        };

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
            if (!Settings.DontDeleteModFolder)
            {
                if (Directory.Exists(Settings.OutputModPath))
                {
                    Utilities.DeleteFilesAndFoldersRecursively(Settings.OutputModPath, deleteDirectoryItself: false);
                }
                else
                {
                    Directory.CreateDirectory(Settings.OutputModPath);
                }
            }

            // Initialize LEC
            LegendaryExplorerCoreLib.InitLib(TaskScheduler.Current, x => MilanLog.Error($"Error saving package: {x}"));
            MEPackageHandler.GlobalSharedCacheEnabled = false; // Do not use package cache

            RunPipelines();
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
                MilanLog.Error($"Must point your settings at your mod library version of the DLC folder! Make sure you import the template from December 11 2023 (or newer) in #links.");
                Environment.Exit(1);
            }
        }

        private static IMilanSettings LoadSettingsConfig(CLIOptions cliOptions) => cliOptions.Config.ToLower() switch
        {
            "mgamerz" => new MilanSettingsMgamerz(),
            "sircxyrtyx" => new MilanSettingsSirCxyrtyx(),
            "kinkojiro" => new MilanSettingsKinkojiro(),
            "henbagle" => new MilanSettingsHenBagle(),
            "d00t" => new MilanSettingsd00t(),
            "dropthesquid" => new MilanSettingsDropTheSquid(),
            _ => throw new Exception($"Undefined configuration: {cliOptions.Config}")
        };

        static void RunPipelines()
        {
            MilanInit.Init(); // Initialize shared pipeline data

            // Uncomment to run DonorDB build
            //DonorTooling.BuildDonorDB();
            //return;

            // Requirements
            // MPCommon.HackPatchParents(); // Should no longer be necessary

            // Pre-build pipelines
            RunPipeline(true, ModBuilder.RunPipeline, "ModBuild"); // This is always run
            RunPipeline(Settings.RunMPCommonPipeline, MPCommon.RunPipeline, "MPCommon"); // Builds the BIOP_MP_COMMON package that is used by all BioP_MP files
            RunPipeline(Settings.RunNonStartupPipeline, NonStartupPipeline.RunPipeline, "NonStartup"); // Ports packages that are not kits, levels, BIOP_MP_COMMON, etc. Things like images, objectives

            // Content build pipelines
            // This should not be required anymore
            if (!MilanShared.EnsureMPCommonInGame()) // These require BIOP_MP_COMMON
                return;

            // Content pipelines will use the milan ME3 cache
            MilanShared.EnsureTFCsAvailable();
            MilanShared.EnsureAFCsAvailable();

            // Post pipelines require additional items to load
            // We load them here so you don't find out later and have to run it again
            MilanShared.EnsureVGMStreamAvailable();
            WwiseProjectRebuild.EnsureWwise7110();

            RunPipeline(Settings.RunKitsPipeline, MPKits.RunPipeline, "Kits"); // Builds character packages
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

            RunPipeline(Settings.RunLevelsPipeline, MPLevels.RunPipeline, "Levels"); // Builds level packages

            // Post-build pipelines
            RunPipeline(Settings.RunTexturePipeline, TFCBuild.RunPipeline, "Texture"); // Performs TFC compaction and texture upgrades
            RunPipeline(Settings.RunAudioPipeline, AudioPipeline.RunPipeline, "Audio"); // Converts audio

            // Package resynthesis
            RunPipeline(Settings.RunResynthesis, ModResynthesis.RunPipeline, "Resynthesis");

            // Conformance
            RunPipeline(true, Conformance.RunPipeline, "Conformance");


            // Verification
            RunPipeline(true, VerifyMod.RunPipeline, "Verify");


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


        private static void Research()
        {
            /*Dictionary<int, ProfileSetting> ProfileSettings = new(103); // ME3 uses 100 keys so it's likely we'll hit that much normally
            var version = 0;

            var infile = @"B:\UserProfile\Documents\BioWare\Mass Effect Legendary Edition\Save\ME3\MP_Profile";
            var inData = File.ReadAllBytes(infile);
            LocalProfile lp = LocalProfile.DeserializeLocalProfile(infile, MEGame.LE3, false, false);
            lp.SetProfileSettingById(1, "20;4;Adept;20;10500000.0000;11");
            lp.SetProfileSettingById(2, "20;4;Soldier;20;10500000.0000;15");
            lp.SetProfileSettingById(3, "20;4;Engineer;20;10500000.0000;16");
            lp.SetProfileSettingById(4, "20;4;Sentinel;20;10500000.0000;13");
            lp.SetProfileSettingById(5, "20;4;Infiltrator;16;28770.0000;14");
            lp.SetProfileSettingById(6, "20;4;Vanguard;20;10500000.0000;13");
            var serialized = lp.Serialize();
            var outData = serialized.ToArray();


            var outfile = @"B:\UserProfile\Documents\BioWare\Mass Effect Legendary Edition\Save\ME3\MP_Profile2";
            File.WriteAllBytes(outfile, outData);

            if (!inData.SequenceEqual(outData))
            {
                Debug.WriteLine("FAIL!");
            }
            else
            {
                Debug.WriteLine("PASS");
            }

            Debug.WriteLine("done");*/
        }
    }
}