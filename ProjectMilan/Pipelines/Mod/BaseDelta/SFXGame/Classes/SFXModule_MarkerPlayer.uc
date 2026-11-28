// MILAN CHANGE 09/30/2025
// By Mgamerz
// Purpose: Use our custom health subclass marker that shows color and priority
Class SFXModule_MarkerPlayer extends SFXModule_Marker
    native
    editinlinenew;

var bool PlayerIsDown;
var bool PlayerIsDead;

public event simulated function HandlePostAdd()
{
    // MILAN CHANGE - 11/25/2026 - Mgamerz
    // If player is downed re-attaching the module doesn't work so we must force it here
    local BioPawn OwnerPawn;
    local Class<SFXDamageType> DownedDamageType;

    OwnerPawn = BioPawn(ModuleOwner);
    if (OwnerPawn != None && OwnerPawn.IsInState('Downed'))
    {
        DownedDamageType = Class<SFXDamageType>(OwnerPawn.KilledByDamageType);
        PlayerIsDown = DownedDamageType == None || !DownedDamageType.default.bMPKillDamage;
    }
    // END MILAN CHANGE
    UpdatePlayerDownState(PlayerIsDown);
    Super.HandlePostAdd();
}
public simulated function UpdatePlayerDownState(bool NewPlayerIsDown)
{
    PlayerIsDown = NewPlayerIsDown;
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    MarkerType = "Player"
    // MILAN CHANGE - Use our custom health subclass version
    GUIMarkerClass = Class'SFXGUIValue_MarkerPlayerHealth'
    // END MILAN CHANGE
    bActive = TRUE
    bNetVisible = FALSE
}