using LegendaryExplorerCore.Packages;
using ME3Tweaks.Wwiser;
using LECWwiseBank = LegendaryExplorerCore.Unreal.BinaryConverters.WwiseBank;

namespace ProjectMilan.Pipelines.Audio;

internal class MilanBankConvertInfo
{
    /// <summary>
    /// ExportEntry of the LE3 wwisebank
    /// </summary>
    public ExportEntry LE3BankExport { get; set; }
    
    public LECWwiseBank ObjectBinary { get; set; }
    
    /// <summary>
    /// Instance of Wwiser.NET bank
    /// </summary>
    public WwiseBankParser? BankParser { get; set; }
    
    public LocalizedIFP LocalizedInfo { get; set; }
    
    public MilanBankConvertInfo(ExportEntry le3BankExport)
    {
        if (le3BankExport.ClassName != "WwiseBank") throw new ArgumentException("Export must be WwiseBank!");
        if (le3BankExport.DataSize == 0) throw new ArgumentException("WwiseBank Export has no binary data!");
        LE3BankExport = le3BankExport;
        LocalizedInfo = new LocalizedIFP()
        {
            Localization = LE3BankExport.FileRef.Localization,
            InstancedFullPath = LE3BankExport.InstancedFullPath
        };

        ObjectBinary = LE3BankExport.GetBinaryData<LECWwiseBank>();
        if (ObjectBinary.BnkFile.Length == 0) return;
        BankParser = new WwiseBankParser(new MemoryStream(ObjectBinary.BnkFile));
    }
}