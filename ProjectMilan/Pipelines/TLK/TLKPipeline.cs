using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.TLK;
using LegendaryExplorerCore.TLK.ME2ME3;
using ProjectMilanCore;

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
            var mergedFiles = new List<(string Path, ME2ME3TalkFile File)>();

            foreach (var tlk in tlks)
            {
                var loc = tlk.GetUnrealLocalization();
                var tlkF = new ME2ME3TalkFile(tlk);
                MilanLog.Information($"Building TLK {Path.GetFileName(tlk)}", customPrefix: LOG_CATEGORY);

                for (int i = 1; i <= 5; i++)
                {
                    var dlcTlkS = MilanShared.GetME3SFARFile($"DLC_CON_MP{i}_{loc}.tlk", true);
                    var dlcTlk = new ME2ME3TalkFile(dlcTlkS, $"DLC_CON_MP{i}");

                    foreach (var f in dlcTlk.StringRefs)
                    {
                        tlkF.ReplaceString(f.StringID, f.Data, true); // Todo: Support Male/Female system for non-INT, if necessary.
                    }
                }

                // Add DLC_Shared
                var sharedTlk = new ME2ME3TalkFile(Path.Combine(MilanShared.PipelineRoot, "Mod", "Live", "DLC_Shared", $"DLC_Shared_{loc}.tlk"));
                foreach (var f in sharedTlk.StringRefs)
                {
                    tlkF.ReplaceString(f.StringID, f.Data, true); // Todo: Support Male/Female system for non-INT, if necessary.
                }

                // Add LiveTLK
                var liveTLK = new ME2ME3TalkFile(Path.Combine(MilanShared.PipelineRoot, "Mod", "Live", "DLC_LiveIni", "CookedPCConsole", $"ME3TLK_{loc}.tlk"));
                foreach (var f in liveTLK.StringRefs)
                {
                    tlkF.ReplaceString(f.StringID, f.Data, true); // Todo: Support Male/Female system for non-INT, if necessary.
                }

                mergedFiles.Add((tlk, tlkF));
            }

            // Every vanilla/seed string is now merged in - anything assigned dynamically from here on
            // (any pipeline stage, via MilanPipelinesShared.AssignTLK) must not collide with it.
            MilanPipelinesShared.TLKStartIndex = mergedFiles.SelectMany(x => x.File.StringRefs)
                .Select(x => x.StringID).DefaultIfEmpty(0).Max();
            MilanPipelinesShared.InitializeTLKSet();

            foreach (var (tlk, tlkF) in mergedFiles)
            {
                MilanLog.Information($"  Saving TLK {Path.GetFileName(tlk)}", customPrefix: LOG_CATEGORY);
                var huff = new HuffmanCompression();
                huff.LoadInputData(tlkF.StringRefs);
                huff.SaveToFile(tlk);
            }
        }

        /// <summary>
        /// Merges every string assigned via MilanPipelinesShared.AssignTLK this session (any stage,
        /// including in-process Rejection/Redemption) plus the closing starter kit into each already-merged
        /// .tlk, and re-saves. Must run exactly once, strictly after every stage that could still call
        /// AssignTLK - see Program.cs's call site.
        /// </summary>
        public static void FinalizePipeline()
        {
            TLKStarterKit.AssignAndAppend(MilanShared.DisplayName, MilanShared.DLC_NAME);

            var outDir = Path.Combine(Program.Settings.OutputModPath, "CookedPCConsole");
            foreach (var tlk in Directory.GetFiles(outDir, "*.tlk", SearchOption.TopDirectoryOnly))
            {
                var loc = tlk.GetUnrealLocalization();
                var tlkF = new ME2ME3TalkFile(tlk);

                foreach (var str in MilanPipelinesShared.TLKSet[loc])
                {
                    tlkF.AddString(new TLKStringRef(str.StringID, str.Data + '\0'));
                }

                MilanLog.Information($"  Finalizing TLK {Path.GetFileName(tlk)}", customPrefix: LOG_CATEGORY);
                var huff = new HuffmanCompression();
                huff.LoadInputData(tlkF.StringRefs);
                huff.SaveToFile(tlk);
            }

            MilanPipelinesShared.TLKSet = null;
            MilanPipelinesShared.TLKStartIndex = 0;
        }
    }
}
