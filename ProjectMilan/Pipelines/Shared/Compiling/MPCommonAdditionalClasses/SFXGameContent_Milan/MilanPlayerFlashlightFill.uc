// MILAN CHANGE - Mgamerz - 2026-10-16
// A separate, local fill-light instance for each MP pawn; movable point lights must be spawnable.
Class MilanPlayerFlashlightFill extends PointLightMovable;

defaultproperties
{
    Begin Template Class=PointLightComponent Name=PointLightComponent0
        bEnabled = FALSE
        Brightness = 0.2
        Radius = 460.0
        FalloffExponent = 2.0
        LightColor = {R = 201, G = 255, B = 234, A = 0}
        bPrecomputedLightingIsValid = FALSE
        LightingChannels = {bInitialized = TRUE, BSP = TRUE, @Static = TRUE, Dynamic = TRUE, CompositeDynamic = TRUE, Gameplay_2 = TRUE}
    End Template
    LightComponent = PointLightComponent0
    Components = (PointLightComponent0)
    bStatic = FALSE
    bNoDelete = FALSE
    bMovable = TRUE
    RemoteRole = ENetRole.ROLE_None
}
// END MILAN CHANGE
