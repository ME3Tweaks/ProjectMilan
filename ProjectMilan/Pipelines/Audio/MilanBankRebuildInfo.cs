using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Unreal;
using LegendaryExplorerCore.Unreal.BinaryConverters;

namespace ProjectMilan.Pipelines.Audio;

/// <summary>
/// Information about ME3 sound bank that is being ported to LE3
/// </summary>
internal class MilanBankRebuildInfo
{
    /// <summary>
    /// How to find the bank
    /// </summary>
    public LocalizedIFP LocalizedInfo { get; set; }

    /// <summary>
    /// ME3 has one event map to its referenced streams. LE3 lists all streams in every event.
    /// </summary>
    public Dictionary<ExportEntry, List<ExportEntry>> EventToStreamMap { get; set; }

    /// <summary>
    /// Source bank export.
    /// </summary>
    public ExportEntry ME3BankExport { get; set; }

    // Eventually we will need additional information such as random containers.

    public override bool Equals(object other)
    {
        var otherLIFP = other as MilanBankRebuildInfo;
        if (otherLIFP == null)
            return false;

        return otherLIFP.LocalizedInfo.Localization == LocalizedInfo.Localization && otherLIFP.LocalizedInfo.InstancedFullPath == LocalizedInfo.InstancedFullPath;
    }

    public string GetDecompiledFolderName()
    {
        var outDir = Path.Combine(DeprecatedAudioPipeline.GetDecompiledBanksFolder(), ME3BankExport.ObjectName);
        if (LocalizedInfo.Localization != MELocalization.None)
        {
            outDir += $"_{LocalizedInfo.Localization}";
        }

        return outDir;
    }
    
    /// <summary>
    /// Maps events to their streams (only works due to how ME3 does events. Does not work for LE3). Does not account for non streaming audio.
    /// </summary>
    public void BuildEventToStreamMap()
    {
        EventToStreamMap = new Dictionary<ExportEntry, List<ExportEntry>>();
        foreach (var evt in ME3BankExport.FileRef.Exports.Where(x => x.ClassName == "WwiseEvent"))
        {
            var bank = evt.GetProperty<StructProperty>("Relationships").GetProp<ObjectProperty>("Bank").ResolveToEntry(ME3BankExport.FileRef) as ExportEntry;
            if (bank != ME3BankExport)
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
    }
}