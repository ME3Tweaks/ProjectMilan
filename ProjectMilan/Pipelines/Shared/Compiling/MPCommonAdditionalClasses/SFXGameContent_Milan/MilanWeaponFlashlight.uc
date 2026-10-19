// MILAN CHANGE - Mgamerz - 2026-10-16
// Each rendering peer owns one light pair per MP pawn. The inventory manager transfers the beam
// to the active weapon, including the consumable rocket launcher, without replicating light actors.
Class MilanWeaponFlashlight extends SpotLightMovable
    config(Game);

// One-off config opt-in: [sfxgamecontent_milan.milanweaponflashlight] FlashlightMaps=BioP_MapName
var config array<name> FlashlightMaps;
var transient BioPawn TargetPawn;
var transient SFXInventoryManager FlashlightManager;
var transient MilanPlayerFlashlightFill FillLight;
var transient bool bCleaningUp;
var vector PlayerLightOffset;

public static function bool IsEnabledForMap(name MapPackageName)
{
    return default.FlashlightMaps.Find(MapPackageName) != -1;
}

public simulated function bool InitializeForPawn(BioPawn InPawn)
{
    if (InPawn == None || InPawn.Mesh == None || LightComponent == None)
    {
        return FALSE;
    }
    TargetPawn = InPawn;
    FlashlightManager = SFXInventoryManager(InPawn.InvManager);
    if (FlashlightManager == None || FlashlightManager.bFlashlightAttached)
    {
        return FALSE;
    }
    FillLight = Spawn(Class'MilanPlayerFlashlightFill', InPawn, , InPawn.Location, InPawn.Rotation, , TRUE, FALSE);
    if (FillLight == None || FillLight.LightComponent == None)
    {
        return FALSE;
    }
    TargetPawn.Mesh.AttachComponent(FillLight.LightComponent, 'God', PlayerLightOffset, rot(0, 0, 0));
    // MILAN CHANGE - Mgamerz - 2026-10-17
    // CitSam's cone and lens flare use the existing per-weapon client-effect start/stop lifecycle.
    FlashlightManager.AddWeaponDynamicLights(Self, FillLight, RvrClientEffect'biovfx_env_flashlight.VCFX.FlashLight_Volumetric_VCFX');
    // END MILAN CHANGE
    return FlashlightManager.AttachedFlashlight == Self;
}

public simulated function Destroyed()
{
    local SFXWeapon Weapon;

    if (!bCleaningUp)
    {
        bCleaningUp = TRUE;
        if (LightComponent != None)
        {
            LightComponent.SetEnabled(FALSE);
        }
        if (FillLight != None && FillLight.LightComponent != None)
        {
            FillLight.LightComponent.SetEnabled(FALSE);
        }
        if (FlashlightManager != None && !FlashlightManager.bDeleteMe && FlashlightManager.AttachedFlashlight == Self)
        {
            // Clear every weapon reference before destroying the light's component owner.
            foreach FlashlightManager.InventoryActors(Class'SFXWeapon', Weapon)
            {
                if (Weapon.AttachedFlashlight == Self)
                {
                    Weapon.DetachFlashlight();
                }
            }
            FlashlightManager.RemoveWeaponDynamicLights();
        }
        if (FillLight != None)
        {
            if (TargetPawn != None && TargetPawn.Mesh != None && FillLight.LightComponent != None)
            {
                TargetPawn.Mesh.DetachComponent(FillLight.LightComponent);
            }
            FillLight.Destroy();
            FillLight = None;
        }
        FlashlightManager = None;
        TargetPawn = None;
    }
    Super.Destroyed();
}

defaultproperties
{
    Begin Template Class=SpotLightComponent Name=SpotLightComponent0
        Begin Object Class=LightFunction Name=FlashlightFunction
            Scale = {X = 1400.0, Y = 1400.0, Z = 1400.0}
            SourceMaterial = MaterialInstanceConstant'biovfx_env_flashlight.Materials.Flashlight_LightFunction_INST_01'
        End Object
        @Function = FlashlightFunction
        bEnabled = FALSE
        Brightness = 4.0
        Radius = 3623.6157
        FalloffExponent = 20.0
        OuterConeAngle = 33.369354
        LightColor = {R = 177, G = 227, B = 255, A = 0}
        bPrecomputedLightingIsValid = FALSE
        LightingChannels = {bInitialized = TRUE, BSP = TRUE, @Static = TRUE, Dynamic = TRUE, CompositeDynamic = TRUE, Gameplay_2 = TRUE}
    End Template
    LightComponent = SpotLightComponent0
    Components = (SpotLightComponent0)
    PlayerLightOffset = {X = -50.0, Y = 30.0, Z = 100.0}
    bStatic = FALSE
    bNoDelete = FALSE
    bMovable = TRUE
    RemoteRole = ENetRole.ROLE_None
}
// END MILAN CHANGE
