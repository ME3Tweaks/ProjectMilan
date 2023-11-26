using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Globalization;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using CsvHelper;
using CsvHelper.Configuration;
using CsvHelper.Configuration.Attributes;
using LegendaryExplorerCore.Helpers;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Unreal.Classes;
using LegendaryExplorerCore.UnrealScript.Language.Tree;

namespace ProjectMilan.Pipelines.Texture
{
    /// <summary>
    /// Research code for Milan-Textures
    /// </summary>
    internal static class TextureResearch
    {

        public class ALOTColumn
        {
            [Index(0)] public string OTEntry { get; set; }

            [Index(1)] public string LEEntry { get; set; }
        }

        // Look for DLC textures.
        public static void RunResearch()
        {
            Dictionary<uint, string> missingCRCs = new();
            MilanShared.LoadME3DLCTOCs();
            foreach (var f in MilanShared.ME3DLCFileMap.Where(x => x.Key.RepresentsPackageFilePath()))
            {
                MilanLog.Information($"Checking for textures in DLC package {f.Key}");
                var package = MilanShared.GetME3Package(f.Key);
                foreach (var tex in package.Exports.Where(x => x.IsTexture()))
                {
                    var destItem = MilanShared.LE3ObjectDB.GetFilesContainingObject(tex.InstancedFullPath);
                    if (destItem == null)
                    {
                        // No donors!
                        var crc = Texture2D.GetTextureCRC(tex);
                        if (missingCRCs.ContainsKey(crc))
                            continue;
                        missingCRCs[crc] = tex.InstancedFullPath;
                        MilanLog.Information($"  0x{crc:X8} | No LE3 version of {tex.InstancedFullPath}");
                    }
                }
            }


            List<ALOTColumn> data;
            var config = new CsvConfiguration(CultureInfo.InvariantCulture)
            {
                HasHeaderRecord = false,
            };
            using (var reader = new StreamReader(@"B:\UserProfile\Downloads\alottextures.csv"))
            using (var csv = new CsvReader(reader, config))
            {
                data = csv.GetRecords<ALOTColumn>().ToList();
            }


            Debug.WriteLine("");
            foreach (var crc in missingCRCs)
            {
                var hasMatch = false;
                foreach (var row in data)
                {
                    if (row.OTEntry != null && row.OTEntry.StartsWith("0x"))
                    {
                        var otHash = int.Parse(row.OTEntry.Substring(2, 8), NumberStyles.HexNumber);
                        if (otHash == crc.Key)
                        {
                            // We have hash
                            Debug.WriteLine($"0x{crc.Key:X8}\t{crc.Value}\tIN ALOT");
                            hasMatch = true;
                            break;
                        }
                    }
                }
                if (!hasMatch)
                {
                    Debug.WriteLine($"0x{crc.Key:X8}\t{crc.Value}\tNOT IN ALOT");
                }
            }
        }
    }
}
