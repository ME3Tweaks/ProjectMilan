public final simulated function DecrementRagdollCount()
{
    if (m_nRemainInRagdoll == 0)
    {
        LogInternal("Ragdoll count out of sync!");
        // MILAN DEBUG - ragdoll trace
        LogInternal("[RAGDOLL] DecrementRagdollCount OUT OF SYNC" @ Self @ "t=" $ WorldInfo.TimeSeconds @ "role=" $ int(Role) @ "state=" $ GetStateName());
        ScriptTrace();
    }
    else
    {
        m_nRemainInRagdoll--;
        // MILAN DEBUG - ragdoll trace
        LogInternal("[RAGDOLL] DecrementRagdollCount" @ Self @ "t=" $ WorldInfo.TimeSeconds @ "role=" $ int(Role) @ "state=" $ GetStateName()
            @ "count=" $ m_nRemainInRagdoll @ "ca=" $ CurrentCustomAction);
    }
}
