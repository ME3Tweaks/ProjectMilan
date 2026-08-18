public function float ViewFriction(float DeltaTime, SFXWeapon Weapon)
{
    local BioPawn FrictionTarget;
    local Vector CamLoc;
    local Vector X;
    local Vector Y;
    local Vector Z;
    local Rotator CamRot;
    local float FrictionMultiplier;
    local float FrictionPlayerConfig;
    
    if (Outer.Pawn == None || Weapon.bFrictionEnabled == FALSE)
    {
        return 0.0;
    }
    Outer.GetPlayerViewPoint(CamLoc, CamRot);
    GetAxes(CamRot, X, Y, Z);
    FrictionTarget = BioPawn(CurrentAimAssistTarget);
    if (FrictionTarget != None && CurrentAimAssistSoftMargin > float(0))
    {
        FrictionMultiplier = GetRangeValueByPct(Weapon.FrictionMultiplierRange, CurrentAimAssistSoftMargin) * GlobalFrictionFactor * AAProfileFrictionValue;
        if (Weapon.IsZoomed())
        {
            FrictionMultiplier *= Weapon.AimModes[Weapon.CurrentAimMode].FrictionMultiplier * AAProfileFrictionValue;
        }
    }
    else
    {
        FrictionMultiplier = 0.0;
    }
    FrictionSmoothValue = Lerp(FrictionSmoothValue, FrictionMultiplier, 1.0 - (float(1) - FrictionSmoothRate) ** DeltaTime);
    FrictionMultiplier = FrictionSmoothValue;
    if (FrictionMultiplier > 0.0)
    {
        LastFrictionTarget = FrictionTarget;
    }
    LastFrictionMultiplier = FrictionMultiplier;
    LastCamLoc = CamLoc;
    return FrictionMultiplier;
}