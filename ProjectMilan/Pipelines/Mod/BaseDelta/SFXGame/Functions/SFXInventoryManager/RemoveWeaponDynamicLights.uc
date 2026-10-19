// MILAN CHANGE - Mgamerz - 2026-10-16
// Run per-pawn flashlight setup/teardown on simulated clients as well as the host.
public final simulated function RemoveWeaponDynamicLights()
{
    local SFXWeapon Weapon;
    
    if (!bFlashlightAttached)
    {
        return;
    }
    bFlashlightAttached = FALSE;
    if (Instigator != None)
    {
        Weapon = SFXWeapon(Instigator.Weapon);
    }
    if (Weapon != None)
    {
        Weapon.DetachFlashlight();
    }
    if (AttachedAmbientLight != None)
    {
        AttachedAmbientLight.bEnabled = FALSE;
        if (AttachedAmbientLight.LightComponent != None)
        {
            AttachedAmbientLight.LightComponent.SetEnabled(FALSE);
        }
        AttachedAmbientLight = None;
    }
    if (AttachedFlashlight != None)
    {
        AttachedFlashlight.bEnabled = FALSE;
        if (AttachedFlashlight.LightComponent != None)
        {
            AttachedFlashlight.LightComponent.SetEnabled(FALSE);
        }
        AttachedFlashlight = None;
    }
    AttachedFlashlightVFX = None;
}
// END MILAN CHANGE
