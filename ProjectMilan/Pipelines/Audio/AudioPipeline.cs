using LegendaryExplorerCore.Packages;
namespace ProjectMilan.Pipelines.Audio;

internal static class AudioPipeline
{
    private const string LOG_CATEGORY = @"MILAN-Audio";

    public static void RunPipeline()
    {
        // Find all banks that need to be converted
        var banksToConvert = GetBanksToConvertInOutputMod();

        // Convert WwiseBank binary to v134
        // Disabled due to BankConvertPipeline not compiling
        // BankConvertPipeline.RunPipeline(banksToConvert, clearCacheOnRebuild: false);

        // Rebuild AFC and WwiseStreams in v134 using Wwise CLI
        AFCRebuildPipeline.RunPipeline(banksToConvert, clearCacheOnRebuild: true);
    }

    private static List<MilanBankConvertInfo> GetBanksToConvertInOutputMod()
    {
        var bankInventory = new List<MilanBankConvertInfo>();
        foreach (var pf in Directory.GetFileSystemEntries(Program.Settings.OutputModPath, "*.pcc",
                     SearchOption.AllDirectories))
        {
            MilanLog.Information($"Inventorying WwiseBanks in {Path.GetFileName(pf)}", customPrefix: LOG_CATEGORY);
            var package = MEPackageHandler.OpenMEPackage(pf);
            foreach (var exp in package.Exports.Where(x => x.ClassName == @"WwiseBank"))
            {
                var bankInfo = new MilanBankConvertInfo(exp);
                // Can add filters here to test specific banks
                if (string.IsNullOrEmpty(bankInfo.AFCName))
                {
                    MilanLog.Information($"Skipping bank {bankInfo.LocalizedInfo}", customPrefix: LOG_CATEGORY);
                    continue;
                }

                // Only convert banks that are v56 - non-donor banks from ME3.
                // if (bankInfo.BankParser is { Version: 56 }) bankInventory.Add(bankInfo);
            }
        }
        return bankInventory;
    }

    public static bool EnsureWwise7110()
    {
        var wwisePath = Environment.GetEnvironmentVariable("WWISEROOT");
        if (wwisePath == null || !Directory.Exists(wwisePath))
        {
            MilanLog.Fatal("This pipeline requires Wwise 7110 to be installed. Ensure WWISEROOT is set as an environment variable.", customPrefix: LOG_CATEGORY);
            Environment.Exit(1);
            return false;
        }

        return true;
    }
}