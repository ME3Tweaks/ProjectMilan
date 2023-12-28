using LegendaryExplorerCore.Helpers;
using LegendaryExplorerCore.Packages;
using ME3Tweaks.Wwiser;

namespace ProjectMilan.Pipelines.Audio;

/// <summary>
/// Pipeline for converting WwiseBanks from ME3 to LE3 using the Wwiser.NET tool
/// </summary>
internal static class BankConvertPipeline
{
    private const string LOG_CATEGORY = @"MILAN-Audio-WwiserConvert";

    public static void RunPipeline(List<MilanBankInfo> bankInventory)
    {
        MilanLog.Information("Converting banks using Wwiser.NET", customPrefix: LOG_CATEGORY);

        foreach (var b in bankInventory)
        {
            MilanLog.Information($" - Converting {b.LocalizedInfo}", customPrefix: LOG_CATEGORY);
            
            // Skip data header
            var bankWithoutHeader = b.Export.GetBinaryData().Skip(sizeof(uint) * 4).ToArray();
            var bank = new WwiseBankParser(new MemoryStream(bankWithoutHeader));
            bank.Deserialize(); // Deserialize binary into object graph
            
            bank.ConvertToVersion(134); // Run Wwiser version convert

            var dataOut = new MemoryStream();
            bank.SerializeTo(dataOut);
            
            var length = dataOut.Length;
            dataOut.Position = 0;
            
            // Write Bulk Data header
            MemoryStream outStream = new MemoryStream();
            outStream.WriteInt32(0); // Local
            outStream.WriteInt32((int)length); // Compressed size
            outStream.WriteInt32((int)length); // Decompressed size
            outStream.WriteInt32(0); // Data offset - this is not external so this is not used
            dataOut.CopyTo(outStream);
            b.Export.WriteBinary(outStream.ToArray());
            
            b.Export.FileRef.Save();
        }
    }
}