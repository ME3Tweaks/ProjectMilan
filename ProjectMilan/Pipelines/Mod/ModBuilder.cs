using System;
using System.Collections.Generic;
using System.Linq;
using System.Net.Mime;
using System.Text;
using System.Threading.Tasks;
using LegendaryExplorerCore.Coalesced;
using LegendaryExplorerCore.GameFilesystem;
using LegendaryExplorerCore.Misc;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.TLK.ME2ME3;
using ProjectMilan.Pipelines.TLK;

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

            // Compile Coalesced file

            // Some notes on multiplayer config files from ME3.
            // Config files mounted in specific order:
            //     0. ? Maybe? TestPatch mounted here it seems. Not entirely sure when this applied, but it has to be read before game even boots.
            //     1. Basegame
            //     2. When entering MPLobby -> DLC, in mount order
            //     3. When entering MPLobby -> LiveIni is applied while game is running
            // MPLobby is the map name for the MP menu system both in and out of lobbies. It's a persistent level.

            var manifest = Path.Combine(MilanShared.PipelineRoot, @"Mod", @"MergedConfig", $@"Default_{MilanShared.DLC_NAME}.xml");
            var dest = Path.Combine(outDir, $@"Default_{MilanShared.DLC_NAME}.bin");
            MilanLog.Information($"Compiling {MilanShared.DLC_NAME}.bin", customPrefix: LOG_CATEGORY);
            CoalescedConverter.ConvertToBin(manifest, dest);

            
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
                    Environment.Exit(1);
                }
            }
        }
    }
}
