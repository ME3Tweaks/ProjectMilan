Class SFXGUI_MPDirectBuyStore extends SFXGUIMovie
    native
    config(UI);

struct native GlobalStoreDiscount 
{
    var string PlayerVariable;
    var float DiscountStrength;
};
struct native ComparisonStat 
{
    var string StatName;
    var int StatBaseValue;
    var int StatBonusValue;
    var int StatCompValue;
};
struct native ModStrings 
{
    var string className;
    var array<float> Custom0Tokens;
    var array<float> Custom1Tokens;
    var stringref srModName;
    var stringref srModDescription;
};

var transient SFXGUIData_Store.StoreItemData ChosenStoreItem;
var transient array<SFXGUIData_Store.StoreItemData> StoreItems;
var transient array<SFXGUIData_Store.StoreItemData> UnsortedMPItems_Weapons;
var transient array<SFXGUIData_Store.StoreItemData> UnsortedMPItems_Mods;
var config string m_sResourceCostColorHTML_CanAfford;
var config string m_sResourceCostColorHTML_CantAfford;
var config string m_DefaultStoreHeaderImageRef;
var config array<SFXGUI_Store.ModStrings> ModStringsArray;
var array<SFXGUI_Store.ComparisonStat> CompStats;
var config array<SFXGUI_Store.GlobalStoreDiscount> GlobalStoreDiscounts;
var config array<int> WeaponUpgradeCosts;
var config array<int> RespecCosts;
var array<int> Achievement_UniqueArmorPlotIDs;
var BioPawn Customer;
var SFXGUIData_Store StoreGUIData;
var SFXGUIData_Store NestedStoreGUIData;
var BioSFHandler_MessageBox ConfirmationMessageBox;
var instanced SFXWeaponUIDataManager WeaponDataManager;
var int nPurchaseIndex;
var config stringref srPurchaseConfirm;
var config stringref srPurchaseCancel;
var config stringref srPurchaseConfirmMessage;
var config stringref srMoreInformation;
var config stringref srBack;
var config stringref srNewFlag;
var config stringref m_srResourceTextCredits;
var config stringref m_srResourceCostFormat;
var config stringref m_srResourceAvailFormat;
var config int m_nInfoScrollSpeed;
var config int DisplayCap_Mods;
var config int DisplayCap_Weapons;
var int ModPriorityModifier;
var int NewGamePlusID;
var int MaxWeaponLevel_Normal;
var int MaxWeaponLevel_NGP;
var int WeaponLevelIncrease_Normal;
var int WeaponLevelIncrease_NGP;
var stringref ArmorEffectDescriptionFormatter;
var config bool bAllItemsUnlocked;
var transient bool bIsFinished;
var transient bool bIsAborted;
var transient bool bWasPaused;
var transient bool bIsFlashLoaded;
var transient bool bUIIsInitialized;
var transient bool m_bStopScroll;
var transient bool bMessageBoxActivated;
var bool bResetTalents;
var bool bInNestedStore;

public event function ASAddChoiceEntry(int p_index, string p_ChoiceName, string p_ChoiceTitle, string p_ChoiceImageTitle, string p_ChoiceDescription, string p_ChoiceOptionalPanelItemValue, int p_ChoiceColor, int p_ChoiceResource, string p_ActionText, string p_ImagePath, bool p_DefaultSelection, bool p_Disabled, SFXGameChoiceGUIData.EChoiceDisplayType p_DisplayType, string p_Stat1Name, int p_Stat1Base, int p_Stat1Bonus, int p_Stat1Comp, string p_Stat2Name, int p_Stat2Base, int p_Stat2Bonus, int p_Stat2Comp, string p_Stat3Name, int p_Stat3Base, int p_Stat3Bonus, int p_Stat3Comp, string p_Stat4Name, int p_Stat4Base, int p_Stat4Bonus, int p_Stat4Comp, string p_Stat5Name, int p_Stat5Base, int p_Stat5Bonus, int p_Stat5Comp)
{
    ActionScriptVoid("StoreStage.addChoiceEntry");
}
public event function ASRefreshChoiceEntry(int p_index, string p_ChoiceName, string p_ChoiceTitle, string p_ChoiceImageTitle, string p_ChoiceDescription, string p_ChoiceOptionalPanelItemValue, int p_ChoiceColor, int p_ChoiceResource, string p_ActionText, string p_ImagePath, bool p_DefaultSelection, bool p_Disabled, SFXGameChoiceGUIData.EChoiceDisplayType p_DisplayType, string p_Stat1Name, int p_Stat1Base, int p_Stat1Bonus, int p_Stat1Comp, string p_Stat2Name, int p_Stat2Base, int p_Stat2Bonus, int p_Stat2Comp, string p_Stat3Name, int p_Stat3Base, int p_Stat3Bonus, int p_Stat3Comp, string p_Stat4Name, int p_Stat4Base, int p_Stat4Bonus, int p_Stat4Comp, string p_Stat5Name, int p_Stat5Base, int p_Stat5Bonus, int p_Stat5Comp)
{
    ActionScriptVoid("StoreStage.refreshChoiceEntry");
}
public event function ASSetInitialListSize(int p_numItems)
{
    ActionScriptVoid("StoreStage.SetInitialListSize");
}
public event function ASSetPlatformLayout(int iPlatformId)
{
    ActionScriptVoid("StoreStage.SetPlatformLayout");
}
public event function ASSetSelectionIndex(int p_index)
{
    ActionScriptVoid("StoreStage.SetSelectionIndex");
}
public event function ASSetTitles(string sTitle, string sSubtitle, string sAText, string sBText, string sYText, int nCreditsAvailable)
{
    ActionScriptVoid("StoreStage.SetTitles");
}
public event function stringref GetBButtonText()
{
    return bInNestedStore ? srBack : StoreGUIData.m_srBText;
}
public event function int GetResourceCount(int nResource)
{
    local BioPlayerController PC;
    local BioPawn pPawn;
    local BioDefine.EInventoryResourceTypes eResource;
    local int nValue;
    
    nValue = 0;
    if (nResource == -1)
    {
        return 0;
    }
    eResource = byte(nResource);
    if (oWorldInfo != None)
    {
        PC = oWorldInfo.GetLocalPlayerController();
        if (PC != None)
        {
            pPawn = BioPawn(PC.Pawn);
            if (pPawn != None)
            {
                nValue = SFXInventoryManager(pPawn.InvManager).GetResource(eResource);
            }
        }
    }
    return nValue;
}
public native function string GetResourceText(BioDefine.EInventoryResourceTypes eResource);

public event function bool GetWeaponDataStats(Name WeaponClassPath, out array<SFXGUI_Store.ComparisonStat> lstDisplayStats)
{
    local SFXGUI_Store.ComparisonStat WeaponStat;
    local SFXWeaponUIData.SFXWeaponSelectWeaponData StockWeaponData;
    local SFXWeaponUIData.SFXWeaponUIStats StockWeaponStatData;
    local SFXWeaponUIData.SFXWeaponUIStats InvWeaponStatData;
    local SFXWeapon InvWeapon;
    local int nStockWeaponUIDataIndex;
    local int nInvWeaponUIDataIndex;
    local float nBonus;
    
    if (Customer == None || SFXInventoryManager(Customer.InvManager) == None)
    {
        return FALSE;
    }
    StockWeaponData = WeaponDataManager.GetWeaponUIDataFromClassPath(WeaponClassPath, nStockWeaponUIDataIndex);
    if (nStockWeaponUIDataIndex == -1)
    {
        return FALSE;
    }
    StockWeaponStatData = WeaponDataManager.GetWeaponModValuesByClassName(WeaponClassPath, 'None');
    InvWeapon = SFXInventoryManager(Customer.InvManager).GetWeaponByCategory(StockWeaponData.Type, FALSE);
    if (InvWeapon == None)
    {
        return FALSE;
    }
    WeaponDataManager.GetWeaponUIDataFromClassPath(Name(PathName(InvWeapon.@Class)), nInvWeaponUIDataIndex);
    if (nInvWeaponUIDataIndex == -1)
    {
        return FALSE;
    }
    InvWeaponStatData = WeaponDataManager.GetWeaponModValuesByClassName(Name(PathName(InvWeapon.@Class)), 'None');
    lstDisplayStats.Length = 0;
    nBonus = 0.0;
    WeaponStat.StatName = UIStrRef(WeaponDataManager.StatNameAccuracy);
    WeaponStat.StatBaseValue = int(WeaponDataManager.GetWeaponUIStatValue(nStockWeaponUIDataIndex, 0, StockWeaponStatData, FALSE, nBonus));
    WeaponStat.StatBonusValue = int(nBonus);
    WeaponStat.StatCompValue = int(WeaponDataManager.GetWeaponUIStatValue(nInvWeaponUIDataIndex, 0, InvWeaponStatData, TRUE));
    lstDisplayStats.AddItem(WeaponStat);
    nBonus = 0.0;
    WeaponStat.StatName = UIStrRef(WeaponDataManager.StatNameDamage);
    WeaponStat.StatBaseValue = int(WeaponDataManager.GetWeaponUIStatValue(nStockWeaponUIDataIndex, 1, StockWeaponStatData, FALSE, nBonus));
    WeaponStat.StatBonusValue = int(nBonus);
    WeaponStat.StatCompValue = int(WeaponDataManager.GetWeaponUIStatValue(nInvWeaponUIDataIndex, 1, InvWeaponStatData, TRUE));
    lstDisplayStats.AddItem(WeaponStat);
    nBonus = 0.0;
    WeaponStat.StatName = UIStrRef(WeaponDataManager.StatNameFireRate);
    WeaponStat.StatBaseValue = int(WeaponDataManager.GetWeaponUIStatValue(nStockWeaponUIDataIndex, 2, StockWeaponStatData, FALSE, nBonus));
    WeaponStat.StatBonusValue = int(nBonus);
    WeaponStat.StatCompValue = int(WeaponDataManager.GetWeaponUIStatValue(nInvWeaponUIDataIndex, 2, InvWeaponStatData, TRUE));
    lstDisplayStats.AddItem(WeaponStat);
    nBonus = 0.0;
    WeaponStat.StatName = UIStrRef(WeaponDataManager.StatNameMagSize);
    WeaponStat.StatBaseValue = int(WeaponDataManager.GetWeaponUIStatValue(nStockWeaponUIDataIndex, 3, StockWeaponStatData, FALSE, nBonus));
    WeaponStat.StatBonusValue = int(nBonus);
    WeaponStat.StatCompValue = int(WeaponDataManager.GetWeaponUIStatValue(nInvWeaponUIDataIndex, 3, InvWeaponStatData, TRUE));
    lstDisplayStats.AddItem(WeaponStat);
    nBonus = 0.0;
    WeaponStat.StatName = UIStrRef(WeaponDataManager.StatNameWeight);
    WeaponStat.StatBaseValue = int(WeaponDataManager.GetWeaponUIStatValue(nStockWeaponUIDataIndex, 4, StockWeaponStatData, FALSE, nBonus));
    WeaponStat.StatBonusValue = int(nBonus);
    WeaponStat.StatCompValue = int(WeaponDataManager.GetWeaponUIStatValue(nInvWeaponUIDataIndex, 4, InvWeaponStatData, TRUE));
    lstDisplayStats.AddItem(WeaponStat);
    return TRUE;
}
public event function bool HandleInputEvent(BioDefine.BioGuiEvents Event, optional float fValue = 1.0)
{
    switch (Event)
    {
        case BioGuiEvents.BIOGUI_EVENT_AXIS_RSTICK_Y:
            ScrollText(-fValue);
            break;
        default:
            return Super.HandleInputEvent(Event, fValue);
    }
    return TRUE;
}
public function Initialize(SFXGUIData_Store InitialStoreChoiceGUIData, Name StoreName, BioPawn PlayerPawn)
{
    local BioPlayerController PlayerController;
    local Class<SFXGUIData_Store> NestedStoreClass;
    local SFXGUIData_Store NestedStore;
    local int idx;
    
    if (PlayerPawn == None)
    {
        bIsAborted = TRUE;
        return;
    }
    Customer = PlayerPawn;
    if (Customer == None || Customer.Controller == None)
    {
        bIsAborted = TRUE;
        return;
    }
    PlayerController = BioPlayerController(Customer.Controller);
    if (PlayerController == None || PlayerController.GameModeManager2 == None)
    {
        bIsAborted = TRUE;
        return;
    }
    StoreGUIData = InitialStoreChoiceGUIData;
    if (StoreGUIData == None)
    {
        bIsAborted = TRUE;
        return;
    }
    SetGameMode(TRUE);
    if (bIsFlashLoaded)
    {
        WeaponDataManager.LoadData(OnWeaponUIDataLoaded);
    }
    if (StoreGUIData.MallStoreArray.Length <= 0)
    {
        for (idx = 0; idx < StoreGUIData.StoreItemArray.Length; idx++)
        {
            if (StoreGUIData.StoreItemArray[idx].ItemType != EItemType.TYPE_NESTEDCATEGORY)
            {
                continue;
            }
            NestedStoreClass = Class<SFXGUIData_Store>(Class'SFXEngine'.static.GetSeekFreeObject(StoreGUIData.StoreItemArray[idx].ItemClassName, Class'Class'));
            if (NestedStoreClass == None)
            {
                continue;
            }
            NestedStore = new (Self) NestedStoreClass;
            if (NestedStore == None)
            {
                continue;
            }
            StoreGUIData.MallStoreArray.AddItem(NestedStore);
        }
    }
}
public delegate function OnCloseCallback();

