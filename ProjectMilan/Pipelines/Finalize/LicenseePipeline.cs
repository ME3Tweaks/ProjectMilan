using LegendaryExplorerCore.Helpers;
using LegendaryExplorerCore.Packages;

namespace ProjectMilan.Pipelines.Finalize
{
    /// <summary>
    /// Sets the licensee version on packages to +1 so they detect as LMP packages, so you cannot share ME3 mods directly with it.
    /// This is to prevent existing mods from really messing up conformance. This also strips the LECLData tag so modifications to the files
    /// will show up in Mod Manager once the Vanilla Database for the game is generated.
    /// </summary>
    public static class LicenseePipeline
    {
        private const string LOG_CATEGORY = @"MILAN-Licensee";
        public static void RunPipeline()
        {
            InternalRunPipeline();
        }

        private static void InternalRunPipeline()
        {
            var allPackagesFiles = Directory.GetFiles(Program.Settings.OutputModPath, "*.pcc", SearchOption.AllDirectories).ToList();
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
