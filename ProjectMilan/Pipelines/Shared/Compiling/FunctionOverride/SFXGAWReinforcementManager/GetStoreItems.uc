// MILAN Change - 12/10/2023
// By Mgamerz
// Purpose: Prevent game crash if StoreData array is empty, as game cannot handle sorting an empty array
public final function array<StoreGUIData> GetStoreItems()
{
    local array<StoreGUIData> StoreData;
    local StoreGUIData NewItem;
    local int idx;
    local int nOfferIndex;
    local int nCurrentTime;
    local StoreInfoEntry CurrStoreItem;
    local array<BWOfferInfo> Offers;
    local array<BWEntitlementInfo> Entitlements;
    local SFXEngine Engine;
    local BWConsumableInfo i;
    
    Engine = Class'SFXEngine'.static.GetSFXEngine();
    nCurrentTime = Class'SFXOnlineSubsystem'.static.GetOnlineSubsystem().GetComponentAPI().GetCurrentTime();
    Class'SFXOnlineSubsystem'.static.GetOnlineSubsystem().GetComponentCommerce().GetOffersList(Offers);
    Class'SFXOnlineSubsystem'.static.GetOnlineSubsystem().GetComponentCommerce().GetEntitlementsList(Entitlements);
    for (idx = 0; idx < StoreInfoArray.Length; ++idx)
    {
        CurrStoreItem = StoreInfoArray[idx];
        if (!Engine.HasRequiredDLC(CurrStoreItem.RequiredDLCModuleIDs))
        {
            continue;
        }
        if (CurrStoreItem.RevealTime > float(0) && CurrStoreItem.RevealTime > float(nCurrentTime) || CurrStoreItem.ExpirationTime > float(0) && float(nCurrentTime) > CurrStoreItem.ExpirationTime)
        {
            continue;
        }
        if (CurrStoreItem.PerPlayerMax > 0 && Engine.GetPlayerVariable(Name(CurrStoreItem.PackName)) >= CurrStoreItem.PerPlayerMax)
        {
            continue;
        }
        NewItem.nID = CurrStoreItem.nID;
        if (CurrStoreItem.srPromoString == 0)
        {
            NewItem.PromoText = "";
        }
        else
        {
            NewItem.PromoText = string(CurrStoreItem.srPromoString);
        }
        NewItem.ImageData = CurrStoreItem.ImageData;
        if (!CheckOfferVisibility(CurrStoreItem, Entitlements))
        {
            continue;
        }
        nOfferIndex = -1;
        if (CurrStoreItem.offerId != 0)
        {
            nOfferIndex = FindOfferIndex(CurrStoreItem.offerId, Offers);
        }
        if (nOfferIndex >= 0)
        {
            foreach OutstandingConsumableIDs(i, )
            {
                if (i.Id.nID == CurrStoreItem.offerId)
                {
                    nOfferIndex = -1;
                    break;
                }
            }
        }
        NewItem.EPurchaseType = EPurchaseType.EPurchaseType_Unknown;
        NewItem.DisplayTitle = string(CurrStoreItem.Title);
        NewItem.DisplaySubtitle = string(CurrStoreItem.SubTitle);
        NewItem.Description = string(CurrStoreItem.Description);
        NewItem.bExpires = CurrStoreItem.ExpirationTime != float(0);
        NewItem.DescriptionTitle = (NewItem.DisplayTitle $ " ") $ NewItem.DisplaySubtitle;
        if (nOfferIndex >= 0)
        {
            NewItem.EPurchaseType = GetStoreItemPurchaseType(CurrStoreItem, Offers[nOfferIndex].sPrice);
        }
        else
        {
            NewItem.EPurchaseType = GetStoreItemPurchaseType(CurrStoreItem);
        }
        if (NewItem.EPurchaseType == EPurchaseType.EPurchaseType_Unknown)
        {
            continue;
        }
        StoreData.AddItem(NewItem);
    }
    // MILAN Change - game crashes if you attempt to sort a list without at least 2 items
    if (StoreData.Length > 1)
    {
        StoreData.Sort(StoreItemSort);
    }
    return StoreData;
}