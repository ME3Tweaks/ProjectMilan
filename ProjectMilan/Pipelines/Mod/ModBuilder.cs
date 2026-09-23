using LegendaryExplorerCore.Coalesced;
using LegendaryExplorerCore.GameFilesystem;
using LegendaryExplorerCore.Misc;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.TLK.ME2ME3;
using ProjectMilan.Pipelines.TLK;
using ProjectMilanCore;
using ProjectMilanCore.Config;
using System.Text.RegularExpressions;

namespace ProjectMilan.Pipelines.Mod
{
    public class ModBuilder
    {
        private const string LOG_CATEGORY = "MILAN-StarterKit"; // Technically not starter kit...

        /// <summary>
        /// The current moddesc version of the mod. Change this every time moddesc updates are required.
        /// </summary>
        private static readonly Version CURRENT_VERSION = new Version("1.0.1");

        public static void RunPipeline()
        {
            InternalRunPipeline();
        }

        private static void InternalRunPipeline()
        {
            // Generate a basic working mod.
            var outDir = Directory.CreateDirectory(Path.Combine(Program.Settings.OutputModPath, @"CookedPCConsole")).FullName;

            // Write mount.dlc
            MilanLog.Information($@"Compiling mount.dlc", customPrefix: LOG_CATEGORY);
            MountFile mf = new MountFile()
            {
                Game = MEGame.LE3,
                MountFlags =
                    new MountFlag(EME3MountFileFlag.LoadsInMultiplayer |
                                  EME3MountFileFlag.LoadsInSingleplayer), // UsedInMatchMaking?
                MountPriority = 8227, // TODO: Change later
                TLKID = 49875623 // Random
            };

            mf.WriteMountFile(Path.Combine(outDir, "mount.dlc"));

            // Compile TLKs
            var tlkSourceDir = Path.Combine(MilanShared.PipelineRoot, "Mod", "TLK");
            foreach (var tlkXml in Directory.EnumerateFiles(tlkSourceDir, "*.xml", SearchOption.TopDirectoryOnly))
            {
                MilanLog.Information($@"Compiling TLK {Path.GetFileNameWithoutExtension(tlkXml)}",
                    customPrefix: LOG_CATEGORY);
                var huff = new HuffmanCompression();
                huff.LoadInputData(tlkXml);
                huff.SaveToFile(Path.Combine(outDir, Path.GetFileNameWithoutExtension(tlkXml) + ".tlk"));
            }

            // Compile Coalesced file - goes into BASEGAME folder of mod manager mod
            var baseOutDir = Directory.CreateDirectory(Path.Combine(Program.Settings.OutputModPath, @"..", @"BASEGAME", @"CookedPCConsole")).FullName;
            var manifest = Path.Combine(MilanShared.PipelineRoot, @"Mod", @"BaseConfig", $@"Coalesced.xml");
            var dest = Path.Combine(baseOutDir, $@"Coalesced.bin");
            MilanLog.Information($"Compiling Coalesced.bin", customPrefix: LOG_CATEGORY);
            CoalescedConverter.ConvertToBin(manifest, dest);

            // Some notes on multiplayer config files from ME3.
            // Config files mounted in specific order:
            //     0. ? Maybe? TestPatch mounted here it seems. Not entirely sure when this applied, but it has to be read before game even boots.
            //     1. Basegame
            //     2. When entering MPLobby -> DLC, in mount order
            //     3. When entering MPLobby -> LiveIni is applied while game is running
            // MPLobby is the map name for the MP menu system both in and out of lobbies. It's a persistent level.

            manifest = Path.Combine(MilanShared.PipelineRoot, @"Mod", @"MergedConfig", $@"Default_{MilanShared.DLC_NAME}.xml");
            dest = Path.Combine(outDir, $@"Default_{MilanShared.DLC_NAME}.bin");
            MilanLog.Information($"Compiling {MilanShared.DLC_NAME}.bin", customPrefix: LOG_CATEGORY);
            CoalescedConverter.ConvertToBin(manifest, dest);

            // Load the just-compiled config back in as a live bundle so MPLevels (and, if enabled later in
            // the same run, Rejection/Redemption) can register their multiplayer maps into it dynamically -
            // this is the first point the main mod's own build starts using MilanPipelinesShared.ConfigBundle.
            MilanPipelinesShared.OutputModPath = Program.Settings.OutputModPath;
            MilanPipelinesShared.LoadConfigBundle();
            MapIdAllocator.ResetCounter(1);


            // Add precomputed files to the CookedPCConsole folders
            foreach (var dir in Directory.GetDirectories(Path.Combine(MilanShared.PipelineRoot, @"Mod"))
                         .Where(x => x.StartsWith("Precomputed")))
            {
                var targetName = dir.Substring("Precomputed".Length);
                var targetDir = Path.Combine(outDir, targetName);
                var cookedOut = Path.Combine(targetDir, "CookedPCConsole");
                if (!Directory.Exists(cookedOut))
                {
                    Directory.CreateDirectory(cookedOut);
                }

                foreach (var file in Directory.GetFiles(dir, "*.*", SearchOption.AllDirectories))
                {
                    MilanLog.Information($"Copying precomputed file {Path.GetFileName(file)} to mod", customPrefix: LOG_CATEGORY);
                    File.Copy(file, Path.Combine(cookedOut, Path.GetFileName(file)), true);
                }
            }

            // Where does TestPatch go in here? First or last?
            // Build merged config file from vanilla ME3 DLC
            // Patch01/02 is not included here and I am unsure how it will affect the results of this
            // Not sure this is a good idea...
            //ConfigAssetBundle bundle = ConfigAssetBundle.FromDLCFolder(MEGame.ME3, @"Z:\Mass Effect Builds\ME3\PC\Retail\BIOGame\DLC_TestPatch\CookedPCConsole", "DLC_TestPatch");
            //ConfigAssetBundle.FromDLCFolder(MEGame.ME3, @"Z:\Mass Effect Builds\ME3\PC\Retail\BIOGame\DLC\DLC_CON_MP1\CookedPCConsole", "DLC_CON_MP1").MergeInto(bundle);
            //ConfigAssetBundle.FromDLCFolder(MEGame.ME3, @"Z:\Mass Effect Builds\ME3\PC\Retail\BIOGame\DLC\DLC_CON_MP2\CookedPCConsole", "DLC_CON_MP2").MergeInto(bundle);
            //ConfigAssetBundle.FromDLCFolder(MEGame.ME3, @"Z:\Mass Effect Builds\ME3\PC\Retail\BIOGame\DLC\DLC_CON_MP3\CookedPCConsole", "DLC_CON_MP3").MergeInto(bundle);
            //ConfigAssetBundle.FromDLCFolder(MEGame.ME3, @"Z:\Mass Effect Builds\ME3\PC\Retail\BIOGame\DLC\DLC_CON_MP4\CookedPCConsole", "DLC_CON_MP4").MergeInto(bundle);
            //ConfigAssetBundle.FromDLCFolder(MEGame.ME3, @"Z:\Mass Effect Builds\ME3\PC\Retail\BIOGame\DLC\DLC_CON_MP5\CookedPCConsole", "DLC_CON_MP5").MergeInto(bundle);
            //ConfigAssetBundle.FromDLCFolder(MEGame.ME3, @"B:\UserProfile\source\repos\ME3Tweaks\ProjectMilan\ProjectMilan\Pipelines\Mod\Live\DLC_LiveIni\CookedPCConsole", "DLC_LiveIni").MergeInto(bundle);
            //bundle.CommitDLCAssets(outDir, "DLC_MOD_ProjectMilan");

            TLKPipeline.RunPipeline();

            // This is here as it will be at point where mod should be deployable for templating.
            // Check moddesc version
            var mdPath = Path.Combine(Program.Settings.OutputModPath, "..", "moddesc.ini");
            if (File.Exists(mdPath))
            {
                var di = DuplicatingIni.LoadIni(mdPath);
                var mdVer = di.GetOrAddSection("ModInfo")["modver"]; // getoradd prevents exceptions, we are not saving.
                if (mdVer.HasValue && Version.TryParse(mdVer.Value, out var actualVersion) && actualVersion < CURRENT_VERSION)
                {
                    MilanLog.Fatal($"moddesc.ini needs updated. Current version: {actualVersion}, Supported version: {CURRENT_VERSION}. Download a new templated version from #links in the Project Milan Discord");
                    MilanLog.Fatal($"Path: {mdPath}");
                    Environment.Exit(1);
                }
            }
        }

