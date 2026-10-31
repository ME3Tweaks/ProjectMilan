public simulated function PlayDying(Class<DamageType> DamageType, Vector HitLoc)
{
    local SFXPowerCustomActionBase Power;
    local SFXModule_Damage DmgModule;

    // MILAN CHANGE - Mgamerz - 2026-10-30
    // Apply ragdoll rules for pawns that normally can't
    if (!bCanRagdoll && Class'MilanRagdollRules'.static.ShouldForceDeathRagdoll(DamageType))
    {
        bCanRagdoll = TRUE;
    }
    // END MILAN CHANGE
    DmgModule = GetModule(Class'SFXModule_Damage');
    if (DmgModule != None)
    {
        DmgModule.SetCurrentHealth(0.0);
    }
    if (Squad != None)
    {
        Squad.RemoveDyingMember(Self);
    }
    ScaleLimitTimeToGo = 1.0;
    GotoState('Dying', , , );
    if (!InitRagdoll())
    {
        WarnInternal("BioPawn" @ Self @ "failed InitRagdoll in PlayDying.");
    }
    Mesh.AddImpulse(TearOffMomentum, HitLoc, DeathHitBoneName);
    bReplicateMovement = FALSE;
    bTearOff = TRUE;
    Velocity += TearOffMomentum;
    bPlayedDeath = TRUE;
    if (!bCollidesAfterDeath)
    {
        Mesh.SetRBChannel(16);
        Mesh.SetRBCollidesWithChannel(2, FALSE);
    }
    TimeOfDeath = WorldInfo.GameTimeSeconds;
    ManageRagdolls();
    m_bEnableRagdollRecovery = FALSE;
    if (!IsPlayerPawn())
    {
        InterruptCustomAction();
    }
    RemoveLifeTimeCrust();
    if (PowerManager != None)
    {
        foreach PowerManager.Powers(Power, )
        {
            Power.OnOwnerDied();
        }
    }
    bIsDead = TRUE;
}
