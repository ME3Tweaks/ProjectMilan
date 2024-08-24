using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Unreal;
using LegendaryExplorerCore.Unreal.BinaryConverters;
using ProjectMilan.Utility;
using ProjectMilanCore;
using ProjectMilan.Pipelines.Audio.Extension;
using LegendaryExplorerCore.Helpers;
using System.IO;
using ME3Tweaks.Wwiser.Model;


namespace ProjectMilan.Pipelines.Audio
{
    internal class AFCRebuildPipeline
    {
        private const string LOG_CATEGORY = "MILAN-Audio-AFCConvert";

        public static Dictionary<string, AFCContents> AFCMap = new();

        public static void RunPipeline(List<MilanBankConvertInfo> banksToConvert, bool clearCacheOnRebuild = false)
        {
            if(clearCacheOnRebuild)
            {
                Utilities.DeleteFilesAndFoldersRecursively(GetAfcCacheFolder(), deleteDirectoryItself: false, quiet: true);
            }

            // Map of all AFCs already in output mod. NOT basegame LE3, BEFORE copying any converted AFCs. These should exclusively be vanilla ME3 AFCs.
            var prePipelineAfcInventory = Directory.GetFileSystemEntries(Program.Settings.OutputModPath, "*.afc", SearchOption.AllDirectories)
                    .ToDictionary(s => Path.GetFileNameWithoutExtension(s).ToLower()) ?? new();

            // Item1: Path to AFC to delete in output mod
            // Item2: Path to AFC to copy from pipeline to output mod
            var afcsToCopy = new HashSet<(string, string)>();

            foreach (var bank in banksToConvert)
            {
                var streams = bank.GetStreams();
                if (streams.Count == 0) continue;

                // Paths
                var afcName = bank.AFCName.ToLower();
                var afcFolder = Path.Combine(GetAfcCacheFolder(), afcName);
                var afcCachedPath = Path.Combine(afcFolder, Path.ChangeExtension(afcName, ".afc"));
                var contentsPath = Path.ChangeExtension(afcCachedPath, ".json");

                // If the AFC doesn't exist in Milan, but the bank was converted from v56, we can't convert the AFC. Streams will be broken.
                // Could be a case where AFC exists in LE3, but we still need to convert from the ME3 version
                if (!prePipelineAfcInventory.TryGetValue(afcName, out var oldAfcPath))
                {
                    MilanLog.Warning($"Referenced AFC {afcName} does not exist in output mod, skipping bank {bank.LocalizedInfo}", customPrefix: LOG_CATEGORY);
                    continue;
                }

                var contents = new AFCContents(contentsPath); // Metadata for new afc

                // If the AFC isn't found on disk, convert all streams to v134 and save it in the cache
                if (!Directory.Exists(afcFolder))
                {
                    ConvertStreamsToAFC(streams, afcName, afcFolder, contents);
                }

                // Mark AFC as needs to copy to output mod
                if(File.Exists(afcCachedPath))
                {
                    afcsToCopy.Add((oldAfcPath, afcCachedPath));
                }

                var streamsNotInAFC = streams.Where(s => !contents.Streams.ContainsKey(s.ObjectNameString)).ToList();
                if(streamsNotInAFC.Count > 0)
                {
                    // If we have any streams that aren't contained in the proper AFC, also convert these.
                    ConvertStreamsToAFC(streamsNotInAFC.ToList(), afcName, afcFolder, contents);
                }

                // Relink each stream for this bank
                foreach (var stream in streams)
                {
                    RelinkWwiseStream(stream, contents);
                }
                bank.LE3BankExport.FileRef.Save();
            }

            // After all banks have been converted, delete ME3 .AFCs and copy AFCs to output mod
            foreach(var tuple in afcsToCopy)
            {
                File.Delete(tuple.Item1);

                var afcName = Path.GetFileName(tuple.Item2);
                var outputModAfcPath = Path.Combine(Program.Settings.OutputModPath, @"CookedPCConsole", afcName);

                MilanLog.Information($"Copying {afcName} to output mod and relinking streams", customPrefix: LOG_CATEGORY);
                File.Copy(tuple.Item2, outputModAfcPath);
            }
        }

        public static string GetAfcCacheFolder()
        {
            return Path.Combine(MilanShared.PipelineRoot, "Audio", "ConvertedAFCCache");
        }

