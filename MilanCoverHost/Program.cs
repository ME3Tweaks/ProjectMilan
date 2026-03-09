using CommandLine;
using LegendaryExplorerCore;
using LegendaryExplorerCore.Packages;
using MilanShaderHost;

namespace MilanCoverHost
{
    /// <summary>
    /// Main entry point for MilanShaderHost
    /// </summary>
    internal class Program
    {
        /// <summary>
        /// The command line arguments for the app.
        /// </summary>
        public static CLIOptions ParsedOptions;

        /// <summary>
        /// Game we are compiling/running shaders for. Eventually will move to ParsedOptions.
        /// </summary>
        public static MEGame Game { get; internal set; }

        // This application will handle interop between dumping HLSL from the games
        // and feeding it to the shader compiler to produce permutations of shaders.

        public async static Task Main(string[] args)
        {
            Parser.Default.ParseArguments<CLIOptions>(args).WithParsed(Init);
        }

        private static void Init(CLIOptions options)
        {
            //if (options.CompileShaders == false && options.PreviewShaders == false)
            //{
            //    Console.WriteLine("Must specify an operation: --compile, --preview, or both");
            //    return;
            //}

            ParsedOptions = options;

            Console.WriteLine("Welcome to Milan Cover Host");
            Console.WriteLine("By ME3Tweaks");
            Console.WriteLine();

            // Eventually make this command line when we support the other games.
            Game = MEGame.LE3;

            // Initialize
            LegendaryExplorerCoreLib.InitLib(null, x => { });
            MEPackageHandler.GlobalSharedCacheEnabled = false; // Do not use the shared cache.

            // Task.Run(MilanShaderBuilderFlow.StartFlow);

            // Start the pipe server.
            CoverHost sh = new CoverHost();
            sh.StartListening();
        }
    }
}