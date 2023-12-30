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

        foreach (var b in bankInventory)
        {
            MilanLog.Information($" - Converting {b.LocalizedInfo} in {Path.GetFileName(b.LE3BankExport.FileRef.FilePath)}", customPrefix: LOG_CATEGORY);
            if(b.BankParser is null) continue;
            
            // Skip data header
            b.BankParser.Deserialize(); // Deserialize binary into object graph
            
            b.BankParser.ConvertToVersion(134); // Run Wwiser version convert

            var dataOut = new MemoryStream();
            b.BankParser.SerializeTo(dataOut);
            
            WwiseBank.WriteBankRaw(dataOut.ToArray(), b.LE3BankExport);
            b.LE3BankExport.FileRef.Save();
        }
    }
    
}