using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Unreal;
using LegendaryExplorerCore.Unreal.BinaryConverters;
using ProjectMilan.Utility;
using ProjectMilanCore;
using ProjectMilan.Pipelines.Audio.Extension;
using LegendaryExplorerCore.Helpers;


namespace ProjectMilan.Pipelines.Audio
{
    internal class AFCRebuildPipeline
    {
        private const string LOG_CATEGORY = "MILAN-Audio-AFCConvert";


        public static void RunPipeline(List<MilanBankConvertInfo> banksToConvert)
        {
            foreach (var bank in banksToConvert)
            {
                var streams = bank.GetStreams();
                if (streams.Count == 0) break;

                var afcName = streams.First().GetProperty<NameProperty>("Filename").Value;
                var afcFolder = Path.Combine(GetAfcCacheFolder(), afcName);

                if (!Directory.Exists(afcFolder))
                {
                    ConvertAFC(streams, afcName, afcFolder);
                }

                foreach (var stream in streams)
                {
                    RelinkWwiseStream(stream, afcName, afcFolder);
                }
            }
        }

        public static string GetAfcCacheFolder()
        {
            return Path.Combine(MilanShared.PipelineRoot, "Audio", "ConvertedAFCCache");
        }

        public static void ConvertAFC(List<ExportEntry> streams, string afcName, string afcFolder)
        {
            if(!Directory.Exists(afcFolder)) Directory.CreateDirectory(afcFolder);
            Utilities.DeleteFilesAndFoldersRecursively(afcFolder);

            var exportedPath = Path.Combine(afcFolder, "Exported");
            Directory.CreateDirectory(exportedPath);

            // STEP 1
            // Export all streams to .wav in Exported folder
            foreach(var stream in streams)
            {
                MilanLog.Information($"  Extracting WwiseStream {stream.InstancedFullPath}", customPrefix: LOG_CATEGORY);
                var wwstream = ObjectBinary.From<WwiseStream>(stream);
                var waveStream = wwstream.CreateWaveStream();
                var outPath = Path.Combine(exportedPath, Path.ChangeExtension(stream.ObjectName.Name, ".wav"));
                waveStream.WriteToFile(outPath);
            }

            // STEP 2
            // Convert all .wavs to .wem in Converted folder with Wwise

            // STEP 3
            // Add .wems to new .afc in the base AFC folder


            // STEP 4
            // Create .json file as table of contents for .afc

            // CLEANUP STEP
            // Delete .wav and .wem folder. Converted .afc and .json will serve as cache until wiped out.
        }

        public static void RelinkWwiseStream(ExportEntry stream, string afcName, string afcFolder)
        {

        }

    }
}
