// Source: ME3, Patch_SFXAI_ProtectorDrone
// Decompiled 11/17/2026 7:37:40 AM against BioD_Gth002_210Tower.pcc
Class SFXAI_ProtectorDrone extends SFXAI_Core
    placeable
    config(AI);

var(SFXAI_ProtectorDrone) Object.Vector2D MoveTime;
var(SFXAI_ProtectorDrone) float TotalMoveTime;
var(SFXAI_ProtectorDrone) float MoveTimeout;

public event function BioClearCrossLevelReferences(Level ClearedLevel)
{
    local SFXPawn_ProtectorDroneBase Drone;
    
    Super.BioClearCrossLevelReferences(ClearedLevel);
    Drone = SFXPawn_ProtectorDroneBase(Pawn);
    if (Drone != None && Drone.Caster != None && Drone.Caster.Outer == ClearedLevel)
    {
        Drone.OnDroneKilled = None;
        Drone.Caster = None;
    }
}
public function PeriodicMoveCheck()
{
    Super.PeriodicMoveCheck();
    TotalMoveTime += GetPeriodicMoveInterval();
    if (TotalMoveTime >= MoveTimeout)
    {
        MoveTarget = None;
        bReachedMoveGoal = TRUE;
    }
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    MoveTime = {X = 2.0, Y = 4.0}
    DefaultCommand = Class'SFXAICmd_Base_ProtectorDrone'
}