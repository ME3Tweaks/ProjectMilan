using LegendaryExplorerCore.Helpers;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Unreal.BinaryConverters;
using ProjectMilan.Pipelines.Audio.Extension;
using ProjectMilan.Utility;
using ProjectMilanCore;

namespace ProjectMilan.Pipelines.Audio;

internal static class AudioPipeline
{
    private const string LOG_CATEGORY = @"MILAN-Audio";

    public static void RunPipeline()
    {
        /*var banksToPort = GetBanksNotInLE3();
        
        // Decompile the audio from the banks
        DecompileBanks(vars, banksToPort);
        var streamingBanks = banksToPort.Where(b => b.EventToStreamMap.Count == 0).ToList();
        AudioRebuild.RunPipeline(streamingBanks, vars);*/


        // Find all banks that need to be converted
        var banksToConvert = GetWwiseV56BanksInOutputMod();

        // Convert WwiseBank binary to v134
        BankConvertPipeline.RunPipeline(banksToConvert);

        // Rebuild AFC and WwiseStreams in v134 using Wwise CLI
        AFCRebuildPipeline.RunPipeline(banksToConvert);


    }

    private static List<MilanBankConvertInfo> GetWwiseV56BanksInOutputMod()
    {
        var bankInventory = new List<MilanBankConvertInfo>();
        foreach (var pf in Directory.GetFileSystemEntries(Program.Settings.OutputModPath, "*.pcc",
                     SearchOption.AllDirectories))
        {
            MilanLog.Information($"Inventorying WwiseBanks in {Path.GetFileName(pf)}", customPrefix: LOG_CATEGORY);
            var package = MEPackageHandler.OpenMEPackage(pf);
            foreach (var exp in package.Exports.Where(x => x.ClassName == @"WwiseBank")
            {
                var bankInfo = new MilanBankConvertInfo(exp);
                if(bankInfo.BankParser is { Version: 56 }) bankInventory.Add(bankInfo);
            }
        }
        return bankInventory;
    }

    private static List<MilanBankRebuildInfo> GetBanksNotInLE3()
    {
        List<MilanBankRebuildInfo> bankInventory = new List<MilanBankRebuildInfo>();
        foreach (var pf in Directory.GetFileSystemEntries(Program.Settings.OutputModPath, "*.pcc",
                     SearchOption.AllDirectories))
        {
            MilanLog.Information($"Inventorying WwiseBanks in {Path.GetFileName(pf)}", customPrefix: LOG_CATEGORY);
            var package = MEPackageHandler.UnsafePartialLoad(pf, x => false); // Only need to find WwiseBank
            foreach (var exp in package.Exports.Where(x => x.ClassName == @"WwiseBank"))
            {
                var matchingObjects =
                    MilanShared.LE3ObjectDB.GetFilesContainingObject(exp.InstancedFullPath, package.Localization);
                if (matchingObjects == null) // bank not already in LE3
                {
                    var bankInfo = new MilanBankRebuildInfo()
                    {
                        LocalizedInfo = new LocalizedIFP()
                            { Localization = package.Localization, InstancedFullPath = exp.InstancedFullPath },
                    };
                    matchingObjects =
                        MilanShared.ME3ObjectDB.GetFilesContainingObject(exp.InstancedFullPath, package.Localization);
                    if (matchingObjects is { Count: > 0 } && !bankInventory.Contains(bankInfo))
                        bankInventory.Add(bankInfo);
                }
            }
        }

        return bankInventory;
    }

    public static string GetDecompiledBanksFolder()
    {
        return Path.Combine(MilanShared.PipelineRoot, "Audio", "DecompiledBanks");
    }

    /// <summary>
    /// Extracts audio from ME3 banks and prepares them for import into Wwise.
    /// </summary>
    /// <param name="vars"></param>
    /// <param name="bankInventory"></param>
    private static void DecompileBanks(AudioVars vars, List<MilanBankRebuildInfo> bankInventory)
    {
        foreach (var bankInfo in bankInventory)
        {
            DecompileME3WwiseBank(vars, bankInfo);
        }
    }

    private static void DecompileME3WwiseBank(AudioVars vars, MilanBankRebuildInfo bankRebuildInfo)
    {
        var sourcePackages = MilanShared.ME3ObjectDB.GetFilesContainingObject(bankRebuildInfo.LocalizedInfo.InstancedFullPath, bankRebuildInfo.LocalizedInfo.Localization);
        if (sourcePackages == null || sourcePackages.Count == 0)
        {
            // Probably don't have localized package available for this right now
            return;
        }
        var sourcePackage = MilanShared.GetME3Package(Path.GetFileName(sourcePackages[0]));
        var bankEntry = sourcePackage.FindExport(bankRebuildInfo.LocalizedInfo.InstancedFullPath);
        bankRebuildInfo.ME3BankExport = bankEntry;

        MilanLog.Information($"Decompiling {bankEntry.InstancedFullPath}", customPrefix: LOG_CATEGORY);
        Directory.CreateDirectory(bankRebuildInfo.GetDecompiledFolderName());

        bankRebuildInfo.BuildEventToStreamMap();
        foreach (var se in bankRebuildInfo.EventToStreamMap)
        {
            foreach (var stream in se.Value)
            {
                MilanLog.Information($"  Extracting WwiseStream {stream.InstancedFullPath}", customPrefix: LOG_CATEGORY);
                var wwstream = ObjectBinary.From<WwiseStream>(stream);
                var waveStream = wwstream.CreateWaveStream();
                var outPath = Path.Combine(bankRebuildInfo.GetDecompiledFolderName(), stream.ObjectName.Name[..^4] + ".wav"); // This removes _wav
                waveStream.WriteToFile(outPath);
            }
        }
    }
}