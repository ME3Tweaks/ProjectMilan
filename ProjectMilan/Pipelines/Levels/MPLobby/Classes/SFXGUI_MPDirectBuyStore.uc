// NEW to Milan - 11/17/2026 - Mgamerz
// Direct purchasing store

Class SFXGUI_MPDirectBuyStore extends SFXGUIMovie
    config(UI);


// A top level category
struct DirectBuyCategory
{
    var stringref Title;
};

// Definition of a single purchasable card
struct DirectBuyOffer
{
    var int Category;
    var string UniqueName;
    var stringref GUIName;
    var stringref GUIDescription;
    var string Image;
    var int MaxCount;
    // Player variable holding how many the player owns (empty if none)
    var string Counter;
    // The rank shown in the name (<CUSTOM0> as a roman numeral, <CUSTOM1> as a number)
    // A value of zero means it's the next rank up (Counter + 1), capped at MaxCount
    // Match consumable versions have a fixed rank as they don't level up like weapons
    var int Rank;
    // If this is a card that can level up
    var bool bLevel;
    // Formatted description tokens for CUSTOM#
    var array<string> DescTokens;
    // Stringrefs for kit cards, used instead of GUIDescription when present
    var array<stringref> KitStrings;
    // Player variable of a card that must be owned first (used by hidden heavy weapons)
    var string Requires;
    // Name of the card that must be owned first (for UI interpolation)
    var stringref RequiresName;
    // Name of the pricegroup for this card
    var Name PriceGroup;
    // Rarity (which affects what index of pricegroup)
    var int Rarity;
};

// Offer prices by rarity (index = ECardRarity) and bundle count to award on purchase
struct DirectBuyPriceGroup
{
    var Name Group;
    var array<int> Cost;
    var array<int> CostPerRank;
    var int BundleSize;
};

// A per-card price that overrides a price
struct DirectBuyPriceOverride
{
    var string UniqueName;
    var int Cost;
    var int CostPerRank;
};

var config array<DirectBuyCategory> Categories;
var config array<DirectBuyOffer> Offers;
var config array<DirectBuyPriceGroup> PriceGroups;
var config array<DirectBuyPriceOverride> PriceOverrides;
var config stringref srTitle;
var config stringref srSelect;
var config stringref srPurchase;
var config stringref srBack;
var config stringref m_srResourceTextCredits;
var config stringref srCreditsTitle;
var config stringref srCostTitle;
var config stringref srRequires;
var config stringref srBundleName;
var config stringref srPurchaseConfirmation;
var config stringref srCancel;
var config stringref srOK;
var config stringref srPurchaseError;

// -1 on the category list, otherwise the open category
var transient int CurrentCategory;
// Selected row on the category list, restored when going back to it
var transient int CategoryListSelection;
var transient array<int> RowEntries;
var transient array<Texture2D> PageImages;
var transient bool bMovieReady;
var transient bool bStageInitialized;
var transient bool bClosing;
// Used for debouncing a purchase button press
var transient float LastActionTime;
var transient int OfferListSelection;
var transient int PendingOffer;
var transient int PendingCost;
var transient int PendingUnits;
var transient string PendingName;
var transient string PendingImage;

public delegate function OnCloseCallback();

public function SetOnCloseCallback(delegate<OnCloseCallback> Callback)
{
    OnCloseCallback = Callback;
}

public function ExPostLoad()
{
    bMovieReady = TRUE;
    RefreshStoreGUI();
    if (IsUsingGamepad())
    {
        HandleButtonRefresh(TRUE);
    }
}

public event function OnStart()
{
    Super.OnStart();
    SetRequiresUIWorld(TRUE);
    SetMouseVisible(!IsUsingGamepad());
    PlayGuiSound('StoreOpen');
    CurrentCategory = -1;
    CategoryListSelection = 0;
    OfferListSelection = 0;
    PendingOffer = -1;
    LastActionTime = -1.0;
}

public event function HandleButtonRefresh(bool usingGamepad)
{
    Super.HandleButtonRefresh(usingGamepad);
    SetMouseVisible(!usingGamepad);
    if (!bMovieReady || bClosing)
    {
        return;
}
    ASRefreshButtonHelp(usingGamepad);
}

private final function bool IsNewAction()
{
    local float Now;

    Now = GetPC().WorldInfo.RealTimeSeconds;
    if (Now == LastActionTime)
    {
        return FALSE;
    }
    LastActionTime = Now;
    return TRUE;
}

