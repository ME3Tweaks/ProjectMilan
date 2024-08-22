using System.Diagnostics;
using System.IO.Compression;
using LegendaryExplorerCore.Helpers;
using LegendaryExplorerCore.Unreal.BinaryConverters;
using ProjectMilanCore;

namespace ProjectMilan.Pipelines.Audio.Extension
{
    // Taken straight out of LEX, stripped down

    /// <summary>
    /// Helper class for audio stuff
    /// </summary>
    public static class VGMAudioStreamHelper
    {
        public static bool EnsureVGMStream()
        {
            if (File.Exists(GetVGMStreamExe()))
                return true;

            var syncZip = Path.Combine(Program.Settings.InputSyncPath, "milan-vgmstream.zip");
            if (!File.Exists(syncZip))
            {
                return false;
            }

            ZipFile.ExtractToDirectory(syncZip, GetVGMStreamFolder());

            return true;
        }

        private static string GetVGMStreamFolder()
        {
            return Directory.CreateDirectory(Path.Combine(MilanShared.PipelineRoot, "Audio", "VGMStream")).FullName;
        }

        private static string GetVGMStreamExe()
        {
            return Path.Combine(GetVGMStreamFolder(), "vgmstream.exe");
        }

        private static string GetATempSoundPath() => $"{Path.GetTempPath()}MILAN_SOUND_{Guid.NewGuid()}";

        /// <summary>
        /// Converts a RAW RIFF/RIFX to WAVE using VGMStream and returns the data
        /// </summary>
        /// <param name="inputfilepath">Path to RIFF file</param>
        /// <returns></returns>
        private static MemoryStream ConvertRIFFToWaveVGMStream(string inputfile)
        {
            //convert ISB Codec 1/4 to WAV
            MemoryStream outputData = new MemoryStream();

            // Todo: Link against VGMStream with a wrapper so we don't have to perform disk writes
            ProcessStartInfo procStartInfo = new ProcessStartInfo(GetVGMStreamExe(), $"-P \"{inputfile}\"")
            {
                WorkingDirectory = GetVGMStreamFolder(),
                RedirectStandardOutput = true,
                UseShellExecute = false,
                CreateNoWindow = true
            };
            //procStartInfo.StandardOutputEncoding = Encoding.GetEncoding(850); //standard cmd-page
            Process proc = new Process
            {
                StartInfo = procStartInfo
            };

            Debug.WriteLine($"\"{procStartInfo.FileName}\" {procStartInfo.Arguments}");

            // Set our event handler to asynchronously read the sort output.
            proc.Start();
            //proc.BeginOutputReadLine();
            var outputTask = Task.Run(() =>
            {
                proc.StandardOutput.BaseStream.CopyTo(outputData);
            });
            Task.WaitAll(outputTask);

            proc.WaitForExit();
            File.Delete(inputfile); //intermediate
            return outputData;
        }


        private static bool ExtractRawFromSourceToFile(string outfile, string afcPath, int dataSize, int dataOffset)
        {
            var ms = ExternalFileHelper.ReadExternalData(afcPath, dataOffset, dataSize);
            if (ms is null)
            {
                return false;
            }
            if (File.Exists(outfile)) File.Delete(outfile);
            ms.WriteToFile(outfile);
            return true;
        }

        private static bool ExtractRawFromSourceToFile(this WwiseStream ws, string outputFile)
        {
            if (ws.IsPCCStored)
            {
                if (ws.EmbeddedData is null || ws.EmbeddedData.Length == 0)
                {
                    return false;
                }
                if (File.Exists(outputFile)) File.Delete(outputFile);
                File.WriteAllBytes(outputFile, ws.EmbeddedData);
                return true;
            }
            var afcPath = ws.GetPathToAFC();
            if (string.IsNullOrWhiteSpace(afcPath))
            {
                MilanLog.Warning($"AFC {ws.Filename} not found in game!", customPrefix:"MILAN-AFCRebuild");
                return false;
            }
            return VGMAudioStreamHelper.ExtractRawFromSourceToFile(outputFile, afcPath, ws.DataSize, ws.DataOffset);
        }

        /// <summary>
        /// Creates wav stream from this WwiseStream
        /// </summary>
        /// <returns></returns>
        public static MemoryStream CreateWaveStream(this WwiseStream ws)
        {
            string basePath = VGMAudioStreamHelper.GetATempSoundPath();
            string wemPath = basePath + ".wem";
            if (ws.ExtractRawFromSourceToFile(wemPath))
            {
                return VGMAudioStreamHelper.ConvertRIFFToWaveVGMStream(wemPath);
            }

            return null;
        }
    }
}