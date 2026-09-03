namespace BankConverter.Bnk.Hirc;

/// <summary>
/// Detects Wwise plugin IDs that belong to a third-party/studio-proprietary company registration
/// rather than a standard Audiokinetic-shipped plugin. Confirmed against the real Wwise SDK header
/// (AkTypes.h): AKCOMPANYID_PLUGINDEV_MIN(64)..AKCOMPANYID_PLUGINDEV_MAX(255) is the range game studios
/// register their own custom Source/Effect plugins under - BioWare used this for at least two real ME3
/// assets found so far (a custom Source plugin on a Collector Adept power, and a custom Effect plugin on
/// a shared ActorMixer in Wwise_GUI_DLC_MP3). LE3's stock Wwise 2019 runtime has no equivalent for either
/// - it never linked BioWare's original plugin code - so passing such a reference through unchanged asks
/// LE3 to instantiate a plugin it doesn't have.
/// </summary>
public static class PluginSupport
{
    private const uint CompanyIdPluginDevMin = 64;
    private const uint CompanyIdPluginDevMax = 255;

    /// <summary>AkPluginID layout: (companyID &lt;&lt; 16) | (pluginID &lt;&lt; 4) | pluginType(4 bits).</summary>
    private static uint GetCompanyId(uint pluginId) => pluginId >> 16;

    public static bool IsThirdParty(uint pluginId)
    {
        var companyId = GetCompanyId(pluginId);
        return companyId is >= CompanyIdPluginDevMin and <= CompanyIdPluginDevMax;
    }
}
