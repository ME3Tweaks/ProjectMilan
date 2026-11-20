// Source: ME3, Patch_SFXAI_CombatDrone
// Decompiled 11/17/2026 7:37:38 AM against BIOP_MP_COMMON.pcc
Class SFXAI_CombatDrone extends SFXAI_Core
    placeable
    config(AI);

var(SFXAI_CombatDrone) Object.Vector2D MoveTime;
var(SFXAI_CombatDrone) float TotalMoveTime;
var(SFXAI_CombatDrone) float MoveTimeout;

public event function BioClearCrossLevelReferences(Level ClearedLevel)
{
    local SFXPawn_CombatDroneBase Drone;
    
    Super.BioClearCrossLevelReferences(ClearedLevel);
    Drone = SFXPawn_CombatDroneBase(Pawn);
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
    DefaultCommand = Class'SFXAICmd_Base_CombatDrone'
}