        /// <summary>
        /// Called instead of <see cref="RunPipeline"/> when a restored checkpoint already covers ModBuild -
        /// its pipeline body (which recompiles Default_&lt;DLC_NAME&gt;.bin and the DLC's .tlk files from
        /// source) is always skipped on any checkpoint restore, but MilanPipelinesShared.ConfigBundle/TLKSet/
        /// TLKStartIndex are pure in-memory state that the checkpoint's file copy doesn't restore on its
        /// own, so they have to be rebuilt from the already-correct restored output instead. Also
        /// fast-forwards MapIdAllocator/TLKStartIndex past whatever map IDs/string IDs are already present,
        /// since a later stage (e.g. Rejection/Redemption, which are numerically after Levels) can still run
        /// fresh this session and would otherwise re-allocate colliding IDs starting back at 1.
        /// </summary>
        public static void RehydrateFromCheckpoint()
        {
            MilanPipelinesShared.LoadConfigBundle();

            var section = MilanPipelinesShared.ConfigBundle.GetAsset("BioGame").GetOrAddSection("sfxonlinefoundation.sfxonlinegamesettings");
            var highestId = section.TryGetValue("mastermaplist", out var mastermaplist)
                ? mastermaplist.Select(v => Regex.Match(v.Value, @"ID=(\d+)"))
                    .Where(m => m.Success).Select(m => int.Parse(m.Groups[1].Value)).DefaultIfEmpty(0).Max()
                : 0;
            MapIdAllocator.FastForwardPast(highestId);

            var outDir = Path.Combine(Program.Settings.OutputModPath, "CookedPCConsole");
            MilanPipelinesShared.TLKStartIndex = Directory.GetFiles(outDir, "*.tlk", SearchOption.TopDirectoryOnly)
                .SelectMany(tlk => new ME2ME3TalkFile(tlk).StringRefs)
                .Select(x => x.StringID).DefaultIfEmpty(0).Max();
            MilanPipelinesShared.InitializeTLKSet();
        }
    }
}
