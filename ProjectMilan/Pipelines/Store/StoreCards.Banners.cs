using ProjectMilanCore;
using ProjectMilanCore.Config.Store;
using ProjectMilanCore.Utility;

namespace ProjectMilan.Pipelines.Store;

public static partial class StoreCards
{
    // Add authored banners here. IDs are explicit; changing list order must never change saved ownership.
    private static IEnumerable<StoreCard> Banners => [];

    public static StoreCard Banner(int emblemId, string uniqueName, int playerVariableId, int titleStrRefId,
        string image, CardRarity rarity, params StorePool[] pools) => new()
    {
        BannerID = emblemId,
        UniqueName = uniqueName,
        Kind = ReinforcementKind.PermanentUpgrade,
        Rarity = rarity,
        MaxCount = 1,
        GUIName = titleStrRefId,
        GUIType = "banner",
        GUITextureRef = image,
        PlayerVariableIds = [playerVariableId],
        Pools = (pools.Length == 0 ? [StorePools.BannerPool(rarity)] : pools).Select(p => new PoolEntry(p)).ToList(),
    };

    public static StoreCard Banner(int emblemId, string uniqueName, int playerVariableId, LocalizedString title,
        string image, CardRarity rarity, params StorePool[] pools) =>
        Banner(emblemId, uniqueName, playerVariableId, MilanPipelinesShared.AssignTLK(title), image, rarity, pools);
}
