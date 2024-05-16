// From: Enemy Ragdoll Fix (by Mgamerz)
// Purpose: Fixes enemies ragdolling and never recovering
// 05/11/2024 
public event simulated function BeginState(Name PreviousStateName)
{
    Super(Object).BeginState(PreviousStateName);
    LastPhysicsSetter = None;
    if (ShouldDieOnRagdoll())
    {
        Died(None, Class'SFXDamageType_Suicide', location);
    }
}