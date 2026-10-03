// MILAN CHANGE - Mgamerz - 2026-09-30
// Sleeping enemy ragdolls can retain reported speed above the recovery threshold.
// Allow a valid, unfixed sleeping ragdoll on authority to recover after checking ground support.
public function bool CheckBeginRecovery()
{
    local bool bCanRecoverFromRagdoll;
    local Vector TraceEnd;
    local Vector TraceExtent;
    local bool bNothingBelow;
    local bool bSlowEnough;
    local bool bSleepingRagdoll;
    local RB_BodyInstance RootBody;

    // MILAN CHANGE - Mgamerz - 2026-09-30
    // Sleeping enemy ragdolls can retain reported speed above the recovery threshold.
    // Allow a valid, unfixed sleeping ragdoll on authority to recover after checking ground support.
    bCanRecoverFromRagdoll = FALSE;
    if (m_oPawn.IsInState('Downed') || m_oPawn.IsDead() || m_oPawn.bIsInRagdollRecovery)
    {
        bCanRecoverFromRagdoll = TRUE;
    }
    else if (m_oPawn.Role > ENetRole.ROLE_SimulatedProxy)
    {
        bSlowEnough = VSize(m_oPawn.Velocity) < m_oPawn.m_fPhysicsRecoverSpeedThreshold;
        if (m_oPawn.Role == ENetRole.ROLE_Authority && !m_oPawn.bIsAPlayer
            && m_oPawn.Physics == EPhysics.PHYS_RigidBody && m_oPawn.Mesh != None
            && m_oPawn.Mesh.PhysicsAssetInstance != None)
        {
            RootBody = m_oPawn.Mesh.GetRootBodyInstance();
            if (RootBody != None && RootBody.IsValidBodyInstance())
            {
                bSleepingRagdoll = !RootBody.IsFixed() && !m_oPawn.Mesh.RigidBodyIsAwake();
            }
        }
        if (bSlowEnough || bSleepingRagdoll)
        {
            TraceExtent = m_oPawn.GetCollisionExtent();
            TraceEnd = m_oPawn.location;
            TraceEnd.Z -= TraceExtent.Z + m_oPawn.MaxStepHeight;
            TraceExtent.Z = 1.0;
            bNothingBelow = m_oPawn.FastTrace(TraceEnd, m_oPawn.location, TraceExtent, FALSE);
            if (bNothingBelow)
            {
                // Preserve the original stationary fallback only for the original low-speed path.
                // A sleeping body above the speed threshold must have ground support to perform recovery
                if (bSlowEnough)
                {
                    if (VSizeSq(LastRecoveryLocation - m_oPawn.location) > 10000.0)
                    {
                        LastRecoveryLocation = m_oPawn.location;
                        LastRecoveryAttemptTime = m_oPawn.WorldInfo.GameTimeSeconds;
                    }
                    else if (m_oPawn.WorldInfo.GameTimeSeconds - LastRecoveryAttemptTime > 1.0)
                    {
                        bCanRecoverFromRagdoll = TRUE;
                    }
                }
            }
            else
            {
                bCanRecoverFromRagdoll = TRUE;
            }
        }
    }
    // END MILAN CHANGE
    if (bCanRecoverFromRagdoll)
    {
        m_oPawn.StopVocalization();
        bHeldInRagdoll = FALSE;
        m_oPawn.ClearTimer('CheckBeginRecovery', Self);
        m_oPawn.ClearTimer('PlayScream', Self);
        m_oPawn.ClearTimer('RestartScream', Self);
        m_oPawn.ClearTimer('RegisterRagdollVocCallback', Self);
        m_oPawn.ClearRBCallbacks();
        m_oPawn.DecrementRagdollCount();
        if (m_oPawn.Role != ENetRole.ROLE_Authority)
        {
            while (m_oPawn.m_nRemainInRagdoll > 0)
            {
                m_oPawn.DecrementRagdollCount();
            }
        }
        m_oPawn.SetTimer(0.100000001, TRUE, 'CheckEndRecovery', Self);
        return TRUE;
    }
    return FALSE;
}
