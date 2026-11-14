public function Rotator GetAdjustedAimFor(Weapon W, Vector StartFireLoc)
{
    local SFXModule_AimAssist AimAssist;

    AimAssist = GetModule(Class'SFXModule_AimAssist');
    // MILAN CHANGE - 11/14/2026 - Mgamerz
    // Add null guards and remove console build check
    if (PlayerInput != None && PlayerInput.bUsingGamepad)
    // END MILAN CHANGE
    {
        if (AimAssist != None && IsZoomed())
        {
            return AimAssist.GetAdjustedAimFor(W, StartFireLoc);
        }
    }
    return Pawn != None ? Pawn.GetBaseAimRotation() : Rotation;
}
