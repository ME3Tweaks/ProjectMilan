// MILAN CHANGE 12/10/2023, 09/27/2026
// By Mgamerz
// Purpose: Prevent crashes sorting when there are no elements in the array, remove delegate so sort works
Class SFXGAWReinforcementManager extends SFXGAWReinforcementManagerBase
    config(Game);

struct StoreGUIData 
{
    var StoreImageData ImageData;
    var string DisplayTitle;
    var string DisplaySubtitle;
    var string DescriptionTitle;
    var string Description;
    var string PromoText;
    var int nID;
    var bool bExpires;
    var EPurchaseType EPurchaseType;
};
struct CardPackEntry 
{
    var string PackName;
    var array<CardPoolEntry> Pools;
    var string BackupPool;
    var int Quantity;
    
    structdefaultproperties
    {
        Quantity = 1
    }
};
struct CardPoolEntry 
{
    var string PoolName;
    var float Weight;
    
    structdefaultproperties
    {
        Weight = 1.0
    }
};
struct ConsumableToPackEntry 
{
    var string PackName;
    var int Id;
};
struct StoreInfoEntry 
{
    var StoreImageData ImageData;
    var string PackName;
    var array<VisibleCondition> visible;
    var config array<int> RequiredDLCModuleIDs;
    var string RevealIntroTextureRef;
    var string RevealIntroHoloTextureRef;
    var Name RevealIntroSound;
    var int nID;
    var stringref Title;
    var stringref SubTitle;
    var stringref Description;
    var int CreditCost;
    var float ExpirationTime;
    var float RevealTime;
    var int offerId;
    var stringref srPromoString;
    var int PerPlayerMax;
    var bool bDisabled;
    
    structdefaultproperties
    {
        CreditCost = -1
    }
};
struct StoreImageData 
{
    var string ImageReference;
    var EStoreImageLocation ImageLocation;
    
    structdefaultproperties
    {
        ImageLocation = EStoreImageLocation.EStoreImageLocation_Default
    }
};
struct VisibleCondition
{
    var array<int> and;
};
// MILAN CHANGE - Mgamerz - 2026-10-22
// Store pack that is only listed once the player has an LE achievement
struct MilanAchievementPack
{
    var string PackName;
    var int AchievementId;
    var Name UnlockVariable;
};
// END MILAN CHANGE
enum EPurchaseType
{
    EPurchaseType_CreditsOnly,
    EPurchaseType_PlatformOnly,
    EPurchaseType_PlatformAndCredits,
    EPurchaseType_Free,
    EPurchaseType_Unknown,
};
enum EStoreImageLocation
{
    EStoreImageLocation_Local,
    EStoreImageLocation_Remote,
    EStoreImageLocation_Default,
};

var config array<CardPackEntry> PackList;
var config array<StoreInfoEntry> StoreInfoArray;
var config array<ConsumableToPackEntry> ConsumableIdPackNameMap;
var config array<CardInfoData> CardData;
var array<CardInfoData> LastAwardedCards;
var array<CardInfoData> AwardedCards;
var string LastAwardedPackName;
var array<CardInfoData> ManualAwardedCards;
var string ManualAwardedPackName;
var array<SFXGAWReinforcementMatchConsumable> MatchConsumables;
var array<SFXGAWReinforcementBase> Deck;
var array<BWConsumableInfo> OutstandingConsumableIDs;
var array<Class<Object>> KnownConsumableTypes;
var string sCachedDataBaseKey;
var int ConsumptionFlowResult;
var config int fTimeoutRefreshDigitalRights;
var config int fTimeoutRefreshMPSaves;
var config int fTimeoutConsumeID;
var config int fTimeoutSaveMPRecord;
var config BWEntitlementId PackPurchasedEntitlement;
var int nTestConsumptionError;
var transient SFXSaveManagerMP SaveManager;
var bool bFetchingProductDetails;
var bool bRetryProcessConsumables;
var bool bProcessConsumableCriticalError;
var bool m_bCreditPurchaseRetry;
// MILAN CHANGE
var config array<MilanAchievementPack> MilanAchievementPacks;
var transient bool bMilanAchievementPacksChecked;
// END MILAN CHANGE

// MILAN CHANGE - Mgamerz - 2026-10-21
// Prevents unlocking an acheivement pack twice
private final function RefreshMilanAchievementPacks()
{
    local SFXOnlineComponentOrigin Origin;
    local SFXEngine Engine;
    local MilanAchievementPack AchPack;
    local int StoreInfoIdx;
    local bool bChanged;

    if (bMilanAchievementPacksChecked || MilanAchievementPacks.Length == 0)
    {
        return;
    }
    Origin = Class'SFXOnlineSubsystem'.static.GetOnlineSubsystem().GetComponentOrigin();
    if (Origin == None)
    {
        return;
    }
    bMilanAchievementPacksChecked = TRUE;
    Engine = Class'SFXEngine'.static.GetSFXEngine();
    foreach MilanAchievementPacks(AchPack, )
    {
        if (Engine.GetPlayerVariable(AchPack.UnlockVariable) > 0)
        {
            continue;
        }
        StoreInfoIdx = StoreInfoArray.Find('PackName', AchPack.PackName);
        if (StoreInfoIdx >= 0 && StoreInfoArray[StoreInfoIdx].PerPlayerMax > 0 && Engine.GetPlayerVariable(Name(AchPack.PackName)) >= StoreInfoArray[StoreInfoIdx].PerPlayerMax)
        {
            continue;
        }
        if (Origin.IsAchievementGranted(AchPack.AchievementId))
        {
            Engine.SetPlayerVariable(AchPack.UnlockVariable, 1);
            bChanged = TRUE;
        }
    }
    if (bChanged && Engine.MPSaveManager != None)
    {
        Engine.MPSaveManager.SaveRecords();
    }
}
private final function bool IsMilanAchievementPackUnlocked(string PackName)
{
    local int idx;

    idx = MilanAchievementPacks.Find('PackName', PackName);
    if (idx == -1)
    {
        return TRUE;
    }
    return Class'SFXEngine'.static.GetSFXEngine().GetPlayerVariable(MilanAchievementPacks[idx].UnlockVariable) > 0;
}
// END MILAN CHANGE

public function bool CanAffordNewStoreItems(int OldCredits, int NewCredits)
{
    local int idx;
    
    for (idx = 0; idx < StoreInfoArray.Length; ++idx)
    {
        if (OldCredits < StoreInfoArray[idx].CreditCost && NewCredits >= StoreInfoArray[idx].CreditCost)
        {
            return TRUE;
        }
    }
    return FALSE;
}
private final function GetProductDetailsComplete()
{
    bFetchingProductDetails = FALSE;
}
public final function bool IsFetchingProductDetails()
{
    return bFetchingProductDetails;
}
public final function LoadDeck()
{
    local array<Object> ObjectCards;
    local Object ObjectCard;
    local SFXEngine Engine;
    local SFXGAWReinforcementBase Card;
    local SFXGAWReinforcementMatchConsumable MatchConsumable;
    
    Engine = Class'SFXEngine'.static.GetSFXEngine();
    if (Engine == None)
    {
        return;
    }
    Deck.Length = 0;
    MatchConsumables.Length = 0;
    GetObjectArrayFromConfigSection(Class'SFXGAWReinforcementBase', ObjectCards, TRUE);
    foreach ObjectCards(ObjectCard, )
    {
        Card = SFXGAWReinforcementBase(ObjectCard);
        if (Card == None)
        {
            continue;
        }
        if (!Engine.HasRequiredDLC(Card.RequiredDLCModuleIDs))
        {
            continue;
        }
        Card.Initialize();
        Card.GAWManager = Self;
        MatchConsumable = SFXGAWReinforcementMatchConsumable(Card);
        if (MatchConsumable != None)
        {
            MatchConsumables.AddItem(MatchConsumable);
        }
        Deck.AddItem(Card);
    }
}
// MILAN CHANGE - Remove delegate flag here, we don't want this as a delegate
public function int MatchConsumableSort(CardInfoData ItemA, CardInfoData ItemB)
{
    local string A;
    local string B;
    
    A = string(ItemA.GUIName);
    B = string(ItemB.GUIName);
    if (A > B)
    {
        return -1;
    }
    else
    {
        if (A == B && ItemA.VersionIdx > ItemB.VersionIdx)
        {
            return -1;
        }
        return 1;
    }
}
public delegate function OnProcessConsumablesDelegate(int nResult);

public delegate function OnPurchaseItemDelegate(int nResult);

public delegate function OnPurchaseItemWithCreditsDelegate(int nResult);

