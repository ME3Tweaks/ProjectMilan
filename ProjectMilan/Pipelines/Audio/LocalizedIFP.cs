using LegendaryExplorerCore.Packages;

namespace ProjectMilan.Pipelines.Audio;

/// <summary>
/// Represents an object path with respect to localization
/// </summary>
internal class LocalizedIFP
{
    public string InstancedFullPath { get; set; }
    public MELocalization Localization { get; set; }

    public override bool Equals(object other)
    {
        var otherLIFP = other as LocalizedIFP;
        if (otherLIFP == null)
            return false;

        return otherLIFP.Localization == Localization && otherLIFP.InstancedFullPath == InstancedFullPath;
    }

    public override string ToString()
    {
        if (Localization == MELocalization.None)
        {
            return InstancedFullPath;
        }

        return $"{InstancedFullPath}({Localization})";
    }
}