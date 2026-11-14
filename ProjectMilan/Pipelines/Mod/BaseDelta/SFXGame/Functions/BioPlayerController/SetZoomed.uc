// MILAN CHANGE - 11/14/2026 - Mgamerz
// Add null guards
public event function SetZoomed(bool bZoomState)
{
    local SFXWeapon Weapon;
    local SFXModule_AimAssist AimAssist;

    // MILAN CHANGE - null guard
    if (Pawn != None)
    {
        Weapon = SFXWeapon(Pawn.Weapon);
    }
    // END MILAN CHANGE
    if (Weapon != None)
    {
        Weapon.SetZoomed(bZoomState);
    }
    // MILAN CHANGE - null guard
    if (PlayerInput != None && PlayerInput.bUsingGamepad)
    // END MILAN CHANGE
    {
        AimAssist = GetModule(Class'SFXModule_AimAssist');
        if (AimAssist != None)
        {
            if (bZoomState)
            {
                AimAssist.ZoomSnap();
            }
            else
            {
                AimAssist.LastZoomSnapTarget = None;
            }
        }
    }
    // MILAN CHANGE - null guard
    if (BioPawn(Pawn) != None)
    {
        BioPawn(Pawn).bIsSniping = bZoomState;
    }
    // END MILAN CHANGE
}