public event function OnClose()
{
    PlayGuiSound('StoreClose');
    PageImages.Length = 0;
    Super.OnClose();
    if (OnCloseCallback != None)
    {
        OnCloseCallback();
        OnCloseCallback = None;
    }
}

public event function stringref GetBButtonText()
{
    if (Pages.Length > 0 && Pages.Length == 1 && Pages[0].Data.m_srBText != 0)
    {
        return Pages[0].Data.m_srBText;
    }
    return srBack;
}

public event function int GetResourceCount(int nResource)
{
    local SFXSaveManagerMP SaveManager;

    if (nResource == -1)
    {
        return 0;
    }
    SaveManager = Class'SFXEngine'.static.GetSFXEngine().MPSaveManager;
    if (SaveManager == None)
    {
        return 0;
    }
    return SaveManager.GetCredits();
}

public function string GetResourceText(BioDefine.EInventoryResourceTypes Resource)
{
    return GetUIString(m_srResourceTextCredits);
}

public event function bool GetWeaponDataStats(Name WeaponClassPath, out array<SFXGUI_Store.ComparisonStat> DisplayStats)
{
    DisplayStats.Length = 0;
    return FALSE;
}

public function ExBuy(int RowIndex)
{
    if (bClosing || PendingOffer >= 0 || RowIndex < 0 || RowIndex >= RowEntries.Length || !IsNewAction())
    {
        return;
    }
    if (CurrentCategory < 0)
    {
        CategoryListSelection = RowIndex;
        OfferListSelection = 0;
        CurrentCategory = RowEntries[RowIndex];
        RefreshStoreGUI();
        return;
    }
    OfferListSelection = RowIndex;
    StartPurchase(RowEntries[RowIndex]);
}

