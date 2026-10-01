public final simulated function float GetBleedoutPct()
{
    // MILAN CHANGE: Module owner must be a human to compute the bleedout percent
    // 09/30/2026 - Mgamerz - Also add IsLocallyControlled() to prevent clients from affecting the host
    if (!Pawn(ModuleOwner).IsHumanControlled() || !Pawn(ModuleOwner).IsLocallyControlled() || CurrentBleedoutState == EBleedoutState.BleedOutState_None || ModuleOwner.IsTimerActive('WaitForShieldPresentation', Self))
    {
        return 0.0;
    }
    HealthRatio = GetHealthRatio();
    if (1.0 - HealthRatio <= BleedoutStartThreshold)
    {
        return InitialBleedoutPct;
    }
    return 1.0 - HealthRatio;
}