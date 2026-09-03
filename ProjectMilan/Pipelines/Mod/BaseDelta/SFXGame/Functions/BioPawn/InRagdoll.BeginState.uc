public event simulated function BeginState(Name PreviousStateName)
{
    Super(Object).BeginState(PreviousStateName);
    LastPhysicsSetter = None;
    if (ShouldDieOnRagdoll())
    {
        Died(None, Class'SFXDamageType_Suicide', location);
    }
    // MILAN CHANGE 08/30/2026 - Mgamerz
    // Remove this new code added in LE that breaks ragdoll recovery for non-player characters
    // It is not present in the original game code, only added in the LE version
    //else if (!bIsAPlayer && Role == ENetRole.ROLE_Authority)
    //{
    //    bIsInRagdollRecovery = FALSE;
    //}
}