Class SFXGAWReinforcementBase
    perobjectconfig
    config(Game);

// Types
struct CardInfoData 
{
    var string UniqueName;
    var string GUIType;
    var string GUITextureRef;
    var transient string PoolName;
    var transient int UniqueId;
    var int MaxCount;
    var stringref GUIName;
    var stringref GUIDescription;
    var int GUIIconIndex;
    var int PVIncrementBonus;
    var int VersionIdx;
    var int Category;
    var int LevelAwarded;
    var transient int StringToken;
    var SFXGAWReinforcementBase CardOwner;
    var int Entitlement;
    var bool bUseVersionIdx;
    var ECardRarity Rarity;
    var EReinforcementGUICategory GUICategory;
    
    structdefaultproperties
    {
        Entitlement = -1
        Rarity = None
    }
};
enum ECardRarity
{
    Rarity_Common,
    Rarity_Uncommon,
    Rarity_Rare,
    Rarity_UltraRare,
};

// Variables
var config string PoolName;
var config array<CardInfoData> CardList;
var config array<int> RequiredDLCModuleIDs;
var SFXGAWReinforcementManager GAWManager;

// Functions
public function Activate(int UniqueId, float VersionIdx);

public function Initialize()
{
    local int idx;
    
    for (idx = 0; idx < CardList.Length; idx++)
    {
        GenerateCardUniqueID(idx);
    }
}
public function bool IsActive(int UniqueId, float VersionIdx)
{
    return FALSE;
}
public function Deactivate(int UniqueId, float VersionIdx);

public static function ConsumeNonGameplayConsumable(Name UniqueName, int VersionIdx)
{
    local SFXEngine Engine;
    local int CurrentValue;
    local Name ConsumableCountPV;
    
    Engine = Class'SFXEngine'.static.GetSFXEngine();
    ConsumableCountPV = Name((UniqueName $ "_") $ VersionIdx);
    CurrentValue = Engine.GetPlayerVariable(ConsumableCountPV);
    CurrentValue = Max(0, CurrentValue - 1);
    Engine.SetPlayerVariable(ConsumableCountPV, CurrentValue);
}
public function GenerateCardUniqueID(int idx)
{
    CardList[idx].UniqueId = Class'SFXEngine'.static.GetSFXUniqueIDFromStr(CardList[idx].UniqueName);
}
public function int GetCardUniqueID(int idx)
{
    return CardList[idx].UniqueId;
}
public function int GetCurrentCount(int SearchUniqueID, optional int VersionIdx = -1)
{
    local int currentCount;
    local int idx;
    local int CardListCount;
    local SFXEngine Engine;
    
    Engine = Class'SFXEngine'.static.GetSFXEngine();
    if (Engine == None)
    {
        return -1;
    }
    CardListCount = CardList.Length;
    for (idx = 0; idx < CardListCount; idx++)
    {
        if (CardList[idx].UniqueId == SearchUniqueID)
        {
            if (VersionIdx == -1 || CardList[idx].VersionIdx == VersionIdx)
            {
                break;
            }
        }
    }
    if (idx >= CardListCount)
    {
        return -1;
    }
    currentCount = Engine.GetPlayerVariable(GetPlayerVariableName(idx));
    return currentCount;
}
public function int GetCurrentValue(Name VarName)
{
    return Class'SFXEngine'.static.GetSFXEngine().GetPlayerVariable(VarName);
}
public function Name GetPlayerVariableName(int idx)
{
    return Name(Class'SFXEngine'.static.GetStrFromSFXUniqueID(CardList[idx].UniqueId));
}
public function Name GetPlayerVariableNameFromCard(const out CardInfoData Card)
{
    return Name(Class'SFXEngine'.static.GetStrFromSFXUniqueID(Card.UniqueId));
}
public function bool OnAwarded(optional out CardInfoData CardInfoOut, optional const out array<CardInfoData> ChosenCards)
{
    local int CurrentValue;
    local int idx;
    local array<CardInfoData> SubCardPool;
    local bool bCardFound;
    local BWEntitlementId eID;
    local Name PlayerVariable;
    
    if (CardList.Length < 1)
    {
        return FALSE;
    }
    SubCardPool = CardList;
    while (bCardFound == FALSE && SubCardPool.Length > 0)
    {
        idx = Rand(SubCardPool.Length);
        CardInfoOut = SubCardPool[idx];
        PlayerVariable = GetPlayerVariableNameFromCard(CardInfoOut);
        CurrentValue = GetCurrentValue(PlayerVariable);
        if (ChosenCards.Find('UniqueName', CardInfoOut.UniqueName) != -1)
        {
            SubCardPool.RemoveItem(SubCardPool[idx]);
            continue;
        }
        if (GAWManager.PopulateCardData(CardInfoOut) == FALSE)
        {
            SubCardPool.RemoveItem(SubCardPool[idx]);
            continue;
        }
        if (CardInfoOut.MaxCount != 0 && CurrentValue >= CardInfoOut.MaxCount)
        {
            SubCardPool.RemoveItem(SubCardPool[idx]);
            continue;
        }
        bCardFound = TRUE;
        break;
    }
    if (!bCardFound)
    {
        return FALSE;
    }
    if (CardInfoOut.Entitlement >= 0)
    {
        eID.nID = CardInfoOut.Entitlement;
        Class'SFXOnlineSubsystem'.static.GetOnlineSubsystem().GetComponentCommerce().GrantEntitlementId(eID);
    }
    if (CardInfoOut.MaxCount <= 0)
    {
        CurrentValue = (CurrentValue + 1) + CardInfoOut.PVIncrementBonus;
    }
    else
    {
        CurrentValue = Min(CardInfoOut.MaxCount, (CurrentValue + 1) + CardInfoOut.PVIncrementBonus);
    }
    SetCurrentValue(PlayerVariable, CurrentValue);
    CardInfoOut.LevelAwarded = CurrentValue;
    return TRUE;
}
public function SetCurrentValue(Name VarName, int Value)
{
    Class'SFXEngine'.static.GetSFXEngine().SetPlayerVariable(VarName, Value);
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
}