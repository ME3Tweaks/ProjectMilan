using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.TLK.ME2ME3;

namespace ProjectMilan.Pipelines.TLK
{
    internal class TLKPipeline
    {
        private const string LOG_CATEGORY = "MILAN-TLK";

        public static void RunPipeline()
        {
            InternalRunPipeline();
        }

        private static void InternalRunPipeline()
        {
            // Generate a basic working mod.
            var outDir = Directory.CreateDirectory(Path.Combine(Program.Settings.OutputModPath, @"CookedPCConsole")).FullName;
            var tlks = Directory.GetFiles(outDir, "*.tlk", SearchOption.TopDirectoryOnly);
            foreach (var tlk in tlks)
            {
                var loc = tlk.GetUnrealLocalization();
                var tlkF = new ME2ME3TalkFile(tlk);
                MilanLog.Information($"Building TLK {Path.GetFileName(tlk)}", customPrefix: LOG_CATEGORY);

                for (int i = 1; i <= 5; i++)
                {
                    var dlcTlkS = MilanShared.GetME3SFARFile($"DLC_CON_MP{i}_{loc}.tlk");
                    var dlcTlk = new ME2ME3TalkFile(dlcTlkS);
                    foreach (var f in dlcTlk.StringRefs)
                    {
                        tlkF.ReplaceString(f.StringID, f.Data, true); // Todo: Support Male/Female system for non-INT, if necessary.
                    }
                }

                // Add LiveTLK
                var liveTLK = new ME2ME3TalkFile(Path.Combine(MilanShared.PipelineRoot, "Mod", "Live", $"ME3TLK_{loc}.tlk"));
                foreach (var f in liveTLK.StringRefs)
                {
                    tlkF.ReplaceString(f.StringID, f.Data, true); // Todo: Support Male/Female system for non-INT, if necessary.
                }

                MilanLog.Information($"  Saving TLK {Path.GetFileName(tlk)}", customPrefix: LOG_CATEGORY);
                var huff = new HuffmanCompression();
                huff.LoadInputData(tlkF.StringRefs);
                huff.SaveToFile(tlk);
            }
        }
    }
}
