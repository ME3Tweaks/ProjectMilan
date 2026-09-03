using LegendaryExplorerCore.Helpers;
using LegendaryExplorerCore.Packages;
using ProjectMilanCore;

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
            MilanLicensee.RunPipeline(Program.Settings.OutputModPath);
        }
    }
}
