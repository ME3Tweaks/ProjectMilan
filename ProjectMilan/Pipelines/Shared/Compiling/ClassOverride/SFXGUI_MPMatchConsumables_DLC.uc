Class SFXGUI_MPMatchConsumables_DLC extends SFXGUI_MPMatchConsumables
    config(UI);

// Functions
// MILAN CHANGE DropTheSquid 12/14/2023
// adding this to make the UI dynamically swap between mouse/controller
public event function HandleButtonRefresh(bool usingGamepad)
{
    Super(SFXGUIMovie).HandleButtonRefresh(usingGamepad);
	SetMouseVisible(!usingGamepad);
    ActionScriptVoid("screen.RefreshButtonHelp");
}
// END MILAN
public event function OnStart()
{
    Super(SFXGUIMovie).OnStart();
    SetGameMode(TRUE, 24); // MILAN Patched: GameMode Enum Index
	// MILAN Change DropTheSquid 10/31/2026
	// make sure the mouse is initially shown/hidden based on the input mode, updated to prevent the mouse briefly flickering
	SetMouseVisible(!IsUsingGamepad());
    // END MILAN
    SetRequiresUIWorld(TRUE);
    PlayGuiSound('MPMatchConsumablesStart');
    GAWManager = SFXGAWReinforcementManager(SFXLocalPlayer(GetPC().Player).GAWReinforcementManager);
    Consumables = GAWManager.GetUniqueMatchConsumables();
    UpdateActiveList_DLC();
    AS_RefreshScreen();
}
public function ConsumableDisplayInfo GetConsumable_DLC(int Id, int Version)
{
    local int i;
    local ConsumableDisplayInfo DisplayInfo;
    
    if (Consumables != None)
    {
        for (i = 0; i < Consumables.CardList.Length; ++i)
        {
            if (Consumables.GetCardUniqueID(i) == Id && (Version == -1 || Consumables.CardList[i].VersionIdx == Version))
            {
                DisplayInfo = GetDisplayInfo_DLC(Consumables.GetCardUniqueID(i), Consumables.CardList[i]);
                break;
            }
        }
    }
    return DisplayInfo;
}
public function array<ConsumableDisplayInfo> GetConsumableList_DLC()
{
    local int i;
    local ConsumableDisplayInfo DisplayInfo;
    local array<ConsumableDisplayInfo> List;
    
    if (Consumables != None)
    {
        for (i = 0; i < Consumables.CardList.Length; ++i)
        {
            DisplayInfo = GetDisplayInfo_DLC(Consumables.GetCardUniqueID(i), Consumables.CardList[i]);
            List.AddItem(DisplayInfo);
        }
    }
    return List;
}
public function array<ConsumableDisplayInfo> GetConsumableListFilteredBySlot_DLC(int SlotIndex)
{
    local int i;
    local ConsumableDisplayInfo DisplayInfo;
    local array<ConsumableDisplayInfo> List;
    
    if (Consumables != None)
    {
        for (i = 0; i < Consumables.CardList.Length; ++i)
        {
            if (GetSlotTypeForCategory(Consumables.CardList[i].Category) == SlotIndex)
            {
                DisplayInfo = GetDisplayInfo_DLC(Consumables.GetCardUniqueID(i), Consumables.CardList[i]);
                if (DisplayInfo.Count > 0)
                {
                    List.AddItem(DisplayInfo);
                }
            }
        }
    }
    return List;
}
public function ConsumableDisplayInfo GetDisplayInfo_DLC(int CardID, CardInfoData CardData)
{
    if (GetSlotTypeForCategory(CardData.Category) == 3)
    {
        return GetDisplayInfo_Gear(CardID, CardData);
    }
    else
    {
        return GetDisplayInfo(CardID, CardData);
    }
}
public function ConsumableDisplayInfo GetDisplayInfo_Gear(int CardID, CardInfoData CardData)
{
    local ConsumableDisplayInfo DisplayInfo;
    local string CardPlayerVariableName;
    local SFXGAWReinforcementMatchConsumable_Gear GearPool;
    local int GearLevel;
    
    DisplayInfo.CardOwner = CardData.CardOwner;
    DisplayInfo.ConsumableID = CardID;
    DisplayInfo.Version = CardData.VersionIdx;
    DisplayInfo.Image = CardData.GUITextureRef;
    DisplayInfo.Category = CardData.Category;
    DisplayInfo.Disabled = !IsConsumableAvailable(CardData.CardOwner, CardID, CardData.VersionIdx, CardData.Category);
    DisplayInfo.Active = CardData.CardOwner.IsActive(CardID, float(CardData.VersionIdx));
    DisplayInfo.Count = CardData.CardOwner.GetCurrentCount(CardID, CardData.VersionIdx);
    GearLevel = DisplayInfo.Count;
    if (GearLevel > 0)
    {
        SetCustomToken(0, Class'SFXWeaponUIDataManager'.static.GetRomanNumeral(GearLevel));
        DisplayInfo.Title = GetTokenisedString(CardData.GUIName);
        GearPool = SFXGAWReinforcementMatchConsumable_Gear(CardData.CardOwner);
        GearPool.PrepareCustomTokensForGearDescription(CardData.UniqueName, GearLevel);
        DisplayInfo.Description = GetTokenisedString(CardData.GUIDescription);
    }
    CardPlayerVariableName = string(SFXGAWReinforcementMatchConsumable(CardData.CardOwner).GetPlayerVariableNameFromCard(CardData));
    DisplayInfo.New = Class'SFXEngine'.static.GetSFXEngine().MPSaveManager.HasNewReinforcement(CardData.GUICategory, CardPlayerVariableName);
    return DisplayInfo;
}
public function SetConsumableActive_DLC(int Id, int Version, bool bActive)
{
    local ConsumableDisplayInfo C;
    local SFXGAWReinforcementBase CardOwner;
    
    C = GetConsumable_DLC(Id, Version);
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
    UpdateActiveList_DLC();
}
public function UpdateActiveList_DLC()
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
                ActiveConsumables.AddItem(GetDisplayInfo_DLC(Consumables.GetCardUniqueID(i), Consumables.CardList[i]));
            }
        }
    }
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
}