public function ExExitStore()
    {
    if (bClosing || PendingOffer >= 0 || !IsNewAction())
    {
        return;
    }
    PageIndex = Pages.Length - 1;
    Item = StoreItems[RowIndex];
    if (Item.ItemType == EItemType.TYPE_RETURN)
    {
        ExExitStore();
    }
    else if (Item.ItemType == EItemType.TYPE_NESTEDCATEGORY && !Item.ChoiceEntry.bDisabled)
private final function SFXGAWReinforcementManager GetGAWManager()
    {
    local SFXLocalPlayer LP;

    LP = SFXLocalPlayer(GetPC().Player);
    if (LP == None)
    {
        return None;
    }
    return SFXGAWReinforcementManager(LP.GAWReinforcementManager);
}
private final function int GetCredits()
        {
    local SFXSaveManagerMP SaveManager;

    SaveManager = Class'SFXEngine'.static.GetSFXEngine().MPSaveManager;
    if (SaveManager == None)
            {
        return 0;
            }
    return SaveManager.GetCredits();
        }

// Opens the confirmation dialog for an offer
private final function StartPurchase(int OfferIndex)
{
    local BioSFHandler_MessageBox ConfirmationBox;
    local BioMessageBoxOptionalParams Params;
    local string Message;

    PendingCost = GetOfferCost(OfferIndex);
    PendingUnits = GetOfferUnits(OfferIndex);
    if (IsOfferLocked(OfferIndex) || PendingCost < 0 || PendingUnits <= 0 || PendingCost > GetCredits())
    {
        PlayGuiSound('Error');
        return;
    }
    PendingOffer = OfferIndex;
    PendingName = GetOfferName(OfferIndex);
    PendingImage = Offers[OfferIndex].Image;
    PlayGuiSound('MPStorePurchase');
    SetCustomToken(0, PendingName);
    Message = GetUIString(srPurchaseConfirmation, TRUE);
    ClearCustomTokens();
    Params.srAText = srPurchase;
    Params.srBText = srCancel;
    ConfirmationBox = Class'SFXGUIInteraction'.static.GetInstance().CreateMessageBox(GetPC());
    if (ConfirmationBox == None)
    {
        PendingOffer = -1;
        return;
    }
    ConfirmationBox.SetInputDelegate(OnPurchaseConfirmed);
    ConfirmationBox.DisplayMessageBoxEx(Message, Params);
}

public function ExExitStore()
{
    if (bClosing)
    {
        return;
    }
    if (Pages.Length > 1)
    {
        Pages.Remove(Pages.Length - 1, 1);
public function OnPurchaseSaved(int nResult)
{
    PendingOffer = -1;
    if (nResult != 0 && nResult != -1)
    {
        WarnInternal("Direct Buy: purchase saving failed! SaveRecords result:"@ nResult);
        ShowPurchaseError();
        return;
    }
    ShowPurchaseNotification();
        RefreshStoreGUI();
}

// Shows the SP purchase notification
private final function ShowPurchaseNotification()
{
    local BioHintSystem HintSystem;

    if (BioPlayerController(GetPC()) == None)
    {
        return;
    }
    HintSystem = BioHintSystem(BioPlayerController(GetPC()).HintSystem);
    if (HintSystem != None)
    {
        HintSystem.AddNotification_StorePurchase(PendingName, "", PendingImage);
    }
}

private final function ShowPurchaseError()
{
    local BioMessageBoxOptionalParams Params;

    Params.bNoFade = TRUE;
    Params.srAText = srOK;
    Class'SFXGUIInteraction'.static.GetInstance().QueueNamedMessageBox('DirectBuyError', 2, srPurchaseError, Params, OnPurchaseErrorClosed);
    RefreshStoreGUI();
}

public function OnPurchaseErrorClosed(bool bAPressed, int nContext)
{
    Class'SFXGUIInteraction'.static.GetInstance().RemoveNamedMessageBox('DirectBuyError', GetPC());
}
}

public function RefreshStoreGUI()
{
    local int PageIndex;
    local int RowIndex;
    local SFXGUIData_Store Data;
    local SFXGUIData_Store.StoreItemData Item;
    local SFXGameChoiceGUIData.SFXChoiceEntry Choice;
    local string ChoiceName;
    local string ChoiceDescription;
    local string Cost;
    local bool bDisabled;

    if (!bMovieReady || Pages.Length == 0 || bClosing)
    {
        return;
    }
    PageIndex = Pages.Length - 1;
    Data = Pages[PageIndex].Data;
    StoreItems = Data.StoreItemArray;
    ASSetPlatformLayout(int(GetScreenLayout()));
    ASSetTitles(GetUIString(Data.m_srTitle), GetUIString(Data.m_srSubTitle), GetUIString(Data.m_srAText), GetUIString(GetBButtonText()), "", GetResourceCount(0));
    ASSetInitialListSize(StoreItems.Length);
    for (RowIndex = 0; RowIndex < StoreItems.Length; ++RowIndex)
    {
        Item = StoreItems[RowIndex];
        Choice = Item.ChoiceEntry;
        ChoiceName = Choice.sChoiceName;
        if (ChoiceName == "")
        {
            ChoiceName = GetUIString(Choice.srChoiceName);
        }
        ChoiceDescription = Choice.sChoiceDescription;
        if (ChoiceDescription == "")
        {
            ChoiceDescription = GetUIString(Choice.srChoiceDescription);
        }
        Cost = "";
        bDisabled = Choice.bDisabled;
        if (Item.ItemType != EItemType.TYPE_NESTEDCATEGORY && Item.ItemType != EItemType.TYPE_RETURN)
        {
            if (!Choice.bOptionalPaneHideCost && Item.BaseCost >= 0)
            {
                Cost = string(Item.BaseCost);
            }
            bDisabled = TRUE;
        }
        ASAddChoiceEntry(RowIndex, ChoiceName, GetUIString(Choice.srChoiceTitle), GetUIString(Choice.srChoiceImageTitle),
            ChoiceDescription, Cost, int(Choice.ChoiceColor), int(Choice.eResource), Choice.sActionText, Item.LargeImage,
            RowIndex == Pages[PageIndex].Selection, bDisabled, Choice.eDisplayType,
            "", 0, 0, 0, "", 0, 0, 0, "", 0, 0, 0, "", 0, 0, 0, "", 0, 0, 0);
    }
    ASInitializationFinished();
    if (StoreItems.Length > 0)
    {
        ASSetSelectionIndex(Clamp(Pages[PageIndex].Selection, 0, StoreItems.Length - 1));
    }
}

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
public function onScreenClosed()
{
    ExExitStore();
}

public function ASInitializationFinished()
{
    ActionScriptVoid("StoreStage.InitializationFinished");
}

public function ScrollText(float Value)
{
    ActionScriptVoid("StoreStage.ScrollInfoText");
}

defaultproperties
{
    CurrentCategory = -1
    srTitle = $49875985
    srSelect = $591479
    srPurchase = $664930
    srBack = $338459
    m_srResourceTextCredits = $665454
    srCreditsTitle = $346393
    srCostTitle = $341340
    srPurchaseConfirmation = $665536
    srCancel = $665537
    srOK = $152938
    srPurchaseError = $715826
    PendingOffer = -1
}
