Class SFXGAWReinforcementCredits extends SFXGAWReinforcementUnsaved
    perobjectconfig
    config(Game);

// Functions
public function bool OnAwarded(optional out CardInfoData CardInfoOut, optional const out array<CardInfoData> ChosenCards)
{
    local SFXSaveManagerMP MPSaveManager;
    
    if (Super(SFXGAWReinforcementBase).OnAwarded(CardInfoOut, ChosenCards))
    {
        MPSaveManager = SFXEngine(Class'Engine'.static.GetEngine()).MPSaveManager;
        MPSaveManager.AddCredits(CardInfoOut.PVIncrementBonus, "card");
        CardInfoOut.PVIncrementBonus -= 1;
        return TRUE;
    }
    return FALSE;
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
}