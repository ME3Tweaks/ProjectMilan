Class SFXGUI_MPMatchConsumables extends SFXGUIMovieMP
    config(UI);

struct CardInfoDataSupplemental 
{
    var stringref GUIDescription;
    var stringref GUIDescription_GoBig;
};
struct ConsumableDisplayInfo 
{
    var string Title;
    var string Description;
    var string Image;
    var SFXGAWReinforcementBase CardOwner;
    var int ConsumableID;
    var int Version;
    var int Category;
    var int Count;
    var bool Disabled;
    var bool Active;
    var bool @New;
};

var array<SFXGUI_MPMatchConsumables.ConsumableDisplayInfo> ActiveConsumables;
var config array<string> InGameConsumableGUIOrder;
var config array<SFXGUI_MPMatchConsumables.CardInfoDataSupplemental> CardListSupplemental;
var SFXGAWReinforcementManager GAWManager;
var SFXGAWReinforcementMatchConsumable Consumables;
var config bool bLiveIniForPatch4AreLive;

public event function OnStart()
{
    Super(SFXGUIMovie).OnStart();
    SetGameMode(TRUE, 24); // MILAN Patched: GameMode Enum Index
    // removed this; it is handled better in the DLC class
    // SetMouseVisible(TRUE);
    SetRequiresUIWorld(TRUE);
    PlayGuiSound('MPMatchConsumablesStart');
    GAWManager = SFXGAWReinforcementManager(SFXLocalPlayer(GetPC().Player).GAWReinforcementManager);
    Consumables = GAWManager.GetUniqueMatchConsumables();
    UpdateActiveList();
    AS_RefreshScreen();
}
public final function SFXGUI_MPMatchConsumables.ConsumableDisplayInfo GetDisplayInfo(int CardID, SFXGAWReinforcementBase.CardInfoData CardData)
{
    local SFXGUI_MPMatchConsumables.ConsumableDisplayInfo DisplayInfo;
    local string CardPlayerVariableName;
    local SFXGAWReinforcementMatchConsumable ConsumablePool;
    local SFXGUI_MPMatchConsumables.CardInfoDataSupplemental DataSupplemental;
    local bool bUsingGoBigDescription;
    
    DisplayInfo.CardOwner = CardData.CardOwner;
    DisplayInfo.ConsumableID = CardID;
    DisplayInfo.Version = CardData.VersionIdx;
    SetCustomToken(0, Class'SFXWeaponUIDataManager'.static.GetRomanNumeral(CardData.VersionIdx + 1));
    DisplayInfo.Title = GetTokenisedString(CardData.GUIName);
    bUsingGoBigDescription = FALSE;
    if (Class'SFXEngine'.static.AreGoBigFeaturesEnabled() && bLiveIniForPatch4AreLive)
    {
        ConsumablePool = SFXGAWReinforcementMatchConsumable(CardData.CardOwner);
        ConsumablePool.PrepareCustomTokensForDescription(CardData.UniqueName);
        foreach CardListSupplemental(DataSupplemental, )
        {
            if (DataSupplemental.GUIDescription == CardData.GUIDescription)
            {
                DisplayInfo.Description = GetTokenisedString(DataSupplemental.GUIDescription_GoBig);
                bUsingGoBigDescription = TRUE;
                break;
            }
        }
    }
    if (!bUsingGoBigDescription)
    {
        SetCustomToken(1, string(CardData.VersionIdx + 1));
        DisplayInfo.Description = GetTokenisedString(CardData.GUIDescription);
    }
    DisplayInfo.Image = CardData.GUITextureRef;
    DisplayInfo.Category = CardData.Category;
    DisplayInfo.Disabled = !IsConsumableAvailable(CardData.CardOwner, CardID, CardData.VersionIdx, CardData.Category);
    DisplayInfo.Active = CardData.CardOwner.IsActive(CardID, float(CardData.VersionIdx));
    DisplayInfo.Count = CardData.CardOwner.GetCurrentCount(CardID, CardData.VersionIdx);
    CardPlayerVariableName = string(SFXGAWReinforcementMatchConsumable(CardData.CardOwner).GetPlayerVariableNameFromCard(CardData));
    DisplayInfo.@New = Class'SFXEngine'.static.GetSFXEngine().MPSaveManager.HasNewReinforcement(CardData.GUICategory, CardPlayerVariableName);
    return DisplayInfo;
}
public event function OnClose()
{
    local SFXSaveManagerMP MPSaveManager;
    
    MPSaveManager = SFXEngine(Class'SFXEngine'.static.GetEngine()).MPSaveManager;
    MPSaveManager.SaveLocalPRIMatchConsumablesForOfflineTransfer(GetPRIMP());
    //SetMouseVisible(FALSE);
    SetGameMode(FALSE, 24);
    // MILAN Patched: GameMode Enum Index
    Super(SFXGUIMovie).OnClose();
}
public final function ExitScreen()
{
    ClearNewFlagsForSlotType(0);
    ClearNewFlagsForSlotType(1);
    ClearNewFlagsForSlotType(2);
    ClearNewFlagsForSlotType(3);
    PlayGuiSound('MPMatchConsumablesFinish');
    Close();
    GetLobbyFlow().ShowLobbyScreen();
}
public final function SetConsumableActive(int Id, int Version, bool bActive)
{
    local SFXGUI_MPMatchConsumables.ConsumableDisplayInfo C;
    local SFXGAWReinforcementBase CardOwner;
    
    C = GetConsumable(Id, Version);
    CardOwner = C.CardOwner;
    if (bActive)
    {
        DeactivateConsumablesOfSlotType(GetSlotTypeForCategory(C.Category));
        CardOwner.Activate(Id, float(Version));
    }
    else
    {
        CardOwner.Deactivate(Id, float(Version));
    }
    UpdateActiveList();
}
public final function ShowStoreScreen()
{
    GetLobbyFlow().ShowStoreScreen();
    Close();
    GetLobbyFlow().PreviousSubScreen = ELobbySubscreen.LSS_MatchConsumables;
}
public final function UpdateActiveList()
{
    local int i;
    local SFXGAWReinforcementBase CardOwner;
    
    ActiveConsumables.Length = 0;
    if (Consumables != None)
    {
        for (i = 0; i < Consumables.CardList.Length; ++i)
        {
            CardOwner = Consumables.CardList[i].CardOwner;
            if (CardOwner.IsActive(Consumables.GetCardUniqueID(i), float(Consumables.CardList[i].VersionIdx)))
            {
                ActiveConsumables.AddItem(GetDisplayInfo(Consumables.GetCardUniqueID(i), Consumables.CardList[i]));
            }
        }
    }
}
public final function AS_RefreshScreen()
{
    ActionScriptVoid("screen.RefreshScreen");
}
public final function ClearNewFlagsForSlotType(int SlotType)
{
    local SFXSaveManagerMP MPSaveManager;
    local SFXSaveManagerMP.EReinforcementGUICategory GUICategory;
    
    GUICategory = GetGUICategoryFromSlotType(SlotType);
    if (GUICategory != EReinforcementGUICategory.EReinforcementGUICategory_None)
    {
        MPSaveManager = Class'SFXEngine'.static.GetSFXEngine().MPSaveManager;
        MPSaveManager.ClearNewReinforcementCategory(GUICategory);
    }
}
public final function DeactivateConsumablesOfSlotType(int SlotType)
{
    local int idx;
    
    for (idx = 0; idx < ActiveConsumables.Length; ++idx)
    {
        if (GetSlotTypeForCategory(ActiveConsumables[idx].Category) == SlotType)
        {
            ActiveConsumables[idx].CardOwner.Deactivate(ActiveConsumables[idx].ConsumableID, float(ActiveConsumables[idx].Version));
        }
    }
}
public final function array<SFXGUI_MPMatchConsumables.ConsumableDisplayInfo> GetActiveConsumables()
{
    return ActiveConsumables;
}
public final function SFXGUI_MPMatchConsumables.ConsumableDisplayInfo GetConsumable(int Id, int Version)
{
    local int i;
    local SFXGUI_MPMatchConsumables.ConsumableDisplayInfo DisplayInfo;
    
    if (Consumables != None)
    {
        for (i = 0; i < Consumables.CardList.Length; ++i)
        {
            if (Consumables.GetCardUniqueID(i) == Id && (Version == -1 || Consumables.CardList[i].VersionIdx == Version))
            {
                DisplayInfo = GetDisplayInfo(Consumables.GetCardUniqueID(i), Consumables.CardList[i]);
                break;
            }
        }
    }
    return DisplayInfo;
}
public final function array<SFXGUI_MPMatchConsumables.ConsumableDisplayInfo> GetConsumableList()
{
    local int i;
    local SFXGUI_MPMatchConsumables.ConsumableDisplayInfo DisplayInfo;
    local array<SFXGUI_MPMatchConsumables.ConsumableDisplayInfo> List;
    
    if (Consumables != None)
    {
        for (i = 0; i < Consumables.CardList.Length; ++i)
        {
            DisplayInfo = GetDisplayInfo(Consumables.GetCardUniqueID(i), Consumables.CardList[i]);
            List.AddItem(DisplayInfo);
        }
    }
    return List;
}
public final function array<SFXGUI_MPMatchConsumables.ConsumableDisplayInfo> GetConsumableListFilteredBySlot(int SlotIndex)
{
    local int i;
    local SFXGUI_MPMatchConsumables.ConsumableDisplayInfo DisplayInfo;
    local array<SFXGUI_MPMatchConsumables.ConsumableDisplayInfo> List;
    
    if (Consumables != None)
    {
        for (i = 0; i < Consumables.CardList.Length; ++i)
        {
            if (GetSlotTypeForCategory(Consumables.CardList[i].Category) == SlotIndex)
            {
                DisplayInfo = GetDisplayInfo(Consumables.GetCardUniqueID(i), Consumables.CardList[i]);
                if (DisplayInfo.Count > 0)
                {
                    List.AddItem(DisplayInfo);
                }
            }
        }
    }
    return List;
}
public final function SFXSaveManagerMP.EReinforcementGUICategory GetGUICategoryFromSlotType(int SlotType)
{
    switch (SlotType)
    {
        case 0:
            return 8;
        case 1:
            return 9;
        case 2:
            return 10;
        case 3:
            return 11;
        default:
    }
    return 0;
}
public final function array<SFXGUI_MPLobby.InGameConsumableInfo> GetInGameConsumableInfo()
{
    local array<SFXGUI_MPLobby.InGameConsumableInfo> InGameConsumableList;
    local SFXGUI_MPLobby.InGameConsumableInfo DisplayInfo;
    local int idx;
    local SFXEngine Engine;
    local string ConsumableClassName;
    local Class<SFXPowerCustomActionMP_Consumable> ConsumableClass;
    local Name CapacityPV;
    
    Engine = Class'SFXEngine'.static.GetSFXEngine();
    for (idx = 0; idx < InGameConsumableGUIOrder.Length; ++idx)
    {
        ConsumableClassName = InGameConsumableGUIOrder[idx];
        ConsumableClass = Class<SFXPowerCustomActionMP_Consumable>(FindObject(ConsumableClassName, Class'Class'));
        CapacityPV = ConsumableClass.default.CapacityPlayerVariable;
        DisplayInfo.ConsumableName = GetUIString(ConsumableClass.default.DisplayName);
        DisplayInfo.ConsumableCap = Engine.GetPlayerVariable(CapacityPV);
        DisplayInfo.ConsumableCount = Engine.GetPlayerVariable(Name(ConsumableClassName));
        InGameConsumableList.AddItem(DisplayInfo);
    }
    return InGameConsumableList;
}
public final function int GetMaxActiveConsumables()
{
    return Class'SFXPRIMP'.default.NumConsumablesAllowedPerMatch;
}
public final function int GetSlotTypeForCategory(int Category)
{
    return Class'SFXGAWReinforcementMatchConsumable'.static.GetSlotTypeForCategory(Category);
}
public final function bool HasNewConsumablesOfSlotType(int SlotType)
{
    local SFXSaveManagerMP MPSaveManager;
    local SFXSaveManagerMP.EReinforcementGUICategory GUICategory;
    
    GUICategory = GetGUICategoryFromSlotType(SlotType);
    if (GUICategory != EReinforcementGUICategory.EReinforcementGUICategory_None)
    {
        MPSaveManager = Class'SFXEngine'.static.GetSFXEngine().MPSaveManager;
        return MPSaveManager.HasNewReinforcementCategory(GUICategory);
    }
    else
    {
        return FALSE;
    }
}
public final function bool IsConsumableAvailable(SFXGAWReinforcementBase CardOwner, int Id, int Version, int Category)
{
    local int idx;
    
    if (CardOwner.IsActive(Id, float(Version)))
    {
        return TRUE;
    }
    for (idx = 0; idx < ActiveConsumables.Length; ++idx)
    {
        if (GetSlotTypeForCategory(ActiveConsumables[idx].Category) == GetSlotTypeForCategory(Category))
        {
            return FALSE;
        }
    }
    return TRUE;
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    InGameConsumableGUIOrder = ("SFXGameMPContent.SFXPowerCustomActionMP_Consumable_Rocket", "SFXGameMPContent.SFXPowerCustomActionMP_Consumable_Revive", "SFXGameMPContent.SFXPowerCustomActionMP_Consumable_Shield", "SFXGameMPContent.SFXPowerCustomActionMP_Consumable_Ammo")
    m_bFocusOnStart = TRUE
}