public event function OnStart()
{
    Super.OnStart();
    SetRequiresUIWorld(TRUE);
    PlayGuiSound('StoreOpen');
}
public native function PrepareStorefront(optional bool bInitFromScratch = TRUE);

public function ShutDown()
{
    local BioPlayerController PlayerController;
    local BioPlayerController oController;
    local SFXGUIInteraction oMgr;
    local SFXGUIMovie oNewPanel;
    
    if (Customer == None || Customer.Controller == None)
    {
        bIsAborted = TRUE;
        return;
    }
    PlayerController = BioPlayerController(Customer.Controller);
    if (PlayerController == None || PlayerController.GameModeManager2 == None)
    {
        bIsAborted = TRUE;
        return;
    }
    if (bIsFinished == FALSE && bIsAborted == FALSE && OnCloseCallback != None)
    {
        OnCloseCallback();
    }
    OnCloseCallback = None;
    SetGameMode(FALSE);
    bIsFinished = TRUE;
    Close();
    if (bResetTalents)
    {
        oController = BioPlayerController(Customer.Controller);
        if (oController != None)
        {
            oMgr = Class'SFXGUIInteraction'.static.GetInstance();
            oNewPanel = oMgr.OpenMovie(oController, oMgr.MovieTag_SquadRecord, TRUE);
            if (oNewPanel != None)
            {
                oNewPanel.SetRequiresUIWorld(TRUE);
            }
        }
        bResetTalents = FALSE;
    }
}
public event function Update(float fDeltaT)
{
    Super.Update(fDeltaT);
    if (bUIIsInitialized == FALSE && WeaponDataManager.DataIsLoaded)
    {
        FinishStorePreparation();
        bUIIsInitialized = TRUE;
    }
}
public event function OnClose()
{
    PlayGuiSound('StoreClose');
    Super.OnClose();
}
public function AddBonusPower(Class<SFXPowerCustomAction> PowerClass)
{
    local SFXPowerCustomAction Power;
    local int Refund;
    local int Index;
    
    if (Customer.PowerManager != None)
    {
        Refund = 0;
        for (Index = Customer.PowerManager.Powers.Length - 1; Index >= 0; Index--)
        {
            Power = SFXPowerCustomAction(Customer.PowerManager.Powers[Index]);
            if (Power != None)
            {
                if (Power.IsBonusPower)
                {
                    Refund += Class'SFXPowerManager'.static.GetRefundAmount(Power.@Class, int(Power.Rank));
                    Customer.PowerManager.RemovePower(Power.@Class);
                }
            }
        }
        if (Refund > 0)
        {
            Customer.AddTalentPoints(Refund);
        }
        Power = SFXPowerCustomAction(Customer.PowerManager.AddPower(PowerClass));
        if (Power == None)
        {
            WarnInternal("Warning: Could not give bonus power to player.");
        }
        else
        {
            Power.OnPowersLoaded();
        }
    }
}
public function ASInitializationFinished()
{
    ActionScriptVoid("StoreStage.InitializationFinished");
}
public function ASScrollInfoText(float fValue)
{
    ActionScriptVoid("StoreStage.ScrollInfoText");
}
public function ASStopInfoScroll()
{
    ActionScriptVoid("StoreStage.StopInfoScroll");
}
public final function ConfirmationMessageBoxInputPressed(bool bAPressed, int nContext)
{
    local BioHintSystem HintSystem;
    local BioGlobalVariableTable PlotStateData;
    local Class<SFXPowerCustomAction> PowerClass;
    local BioPlayerController PlayerController;
    local SFXEngine Engine;
    local SFXInventoryManager PlayerInventory;
    local int idx;
    local int UniqueArmorCount;
    local int UniqueArmorPlotID;
    local string PV;
    local Class<SFXWeapon> WeaponClass;
    local Class<SFXWeaponMod> WeaponModClass;
    local BioWorldInfo WI;
    local BioGlobalVariableTable VarTable;
    local bool bAddedNotification;
    local SFXPawn_Player PlayerCustomer;
    
    if (Customer == None || Customer.Controller == None)
    {
        bIsAborted = TRUE;
        return;
    }
    PlayerController = BioPlayerController(Customer.Controller);
    if (PlayerController == None)
    {
        bIsAborted = TRUE;
        return;
    }
    Engine = SFXEngine(Class'Engine'.static.GetEngine());
    if (Engine == None)
    {
        bIsAborted = TRUE;
        return;
    }
    HintSystem = BioHintSystem(PlayerController.HintSystem);
    if (HintSystem == None)
    {
        bIsAborted = TRUE;
        return;
    }
    PlayerInventory = SFXInventoryManager(Customer.InvManager);
    if (PlayerInventory == None)
    {
        bIsAborted = TRUE;
        return;
    }
    PlotStateData = oWorldInfo.GetGlobalVariables();
    if (PlotStateData == None)
    {
        bIsAborted = TRUE;
        return;
    }
    WI = BioWorldInfo(Class'WorldInfo'.static.GetWorldInfo());
    if (WI == None)
    {
        bIsAborted = TRUE;
        return;
    }
    VarTable = WI.GetGlobalVariables();
    if (VarTable == None)
    {
        bIsAborted = TRUE;
        return;
    }
    if (bAPressed)
    {
        switch (ChosenStoreItem.ItemType)
        {
            case EItemType.TYPE_MOD:
                WeaponModClass = Class'SFXWeaponMod'.static.LoadModClass(ChosenStoreItem.ItemClassName);
                if (WeaponModClass != None)
                {
                    WeaponModClass.static.Upgrade(Customer);
                }
                bAddedNotification = TRUE;
                break;
            case EItemType.TYPE_WEAPON:
                WeaponClass = Class'SFXWeapon'.static.LoadWeaponClass(ChosenStoreItem.ItemClassName);
                if (WeaponClass != None)
                {
                    WeaponClass.static.Upgrade(SFXPawn_Player(Customer), WeaponClass);
                }
                bAddedNotification = TRUE;
                break;
            case EItemType.TYPE_POWER:
                PowerClass = FindPowerClass(ChosenStoreItem.ItemClassName);
                if (PowerClass == None)
                {
                    return;
                }
                AddBonusPower(PowerClass);
                break;
            case EItemType.TYPE_TALENTRESET:
                TalentResetHelper(ChosenStoreItem.ItemClassName);
                if (ChosenStoreItem.ItemClassName == "Shepard")
                {
                    bResetTalents = TRUE;
                }
                Engine.SetPlayerVariable(Name(ChosenStoreItem.ItemClassName $ "_RespecCount"), Engine.GetPlayerVariable(Name(ChosenStoreItem.ItemClassName $ "_RespecCount")) + 1);
                break;
            case EItemType.TYPE_INTELREWARD:
                bInNestedStore = FALSE;
                GrantIntelReward();
                break;
            case EItemType.TYPE_WEAPONUPGRADE:
                WeaponClass = Class'SFXWeapon'.static.LoadWeaponClass(ChosenStoreItem.ItemClassName);
                if (WeaponClass != None)
                {
                    WeaponClass.static.Upgrade(SFXPawn_Player(Customer), WeaponClass, FALSE, FALSE, TRUE);
                }
                bAddedNotification = TRUE;
                break;
            default:
        }
        if (!bAddedNotification)
        {
            HintSystem.AddNotification_StorePurchase(ChosenStoreItem.ChoiceEntry.sChoiceName, ChosenStoreItem.ChoiceEntry.sChoiceDescription, ChosenStoreItem.SmallImage);
        }
        PlayerInventory.Credits = PlayerInventory.Credits - ChosenStoreItem.ChoiceEntry.nOptionalPaneItemValue;
        for (idx = 0; idx < ChosenStoreItem.PlotPurchaseID.Length; idx++)
        {
            PlotStateData.SetBool(ChosenStoreItem.PlotPurchaseID[idx], TRUE, FALSE);
        }
        if (ChosenStoreItem.PlotPurchaseInt != 0)
        {
            PlotStateData.SetInt(ChosenStoreItem.PlotPurchaseInt, PlotStateData.GetInt(ChosenStoreItem.PlotPurchaseInt) + 1);
        }
        foreach ChosenStoreItem.PVsToIncrement(PV, )
        {
            Engine.SetPlayerVariable(Name(PV), Engine.GetPlayerVariable(Name(PV)) + 1);
        }
        if (ChosenStoreItem.ItemClassName == "Intel_MedicalUpgrade_Scars")
        {
            PlayerCustomer = SFXPawn_Player(Customer);
            if (PlayerCustomer != None)
            {
                PlayerCustomer.UpdateParameters();
            }
        }
        foreach Achievement_UniqueArmorPlotIDs(UniqueArmorPlotID, )
        {
            if (VarTable.GetBool(UniqueArmorPlotID) == TRUE)
            {
                UniqueArmorCount++;
            }
        }
        PlayerController.SetAccomplishmentProgression('ARMORCOUNT', UniqueArmorCount);
        PlayGuiSound('StoreBuyItem');
        RefreshStoreGUI();
    }
}
public function DiscoverStore()
{
    local BioGlobalVariableTable PlotStateData;
    local BioPlayerController PC;
    local BioWorldInfo BWI;
    
    PlotStateData = oWorldInfo.GetGlobalVariables();
    if (PlotStateData == None)
    {
        return;
    }
    if (StoreGUIData.DiscoveryID != 0 && PlotStateData.GetBool(StoreGUIData.DiscoveryID) != TRUE)
    {
        PlotStateData.SetBool(StoreGUIData.DiscoveryID, TRUE, FALSE);
        BWI = BioWorldInfo(Class'Engine'.static.GetCurrentWorldInfo());
        if (BWI != None)
        {
            PC = BWI.GetLocalPlayerController();
            if (PC != None)
            {
                PC.UnlockAccomplishment('Store');
            }
        }
    }
}
public final function ExBuy(int nListIndexSelected)
{
    local int idx;
    local string StorePathName;
    local string SearchName;
    
    if (bIsFinished)
    {
        return;
    }
    if (StoreGUIData == None)
    {
        return;
    }
    if (nListIndexSelected < StoreItems.Length)
    {
        ChosenStoreItem = StoreItems[nListIndexSelected];
        nPurchaseIndex = nListIndexSelected;
        if (ChosenStoreItem.ItemType == EItemType.TYPE_INTELSUMMARY)
        {
            return;
        }
        else if (ChosenStoreItem.ItemType == EItemType.TYPE_RETURN)
        {
            bInNestedStore = FALSE;
            RefreshStoreGUI();
        }
        else if (ChosenStoreItem.ItemType != EItemType.TYPE_NESTEDCATEGORY)
        {
            ShowConfirmationMessageBox();
        }
        else
        {
            for (idx = 0; idx < StoreGUIData.MallStoreArray.Length; idx++)
            {
                StorePathName = PathName(StoreGUIData.MallStoreArray[idx]);
                SearchName = Split(ChosenStoreItem.ItemClassName, ".", TRUE);
                if (Split(StorePathName, SearchName, TRUE) != StorePathName)
                {
                    bInNestedStore = TRUE;
                    NestedStoreGUIData = StoreGUIData.MallStoreArray[idx];
                    break;
                }
            }
            RefreshStoreGUI();
        }
    }
}
public function ExExitStore()
{
    if (!bInNestedStore)
    {
        bIsFinished = TRUE;
        if (OnCloseCallback != None)
        {
            OnCloseCallback();
        }
        else
        {
            ShutDown();
        }
    }
    else
    {
        bInNestedStore = FALSE;
        RefreshStoreGUI();
    }
}
public function ExPostLoad()
{
    if (!bIsFlashLoaded)
    {
        bIsFlashLoaded = TRUE;
        WeaponDataManager.LoadData(OnWeaponUIDataLoaded);
    }
}
private final function Class<SFXPowerCustomAction> FindPowerClass(string PowerClassString)
{
    return Class<SFXPowerCustomAction>(Class'SFXEngine'.static.GetSeekFreeObject(PowerClassString, Class'Class'));
}
public function FinishStorePreparation()
{
    DiscoverStore();
    StockStore();
    PrepareStorefront(TRUE);
    ASInitializationFinished();
}
public final function FlagNewItems()
{
    local SFXEngine MyEngine;
    local int idx;
    local bool bApplyFlag;
    local string NewChoiceName;
    
    MyEngine = SFXEngine(Class'Engine'.static.GetEngine());
    if (MyEngine == None)
    {
        return;
    }
    for (idx = 0; idx < StoreItems.Length; idx++)
    {
        bApplyFlag = FALSE;
        if (MyEngine.GetPlayerVariable(GetItemDisplayVariable(StoreItems[idx])) == 0)
        {
            MyEngine.SetPlayerVariable(GetItemDisplayVariable(StoreItems[idx]), -1);
            bApplyFlag = TRUE;
        }
        else if (MyEngine.GetPlayerVariable(GetItemDisplayVariable(StoreItems[idx])) == -1)
        {
            MyEngine.SetPlayerVariable(GetItemDisplayVariable(StoreItems[idx]), -2);
        }
        if (bApplyFlag)
        {
            ClearCustomTokens();
            SetCustomToken(0, StoreItems[idx].ChoiceEntry.sChoiceName);
            NewChoiceName = GetUIString(srNewFlag, TRUE);
            StoreItems[idx].ChoiceEntry.sChoiceName = NewChoiceName;
            StoreGUIData.lstChoices[idx].sChoiceName = NewChoiceName;
        }
    }
}
public final function string FloatToString(float Number)
{
    if (Number >= 1000.0)
    {
        return Left(string(Number), 6);
    }
    else if (Number >= 100.0)
    {
        return Left(string(Number), 5);
    }
    else if (Number >= 10.0)
    {
        return Left(string(Number), 4);
    }
    else
    {
        return Left(string(Number), 3);
    }
}
public function int GetCalculatedItemCost(int BaseCost)
{
    local int CalculatedCost;
    local int idx;
    local BioGlobalVariableTable PlotStateData;
    local SFXEngine MyEngine;
    
    CalculatedCost = BaseCost;
    PlotStateData = oWorldInfo.GetGlobalVariables();
    if (PlotStateData == None)
    {
        return CalculatedCost;
    }
    if (NestedStoreGUIData != None && NestedStoreGUIData.DiscountUnlockID > 0 && PlotStateData.GetBool(NestedStoreGUIData.DiscountUnlockID) == TRUE)
    {
        CalculatedCost -= int(float(BaseCost) * NestedStoreGUIData.DiscountPercent);
    }
    else if (NestedStoreGUIData != None && NestedStoreGUIData.DiscountUnlockID == -1)
    {
        CalculatedCost += int(float(BaseCost) * NestedStoreGUIData.MarkupPercent);
    }
    if (StoreGUIData.DiscountUnlockID > 0 && PlotStateData.GetBool(StoreGUIData.DiscountUnlockID) == TRUE)
    {
        CalculatedCost -= int(float(BaseCost) * StoreGUIData.DiscountPercent);
    }
    else if (StoreGUIData.DiscountUnlockID == -1)
    {
        CalculatedCost += int(float(BaseCost) * StoreGUIData.MarkupPercent);
    }
    MyEngine = SFXEngine(Class'Engine'.static.GetEngine());
    if (MyEngine != None)
    {
        for (idx = 0; idx < GlobalStoreDiscounts.Length; idx++)
        {
            if (MyEngine.GetPlayerVariable(Name(GlobalStoreDiscounts[idx].PlayerVariable)) > 0)
            {
                CalculatedCost -= int(float(BaseCost) * GlobalStoreDiscounts[idx].DiscountStrength);
            }
        }
    }
    return CalculatedCost;
}
public final function Name GetItemDisplayVariable(SFXGUIData_Store.StoreItemData ItemData)
{
    local Name NewItemDisplayVariable;
    
    if (ItemData.ItemType == EItemType.TYPE_POWER)
    {
        NewItemDisplayVariable = Name(ItemData.ItemClassName);
    }
    return NewItemDisplayVariable;
}
public final function string GetStoreHeaderImageRef()
{
    if (StoreGUIData.StoreHeaderImageRef == "")
    {
        return m_DefaultStoreHeaderImageRef;
    }
    return StoreGUIData.StoreHeaderImageRef;
}
private final function Texture2D GetStoreItemImage(string Path)
{
    local Texture2D Image;
    
    Image = Texture2D(FindObject(Path, Class'Texture2D'));
    if (Image == None)
    {
        Image = Texture2D(Class'SFXEngine'.static.GetSeekFreeObject(Path, Class'Texture2D'));
    }
    if (Image == None)
    {
        Image = Texture2D(Class'SFXEngine'.static.GetSeekFreeObject(StoreGUIData.DefaultImage, Class'Texture2D'));
    }
    return Image;
}
public final function GrantIntelReward()
{
    local SFXEngine Engine;
    local SFXPawn_Player PlayerCustomer;
    
    PlayerCustomer = SFXPawn_Player(Customer);
    if (PlayerCustomer == None)
    {
        return;
    }
    if (ChosenStoreItem.bIsGameEffect)
    {
        PlayerCustomer.ApplyPermanentPlayerGameEffect(Name(ChosenStoreItem.ItemClassName));
    }
    Engine = SFXEngine(Class'Engine'.static.GetEngine());
    if (Engine == None)
    {
        return;
    }
    Engine.SetPlayerVariable(Name(ChosenStoreItem.ItemClassName), 1);
}
public final function bool ItemIsNew(SFXGUIData_Store.StoreItemData ItemData)
{
    local SFXEngine MyEngine;
    
    MyEngine = SFXEngine(Class'Engine'.static.GetEngine());
    if (MyEngine == None)
    {
        return FALSE;
    }
    if (MyEngine.GetPlayerVariable(GetItemDisplayVariable(ItemData)) == 0)
    {
        return TRUE;
    }
    return FALSE;
}
public final function NestedStockStore()
{
    local SFXGUIData_Store.StoreItemData ItemData;
    local BioGlobalVariableTable PlotStateData;
    local bool bSkipItem;
    local BioDefine.CustomizableElement ArmorPart;
    local int ArmorIndex;
    local int IntelIdx;
    local int WeaponIdx;
    local int ModIdx;
    local int Rank;
    local SFXEngine Engine;
    local SFXInventoryManager PlayerInventory;
    local SFXPawn_Player pPawn;
    local SFXWeaponUIData.SFXWeaponSelectWeaponData WeaponData;
    local SFXWeaponUIData.SFXWeaponModData modData;
    local SFXPowerCustomActionBase Power;
    local array<string> ArmorEffects;
    local string ArmorDescription;
    local string IntelRewardDescription;
    local int nLevel;
    
    PlotStateData = oWorldInfo.GetGlobalVariables();
    if (PlotStateData == None)
    {
        bIsAborted = TRUE;
        return;
    }
    Engine = SFXEngine(Class'Engine'.static.GetEngine());
    if (Engine == None)
    {
        bIsAborted = TRUE;
        return;
    }
    PlayerInventory = SFXInventoryManager(Customer.InvManager);
    if (PlayerInventory == None)
    {
        bIsAborted = TRUE;
        return;
    }
    pPawn = SFXPawn_Player(Customer);
    if (pPawn == None)
    {
        bIsAborted = TRUE;
        return;
    }
    StoreItems.Length = 0;
    StoreGUIData.lstChoices.Length = 0;
    UnsortedMPItems_Mods.Length = 0;
    UnsortedMPItems_Weapons.Length = 0;
    StoreGUIData.m_srAText = NestedStoreGUIData.default.m_srAText;
    foreach NestedStoreGUIData.StoreItemArray(ItemData, )
    {
        bSkipItem = FALSE;
        if (bAllItemsUnlocked == FALSE && (ItemData.PlotUnlockID != 0 && PlotStateData.GetBool(ItemData.PlotUnlockID) == FALSE || ItemData.PlotUnlockConditionalID != 0 && oWorldInfo.CheckConditional(ItemData.PlotUnlockConditionalID) == FALSE))
        {
            continue;
        }
        switch (ItemData.ItemType)
        {
            case EItemType.TYPE_MOD:
                Rank = Engine.GetPlayerVariable(Name(ItemData.ItemClassName));
                if (Rank >= Class'SFXWeaponMod'.default.MAX_RANK)
                {
                    bSkipItem = TRUE;
                    break;
                }
                modData = WeaponDataManager.GetWeaponModUIDataFromClassName(Name(ItemData.ItemClassName), ModIdx);
                nLevel = Engine.GetPlayerVariable(Name(ItemData.ItemClassName)) + 1;
                ItemData.ChoiceEntry.sChoiceName = WeaponDataManager.GetModDisplayName(ModIdx, nLevel);
                ItemData.ChoiceEntry.sChoiceDescription = WeaponDataManager.GetModDescription(ModIdx, nLevel);
                ItemData.ChoiceEntry.oChoiceImage = modData.LargeImage;
                break;
            case EItemType.TYPE_POWER:
                foreach pPawn.PowerManager.Powers(Power, )
                {
                    if (PathName(Power) == ItemData.ItemClassName)
                    {
                        bSkipItem = TRUE;
                        break;
                    }
                }
                ItemData.ChoiceEntry.sChoiceName = string(ItemData.ChoiceEntry.srChoiceName);
                ItemData.ChoiceEntry.sChoiceDescription = string(ItemData.ChoiceEntry.srChoiceDescription);
                break;
            case EItemType.TYPE_MEDIGEL:
                ClearCustomTokens();
                SetCustomToken(0, Class'SFXWeaponUIDataManager'.static.GetRomanNumeral(int(ItemData.Value)));
                ItemData.ChoiceEntry.sChoiceName = GetUIString(ItemData.ChoiceEntry.srChoiceName, TRUE);
                ClearCustomTokens();
                SetCustomToken(0, string(1));
                ItemData.ChoiceEntry.sChoiceDescription = GetUIString(ItemData.ChoiceEntry.srChoiceDescription, TRUE);
                break;
            case EItemType.TYPE_UNIQUEARMOR:
                ItemData.ChoiceEntry.sChoiceName = string(ItemData.ChoiceEntry.srChoiceName);
                ArmorEffects[0] = ItemData.ItemClassName;
                ArmorDescription = pPawn.GetArmorEffectDescription(ArmorEffects);
                ClearCustomTokens();
                SetCustomToken(0, ArmorDescription);
                SetCustomToken(1, string(ItemData.ChoiceEntry.srChoiceDescription));
                ItemData.ChoiceEntry.sChoiceDescription = GetUIString(ArmorEffectDescriptionFormatter, TRUE);
                ClearCustomTokens();
                break;
            case EItemType.TYPE_HELMET:
                ArmorIndex = Class'SFXPlayerCustomization'.default.HelmetAppearances.Find('Id', ItemData.ArmorID);
                if (ArmorIndex != -1)
                {
                    ArmorPart = Class'SFXPlayerCustomization'.default.HelmetAppearances[ArmorIndex];
                }
                ItemData.ChoiceEntry.sChoiceName = string(ItemData.ChoiceEntry.srChoiceName);
                ArmorDescription = pPawn.GetArmorEffectDescription(ArmorPart.GameEffects);
                ClearCustomTokens();
                SetCustomToken(0, ArmorDescription);
                SetCustomToken(1, string(ItemData.ChoiceEntry.srChoiceDescription));
                ItemData.ChoiceEntry.sChoiceDescription = GetUIString(ArmorEffectDescriptionFormatter, TRUE);
                ClearCustomTokens();
                break;
            case EItemType.TYPE_TORSO:
                ArmorIndex = Class'SFXPlayerCustomization'.default.TorsoAppearances.Find('Id', ItemData.ArmorID);
                if (ArmorIndex != -1)
                {
                    ArmorPart = Class'SFXPlayerCustomization'.default.TorsoAppearances[ArmorIndex];
                }
                ItemData.ChoiceEntry.sChoiceName = string(ItemData.ChoiceEntry.srChoiceName);
                ArmorDescription = pPawn.GetArmorEffectDescription(ArmorPart.GameEffects);
                ClearCustomTokens();
                SetCustomToken(0, ArmorDescription);
                SetCustomToken(1, string(ItemData.ChoiceEntry.srChoiceDescription));
                ItemData.ChoiceEntry.sChoiceDescription = GetUIString(ArmorEffectDescriptionFormatter, TRUE);
                ClearCustomTokens();
                break;
            case EItemType.TYPE_SHOULDERS:
                ArmorIndex = Class'SFXPlayerCustomization'.default.ShoulderAppearances.Find('Id', ItemData.ArmorID);
                if (ArmorIndex != -1)
                {
                    ArmorPart = Class'SFXPlayerCustomization'.default.ShoulderAppearances[ArmorIndex];
                }
                ItemData.ChoiceEntry.sChoiceName = string(ItemData.ChoiceEntry.srChoiceName);
                ArmorDescription = pPawn.GetArmorEffectDescription(ArmorPart.GameEffects);
                ClearCustomTokens();
                SetCustomToken(0, ArmorDescription);
                SetCustomToken(1, string(ItemData.ChoiceEntry.srChoiceDescription));
                ItemData.ChoiceEntry.sChoiceDescription = GetUIString(ArmorEffectDescriptionFormatter, TRUE);
                ClearCustomTokens();
                break;
            case EItemType.TYPE_LEGS:
                ArmorIndex = Class'SFXPlayerCustomization'.default.LegAppearances.Find('Id', ItemData.ArmorID);
                if (ArmorIndex != -1)
                {
                    ArmorPart = Class'SFXPlayerCustomization'.default.LegAppearances[ArmorIndex];
                }
                ItemData.ChoiceEntry.sChoiceName = string(ItemData.ChoiceEntry.srChoiceName);
                ArmorDescription = pPawn.GetArmorEffectDescription(ArmorPart.GameEffects);
                ClearCustomTokens();
                SetCustomToken(0, ArmorDescription);
                SetCustomToken(1, string(ItemData.ChoiceEntry.srChoiceDescription));
                ItemData.ChoiceEntry.sChoiceDescription = GetUIString(ArmorEffectDescriptionFormatter, TRUE);
                ClearCustomTokens();
                break;
            case EItemType.TYPE_ARMS:
                ArmorIndex = Class'SFXPlayerCustomization'.default.ArmAppearances.Find('Id', ItemData.ArmorID);
                if (ArmorIndex != -1)
                {
                    ArmorPart = Class'SFXPlayerCustomization'.default.ArmAppearances[ArmorIndex];
                }
                ItemData.ChoiceEntry.sChoiceName = string(ItemData.ChoiceEntry.srChoiceName);
                ArmorDescription = pPawn.GetArmorEffectDescription(ArmorPart.GameEffects);
                ClearCustomTokens();
                SetCustomToken(0, ArmorDescription);
                SetCustomToken(1, string(ItemData.ChoiceEntry.srChoiceDescription));
                ItemData.ChoiceEntry.sChoiceDescription = GetUIString(ArmorEffectDescriptionFormatter, TRUE);
                ClearCustomTokens();
                break;
            case EItemType.TYPE_WEAPON:
                Rank = Engine.GetPlayerVariable(Name(ItemData.ItemClassName));
                if (float(Rank) >= Class'SFXWeapon'.default.MaxLevel)
                {
                    bSkipItem = TRUE;
                    break;
                }
                ClearCustomTokens();
                SetCustomToken(0, Class'SFXWeaponUIDataManager'.static.GetRomanNumeral(Engine.GetPlayerVariable(Name(ItemData.ItemClassName)) + 1));
                WeaponData = WeaponDataManager.GetWeaponUIDataFromClassPath(Name(ItemData.ItemClassName), WeaponIdx);
                ItemData.ChoiceEntry.sChoiceName = GetUIString(WeaponData.Name, TRUE);
                ClearCustomTokens();
                ItemData.ChoiceEntry.oChoiceImage = WeaponData.Image;
                ItemData.ChoiceEntry.sChoiceDescription = string(WeaponData.Description);
                break;
            case EItemType.TYPE_INTELREWARD:
                ItemData.ChoiceEntry.sChoiceName = string(ItemData.ChoiceEntry.srChoiceName);
                ClearCustomTokens();
                IntelIdx = pPawn.PermanentGameEffects.Find('UniqueName', ItemData.ItemClassName);
                if (IntelIdx != -1)
                {
                    SetCustomToken(0, string(int(Abs(pPawn.PermanentGameEffects[IntelIdx].Value) * 100.0)));
                }
                else
                {
                    IntelIdx = GlobalStoreDiscounts.Find('PlayerVariable', ItemData.ItemClassName);
                    if (IntelIdx != -1)
                    {
                        SetCustomToken(0, string(int(GlobalStoreDiscounts[IntelIdx].DiscountStrength * 100.0)));
                    }
                    else
                    {
                        SetCustomToken(0, "0");
                    }
                }
                SetCustomToken(1, "");
                IntelRewardDescription = GetUIString(ItemData.ChoiceEntry.srChoiceDescription, TRUE);
                if (ItemData.CustomTokens.Length > 0 && ItemData.CustomTokens[0] != 0)
                {
                    ClearCustomTokens();
                    SetCustomToken(0, IntelRewardDescription);
                    SetCustomToken(1, string(ItemData.CustomTokens[0]));
                    IntelRewardDescription = GetUIString(ArmorEffectDescriptionFormatter, TRUE);
                    ClearCustomTokens();
                }
                ItemData.ChoiceEntry.sChoiceDescription = IntelRewardDescription;
                break;
            default:
                ItemData.ChoiceEntry.sChoiceName = string(ItemData.ChoiceEntry.srChoiceName);
                ItemData.ChoiceEntry.sChoiceDescription = string(ItemData.ChoiceEntry.srChoiceDescription);
        }
        if (bSkipItem)
        {
            continue;
        }
        if (ItemData.ItemType != EItemType.TYPE_WEAPONUPGRADE && ItemData.ItemType != EItemType.TYPE_WEAPON && ItemData.ItemType != EItemType.TYPE_MOD)
        {
            ItemData.ChoiceEntry.oChoiceImage = GetStoreItemImage(ItemData.LargeImage);
        }
        ItemData.ChoiceEntry.nOptionalPaneItemValue = GetCalculatedItemCost(ItemData.BaseCost);
        ItemData.ChoiceEntry.bDisabled = ShouldItemBeDisabled(ItemData);
        StoreGUIData.lstChoices.AddItem(ItemData.ChoiceEntry);
        StoreItems.AddItem(ItemData);
    }
    if (StoreGUIData.lstChoices.Length == 0)
    {
        OutOfStock();
    }
}
public function onScreenClosed()
{
    local BioPlayerController oController;
    local SFXGUIInteraction oMgr;
    
    oController = BioPlayerController(Customer.Controller);
    if (oController != None)
    {
        oMgr = Class'SFXGUIInteraction'.static.GetInstance();
        if (oMgr != None)
        {
            oMgr.RemoveMovie(oController, oMgr.MovieTag_SquadRecord);
        }
    }
}
public function OnWeaponUIDataLoaded();

