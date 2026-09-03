using LegendaryExplorerCore.Helpers;
using LegendaryExplorerCore.Packages;
using ProjectMilan;
using System;
using System.Collections.Generic;
using System.Text;

namespace ProjectMilanCore
{
    /// <summary>
    /// Class that contains shared code for setting the licensee data and stripping LECL tags
    /// </summary>
    public static class MilanLicensee
    {
        private const string LOG_CATEGORY = @"MILAN-Licensee";
        public static void RunPipeline(string path)
        {
            var allPackagesFiles = Directory.GetFiles(path, "*.pcc", SearchOption.AllDirectories).ToList();
            foreach (var v in allPackagesFiles)
            {
                MilanLog.Information($"Licensee changing {Path.GetFileName(v)}", customPrefix: LOG_CATEGORY);
                // Update the licensee value.
                using var fs = File.Open(v, FileMode.Open, FileAccess.ReadWrite);
                fs.Seek(0x6, SeekOrigin.Begin);
                fs.WriteByte((byte)MEPackage.LMPLicenseeVersion);

                // Strip LECL tag
                fs.Seek(-4, SeekOrigin.End);
                if ("LECL"u8.SequenceEqual(fs.ReadToBuffer(4)))
                {
                    fs.Seek(-8, SeekOrigin.End);
                    var leclPayloadSize = fs.ReadInt32();
                    fs.SetLength(fs.Length - leclPayloadSize - 8);
                }
            }
        }
    }
}
