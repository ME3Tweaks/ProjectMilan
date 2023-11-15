Class SFXGAWReinforcementMatchConsumable_NonGameplay extends SFXGAWReinforcementMatchConsumable
    perobjectconfig
    config(Game);

// Functions
public function Activate(int UniqueId, float VersionIdx)
{
    local int idx;
    local int CardListCount;
    local bool bFound;
    local SFXEngine Engine;
    
    Super.Activate(UniqueId, VersionIdx);
    Engine = Class'SFXEngine'.static.GetSFXEngine();
    if (Engine == None)
    {
        return;
    }
    CardListCount = CardList.Length;
    for (idx = 0; idx < CardListCount; idx++)
    {
        if (CardList[idx].UniqueId == UniqueId && float(CardList[idx].VersionIdx) == VersionIdx)
        {
            bFound = TRUE;
            break;
        }
    }
    if (!bFound)
    {
        return;
    }
    Engine.SetPlayerVariable(Name(Class'SFXEngine'.static.GetStrFromSFXUniqueID(CardList[idx].UniqueId)), CardList[idx].VersionIdx);
}
public function bool IsActive(int UniqueId, float VersionIdx)
{
    local int idx;
    local int CardListCount;
    local bool bFound;
    local SFXEngine Engine;
    
    Engine = Class'SFXEngine'.static.GetSFXEngine();
    if (Engine == None)
    {
        return FALSE;
    }
    CardListCount = CardList.Length;
    for (idx = 0; idx < CardListCount; idx++)
    {
        if (CardList[idx].UniqueId == UniqueId && float(CardList[idx].VersionIdx) == VersionIdx)
        {
            bFound = TRUE;
            break;
        }
    }
    if (!bFound)
    {
        return FALSE;
    }
    if (Engine.GetPlayerVariable(Name(Class'SFXEngine'.static.GetStrFromSFXUniqueID(CardList[idx].UniqueId))) == CardList[idx].VersionIdx)
    {
        return TRUE;
    }
    return FALSE;
}
public function Deactivate(int UniqueId, float VersionIdx)
{
    local int idx;
    local int CardListCount;
    local bool bFound;
    local SFXEngine Engine;
    
    Super.Deactivate(UniqueId, VersionIdx);
    Engine = Class'SFXEngine'.static.GetSFXEngine();
    if (Engine == None)
    {
        return;
    }
    CardListCount = CardList.Length;
    for (idx = 0; idx < CardListCount; idx++)
    {
        if (CardList[idx].UniqueId == UniqueId && float(CardList[idx].VersionIdx) == VersionIdx)
        {
            bFound = TRUE;
            break;
        }
    }
    if (!bFound)
    {
        return;
    }
    Engine.SetPlayerVariable(Name(Class'SFXEngine'.static.GetStrFromSFXUniqueID(CardList[idx].UniqueId)), 0);
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
}