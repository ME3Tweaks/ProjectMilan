Class SFXPowerCustomActionMP_Consumable extends SFXPowerCustomAction
    abstract
    config(Game);

// Variables
var Name CapacityPlayerVariable;
var int UsedCount;
var int CapacityBonus;

// Functions
public function bool CanUsePower(Actor oTarget)
{
    local SFXAI_Core AutobotAI;
    
    if (m_oPawn.Controller.IsLocalPlayerController() && !HasCharges())
    {
        return FALSE;
    }
    AutobotAI = SFXAI_Core(m_oPawn.Controller);
    if (AutobotAI != None && AutobotAI.bIsAutoBot == TRUE)
    {
        return FALSE;
    }
    return Super.CanUsePower(oTarget);
}
public event function string GetHUDWheelIconInfo()
{
    return string(GetChargeCount());
}
public event function bool ShouldUsePower(Actor Target, out string sOptionalInfo)
{
    if (!m_oPawn.Controller.IsLocalPlayerController())
    {
        return TRUE;
    }
    return CanUsePower(Target);
}
public function OnPowersLoaded()
{
    Super(SFXPowerCustomActionBase).OnPowersLoaded();
    Rank = default.Rank;
}
public simulated function AddAvailableCharges(int Quantity)
{
    CapacityBonus += Quantity;
}
public final simulated function int GetChargeCount()
{
    local SFXEngine Engine;
    local int MatchMax;
    local int ChargeCount;
    local int TotalConsumables;
    
    Engine = Class'SFXEngine'.static.GetSFXEngine();
    if (Engine == None)
    {
        return 0;
    }
    MatchMax = Engine.GetPlayerVariable(CapacityPlayerVariable) + CapacityBonus;
    ChargeCount = MatchMax - UsedCount;
    TotalConsumables = Engine.GetPlayerVariable(Name(PathName(Class)));
    ChargeCount = Min(ChargeCount, TotalConsumables);
    return ChargeCount;
}
public final simulated function bool HasCharges()
{
    local SFXEngine Engine;
    local bool bHasCharges;
    local int TotalConsumables;
    local int MaxPerMatch;
    
    Engine = Class'SFXEngine'.static.GetSFXEngine();
    if (Engine == None)
    {
        return FALSE;
    }
    TotalConsumables = Engine.GetPlayerVariable(Name(PathName(Class)));
    MaxPerMatch = Engine.GetPlayerVariable(CapacityPlayerVariable) + CapacityBonus;
    if (TotalConsumables > 0 && UsedCount < MaxPerMatch)
    {
        bHasCharges = TRUE;
    }
    return bHasCharges;
}
public final simulated function UseConsumable()
{
    local SFXPlayerController PC;
    local SFXEngine Engine;
    local int CurrentCharges;
    
    if (!m_oPawn.Controller.IsLocalPlayerController())
    {
        return;
    }
    Engine = Class'SFXEngine'.static.GetSFXEngine();
    if (Engine == None)
    {
        return;
    }
    CurrentCharges = Engine.GetPlayerVariable(Name(PathName(Class))) - 1;
    Engine.SetPlayerVariable(Name(PathName(Class)), CurrentCharges);
    UsedCount++;
    PC = SFXPlayerController(m_oPawn.Controller);
    if (PC != None)
    {
        PC.UpdateInGameConsumableUI();
    }
    Class'SFXTelemetryHooksMP'.static.SendConsumable(Class, CurrentCharges, UsedCount);
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    Discipline = EBioCapMode.BIO_CAPMODE_COMBAT
    RankCosts = ()
    Rank = 1.0
    UsesSharedCooldown = FALSE
    DisplayInCharacterRecord = FALSE
    PowerType = EPowerType.PowerType_Buff
}