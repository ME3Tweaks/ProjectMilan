Class SFXGAWReinforcementInventoryUnlock extends SFXGAWReinforcementBase
    perobjectconfig
    config(Game);

// Functions
public function bool OnAwarded(optional out CardInfoData CardInfoOut, optional const out array<CardInfoData> ChosenCards)
{
    local SFXEngine Engine;
    local int CurrentValue;
    local BioPlayerController PC;
    local BioWorldInfo BWI;
    
    Engine = Class'SFXEngine'.static.GetSFXEngine();
    if (Super.OnAwarded(CardInfoOut, ChosenCards))
    {
        CurrentValue = Engine.GetPlayerVariable(Name(CardInfoOut.UniqueName));
        if (CurrentValue == 1)
        {
            Engine.MPSaveManager.AddNewReinforcement(CardInfoOut.GUICategory, CardInfoOut.UniqueName);
        }
        else if (CurrentValue > 1 && Split(CardInfoOut.UniqueName, "SFXWeapon_", TRUE) != CardInfoOut.UniqueName)
        {
            BWI = BioWorldInfo(Class'WorldInfo'.static.GetWorldInfo());
            if (BWI != None)
            {
                PC = BioPlayerController(BWI.GetALocalPlayerController());
                if (PC != None)
                {
                    PC.SetAccomplishmentProgression('WeaponLevel', CurrentValue);
                }
            }
        }
        return TRUE;
    }
    return FALSE;
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
}