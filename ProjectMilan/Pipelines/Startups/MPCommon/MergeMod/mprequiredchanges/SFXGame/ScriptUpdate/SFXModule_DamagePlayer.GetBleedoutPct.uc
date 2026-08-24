public final simulated function float GetBleedoutPct()
{
    // MILAN CHANGE: Module owner must be a human to compute the bleedout percent
    if (!Pawn(ModuleOwner).IsHumanControlled() || CurrentBleedoutState == EBleedoutState.BleedOutState_None || ModuleOwner.IsTimerActive('WaitForShieldPresentation', Self))
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