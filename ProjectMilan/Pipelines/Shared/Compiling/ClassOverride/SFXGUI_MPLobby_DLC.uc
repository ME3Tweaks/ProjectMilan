Class SFXGUI_MPLobby_DLC extends SFXGUI_MPLobby
    config(UI);

// Functions
// MILAN CHANGE DropTheSquid 12/14/2023
// adding this to make the UI dynamically swap between mouse/controller
public event function HandleButtonRefresh(bool usingGamepad)
{
    Super(SFXGUIMovie).HandleButtonRefresh(usingGamepad);
    ActionScriptVoid("screen.RefreshButtonHelp");
}
// END MILAN
public function array<MatchConsumableDisplayInfo> GetCharacterConsumableInfo_DLC(SFXPRIMP PRI)
{
    local array<MatchConsumableDisplayInfo> ConsumableData;
    local MatchConsumableDisplayInfo CurrConsumableData;
    local int idx;
    local int Idx2;
    local int CurrConsumableValue;
    local Name CurrConsumableClass;
    local SFXGAWReinforcementManager GAWManager;
    local CardInfoData CardData;
    local int GearLevel;
    
    GAWManager = SFXGAWReinforcementManager(SFXLocalPlayer(GetPC().Player).GAWReinforcementManager);
    if (AllConsumables == None && GAWManager != None)
    {
        AllConsumables = GAWManager.GetUniqueMatchConsumables();
    }
    for (idx = 0; idx < Class'SFXPRIMP'.default.NumConsumablesAllowedPerMatch; ++idx)
    {
        PRI.GetActiveMatchConsumable(idx, CurrConsumableClass, CurrConsumableValue);
        if (CurrConsumableClass == 'None')
        {
            continue;
        }
        for (Idx2 = 0; Idx2 < AllConsumables.CardList.Length; ++Idx2)
        {
            CardData = AllConsumables.CardList[Idx2];
            if (GetMatchConsumableSlotTypeForCategory(CardData.Category) == 3)
            {
                if (Name(CardData.UniqueName) == CurrConsumableClass)
                {
                    GearLevel = CurrConsumableValue;
                    SetCustomToken(0, Class'SFXWeaponUIDataManager'.static.GetRomanNumeral(GearLevel));
                    CurrConsumableData.MatchConsumableName = GetUIString(CardData.GUIName, TRUE);
                    CurrConsumableData.MatchConsumableIconRef = CardData.GUITextureRef;
                    CurrConsumableData.Category = CardData.Category;
                    ConsumableData.AddItem(CurrConsumableData);
                    break;
                }
                continue;
            }
            if (Name(CardData.UniqueName) == CurrConsumableClass && CardData.VersionIdx == CurrConsumableValue)
            {
                SetCustomToken(0, Class'SFXWeaponUIDataManager'.static.GetRomanNumeral(CardData.VersionIdx + 1));
                CurrConsumableData.MatchConsumableName = GetUIString(CardData.GUIName, TRUE);
                ClearCustomTokens();
                CurrConsumableData.MatchConsumableIconRef = CardData.GUITextureRef;
                CurrConsumableData.Category = CardData.Category;
                ConsumableData.AddItem(CurrConsumableData);
                break;
            }
        }
    }
    return ConsumableData;
}
public function PlayerDisplayInfo GetCharacterInfoDetailed_DLC(SFXPRIMP PRI)
{
    local PlayerDisplayInfo PlayerData;
    
    PlayerData = GetCharacterInfoBasic(PRI);
    PlayerData.PowerData = GetCharacterPowerInfo(PRI);
    PlayerData.WeaponData = GetCharacterWeaponInfo(PRI);
    PlayerData.MatchConsumableData = GetCharacterConsumableInfo_DLC(PRI);
    return PlayerData;
}
public final function PlayerDisplayInfo GetLocalPlayerDetailedInfo_DLC()
{
    return GetCharacterInfoDetailed_DLC(GetPRIMP());
}
public final function PlayerDisplayInfo GetPlayerSlotDetailedInfo_DLC(int Index)
{
    return GetCharacterInfoDetailed_DLC(GetPlayerInSlot(Index));
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
}