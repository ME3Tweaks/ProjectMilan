using LegendaryExplorerCore.Packages;

namespace ProjectMilan.Pipelines.Finalize
{
    /// <summary>
    /// Sets the licensee version on packages to +1 so they detect as LMP packages, so you cannot share ME3 mods directly with it.
    /// This is to prevent existing mods from really messing up conformance.
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
                using var fs = File.OpenWrite(v);
                fs.Seek(0x6, SeekOrigin.Begin);
                fs.WriteByte((byte)MEPackage.LMPLicenseeVersion);
            }
        }
    }
}
