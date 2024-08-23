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

        public static Dictionary<string, AFCContents> AFCMap = new();

        public static void RunPipeline(List<MilanBankConvertInfo> banksToConvert)
        {
            Utilities.DeleteFilesAndFoldersRecursively(GetAfcCacheFolder(), quiet: true); // Uncomment me to rebuild AFC cache on every Milan run

            var prePipelineAfcInventory = Directory.GetFileSystemEntries(Program.Settings.OutputModPath, "*.afc", SearchOption.AllDirectories)
                    .ToDictionary(s => Path.GetFileNameWithoutExtension(s).ToLower()) ?? new();

            foreach (var bank in banksToConvert)
            {
                var streams = bank.GetStreams();
                if (streams.Count == 0) break;

                var afcName = streams.First().GetProperty<NameProperty>("Filename").Value.ToString().ToLower();
                var afcFolder = Path.Combine(GetAfcCacheFolder(), afcName);

                if (!Directory.Exists(afcFolder))
                {
                    ConvertAFC(streams, afcName, afcFolder); // If the AFC isn't found, convert it to v134 and save it in the cache
                }

                string afcCachedPath = Path.Combine(afcFolder, Path.ChangeExtension(afcName, ".afc"));
                AFCContents afcContents = new AFCContents(afcName, afcFolder); // Metadata for new afc

                // Delete existing afc and copy the new one to output mod
                if(prePipelineAfcInventory.TryGetValue(afcName, out var oldAfcPath))
                {
                    File.Delete(oldAfcPath);
                }

                var outputModAfcPath = Path.Combine(Program.Settings.OutputModPath, @"CookedPCConsole", Path.ChangeExtension(afcName, ".afc"));
                if(File.Exists(afcCachedPath))
                {
                    MilanLog.Information($"Copying {afcName}.afc to output mod and relinking streams", customPrefix: LOG_CATEGORY);
                    File.Copy(afcCachedPath, outputModAfcPath);
                }

                foreach (var stream in streams)
                {
                    // Relink each stream for this bank. This will copy the cached AFC into the output mod folder as needed.
                    RelinkWwiseStream(stream, afcContents);
                }
            }
        }

        public static string GetAfcCacheFolder()
        {
            return Path.Combine(MilanShared.PipelineRoot, "Audio", "ConvertedAFCCache");
        }

        public static void ConvertAFC(List<ExportEntry> streams, string afcName, string afcFolder)
        {
            if (!Directory.Exists(afcFolder)) Directory.CreateDirectory(afcFolder);

            var exportedPath = Path.Combine(afcFolder, "Exported"); // Exported folder is where .wavs go
            Directory.CreateDirectory(exportedPath);

            // STEP 1
            // Export all streams to .wav in Exported folder
            MilanLog.Information($"Extracting {streams.Count} WwiseStreams from ME3 {afcName}.afc", customPrefix: LOG_CATEGORY);
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
            MilanLog.Information($"Converting {afcName} with WwiseCLI v134", customPrefix: LOG_CATEGORY);
            WwiseCliHandler.RunWwiseConversion(MEGame.LE3, exportedPath, 24000).Wait();

            // STEP 3
            // Use .wems to create new .afc in the pipeline AFC folder, building AFC afcContents as we go
            MilanLog.Information($"Creating {afcName}.afc for Milan", customPrefix: LOG_CATEGORY);

            var convertedPath = Path.Combine(afcFolder, "Converted"); // Converted folder is where CLI converted .wems go
            var contents = new AFCContents(afcName, afcFolder);

            using MemoryStream memoryNewAfc = new MemoryStream();
            var wems = Directory.EnumerateFiles(convertedPath).ToDictionary<string, string>(Path.GetFileNameWithoutExtension);
            foreach(var stream in streams)
            {
                if(wems.TryGetValue(stream.ObjectNameString, out var wemPath))
                {
                    using var wemFileStream = new FileStream(wemPath, FileMode.Open, FileAccess.Read);
                    contents.AddAFCItem(stream.ObjectNameString, wemFileStream.Length, memoryNewAfc.Position);
                    wemFileStream.CopyTo(memoryNewAfc);
                }
            }
            var newWemPath = Path.Combine(afcFolder, Path.ChangeExtension(afcName, ".afc"));
            memoryNewAfc.WriteToFile(newWemPath);

            // STEP 4
            // Create .json file to save table of afcContents for .afc
            contents.WriteToFile(afcFolder);

            // STEP 5 - CLEANUP STEP
            // Delete .wav and .wem folder. Converted .afc and .json will serve as cache until wiped out.
            Utilities.DeleteFilesAndFoldersRecursively(exportedPath, deleteDirectoryItself: true, quiet: true);
            Utilities.DeleteFilesAndFoldersRecursively(convertedPath, deleteDirectoryItself: true, quiet: true);
        }

        public static void RelinkWwiseStream(ExportEntry stream, AFCContents contents)
        {
            if(contents.Streams.TryGetValue(stream.ObjectNameString, out var item))
            {
                var streamObj = ObjectBinary.From<WwiseStream>(stream);
                streamObj.DataOffset = (int)item.Offset;
                streamObj.DataSize = (int)item.Size;
                stream.WriteBinary(streamObj);
            }
            else
            {
                MilanLog.Warning($"WwiseStream {stream.ObjectNameString} in {stream.FileRef.FileNameNoExtension} not in AFC contents!", customPrefix: LOG_CATEGORY);
            }
        }

    }
}
