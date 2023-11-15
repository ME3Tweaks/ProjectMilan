Class SFXGAWReinforcementKitUnlock extends SFXGAWReinforcementBase
    perobjectconfig
    config(Game);

// Variables
var config array<int> XPBonus;

// Functions
public function bool OnAwarded(optional out CardInfoData CardInfoOut, optional const out array<CardInfoData> ChosenCards)
{
    local SFXSaveManagerMP MPSaveManager;
    local Name className;
    local MPKitData KitData;
    local int CurrentValue;
    
    if (Super.OnAwarded(CardInfoOut, ChosenCards))
    {
        MPSaveManager = SFXEngine(Class'Engine'.static.GetEngine()).MPSaveManager;
        KitData = MPSaveManager.GetKitData(Name(CardInfoOut.UniqueName));
        CurrentValue = MPSaveManager.GetPlayerVariable(Name(CardInfoOut.UniqueName));
        if (CurrentValue <= KitData.MaxNewUnlockLevel)
        {
            MPSaveManager.AddNewReinforcement(13, CardInfoOut.UniqueName);
        }
        if (CurrentValue == 1)
        {
            MPSaveManager.AddNewReinforcement(CardInfoOut.GUICategory, CardInfoOut.UniqueName);
        }
        if (CardInfoOut.VersionIdx < XPBonus.Length)
        {
            CardInfoOut.StringToken = XPBonus[CardInfoOut.VersionIdx];
            className = KitData.BaseMPClassName;
            MPSaveManager.LevelUpClass(className, float(XPBonus[CardInfoOut.VersionIdx]));
        }
        return TRUE;
    }
    return FALSE;
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    XPBonus = (12500, 50000, 100000)
}