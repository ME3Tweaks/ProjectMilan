using System.Text.Json;
using LegendaryExplorerCore;
using LegendaryExplorerCore.Packages;
using ProjectMilan.Utility;

namespace RedemptionMapTool
{
    internal class Program
    {
        private static readonly JsonSerializerOptions JsonOpts = new() { WriteIndented = true };

        /// <summary>
        /// Default location of a full ME3 install (base game + DLC unpacked) used to resolve renamed sublevels
        /// back to their original shipping package name. Override with a command-line argument if run elsewhere.
        /// </summary>
        private const string DefaultBiogamePath = @"Z:\Mass Effect Builds\ME3\PC\Retail\BIOGame";

        static int Main(string[] args)
        {
            var libraryPath = Utilities.GetModManagerLibraryPath();
            var redemptionPath = Path.Combine(libraryPath, "ME3", "Redemption MP Map Pack");
            if (!Directory.Exists(redemptionPath))
            {
                Console.WriteLine("Redemption MP Map Pack not found in the Mod Manager library. Import the mod and run this tool again.");
                return 1;
            }

            LegendaryExplorerCoreLib.InitLib(TaskScheduler.Default, s => Console.Error.WriteLine($"LEC: {s}"), objectDBsToLoad: [MEGame.ME3]);

            // Batch-scanning ~90 files; don't let the shared cache pin every one of them in memory.
            MEPackageHandler.GlobalSharedCacheEnabled = false;

            var cookedDir = Path.Combine(redemptionPath, "DLC_MOD_MPMapPack", "CookedPCConsole");
            if (!Directory.Exists(cookedDir))
            {
                Console.WriteLine($"CookedPCConsole folder not found at {cookedDir}.");
                return 1;
            }

            var outputDir = ResolveChangeManifestsDir();
            Directory.CreateDirectory(outputDir);

            var biogamePath = args.Length > 0 ? args[0] : DefaultBiogamePath;
            if (!Directory.Exists(biogamePath))
            {
                Console.WriteLine($"ME3 BIOGame folder not found at {biogamePath} - can't resolve renamed sublevels. Pass a path as the first argument to override.");
                return 1;
            }
            var vanillaGuidMap = VanillaGuidLookup.Build(biogamePath);

            var displayInfoByMap = MasterMapListReader.Read(cookedDir);
            Console.WriteLine($"Found display info for {displayInfoByMap.Count} map(s) in the original mastermaplist.");

            var masters = Directory.GetFiles(cookedDir, "BioP_MP*.pcc").OrderBy(f => f).ToArray();
            Console.WriteLine($"Found {masters.Length} master level file(s).");

            var failures = 0;
            foreach (var masterPath in masters)
            {
                var name = Path.GetFileNameWithoutExtension(masterPath);
                Console.WriteLine($"Processing {name}...");
                try
                {
                    var manifest = MapManifestBuilder.BuildManifest(masterPath, cookedDir, vanillaGuidMap, displayInfoByMap);
                    var outPath = Path.Combine(outputDir, name + ".json");
                    File.WriteAllText(outPath, JsonSerializer.Serialize(manifest, JsonOpts));
                    Console.WriteLine($"  wrote {outPath}");
                }
                catch (Exception ex)
                {
                    failures++;
                    Console.WriteLine($"  [ERROR] {name}: {ex.Message}");
                }
            }

            Console.WriteLine($"Done. {masters.Length - failures}/{masters.Length} maps processed successfully.");
            return failures > 0 ? 1 : 0;
        }

        /// <summary>
        /// Resolves ProjectMilan_ExtraContent's ChangeManifests folder by walking up from the
        /// running assembly's directory (not the CWD, which is unreliable across invocation styles)
        /// looking for the repo-root marker ProjectMilan.slnx.
        /// </summary>
        private static string ResolveChangeManifestsDir()
        {
            var dir = new DirectoryInfo(AppContext.BaseDirectory);
            while (dir != null && !File.Exists(Path.Combine(dir.FullName, "ProjectMilan.slnx")))
            {
                dir = dir.Parent;
            }

            if (dir is null)
            {
                throw new InvalidOperationException($"Could not locate repo root (ProjectMilan.slnx) above {AppContext.BaseDirectory}");
            }

            return Path.Combine(dir.FullName, "ProjectMilan_ExtraContent", "Redemption", "Levels", "MapPack", "ChangeManifests");
        }
    }
}
