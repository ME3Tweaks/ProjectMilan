using System;
using System.Collections.Generic;
using System.IO.Compression;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using LegendaryExplorerCore.Helpers;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Unreal;
using ProjectMilan.Utility;

namespace ProjectMilan.Pipelines.Audio
{
    /// <summary>
    /// Pipeline for extracting audio from ME3 and porting it to LE3 WwiseBanks
    /// </summary>
    internal class AudioRebuild
    {
        private const string LOG_CATEGORY = @"MILAN-Audio";

        // Expected pipeline:
        // 1. Go through ME3 package files and find all WwiseBanks that are not in LE (using object database?)
        // 2. Extract all WwiseBanks from them to disk.
        // 3. Extract all audio from WwiseBank and WwiseStreams to disk
        // 4. Decompile WwiseBank to gather information about what is needed to rebuild. Things like attenuation and stuff (this will probably be the worst step)
        // 5. Build new LE versions of banks using the Wwise Authoring API (WAAPI)
        // 6. Inject the new banks into the compiled mod files
        // This will probably be one of the later pipelines
        public static void RunPipeline()
        {
            ExtractWwiseBanks();
        }

        private static void ExtractWwiseBanks()
        {
            // Basegame
            // Figure out where to put this so it isn't in the repo.
            // Contains FRA and DEU audio as well as INT. Not sure where POL or ITA went
            var mpBasegameZip = Path.Combine(@"G:\My Drive\Mass Effect Legendary Modding\ProjectMilan", @"MPBasegame.zip");
            var archive = ZipFile.OpenRead(mpBasegameZip);
            foreach (var e in archive.Entries)
            {
                if (!e.Name.RepresentsPackageFilePath())
                    continue;

                var decomp = MEPackageHandler.OpenMEPackageFromStream(e.Decompress(), e.Name);
                foreach (var exp in decomp.Exports.Where(x => x.ClassName == @"WwiseBank"))
                {
                    var matchingObjects = MilanShared.LE3ObjectDB.GetFilesContainingObject(exp.InstancedFullPath);
                    if (matchingObjects == null)
                    {
                        // Needs extracted
                        ExtractWwiseBank(exp);
                    }
                }
            }

        }

        /// <summary>
        /// Extracts an ME3 WwiseBank
        /// </summary>
        /// <param name="export"></param>
        private static void ExtractWwiseBank(ExportEntry export)
        {
            if (export.Game != MEGame.ME3)
                throw new Exception("This method is only for extracting ME3 WwiseBanks!");

            var outPath = Path.Combine(Program.Settings.OutputModPath, @"ME3", @"WwiseBanks", export.ObjectName);
            var outBankPath = Path.Combine(outPath, $"{export.ObjectName}.bnk");
            if (File.Exists(outBankPath))
                return;
            Directory.CreateDirectory(outPath);

            MilanLog.Information($"Extracting WwiseBank {export.ObjectName}", customPrefix: LOG_CATEGORY);
            // Taken from LEX Package Editor
            var data = new MemoryStream(export.GetBinaryData());
            if (export.Game.IsGame3())
            {
                data.Skip(0x10);
            }
            else if (export.Game.IsGame2())
            {
                data.Skip(0x18);
            }

            using FileStream fs = new FileStream(outBankPath, FileMode.Create);
            data.CopyToEx(fs, (int)data.Length - 0x10);
        }

    }
}
