using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Unreal;
using LegendaryExplorerCore.Unreal.BinaryConverters;
using ProjectMilan.Utility;
using ProjectMilanCore;
using ProjectMilan.Pipelines.Audio.Extension;
using LegendaryExplorerCore.Helpers;
using System.IO;


namespace ProjectMilan.Pipelines.Audio
{
    internal class AFCRebuildPipeline
    {
        private const string LOG_CATEGORY = "MILAN-Audio-AFCConvert";

        public static Dictionary<string, AFCInventory> AFCMap = new();

        public static void RunPipeline(List<MilanBankConvertInfo> banksToConvert)
        {
            Utilities.DeleteFilesAndFoldersRecursively(GetAfcCacheFolder());
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

        public static async void ConvertAFC(List<ExportEntry> streams, string afcName, string afcFolder)
        {
            MilanLog.Information($"  Converting {afcName}.afc to Wwise v134", customPrefix: LOG_CATEGORY);

            if (!Directory.Exists(afcFolder)) Directory.CreateDirectory(afcFolder);
            Utilities.DeleteFilesAndFoldersRecursively(afcFolder);

            var exportedPath = Path.Combine(afcFolder, "Exported");
            Directory.CreateDirectory(exportedPath);

            // STEP 1
            // Export all streams to .wav in Exported folder
            MilanLog.Information($"  Extracting {streams.Count} WwiseStreams from {afcName}", customPrefix: LOG_CATEGORY);
            foreach (var stream in streams)
            {
                var wwstream = ObjectBinary.From<WwiseStream>(stream);
                var waveStream = wwstream.CreateWaveStream();
                if(waveStream is null)
                {
                    break;
                }
                var outPath = Path.Combine(exportedPath, Path.ChangeExtension(stream.ObjectName.Name, ".wav"));
                waveStream.WriteToFile(outPath);
            }

            // STEP 2
            // Convert all .wavs to .wem in Converted folder with Wwise
            await WwiseCliHandler.RunWwiseConversion(MEGame.LE3, exportedPath, 24000);

            // STEP 3
            // Add .wems to new .afc in the base AFC folder
            var convertedPath = Path.Combine(afcFolder, "Converted");
            var inventory = new AFCInventory(afcName, afcFolder);

            // TODO

            // STEP 4
            // Create .json file as table of contents for .afc
            inventory.WriteToFile(Path.Combine(afcFolder, Path.ChangeExtension(afcName, ".json")));
            AFCMap.TryAdd(afcName, inventory);

            // CLEANUP STEP
            // Delete .wav and .wem folder. Converted .afc and .json will serve as cache until wiped out.
            //Utilities.DeleteFilesAndFoldersRecursively(exportedPath, deleteDirectoryItself: true);
            //Utilities.DeleteFilesAndFoldersRecursively(convertedPath, deleteDirectoryItself: true);
        }

        public static void RelinkWwiseStream(ExportEntry stream, string afcName, string afcFolder)
        {
            AFCInventory inventory;
            if(AFCMap.ContainsKey(afcName))
            {
                inventory = AFCMap[afcName];
            }
            else
            {
                inventory = new AFCInventory(afcName, afcFolder);
                AFCMap[afcName] = inventory;
            }

            if(inventory.Streams.TryGetValue(stream.ObjectNameString, out var item))
            {
                var streamObj = ObjectBinary.From<WwiseStream>(stream);
                streamObj.DataOffset = item.Offset;
                streamObj.DataSize = item.Size;
                stream.WriteBinary(streamObj);
            }
            else
            {
                MilanLog.Warning($"WwiseStream {stream.ObjectNameString} in {stream.FileRef.FileNameNoExtension} not in AFC Inventory!", customPrefix: LOG_CATEGORY);
            }
        }

    }
}
