using LegendaryExplorerCore.Helpers;
using LegendaryExplorerCore.Packages;
using ME3Tweaks.Wwiser;
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

        Parallel.ForEach(packageMap, new ParallelOptions() { MaxDegreeOfParallelism = /* 1 */ Program.Settings.MaxThreads }, map =>
            {
                foreach (var b in map.Value)
                {
                    MilanLog.Information(
                        $" - Converting {b.LocalizedInfo} in {Path.GetFileName(b.LE3BankExport.FileRef.FilePath)}",
                        customPrefix: LOG_CATEGORY);
                    if (b.BankParser is null) continue;

                    // Skip data header
                    try
                    {
                        b.BankParser.Deserialize(); // Deserialize binary into object graph

                        b.BankParser.ConvertToVersion(134); // Run Wwiser version convert

                        var dataOut = new MemoryStream();
                        b.BankParser.SerializeTo(dataOut);

                        WwiseBank.WriteBankRaw(dataOut.ToArray(), b.LE3BankExport);
                    }
                    catch (Exception e)
                    {
                        MilanLog.Exception(e, $"Error converting WwiseBank {b.LE3BankExport.InstancedFullPath}", customPrefix: LOG_CATEGORY);
                    }
                }

                // Save package
                map.Key.Save();
            });
    }

}