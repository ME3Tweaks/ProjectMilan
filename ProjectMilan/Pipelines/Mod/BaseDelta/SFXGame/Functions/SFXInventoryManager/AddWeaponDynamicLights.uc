// MILAN CHANGE - Mgamerz - 2026-10-16
// Run per-pawn flashlight setup/teardown on simulated clients as well as the host.
public final simulated function AddWeaponDynamicLights(Light oLight, optional Light oAmbientLight, optional RvrClientEffectInterface CE_WeaponEffect = None)
{
    local SpotLightComponent oSpotLightComp;
    local SFXWeapon Weapon;
    
    if (bFlashlightAttached || Instigator == None || oLight == None || oLight.LightComponent == None)
    {
        return;
    }
    bFlashlightAttached = TRUE;
    if (oAmbientLight != None && oAmbientLight.LightComponent != None)
    {
        AttachedAmbientLight = oAmbientLight;
        AmbientLightCachedBrightness = oAmbientLight.LightComponent.Brightness;
        AmbientLightCachedColor = oAmbientLight.LightComponent.LightColor;
    }
    if (oLight != None)
    {
        AttachedFlashlight = oLight;
        AttachedFlashlightVFX = CE_WeaponEffect;
        oSpotLightComp = SpotLightComponent(oLight.LightComponent);
        if (oSpotLightComp != None)
        {
            FlashlightCachedBrightness = oSpotLightComp.Brightness;
            FlashlightCachedColor = oSpotLightComp.LightColor;
            FlashlightCachedRadius = oSpotLightComp.OuterConeAngle;
        }
        Weapon = SFXWeapon(Instigator.Weapon);
        if (Weapon != None)
        {
            Weapon.AttachFlashlight();
        }
    }
}
// END MILAN CHANGE
