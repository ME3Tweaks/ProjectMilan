using LegendaryExplorerCore.Packages;

namespace ProjectMilan.Pipelines.Audio;

/// <summary>
/// Information about ME3 sound bank that is being ported to LE3
/// </summary>
class MilanBankInfo
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
    public ExportEntry Export { get; set; }

    // Eventually we will need additional information such as random containers.

    public override bool Equals(object other)
    {
        var otherLIFP = other as MilanBankInfo;
        if (otherLIFP == null)
            return false;

        return otherLIFP.LocalizedInfo.Localization == LocalizedInfo.Localization && otherLIFP.LocalizedInfo.InstancedFullPath == LocalizedInfo.InstancedFullPath;
    }

    public string GetDecompiledFolderName()
    {
        var outDir = Path.Combine(AudioPipeline.GetDecompiledBanksFolder(), Export.ObjectName);
        if (LocalizedInfo.Localization != MELocalization.None)
        {
            outDir += $"_{LocalizedInfo.Localization}";
        }

        return outDir;
    }
}