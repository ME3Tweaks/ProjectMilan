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

        public static void SetGame(string path, MEGame game)
        {
            if (!game.IsLEGame3())
            {
                throw new Exception("Can't be set to anything other than LE3/LMP");
            }

            // Update the licensee value.
            using var fs = File.Open(path, FileMode.Open, FileAccess.ReadWrite);
            fs.Seek(0x6, SeekOrigin.Begin);
            var b = fs.ReadByte();
            if (b != 205 && b != 206)
            {
                throw new Exception($"Cannot set game on {path} - doesn't look like an LE3 or LMP file");
            }

            fs.Seek(0x6, SeekOrigin.Begin);
            fs.WriteByte(game == MEGame.LE3 ? (byte)MEPackage.LE3LicenseeVersion : (byte)MEPackage.LMPLicenseeVersion);
        }

        public static MEGame GetGame(string path)
        {
            // Update the licensee value.
            using var fs = File.OpenRead(path);
            fs.Seek(0x6, SeekOrigin.Begin);
            var b = fs.ReadByte();
            switch (b)
            {
                case MEPackage.LE1LicenseeVersion:
                    return MEGame.LE1;
                case MEPackage.LE2LicenseeVersion:
                    return MEGame.LE2;
                case MEPackage.LE3LicenseeVersion:
                    return MEGame.LE3;
                case MEPackage.LMPLicenseeVersion:
                    return MEGame.LMP;
            }
            throw new Exception($"Input file is not an LEGame file");
        }
    }
}
