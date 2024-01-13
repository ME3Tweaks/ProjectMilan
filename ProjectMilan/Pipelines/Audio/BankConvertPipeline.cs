using System.Collections.Concurrent;
using System.Diagnostics;
using LegendaryExplorerCore.Helpers;
using LegendaryExplorerCore.Packages;
using ME3Tweaks.Wwiser;
using ProjectMilan.Utility;
using WwiseBank = LegendaryExplorerCore.Unreal.BinaryConverters.WwiseBank;

namespace ProjectMilan.Pipelines.Audio;

/// <summary>
/// Pipeline for converting WwiseBanks from ME3 to LE3 using the Wwiser.NET tool
/// </summary>
internal static class BankConvertPipeline
{
    private const string LOG_CATEGORY = @"MILAN-Audio-WwiserConvert";

    public static void RunPipeline(List<MilanBankConvertInfo> bankInventory)
    {
        MilanLog.Information("Converting banks using Wwiser.NET", customPrefix: LOG_CATEGORY);

        var packageMap = new Dictionary<IMEPackage, List<MilanBankConvertInfo>>();
        foreach (var f in bankInventory)
        {
            if (!packageMap.TryGetValue(f.LE3BankExport.FileRef, out var list))
            {
                list = new List<MilanBankConvertInfo>();
                packageMap[f.LE3BankExport.FileRef] = list;
            }

            list.Add(f);
        }

        var bankCacheFolder = Path.Combine(MilanShared.PipelineRoot, "Audio", "ConvertedBankCache");
        Directory.CreateDirectory(bankCacheFolder);
        Utilities.DeleteFilesAndFoldersRecursively(bankCacheFolder, deleteDirectoryItself:false);
        var bankCache = new ConcurrentDictionary<string, string>();

        Parallel.ForEach(packageMap,
            new ParallelOptions() { MaxDegreeOfParallelism = /* 1 */ Program.Settings.MaxThreads }, map =>
            {
                foreach (var b in map.Value)
                {
                    if(bankCache.TryGetValue(b.LocalizedInfo.ToString(), out var value))
                    {
                        MilanLog.Information(
                            $" - Already converted {b.LocalizedInfo} in {Path.GetFileName(b.LE3BankExport.FileRef.FilePath)} - copying from cache",
                            customPrefix: LOG_CATEGORY);
                        var bank = File.ReadAllBytes(value);
                        WwiseBank.WriteBankRaw(bank, b.LE3BankExport);
                    }
                    else
                    {
                        MilanLog.Information(
                            $" - Converting {b.LocalizedInfo} in {Path.GetFileName(b.LE3BankExport.FileRef.FilePath)}",
                            customPrefix: LOG_CATEGORY);
                        if (b.BankParser is null) continue;
                        try
                        {
                            var bankArray = ConvertBank(b, bankCache).ToArray();
                            WwiseBank.WriteBankRaw(bankArray, b.LE3BankExport);
                            
                            var cacheFileName = Path.Combine(bankCacheFolder, $"{b.LocalizedInfo}.bnk");
                            if (bankCache.TryAdd(b.LocalizedInfo.ToString(), cacheFileName))
                            {
                                File.WriteAllBytes(cacheFileName, bankArray);
                            }
                        }
                        catch (Exception e)
                        {
                            MilanLog.Exception(e, $"Error converting WwiseBank {b.LE3BankExport.InstancedFullPath}",
                                customPrefix: LOG_CATEGORY);
                        }
                    }
                }

                // Save package
                map.Key.Save();
            });
    }

    private static MemoryStream ConvertBank(MilanBankConvertInfo b, ConcurrentDictionary<string, string> cache)
    {
        if (b.BankParser is null) return new MemoryStream();
        
        b.BankParser.Deserialize(); // Deserialize binary into object graph

        b.BankParser.ConvertToVersion(134); // Run Wwiser version convert

        // No STID chunks found on LE wwise banks
        if (b.BankParser.WwiseBank != null)
        {
            b.BankParser.WwiseBank.STID = null;
        }

        var dataOut = new MemoryStream();
        b.BankParser.SerializeTo(dataOut);
        return dataOut;
    }
}