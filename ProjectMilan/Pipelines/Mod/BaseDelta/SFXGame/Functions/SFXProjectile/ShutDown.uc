public simulated function ShutDown()
{
    local SFXProjectile_Explosive Explosive;

    if (bShuttingDown)
    {
        return;
    }
    // MILAN CHANGE - Mgamerz - 2026-10-28
    // Disable the light effect on the explosive which prevents cleanup off host
    Explosive = SFXProjectile_Explosive(Self);
    if (bClientPredictionActive && bEffectLightActive && Explosive != None)
    {
        Explosive.DisableLight();
    }
    // END MILAN CHANGE
    if (bClientPredictionActive)
    {
        SetPrediction(FALSE, FALSE);
    }
    bShuttingDown = TRUE;
    SetCollision(FALSE, FALSE);
    SetProjectileHidden(TRUE);
    SetPhysics(7);
    if (ProjEffectsHead != None)
    {
        ProjEffectsHead.SetActive(FALSE);
    }
    if (ProjEffectsTrail != None && ProjEffectsTrail.bIsActive)
    {
        ProjEffectsTrail.SetActive(FALSE);
        SetTimer(ProjEffectsTrailWaitTime, FALSE, 'ShutdownPostEffects');
        LifeSpan = 0.0;
    }
    else
    {
        ShutdownPostEffects();
    }
}
