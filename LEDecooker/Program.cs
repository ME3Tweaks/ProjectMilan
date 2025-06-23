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
            if (!string.IsNullOrWhiteSpace(options.T3DInputfolder) && Directory.Exists(options.T3DInputfolder))
            {
                didSomething = true;
                Decooker.CompileT3Ds();
            }

            if (!didSomething)
            {
                Console.WriteLine("No operation specified, see --help for usage.");
            }
        }


        [Conditional("DEBUG")]
        private static void RunSupportGenerators()
        {
            /*
            // Textures
            //SupportGenerators.GenerateTextureDB(MEGame.ME1); // ME1 has some extra content in it due to it shipping uncooked files.
            //SupportGenerators.GenerateTextureDB(MEGame.LE1);
            //SupportGenerators.GenerateTextureDB(MEGame.LE2);

            // Material Instance Constant
            SupportGenerators.GenUObjDB(MEGame.LE1, "MaterialInstanceConstant", false);
            SupportGenerators.GenUObjDB(MEGame.LE2, "MaterialInstanceConstant", false);

            // Static Meshes
            SupportGenerators.GenUObjDB(MEGame.LE1, "StaticMesh", false);
            SupportGenerators.GenUObjDB(MEGame.LE2, "StaticMesh", false);

            // Material IFP Database
            SupportGenerators.GeneratePerPackageNesting(MEGame.LE1);
            SupportGenerators.GeneratePerPackageNesting(MEGame.LE2);
            */
            var zipfolder = Path.Combine("..", "..", "..", "supportfiles");
            var zipfile = Path.Combine(zipfolder, "supportdbs.zip");
            if (File.Exists(zipfile))
            {
                File.Delete(zipfile);
            }

            MemoryStream zipStream = new MemoryStream();

            DecookerLog.Information("Compressing support files...");
            ZipFile.CreateFromDirectory(zipfolder, zipStream, CompressionLevel.SmallestSize, false);
            zipStream.WriteToFile(zipfile);
        }
    }
}