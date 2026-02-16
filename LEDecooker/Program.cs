using CommandLine;
using LegendaryExplorerCore;
using LegendaryExplorerCore.Helpers;
using LegendaryExplorerCore.Packages;
using System.Diagnostics;
using System.IO.Compression;

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

#if DEBUG
            // Uncomment to run support generation
            //RunSupportGenerators();
            //return;
#endif

            Parser.Default.ParseArguments<CLIOptions>(args).WithParsed(RunDecook);
        }

        private static void RunDecook(CLIOptions options)
        {
            CLIOptions.ParsedOptions = options;
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
            MEGame[] games = [MEGame.ME1, MEGame.ME2, MEGame.ME3, MEGame.LE1, MEGame.LE2, MEGame.LE3];


            foreach (var g in games)
            {
                // Textures
                SupportGenerators.GenerateTextureDB(g); // ME1 has some extra content in it due to it shipping uncooked files.

                // Material Instance Constant
                SupportGenerators.GenUObjDB(g, "MaterialInstanceConstant", false);

                // Static Meshes
                SupportGenerators.GenUObjDB(g, "StaticMesh", false);

                // Material IFP Database
                SupportGenerators.GeneratePerPackageNesting(g);
            }

            
            var zipfolder = Path.Combine("..", "..", "..", "supportfiles");
            var zipfile = Path.Combine(zipfolder, "supportdbs.zip");
            if (File.Exists(zipfile))
            {
                File.Delete(zipfile);
            }

            MemoryStream zipStream = new MemoryStream();

            DecookerLog.Information("Compressing support files...");
            ZipFile.CreateFromDirectory(zipfolder, zipStream, CompressionLevel.SmallestSize, false);
            DecookerLog.Information($"Writing zip file: {zipfile}");
            zipStream.WriteToFile(zipfile);
        }
    }
}