public final function OutOfStock()
{
    local SFXGameChoiceGUIData.SFXChoiceEntry ChoiceEntry;
    
    if (StoreGUIData == None)
    {
        return;
    }
    ChoiceEntry.bDisabled = TRUE;
    ChoiceEntry.srChoiceName = StoreGUIData.srOutOfStock;
    ChoiceEntry.srChoiceTitle = StoreGUIData.srOutOfStock;
    ChoiceEntry.oChoiceImage = GetStoreItemImage(StoreGUIData.DefaultImage);
    if (StoreGUIData.srOutOfStockDescription != 0)
    {
        ChoiceEntry.srChoiceDescription = StoreGUIData.srOutOfStockDescription;
    }
    StoreGUIData.lstChoices.AddItem(ChoiceEntry);
}
public final function RefreshStoreGUI()
{
    local BioPlayerController PlayerController;
    
    if (StoreGUIData == None)
    {
        bIsAborted = TRUE;
        return;
    }
    if (Customer == None || Customer.Controller == None)
    {
        bIsAborted = TRUE;
        return;
    }
    PlayerController = BioPlayerController(Customer.Controller);
    if (PlayerController == None)
    {
        bIsAborted = TRUE;
        return;
    }
    if (bInNestedStore)
    {
        NestedStockStore();
    }
    else
    {
        StockStore();
    }
    PrepareStorefront(TRUE);
}
public function ScrollText(float fValue)
{
    if (Abs(fValue) <= 0.0000999999975)
    {
        if (m_bStopScroll)
        {
            ASStopInfoScroll();
            m_bStopScroll = FALSE;
        }
        return;
    }
    ASScrollInfoText(fValue * float(m_nInfoScrollSpeed));
    m_bStopScroll = TRUE;
}
public function SetOnCloseCallback(delegate<SFXGUI_Store.OnCloseCallback> fn_OnCloseDelegate)
{
    OnCloseCallback = fn_OnCloseDelegate;
}
public function bool ShouldItemBeDisabled(SFXGUIData_Store.StoreItemData ItemData)
{
    local SFXInventoryManager PlayerInventory;
    local bool bUnpurchasable;
    
    bUnpurchasable = TRUE;
    PlayerInventory = SFXInventoryManager(Customer.InvManager);
    if (PlayerInventory == None)
    {
        bIsAborted = TRUE;
        return bUnpurchasable;
    }
    if (PlayerInventory.Credits >= ItemData.ChoiceEntry.nOptionalPaneItemValue)
    {
        bUnpurchasable = FALSE;
    }
    return bUnpurchasable;
}
public function ShowConfirmationMessageBox()
{
    local BioDefine.BioMessageBoxOptionalParams stParams;
    local BioPlayerController PlayerController;
    local SFXInventoryManager PlayerInventory;
    local string ConfirmationMessage;
    
    if (Customer == None || Customer.Controller == None)
    {
        bIsAborted = TRUE;
        return;
    }
    PlayerController = BioPlayerController(Customer.Controller);
    if (PlayerController == None)
    {
        bIsAborted = TRUE;
        return;
    }
    PlayerInventory = SFXInventoryManager(Customer.InvManager);
    if (PlayerInventory == None)
    {
        bIsAborted = TRUE;
        return;
    }
    if (PlayerInventory.Credits < ChosenStoreItem.ChoiceEntry.nOptionalPaneItemValue)
    {
        bIsAborted = TRUE;
        return;
    }
    if (PlayerInventory.Credits >= ChosenStoreItem.ChoiceEntry.nOptionalPaneItemValue)
    {
        ClearCustomTokens();
        SetCustomToken(0, ChosenStoreItem.ChoiceEntry.sChoiceName);
        SetCustomToken(1, string(ChosenStoreItem.ChoiceEntry.nOptionalPaneItemValue));
        ConfirmationMessageBox = PlayerController.GetSFXUIController().CreateMessageBox(PlayerController);
        if (ConfirmationMessageBox == None)
        {
            bIsAborted = TRUE;
            return;
        }
        ConfirmationMessageBox.SetInputDelegate(ConfirmationMessageBoxInputPressed);
        if (StoreGUIData.ConfirmationMessageATextOverride != 0)
        {
            stParams.srAText = StoreGUIData.ConfirmationMessageATextOverride;
        }
        else
        {
            stParams.srAText = srPurchaseConfirm;
        }
        stParams.srBText = srPurchaseCancel;
        stParams.bNoFade = TRUE;
        if (StoreGUIData.bUseChoiceNameAsConfirmationMessage == TRUE)
        {
            ConfirmationMessage = ChosenStoreItem.ChoiceEntry.sChoiceName;
        }
        else
        {
            ConfirmationMessage = string(srPurchaseConfirmMessage);
        }
        ConfirmationMessageBox.DisplayMessageBoxEx(ConfirmationMessage, stParams);
        bMessageBoxActivated = TRUE;
    }
}
public final function StockStore()
{
    local SFXGUIData_Store.StoreItemData ItemData;
    local BioGlobalVariableTable PlotStateData;
    local bool bSkipItem;
    local bool bWeaponFoundNGP;
    local BioDefine.CustomizableElement ArmorPart;
    local int ArmorIndex;
    local int WeaponLevel;
    local int CostIndexModifier;
    local int MaxWeaponLevel;
    local int idx;
    local int NestedIdx;
    local int IntelIdx;
    local int WeaponIdx;
    local int ModIdx;
    local int RespecCostIdx;
    local int Rank;
    local SFXEngine Engine;
    local SFXInventoryManager PlayerInventory;
    local string IntelSummary;
    local string ArmorDescription;
    local string PowerClassPath;
    local SFXPawn_Player pPawn;
    local SFXWeaponUIData.SFXWeaponSelectWeaponData WeaponData;
    local SFXWeaponUIData.SFXWeaponModData modData;
    local SFXPowerCustomActionBase Power;
    local array<string> ArmorEffects;
    local int nLevel;
    
    PlotStateData = oWorldInfo.GetGlobalVariables();
    if (PlotStateData == None)
    {
        bIsAborted = TRUE;
        return;
    }
    Engine = SFXEngine(Class'Engine'.static.GetEngine());
    if (Engine == None)
    {
        bIsAborted = TRUE;
        return;
    }
    PlayerInventory = SFXInventoryManager(Customer.InvManager);
    if (PlayerInventory == None)
    {
        bIsAborted = TRUE;
        return;
    }
    pPawn = SFXPawn_Player(Customer);
    if (pPawn == None)
    {
        bIsAborted = TRUE;
        return;
    }
    StoreItems.Length = 0;
    StoreGUIData.lstChoices.Length = 0;
    UnsortedMPItems_Mods.Length = 0;
    UnsortedMPItems_Weapons.Length = 0;
    StoreGUIData.m_srAText = StoreGUIData.default.m_srAText;
    foreach StoreGUIData.StoreItemArray(ItemData, )
    {
        bSkipItem = FALSE;
        if (bAllItemsUnlocked == FALSE && (ItemData.PlotUnlockID != 0 && PlotStateData.GetBool(ItemData.PlotUnlockID) == FALSE || ItemData.PlotUnlockConditionalID != 0 && oWorldInfo.CheckConditional(ItemData.PlotUnlockConditionalID) == FALSE))
        {
            continue;
        }
        switch (ItemData.ItemType)
        {
            case EItemType.TYPE_TALENTRESET:
                RespecCostIdx = Engine.GetPlayerVariable(Name(ItemData.ItemClassName $ "_RespecCount"));
                RespecCostIdx = Min(RespecCostIdx, RespecCosts.Length - 1);
                ItemData.ChoiceEntry.nOptionalPaneItemValue = GetCalculatedItemCost(RespecCosts[RespecCostIdx]);
                ItemData.ChoiceEntry.sChoiceName = string(ItemData.ChoiceEntry.srChoiceName);
                ItemData.ChoiceEntry.sChoiceDescription = string(ItemData.ChoiceEntry.srChoiceDescription);
                break;
            case EItemType.TYPE_MOD:
                Rank = Engine.GetPlayerVariable(Name(ItemData.ItemClassName));
                if (Rank >= Class'SFXWeaponMod'.default.MAX_RANK)
                {
                    bSkipItem = TRUE;
                    break;
                }
                modData = WeaponDataManager.GetWeaponModUIDataFromClassName(Name(ItemData.ItemClassName), ModIdx);
                nLevel = Engine.GetPlayerVariable(Name(ItemData.ItemClassName)) + 1;
                ItemData.ChoiceEntry.sChoiceName = WeaponDataManager.GetModDisplayName(ModIdx, nLevel);
                ItemData.ChoiceEntry.sChoiceDescription = WeaponDataManager.GetModDescription(ModIdx, nLevel);
                ItemData.ChoiceEntry.oChoiceImage = modData.LargeImage;
                break;
            case EItemType.TYPE_POWER:
                foreach pPawn.PowerManager.Powers(Power, )
                {
                    PowerClassPath = PathName(Power.@Class);
                    if (PowerClassPath == ItemData.ItemClassName)
                    {
                        bSkipItem = TRUE;
                        break;
                    }
                }
                ItemData.ChoiceEntry.sChoiceName = string(ItemData.ChoiceEntry.srChoiceName);
                ItemData.ChoiceEntry.sChoiceDescription = string(ItemData.ChoiceEntry.srChoiceDescription);
                break;
            case EItemType.TYPE_MEDIGEL:
                ClearCustomTokens();
                SetCustomToken(0, Class'SFXWeaponUIDataManager'.static.GetRomanNumeral(int(ItemData.Value)));
                ItemData.ChoiceEntry.sChoiceName = GetUIString(ItemData.ChoiceEntry.srChoiceName, TRUE);
                ClearCustomTokens();
                SetCustomToken(0, string(1));
                ItemData.ChoiceEntry.sChoiceDescription = GetUIString(ItemData.ChoiceEntry.srChoiceDescription, TRUE);
                break;
            case EItemType.TYPE_UNIQUEARMOR:
                ItemData.ChoiceEntry.sChoiceName = string(ItemData.ChoiceEntry.srChoiceName);
                ArmorEffects[0] = ItemData.ItemClassName;
                ArmorDescription = pPawn.GetArmorEffectDescription(ArmorEffects);
                ClearCustomTokens();
                SetCustomToken(0, ArmorDescription);
                SetCustomToken(1, string(ItemData.ChoiceEntry.srChoiceDescription));
                ItemData.ChoiceEntry.sChoiceDescription = GetUIString(ArmorEffectDescriptionFormatter, TRUE);
                ClearCustomTokens();
                break;
            case EItemType.TYPE_HELMET:
                ArmorIndex = Class'SFXPlayerCustomization'.default.HelmetAppearances.Find('Id', ItemData.ArmorID);
                if (ArmorIndex != -1)
                {
                    ArmorPart = Class'SFXPlayerCustomization'.default.HelmetAppearances[ArmorIndex];
                }
                ItemData.ChoiceEntry.sChoiceName = string(ItemData.ChoiceEntry.srChoiceName);
                ArmorDescription = pPawn.GetArmorEffectDescription(ArmorPart.GameEffects);
                ClearCustomTokens();
                SetCustomToken(0, ArmorDescription);
                SetCustomToken(1, string(ItemData.ChoiceEntry.srChoiceDescription));
                ItemData.ChoiceEntry.sChoiceDescription = GetUIString(ArmorEffectDescriptionFormatter, TRUE);
                ClearCustomTokens();
                break;
            case EItemType.TYPE_TORSO:
                ArmorIndex = Class'SFXPlayerCustomization'.default.TorsoAppearances.Find('Id', ItemData.ArmorID);
                if (ArmorIndex != -1)
                {
                    ArmorPart = Class'SFXPlayerCustomization'.default.TorsoAppearances[ArmorIndex];
                }
                ItemData.ChoiceEntry.sChoiceName = string(ItemData.ChoiceEntry.srChoiceName);
                ArmorDescription = pPawn.GetArmorEffectDescription(ArmorPart.GameEffects);
                ClearCustomTokens();
                SetCustomToken(0, ArmorDescription);
                SetCustomToken(1, string(ItemData.ChoiceEntry.srChoiceDescription));
                ItemData.ChoiceEntry.sChoiceDescription = GetUIString(ArmorEffectDescriptionFormatter, TRUE);
                ClearCustomTokens();
                break;
            case EItemType.TYPE_SHOULDERS:
                ArmorIndex = Class'SFXPlayerCustomization'.default.ShoulderAppearances.Find('Id', ItemData.ArmorID);
                if (ArmorIndex != -1)
                {
                    ArmorPart = Class'SFXPlayerCustomization'.default.ShoulderAppearances[ArmorIndex];
                }
                ItemData.ChoiceEntry.sChoiceName = string(ItemData.ChoiceEntry.srChoiceName);
                ArmorDescription = pPawn.GetArmorEffectDescription(ArmorPart.GameEffects);
                ClearCustomTokens();
                SetCustomToken(0, ArmorDescription);
                SetCustomToken(1, string(ItemData.ChoiceEntry.srChoiceDescription));
                ItemData.ChoiceEntry.sChoiceDescription = GetUIString(ArmorEffectDescriptionFormatter, TRUE);
                ClearCustomTokens();
                break;
            case EItemType.TYPE_LEGS:
                ArmorIndex = Class'SFXPlayerCustomization'.default.LegAppearances.Find('Id', ItemData.ArmorID);
                if (ArmorIndex != -1)
                {
                    ArmorPart = Class'SFXPlayerCustomization'.default.LegAppearances[ArmorIndex];
                }
                ItemData.ChoiceEntry.sChoiceName = string(ItemData.ChoiceEntry.srChoiceName);
                ArmorDescription = pPawn.GetArmorEffectDescription(ArmorPart.GameEffects);
                ClearCustomTokens();
                SetCustomToken(0, ArmorDescription);
                SetCustomToken(1, string(ItemData.ChoiceEntry.srChoiceDescription));
                ItemData.ChoiceEntry.sChoiceDescription = GetUIString(ArmorEffectDescriptionFormatter, TRUE);
                ClearCustomTokens();
                break;
            case EItemType.TYPE_ARMS:
                ArmorIndex = Class'SFXPlayerCustomization'.default.ArmAppearances.Find('Id', ItemData.ArmorID);
                if (ArmorIndex != -1)
                {
                    ArmorPart = Class'SFXPlayerCustomization'.default.ArmAppearances[ArmorIndex];
                }
                ItemData.ChoiceEntry.sChoiceName = string(ItemData.ChoiceEntry.srChoiceName);
                ArmorDescription = pPawn.GetArmorEffectDescription(ArmorPart.GameEffects);
                ClearCustomTokens();
                SetCustomToken(0, ArmorDescription);
                SetCustomToken(1, string(ItemData.ChoiceEntry.srChoiceDescription));
                ItemData.ChoiceEntry.sChoiceDescription = GetUIString(ArmorEffectDescriptionFormatter, TRUE);
                ClearCustomTokens();
                break;
            case EItemType.TYPE_NESTEDCATEGORY:
                ItemData.ChoiceEntry.eDisplayType = EChoiceDisplayType.EChoiceDisplayType_Nested;
                break;
            case EItemType.TYPE_WEAPONUPGRADE:
                MaxWeaponLevel = MaxWeaponLevel_Normal;
                bSkipItem = TRUE;
                WeaponLevel = Engine.GetPlayerVariable(Name(ItemData.ItemClassName));
                if (WeaponLevel <= 0)
                {
                    break;
                }
                CostIndexModifier = WeaponLevelIncrease_Normal;
                bWeaponFoundNGP = oWorldInfo.CheckConditional(ItemData.ItemConditionals[0]);
                if (bWeaponFoundNGP)
                {
                    CostIndexModifier += WeaponLevelIncrease_NGP;
                }
                if (WeaponLevel < MaxWeaponLevel)
                {
                    bSkipItem = FALSE;
                }
                else if (oWorldInfo.CheckConditional(NewGamePlusID) == TRUE)
                {
                    MaxWeaponLevel = MaxWeaponLevel_NGP;
                    if (bWeaponFoundNGP == FALSE && WeaponLevel + WeaponLevelIncrease_NGP < MaxWeaponLevel || ItemData.ItemConditionals[0] == 0 && WeaponLevel < MaxWeaponLevel || bWeaponFoundNGP == TRUE && WeaponLevel < MaxWeaponLevel)
                    {
                        bSkipItem = FALSE;
                    }
                }
                if (!bSkipItem)
                {
                    ClearCustomTokens();
                    SetCustomToken(0, Class'SFXWeaponUIDataManager'.static.GetRomanNumeral(WeaponLevel + 1));
                    WeaponData = WeaponDataManager.GetWeaponUIDataFromClassPath(Name(ItemData.ItemClassName), WeaponIdx);
                    ItemData.ChoiceEntry.sChoiceName = GetUIString(WeaponData.Name, TRUE);
                    ClearCustomTokens();
                    ItemData.ChoiceEntry.oChoiceImage = WeaponData.Image;
                    ItemData.ChoiceEntry.sChoiceDescription = string(ItemData.ChoiceEntry.srChoiceDescription);
                    CostIndexModifier -= int(ItemData.Value);
                    ItemData.ChoiceEntry.nOptionalPaneItemValue = GetCalculatedItemCost(WeaponUpgradeCosts[Clamp(WeaponLevel - CostIndexModifier, 0, WeaponUpgradeCosts.Length - 1)]);
                }
                break;
            case EItemType.TYPE_WEAPON:
                Rank = Engine.GetPlayerVariable(Name(ItemData.ItemClassName));
                if (float(Rank) >= Class'SFXWeapon'.default.MaxLevel)
                {
                    bSkipItem = TRUE;
                    break;
                }
                ClearCustomTokens();
                SetCustomToken(0, Class'SFXWeaponUIDataManager'.static.GetRomanNumeral(Engine.GetPlayerVariable(Name(ItemData.ItemClassName)) + 1));
                WeaponData = WeaponDataManager.GetWeaponUIDataFromClassPath(Name(ItemData.ItemClassName), WeaponIdx);
                ItemData.ChoiceEntry.sChoiceName = GetUIString(WeaponData.Name, TRUE);
                ClearCustomTokens();
                ItemData.ChoiceEntry.oChoiceImage = WeaponData.Image;
                ItemData.ChoiceEntry.sChoiceDescription = string(WeaponData.Description);
                ItemData.ChoiceEntry.WeaponClassRef = Name(ItemData.ItemClassName);
                break;
            default:
                ItemData.ChoiceEntry.sChoiceName = string(ItemData.ChoiceEntry.srChoiceName);
                ItemData.ChoiceEntry.sChoiceDescription = string(ItemData.ChoiceEntry.srChoiceDescription);
        }
        if (bSkipItem)
        {
            continue;
        }
        if (ItemData.ItemType != EItemType.TYPE_WEAPONUPGRADE && ItemData.ItemType != EItemType.TYPE_WEAPON && ItemData.ItemType != EItemType.TYPE_MOD)
        {
            ItemData.ChoiceEntry.oChoiceImage = GetStoreItemImage(ItemData.LargeImage);
        }
        if (ItemData.ItemType != EItemType.TYPE_WEAPONUPGRADE && ItemData.ItemType != EItemType.TYPE_TALENTRESET)
        {
            ItemData.ChoiceEntry.nOptionalPaneItemValue = GetCalculatedItemCost(ItemData.BaseCost);
        }
        ItemData.ChoiceEntry.bDisabled = ShouldItemBeDisabled(ItemData);
        StoreGUIData.lstChoices.AddItem(ItemData.ChoiceEntry);
        StoreItems.AddItem(ItemData);
    }
    if (StoreGUIData.bApplyIntelSummary == TRUE)
    {
        StoreGUIData.IntelSummary.ChoiceEntry.sChoiceName = string(StoreGUIData.IntelSummary.ChoiceEntry.srChoiceName);
        IntelSummary = "";
        ClearCustomTokens();
        for (idx = 0; idx < StoreGUIData.MallStoreArray.Length; idx++)
        {
            for (NestedIdx = 0; NestedIdx < StoreGUIData.MallStoreArray[idx].StoreItemArray.Length; NestedIdx++)
            {
                if (Engine.GetPlayerVariable(Name(StoreGUIData.MallStoreArray[idx].StoreItemArray[NestedIdx].ItemClassName)) <= 0)
                {
                    continue;
                }
                if (StoreGUIData.MallStoreArray[idx].StoreItemArray[NestedIdx].ItemClassName == "Intel_MedicalUpgrade_Scars")
                {
                    SetCustomToken(0, string(StoreGUIData.MallStoreArray[idx].StoreItemArray[NestedIdx].ChoiceEntry.srChoiceDescription));
                    SetCustomToken(1, IntelSummary);
                    IntelSummary = GetUIString(ArmorEffectDescriptionFormatter, TRUE);
                    continue;
                }
                IntelIdx = pPawn.PermanentGameEffects.Find('UniqueName', StoreGUIData.MallStoreArray[idx].StoreItemArray[NestedIdx].ItemClassName);
                if (IntelIdx != -1)
                {
                    SetCustomToken(0, string(int(Abs(pPawn.PermanentGameEffects[IntelIdx].Value) * 100.0)));
                }
                else
                {
                    IntelIdx = GlobalStoreDiscounts.Find('PlayerVariable', StoreGUIData.MallStoreArray[idx].StoreItemArray[NestedIdx].ItemClassName);
                    if (IntelIdx != -1)
                    {
                        SetCustomToken(0, string(int(GlobalStoreDiscounts[IntelIdx].DiscountStrength * 100.0)));
                    }
                    else
                    {
                        SetCustomToken(0, "0");
                    }
                }
                SetCustomToken(1, IntelSummary);
                IntelSummary = GetUIString(StoreGUIData.MallStoreArray[idx].StoreItemArray[NestedIdx].ChoiceEntry.srChoiceDescription, TRUE);
            }
        }
        if (IntelSummary != "")
        {
            StoreGUIData.IntelSummary.ChoiceEntry.sChoiceDescription = IntelSummary;
        }
        else
        {
            StoreGUIData.IntelSummary.ChoiceEntry.sChoiceDescription = string(StoreGUIData.IntelSummary.ChoiceEntry.srChoiceDescription);
        }
        StoreGUIData.lstChoices.AddItem(StoreGUIData.IntelSummary.ChoiceEntry);
        StoreItems.AddItem(StoreGUIData.IntelSummary);
    }
    if (StoreGUIData.lstChoices.Length == 0)
    {
        OutOfStock();
    }
}
public function TalentResetHelper(string PawnName)
{
    local int Index;
    local int X;
    local int nEvolveIndex;
    local SFXEngine Engine;
    local int TotalPoints;
    
    Engine = Class'SFXEngine'.static.GetSFXEngine();
    if (Engine == None)
    {
        return;
    }
    if (PawnName == "Shepard")
    {
        Customer.PowerManager.RefundAllTalentPoints();
    }
    else
    {
        Index = Engine.HenchmanRecords.Find('Tag', Name(PawnName));
        if (Index != -1)
        {
            for (X = 0; X < Engine.HenchmanRecords[Index].Powers.Length; X++)
            {
                switch (Engine.HenchmanRecords[Index].Powers[X].CurrentRank)
                {
                    case 6.0:
                        TotalPoints += Class'SFXPowerCustomAction'.default.RankCosts[5];
                    case 5.0:
                        TotalPoints += Class'SFXPowerCustomAction'.default.RankCosts[4];
                    case 4.0:
                        TotalPoints += Class'SFXPowerCustomAction'.default.RankCosts[3];
                    case 3.0:
                        TotalPoints += Class'SFXPowerCustomAction'.default.RankCosts[2];
                    case 2.0:
                        TotalPoints += Class'SFXPowerCustomAction'.default.RankCosts[1];
                    case 1.0:
                        TotalPoints += Class'SFXPowerCustomAction'.default.RankCosts[0];
                    default:
                }
                Engine.HenchmanRecords[Index].Powers[X].CurrentRank = 0.0;
                for (nEvolveIndex = 0; nEvolveIndex < 6; nEvolveIndex++)
                {
                    Engine.HenchmanRecords[Index].Powers[X].EvolvedChoices[nEvolveIndex] = 0;
                }
            }
            Engine.HenchmanRecords[Index].TalentPoints += TotalPoints;
        }
    }
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    Begin Object Class=SFXWeaponUIDataManager Name=oDataManager
    End Object
    ChosenStoreItem = {
                       ChoiceEntry = {
                                      m_mapTokenIDToActual = (), 
                                      sChoiceName = "", 
                                      sChoiceTitle = "", 
                                      sChoiceImageTitle = "", 
                                      sChoiceDescription = "", 
                                      sActionText = "", 
                                      oChoiceImage = None, 
                                      WeaponClassRef = 'None', 
                                      WeaponModClassRef = 'None', 
                                      srChoiceName = $0, 
                                      srChoiceTitle = $0, 
                                      srChoiceImageTitle = $0, 
                                      srChoiceDescription = $0, 
                                      nOptionalPaneItemValue = 0, 
                                      nChoiceID = 0, 
                                      srActionText = $0, 
                                      bDefaultSelection = FALSE, 
                                      bDisabled = FALSE, 
                                      bNested = FALSE, 
                                      bOptionalPaneHideCost = FALSE, 
                                      ChoiceColor = SFXChoiceColors.CHOICECOLOR_Orange, 
                                      eResource = None, 
                                      eDisplayType = EChoiceDisplayType.EChoiceDisplayType_Normal
                                     }, 
                       ItemClassName = "", 
                       PlotPurchaseID = (), 
                       LargeImage = "", 
                       SmallImage = "", 
                       PVsToIncrement = (), 
                       CustomTokens = (), 
                       ItemConditionals = (), 
                       BaseCost = 0, 
                       PlotUnlockID = 0, 
                       PlotUnlockConditionalID = 0, 
                       ArmorID = 0, 
                       PlotPurchaseInt = 0, 
                       Priority = 0.0, 
                       CurrentModRank = 0, 
                       Value = 0.0, 
                       bIsGameEffect = FALSE, 
                       ItemType = EItemType.TYPE_MOD
                      }
    ModStringsArray = ({
                        className = "SFXGameContent.SFXWeaponMod_AssaultRifleAccuracy", 
                        Custom0Tokens = (25.0, 30.0, 35.0, 40.0, 45.0), 
                        Custom1Tokens = (1.0, 1.0, 1.0, 1.0, 1.0), 
                        srModName = $515088, 
                        srModDescription = $515089
                       }, 
                       {
                        className = "SFXGameContent.SFXWeaponMod_AssaultRifleDamage", 
                        Custom0Tokens = (25.0, 30.0, 35.0, 40.0, 45.0), 
                        Custom1Tokens = (1.0, 1.0, 1.0, 1.0, 1.0), 
                        srModName = $518965, 
                        srModDescription = $518966
                       }, 
                       {
                        className = "SFXGameContent.SFXWeaponMod_AssaultRifleForce", 
                        Custom0Tokens = (1.0, 1.0, 1.0, 1.0, 1.0), 
                        Custom1Tokens = (1.0, 1.0, 1.0, 1.0, 1.0), 
                        srModName = $518987, 
                        srModDescription = $518988
                       }, 
                       {
                        className = "SFXGameContent.SFXWeaponMod_AssaultRifleMagSize", 
                        Custom0Tokens = (40.0, 50.0, 60.0, 70.0, 80.0), 
                        Custom1Tokens = (1.0, 1.0, 1.0, 1.0, 1.0), 
                        srModName = $518985, 
                        srModDescription = $518986
                       }, 
                       {
                        className = "SFXGameContent.SFXWeaponMod_AssaultRifleStability", 
                        Custom0Tokens = (30.0, 40.0, 50.0, 60.0, 70.0), 
                        Custom1Tokens = (1.0, 1.0, 1.0, 1.0, 1.0), 
                        srModName = $518980, 
                        srModDescription = $518984
                       }, 
                       {
                        className = "SFXGameContent.SFXWeaponMod_SniperRifleAccuracy", 
                        Custom0Tokens = (25.0, 30.0, 35.0, 40.0, 45.0), 
                        Custom1Tokens = (1.0, 1.0, 1.0, 1.0, 1.0), 
                        srModName = $519534, 
                        srModDescription = $519535
                       }, 
                       {
                        className = "SFXGameContent.SFXWeaponMod_SniperRifleConstraintDamage", 
                        Custom0Tokens = (1.0, 1.0, 1.0, 1.0, 1.0), 
                        Custom1Tokens = (1.0, 1.0, 1.0, 1.0, 1.0), 
                        srModName = $519550, 
                        srModDescription = $519552
                       }, 
                       {
                        className = "SFXGameContent.SFXWeaponMod_SniperRifleDamage", 
                        Custom0Tokens = (25.0, 30.0, 35.0, 40.0, 45.0), 
                        Custom1Tokens = (1.0, 1.0, 1.0, 1.0, 1.0), 
                        srModName = $519527, 
                        srModDescription = $519531
                       }, 
                       {
                        className = "SFXGameContent.SFXWeaponMod_SniperRifleReloadSpeed", 
                        Custom0Tokens = (50.0, 60.0, 70.0, 80.0, 90.0), 
                        Custom1Tokens = (1.0, 1.0, 1.0, 1.0, 1.0), 
                        srModName = $519536, 
                        srModDescription = $519549
                       }, 
                       {
                        className = "SFXGameContent.SFXWeaponMod_SniperRifleTimeDilation", 
                        Custom0Tokens = (10.0, 12.5, 15.0, 17.5, 20.0), 
                        Custom1Tokens = (15.0, 17.5, 20.0, 22.5, 25.0), 
                        srModName = $519532, 
                        srModDescription = $519533
                       }, 
                       {
                        className = "SFXGameContent.SFXWeaponMod_ShotgunAccuracy", 
                        Custom0Tokens = (15.0, 17.5, 20.0, 22.5, 25.0), 
                        Custom1Tokens = (1.0, 1.0, 1.0, 1.0, 1.0), 
                        srModName = $519500, 
                        srModDescription = $519503
                       }, 
                       {
                        className = "SFXGameContent.SFXWeaponMod_ShotgunDamage", 
                        Custom0Tokens = (25.0, 30.0, 35.0, 40.0, 45.0), 
                        Custom1Tokens = (1.0, 1.0, 1.0, 1.0, 1.0), 
                        srModName = $519486, 
                        srModDescription = $519487
                       }, 
                       {
                        className = "SFXGameContent.SFXWeaponMod_ShotgunMeleeDamage", 
                        Custom0Tokens = (15.0, 17.5, 20.0, 22.5, 25.0), 
                        Custom1Tokens = (1.0, 1.0, 1.0, 1.0, 1.0), 
                        srModName = $519504, 
                        srModDescription = $519505
                       }, 
                       {
                        className = "SFXGameContent.SFXWeaponMod_ShotgunReloadSpeed", 
                        Custom0Tokens = (1.0, 1.0, 1.0, 1.0, 1.0), 
                        Custom1Tokens = (1.0, 1.0, 1.0, 1.0, 1.0), 
                        srModName = $519482, 
                        srModDescription = $519485
                       }, 
                       {
                        className = "SFXGameContent.SFXWeaponMod_ShotgunStability", 
                        Custom0Tokens = (50.0, 60.0, 70.0, 80.0, 90.0), 
                        Custom1Tokens = (1.0, 1.0, 1.0, 1.0, 1.0), 
                        srModName = $519508, 
                        srModDescription = $519509
                       }, 
                       {
                        className = "SFXGameContent.SFXWeaponMod_PistolAccuracy", 
                        Custom0Tokens = (25.0, 30.0, 35.0, 40.0, 45.0), 
                        Custom1Tokens = (1.0, 1.0, 1.0, 1.0, 1.0), 
                        srModName = $519359, 
                        srModDescription = $519360
                       }, 
                       {
                        className = "SFXGameContent.SFXWeaponMod_PistolDamage", 
                        Custom0Tokens = (25.0, 30.0, 35.0, 40.0, 45.0), 
                        Custom1Tokens = (1.0, 1.0, 1.0, 1.0, 1.0), 
                        srModName = $519355, 
                        srModDescription = $519356
                       }, 
                       {
                        className = "SFXGameContent.SFXWeaponMod_PistolMagSize", 
                        Custom0Tokens = (40.0, 50.0, 60.0, 70.0, 80.0), 
                        Custom1Tokens = (1.0, 1.0, 1.0, 1.0, 1.0), 
                        srModName = $519438, 
                        srModDescription = $519439
                       }, 
                       {
                        className = "SFXGameContent.SFXWeaponMod_PistolReloadSpeed", 
                        Custom0Tokens = (1.0, 1.0, 1.0, 1.0, 1.0), 
                        Custom1Tokens = (1.0, 1.0, 1.0, 1.0, 1.0), 
                        srModName = $519352, 
                        srModDescription = $519354
                       }, 
                       {
                        className = "SFXGameContent.SFXWeaponMod_PistolStability", 
                        Custom0Tokens = (15.0, 17.5, 20.0, 22.5, 25.0), 
                        Custom1Tokens = (1.0, 1.0, 1.0, 1.0, 1.0), 
                        srModName = $519357, 
                        srModDescription = $519358
                       }, 
                       {
                        className = "SFXGameContent.SFXWeaponMod_SMGAccuracy", 
                        Custom0Tokens = (25.0, 30.0, 35.0, 40.0, 45.0), 
                        Custom1Tokens = (1.0, 1.0, 1.0, 1.0, 1.0), 
                        srModName = $519472, 
                        srModDescription = $519473
                       }, 
                       {
                        className = "SFXGameContent.SFXWeaponMod_SMGConstraintDamage", 
                        Custom0Tokens = (25.0, 30.0, 35.0, 40.0, 45.0), 
                        Custom1Tokens = (1.0, 1.0, 1.0, 1.0, 1.0), 
                        srModName = $519476, 
                        srModDescription = $519477
                       }, 
                       {
                        className = "SFXGameContent.SFXWeaponMod_SMGDamage", 
                        Custom0Tokens = (25.0, 30.0, 35.0, 40.0, 45.0), 
                        Custom1Tokens = (1.0, 1.0, 1.0, 1.0, 1.0), 
                        srModName = $519468, 
                        srModDescription = $519469
                       }, 
                       {
                        className = "SFXGameContent.SFXWeaponMod_SMGMagSize", 
                        Custom0Tokens = (40.0, 50.0, 60.0, 70.0, 80.0), 
                        Custom1Tokens = (1.0, 1.0, 1.0, 1.0, 1.0), 
                        srModName = $519470, 
                        srModDescription = $519471
                       }, 
                       {
                        className = "SFXGameContent.SFXWeaponMod_SMGStability", 
                        Custom0Tokens = (50.0, 60.0, 70.0, 80.0, 90.0), 
                        Custom1Tokens = (1.0, 1.0, 1.0, 1.0, 1.0), 
                        srModName = $519474, 
                        srModDescription = $519475
                       }
                      )
    GlobalStoreDiscounts = ({PlayerVariable = "Intel_DestroyedMiniReaper_StoreDiscount", DiscountStrength = 0.0500000007}, 
                            {PlayerVariable = "Intel_SamaraMission_StoreDiscount", DiscountStrength = 0.0500000007}
                           )
    WeaponUpgradeCosts = (1000, 
                          2000, 
                          3000, 
                          4000, 
                          5000, 
                          7500, 
                          10000, 
                          15000, 
                          20000, 
                          25000, 
                          30000, 
                          35000, 
                          40000, 
                          50000
                         )
    RespecCosts = (0, 5000, 10000, 15000, 20000, 25000)
    Achievement_UniqueArmorPlotIDs = (20984, 20985, 20986, 20987, 21417)
    WeaponDataManager = oDataManager
    srPurchaseConfirm = $567685
    srPurchaseCancel = $568219
    srPurchaseConfirmMessage = $568021
    srMoreInformation = $315193
    srBack = $338459
    srNewFlag = $632403
    m_nInfoScrollSpeed = 1
    DisplayCap_Mods = 3
    DisplayCap_Weapons = 2
    ModPriorityModifier = 3
    NewGamePlusID = 1690
    MaxWeaponLevel_Normal = 5
    MaxWeaponLevel_NGP = 10
    WeaponLevelIncrease_Normal = 1
    WeaponLevelIncrease_NGP = 3
    ArmorEffectDescriptionFormatter = $347273
}