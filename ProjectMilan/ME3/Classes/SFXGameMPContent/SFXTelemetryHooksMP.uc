Class SFXTelemetryHooksMP extends SFXTelemetryHooks
    transient
    config(Game);

// Functions
public static final function SendConsumable(Class<Object> ConsumableClass, int CurrentCharges, int UsedCount)
{
    local array<TelemetryAttribute> Attributes;
    local string ConsumableClassName;
    
    ConsumableClassName = Class'SFXTelemetry'.static.GenerateUniqueClassId(ConsumableClass);
    AddAttributeToArray(Attributes, 1, "name", ConsumableClassName);
    AddAttributeToArray(Attributes, 2, "curr", , CurrentCharges);
    AddAttributeToArray(Attributes, 2, "used", , UsedCount);
    SendArray('TelemetryHook_MP_Consumable', Attributes);
}
public static final function SendMPHostNew(bool Success)
{
    local array<TelemetryAttribute> Attributes;
    
    AddAttributeToArray(Attributes, 4, "succ", , , , Success);
    SendArray('TelemetryHook_MP_HostNew', Attributes);
}
public static final function SendPurchaseComplete(int Result)
{
    local array<TelemetryAttribute> Attributes;
    
    AddAttributeToArray(Attributes, 2, "resu", , Result);
    SendArray('TelemetryHook_PurchaseComplete', Attributes);
}
public static final function SendPurchaseOffer(int offerId)
{
    local array<TelemetryAttribute> Attributes;
    
    AddAttributeToArray(Attributes, 2, "offr", , offerId);
    SendArray('TelemetryHook_PurchaseOffer', Attributes);
}
public static final function SendReinforcementPackPurchase(SFXGAWReinforcementManager ReinforcementManager, int nPurchasedID, int nConsumableId, SFXSaveManagerMP Save, bool bInLobby)
{
    local array<TelemetryAttribute> Attributes;
    local int nCost;
    local int nOfferID;
    local int i;
    local string PackName;
    local bool bCredits;
    local int PlatformCost;
    
    PlatformCost = ReinforcementManager.GetPlatformCostValue(ReinforcementManager.StoreInfoArray[nPurchasedID].nID);
    nOfferID = ReinforcementManager.StoreInfoArray[nPurchasedID].offerId;
    PackName = ReinforcementManager.StoreInfoArray[nPurchasedID].PackName;
    nCost = ReinforcementManager.StoreInfoArray[nPurchasedID].CreditCost;
    if (nConsumableId < 0)
    {
        bCredits = TRUE;
    }
    else
    {
        Save.TotalPlatformCurrencySpent += PlatformCost;
        Save.SessionPlatformCurrencySpent += PlatformCost;
    }
    AddAttributeToArray(Attributes, 1, "pack", PackName);
    AddAttributeToArray(Attributes, 4, "ctyp", , , , bCredits);
    AddAttributeToArray(Attributes, 2, "cost", , nCost);
    AddAttributeToArray(Attributes, 2, "plat", , PlatformCost);
    AddAttributeToArray(Attributes, 2, "ofid", , nOfferID);
    AddAttributeToArray(Attributes, 4, "inlo", , , , bInLobby);
    AddAttributeToArray(Attributes, 2, "coid", , nConsumableId);
    AddAttributeToArray(Attributes, 2, "balc", , Save.AvailableCredits);
    AddAttributeToArray(Attributes, 2, "tocr", , Save.TotalCreditsSpent);
    AddAttributeToArray(Attributes, 2, "toca", , Save.TotalPlatformCurrencySpent);
    AddAttributeToArray(Attributes, 2, "secr", , Save.SessionCreditsSpent);
    AddAttributeToArray(Attributes, 2, "seca", , Save.SessionPlatformCurrencySpent);
    SendArray('TelemetryHook_RP_Purchased', Attributes);
    for (i = 0; i < ReinforcementManager.AwardedCards.Length; ++i)
    {
        SendReinforcementCardGranted(PackName, ReinforcementManager.AwardedCards[i].PoolName, 0, ReinforcementManager.AwardedCards[i].UniqueName, ReinforcementManager.AwardedCards[i].VersionIdx, ReinforcementManager.AwardedCards[i].PVIncrementBonus, ReinforcementManager.AwardedCards[i].Category);
    }
}
public static final function SendStoreClosed()
{
    local array<TelemetryAttribute> Attributes;
    local SFXTelemetryGameSession TelemetryGameSession;
    local WorldInfo WorldInfo;
    local SFXSaveManagerMP MPSaveManager;
    
    WorldInfo = Class'Engine'.static.GetCurrentWorldInfo();
    TelemetryGameSession = Class'SFXTelemetry'.static.GetInstanceGameSession();
    MPSaveManager = SFXEngine(Class'Engine'.static.GetEngine()).MPSaveManager;
    AddAttributeToArray(Attributes, 2, "dura", , int(WorldInfo.TimeSeconds - TelemetryGameSession.StoreOpenedTime));
    AddAttributeToArray(Attributes, 2, "stcr", , MPSaveManager.SessionCreditsSpent - TelemetryGameSession.StoreOpenCreditsSpent);
    AddAttributeToArray(Attributes, 2, "stca", , MPSaveManager.SessionPlatformCurrencySpent - TelemetryGameSession.StoreOpenCashSpent);
    SendArray('TelemetryHook_StoreClosed', Attributes);
}
public static final function SendStoreOpened(bool bInLobby, optional int PromotionalId = -1)
{
    local array<TelemetryAttribute> Attributes;
    local SFXTelemetryGameSession TelemetryGameSession;
    local WorldInfo WorldInfo;
    local SFXSaveManagerMP MPSaveManager;
    
    WorldInfo = Class'Engine'.static.GetCurrentWorldInfo();
    TelemetryGameSession = Class'SFXTelemetry'.static.GetInstanceGameSession();
    MPSaveManager = SFXEngine(Class'Engine'.static.GetEngine()).MPSaveManager;
    TelemetryGameSession.StoreOpenedTime = WorldInfo.TimeSeconds;
    TelemetryGameSession.StoreOpenCashSpent = MPSaveManager.SessionPlatformCurrencySpent;
    TelemetryGameSession.StoreOpenCreditsSpent = MPSaveManager.SessionCreditsSpent;
    AddAttributeToArray(Attributes, 4, "inlo", , , , bInLobby);
    AddAttributeToArray(Attributes, 2, "prom", , PromotionalId);
    SendArray('TelemetryHook_StoreOpened', Attributes);
}
public static final function SendSupplyDropGranted(SFXGAWReinforcementManager ReinforcementManager, int nSupplyDrop, int nPoolID)
{
    local array<TelemetryAttribute> Attributes;
    local int i;
    
    AddAttributeToArray(Attributes, 2, "drop", , nSupplyDrop);
    AddAttributeToArray(Attributes, 2, "sdpo", , nPoolID);
    SendArray('TelemetryHook_SupplyDrop_Pickup', Attributes);
    for (i = 0; i < ReinforcementManager.LastAwardedCards.Length; ++i)
    {
        SendReinforcementCardGranted("supplydrop", ReinforcementManager.LastAwardedCards[i].PoolName, 1, ReinforcementManager.LastAwardedCards[i].UniqueName, ReinforcementManager.LastAwardedCards[i].VersionIdx, ReinforcementManager.LastAwardedCards[i].PVIncrementBonus, ReinforcementManager.LastAwardedCards[i].Category);
    }
}
public static final function SendWaveComplete(int WaveNumber, string WaveTypeStr, bool WasObjectiveWave, int CreditsGranted, int SquadScore, int NumSupplyDropsRecd)
{
    local SFXTelemetryGameSession TelemetryGameSession;
    local array<TelemetryAttribute> Attributes;
    
    TelemetryGameSession = Class'SFXTelemetry'.static.GetInstanceGameSession();
    if (TelemetryGameSession != None)
    {
        AddAttributeToArray(Attributes, 2, "wave", , WaveNumber);
        AddAttributeToArray(Attributes, 1, "waty", WaveTypeStr);
        AddAttributeToArray(Attributes, 4, "objw", , , , WasObjectiveWave);
        AddAttributeToArray(Attributes, 2, "crdg", , CreditsGranted - TelemetryGameSession.TotalCredits);
        AddAttributeToArray(Attributes, 2, "scrg", , SquadScore - TelemetryGameSession.TotalScore);
        AddAttributeToArray(Attributes, 2, "sply", , NumSupplyDropsRecd - TelemetryGameSession.TotalSupplyDrops);
        SendArray('TelemetryHook_MPHOST_WaveComplete', Attributes);
        TelemetryGameSession.RoundID++;
        TelemetryGameSession.TotalCredits = CreditsGranted;
        TelemetryGameSession.TotalScore = SquadScore;
        TelemetryGameSession.TotalSupplyDrops = NumSupplyDropsRecd;
    }
    SendPlayersMuted();
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
}