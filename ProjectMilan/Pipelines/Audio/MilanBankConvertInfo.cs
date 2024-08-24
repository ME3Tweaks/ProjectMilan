using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Unreal;
using ME3Tweaks.Wwiser;
using System.Diagnostics;
using LECWwiseBank = LegendaryExplorerCore.Unreal.BinaryConverters.WwiseBank;

namespace ProjectMilan.Pipelines.Audio;

[DebuggerDisplay("{LocalizedInfo}")]
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

    public string AFCName { get; set; }
    
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

        var firstStream = LE3BankExport.FileRef.Exports.FirstOrDefault(e => e.ClassName == "WwiseStream" && e.InstancedFullPath.Contains(LE3BankExport.ObjectNameString));
        AFCName = firstStream?.GetProperty<NameProperty>("Filename").Value ?? "";

        ObjectBinary = LE3BankExport.GetBinaryData<LECWwiseBank>();
        if (ObjectBinary.BnkFile.Length == 0) return;
        BankParser = new WwiseBankParser(new MemoryStream(ObjectBinary.BnkFile));

    }

    public string GetDecompiledFolderName()
    {
        var outDir = Path.Combine(DeprecatedAudioPipeline.GetDecompiledBanksFolder(), LE3BankExport.ObjectName);
        if (LocalizedInfo.Localization != MELocalization.None)
        {
            outDir += $"_{LocalizedInfo.Localization}";
        }

        return outDir;
    }


    public List<ExportEntry> GetStreams()
    {
        var streams = new List<ExportEntry>();

        foreach(var e in LE3BankExport.FileRef.Exports.Where(e => e.ClassName == "WwiseStream"))
        {
            // Looking for streams that are underneath the package export containing the name of the bank.
            // TODO: Is this true for all banks? bankname_D package always?

            if (e.InstancedFullPath.Contains(LE3BankExport.ObjectNameString))
            {
                streams.Add(e);
            }
        }

        return streams;
    }
}