        public static void ConvertStreamsToAFC(List<ExportEntry> streams, string afcName, string afcFolder, AFCContents contents)
        {
            if (!Directory.Exists(afcFolder)) Directory.CreateDirectory(afcFolder);

            // PATHS
            var exportedPath = Path.Combine(afcFolder, "Exported"); // Exported folder is where .wavs go
            Directory.CreateDirectory(exportedPath);
            
            var convertedPath = Path.Combine(afcFolder, "Converted"); // Converted folder is where CLI converted .wems go

            var afcFilepath = Path.Combine(afcFolder, Path.ChangeExtension(afcName, ".afc"));
            var contentsPath = Path.ChangeExtension(afcFilepath, ".json");

            // STEP 1
            // Export all streams to .wav in Exported folder
            MilanLog.Information($"Extracting and converting {streams.Count} streams from ME3 {afcName}.afc with Wwise 7110", customPrefix: LOG_CATEGORY);
            ExportStreamsToWav(streams, exportedPath);

            // STEP 2
            // Convert all .wavs to .wem in Converted folder with Wwise
            WwiseCliHandler.RunWwiseConversion(MEGame.LE3, exportedPath, 24000).Wait();

            // STEP 3
            // Use .wems to build AFC chunk. Build AFC contents as we go
            var appendOffset = File.Exists(afcFilepath) ? new FileInfo(afcFilepath).Length : 0;
            
            using MemoryStream newAfcChunk = new MemoryStream();
            var wems = Directory.EnumerateFiles(convertedPath).ToDictionary<string, string>(Path.GetFileNameWithoutExtension);
            foreach (var stream in streams)
            {
                if (wems.TryGetValue(stream.ObjectNameString, out var wemPath))
                {
                    using var wemFileStream = new FileStream(wemPath, FileMode.Open, FileAccess.Read);
                    contents.AddAFCItem(stream.ObjectNameString, wemFileStream.Length, newAfcChunk.Position + appendOffset);
                    wemFileStream.CopyTo(newAfcChunk);
                }
            }

            // STEP 4
            // Write AFC chunk to disk, either as brand new AFC or appending to existing Milan AFC
            if (File.Exists(afcFilepath))
            {
                // AFC already exists and we need to append
                MilanLog.Information($"Appending {streams.Count} .wems to Milan {afcName}.afc", customPrefix: LOG_CATEGORY);
                using var afcAppendStream = new FileStream(afcFilepath, FileMode.Append, FileAccess.Write);
                newAfcChunk.Seek(0, SeekOrigin.Begin);
                newAfcChunk.CopyTo(afcAppendStream);
            }
            else
            {
                // New AFC, just write it to disk
                MilanLog.Information($"Creating {afcName}.afc for Milan", customPrefix: LOG_CATEGORY);
                newAfcChunk.WriteToFile(afcFilepath);
            }

            // STEP 5 - CLEANUP STEP
            // Delete .wav and .wem folder. Converted .afc and .json will serve as cache until wiped out.
            Utilities.DeleteFilesAndFoldersRecursively(exportedPath, deleteDirectoryItself: true, quiet: true);
            Utilities.DeleteFilesAndFoldersRecursively(convertedPath, deleteDirectoryItself: true, quiet: true);

            // Save contents to disk
            contents.WriteToFile(contentsPath);
        }

        private static void ExportStreamsToWav(List<ExportEntry> streams, string exportedPath)
        {
            foreach (var stream in streams)
            {
                var wwstream = ObjectBinary.From<WwiseStream>(stream);
                var waveStream = wwstream.CreateWaveStream();
                if (WaveStreamInvalid(waveStream))
                {
                    break;
                }
                var outPath = Path.Combine(exportedPath, Path.ChangeExtension(stream.ObjectName.Name, ".wav"));
                waveStream.WriteToFile(outPath);
            }
        }

        /// <summary>
        /// Returns true if stream is invalid
        /// </summary>
        /// <param name="waveStream"></param>
        /// <returns></returns>
        public static bool WaveStreamInvalid(MemoryStream waveStream)
        {
            if (waveStream is null) return true;

            waveStream.Position = 0;
            var riff = waveStream.ReadStringASCII(4);
            if (riff != "RIFF") return true;
            waveStream.Position = 0;

            return false;
        }

        public static void RelinkWwiseStream(ExportEntry stream, AFCContents contents)
        {
            if(contents.Streams.TryGetValue(stream.ObjectNameString, out var item))
            {
                var streamObj = ObjectBinary.From<WwiseStream>(stream);
                streamObj.DataOffset = (int)item.Offset;
                streamObj.DataSize = (int)item.Size;
                // Do we need to update the Filename property here? Probably not. Pipeline is written to never change AFC name
                stream.WriteBinary(streamObj);
            }
            else
            {
                MilanLog.Warning($"WwiseStream {stream.ObjectNameString} in {stream.FileRef.FileNameNoExtension} not in AFC contents!", customPrefix: LOG_CATEGORY);
            }
        }

    }
}
