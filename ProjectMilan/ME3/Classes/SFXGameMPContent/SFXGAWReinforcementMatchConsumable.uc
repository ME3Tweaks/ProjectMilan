Class SFXGAWReinforcementMatchConsumable extends SFXGAWReinforcementBase
    perobjectconfig
    config(Game);

// Types
enum EUpgradeSlotType
{
    Slot_Ammo,
    Slot_Weapon,
    Slot_Armor,
    Slot_Gear,
};

// Functions
public function Activate(int UniqueId, float VersionIdx)
{
    local int idx;
    local SFXPRI PRI;
    
    PRI = GetPRI();
    idx = FindCardIndexFromID(UniqueId, VersionIdx);
    if (PRI != None && idx != -1)
    {
        if (PRI.Role < ENetRole.ROLE_Authority)
        {
            PRI.AddActiveMatchConsumable(CardList[idx].UniqueId, float(CardList[idx].VersionIdx));
        }
        PRI.ServerAddActiveMatchConsumable(CardList[idx].UniqueId, float(CardList[idx].VersionIdx));
    }
}
public function bool IsActive(int UniqueId, float VersionIdx)
{
    local int idx;
    local SFXPRI PRI;
    
    PRI = GetPRI();
    idx = FindCardIndexFromID(UniqueId, VersionIdx);
    if (PRI != None && idx != -1)
    {
        return PRI.IsMatchConsumableActive(CardList[idx].UniqueId, float(CardList[idx].VersionIdx));
    }
    else
    {
        return FALSE;
    }
}
public function Deactivate(int UniqueId, float VersionIdx)
{
    local int idx;
    local SFXPRI PRI;
    
    PRI = GetPRI();
    idx = FindCardIndexFromID(UniqueId, VersionIdx);
    if (PRI != None && idx != -1)
    {
        if (PRI.Role < ENetRole.ROLE_Authority)
        {
            PRI.RemoveActiveMatchConsumable(CardList[idx].UniqueId, float(CardList[idx].VersionIdx));
        }
        PRI.ServerRemoveActiveMatchConsumable(CardList[idx].UniqueId, float(CardList[idx].VersionIdx));
    }
}
public function bool ContainsCard(int UniqueId, float VersionIdx)
{
    return FindCardIndexFromID(UniqueId, VersionIdx) != -1;
}
public function int FindCardIndexFromID(int UniqueId, float VersionIdx)
{
    local int idx;
    local int CardListCount;
    
    CardListCount = CardList.Length;
    for (idx = 0; idx < CardListCount; idx++)
    {
        if (CardList[idx].UniqueId == UniqueId && float(CardList[idx].VersionIdx) == VersionIdx)
        {
            return idx;
        }
    }
    return -1;
}
public function Name GetPlayerVariableName(int idx)
{
    local Name PlayerVariableName;
    
    PlayerVariableName = Name((CardList[idx].UniqueName $ "_") $ CardList[idx].VersionIdx);
    return PlayerVariableName;
}
public function Name GetPlayerVariableNameFromCard(const out CardInfoData Card)
{
    local Name PlayerVariableName;
    
    PlayerVariableName = Name((Card.UniqueName $ "_") $ Card.VersionIdx);
    return PlayerVariableName;
}
public function SFXPRI GetPRI()
{
    local WorldInfo WI;
    local BioPlayerController PC;
    local SFXPRI PRI;
    
    WI = Class'WorldInfo'.static.GetWorldInfo();
    if (WI == None)
    {
        return None;
    }
    PC = BioPlayerController(WI.GetALocalPlayerController());
    if (PC == None)
    {
        return None;
    }
    PRI = SFXPRI(PC.PlayerReplicationInfo);
    return PRI;
}
public static function int GetSlotTypeForCategory(int Category)
{
    if (Category == 1)
    {
        return 0;
    }
    else if (Category == 2)
    {
        return 2;
    }
    else if (Category == 3)
    {
        return 1;
    }
    else if (Category == 4)
    {
        return 3;
    }
    else
    {
        return -1;
    }
}
public function bool OnAwarded(optional out CardInfoData CardInfoOut, optional const out array<CardInfoData> ChosenCards)
{
    local SFXEngine Engine;
    local Name PlayerVariable;
    local int CurrentValue;
    
    Engine = Class'SFXEngine'.static.GetSFXEngine();
    if (Super.OnAwarded(CardInfoOut, ChosenCards))
    {
        PlayerVariable = GetPlayerVariableNameFromCard(CardInfoOut);
        CurrentValue = Engine.GetPlayerVariable(PlayerVariable);
        if (CurrentValue == 1)
        {
            Engine.MPSaveManager.AddNewReinforcement(CardInfoOut.GUICategory, string(PlayerVariable));
        }
        return TRUE;
    }
    return FALSE;
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
}