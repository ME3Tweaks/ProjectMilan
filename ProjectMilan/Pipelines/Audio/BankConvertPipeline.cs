using LegendaryExplorerCore.Helpers;
using LegendaryExplorerCore.Packages;
using ME3Tweaks.Wwiser;

namespace ProjectMilan.Pipelines.Audio;

internal static class BankConvertPipeline
{
    private const string LOG_CATEGORY = @"MILAN-Audio-Convert";

    public static async Task RunPipeline(List<MilanBankInfo> bankInventory,  AudioVars vars)
    {
        MilanLog.Information("The following banks will be converted using Wwiser:", customPrefix: LOG_CATEGORY);
        foreach (var lifp in bankInventory)
        {
            MilanLog.Information($"  {lifp?.LocalizedInfo}", customPrefix: LOG_CATEGORY);
        }

        foreach (var b in bankInventory)
        {
            // Skip data header
            var bankWithoutHeader = b.Export.GetBinaryData().Skip(sizeof(uint) * 4).ToArray();
            var bank = new WwiseBankParser(new MemoryStream(bankWithoutHeader));
            await bank.Deserialize();
            
            bank.ConvertToVersion(134);

            var dataOut = new MemoryStream();
            await bank.Serialize(dataOut);
            
            var length = dataOut.Length;
            dataOut.Position = 0;
            
            // Write Bulk Data header
            MemoryStream outStream = new MemoryStream();
            outStream.WriteInt32(0); // Local
            outStream.WriteInt32((int)length); // Compressed size
            outStream.WriteInt32((int)length); // Decompressed size
            outStream.WriteInt32(0); // Data offset - this is not external so this is not used
            await dataOut.CopyToAsync(outStream);
            b.Export.WriteBinary(outStream.ToArray()); // Do not use buffer
            
            b.Export.FileRef.Save();
        }
    }
}