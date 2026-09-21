using CommandLine;
using LegendaryExplorerCore;
using LegendaryExplorerCore.Helpers;
using LegendaryExplorerCore.Packages;
using System.Diagnostics;

namespace LEDecooker
{
    /// <summary>
    /// Main entry point for LE Decooker
    /// </summary>
    internal class Program
    {
        public static void Main(string[] args)
        {
            Console.WriteLine("Welcome to Legendary Edition Decooker");
            Console.WriteLine("By ME3Tweaks");
            Console.WriteLine();

            Console.Write("Initializing...");

            // Initialize LEC
            LegendaryExplorerCoreLib.InitLib(TaskScheduler.Current, x => Console.Error.WriteLine($"Error saving package: {x}"), null);
            MEPackageHandler.GlobalSharedCacheEnabled = false; // Do not use package cache
            DecookerLog.CreateLogger();
            Console.Write(" Done.\n");

            // Serilog buffers, so without this the tail of a run -- which is exactly the part worth
            // reading after a crash or a kill -- never reaches the file. try/finally rather than a
            // call at the end of Main so it still runs when a decook throws.
            try
            {
#if DEBUG
                // Uncomment to run support generation. Only when launched with no arguments, so that the
                // CLI (including --gensupportfiles for a single game) still works from a debug build.
                if (args.Length == 0)
                {
                    RunSupportGenerators();
                    return;
                }
#endif

                Parser.Default.ParseArguments<CLIOptions>(args).WithParsed(RunDecook);
            }
            finally
            {
                DecookerLog.CloseAndFlush();
            }
        }

        private static void RunDecook(CLIOptions options)
        {
            CLIOptions.ParsedOptions = options;

            // Database generation runs before the LE check: the ME3 database is what supplies the
            // original-generation objects, so this operation is valid for the OT games too.
            if (options.ZipSupportFiles)
            {
#if DEBUG
                SupportGenerators.ZipSupportFiles();
#else
                DecookerLog.Fatal("--zipsupportfiles is only available in DEBUG builds.");
                Environment.Exit(1);
#endif
                return;
            }

            if (options.GenerateObjectDB)
            {
#if DEBUG
                SupportGenerators.GenerateObjectInstanceDB(options.Game);
#else
                DecookerLog.Fatal("--genobjectdb is only available in DEBUG builds.");
                Environment.Exit(1);
#endif
                return;
            }

            if (options.GenerateTextureDB)
            {
#if DEBUG
                SupportGenerators.GenerateSupportFiles(options.Game, SupportGenerators.SupportDatabase.Textures);
#else
                DecookerLog.Fatal("--gentexturedb is only available in DEBUG builds.");
                Environment.Exit(1);
#endif
                return;
            }

            if (options.GenerateSupportFiles)
            {
#if DEBUG
                SupportGenerators.GenerateSupportFiles(options.Game);
#else
                DecookerLog.Fatal("--gensupportfiles is only available in DEBUG builds.");
                Environment.Exit(1);
#endif
                return;
            }

            if (!options.Game.IsLEGame())
            {
                DecookerLog.Fatal($"{options.Game} is not a game supported by the decooker.");
                Environment.Exit(1);
            }

            bool didSomething = false;
            if (options.CompileAssets)
            {
                didSomething = true;
               Decooker.CompileT3Ds();
            }

            if (options.ConvertAssetsToUDK)
            {
                didSomething = true;
                ConvertToUDK.ConvertAssetsToUDK();
            }

            if (!didSomething)
            {
                Console.WriteLine("No operation specified, see --help for usage.");
            }
        }


        [Conditional("DEBUG")]
        private static void RunSupportGenerators()
        {
#if DEBUG
            MEGame[] games = [MEGame.ME1, MEGame.ME2, MEGame.ME3, MEGame.LE1, MEGame.LE2, MEGame.LE3];

            foreach (var g in games)
            {
                //if (g != MEGame.LE1)
                //{
                //    continue;
                //}
                // One walk over the game builds all of them: textures, MaterialInstanceConstant,
                // StaticMesh, RvrEffectsMaterialUser, the material IFP database and the
                // ObjectInstanceDB. ME1 has some extra content in it due to it shipping uncooked files.
                SupportGenerators.GenerateSupportFiles(g);
            }

            
            // Reuses SupportGenerators' own folder lookup (walks up from AppContext.BaseDirectory
            // looking for a "supportfiles" directory) instead of a hardcoded "../../../" relative path,
            // which broke as soon as the build output sat at a different depth (e.g. an x64 or
            // RID-qualified output folder) than the Debug/net10.0 layout it was written for.
            SupportGenerators.ZipSupportFiles();
#endif
        }
    }
}