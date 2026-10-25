// MILAN CHANGE 
// By Mgamerz
// Add custom MilanPowerTargetInterpActor so we can have triggerable things in levels
public function bool CanImpactActor(Actor oActor)
{
    if (oActor == None)
    {
        WarnInternal("Check impact against NULL actor");
        return FALSE;
    }
    // MILAN CHANGE 10/23/2026 - Mgamerz
    // Add custom milan class
    if (oActor.IsA('Pawn') || oActor.IsA('KActor') || oActor.IsA('SFXPlaceable') || oActor.IsA('MilanPowerTargetInterpActor'))
    // END MILAN CHANGE
    {
        if (oActor.CollisionComponent != None && oActor.CollisionType != ECollisionType.COLLIDE_NoCollision)
        {
            return TRUE;
        }
    }
    return FALSE;
}
