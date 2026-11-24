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
    if (CurrentCategory >= 0)
    {
        CurrentCategory = -1;
        RefreshStoreGUI();
        return;
    }
    bClosing = TRUE;
    Close();
}

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

private final function bool FindOfferCard(int OfferIndex, out SFXGAWReinforcementBase Reinforcement, out int CardIndex)
{
    local SFXGAWReinforcementManager GAWManager;
    local SFXGAWReinforcementBase Pool;
    local int DeckIndex;
    local int EntryIndex;
    local bool bMatchVersion;
    local string WantedName;

    Reinforcement = None;
    CardIndex = -1;
    GAWManager = GetGAWManager();
    if (GAWManager == None)
    {
        return FALSE;
    }
    WantedName = Locs(Offers[OfferIndex].UniqueName);
    for (DeckIndex = 0; DeckIndex < GAWManager.Deck.Length; ++DeckIndex)
    {
        Pool = GAWManager.Deck[DeckIndex];
        if (Pool == None)
        {
            continue;
        }
        bMatchVersion = FALSE;
        if (Pool.IsA('SFXGAWReinforcementMatchConsumable') && !Offers[OfferIndex].bLevel && Offers[OfferIndex].Rank > 0)
        {
            bMatchVersion = TRUE;
        }
        for (EntryIndex = 0; EntryIndex < Pool.CardList.Length; ++EntryIndex)
        {
            if (Locs(Pool.CardList[EntryIndex].UniqueName) != WantedName)
            {
                continue;
            }
            if (bMatchVersion && Pool.CardList[EntryIndex].VersionIdx != Offers[OfferIndex].Rank - 1)
            {
                continue;
            }
            Reinforcement = Pool;
            CardIndex = EntryIndex;
            return TRUE;
        }
    }
    return FALSE;
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

public function OnPurchaseConfirmed(bool bAPressed, int nContext)
{
    if (!bAPressed || bClosing || PendingOffer < 0)
    {
        PendingOffer = -1;
        return;
    }
    PlayGuiSound('MPStorePurchaseConfirm');
    if (!CompletePurchase(PendingOffer))
    {
        PendingOffer = -1;
        ShowPurchaseError();
    }
}

private final function bool CompletePurchase(int OfferIndex)
{
    local SFXSaveManagerMP SaveManager;
    local SFXGAWReinforcementBase Reinforcement;
    local int CardIndex;
    local array<SFXGAWReinforcementBase.CardInfoData> SavedCardList;
    local SFXGAWReinforcementBase.CardInfoData Entry;
    local SFXGAWReinforcementBase.CardInfoData Awarded;
    local bool bAwarded;

    SaveManager = Class'SFXEngine'.static.GetSFXEngine().MPSaveManager;
    if (SaveManager == None)
    {
        WarnInternal("Direct Buy: purchase of" @ Offers[OfferIndex].UniqueName @ "failed, no MPSaveManager");
        return FALSE;
    }
    if (PendingCost > SaveManager.GetCredits())
    {
        WarnInternal("Direct Buy: purchase of" @ Offers[OfferIndex].UniqueName @ "failed, user is too poor. Item costs" @ PendingCost @ "but only has" @ SaveManager.GetCredits() @ "credits");
        return FALSE;
    }
    if (!FindOfferCard(OfferIndex, Reinforcement, CardIndex))
    {
        // Card isn't properly defined
        WarnInternal("Direct Buy: purchase of" @ Offers[OfferIndex].UniqueName @ "(rank" @ Offers[OfferIndex].Rank $ ") failed, no reinforcement pool in the deck system has this card");
        return FALSE;
    }
    SavedCardList = Reinforcement.CardList;
    Entry = SavedCardList[CardIndex];
    Entry.PVIncrementBonus = PendingUnits - 1;
    Reinforcement.CardList.Length = 0;
    Reinforcement.CardList.AddItem(Entry);
    bAwarded = Reinforcement.OnAwarded(Awarded);
    Reinforcement.CardList = SavedCardList;
    if (!bAwarded)
    {
        WarnInternal("Direct Buy: purchase of" @ Offers[OfferIndex].UniqueName @ "failed, OnAwarded failed for entry" @ CardIndex);
        return FALSE;
    }
    SaveManager.SubtractCredits(PendingCost, "DirectBuy_" $ Offers[OfferIndex].UniqueName);
    SaveManager.SaveRecords(FALSE, OnPurchaseSaved);
    return TRUE;
}

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

// Preloads texture so img:// finds it
private final function string LoadRowImage(string Path)
{
    local Texture2D Image;

    if (Path == "")
    {
        return "";
    }
    Image = Texture2D(FindObject(Path, Class'Texture2D'));
    if (Image == None)
    {
        Image = Texture2D(Class'SFXEngine'.static.GetSeekFreeObject(Path, Class'Texture2D'));
    }
    if (Image == None)
    {
        return "";
    }
    PageImages.AddItem(Image);
    return Path;
}

private final function int GetOfferRank(int OfferIndex)
{
    local int NextRank;

    if (Offers[OfferIndex].Rank > 0 && !Offers[OfferIndex].bLevel)
    {
        return Offers[OfferIndex].Rank;
    }
    NextRank = 1;
    if (Offers[OfferIndex].Counter != "")
    {
        NextRank = Class'SFXEngine'.static.GetSFXEngine().GetPlayerVariable(Name(Offers[OfferIndex].Counter)) + 1;
    }
    if (Offers[OfferIndex].MaxCount > 0)
    {
        NextRank = Min(NextRank, Offers[OfferIndex].MaxCount);
    }
    return NextRank;
}

// Level rows are only shown for the level the player would buy next (if they can)
private final function bool IsOfferShown(int OfferIndex)
{
    return !Offers[OfferIndex].bLevel || Offers[OfferIndex].Rank == GetOfferRank(OfferIndex);
}

// Fills the custom tokens for the next string interpolation
// <CUSTOM2> is how many one purchase gives (bundle size)
private final function SetRankTokens(int Rank, optional int Quantity = 1)
{
    ClearCustomTokens();
    SetCustomToken(0, Class'SFXWeaponUIDataManager'.static.GetRomanNumeral(Rank));
    SetCustomToken(1, string(Rank));
    SetCustomToken(2, string(Quantity));
}

private final function int GetPriceGroupIndex(int OfferIndex)
{
    local int GroupIndex;

    for (GroupIndex = 0; GroupIndex < PriceGroups.Length; ++GroupIndex)
    {
        if (PriceGroups[GroupIndex].Group == Offers[OfferIndex].PriceGroup)
        {
            return GroupIndex;
        }
    }
    return -1;
}

private final function int GetOfferBundleSize(int OfferIndex)
{
    local int GroupIndex;

    GroupIndex = GetPriceGroupIndex(OfferIndex);
    if (GroupIndex < 0)
    {
        return 1;
    }
    return Max(1, PriceGroups[GroupIndex].BundleSize);
}

// Has the player maxed out this card?
private final function bool IsOfferMaxed(int OfferIndex)
{
    if (Offers[OfferIndex].Counter == "" || Offers[OfferIndex].MaxCount <= 0)
    {
        return FALSE;
    }
    return Class'SFXEngine'.static.GetSFXEngine().GetPlayerVariable(Name(Offers[OfferIndex].Counter)) >= Offers[OfferIndex].MaxCount;
}

// Clamped bundle size
private final function int GetOfferUnits(int OfferIndex)
{
    local int Units;

    Units = GetOfferBundleSize(OfferIndex);
    if (Offers[OfferIndex].Counter != "" && Offers[OfferIndex].MaxCount > 0)
    {
        Units = Min(Units, Offers[OfferIndex].MaxCount - Class'SFXEngine'.static.GetSFXEngine().GetPlayerVariable(Name(Offers[OfferIndex].Counter)));
    }
    return Max(0, Units);
}

// Clamped bundle-size aware purchase price - if bundle puts you over the max, you get a prorated price
private final function int GetOfferCost(int OfferIndex)
{
    local int GroupIndex;
    local int OverrideIndex;
    local int Rarity;
    local int Cost;
    local int CostPerRank;
    local int Steps;

    if (IsOfferMaxed(OfferIndex))
    {
        return -1;
    }
    OverrideIndex = PriceOverrides.Find('UniqueName', Offers[OfferIndex].UniqueName);
    if (OverrideIndex >= 0)
    {
        Cost = PriceOverrides[OverrideIndex].Cost;
        CostPerRank = PriceOverrides[OverrideIndex].CostPerRank;
    }
    else
    {
        GroupIndex = GetPriceGroupIndex(OfferIndex);
        if (GroupIndex < 0)
        {
            return -1;
        }
        Rarity = Offers[OfferIndex].Rarity;
        if (Rarity < 0 || Rarity >= PriceGroups[GroupIndex].Cost.Length)
        {
            return -1;
        }
        Cost = PriceGroups[GroupIndex].Cost[Rarity];
        if (Rarity < PriceGroups[GroupIndex].CostPerRank.Length)
        {
            CostPerRank = PriceGroups[GroupIndex].CostPerRank[Rarity];
        }
    }
    if (Offers[OfferIndex].Rank == 0 || Offers[OfferIndex].bLevel)
    {
        Steps = Max(0, GetOfferRank(OfferIndex) - 1);
    }
    return (Cost + CostPerRank * Steps) * GetOfferUnits(OfferIndex);
}

private final function string GetOfferCostText(int OfferIndex)
{
    local int Cost;

    Cost = GetOfferCost(OfferIndex);
    if (Cost < 0)
    {
        return "";
    }
    return string(Cost);
}

private final function string GetOfferName(int OfferIndex)
{
    local string Result;

    local int Units;

    Units = Max(1, GetOfferUnits(OfferIndex));
    SetRankTokens(GetOfferRank(OfferIndex), Units);
    Result = GetTokenisedString(Offers[OfferIndex].GUIName);
    ClearCustomTokens();
    if (GetOfferBundleSize(OfferIndex) > 1 && srBundleName != $0)
    {
        SetCustomToken(0, Result);
        SetCustomToken(1, string(Units));
        Result = GetTokenisedString(srBundleName);
        ClearCustomTokens();
    }
    return Result;
}

private final function bool IsOfferLocked(int OfferIndex)
{
    return Offers[OfferIndex].Requires != "" && Class'SFXEngine'.static.GetSFXEngine().GetPlayerVariable(Name(Offers[OfferIndex].Requires)) <= 0;
}

private final function string GetOfferDescription(int OfferIndex)
{
    local string Result;

    Result = GetOfferBaseDescription(OfferIndex);
    if (IsOfferLocked(OfferIndex))
    {
        ClearCustomTokens();
        SetCustomToken(0, GetUIString(Offers[OfferIndex].RequiresName));
        if (Result != "")
        {
            Result $= "\n\n";
        }
        Result $= GetTokenisedString(srRequires);
        ClearCustomTokens();
    }
    return Result;
}

private final function string GetKitDescription(int OfferIndex)
{
    local string Result;
    local int LineIndex;

    for (LineIndex = 0; LineIndex < Offers[OfferIndex].KitStrings.Length; ++LineIndex)
    {
        if (Offers[OfferIndex].KitStrings[LineIndex] == 0)
        {
            continue;
        }
        // Insert a new line to match card description
        if (LineIndex >= 2 && LineIndex <= 4)
        {
            Result $= "\n";
        }
        Result $= GetUIString(Offers[OfferIndex].KitStrings[LineIndex]) $ "\n";
    }
    return Result;
}

private final function string GetOfferBaseDescription(int OfferIndex)
{
    local string Result;
    local int TokenIndex;

    if (Offers[OfferIndex].KitStrings.Length > 0)
    {
        return GetKitDescription(OfferIndex);
    }
    if (Offers[OfferIndex].GUIDescription == 0)
    {
        return "";
    }
    if (Offers[OfferIndex].DescTokens.Length > 0)
    {
        ClearCustomTokens();
        for (TokenIndex = 0; TokenIndex < Offers[OfferIndex].DescTokens.Length; ++TokenIndex)
        {
            SetCustomToken(TokenIndex, Offers[OfferIndex].DescTokens[TokenIndex]);
        }
    }
    else
    {
        SetRankTokens(GetOfferRank(OfferIndex));
    }
    Result = GetTokenisedString(Offers[OfferIndex].GUIDescription);
    ClearCustomTokens();
    return Result;
}

// The first offer in a category, or -1 if it has none
private final function int GetFirstOffer(int CategoryIndex)
{
    local int OfferIndex;

    for (OfferIndex = 0; OfferIndex < Offers.Length; ++OfferIndex)
    {
        if (Offers[OfferIndex].Category == CategoryIndex)
        {
            return OfferIndex;
        }
    }
    return -1;
}

// Adds a row to the store GUI
private final function AddRow(int RowIndex, string RowName, string Description, string Cost, string Image, bool bSelected, bool bDisabled, bool bNested)
{
    local SFXGameChoiceGUIData.EChoiceDisplayType DisplayType;

    if (bNested)
    {
        DisplayType = EChoiceDisplayType.EChoiceDisplayType_Nested;
    }
    else
    {
        DisplayType = EChoiceDisplayType.EChoiceDisplayType_Normal;
    }
    ASAddChoiceEntry(RowIndex, RowName, "", "", Description, Cost, 0, 0, "", Image, bSelected, bDisabled, DisplayType, "", 0, 0, 0, "", 0, 0, 0, "", 0, 0, 0, "", 0, 0, 0, "", 0, 0, 0);
}

public function RefreshStoreGUI()
{
    local int Index;
    local int FirstOffer;
    local int Selection;
    local string Subtitle;
    local stringref AText;

    if (!bMovieReady || bClosing)
    {
        return;
    }
    RowEntries.Length = 0;
    PageImages.Length = 0;
    if (CurrentCategory < 0)
    {
        for (Index = 0; Index < Categories.Length; ++Index)
        {
            if (GetFirstOffer(Index) >= 0)
            {
                RowEntries.AddItem(Index);
            }
        }
        Subtitle = "";
        AText = srSelect;
        Selection = CategoryListSelection;
    }
    else
    {
        for (Index = 0; Index < Offers.Length; ++Index)
        {
            if (Offers[Index].Category == CurrentCategory && IsOfferShown(Index))
            {
                RowEntries.AddItem(Index);
            }
        }
        Subtitle = GetUIString(Categories[CurrentCategory].Title);
        AText = srPurchase;
        Selection = OfferListSelection;
    }

    ASSetTitles(GetUIString(srTitle), Subtitle, GetUIString(AText), GetUIString(GetBButtonText()), "", GetResourceCount(0));
    ASSetInitialListSize(RowEntries.Length);
    for (Index = 0; Index < RowEntries.Length; ++Index)
    {
        if (CurrentCategory < 0)
        {
            // A category shows its first offer's image
            // We might consider hardcoding a different value as some weapon mods have the same image across categories
            FirstOffer = GetFirstOffer(RowEntries[Index]);
            AddRow(Index, GetUIString(Categories[RowEntries[Index]].Title), "", "", LoadRowImage(Offers[FirstOffer].Image), Index == Selection, FALSE, TRUE);
        }
        else
        {
            AddRow(Index, GetOfferName(RowEntries[Index]), GetOfferDescription(RowEntries[Index]), GetOfferCostText(RowEntries[Index]), LoadRowImage(Offers[RowEntries[Index]].Image), Index == Selection, IsOfferLocked(RowEntries[Index]) || GetOfferCost(RowEntries[Index]) < 0, FALSE);
        }
    }
    if (!bStageInitialized)
    {
        bStageInitialized = TRUE;
        ASInitializationFinished();
    }
    CenterItemImage();
    if (RowEntries.Length > 0)
    {
        ASSetSelectionIndex(Clamp(Selection, 0, RowEntries.Length - 1));
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

// Used to vertically center banners which have a different aspect ratio
private final function CenterItemImage()
{
    SetVariableNumber("_root.StoreStage.storeItemBox.StoreItemImage.screenShotLoader._RegistrationPoint", 0);
    SetVariableNumber("_root.StoreStage.storeItemBox.StoreItemImage.screenShotLoader._HAlign", 1);
    SetVariableNumber("_root.StoreStage.storeItemBox.StoreItemImage.screenShotLoader._VAlign", 1);
}

public function ASRefreshButtonHelp(bool usingGamepad)
{
    ActionScriptVoid("StoreStage.RefreshButtonHelp");
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
