Class SFXGAWReinforcementInGameConsumable extends SFXGAWReinforcementBase
    perobjectconfig
    config(Game);

// Functions
public function bool OnAwarded(optional out CardInfoData CardInfoOut, optional const out array<CardInfoData> ChosenCards)
{
    local bool bAwarded;
    local BioWorldInfo WI;
    local BioPlayerController PC;
    local SFXPawn_Player pPawn;
    local SFXPowerManager PowerManager;
    local SFXPowerCustomActionBase Power;
    local SFXPowerCustomActionMP_Consumable ConsumablePower;
    
    bAwarded = Super.OnAwarded(CardInfoOut, ChosenCards);
    WI = BioWorldInfo(Class'WorldInfo'.static.GetWorldInfo());
    if (WI == None)
    {
        return bAwarded;
    }
    PC = BioPlayerController(WI.GetALocalPlayerController());
    if (PC == None)
    {
        return bAwarded;
    }
    pPawn = SFXPawn_Player(PC.Pawn);
    if (pPawn == None)
    {
        return bAwarded;
    }
    PowerManager = pPawn.PowerManager;
    if (PowerManager == None)
    {
        return bAwarded;
    }
    foreach PowerManager.Powers(Power, )
    {
        ConsumablePower = SFXPowerCustomActionMP_Consumable(Power);
        if (ConsumablePower == None)
        {
            continue;
        }
        if (CardInfoOut.UniqueName == PathName(ConsumablePower.Class))
        {
            ConsumablePower.AddAvailableCharges(CardInfoOut.PVIncrementBonus + 1);
        }
    }
    return bAwarded;
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
}