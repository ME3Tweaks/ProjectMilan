using LegendaryExplorerCore.Helpers;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Unreal;
using LegendaryExplorerCore.Unreal.BinaryConverters;
using ProjectMilan.Pipelines.Audio.Extension;
using ProjectMilan.Utility;

namespace ProjectMilan.Pipelines.Audio;

internal static class AudioPipeline
{
    private const string LOG_CATEGORY = @"MILAN-Audio";

    public static void RunPipeline()
    {
        // Find all banks that need to be rebuilt
        var banksToPort = GetBanksNotInLE3();

        var vars = new AudioVars
        {
            ProjectDir = Path.Combine(MilanShared.PipelineRoot, "Audio", "Wwise", "Milan")
        };
            
        if (Directory.Exists(vars.ProjectDir))
        {
            Utilities.DeleteFilesAndFoldersRecursively(vars.ProjectDir);
        }
        
        // Decompile the audio from the banks
        DecompileBanks(vars, banksToPort);

        var streamingBanks = banksToPort.Where(b => b.EventToStreamMap.Count == 0).ToList();
        var nonStreamingBanks = banksToPort.Where(b => b.EventToStreamMap.Count != 0).ToList();
        
        
        //AudioRebuild.RunPipeline(streamingBanks, vars);
        BankConvertPipeline.RunPipeline(nonStreamingBanks);
    }

    private static List<MilanBankInfo> GetBanksNotInLE3()
    {
        List<MilanBankInfo> bankInventory = new List<MilanBankInfo>();
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
                    var bankInfo = new MilanBankInfo()
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
    private static void DecompileBanks(AudioVars vars, List<MilanBankInfo> bankInventory)
    {
        foreach (var bankInfo in bankInventory)
        {
            DecompileME3WwiseBank(vars, bankInfo);
        }
    }

    private static void DecompileME3WwiseBank(AudioVars vars, MilanBankInfo bankInfo)
    {
        var sourcePackages = MilanShared.ME3ObjectDB.GetFilesContainingObject(bankInfo.LocalizedInfo.InstancedFullPath, bankInfo.LocalizedInfo.Localization);
        if (sourcePackages == null || sourcePackages.Count == 0)
        {
            // Probably don't have localized package available for this right now
            return;
        }
        var sourcePackage = MilanShared.GetME3Package(Path.GetFileName(sourcePackages[0]));
        var bankEntry = sourcePackage.FindExport(bankInfo.LocalizedInfo.InstancedFullPath);
        bankInfo.Export = bankEntry;

        MilanLog.Information($"Decompiling {bankEntry.InstancedFullPath}", customPrefix: LOG_CATEGORY);
        Directory.CreateDirectory(bankInfo.GetDecompiledFolderName());

        bankInfo.EventToStreamMap = BuildEventToStreamMap(bankEntry);
        foreach (var se in bankInfo.EventToStreamMap)
        {
            foreach (var stream in se.Value)
            {
                MilanLog.Information($"  Extracting WwiseStream {stream.InstancedFullPath}", customPrefix: LOG_CATEGORY);
                var wwstream = ObjectBinary.From<WwiseStream>(stream);
                var waveStream = wwstream.CreateWaveStream();
                var outPath = Path.Combine(bankInfo.GetDecompiledFolderName(), stream.ObjectName.Name[..^4] + ".wav"); // This removes _wav
                waveStream.WriteToFile(outPath);
            }
        }
    }

    /// <summary>
    /// Maps events to their streams (only works due to how ME3 does events. Does not work for LE3). Does not account for non streaming audio.
    /// </summary>
    /// <param name="bankEntry"></param>
    /// <returns></returns>
    private static Dictionary<ExportEntry, List<ExportEntry>> BuildEventToStreamMap(ExportEntry bankEntry)
    {
        var EventToStreamMap = new Dictionary<ExportEntry, List<ExportEntry>>();
        foreach (var evt in bankEntry.FileRef.Exports.Where(x => x.ClassName == "WwiseEvent"))
        {
            var bank = evt.GetProperty<StructProperty>("Relationships").GetProp<ObjectProperty>("Bank").ResolveToEntry(bankEntry.FileRef) as ExportEntry;
            if (bank != bankEntry)
                continue; // Not our bank
            var wwiseBin = ObjectBinary.From<WwiseEvent>(evt);
            if (wwiseBin.Links != null && wwiseBin.Links.Count == 1 && wwiseBin.Links[0].WwiseStreams.Count >= 1)
            {
                var streams = new List<ExportEntry>();
                EventToStreamMap[evt] = streams;
                foreach (var stream in wwiseBin.Links[0].WwiseStreams)
                {
                    streams.Add(bank.FileRef.GetUExport(stream)); // Should this be IEntry?
                }
            }
        }

        return EventToStreamMap;
    }
}