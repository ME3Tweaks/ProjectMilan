using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Unreal;
namespace ProjectMilan.Pipelines.Audio;

internal static class AudioPipeline
{
    private const string LOG_CATEGORY = @"MILAN-Audio";

    public static void RunPipeline()
    {
        // Find all banks that need to be converted
        var banksToConvert = GetWwiseV56BanksInOutputMod();

        // Convert WwiseBank binary to v134
        BankConvertPipeline.RunPipeline(banksToConvert, clearCacheOnRebuild: false);

        // Rebuild AFC and WwiseStreams in v134 using Wwise CLI
        AFCRebuildPipeline.RunPipeline(banksToConvert, clearCacheOnRebuild: true);

        // TODO: Handle banks that have changed from LE to OT if they exist. Need to convert OT version even if newer LE version exists?
    }

    private static List<MilanBankConvertInfo> GetWwiseV56BanksInOutputMod()
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

                // TEMPORARY: Don't convert any VocalizationBanks
               if (!bankInfo.LocalizedInfo.ToString().Contains("ss_mp", StringComparison.OrdinalIgnoreCase))
                {
                    MilanLog.Information($"Skipping bank {bankInfo.LocalizedInfo}", customPrefix: LOG_CATEGORY);
                    continue;
                }
                if (bankInfo.AFCName.Contains("VocalizationBank", StringComparison.OrdinalIgnoreCase)) {
                    MilanLog.Information($"Skipping vocalization bank {bankInfo.LocalizedInfo}", customPrefix: LOG_CATEGORY);
                    continue;
                } 

                if(bankInfo.BankParser is { Version: 56 }) bankInventory.Add(bankInfo);
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