private final function OnPurchaseItemWithCreditsFinished(int nResult)
{
    local OnlinePlayerStorage PlayerStorage;
    local LocalPlayer LP;
    
    if (nResult == 0)
    {
        m_bCreditPurchaseRetry = FALSE;
        OnPurchaseItemWithCreditsDelegate(nResult);
        OnPurchaseItemWithCreditsDelegate = None;
        return;
    }
    if (!m_bCreditPurchaseRetry)
    {
        m_bCreditPurchaseRetry = TRUE;
        LP = LocalPlayer(BioWorldInfo(Class'WorldInfo'.static.GetWorldInfo()).GetLocalPlayerController().Player);
        PlayerStorage = Class'SFXOnlineSubsystem'.static.GetOnlineSubsystem().GetComponentUnrealPlayer().PlayerStorageCache[LP.ControllerId];
        if (PlayerStorage != None && PlayerStorage.GetProfileSettingValueByName('Base', sCachedDataBaseKey))
        {
            Class'SFXOnlineSubsystem'.static.GetOnlineSubsystem().GetComponentUnrealPlayer().PlayerStorageCache[LP.ControllerId] = None;
            SFXEngine(Class'Engine'.static.GetEngine()).ReadPlayerStorage(ReloadPlayerSettingsComplete);
            return;
        }
    }
    m_bCreditPurchaseRetry = FALSE;
    OnPurchaseItemWithCreditsDelegate(nResult);
    OnPurchaseItemWithCreditsDelegate = None;
}
public final function bool PopulateCardData(out CardInfoData Card)
{
    local int idx;
    local int IncrementBonus;
    local int Version;
    local ECardRarity Rarity;
    local int UniqueId;
    local stringref GUIName;
    local stringref GUIDesc;
    local int MaxCount;
    
    idx = CardData.Find('UniqueName', Card.UniqueName);
    if (idx >= 0)
    {
        IncrementBonus = Card.PVIncrementBonus;
        Version = Card.VersionIdx;
        Rarity = Card.Rarity;
        UniqueId = Card.UniqueId;
        GUIName = Card.GUIName;
        GUIDesc = Card.GUIDescription;
        MaxCount = Card.MaxCount;
        Card = CardData[idx];
        if (IncrementBonus > 0)
        {
            Card.PVIncrementBonus = IncrementBonus;
        }
        if (Version > 0)
        {
            Card.VersionIdx = Version;
        }
        if (int(Rarity) != 4)
        {
            Card.Rarity = Rarity;
        }
        if (GUIName != 0)
        {
            Card.GUIName = GUIName;
        }
        if (GUIDesc != 0)
        {
            Card.GUIDescription = GUIDesc;
        }
        if (MaxCount > 0)
        {
            Card.MaxCount = MaxCount;
        }
        Card.UniqueId = UniqueId;
        return TRUE;
    }
    return FALSE;
}
public final function ProcessConsumables(delegate<OnProcessConsumablesDelegate> ConsumeCallback, optional bool bRetry = FALSE)
{
    bProcessConsumableCriticalError = FALSE;
    ConsumptionFlowResult = 0;
    OnProcessConsumablesDelegate = ConsumeCallback;
    SaveManager = Class'SFXEngine'.static.GetSFXEngine().MPSaveManager;
    if (SaveManager == None)
    {
        ConsumptionFlowError("Error: [ProcessConsumables] Aborting processing of consumables - unable to find save manager", TRUE);
        return;
    }
    bRetryProcessConsumables = bRetry;
    if (ConsumptionFlow_SetCallbackTimer(float(fTimeoutRefreshDigitalRights)))
    {
        // MILAN Change - Change from online commerce delegate to just directly calling the result with code success
        // Strip out online commerce code
        ConsumptionFlow_Setup(0);
        // END MILAN CHANGE
    }
}
public final function bool PurchaseItemFromPlatform(int ItemId, delegate<OnPurchaseItemDelegate> PurchaseCallback)
{
    local int nItemIndex;
    local int nOfferIndex;
    local array<BWOfferInfo> Offers;
    local BWOfferInfo Offer;
    
    nItemIndex = StoreInfoArray.Find('nID', ItemId);
    if (nItemIndex >= 0)
    {
        Class'SFXOnlineSubsystem'.static.GetOnlineSubsystem().GetComponentCommerce().GetOffersList(Offers);
        if (Offers.Length <= 0)
        {
            return FALSE;
        }
        nOfferIndex = FindOfferIndex(StoreInfoArray[nItemIndex].offerId, Offers);
        if (nOfferIndex < 0 || nOfferIndex >= Offers.Length)
        {
            foreach Offers(Offer, )
            {
            }
            return FALSE;
        }
        OnPurchaseItemDelegate = PurchaseCallback;
        Class'SFXOnlineSubsystem'.static.GetOnlineSubsystem().GetComponentCommerce().PurchaseOfferId(Offers[nOfferIndex].Id, FinishPurchase);
        Class'SFXTelemetryHooksMP'.static.SendPurchaseOffer(Offers[nOfferIndex].Id.nID);
        return TRUE;
    }
    return FALSE;
}
public final function PurchaseItemWithCredits(int ItemId, delegate<SFXSaveManagerMP.OnSaveRecordsDelegate> SaveRecordsCallback)
{
    local SFXSaveManagerMP MPSaveManager;
    local int ItemIndex;
    
    MPSaveManager = SFXEngine(Class'Engine'.static.GetEngine()).MPSaveManager;
    ItemIndex = StoreInfoArray.Find('nID', ItemId);
    if (ItemIndex >= 0)
    {
        OnPurchaseItemWithCreditsDelegate = SaveRecordsCallback;
        AwardedCards.Length = 0;
        GiveCardPack(StoreInfoArray[ItemIndex].PackName);
        UpdateLastAwardedCards();
        MPSaveManager.SubtractCredits(StoreInfoArray[ItemIndex].CreditCost, StoreInfoArray[ItemIndex].PackName);
        MPSaveManager.SaveRecords(FALSE, OnPurchaseItemWithCreditsFinished);
    }
}
public function ReloadPlayerSettingsComplete(byte LocalUserNum, bool bWasSuccessful)
{
    local string refreshedBaseKey;
    local bool bBaseKeyWasSaved;
    local OnlinePlayerStorage PlayerStorage;
    
    SFXEngine(Class'Engine'.static.GetEngine()).ClearReadPlayerStorageCompleteDelegate(LocalUserNum, ReloadPlayerSettingsComplete);
    if (bWasSuccessful)
    {
        PlayerStorage = Class'SFXOnlineSubsystem'.static.GetOnlineSubsystem().GetComponentUnrealPlayer().PlayerStorageCache[int(LocalUserNum)];
        bBaseKeyWasSaved = PlayerStorage != None && PlayerStorage.GetProfileSettingValueByName('Base', refreshedBaseKey) && sCachedDataBaseKey == refreshedBaseKey;
        if (bBaseKeyWasSaved)
        {
            OnPurchaseItemWithCreditsFinished(0);
        }
        else
        {
            OnPurchaseItemWithCreditsFinished(-1);
        }
    }
    else
    {
        OnPurchaseItemWithCreditsFinished(-1);
    }
}
public final function StartConsumptionFlow(bool bRefreshSave)
{
    ConsumptionFlow_ClearCallbackTimer();
    if (bProcessConsumableCriticalError)
    {
        LogInternal("Critical error in StartConsumptionFlow!", );
        return;
    }
    if (bRefreshSave)
    {
        LogInternal("bRefreshSave", );
        if (ConsumptionFlow_SetCallbackTimer(float(fTimeoutRefreshMPSaves)))
        {
            // MILAN Change - don't refresh data from server as we use local systems now
            ConsumptionFlow_Top(0);
            // END MILAN CHANGE
        }
    }
    else
    {
        LogInternal("Directly going to CF_TOP", );
        ConsumptionFlow_Top(0);
    }
}
public delegate function int StoreItemSort(StoreGUIData Entry_A, StoreGUIData Entry_B)
{
    if (Entry_A.nID > Entry_B.nID)
    {
        return -1;
    }
    else
    {
        return 1;
    }
}
private final function UpdateLastAwardedCards()
{
    local CardInfoData Card;
    
    ManualAwardedCards.Length = 0;
    foreach AwardedCards(Card, )
    {
        LastAwardedCards.AddItem(Card);
        ManualAwardedCards.AddItem(Card);
    }
    AwardedCards.Length = 0;
}
public final function bool UpdateStoreDescriptions()
{
    local int idx;
    local StoreInfoEntry CurrStoreItem;
    local BWOfferId Offer;
    local array<BWOfferId> Offers;
    
    if (!Class'WorldInfo'.static.IsConsoleBuild(2))
    {
        return TRUE;
    }
    if (bFetchingProductDetails)
    {
        return FALSE;
    }
    for (idx = 0; idx < StoreInfoArray.Length; ++idx)
    {
        CurrStoreItem = StoreInfoArray[idx];
        Offer.nID = CurrStoreItem.offerId;
        Offers.AddItem(Offer);
    }
    if (Offers.Length == 0)
    {
        return TRUE;
    }
    bFetchingProductDetails = TRUE;
    Class'SFXOnlineSubsystem'.static.GetOnlineSubsystem().GetComponentCommerce().FetchOfferDetails(Offers, GetProductDetailsComplete);
    return TRUE;
}
private final function AwardPacks(int nID, int nCopies)
{
    local int nConsumableMapIndex;
    local int idx;
    
    AwardedCards.Length = 0;
    nConsumableMapIndex = ConsumableIdPackNameMap.Find('Id', nID);
    if (nConsumableMapIndex >= 0)
    {
        for (idx = 0; idx < nCopies; ++idx)
        {
            GiveCardPack(ConsumableIdPackNameMap[nConsumableMapIndex].PackName, nID);
        }
    }
}
public final function int AwardRandomCardsFromPoolCards(const string PoolName, out array<CardInfoData> ChosenCards, int Quantity, optional bool AllowDupes)
{
    local int idx;
    local array<SFXGAWReinforcementBase> PoolCards;
    local CardInfoData Card;
    local int NumAwardedCards;
    
    PoolCards = GetCardsOfType(PoolName);
    while (NumAwardedCards < Quantity && PoolCards.Length > 0)
    {
        idx = Rand(PoolCards.Length);
        if (AllowDupes && PoolCards[idx].OnAwarded(Card) || PoolCards[idx].OnAwarded(Card, ChosenCards))
        {
            ChosenCards.AddItem(Card);
            ChosenCards[ChosenCards.Length - 1].PoolName = PoolName;
            NumAwardedCards++;
            continue;
        }
        PoolCards.RemoveItem(PoolCards[idx]);
    }
    return NumAwardedCards;
}
public final function bool CanPurchaseItemWithCredits(int ItemId)
{
    local int ItemIndex;
    local int TotalCredits;
    
    ItemIndex = StoreInfoArray.Find('nID', ItemId);
    if (ItemIndex >= 0)
    {
        TotalCredits = SFXEngine(Class'Engine'.static.GetEngine()).MPSaveManager.GetCredits();
        return TotalCredits >= StoreInfoArray[ItemIndex].CreditCost;
    }
    return FALSE;
}
public delegate function int CardSort(SFXGAWReinforcementBase CardA, SFXGAWReinforcementBase CardB)
{
    if (CardA.PoolName > CardB.PoolName)
    {
        return -1;
    }
    else
    {
        return 1;
    }
}
private final function bool CheckOfferVisibility(const out StoreInfoEntry StoreItem, const out array<BWEntitlementInfo> Entitlements)
{
    local int idx;
    local VisibleCondition Condition;
    
    if (StoreItem.visible.Length == 0)
    {
        return TRUE;
    }
    for (idx = 0; idx < StoreItem.visible.Length; ++idx)
    {
        Condition = StoreItem.visible[idx];
        if (EntitlementVisiblityCheck(Condition, Entitlements))
        {
            return TRUE;
        }
    }
    return FALSE;
}
public final function bool ConsumptionFlow_ClearCallbackTimer()
{
    local SFXGRI GRI;
    
    GRI = SFXGRI(Class'WorldInfo'.static.GetWorldInfo().GRI);
    if (GRI == None)
    {
        ConsumptionFlowError("[ConsumptionFlow_ClearCallbackTimer] Failed to find world info", TRUE);
        return FALSE;
    }
    if (!GRI.ClearGenericTimer(ConsumptionFlow_Timer))
    {
        ConsumptionFlowError("[ConsumptionFlow_ClearCallbackTimer] Failed to clear timer", TRUE);
        return FALSE;
    }
    return TRUE;
}
private final function ConsumptionFlow_Finished(int nResult)
{
    Class'SFXOnlineSubsystem'.static.GetOnlineSubsystem().GetComponentCommerce().GetConsumablesList(OutstandingConsumableIDs);
    if (OnProcessConsumablesDelegate != None)
    {
        OnProcessConsumablesDelegate(ConsumptionFlowResult);
    }
    OnProcessConsumablesDelegate = None;
}
private final function ConsumptionFlow_ProcessLocal(BWConsumableId Id, int nCopies, int nResult)
{
    local int NextConsumableToProcess;
    local int NumCopiesToConsume;
    
    ConsumptionFlow_ClearCallbackTimer();
    if (bProcessConsumableCriticalError)
    {
        return;
    }
    Class'SFXOnlineSubsystem'.static.GetOnlineSubsystem().GetComponentCommerce().GetConsumablesList(OutstandingConsumableIDs);
    NextConsumableToProcess = SaveManager.GetNextPackToConsume();
    NumCopiesToConsume = SaveManager.GetNumCopiesToConsume();
    switch (nResult)
    {
        case 0:
            break;
        case -2:
            ConsumptionFlowError("[ConsumptionFlow_ProcessLocal] Failed to find offer ID " $ NextConsumableToProcess, TRUE, TRUE);
            return;
        case -3:
            break;
        default:
            ConsumptionFlowError("[ConsumptionFlow_ProcessLocal] Unknown Error.  nResult=" $ nResult, TRUE, TRUE);
            return;
    }
    if (NextConsumableToProcess == -1)
    {
        ConsumptionFlowError("[ConsumptionFlow_ProcessLocal] Attempting to award pack -1", TRUE);
        return;
    }
    AwardPacks(NextConsumableToProcess, NumCopiesToConsume);
    SaveManager.PackConsumed();
    if (nTestConsumptionError == 2 || nTestConsumptionError == 20)
    {
        if (nTestConsumptionError == 20)
        {
            Class'SFXOnlineSubsystem'.static.GetOnlineSubsystem().GetComponentLogin().Disconnect();
        }
        ConsumptionFlowError("[ConsumptionFlow_ProcessLocal] Killing consumption flow at critical section 2 by user request", TRUE);
        return;
    }
    if (ConsumptionFlow_SetCallbackTimer(float(fTimeoutSaveMPRecord)))
    {
        SaveManager.SaveRecords(FALSE, ConsumptionFlow_SaveComplete);
    }
    GrantPackPurchasedEntitlement();
}
public final function ConsumptionFlow_ProcessRemote()
{
    local int nID;
    local int nCopies;
    
    ConsumptionFlow_ClearCallbackTimer();
    if (bProcessConsumableCriticalError)
    {
        return;
    }
    nID = OutstandingConsumableIDs[0].Id.nID;
    nCopies = OutstandingConsumableIDs[0].nCopies;
    OutstandingConsumableIDs.Remove(0, 1);
    if (SaveManager.SetNextPackToConsume(nID, nCopies) == FALSE)
    {
        ConsumptionFlowError("[ConsumptionFlow_ProcessRemote] Aborting processing of consumables - unable to set the next pack to consume");
        return;
    }
    if (nTestConsumptionError == 3 || nTestConsumptionError == 30)
    {
        if (nTestConsumptionError == 30)
        {
            Class'SFXOnlineSubsystem'.static.GetOnlineSubsystem().GetComponentLogin().Disconnect();
        }
        ConsumptionFlowError("[ConsumptionFlow_ProcessRemote] Killing consumption flow at critical section 3 by user request", TRUE);
        return;
    }
    if (ConsumptionFlow_SetCallbackTimer(float(fTimeoutSaveMPRecord)))
    {
        SaveManager.SaveRecords(FALSE, ConsumptionFlow_SaveComplete);
    }
}
public final function ConsumptionFlow_SaveComplete(int nResult)
{
    ConsumptionFlow_ClearCallbackTimer();
    if (bProcessConsumableCriticalError)
    {
        return;
    }
    if (nResult != 0)
    {
        ConsumptionFlowError("[ConsumptionFlow_SaveComplete] Aborting processing of consumables - failed to save", TRUE);
        return;
    }
    UpdateLastAwardedCards();
    StartConsumptionFlow(FALSE);
}
public final function bool ConsumptionFlow_SetCallbackTimer(float fTime)
{
    local SFXGRI GRI;
    
    GRI = SFXGRI(Class'WorldInfo'.static.GetWorldInfo().GRI);
    if (GRI == None)
    {
        ConsumptionFlowError("[ConsumptionFlow_SetCallbackTimer] Failed to find world info", TRUE);
        return FALSE;
    }
    if (!GRI.SetGenericTimer(fTime, ConsumptionFlow_Timer))
    {
        ConsumptionFlowError("[ConsumptionFlow_SetCallbackTimer] Failed to set timer", TRUE);
        return FALSE;
    }
    return TRUE;
}
public final function ConsumptionFlow_Setup(int nResult)
{
    ConsumptionFlow_ClearCallbackTimer();
    if (bProcessConsumableCriticalError)
    {
        return;
    }
    if (nResult != 0)
    {
        ConsumptionFlowError("[ConsumptionFlow_Setup] RefreshDigitalRights returned with error code " $ nResult, TRUE);
        return;
    }
    Class'SFXOnlineSubsystem'.static.GetOnlineSubsystem().GetComponentCommerce().GetConsumablesList(OutstandingConsumableIDs);
    StartConsumptionFlow(TRUE);
}
public final function ConsumptionFlow_Timer()
{
    bProcessConsumableCriticalError = TRUE;
    ConsumptionFlowError("Consumption flow critical error - aborting", TRUE);
}
public final function ConsumptionFlow_Top(int nResult)
{
    local BWConsumableId Id;
    
    ConsumptionFlow_ClearCallbackTimer();
    if (bProcessConsumableCriticalError)
    {
        return;
    }
    if (nResult != 0)
    {
        ConsumptionFlowError("[ConsumptionFlow_Top] Error refreshing MP save data.  Result = " $ nResult, TRUE);
        return;
    }
    Id.nID = SaveManager.GetNextPackToConsume();
    if (Id.nID != -1)
    {
        if (nTestConsumptionError == 1 || nTestConsumptionError == 10)
        {
            if (nTestConsumptionError == 10)
            {
                Class'SFXOnlineSubsystem'.static.GetOnlineSubsystem().GetComponentLogin().Disconnect();
            }
            ConsumptionFlowError("[ConsumptionFlow_SaveComplete] Killing consumption flow at critical section 1 by user request", TRUE);
            return;
        }
        if (ConsumptionFlow_SetCallbackTimer(float(fTimeoutConsumeID)))
        {
            Class'SFXOnlineSubsystem'.static.GetOnlineSubsystem().GetComponentCommerce().ConsumeId(Id, SaveManager.GetNumCopiesToConsume(), ConsumptionFlow_ProcessLocal);
        }
        return;
    }
    if (OutstandingConsumableIDs.Length <= 0)
    {
        ExitConsumptionFlow();
        return;
    }
    ConsumptionFlow_ProcessRemote();
}
public final function ConsumptionFlowError(string sMsg, optional bool bAbortFlow = FALSE, optional bool bWipeSave = FALSE)
{
    if (bWipeSave)
    {
        SaveManager.PackConsumed();
        SaveManager.SaveRecords();
    }
    if (bAbortFlow)
    {
        ConsumptionFlowResult = -2;
        ExitConsumptionFlow();
    }
    else
    {
        ConsumptionFlowResult = -1;
        StartConsumptionFlow(TRUE);
    }
}
private final function bool EntitlementVisiblityCheck(const out VisibleCondition visible, const out array<BWEntitlementInfo> Entitlements)
{
    local int idx;
    local int Idx2;
    local int IDToCheck;
    local bool bEntitlementFound;
    local bool bNeedsToExist;
    
    for (idx = 0; idx < visible.and.Length; ++idx)
    {
        bEntitlementFound = FALSE;
        if (visible.and[idx] < 0)
        {
            bNeedsToExist = FALSE;
            IDToCheck = visible.and[idx] * -1;
        }
        else
        {
            bNeedsToExist = TRUE;
            IDToCheck = visible.and[idx];
        }
        for (Idx2 = 0; Idx2 < Entitlements.Length; ++Idx2)
        {
            if (IDToCheck == Entitlements[Idx2].Id.nID)
            {
                bEntitlementFound = TRUE;
                break;
            }
        }
        if (bEntitlementFound != bNeedsToExist)
        {
            return FALSE;
        }
    }
    return TRUE;
}
private final function ExitConsumptionFlow()
{
    if (ConsumptionFlowResult < 0)
    {
        if (bRetryProcessConsumables)
        {
            ProcessConsumables(OnProcessConsumablesDelegate, FALSE);
            return;
        }
        else
        {
            SaveManager.RefreshMPDataFromServer(ConsumptionFlow_Finished);
        }
    }
    else
    {
        ConsumptionFlow_Finished(0);
    }
}
private final function int FindOfferIndex(int nOfferID, const out array<BWOfferInfo> Offers)
{
    local int idx;
    
    for (idx = 0; idx < Offers.Length; ++idx)
    {
        if (Offers[idx].Id.nID == nOfferID)
        {
            return idx;
        }
    }
    return -1;
}
private final function FinishPurchase(int nResult)
{
    if (nTestConsumptionError == 4 || nTestConsumptionError == 40)
    {
        if (nTestConsumptionError == 40)
        {
            Class'SFXOnlineSubsystem'.static.GetOnlineSubsystem().GetComponentLogin().Disconnect();
        }
        ConsumptionFlowError("[FinishPurchase] Killing consumption flow at critical section 4 by user request", TRUE);
        return;
    }
    if (OnPurchaseItemDelegate != None)
    {
        OnPurchaseItemDelegate(nResult);
    }
    OnPurchaseItemDelegate = None;
}
public final function array<SFXGAWReinforcementBase> GetCardsOfType(string PoolName)
{
    local array<SFXGAWReinforcementBase> PoolCards;
    local int idx;
    local int Idx2;
    local int DeckCount;
    local int SubCardCount;
    
    DeckCount = Deck.Length;
    for (idx = 0; idx < DeckCount; idx++)
    {
        if (PoolName != Deck[idx].PoolName)
        {
            continue;
        }
        SubCardCount = Deck[idx].CardList.Length;
        for (Idx2 = 0; Idx2 < SubCardCount; Idx2++)
        {
            PoolCards.AddItem(Deck[idx]);
        }
    }
    return PoolCards;
}
public function int GetCreditCost(int ItemId)
{
    local int nItemIndex;
    
    nItemIndex = StoreInfoArray.Find('nID', ItemId);
    if (nItemIndex >= 0)
    {
        return StoreInfoArray[nItemIndex].CreditCost;
    }
    return 0;
}
public function int GetOfferIDFromStoreID(int StoreID)
{
    local int nStoreItemIndex;
    
    nStoreItemIndex = StoreInfoArray.Find('nID', StoreID);
    if (nStoreItemIndex >= 0)
    {
        return StoreInfoArray[nStoreItemIndex].offerId;
    }
    return -1;
}
public function string GetPCPointsBalance()
{
    return Class'SFXOnlineSubsystem'.static.GetOnlineSubsystem().GetComponentCommerce().GetWalletBalance();
}
public function string GetPlatformCost(int ItemId)
{
    local array<BWOfferInfo> Offers;
    local int nItemIndex;
    local int nOfferIndex;
    
    Class'SFXOnlineSubsystem'.static.GetOnlineSubsystem().GetComponentCommerce().GetOffersList(Offers);
    nItemIndex = StoreInfoArray.Find('nID', ItemId);
    if (nItemIndex >= 0)
    {
        if (StoreInfoArray[nItemIndex].offerId != 0)
        {
            nOfferIndex = FindOfferIndex(StoreInfoArray[nItemIndex].offerId, Offers);
            if (nOfferIndex >= 0)
            {
                return Offers[nOfferIndex].sPrice;
            }
        }
    }
    return "";
}
public function int GetPlatformCostValue(int ItemId)
{
    local array<BWOfferInfo> Offers;
    local int nItemIndex;
    local int nOfferIndex;
    
    Class'SFXOnlineSubsystem'.static.GetOnlineSubsystem().GetComponentCommerce().GetOffersList(Offers);
    nItemIndex = StoreInfoArray.Find('nID', ItemId);
    if (nItemIndex >= 0)
    {
        if (StoreInfoArray[nItemIndex].offerId != 0)
        {
            nOfferIndex = FindOfferIndex(StoreInfoArray[nItemIndex].offerId, Offers);
            if (nOfferIndex >= 0)
            {
                return Offers[nOfferIndex].nPrice;
            }
        }
    }
    return 0;
}
public final function array<StoreInfoEntry> GetStoreInfo()
{
    return StoreInfoArray;
}
public function int GetStoreItemIDFromOffer(int offerId)
{
    local int nStoreItemIndex;
    
    nStoreItemIndex = StoreInfoArray.Find('offerId', offerId);
    if (nStoreItemIndex >= 0)
    {
        return StoreInfoArray[nStoreItemIndex].nID;
    }
    return -1;
}
private final function EPurchaseType GetStoreItemPurchaseType(const out StoreInfoEntry StoreItem, optional string FirstPartyPrice = "")
{
    if (FirstPartyPrice != "")
    {
        if (StoreItem.CreditCost > 0)
        {
            return EPurchaseType.EPurchaseType_PlatformAndCredits;
        }
        else
        {
            return EPurchaseType.EPurchaseType_PlatformOnly;
        }
    }
    else if (StoreItem.CreditCost > 0)
    {
        return EPurchaseType.EPurchaseType_CreditsOnly;
    }
    else if (StoreItem.CreditCost == 0)
    {
        return EPurchaseType.EPurchaseType_Free;
    }
    return EPurchaseType.EPurchaseType_Unknown;
}
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
    // MILAN CHANGE
    RefreshMilanAchievementPacks(); 
    // END MILAN CHANGE
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
        // MILAN CHANGE
        // Achievement packs stay hidden until earned
        if (!IsMilanAchievementPackUnlocked(CurrStoreItem.PackName))
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
    // END MILAN CHANGE
    return StoreData;
}
public final function SFXGAWReinforcementMatchConsumable GetUniqueMatchConsumables()
{
    local int idx;
    local int Idx2;
    local SFXGAWReinforcementMatchConsumable SuperCard;
    local bool bAlreadyInList;
    local int CardID;
    local int CardVersion;
    local CardInfoData CardInfo;
    
    SuperCard = new (Self) Class'SFXGAWReinforcementMatchConsumable';
    for (idx = 0; idx < MatchConsumables.Length; idx++)
    {
        if (MatchConsumables[idx].CardList.Length > 0 && MatchConsumables[idx].CardList[0].UniqueId == 0)
        {
            MatchConsumables[idx].Initialize();
        }
        for (Idx2 = 0; Idx2 < MatchConsumables[idx].CardList.Length; Idx2++)
        {
            CardID = MatchConsumables[idx].GetCardUniqueID(Idx2);
            CardVersion = MatchConsumables[idx].CardList[Idx2].VersionIdx;
            if (CardID == 0)
            {
                continue;
            }
            bAlreadyInList = SuperCard.ContainsCard(CardID, float(CardVersion));
            if (!bAlreadyInList)
            {
                CardInfo = MatchConsumables[idx].CardList[Idx2];
                PopulateCardData(CardInfo);
                CardInfo.CardOwner = MatchConsumables[idx];
                SuperCard.CardList.AddItem(CardInfo);
                SuperCard.GenerateCardUniqueID(SuperCard.CardList.Length - 1);
            }
        }
    }
    // MILAN Change - game crashes if you attempt to sort a list without at least 2 items
    if (SuperCard.CardList.Length > 1)
    {
        SuperCard.CardList.Sort(MatchConsumableSort);
    }
    // END MILAN CHANGE
    return SuperCard;
}
public final function array<CardInfoData> GiveCardPack(string PackName, optional int nConsumableId = -1)
{
    local int idx;
    local int Idx2;
    local int Idx3;
    local int ExpectedCardCount;
    local int PackCount;
    local array<CardInfoData> CardPack;
    local bool bFoundPack;
    local SFXEngine Engine;
    local SFXSaveManagerMP MPSaveManager;
    local BioWorldInfo WI;
    local bool InLobby;
    local int PacksBought;
    local int StoreInfoIdx;
    local float TotalWeight;
    local float RandWeight;
    
    Engine = Class'SFXEngine'.static.GetSFXEngine();
    WI = BioWorldInfo(Class'WorldInfo'.static.GetWorldInfo());
    InLobby = WI.GRI.GetStateName() != 'MultiplayerMenu';
    MPSaveManager = SFXEngine(Class'Engine'.static.GetEngine()).MPSaveManager;
    StoreInfoIdx = StoreInfoArray.Find('PackName', PackName);
    if (StoreInfoIdx >= 0)
    {
        if (StoreInfoArray[StoreInfoIdx].PerPlayerMax > 0)
        {
            PacksBought = Engine.GetPlayerVariable(Name(PackName));
            Engine.SetPlayerVariable(Name(PackName), PacksBought + 1);
        }
    }
    PackCount = PackList.Length;
    for (idx = 0; idx < PackCount; idx++)
    {
        if (PackList[idx].PackName == PackName)
        {
            ExpectedCardCount += PackList[idx].Quantity;
            bFoundPack = TRUE;
            TotalWeight = 0.0;
            for (Idx3 = 0; Idx3 < PackList[idx].Pools.Length; Idx3++)
            {
                TotalWeight += PackList[idx].Pools[Idx3].Weight;
            }
            for (Idx2 = 0; Idx2 < PackList[idx].Quantity; Idx2++)
            {
                RandWeight = RandRange(0.0, TotalWeight);
                for (Idx3 = 0; Idx3 < PackList[idx].Pools.Length; Idx3++)
                {
                    if (RandWeight <= PackList[idx].Pools[Idx3].Weight)
                    {
                        if (AwardRandomCardsFromPoolCards(PackList[idx].Pools[Idx3].PoolName, CardPack, 1) != 1)
                        {
                            if (AwardRandomCardsFromPoolCards(PackList[idx].Pools[Idx3].PoolName, CardPack, 1, TRUE) != 1)
                            {
                                AwardRandomCardsFromPoolCards(PackList[idx].BackupPool, CardPack, 1, TRUE);
                            }
                        }
                        break;
                    }
                    RandWeight -= PackList[idx].Pools[Idx3].Weight;
                }
            }
        }
    }
    if (!bFoundPack)
    {
    }
    else if (ExpectedCardCount > CardPack.Length)
    {
    }
    for (idx = 0; idx < CardPack.Length; ++idx)
    {
        AwardedCards.AddItem(CardPack[idx]);
    }
    LastAwardedPackName = PackName;
    ManualAwardedPackName = PackName;
    Class'SFXTelemetryHooksMP'.static.SendReinforcementPackPurchase(Self, StoreInfoIdx, nConsumableId, MPSaveManager, InLobby);
    return CardPack;
}
public function GrantPackPurchasedEntitlement()
{
    local bool bOwnEntitlement;
    local array<BWEntitlementInfo> aEntitlements;
    local BWEntitlementInfo eEntitlement;
    
    if (PackPurchasedEntitlement.nID > 0)
    {
        bOwnEntitlement = FALSE;
        if (Class'SFXOnlineSubsystem'.static.GetOnlineSubsystem().GetComponentCommerce().GetEntitlementsList(aEntitlements))
        {
            foreach aEntitlements(eEntitlement, )
            {
                if (eEntitlement.Id.nID == PackPurchasedEntitlement.nID)
                {
                    bOwnEntitlement = TRUE;
                    break;
                }
            }
        }
        if (!bOwnEntitlement)
        {
            Class'SFXOnlineSubsystem'.static.GetOnlineSubsystem().GetComponentCommerce().GrantEntitlementId(PackPurchasedEntitlement);
        }
    }
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    CardData = ({
                 UniqueName = "SFXGameMPContent.SFXPowerCustomActionMP_Consumable_Ammo", 
                 GUIType = "consumable", 
                 GUITextureRef = "GUI_MPImages.Cards.EquipAmmo", 
                 PoolName = "", 
                 UniqueId = 0, 
                 MaxCount = 0, 
                 GUIName = $661162, 
                 GUIDescription = $661163, 
                 GUIIconIndex = 0, 
                 PVIncrementBonus = 0, 
                 VersionIdx = 0, 
                 Category = 0, 
                 LevelAwarded = 0, 
                 StringToken = 0, 
                 CardOwner = None, 
                 Entitlement = -1, 
                 bUseVersionIdx = FALSE, 
                 Rarity = ECardRarity.Rarity_Common, 
                 GUICategory = EReinforcementGUICategory.EReinforcementGUICategory_None
                }, 
                {
                 UniqueName = "SFXGameMPContent.SFXPowerCustomActionMP_Consumable_Revive", 
                 GUIType = "consumable", 
                 GUITextureRef = "GUI_MPImages.Cards.EquipRevive", 
                 PoolName = "", 
                 UniqueId = 0, 
                 MaxCount = 0, 
                 GUIName = $661168, 
                 GUIDescription = $661169, 
                 GUIIconIndex = 0, 
                 PVIncrementBonus = 0, 
                 VersionIdx = 0, 
                 Category = 0, 
                 LevelAwarded = 0, 
                 StringToken = 0, 
                 CardOwner = None, 
                 Entitlement = -1, 
                 bUseVersionIdx = FALSE, 
                 Rarity = ECardRarity.Rarity_Common, 
                 GUICategory = EReinforcementGUICategory.EReinforcementGUICategory_None
                }, 
                {
                 UniqueName = "SFXGameMPContent.SFXPowerCustomActionMP_Consumable_Rocket", 
                 GUIType = "consumable", 
                 GUITextureRef = "GUI_MPImages.Cards.EquipRocket", 
                 PoolName = "", 
                 UniqueId = 0, 
                 MaxCount = 0, 
                 GUIName = $661166, 
                 GUIDescription = $661167, 
                 GUIIconIndex = 0, 
                 PVIncrementBonus = 0, 
                 VersionIdx = 0, 
                 Category = 0, 
                 LevelAwarded = 0, 
                 StringToken = 0, 
                 CardOwner = None, 
                 Entitlement = -1, 
                 bUseVersionIdx = FALSE, 
                 Rarity = ECardRarity.Rarity_Common, 
                 GUICategory = EReinforcementGUICategory.EReinforcementGUICategory_None
                }, 
                {
                 UniqueName = "SFXGameMPContent.SFXPowerCustomActionMP_Consumable_Shield", 
                 GUIType = "consumable", 
                 GUITextureRef = "GUI_MPImages.Cards.EquipShield", 
                 PoolName = "", 
                 UniqueId = 0, 
                 MaxCount = 0, 
                 GUIName = $661164, 
                 GUIDescription = $661165, 
                 GUIIconIndex = 0, 
                 PVIncrementBonus = 0, 
                 VersionIdx = 0, 
                 Category = 0, 
                 LevelAwarded = 0, 
                 StringToken = 0, 
                 CardOwner = None, 
                 Entitlement = -1, 
                 bUseVersionIdx = FALSE, 
                 Rarity = ECardRarity.Rarity_Common, 
                 GUICategory = EReinforcementGUICategory.EReinforcementGUICategory_None
                }, 
                {
                 UniqueName = "SFXGameMPContent.SFXGameEffect_MatchConsumable_AmmoPower_Incendiary", 
                 GUIType = "ammoUpgrade", 
                 GUITextureRef = "GUI_MPImages.Cards.AmmoIncendiary", 
                 PoolName = "", 
                 UniqueId = 0, 
                 MaxCount = 0, 
                 GUIName = $711347, 
                 GUIDescription = $676662, 
                 GUIIconIndex = 0, 
                 PVIncrementBonus = 0, 
                 VersionIdx = 0, 
                 Category = 1, 
                 LevelAwarded = 0, 
                 StringToken = 0, 
                 CardOwner = None, 
                 Entitlement = -1, 
                 bUseVersionIdx = TRUE, 
                 Rarity = ECardRarity.Rarity_Common, 
                 GUICategory = EReinforcementGUICategory.EReinforcementGUICategory_MatchConsumableAmmo
                }, 
                {
                 UniqueName = "SFXGameMPContent.SFXGameEffect_MatchConsumable_AmmoPower_Disruptor", 
                 GUIType = "ammoUpgrade", 
                 GUITextureRef = "GUI_MPImages.Cards.AmmoDisrupt", 
                 PoolName = "", 
                 UniqueId = 0, 
                 MaxCount = 0, 
                 GUIName = $711348, 
                 GUIDescription = $676663, 
                 GUIIconIndex = 0, 
                 PVIncrementBonus = 0, 
                 VersionIdx = 0, 
                 Category = 1, 
                 LevelAwarded = 0, 
                 StringToken = 0, 
                 CardOwner = None, 
                 Entitlement = -1, 
                 bUseVersionIdx = TRUE, 
                 Rarity = ECardRarity.Rarity_Common, 
                 GUICategory = EReinforcementGUICategory.EReinforcementGUICategory_MatchConsumableAmmo
                }, 
                {
                 UniqueName = "SFXGameMPContent.SFXGameEffect_MatchConsumable_AmmoPower_ArmorPiercing", 
                 GUIType = "ammoUpgrade", 
                 GUITextureRef = "GUI_MPImages.Cards.AmmoPiercing", 
                 PoolName = "", 
                 UniqueId = 0, 
                 MaxCount = 0, 
                 GUIName = $711349, 
                 GUIDescription = $676664, 
                 GUIIconIndex = 0, 
                 PVIncrementBonus = 0, 
                 VersionIdx = 0, 
                 Category = 1, 
                 LevelAwarded = 0, 
                 StringToken = 0, 
                 CardOwner = None, 
                 Entitlement = -1, 
                 bUseVersionIdx = TRUE, 
                 Rarity = ECardRarity.Rarity_Common, 
                 GUICategory = EReinforcementGUICategory.EReinforcementGUICategory_MatchConsumableAmmo
                }, 
                {
                 UniqueName = "SFXGameMPContent.SFXGameEffect_MatchConsumable_AmmoPower_Warp", 
                 GUIType = "ammoUpgrade", 
                 GUITextureRef = "GUI_MPImages.Cards.AmmoWarp", 
                 PoolName = "", 
                 UniqueId = 0, 
                 MaxCount = 0, 
                 GUIName = $711350, 
                 GUIDescription = $676665, 
                 GUIIconIndex = 0, 
                 PVIncrementBonus = 0, 
                 VersionIdx = 0, 
                 Category = 1, 
                 LevelAwarded = 0, 
                 StringToken = 0, 
                 CardOwner = None, 
                 Entitlement = -1, 
                 bUseVersionIdx = TRUE, 
                 Rarity = ECardRarity.Rarity_Common, 
                 GUICategory = EReinforcementGUICategory.EReinforcementGUICategory_MatchConsumableAmmo
                }, 
                {
                 UniqueName = "SFXGameMPContent.SFXGameEffect_MatchConsumable_AmmoPower_Cryo", 
                 GUIType = "ammoUpgrade", 
                 GUITextureRef = "GUI_MPImages.Cards.AmmoCryo", 
                 PoolName = "", 
                 UniqueId = 0, 
                 MaxCount = 0, 
                 GUIName = $711351, 
                 GUIDescription = $676666, 
                 GUIIconIndex = 0, 
                 PVIncrementBonus = 0, 
                 VersionIdx = 0, 
                 Category = 1, 
                 LevelAwarded = 0, 
                 StringToken = 0, 
                 CardOwner = None, 
                 Entitlement = -1, 
                 bUseVersionIdx = TRUE, 
                 Rarity = ECardRarity.Rarity_Common, 
                 GUICategory = EReinforcementGUICategory.EReinforcementGUICategory_MatchConsumableAmmo
                }, 
                {
                 UniqueName = "SFXGameMPContent.SFXGameEffect_MatchConsumable_PowerBonus", 
                 GUIType = "armorUpgrade", 
                 GUITextureRef = "GUI_MPImages.Cards.BoostTime", 
                 PoolName = "", 
                 UniqueId = 0, 
                 MaxCount = 0, 
                 GUIName = $711352, 
                 GUIDescription = $676667, 
                 GUIIconIndex = 0, 
                 PVIncrementBonus = 0, 
                 VersionIdx = 0, 
                 Category = 2, 
                 LevelAwarded = 0, 
                 StringToken = 0, 
                 CardOwner = None, 
                 Entitlement = -1, 
                 bUseVersionIdx = TRUE, 
                 Rarity = ECardRarity.Rarity_Common, 
                 GUICategory = EReinforcementGUICategory.EReinforcementGUICategory_MatchConsumableArmor
                }, 
                {
                 UniqueName = "SFXGameMPContent.SFXGameEffect_MatchConsumable_PowerBonusDamage", 
                 GUIType = "armorUpgrade", 
                 GUITextureRef = "GUI_MPImages.Cards.BoostPower", 
                 PoolName = "", 
                 UniqueId = 0, 
                 MaxCount = 0, 
                 GUIName = $711353, 
                 GUIDescription = $676668, 
                 GUIIconIndex = 0, 
                 PVIncrementBonus = 0, 
                 VersionIdx = 0, 
                 Category = 2, 
                 LevelAwarded = 0, 
                 StringToken = 0, 
                 CardOwner = None, 
                 Entitlement = -1, 
                 bUseVersionIdx = TRUE, 
                 Rarity = ECardRarity.Rarity_Common, 
                 GUICategory = EReinforcementGUICategory.EReinforcementGUICategory_MatchConsumableArmor
                }, 
                {
                 UniqueName = "SFXGameMPContent.SFXGameEffect_MatchConsumable_WeaponDamageBonus_AssaultRifle", 
                 GUIType = "weaponUpgrade", 
                 GUITextureRef = "GUI_MPImages.Cards.DamageAssault", 
                 PoolName = "", 
                 UniqueId = 0, 
                 MaxCount = 0, 
                 GUIName = $711354, 
                 GUIDescription = $676669, 
                 GUIIconIndex = 0, 
                 PVIncrementBonus = 0, 
                 VersionIdx = 0, 
                 Category = 3, 
                 LevelAwarded = 0, 
                 StringToken = 0, 
                 CardOwner = None, 
                 Entitlement = -1, 
                 bUseVersionIdx = TRUE, 
                 Rarity = ECardRarity.Rarity_Common, 
                 GUICategory = EReinforcementGUICategory.EReinforcementGUICategory_MatchConsumableWeapon
                }, 
                {
                 UniqueName = "SFXGameMPContent.SFXGameEffect_MatchConsumable_WeaponDamageBonus_SniperRifle", 
                 GUIType = "weaponUpgrade", 
                 GUITextureRef = "GUI_MPImages.Cards.DamageSniper", 
                 PoolName = "", 
                 UniqueId = 0, 
                 MaxCount = 0, 
                 GUIName = $711355, 
                 GUIDescription = $676670, 
                 GUIIconIndex = 0, 
                 PVIncrementBonus = 0, 
                 VersionIdx = 0, 
                 Category = 3, 
                 LevelAwarded = 0, 
                 StringToken = 0, 
                 CardOwner = None, 
                 Entitlement = -1, 
                 bUseVersionIdx = TRUE, 
                 Rarity = ECardRarity.Rarity_Common, 
                 GUICategory = EReinforcementGUICategory.EReinforcementGUICategory_MatchConsumableWeapon
                }, 
                {
                 UniqueName = "SFXGameMPContent.SFXGameEffect_MatchConsumable_WeaponDamageBonus_Shotgun", 
                 GUIType = "weaponUpgrade", 
                 GUITextureRef = "GUI_MPImages.Cards.DamageShotgun", 
                 PoolName = "", 
                 UniqueId = 0, 
                 MaxCount = 0, 
                 GUIName = $711356, 
                 GUIDescription = $676671, 
                 GUIIconIndex = 0, 
                 PVIncrementBonus = 0, 
                 VersionIdx = 0, 
                 Category = 3, 
                 LevelAwarded = 0, 
                 StringToken = 0, 
                 CardOwner = None, 
                 Entitlement = -1, 
                 bUseVersionIdx = TRUE, 
                 Rarity = ECardRarity.Rarity_Common, 
                 GUICategory = EReinforcementGUICategory.EReinforcementGUICategory_MatchConsumableWeapon
                }, 
                {
                 UniqueName = "SFXGameMPContent.SFXGameEffect_MatchConsumable_WeaponDamageBonus_Pistol", 
                 GUIType = "weaponUpgrade", 
                 GUITextureRef = "GUI_MPImages.Cards.DamagePistol", 
                 PoolName = "", 
                 UniqueId = 0, 
                 MaxCount = 0, 
                 GUIName = $711357, 
                 GUIDescription = $676672, 
                 GUIIconIndex = 0, 
                 PVIncrementBonus = 0, 
                 VersionIdx = 0, 
                 Category = 3, 
                 LevelAwarded = 0, 
                 StringToken = 0, 
                 CardOwner = None, 
                 Entitlement = -1, 
                 bUseVersionIdx = TRUE, 
                 Rarity = ECardRarity.Rarity_Common, 
                 GUICategory = EReinforcementGUICategory.EReinforcementGUICategory_MatchConsumableWeapon
                }, 
                {
                 UniqueName = "SFXGameMPContent.SFXGameEffect_MatchConsumable_WeaponDamageBonus_SMG", 
                 GUIType = "weaponUpgrade", 
                 GUITextureRef = "GUI_MPImages.Cards.DamageSMG", 
                 PoolName = "", 
                 UniqueId = 0, 
                 MaxCount = 0, 
                 GUIName = $711358, 
                 GUIDescription = $676673, 
                 GUIIconIndex = 0, 
                 PVIncrementBonus = 0, 
                 VersionIdx = 0, 
                 Category = 3, 
                 LevelAwarded = 0, 
                 StringToken = 0, 
                 CardOwner = None, 
                 Entitlement = -1, 
                 bUseVersionIdx = TRUE, 
                 Rarity = ECardRarity.Rarity_Common, 
                 GUICategory = EReinforcementGUICategory.EReinforcementGUICategory_MatchConsumableWeapon
                }, 
                {
                 UniqueName = "SFXGameMPContent.SFXGameEffect_MatchConsumable_SpeedBonus", 
                 GUIType = "armorUpgrade", 
                 GUITextureRef = "GUI_MPImages.Cards.BoostSpeed", 
                 PoolName = "", 
                 UniqueId = 0, 
                 MaxCount = 0, 
                 GUIName = $711359, 
                 GUIDescription = $676674, 
                 GUIIconIndex = 0, 
                 PVIncrementBonus = 0, 
                 VersionIdx = 0, 
                 Category = 2, 
                 LevelAwarded = 0, 
                 StringToken = 0, 
                 CardOwner = None, 
                 Entitlement = -1, 
                 bUseVersionIdx = TRUE, 
                 Rarity = ECardRarity.Rarity_Common, 
                 GUICategory = EReinforcementGUICategory.EReinforcementGUICategory_MatchConsumableArmor
                }, 
                {
                 UniqueName = "SFXGameMPContent.SFXGameEffect_MatchConsumable_ShieldBonus", 
                 GUIType = "armorUpgrade", 
                 GUITextureRef = "GUI_MPImages.Cards.BoostShields", 
                 PoolName = "", 
                 UniqueId = 0, 
                 MaxCount = 0, 
                 GUIName = $711360, 
                 GUIDescription = $676675, 
                 GUIIconIndex = 0, 
                 PVIncrementBonus = 0, 
                 VersionIdx = 0, 
                 Category = 2, 
                 LevelAwarded = 0, 
                 StringToken = 0, 
                 CardOwner = None, 
                 Entitlement = -1, 
                 bUseVersionIdx = TRUE, 
                 Rarity = ECardRarity.Rarity_Common, 
                 GUICategory = EReinforcementGUICategory.EReinforcementGUICategory_MatchConsumableArmor
                }, 
                {
                 UniqueName = "SFXGameContent.SFXWeapon_AssaultRifle_Avenger", 
                 GUIType = "assault", 
                 GUITextureRef = "GUI_Icons.Weapons.asl_avenger_256x128", 
                 PoolName = "", 
                 UniqueId = 0, 
                 MaxCount = 10, 
                 GUIName = $589047, 
                 GUIDescription = $339266, 
                 GUIIconIndex = 0, 
                 PVIncrementBonus = 0, 
                 VersionIdx = 0, 
                 Category = 0, 
                 LevelAwarded = 0, 
                 StringToken = 0, 
                 CardOwner = None, 
                 Entitlement = -1, 
                 bUseVersionIdx = FALSE, 
                 Rarity = ECardRarity.Rarity_Common, 
                 GUICategory = EReinforcementGUICategory.EReinforcementGUICategory_AssaultRifle
                }, 
                {
                 UniqueName = "SFXGameContent.SFXWeapon_SniperRifle_Mantis", 
                 GUIType = "sniper", 
                 GUITextureRef = "GUI_Icons.Weapons.snp_mantis_256x128", 
                 PoolName = "", 
                 UniqueId = 0, 
                 MaxCount = 10, 
                 GUIName = $209737, 
                 GUIDescription = $339320, 
                 GUIIconIndex = 0, 
                 PVIncrementBonus = 0, 
                 VersionIdx = 0, 
                 Category = 0, 
                 LevelAwarded = 0, 
                 StringToken = 0, 
                 CardOwner = None, 
                 Entitlement = -1, 
                 bUseVersionIdx = FALSE, 
                 Rarity = ECardRarity.Rarity_Common, 
                 GUICategory = EReinforcementGUICategory.EReinforcementGUICategory_SniperRifle
                }, 
                {
                 UniqueName = "SFXGameContent.SFXWeapon_Pistol_Predator", 
                 GUIType = "pistol", 
                 GUITextureRef = "GUI_Icons.Weapons.pst_predator_256x128", 
                 PoolName = "", 
                 UniqueId = 0, 
                 MaxCount = 10, 
                 GUIName = $209732, 
                 GUIDescription = $339301, 
                 GUIIconIndex = 0, 
                 PVIncrementBonus = 0, 
                 VersionIdx = 0, 
                 Category = 0, 
                 LevelAwarded = 0, 
                 StringToken = 0, 
                 CardOwner = None, 
                 Entitlement = -1, 
                 bUseVersionIdx = FALSE, 
                 Rarity = ECardRarity.Rarity_Common, 
                 GUICategory = EReinforcementGUICategory.EReinforcementGUICategory_Pistol
                }, 
                {
                 UniqueName = "SFXGameContent.SFXWeapon_SMG_Shuriken", 
                 GUIType = "smg", 
                 GUITextureRef = "GUI_Icons.Weapons.smg_shuriken_256x128", 
                 PoolName = "", 
                 UniqueId = 0, 
                 MaxCount = 10, 
                 GUIName = $209730, 
                 GUIDescription = $339296, 
                 GUIIconIndex = 0, 
                 PVIncrementBonus = 0, 
                 VersionIdx = 0, 
                 Category = 0, 
                 LevelAwarded = 0, 
                 StringToken = 0, 
                 CardOwner = None, 
                 Entitlement = -1, 
                 bUseVersionIdx = FALSE, 
                 Rarity = ECardRarity.Rarity_Common, 
                 GUICategory = EReinforcementGUICategory.EReinforcementGUICategory_SMG
                }, 
                {
                 UniqueName = "SFXGameContent.SFXWeapon_Shotgun_Katana", 
                 GUIType = "shotgun", 
                 GUITextureRef = "GUI_Icons.Weapons.bls_katana_256x128", 
                 PoolName = "", 
                 UniqueId = 0, 
                 MaxCount = 10, 
                 GUIName = $209734, 
                 GUIDescription = $339313, 
                 GUIIconIndex = 0, 
                 PVIncrementBonus = 0, 
                 VersionIdx = 0, 
                 Category = 0, 
                 LevelAwarded = 0, 
                 StringToken = 0, 
                 CardOwner = None, 
                 Entitlement = -1, 
                 bUseVersionIdx = FALSE, 
                 Rarity = ECardRarity.Rarity_Common, 
                 GUICategory = EReinforcementGUICategory.EReinforcementGUICategory_Shotgun
                }, 
                {
                 UniqueName = "SFXGameContent.SFXWeapon_AssaultRifle_Cobra", 
                 GUIType = "assault", 
                 GUITextureRef = "GUI_Icons.Weapons.asl_cobra_256x128", 
                 PoolName = "", 
                 UniqueId = 0, 
                 MaxCount = 10, 
                 GUIName = $634278, 
                 GUIDescription = $634280, 
                 GUIIconIndex = 0, 
                 PVIncrementBonus = 0, 
                 VersionIdx = 0, 
                 Category = 0, 
                 LevelAwarded = 0, 
                 StringToken = 0, 
                 CardOwner = None, 
                 Entitlement = -1, 
                 bUseVersionIdx = FALSE, 
                 Rarity = ECardRarity.Rarity_Uncommon, 
                 GUICategory = EReinforcementGUICategory.EReinforcementGUICategory_AssaultRifle
                }, 
                {
                 UniqueName = "SFXGameContent.SFXWeapon_AssaultRifle_Vindicator", 
                 GUIType = "assault", 
                 GUITextureRef = "GUI_Icons.Weapons.asl_vindicator_256x128", 
                 PoolName = "", 
                 UniqueId = 0, 
                 MaxCount = 10, 
                 GUIName = $621121, 
                 GUIDescription = $621123, 
                 GUIIconIndex = 0, 
                 PVIncrementBonus = 0, 
                 VersionIdx = 0, 
                 Category = 0, 
                 LevelAwarded = 0, 
                 StringToken = 0, 
                 CardOwner = None, 
                 Entitlement = -1, 
                 bUseVersionIdx = FALSE, 
                 Rarity = ECardRarity.Rarity_Uncommon, 
                 GUICategory = EReinforcementGUICategory.EReinforcementGUICategory_AssaultRifle
                }, 
                {
                 UniqueName = "SFXGameContent.SFXWeapon_Shotgun_Scimitar", 
                 GUIType = "shotgun", 
                 GUITextureRef = "GUI_Icons.Weapons.bls_scimitar_256x128", 
                 PoolName = "", 
                 UniqueId = 0, 
                 MaxCount = 10, 
                 GUIName = $209735, 
                 GUIDescription = $339316, 
                 GUIIconIndex = 0, 
                 PVIncrementBonus = 0, 
                 VersionIdx = 0, 
                 Category = 0, 
                 LevelAwarded = 0, 
                 StringToken = 0, 
                 CardOwner = None, 
                 Entitlement = -1, 
                 bUseVersionIdx = FALSE, 
                 Rarity = ECardRarity.Rarity_Uncommon, 
                 GUICategory = EReinforcementGUICategory.EReinforcementGUICategory_Shotgun
                }, 
                {
                 UniqueName = "SFXGameContent.SFXWeapon_SniperRifle_Viper", 
                 GUIType = "sniper", 
                 GUITextureRef = "GUI_Icons.Weapons.snp_viper_256x128", 
                 PoolName = "", 
                 UniqueId = 0, 
                 MaxCount = 10, 
                 GUIName = $209738, 
                 GUIDescription = $339322, 
                 GUIIconIndex = 0, 
                 PVIncrementBonus = 0, 
                 VersionIdx = 0, 
                 Category = 0, 
                 LevelAwarded = 0, 
                 StringToken = 0, 
                 CardOwner = None, 
                 Entitlement = -1, 
                 bUseVersionIdx = FALSE, 
                 Rarity = ECardRarity.Rarity_Uncommon, 
                 GUICategory = EReinforcementGUICategory.EReinforcementGUICategory_SniperRifle
                }, 
                {
                 UniqueName = "SFXGameContent.SFXWeapon_SniperRifle_Raptor", 
                 GUIType = "sniper", 
                 GUITextureRef = "GUI_Icons.Weapons.snp_raptor_256x128", 
                 PoolName = "", 
                 UniqueId = 0, 
                 MaxCount = 10, 
                 GUIName = $551044, 
                 GUIDescription = $551046, 
                 GUIIconIndex = 0, 
                 PVIncrementBonus = 0, 
                 VersionIdx = 0, 
                 Category = 0, 
                 LevelAwarded = 0, 
                 StringToken = 0, 
                 CardOwner = None, 
                 Entitlement = -1, 
                 bUseVersionIdx = FALSE, 
                 Rarity = ECardRarity.Rarity_Uncommon, 
                 GUICategory = EReinforcementGUICategory.EReinforcementGUICategory_SniperRifle
                }, 
                {
                 UniqueName = "SFXGameContent.SFXWeapon_Pistol_Phalanx", 
                 GUIType = "pistol", 
                 GUITextureRef = "GUI_Icons.Weapons.pst_phalanx_256x128", 
                 PoolName = "", 
                 UniqueId = 0, 
                 MaxCount = 10, 
                 GUIName = $546166, 
                 GUIDescription = $652049, 
                 GUIIconIndex = 0, 
                 PVIncrementBonus = 0, 
                 VersionIdx = 0, 
                 Category = 0, 
                 LevelAwarded = 0, 
                 StringToken = 0, 
                 CardOwner = None, 
                 Entitlement = -1, 
                 bUseVersionIdx = FALSE, 
                 Rarity = ECardRarity.Rarity_Uncommon, 
                 GUICategory = EReinforcementGUICategory.EReinforcementGUICategory_Pistol
                }, 
                {
                 UniqueName = "SFXGameContent.SFXWeapon_AssaultRifle_Mattock", 
                 GUIType = "assault", 
                 GUITextureRef = "GUI_Icons.Weapons.asl_mattock_256x128", 
                 PoolName = "", 
                 UniqueId = 0, 
                 MaxCount = 10, 
                 GUIName = $545842, 
                 GUIDescription = $619710, 
                 GUIIconIndex = 0, 
                 PVIncrementBonus = 0, 
                 VersionIdx = 0, 
                 Category = 0, 
                 LevelAwarded = 0, 
                 StringToken = 0, 
                 CardOwner = None, 
                 Entitlement = -1, 
                 bUseVersionIdx = FALSE, 
                 Rarity = ECardRarity.Rarity_Uncommon, 
                 GUICategory = EReinforcementGUICategory.EReinforcementGUICategory_AssaultRifle
                }, 
                {
                 UniqueName = "SFXGameContent.SFXWeapon_SMG_Tempest", 
                 GUIType = "smg", 
                 GUITextureRef = "GUI_Icons.Weapons.smg_tempest_256x128", 
                 PoolName = "", 
                 UniqueId = 0, 
                 MaxCount = 10, 
                 GUIName = $209731, 
                 GUIDescription = $339299, 
                 GUIIconIndex = 0, 
                 PVIncrementBonus = 0, 
                 VersionIdx = 0, 
                 Category = 0, 
                 LevelAwarded = 0, 
                 StringToken = 0, 
                 CardOwner = None, 
                 Entitlement = -1, 
                 bUseVersionIdx = FALSE, 
                 Rarity = ECardRarity.Rarity_Uncommon, 
                 GUICategory = EReinforcementGUICategory.EReinforcementGUICategory_SMG
                }, 
                {
                 UniqueName = "SFXGameContent.SFXWeapon_SMG_Locust", 
                 GUIType = "smg", 
                 GUITextureRef = "GUI_Icons.Weapons.smg_locust_256x128", 
                 PoolName = "", 
                 UniqueId = 0, 
                 MaxCount = 10, 
                 GUIName = $546170, 
                 GUIDescription = $619711, 
                 GUIIconIndex = 0, 
                 PVIncrementBonus = 0, 
                 VersionIdx = 0, 
                 Category = 0, 
                 LevelAwarded = 0, 
                 StringToken = 0, 
                 CardOwner = None, 
                 Entitlement = -1, 
                 bUseVersionIdx = FALSE, 
                 Rarity = ECardRarity.Rarity_Uncommon, 
                 GUICategory = EReinforcementGUICategory.EReinforcementGUICategory_SMG
                }, 
                {
                 UniqueName = "SFXGameContent.SFXWeapon_Shotgun_Eviscerator", 
                 GUIType = "shotgun", 
                 GUITextureRef = "GUI_Icons.Weapons.bls_eviscerator_256x128", 
                 PoolName = "", 
                 UniqueId = 0, 
                 MaxCount = 10, 
                 GUIName = $314330, 
                 GUIDescription = $352863, 
                 GUIIconIndex = 0, 
                 PVIncrementBonus = 0, 
                 VersionIdx = 0, 
                 Category = 0, 
                 LevelAwarded = 0, 
                 StringToken = 0, 
                 CardOwner = None, 
                 Entitlement = -1, 
                 bUseVersionIdx = FALSE, 
                 Rarity = ECardRarity.Rarity_Uncommon, 
                 GUICategory = EReinforcementGUICategory.EReinforcementGUICategory_Shotgun
                }, 
                {
                 UniqueName = "SFXGameContent.SFXWeapon_SniperRifle_Incisor", 
                 GUIType = "sniper", 
                 GUITextureRef = "GUI_Icons.Weapons.snp_incisor_256x128", 
                 PoolName = "", 
                 UniqueId = 0, 
                 MaxCount = 10, 
                 GUIName = $546171, 
                 GUIDescription = $351820, 
                 GUIIconIndex = 0, 
                 PVIncrementBonus = 0, 
                 VersionIdx = 0, 
                 Category = 0, 
                 LevelAwarded = 0, 
                 StringToken = 0, 
                 CardOwner = None, 
                 Entitlement = -1, 
                 bUseVersionIdx = FALSE, 
                 Rarity = ECardRarity.Rarity_Uncommon, 
                 GUICategory = EReinforcementGUICategory.EReinforcementGUICategory_SniperRifle
                }, 
                {
                 UniqueName = "SFXGameContent.SFXWeapon_AssaultRifle_Falcon", 
                 GUIType = "assault", 
                 GUITextureRef = "GUI_Icons.Weapons.asl_falcon_256x128", 
                 PoolName = "", 
                 UniqueId = 0, 
                 MaxCount = 10, 
                 GUIName = $550944, 
                 GUIDescription = $570666, 
                 GUIIconIndex = 0, 
                 PVIncrementBonus = 0, 
                 VersionIdx = 0, 
                 Category = 0, 
                 LevelAwarded = 0, 
                 StringToken = 0, 
                 CardOwner = None, 
                 Entitlement = -1, 
                 bUseVersionIdx = FALSE, 
                 Rarity = ECardRarity.Rarity_Rare, 
                 GUICategory = EReinforcementGUICategory.EReinforcementGUICategory_AssaultRifle
                }, 
                {
                 UniqueName = "SFXGameContent.SFXWeapon_AssaultRifle_Revenant", 
                 GUIType = "assault", 
                 GUITextureRef = "GUI_Icons.Weapons.asl_revenant_256x128", 
                 PoolName = "", 
                 UniqueId = 0, 
                 MaxCount = 10, 
                 GUIName = $209729, 
                 GUIDescription = $339279, 
                 GUIIconIndex = 0, 
                 PVIncrementBonus = 0, 
                 VersionIdx = 0, 
                 Category = 0, 
                 LevelAwarded = 0, 
                 StringToken = 0, 
                 CardOwner = None, 
                 Entitlement = -1, 
                 bUseVersionIdx = FALSE, 
                 Rarity = ECardRarity.Rarity_Rare, 
                 GUICategory = EReinforcementGUICategory.EReinforcementGUICategory_AssaultRifle
                }, 
                {
                 UniqueName = "SFXGameContent.SFXWeapon_AssaultRifle_Geth", 
                 GUIType = "assault", 
                 GUITextureRef = "GUI_Icons.Weapons.asl_gethpulse_256x128", 
                 PoolName = "", 
                 UniqueId = 0, 
                 MaxCount = 10, 
                 GUIName = $546169, 
                 GUIDescription = $339329, 
                 GUIIconIndex = 0, 
                 PVIncrementBonus = 0, 
                 VersionIdx = 0, 
                 Category = 0, 
                 LevelAwarded = 0, 
                 StringToken = 0, 
                 CardOwner = None, 
                 Entitlement = -1, 
                 bUseVersionIdx = FALSE, 
                 Rarity = ECardRarity.Rarity_Rare, 
                 GUICategory = EReinforcementGUICategory.EReinforcementGUICategory_AssaultRifle
                }, 
                {
                 UniqueName = "SFXGameContent.SFXWeapon_Pistol_Thor", 
                 GUIType = "pistol", 
                 GUITextureRef = "GUI_Icons.Weapons.pst_thor_256x128", 
                 PoolName = "", 
                 UniqueId = 0, 
                 MaxCount = 10, 
                 GUIName = $551034, 
                 GUIDescription = $551036, 
                 GUIIconIndex = 0, 
                 PVIncrementBonus = 0, 
                 VersionIdx = 0, 
                 Category = 0, 
                 LevelAwarded = 0, 
                 StringToken = 0, 
                 CardOwner = None, 
                 Entitlement = -1, 
                 bUseVersionIdx = FALSE, 
                 Rarity = ECardRarity.Rarity_Rare, 
                 GUICategory = EReinforcementGUICategory.EReinforcementGUICategory_Pistol
                }, 
                {
                 UniqueName = "SFXGameContent.SFXWeapon_Pistol_Carnifex", 
                 GUIType = "pistol", 
                 GUITextureRef = "GUI_Icons.Weapons.pst_carniflex_256x128", 
                 PoolName = "", 
                 UniqueId = 0, 
                 MaxCount = 10, 
                 GUIName = $209733, 
                 GUIDescription = $339305, 
                 GUIIconIndex = 0, 
                 PVIncrementBonus = 0, 
                 VersionIdx = 0, 
                 Category = 0, 
                 LevelAwarded = 0, 
                 StringToken = 0, 
                 CardOwner = None, 
                 Entitlement = -1, 
                 bUseVersionIdx = FALSE, 
                 Rarity = ECardRarity.Rarity_Rare, 
                 GUICategory = EReinforcementGUICategory.EReinforcementGUICategory_Pistol
                }, 
                {
                 UniqueName = "SFXGameContent.SFXWeapon_SMG_Hornet", 
                 GUIType = "smg", 
                 GUITextureRef = "GUI_Icons.Weapons.smg_hornet_256x128", 
                 PoolName = "", 
                 UniqueId = 0, 
                 MaxCount = 10, 
                 GUIName = $551028, 
                 GUIDescription = $551030, 
                 GUIIconIndex = 0, 
                 PVIncrementBonus = 0, 
                 VersionIdx = 0, 
                 Category = 0, 
                 LevelAwarded = 0, 
                 StringToken = 0, 
                 CardOwner = None, 
                 Entitlement = -1, 
                 bUseVersionIdx = FALSE, 
                 Rarity = ECardRarity.Rarity_Rare, 
                 GUICategory = EReinforcementGUICategory.EReinforcementGUICategory_SMG
                }, 
                {
                 UniqueName = "SFXGameContent.SFXWeapon_Shotgun_Graal", 
                 GUIType = "shotgun", 
                 GUITextureRef = "GUI_Icons.Weapons.bls_graal_256x128", 
                 PoolName = "", 
                 UniqueId = 0, 
                 MaxCount = 10, 
                 GUIName = $551037, 
                 GUIDescription = $551039, 
                 GUIIconIndex = 0, 
                 PVIncrementBonus = 0, 
                 VersionIdx = 0, 
                 Category = 0, 
                 LevelAwarded = 0, 
                 StringToken = 0, 
                 CardOwner = None, 
                 Entitlement = -1, 
                 bUseVersionIdx = FALSE, 
                 Rarity = ECardRarity.Rarity_Rare, 
                 GUICategory = EReinforcementGUICategory.EReinforcementGUICategory_Shotgun
                }, 
                {
                 UniqueName = "SFXGameContent.SFXWeapon_Shotgun_Claymore", 
                 GUIType = "shotgun", 
                 GUITextureRef = "GUI_Icons.Weapons.bls_claymore_256x128", 
                 PoolName = "", 
                 UniqueId = 0, 
                 MaxCount = 10, 
                 GUIName = $209736, 
                 GUIDescription = $339318, 
                 GUIIconIndex = 0, 
                 PVIncrementBonus = 0, 
                 VersionIdx = 0, 
                 Category = 0, 
                 LevelAwarded = 0, 
                 StringToken = 0, 
                 CardOwner = None, 
                 Entitlement = -1, 
                 bUseVersionIdx = FALSE, 
                 Rarity = ECardRarity.Rarity_Rare, 
                 GUICategory = EReinforcementGUICategory.EReinforcementGUICategory_Shotgun
                }, 
                {
                 UniqueName = "SFXGameContent.SFXWeapon_Shotgun_Disciple", 
                 GUIType = "shotgun", 
                 GUITextureRef = "GUI_Icons.Weapons.bls_disciple_256x128", 
                 PoolName = "", 
                 UniqueId = 0, 
                 MaxCount = 10, 
                 GUIName = $581148, 
                 GUIDescription = $581149, 
                 GUIIconIndex = 0, 
                 PVIncrementBonus = 0, 
                 VersionIdx = 0, 
                 Category = 0, 
                 LevelAwarded = 0, 
                 StringToken = 0, 
                 CardOwner = None, 
                 Entitlement = -1, 
                 bUseVersionIdx = FALSE, 
                 Rarity = ECardRarity.Rarity_Rare, 
                 GUICategory = EReinforcementGUICategory.EReinforcementGUICategory_Shotgun
                }, 
                {
                 UniqueName = "SFXGameContent.SFXWeapon_Shotgun_Geth", 
                 GUIType = "shotgun", 
                 GUITextureRef = "GUI_Icons.Weapons.bls_gethplasma_256x128", 
                 PoolName = "", 
                 UniqueId = 0, 
                 MaxCount = 10, 
                 GUIName = $560869, 
                 GUIDescription = $560871, 
                 GUIIconIndex = 0, 
                 PVIncrementBonus = 0, 
                 VersionIdx = 0, 
                 Category = 0, 
                 LevelAwarded = 0, 
                 StringToken = 0, 
                 CardOwner = None, 
                 Entitlement = -1, 
                 bUseVersionIdx = FALSE, 
                 Rarity = ECardRarity.Rarity_Rare, 
                 GUICategory = EReinforcementGUICategory.EReinforcementGUICategory_Shotgun
                }, 
                {
                 UniqueName = "SFXGameContent.SFXWeapon_SniperRifle_Widow", 
                 GUIType = "sniper", 
                 GUITextureRef = "GUI_Icons.Weapons.snp_widow_256x128", 
                 PoolName = "", 
                 UniqueId = 0, 
                 MaxCount = 10, 
                 GUIName = $209739, 
                 GUIDescription = $339324, 
                 GUIIconIndex = 0, 
                 PVIncrementBonus = 0, 
                 VersionIdx = 0, 
                 Category = 0, 
                 LevelAwarded = 0, 
                 StringToken = 0, 
                 CardOwner = None, 
                 Entitlement = -1, 
                 bUseVersionIdx = FALSE, 
                 Rarity = ECardRarity.Rarity_Rare, 
                 GUICategory = EReinforcementGUICategory.EReinforcementGUICategory_SniperRifle
                }, 
                {
                 UniqueName = "SFXGameContent.SFXWeapon_Pistol_Scorpion", 
                 GUIType = "pistol", 
                 GUITextureRef = "GUI_Icons.Weapons.pst_scorpion_256x128", 
                 PoolName = "", 
                 UniqueId = 0, 
                 MaxCount = 10, 
                 GUIName = $551025, 
                 GUIDescription = $551027, 
                 GUIIconIndex = 0, 
                 PVIncrementBonus = 0, 
                 VersionIdx = 0, 
                 Category = 0, 
                 LevelAwarded = 0, 
                 StringToken = 0, 
                 CardOwner = None, 
                 Entitlement = -1, 
                 bUseVersionIdx = FALSE, 
                 Rarity = ECardRarity.Rarity_UltraRare, 
                 GUICategory = EReinforcementGUICategory.EReinforcementGUICategory_Pistol
                }, 
                {
                 UniqueName = "SFXGameContent.SFXWeapon_SniperRifle_Javelin", 
                 GUIType = "sniper", 
                 GUITextureRef = "GUI_Icons.Weapons.snp_javelin_256x128", 
                 PoolName = "", 
                 UniqueId = 0, 
                 MaxCount = 10, 
                 GUIName = $551047, 
                 GUIDescription = $551049, 
                 GUIIconIndex = 0, 
                 PVIncrementBonus = 0, 
                 VersionIdx = 0, 
                 Category = 0, 
                 LevelAwarded = 0, 
                 StringToken = 0, 
                 CardOwner = None, 
                 Entitlement = -1, 
                 bUseVersionIdx = FALSE, 
                 Rarity = ECardRarity.Rarity_UltraRare, 
                 GUICategory = EReinforcementGUICategory.EReinforcementGUICategory_SniperRifle
                }, 
                {
                 UniqueName = "SFXGameContent.SFXWeapon_AssaultRifle_Saber", 
                 GUIType = "assault", 
                 GUITextureRef = "GUI_Icons.Weapons.asl_saber_256x128", 
                 PoolName = "", 
                 UniqueId = 0, 
                 MaxCount = 10, 
                 GUIName = $676841, 
                 GUIDescription = $676842, 
                 GUIIconIndex = 0, 
                 PVIncrementBonus = 0, 
                 VersionIdx = 0, 
                 Category = 0, 
                 LevelAwarded = 0, 
                 StringToken = 0, 
                 CardOwner = None, 
                 Entitlement = -1, 
                 bUseVersionIdx = FALSE, 
                 Rarity = ECardRarity.Rarity_UltraRare, 
                 GUICategory = EReinforcementGUICategory.EReinforcementGUICategory_AssaultRifle
                }, 
                {
                 UniqueName = "SFXGameContent.SFXWeapon_Pistol_Talon", 
                 GUIType = "pistol", 
                 GUITextureRef = "GUI_Icons.Weapons.pst_talon_256x128", 
                 PoolName = "", 
                 UniqueId = 0, 
                 MaxCount = 10, 
                 GUIName = $551031, 
                 GUIDescription = $551033, 
                 GUIIconIndex = 0, 
                 PVIncrementBonus = 0, 
                 VersionIdx = 0, 
                 Category = 0, 
                 LevelAwarded = 0, 
                 StringToken = 0, 
                 CardOwner = None, 
                 Entitlement = -1, 
                 bUseVersionIdx = FALSE, 
                 Rarity = ECardRarity.Rarity_UltraRare, 
                 GUICategory = EReinforcementGUICategory.EReinforcementGUICategory_Pistol
                }, 
                {
                 UniqueName = "SFXGameContent.SFXWeapon_SniperRifle_BlackWidow", 
                 GUIType = "sniper", 
                 GUITextureRef = "GUI_Icons.Weapons.snp_blackwidow_256x128", 
                 PoolName = "", 
                 UniqueId = 0, 
                 MaxCount = 10, 
                 GUIName = $692577, 
                 GUIDescription = $707215, 
                 GUIIconIndex = 0, 
                 PVIncrementBonus = 0, 
                 VersionIdx = 0, 
                 Category = 0, 
                 LevelAwarded = 0, 
                 StringToken = 0, 
                 CardOwner = None, 
                 Entitlement = -1, 
                 bUseVersionIdx = FALSE, 
                 Rarity = ECardRarity.Rarity_UltraRare, 
                 GUICategory = EReinforcementGUICategory.EReinforcementGUICategory_SniperRifle
                }, 
                {
                 UniqueName = "SFXGameContent.SFXWeapon_Pistol_Ivory", 
                 GUIType = "pistol", 
                 GUITextureRef = "GUI_Icons.Weapons.pst_ivory_256x128", 
                 PoolName = "", 
                 UniqueId = 0, 
                 MaxCount = 10, 
                 GUIName = $704673, 
                 GUIDescription = $707217, 
                 GUIIconIndex = 0, 
                 PVIncrementBonus = 0, 
                 VersionIdx = 0, 
                 Category = 0, 
                 LevelAwarded = 0, 
                 StringToken = 0, 
                 CardOwner = None, 
                 Entitlement = -1, 
                 bUseVersionIdx = FALSE, 
                 Rarity = ECardRarity.Rarity_UltraRare, 
                 GUICategory = EReinforcementGUICategory.EReinforcementGUICategory_Pistol
                }, 
                {
                 UniqueName = "SFXGameContent.SFXWeapon_Shotgun_Striker", 
                 GUIType = "shotgun", 
                 GUITextureRef = "GUI_Icons.Weapons.bls_striker_256x128", 
                 PoolName = "", 
                 UniqueId = 0, 
                 MaxCount = 10, 
                 GUIName = $709355, 
                 GUIDescription = $707213, 
                 GUIIconIndex = 0, 
                 PVIncrementBonus = 0, 
                 VersionIdx = 0, 
                 Category = 0, 
                 LevelAwarded = 0, 
                 StringToken = 0, 
                 CardOwner = None, 
                 Entitlement = -1, 
                 bUseVersionIdx = FALSE, 
                 Rarity = ECardRarity.Rarity_UltraRare, 
                 GUICategory = EReinforcementGUICategory.EReinforcementGUICategory_Shotgun
                }, 
                {
                 UniqueName = "AdeptHumanMale", 
                 GUIType = "char", 
                 GUITextureRef = "GUI_MPImages.Cards.KitBioticMale", 
                 PoolName = "", 
                 UniqueId = 0, 
                 MaxCount = 0, 
                 GUIName = $711364, 
                 GUIDescription = $0, 
                 GUIIconIndex = 0, 
                 PVIncrementBonus = 0, 
                 VersionIdx = 0, 
                 Category = 0, 
                 LevelAwarded = 0, 
                 StringToken = 0, 
                 CardOwner = None, 
                 Entitlement = -1, 
                 bUseVersionIdx = FALSE, 
                 Rarity = ECardRarity.Rarity_Common, 
                 GUICategory = EReinforcementGUICategory.EReinforcementGUICategory_None
                }, 
                {
                 UniqueName = "AdeptHumanFemale", 
                 GUIType = "char", 
                 GUITextureRef = "GUI_MPImages.Cards.KitBiotic", 
                 PoolName = "", 
                 UniqueId = 0, 
                 MaxCount = 0, 
                 GUIName = $711370, 
                 GUIDescription = $0, 
                 GUIIconIndex = 0, 
                 PVIncrementBonus = 0, 
                 VersionIdx = 0, 
                 Category = 0, 
                 LevelAwarded = 0, 
                 StringToken = 0, 
                 CardOwner = None, 
                 Entitlement = -1, 
                 bUseVersionIdx = FALSE, 
                 Rarity = ECardRarity.Rarity_Common, 
                 GUICategory = EReinforcementGUICategory.EReinforcementGUICategory_None
                }, 
                {
                 UniqueName = "EngineerHumanMale", 
                 GUIType = "char", 
                 GUITextureRef = "GUI_MPImages.Cards.KitAgentMale", 
                 PoolName = "", 
                 UniqueId = 0, 
                 MaxCount = 0, 
                 GUIName = $711365, 
                 GUIDescription = $0, 
                 GUIIconIndex = 0, 
                 PVIncrementBonus = 0, 
                 VersionIdx = 0, 
                 Category = 0, 
                 LevelAwarded = 0, 
                 StringToken = 0, 
                 CardOwner = None, 
                 Entitlement = -1, 
                 bUseVersionIdx = FALSE, 
                 Rarity = ECardRarity.Rarity_Common, 
                 GUICategory = EReinforcementGUICategory.EReinforcementGUICategory_None
                }, 
                {
                 UniqueName = "EngineerHumanFemale", 
                 GUIType = "char", 
                 GUITextureRef = "GUI_MPImages.Cards.KitAgent", 
                 PoolName = "", 
                 UniqueId = 0, 
                 MaxCount = 0, 
                 GUIName = $711371, 
                 GUIDescription = $0, 
                 GUIIconIndex = 0, 
                 PVIncrementBonus = 0, 
                 VersionIdx = 0, 
                 Category = 0, 
                 LevelAwarded = 0, 
                 StringToken = 0, 
                 CardOwner = None, 
                 Entitlement = -1, 
                 bUseVersionIdx = FALSE, 
                 Rarity = ECardRarity.Rarity_Common, 
                 GUICategory = EReinforcementGUICategory.EReinforcementGUICategory_None
                }, 
                {
                 UniqueName = "InfiltratorHumanMale", 
                 GUIType = "char", 
                 GUITextureRef = "GUI_MPImages.Cards.KitAgentMale", 
                 PoolName = "", 
                 UniqueId = 0, 
                 MaxCount = 0, 
                 GUIName = $711366, 
                 GUIDescription = $0, 
                 GUIIconIndex = 0, 
                 PVIncrementBonus = 0, 
                 VersionIdx = 0, 
                 Category = 0, 
                 LevelAwarded = 0, 
                 StringToken = 0, 
                 CardOwner = None, 
                 Entitlement = -1, 
                 bUseVersionIdx = FALSE, 
                 Rarity = ECardRarity.Rarity_Common, 
                 GUICategory = EReinforcementGUICategory.EReinforcementGUICategory_None
                }, 
                {
                 UniqueName = "InfiltratorHumanFemale", 
                 GUIType = "char", 
                 GUITextureRef = "GUI_MPImages.Cards.KitAgent", 
                 PoolName = "", 
                 UniqueId = 0, 
                 MaxCount = 0, 
                 GUIName = $711372, 
                 GUIDescription = $0, 
                 GUIIconIndex = 0, 
                 PVIncrementBonus = 0, 
                 VersionIdx = 0, 
                 Category = 0, 
                 LevelAwarded = 0, 
                 StringToken = 0, 
                 CardOwner = None, 
                 Entitlement = -1, 
                 bUseVersionIdx = FALSE, 
                 Rarity = ECardRarity.Rarity_Common, 
                 GUICategory = EReinforcementGUICategory.EReinforcementGUICategory_None
                }, 
                {
                 UniqueName = "SentinelHumanMale", 
                 GUIType = "char", 
                 GUITextureRef = "GUI_MPImages.Cards.KitBioticMale", 
                 PoolName = "", 
                 UniqueId = 0, 
                 MaxCount = 0, 
                 GUIName = $711367, 
                 GUIDescription = $0, 
                 GUIIconIndex = 0, 
                 PVIncrementBonus = 0, 
                 VersionIdx = 0, 
                 Category = 0, 
                 LevelAwarded = 0, 
                 StringToken = 0, 
                 CardOwner = None, 
                 Entitlement = -1, 
                 bUseVersionIdx = FALSE, 
                 Rarity = ECardRarity.Rarity_Common, 
                 GUICategory = EReinforcementGUICategory.EReinforcementGUICategory_None
                }, 
                {
                 UniqueName = "SentinelHumanFemale", 
                 GUIType = "char", 
                 GUITextureRef = "GUI_MPImages.Cards.KitBiotic", 
                 PoolName = "", 
                 UniqueId = 0, 
                 MaxCount = 0, 
                 GUIName = $711373, 
                 GUIDescription = $0, 
                 GUIIconIndex = 0, 
                 PVIncrementBonus = 0, 
                 VersionIdx = 0, 
                 Category = 0, 
                 LevelAwarded = 0, 
                 StringToken = 0, 
                 CardOwner = None, 
                 Entitlement = -1, 
                 bUseVersionIdx = FALSE, 
                 Rarity = ECardRarity.Rarity_Common, 
                 GUICategory = EReinforcementGUICategory.EReinforcementGUICategory_None
                }, 
                {
                 UniqueName = "SoldierHumanMale", 
                 GUIType = "char", 
                 GUITextureRef = "GUI_MPImages.Cards.KitSoldierMale", 
                 PoolName = "", 
                 UniqueId = 0, 
                 MaxCount = 0, 
                 GUIName = $711368, 
                 GUIDescription = $0, 
                 GUIIconIndex = 0, 
                 PVIncrementBonus = 0, 
                 VersionIdx = 0, 
                 Category = 0, 
                 LevelAwarded = 0, 
                 StringToken = 0, 
                 CardOwner = None, 
                 Entitlement = -1, 
                 bUseVersionIdx = FALSE, 
                 Rarity = ECardRarity.Rarity_Common, 
                 GUICategory = EReinforcementGUICategory.EReinforcementGUICategory_None
                }, 
                {
                 UniqueName = "SoldierHumanFemale", 
                 GUIType = "char", 
                 GUITextureRef = "GUI_MPImages.Cards.KitSoldier", 
                 PoolName = "", 
                 UniqueId = 0, 
                 MaxCount = 0, 
                 GUIName = $711374, 
                 GUIDescription = $0, 
                 GUIIconIndex = 0, 
                 PVIncrementBonus = 0, 
                 VersionIdx = 0, 
                 Category = 0, 
                 LevelAwarded = 0, 
                 StringToken = 0, 
                 CardOwner = None, 
                 Entitlement = -1, 
                 bUseVersionIdx = FALSE, 
                 Rarity = ECardRarity.Rarity_Common, 
                 GUICategory = EReinforcementGUICategory.EReinforcementGUICategory_None
                }, 
                {
                 UniqueName = "VanguardHumanMale", 
                 GUIType = "char", 
                 GUITextureRef = "GUI_MPImages.Cards.KitSoldierMale", 
                 PoolName = "", 
                 UniqueId = 0, 
                 MaxCount = 0, 
                 GUIName = $711369, 
                 GUIDescription = $0, 
                 GUIIconIndex = 0, 
                 PVIncrementBonus = 0, 
                 VersionIdx = 0, 
                 Category = 0, 
                 LevelAwarded = 0, 
                 StringToken = 0, 
                 CardOwner = None, 
                 Entitlement = -1, 
                 bUseVersionIdx = FALSE, 
                 Rarity = ECardRarity.Rarity_Common, 
                 GUICategory = EReinforcementGUICategory.EReinforcementGUICategory_None
                }, 
                {
                 UniqueName = "VanguardHumanFemale", 
                 GUIType = "char", 
                 GUITextureRef = "GUI_MPImages.Cards.KitSoldier", 
                 PoolName = "", 
                 UniqueId = 0, 
                 MaxCount = 0, 
                 GUIName = $711375, 
                 GUIDescription = $0, 
                 GUIIconIndex = 0, 
                 PVIncrementBonus = 0, 
                 VersionIdx = 0, 
                 Category = 0, 
                 LevelAwarded = 0, 
                 StringToken = 0, 
                 CardOwner = None, 
                 Entitlement = -1, 
                 bUseVersionIdx = FALSE, 
                 Rarity = ECardRarity.Rarity_Common, 
                 GUICategory = EReinforcementGUICategory.EReinforcementGUICategory_None
                }, 
                {
                 UniqueName = "SoldierHumanMaleBF3", 
                 GUIType = "char", 
                 GUITextureRef = "GUI_MPImages.Cards.KitSoldierMale", 
                 PoolName = "", 
                 UniqueId = 0, 
                 MaxCount = 0, 
                 GUIName = $723302, 
                 GUIDescription = $723303, 
                 GUIIconIndex = 0, 
                 PVIncrementBonus = 0, 
                 VersionIdx = 0, 
                 Category = 0, 
                 LevelAwarded = 0, 
                 StringToken = 0, 
                 CardOwner = None, 
                 Entitlement = -1, 
                 bUseVersionIdx = FALSE, 
                 Rarity = ECardRarity.Rarity_Uncommon, 
                 GUICategory = EReinforcementGUICategory.EReinforcementGUICategory_None
                }, 
                {
                 UniqueName = "InfiltratorHumanFemaleBF3", 
                 GUIType = "char", 
                 GUITextureRef = "GUI_MPImages.Cards.KitAgent", 
                 PoolName = "", 
                 UniqueId = 0, 
                 MaxCount = 0, 
                 GUIName = $723371, 
                 GUIDescription = $723303, 
                 GUIIconIndex = 0, 
                 PVIncrementBonus = 0, 
                 VersionIdx = 0, 
                 Category = 0, 
                 LevelAwarded = 0, 
                 StringToken = 0, 
                 CardOwner = None, 
                 Entitlement = -1, 
                 bUseVersionIdx = FALSE, 
                 Rarity = ECardRarity.Rarity_Uncommon, 
                 GUICategory = EReinforcementGUICategory.EReinforcementGUICategory_None
                }, 
                {
                 UniqueName = "AdeptDrell", 
                 GUIType = "char", 
                 GUITextureRef = "GUI_MPImages.Cards.KitDrell", 
                 PoolName = "", 
                 UniqueId = 0, 
                 MaxCount = 0, 
                 GUIName = $711377, 
                 GUIDescription = $0, 
                 GUIIconIndex = 0, 
                 PVIncrementBonus = 0, 
                 VersionIdx = 1, 
                 Category = 0, 
                 LevelAwarded = 0, 
                 StringToken = 0, 
                 CardOwner = None, 
                 Entitlement = -1, 
                 bUseVersionIdx = FALSE, 
                 Rarity = ECardRarity.Rarity_Uncommon, 
                 GUICategory = EReinforcementGUICategory.EReinforcementGUICategory_Kit
                }, 
                {
                 UniqueName = "VanguardDrell", 
                 GUIType = "char", 
                 GUITextureRef = "GUI_MPImages.Cards.KitDrell", 
                 PoolName = "", 
                 UniqueId = 0, 
                 MaxCount = 0, 
                 GUIName = $711386, 
                 GUIDescription = $0, 
                 GUIIconIndex = 0, 
                 PVIncrementBonus = 0, 
                 VersionIdx = 2, 
                 Category = 0, 
                 LevelAwarded = 0, 
                 StringToken = 0, 
                 CardOwner = None, 
                 Entitlement = -1, 
                 bUseVersionIdx = FALSE, 
                 Rarity = ECardRarity.Rarity_Rare, 
                 GUICategory = EReinforcementGUICategory.EReinforcementGUICategory_Kit
                }, 
                {
                 UniqueName = "EngineerSalarian", 
                 GUIType = "char", 
                 GUITextureRef = "GUI_MPImages.Cards.KitSalarian", 
                 PoolName = "", 
                 UniqueId = 0, 
                 MaxCount = 0, 
                 GUIName = $711379, 
                 GUIDescription = $0, 
                 GUIIconIndex = 0, 
                 PVIncrementBonus = 0, 
                 VersionIdx = 1, 
                 Category = 0, 
                 LevelAwarded = 0, 
                 StringToken = 0, 
                 CardOwner = None, 
                 Entitlement = -1, 
                 bUseVersionIdx = FALSE, 
                 Rarity = ECardRarity.Rarity_Uncommon, 
                 GUICategory = EReinforcementGUICategory.EReinforcementGUICategory_Kit
                }, 
                {
                 UniqueName = "InfiltratorSalarian", 
                 GUIType = "char", 
                 GUITextureRef = "GUI_MPImages.Cards.KitSalarian", 
                 PoolName = "", 
                 UniqueId = 0, 
                 MaxCount = 0, 
                 GUIName = $711380, 
                 GUIDescription = $0, 
                 GUIIconIndex = 0, 
                 PVIncrementBonus = 0, 
                 VersionIdx = 2, 
                 Category = 0, 
                 LevelAwarded = 0, 
                 StringToken = 0, 
                 CardOwner = None, 
                 Entitlement = -1, 
                 bUseVersionIdx = FALSE, 
                 Rarity = ECardRarity.Rarity_Rare, 
                 GUICategory = EReinforcementGUICategory.EReinforcementGUICategory_Kit
                }, 
                {
                 UniqueName = "InfiltratorQuarian", 
                 GUIType = "char", 
                 GUITextureRef = "GUI_MPImages.Cards.KitQuarian", 
                 PoolName = "", 
                 UniqueId = 0, 
                 MaxCount = 0, 
                 GUIName = $711381, 
                 GUIDescription = $0, 
                 GUIIconIndex = 0, 
                 PVIncrementBonus = 0, 
                 VersionIdx = 1, 
                 Category = 0, 
                 LevelAwarded = 0, 
                 StringToken = 0, 
                 CardOwner = None, 
                 Entitlement = -1, 
                 bUseVersionIdx = FALSE, 
                 Rarity = ECardRarity.Rarity_Uncommon, 
                 GUICategory = EReinforcementGUICategory.EReinforcementGUICategory_Kit
                }, 
                {
                 UniqueName = "EngineerQuarian", 
                 GUIType = "char", 
                 GUITextureRef = "GUI_MPImages.Cards.KitQuarian", 
                 PoolName = "", 
                 UniqueId = 0, 
                 MaxCount = 0, 
                 GUIName = $711378, 
                 GUIDescription = $0, 
                 GUIIconIndex = 0, 
                 PVIncrementBonus = 0, 
                 VersionIdx = 2, 
                 Category = 0, 
                 LevelAwarded = 0, 
                 StringToken = 0, 
                 CardOwner = None, 
                 Entitlement = -1, 
                 bUseVersionIdx = FALSE, 
                 Rarity = ECardRarity.Rarity_Rare, 
                 GUICategory = EReinforcementGUICategory.EReinforcementGUICategory_Kit
                }, 
                {
                 UniqueName = "SentinelTurian", 
                 GUIType = "char", 
                 GUITextureRef = "GUI_MPImages.Cards.KitTurian", 
                 PoolName = "", 
                 UniqueId = 0, 
                 MaxCount = 0, 
                 GUIName = $711382, 
                 GUIDescription = $0, 
                 GUIIconIndex = 0, 
                 PVIncrementBonus = 0, 
                 VersionIdx = 1, 
                 Category = 0, 
                 LevelAwarded = 0, 
                 StringToken = 0, 
                 CardOwner = None, 
                 Entitlement = -1, 
                 bUseVersionIdx = FALSE, 
                 Rarity = ECardRarity.Rarity_Uncommon, 
                 GUICategory = EReinforcementGUICategory.EReinforcementGUICategory_Kit
                }, 
                {
                 UniqueName = "SoldierTurian", 
                 GUIType = "char", 
                 GUITextureRef = "GUI_MPImages.Cards.KitTurian", 
                 PoolName = "", 
                 UniqueId = 0, 
                 MaxCount = 0, 
                 GUIName = $711385, 
                 GUIDescription = $0, 
                 GUIIconIndex = 0, 
                 PVIncrementBonus = 0, 
                 VersionIdx = 1, 
                 Category = 0, 
                 LevelAwarded = 0, 
                 StringToken = 0, 
                 CardOwner = None, 
                 Entitlement = -1, 
                 bUseVersionIdx = FALSE, 
                 Rarity = ECardRarity.Rarity_Uncommon, 
                 GUICategory = EReinforcementGUICategory.EReinforcementGUICategory_Kit
                }, 
                {
                 UniqueName = "VanguardAsari", 
                 GUIType = "char", 
                 GUITextureRef = "GUI_MPImages.Cards.KitAsari", 
                 PoolName = "", 
                 UniqueId = 0, 
                 MaxCount = 0, 
                 GUIName = $711387, 
                 GUIDescription = $0, 
                 GUIIconIndex = 0, 
                 PVIncrementBonus = 0, 
                 VersionIdx = 1, 
                 Category = 0, 
                 LevelAwarded = 0, 
                 StringToken = 0, 
                 CardOwner = None, 
                 Entitlement = -1, 
                 bUseVersionIdx = FALSE, 
                 Rarity = ECardRarity.Rarity_Uncommon, 
                 GUICategory = EReinforcementGUICategory.EReinforcementGUICategory_Kit
                }, 
                {
                 UniqueName = "AdeptAsari", 
                 GUIType = "char", 
                 GUITextureRef = "GUI_MPImages.Cards.KitAsari", 
                 PoolName = "", 
                 UniqueId = 0, 
                 MaxCount = 0, 
                 GUIName = $711376, 
                 GUIDescription = $0, 
                 GUIIconIndex = 0, 
                 PVIncrementBonus = 0, 
                 VersionIdx = 2, 
                 Category = 0, 
                 LevelAwarded = 0, 
                 StringToken = 0, 
                 CardOwner = None, 
                 Entitlement = -1, 
                 bUseVersionIdx = FALSE, 
                 Rarity = ECardRarity.Rarity_Rare, 
                 GUICategory = EReinforcementGUICategory.EReinforcementGUICategory_Kit
                }, 
                {
                 UniqueName = "SentinelKrogan", 
                 GUIType = "char", 
                 GUITextureRef = "GUI_MPImages.Cards.KitKrogan", 
                 PoolName = "", 
                 UniqueId = 0, 
                 MaxCount = 0, 
                 GUIName = $711383, 
                 GUIDescription = $0, 
                 GUIIconIndex = 0, 
                 PVIncrementBonus = 0, 
                 VersionIdx = 2, 
                 Category = 0, 
                 LevelAwarded = 0, 
                 StringToken = 0, 
                 CardOwner = None, 
                 Entitlement = -1, 
                 bUseVersionIdx = FALSE, 
                 Rarity = ECardRarity.Rarity_Rare, 
                 GUICategory = EReinforcementGUICategory.EReinforcementGUICategory_Kit
                }, 
                {
                 UniqueName = "SoldierKrogan", 
                 GUIType = "char", 
                 GUITextureRef = "GUI_MPImages.Cards.KitKrogan", 
                 PoolName = "", 
                 UniqueId = 0, 
                 MaxCount = 0, 
                 GUIName = $711384, 
                 GUIDescription = $0, 
                 GUIIconIndex = 0, 
                 PVIncrementBonus = 0, 
                 VersionIdx = 2, 
                 Category = 0, 
                 LevelAwarded = 0, 
                 StringToken = 0, 
                 CardOwner = None, 
                 Entitlement = -1, 
                 bUseVersionIdx = FALSE, 
                 Rarity = ECardRarity.Rarity_Rare, 
                 GUICategory = EReinforcementGUICategory.EReinforcementGUICategory_Kit
                }, 
                {
                 UniqueName = "SFXGameContent.SFXWeaponMod_PistolAccuracy", 
                 GUIType = "pistolmod", 
                 GUITextureRef = "GUI_Icons.Weapons.pst_sco_a_256x128", 
                 PoolName = "", 
                 UniqueId = 0, 
                 MaxCount = 5, 
                 GUIName = $519359, 
                 GUIDescription = $711318, 
                 GUIIconIndex = 0, 
                 PVIncrementBonus = 0, 
                 VersionIdx = 0, 
                 Category = 0, 
                 LevelAwarded = 0, 
                 StringToken = 0, 
                 CardOwner = None, 
                 Entitlement = -1, 
                 bUseVersionIdx = FALSE, 
                 Rarity = ECardRarity.Rarity_Common, 
                 GUICategory = EReinforcementGUICategory.EReinforcementGUICategory_Mod
                }, 
                {
                 UniqueName = "SFXGameContent.SFXWeaponMod_SMGMagSize", 
                 GUIType = "smgmod", 
                 GUITextureRef = "GUI_Icons.Weapons.MOD_ammo-capacity_256x128", 
                 PoolName = "", 
                 UniqueId = 0, 
                 MaxCount = 5, 
                 GUIName = $519470, 
                 GUIDescription = $711326, 
                 GUIIconIndex = 0, 
                 PVIncrementBonus = 0, 
                 VersionIdx = 0, 
                 Category = 0, 
                 LevelAwarded = 0, 
                 StringToken = 0, 
                 CardOwner = None, 
                 Entitlement = -1, 
                 bUseVersionIdx = FALSE, 
                 Rarity = ECardRarity.Rarity_Common, 
                 GUICategory = EReinforcementGUICategory.EReinforcementGUICategory_Mod
                }, 
                {
                 UniqueName = "SFXGameContent.SFXWeaponMod_AssaultRifleStability", 
                 GUIType = "assaultmod", 
                 GUITextureRef = "GUI_Icons.Weapons.MOD_stability-damper_256x128", 
                 PoolName = "", 
                 UniqueId = 0, 
                 MaxCount = 5, 
                 GUIName = $518980, 
                 GUIDescription = $711330, 
                 GUIIconIndex = 0, 
                 PVIncrementBonus = 0, 
                 VersionIdx = 0, 
                 Category = 0, 
                 LevelAwarded = 0, 
                 StringToken = 0, 
                 CardOwner = None, 
                 Entitlement = -1, 
                 bUseVersionIdx = FALSE, 
                 Rarity = ECardRarity.Rarity_Common, 
                 GUICategory = EReinforcementGUICategory.EReinforcementGUICategory_Mod
                }, 
                {
                 UniqueName = "SFXGameContent.SFXWeaponMod_ShotgunAccuracy", 
                 GUIType = "shotgunmod", 
                 GUITextureRef = "GUI_Icons.Weapons.MOD_barrel-choke_256x128", 
                 PoolName = "", 
                 UniqueId = 0, 
                 MaxCount = 5, 
                 GUIName = $519500, 
                 GUIDescription = $711336, 
                 GUIIconIndex = 0, 
                 PVIncrementBonus = 0, 
                 VersionIdx = 0, 
                 Category = 0, 
                 LevelAwarded = 0, 
                 StringToken = 0, 
                 CardOwner = None, 
                 Entitlement = -1, 
                 bUseVersionIdx = FALSE, 
                 Rarity = ECardRarity.Rarity_Common, 
                 GUICategory = EReinforcementGUICategory.EReinforcementGUICategory_Mod
                }, 
                {
                 UniqueName = "SFXGameContent.SFXWeaponMod_SniperRifleReloadSpeed", 
                 GUIType = "snipermod", 
                 GUITextureRef = "GUI_Icons.Weapons.MOD_heat-sink_256x128", 
                 PoolName = "", 
                 UniqueId = 0, 
                 MaxCount = 5, 
                 GUIName = $519536, 
                 GUIDescription = $711340, 
                 GUIIconIndex = 0, 
                 PVIncrementBonus = 0, 
                 VersionIdx = 0, 
                 Category = 0, 
                 LevelAwarded = 0, 
                 StringToken = 0, 
                 CardOwner = None, 
                 Entitlement = -1, 
                 bUseVersionIdx = FALSE, 
                 Rarity = ECardRarity.Rarity_Common, 
                 GUICategory = EReinforcementGUICategory.EReinforcementGUICategory_Mod
                }, 
                {
                 UniqueName = "SFXGameContent.SFXWeaponMod_PistolMagSize", 
                 GUIType = "pistolmod", 
                 GUITextureRef = "GUI_Icons.Weapons.MOD_ammo-capacity_256x128", 
                 PoolName = "", 
                 UniqueId = 0, 
                 MaxCount = 5, 
                 GUIName = $519438, 
                 GUIDescription = $711321, 
                 GUIIconIndex = 0, 
                 PVIncrementBonus = 0, 
                 VersionIdx = 0, 
                 Category = 0, 
                 LevelAwarded = 0, 
                 StringToken = 0, 
                 CardOwner = None, 
                 Entitlement = -1, 
                 bUseVersionIdx = FALSE, 
                 Rarity = ECardRarity.Rarity_Common, 
                 GUICategory = EReinforcementGUICategory.EReinforcementGUICategory_Mod
                }, 
                {
                 UniqueName = "SFXGameContent.SFXWeaponMod_PistolDamage", 
                 GUIType = "pistolmod", 
                 GUITextureRef = "GUI_Icons.Weapons.pst_bar_a_256x128", 
                 PoolName = "", 
                 UniqueId = 0, 
                 MaxCount = 5, 
                 GUIName = $519355, 
                 GUIDescription = $711319, 
                 GUIIconIndex = 0, 
                 PVIncrementBonus = 0, 
                 VersionIdx = 0, 
                 Category = 0, 
                 LevelAwarded = 0, 
                 StringToken = 0, 
                 CardOwner = None, 
                 Entitlement = -1, 
                 bUseVersionIdx = FALSE, 
                 Rarity = ECardRarity.Rarity_Common, 
                 GUICategory = EReinforcementGUICategory.EReinforcementGUICategory_Mod
                }, 
                {
                 UniqueName = "SFXGameContent.SFXWeaponMod_SMGAccuracy", 
                 GUIType = "smgmod", 
                 GUITextureRef = "GUI_Icons.Weapons.pst_sco_a_256x128", 
                 PoolName = "", 
                 UniqueId = 0, 
                 MaxCount = 5, 
                 GUIName = $519472, 
                 GUIDescription = $711323, 
                 GUIIconIndex = 0, 
                 PVIncrementBonus = 0, 
                 VersionIdx = 0, 
                 Category = 0, 
                 LevelAwarded = 0, 
                 StringToken = 0, 
                 CardOwner = None, 
                 Entitlement = -1, 
                 bUseVersionIdx = FALSE, 
                 Rarity = ECardRarity.Rarity_Common, 
                 GUICategory = EReinforcementGUICategory.EReinforcementGUICategory_Mod
                }, 
                {
                 UniqueName = "SFXGameContent.SFXWeaponMod_SMGConstraintDamage", 
                 GUIType = "smgmod", 
                 GUITextureRef = "GUI_Icons.Weapons.MOD_smg_heat-sink-mod_256x128", 
                 PoolName = "", 
                 UniqueId = 0, 
                 MaxCount = 5, 
                 GUIName = $519476, 
                 GUIDescription = $711327, 
                 GUIIconIndex = 0, 
                 PVIncrementBonus = 0, 
                 VersionIdx = 0, 
                 Category = 0, 
                 LevelAwarded = 0, 
                 StringToken = 0, 
                 CardOwner = None, 
                 Entitlement = -1, 
                 bUseVersionIdx = FALSE, 
                 Rarity = ECardRarity.Rarity_Common, 
                 GUICategory = EReinforcementGUICategory.EReinforcementGUICategory_Mod
                }, 
                {
                 UniqueName = "SFXGameContent.SFXWeaponMod_AssaultRifleAccuracy", 
                 GUIType = "assaultmod", 
                 GUITextureRef = "GUI_Icons.Weapons.asl_sco_a_256x128", 
                 PoolName = "", 
                 UniqueId = 0, 
                 MaxCount = 5, 
                 GUIName = $515088, 
                 GUIDescription = $711328, 
                 GUIIconIndex = 0, 
                 PVIncrementBonus = 0, 
                 VersionIdx = 0, 
                 Category = 0, 
                 LevelAwarded = 0, 
                 StringToken = 0, 
                 CardOwner = None, 
                 Entitlement = -1, 
                 bUseVersionIdx = FALSE, 
                 Rarity = ECardRarity.Rarity_Common, 
                 GUICategory = EReinforcementGUICategory.EReinforcementGUICategory_Mod
                }, 
                {
                 UniqueName = "SFXGameContent.SFXWeaponMod_AssaultRifleMagSize", 
                 GUIType = "assaultmod", 
                 GUITextureRef = "GUI_Icons.Weapons.MOD_ammo-capacity_256x128", 
                 PoolName = "", 
                 UniqueId = 0, 
                 MaxCount = 5, 
                 GUIName = $518985, 
                 GUIDescription = $711331, 
                 GUIIconIndex = 0, 
                 PVIncrementBonus = 0, 
                 VersionIdx = 0, 
                 Category = 0, 
                 LevelAwarded = 0, 
                 StringToken = 0, 
                 CardOwner = None, 
                 Entitlement = -1, 
                 bUseVersionIdx = FALSE, 
                 Rarity = ECardRarity.Rarity_Common, 
                 GUICategory = EReinforcementGUICategory.EReinforcementGUICategory_Mod
                }, 
                {
                 UniqueName = "SFXGameContent.SFXWeaponMod_ShotgunDamage", 
                 GUIType = "shotgunmod", 
                 GUITextureRef = "GUI_Icons.Weapons.bls_bar_a_256x128", 
                 PoolName = "", 
                 UniqueId = 0, 
                 MaxCount = 5, 
                 GUIName = $519486, 
                 GUIDescription = $711333, 
                 GUIIconIndex = 0, 
                 PVIncrementBonus = 0, 
                 VersionIdx = 0, 
                 Category = 0, 
                 LevelAwarded = 0, 
                 StringToken = 0, 
                 CardOwner = None, 
                 Entitlement = -1, 
                 bUseVersionIdx = FALSE, 
                 Rarity = ECardRarity.Rarity_Common, 
                 GUICategory = EReinforcementGUICategory.EReinforcementGUICategory_Mod
                }, 
                {
                 UniqueName = "SFXGameContent.SFXWeaponMod_ShotgunMeleeDamage", 
                 GUIType = "shotgunmod", 
                 GUITextureRef = "GUI_Icons.Weapons.bls_melee_a_256x128", 
                 PoolName = "", 
                 UniqueId = 0, 
                 MaxCount = 5, 
                 GUIName = $519504, 
                 GUIDescription = $711334, 
                 GUIIconIndex = 0, 
                 PVIncrementBonus = 0, 
                 VersionIdx = 0, 
                 Category = 0, 
                 LevelAwarded = 0, 
                 StringToken = 0, 
                 CardOwner = None, 
                 Entitlement = -1, 
                 bUseVersionIdx = FALSE, 
                 Rarity = ECardRarity.Rarity_Common, 
                 GUICategory = EReinforcementGUICategory.EReinforcementGUICategory_Mod
                }, 
                {
                 UniqueName = "SFXGameContent.SFXWeaponMod_SniperRifleDamage", 
                 GUIType = "snipermod", 
                 GUITextureRef = "GUI_Icons.Weapons.snp_bar_a_256x128", 
                 PoolName = "", 
                 UniqueId = 0, 
                 MaxCount = 5, 
                 GUIName = $519527, 
                 GUIDescription = $711339, 
                 GUIIconIndex = 0, 
                 PVIncrementBonus = 0, 
                 VersionIdx = 0, 
                 Category = 0, 
                 LevelAwarded = 0, 
                 StringToken = 0, 
                 CardOwner = None, 
                 Entitlement = -1, 
                 bUseVersionIdx = FALSE, 
                 Rarity = ECardRarity.Rarity_Uncommon, 
                 GUICategory = EReinforcementGUICategory.EReinforcementGUICategory_Mod
                }, 
                {
                 UniqueName = "SFXGameContent.SFXWeaponMod_PistolStability", 
                 GUIType = "pistolmod", 
                 GUITextureRef = "GUI_Icons.Weapons.MOD_tazer-mod_256x128", 
                 PoolName = "", 
                 UniqueId = 0, 
                 MaxCount = 5, 
                 GUIName = $519357, 
                 GUIDescription = $711320, 
                 GUIIconIndex = 0, 
                 PVIncrementBonus = 0, 
                 VersionIdx = 0, 
                 Category = 0, 
                 LevelAwarded = 0, 
                 StringToken = 0, 
                 CardOwner = None, 
                 Entitlement = -1, 
                 bUseVersionIdx = FALSE, 
                 Rarity = ECardRarity.Rarity_Uncommon, 
                 GUICategory = EReinforcementGUICategory.EReinforcementGUICategory_Mod
                }, 
                {
                 UniqueName = "SFXGameContent.SFXWeaponMod_PistolReloadSpeed", 
                 GUIType = "pistolmod", 
                 GUITextureRef = "GUI_Icons.Weapons.MOD_penetration-mod_256x128", 
                 PoolName = "", 
                 UniqueId = 0, 
                 MaxCount = 5, 
                 GUIName = $519352, 
                 GUIDescription = $711322, 
                 GUIIconIndex = 0, 
                 PVIncrementBonus = 0, 
                 VersionIdx = 0, 
                 Category = 0, 
                 LevelAwarded = 0, 
                 StringToken = 0, 
                 CardOwner = None, 
                 Entitlement = -1, 
                 bUseVersionIdx = FALSE, 
                 Rarity = ECardRarity.Rarity_Uncommon, 
                 GUICategory = EReinforcementGUICategory.EReinforcementGUICategory_Mod
                }, 
                {
                 UniqueName = "SFXGameContent.SFXWeaponMod_SMGStability", 
                 GUIType = "smgmod", 
                 GUITextureRef = "GUI_Icons.Weapons.MOD_ultralight-material_256x128", 
                 PoolName = "", 
                 UniqueId = 0, 
                 MaxCount = 5, 
                 GUIName = $519474, 
                 GUIDescription = $711325, 
                 GUIIconIndex = 0, 
                 PVIncrementBonus = 0, 
                 VersionIdx = 0, 
                 Category = 0, 
                 LevelAwarded = 0, 
                 StringToken = 0, 
                 CardOwner = None, 
                 Entitlement = -1, 
                 bUseVersionIdx = FALSE, 
                 Rarity = ECardRarity.Rarity_Uncommon, 
                 GUICategory = EReinforcementGUICategory.EReinforcementGUICategory_Mod
                }, 
                {
                 UniqueName = "SFXGameContent.SFXWeaponMod_SMGDamage", 
                 GUIType = "smgmod", 
                 GUITextureRef = "GUI_Icons.Weapons.pst_bar_a_256x128", 
                 PoolName = "", 
                 UniqueId = 0, 
                 MaxCount = 5, 
                 GUIName = $519468, 
                 GUIDescription = $711324, 
                 GUIIconIndex = 0, 
                 PVIncrementBonus = 0, 
                 VersionIdx = 0, 
                 Category = 0, 
                 LevelAwarded = 0, 
                 StringToken = 0, 
                 CardOwner = None, 
                 Entitlement = -1, 
                 bUseVersionIdx = FALSE, 
                 Rarity = ECardRarity.Rarity_Uncommon, 
                 GUICategory = EReinforcementGUICategory.EReinforcementGUICategory_Mod
                }, 
                {
                 UniqueName = "SFXGameContent.SFXWeaponMod_AssaultRifleDamage", 
                 GUIType = "assaultmod", 
                 GUITextureRef = "GUI_Icons.Weapons.asl_bar_a_256x128", 
                 PoolName = "", 
                 UniqueId = 0, 
                 MaxCount = 5, 
                 GUIName = $518965, 
                 GUIDescription = $711329, 
                 GUIIconIndex = 0, 
                 PVIncrementBonus = 0, 
                 VersionIdx = 0, 
                 Category = 0, 
                 LevelAwarded = 0, 
                 StringToken = 0, 
                 CardOwner = None, 
                 Entitlement = -1, 
                 bUseVersionIdx = FALSE, 
                 Rarity = ECardRarity.Rarity_Uncommon, 
                 GUICategory = EReinforcementGUICategory.EReinforcementGUICategory_Mod
                }, 
                {
                 UniqueName = "SFXGameContent.SFXWeaponMod_AssaultRifleForce", 
                 GUIType = "assaultmod", 
                 GUITextureRef = "GUI_Icons.Weapons.MOD_penetration-mod_256x128", 
                 PoolName = "", 
                 UniqueId = 0, 
                 MaxCount = 5, 
                 GUIName = $518987, 
                 GUIDescription = $711332, 
                 GUIIconIndex = 0, 
                 PVIncrementBonus = 0, 
                 VersionIdx = 0, 
                 Category = 0, 
                 LevelAwarded = 0, 
                 StringToken = 0, 
                 CardOwner = None, 
                 Entitlement = -1, 
                 bUseVersionIdx = FALSE, 
                 Rarity = ECardRarity.Rarity_Uncommon, 
                 GUICategory = EReinforcementGUICategory.EReinforcementGUICategory_Mod
                }, 
                {
                 UniqueName = "SFXGameContent.SFXWeaponMod_ShotgunStability", 
                 GUIType = "shotgunmod", 
                 GUITextureRef = "GUI_Icons.Weapons.MOD_heat-sink_256x128", 
                 PoolName = "", 
                 UniqueId = 0, 
                 MaxCount = 5, 
                 GUIName = $519508, 
                 GUIDescription = $711335, 
                 GUIIconIndex = 0, 
                 PVIncrementBonus = 0, 
                 VersionIdx = 0, 
                 Category = 0, 
                 LevelAwarded = 0, 
                 StringToken = 0, 
                 CardOwner = None, 
                 Entitlement = -1, 
                 bUseVersionIdx = FALSE, 
                 Rarity = ECardRarity.Rarity_Uncommon, 
                 GUICategory = EReinforcementGUICategory.EReinforcementGUICategory_Mod
                }, 
                {
                 UniqueName = "SFXGameContent.SFXWeaponMod_ShotgunReloadSpeed", 
                 GUIType = "shotgunmod", 
                 GUITextureRef = "GUI_Icons.Weapons.MOD_shredder-mod_256x128", 
                 PoolName = "", 
                 UniqueId = 0, 
                 MaxCount = 5, 
                 GUIName = $519482, 
                 GUIDescription = $711337, 
                 GUIIconIndex = 0, 
                 PVIncrementBonus = 0, 
                 VersionIdx = 0, 
                 Category = 0, 
                 LevelAwarded = 0, 
                 StringToken = 0, 
                 CardOwner = None, 
                 Entitlement = -1, 
                 bUseVersionIdx = FALSE, 
                 Rarity = ECardRarity.Rarity_Uncommon, 
                 GUICategory = EReinforcementGUICategory.EReinforcementGUICategory_Mod
                }, 
                {
                 UniqueName = "SFXGameContent.SFXWeaponMod_SniperRifleAccuracy", 
                 GUIType = "snipermod", 
                 GUITextureRef = "GUI_Icons.Weapons.snp_sco_a_256x128", 
                 PoolName = "", 
                 UniqueId = 0, 
                 MaxCount = 5, 
                 GUIName = $519534, 
                 GUIDescription = $711338, 
                 GUIIconIndex = 0, 
                 PVIncrementBonus = 0, 
                 VersionIdx = 0, 
                 Category = 0, 
                 LevelAwarded = 0, 
                 StringToken = 0, 
                 CardOwner = None, 
                 Entitlement = -1, 
                 bUseVersionIdx = FALSE, 
                 Rarity = ECardRarity.Rarity_Uncommon, 
                 GUICategory = EReinforcementGUICategory.EReinforcementGUICategory_Mod
                }, 
                {
                 UniqueName = "SFXGameContent.SFXWeaponMod_SniperRifleConstraintDamage", 
                 GUIType = "snipermod", 
                 GUITextureRef = "GUI_Icons.Weapons.MOD_penetration-mod_256x128", 
                 PoolName = "", 
                 UniqueId = 0, 
                 MaxCount = 5, 
                 GUIName = $519550, 
                 GUIDescription = $711342, 
                 GUIIconIndex = 0, 
                 PVIncrementBonus = 0, 
                 VersionIdx = 0, 
                 Category = 0, 
                 LevelAwarded = 0, 
                 StringToken = 0, 
                 CardOwner = None, 
                 Entitlement = -1, 
                 bUseVersionIdx = FALSE, 
                 Rarity = ECardRarity.Rarity_Uncommon, 
                 GUICategory = EReinforcementGUICategory.EReinforcementGUICategory_Mod
                }, 
                {
                 UniqueName = "MPCapacity_Ammo", 
                 GUIType = "capacity", 
                 GUITextureRef = "GUI_MPImages.Cards.AddAmmo", 
                 PoolName = "", 
                 UniqueId = 0, 
                 MaxCount = 10, 
                 GUIName = $723382, 
                 GUIDescription = $723378, 
                 GUIIconIndex = 0, 
                 PVIncrementBonus = 0, 
                 VersionIdx = 0, 
                 Category = 0, 
                 LevelAwarded = 0, 
                 StringToken = 0, 
                 CardOwner = None, 
                 Entitlement = -1, 
                 bUseVersionIdx = FALSE, 
                 Rarity = ECardRarity.Rarity_Rare, 
                 GUICategory = EReinforcementGUICategory.EReinforcementGUICategory_None
                }, 
                {
                 UniqueName = "MPCapacity_Revive", 
                 GUIType = "capacity", 
                 GUITextureRef = "GUI_MPImages.Cards.AddRevive", 
                 PoolName = "", 
                 UniqueId = 0, 
                 MaxCount = 10, 
                 GUIName = $723385, 
                 GUIDescription = $723381, 
                 GUIIconIndex = 0, 
                 PVIncrementBonus = 0, 
                 VersionIdx = 0, 
                 Category = 0, 
                 LevelAwarded = 0, 
                 StringToken = 0, 
                 CardOwner = None, 
                 Entitlement = -1, 
                 bUseVersionIdx = FALSE, 
                 Rarity = ECardRarity.Rarity_Rare, 
                 GUICategory = EReinforcementGUICategory.EReinforcementGUICategory_None
                }, 
                {
                 UniqueName = "MPCapacity_Rocket", 
                 GUIType = "capacity", 
                 GUITextureRef = "GUI_MPImages.Cards.AddRockets", 
                 PoolName = "", 
                 UniqueId = 0, 
                 MaxCount = 10, 
                 GUIName = $723384, 
                 GUIDescription = $723380, 
                 GUIIconIndex = 0, 
                 PVIncrementBonus = 0, 
                 VersionIdx = 0, 
                 Category = 0, 
                 LevelAwarded = 0, 
                 StringToken = 0, 
                 CardOwner = None, 
                 Entitlement = -1, 
                 bUseVersionIdx = FALSE, 
                 Rarity = ECardRarity.Rarity_Rare, 
                 GUICategory = EReinforcementGUICategory.EReinforcementGUICategory_None
                }, 
                {
                 UniqueName = "MPCapacity_Shield", 
                 GUIType = "capacity", 
                 GUITextureRef = "GUI_MPImages.Cards.AddShield", 
                 PoolName = "", 
                 UniqueId = 0, 
                 MaxCount = 10, 
                 GUIName = $723383, 
                 GUIDescription = $723379, 
                 GUIIconIndex = 0, 
                 PVIncrementBonus = 0, 
                 VersionIdx = 0, 
                 Category = 0, 
                 LevelAwarded = 0, 
                 StringToken = 0, 
                 CardOwner = None, 
                 Entitlement = -1, 
                 bUseVersionIdx = FALSE, 
                 Rarity = ECardRarity.Rarity_Rare, 
                 GUICategory = EReinforcementGUICategory.EReinforcementGUICategory_None
                }, 
                {
                 UniqueName = "MPRespec", 
                 GUIType = "respec", 
                 GUITextureRef = "GUI_MPImages.Cards.Talent", 
                 PoolName = "", 
                 UniqueId = 0, 
                 MaxCount = 0, 
                 GUIName = $708848, 
                 GUIDescription = $0, 
                 GUIIconIndex = 0, 
                 PVIncrementBonus = 0, 
                 VersionIdx = 0, 
                 Category = 0, 
                 LevelAwarded = 0, 
                 StringToken = 0, 
                 CardOwner = None, 
                 Entitlement = -1, 
                 bUseVersionIdx = FALSE, 
                 Rarity = ECardRarity.Rarity_Rare, 
                 GUICategory = EReinforcementGUICategory.EReinforcementGUICategory_None
                }, 
                {
                 UniqueName = "MPCredits", 
                 GUIType = "bonus", 
                 GUITextureRef = "GUI_MPImages.Cards.Credits", 
                 PoolName = "", 
                 UniqueId = 0, 
                 MaxCount = 0, 
                 GUIName = $720016, 
                 GUIDescription = $720018, 
                 GUIIconIndex = 0, 
                 PVIncrementBonus = 0, 
                 VersionIdx = 0, 
                 Category = 0, 
                 LevelAwarded = 0, 
                 StringToken = 0, 
                 CardOwner = None, 
                 Entitlement = -1, 
                 bUseVersionIdx = FALSE, 
                 Rarity = ECardRarity.Rarity_Rare, 
                 GUICategory = EReinforcementGUICategory.EReinforcementGUICategory_None
                }
               )
    KnownConsumableTypes = (Class'SFXGAWReinforcementInGameConsumable', 
                            Class'SFXGAWReinforcementInventoryUnlock', 
                            Class'SFXGAWReinforcementMatchConsumable', 
                            Class'SFXGAWReinforcementMatchConsumable_NonGameplay', 
                            Class'SFXGAWReinforcementPermanentUpgrade', 
                            Class'SFXGAWReinforcementCredits', 
                            Class'SFXGAWReinforcementKitUnlock', 
                            Class'SFXGAWReinforcementUnsaved'
                           )
    fTimeoutRefreshDigitalRights = 60
    fTimeoutRefreshMPSaves = 60
    fTimeoutConsumeID = 60
    fTimeoutSaveMPRecord = 60
    PackPurchasedEntitlement = {}
}