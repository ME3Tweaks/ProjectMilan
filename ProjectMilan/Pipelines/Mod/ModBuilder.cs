using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using LegendaryExplorerCore.Coalesced;
using LegendaryExplorerCore.GameFilesystem;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.TLK.ME2ME3;

namespace ProjectMilan.Pipelines.Mod
{
    public class ModBuilder
    {
        private const string LOG_CATEGORY = "MILAN-StarterKit"; // Technically not starter kit...

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

            var manifest = Path.Combine(MilanShared.PipelineRoot, @"Mod", @"Config", $@"Default_{MilanShared.DLC_NAME}.xml");
            var dest = Path.Combine(outDir, $@"Default_{MilanShared.DLC_NAME}.bin");
            MilanLog.Information($"Compiling {MilanShared.DLC_NAME}.bin", customPrefix: LOG_CATEGORY);
            CoalescedConverter.ConvertToBin(manifest, dest);

            // Add precomputed files
            var afcPath = Path.Combine(MilanShared.PipelineRoot, @"Mod", @"Precomputed");
            foreach (var file in Directory.GetFiles(afcPath, "*.*", SearchOption.AllDirectories))
            {
                MilanLog.Information($"Copying precomputed file {Path.GetFileName(file)} to mod", customPrefix: LOG_CATEGORY);
                File.Copy(file, Path.Combine(outDir, Path.GetFileName(file)), true);
            }
        }
    }
}
