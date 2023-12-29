// MILAN Weapon
// Source: DLC_TestPatch
Class SFXWeapon_Shotgun_Quarian extends SFXWeapon_Heavy_Beam_Base_DLC2
    placeable
    config(Weapon);

// Variables
var Guid ChargeEffectGuid;
var Guid FireChargeEffectGuid;
var WwiseEvent PlayerPowerUpSound1;
var WwiseEvent PlayerPowerDownSound1;
var WwiseEvent PowerUpSound1;
var WwiseEvent PowerDownSound1;
var transient float FireStartTime;
var RvrClientEffectInterface CE_ChargeUp;
var RvrClientEffectInterface CE_FireChargeUp;
var AnimSet ShotgunShotAnimset; // MILAN Change - GUN01 LE3 uses this, we're going to try it out
var float MinROF;
var float RampTime;

// Functions
public simulated function FireAmmunition()
{
    Super(SFXWeapon_NativeBase).FireAmmunition();
    SetTimer(GetFireInterval(DefaultFireMode), TRUE, 'RefireCheckTimer', );
}
public simulated function PlayFireEffects(byte FireModeNum, optional Vector HitLocation)
{
    local RvrClientEffectTarget CETarget;
    
    if (!bPlayingMuzzleFlashEffect)
    {
        GetModule(Class'SFXModule_GameEffectManager').RemoveEffectsByType(Class'SFXGameEffect_WeaponVFXChange');
        CETarget.Instigator = Instigator;
        CETarget.HitBone = 'Flash_2';
        FireChargeEffectGuid = Class'RvrClientEffectManager'.static.GetClientEffectManager().StartOnTarget(CE_FireChargeUp, CETarget);
        if (SFXPawn_Player(Instigator) != None && Instigator.IsLocallyControlled())
        {
            WeaponPlayWwiseEvent(PlayerPowerUpSound1);
        }
        else
        {
            WeaponPlayWwiseEvent(PowerUpSound1);
        }
    }
    Super(SFXWeapon).PlayFireEffects(FireModeNum, HitLocation);
}
public simulated function bool ShouldRefire()
{
    local BioCustomAction oAction;
    
    if (BioPawn(Instigator).GetCurrentCustomAction(oAction) && oAction != None)
    {
        return FALSE;
    }
    return Super(SFXWeapon).ShouldRefire();
}
public simulated function StopFireEffects(byte FireModeNum)
{
    Super(SFXWeapon).StopFireEffects(FireModeNum);
    Class'RvrClientEffectManager'.static.GetClientEffectManager().Stop(CE_FireChargeUp, ChargeEffectGuid, FALSE);
    if (SFXPawn_Player(Instigator) != None && Instigator.IsLocallyControlled())
    {
        WeaponPlayWwiseEvent(PlayerPowerDownSound1);
    }
    else
    {
        WeaponPlayWwiseEvent(PowerDownSound1);
    }
}
public simulated function TimeWeaponFiring(byte FireModeNum)
{
    if (!IsTimerActive('RefireCheckTimer'))
    {
        SetTimer(GetFireInterval(FireModeNum), FALSE, 'RefireCheckTimer', );
    }
}
public simulated function float GetRateOfFire()
{
    local float fRateOfFire;
    
    fRateOfFire = Super(SFXWeapon).GetRateOfFire();
    fRateOfFire = FClamp(Lerp(0.0, fRateOfFire, (WorldInfo.GameTimeSeconds - FireStartTime) / RampTime), MinROF, fRateOfFire);
    return fRateOfFire;
}
public simulated function WwiseEvent GetWeaponSpecificImpactSound(SFXPhysicalMaterialImpactSounds ImpactSounds);

public simulated function InitDefaultDecalProperties()
{
    DefaultDecalProperties = new (Self) Class'DecalComponent';
    DefaultDecalProperties.Width = 0.0;
    DefaultDecalProperties.Height = 0.0;
    DefaultDecalProperties.TileX = 0.0;
    DefaultDecalProperties.DepthBias = -0.0;
    DefaultDecalProperties.bNoClip = TRUE;
    DefaultDecalProperties.SetDecalMaterial(DefaultDecalMaterial);
}
public simulated function InitializeWeapon()
{
    local int idx;
    local int Idx2;
    local int WeaponModLevel;
    local SFXModule_WeaponModManager Manager;
    local Class<SFXWeaponMod> ModClass;
    local SFXPRIMP oPRI;
    local Name WeaponClassPath;
    local Name WeaponModClassPath;
    local SFXPawn_PlayerMP Player;
    
    Super(SFXWeapon).InitializeWeapon();
    Player = SFXPawn_PlayerMP(Instigator);
    if (Player == None)
    {
        return;
    }
    oPRI = SFXPRIMP(Player.PlayerReplicationInfo);
    if (oPRI == None)
    {
        return;
    }
    for (idx = 0; idx < 2; idx++)
    {
        oPRI.GetWeapon(idx, WeaponClassPath);
        if (Caps(PathName(Class)) == Caps(string(WeaponClassPath)))
        {
            Manager = GetModule(Class'SFXModule_WeaponModManager');
            if (Manager != None)
            {
                Manager.RemoveAllMods();
                for (Idx2 = 0; Idx2 < 2; ++Idx2)
                {
                    oPRI.GetWeaponMod(idx, Idx2, WeaponModClassPath, WeaponModLevel);
                    if (WeaponModClassPath != 'None')
                    {
                        ModClass = Class'SFXWeaponMod'.static.LoadModClass(string(WeaponModClassPath));
                        if (ModClass != None)
                        {
                            Manager.AddMod(ModClass, WeaponModLevel);
                        }
                        continue;
                    }
                    break;
                }
            }
        }
    }
}
public simulated function PlayReloadEject()
{
    local RvrClientEffectTarget CETarget;
    
    CETarget.Instigator = Instigator;
    CETarget.HitBone = 'Flash_2';
    Class'RvrClientEffectManager'.static.GetClientEffectManager().Stop(CE_ChargeUp, ChargeEffectGuid, FALSE);
    FireChargeEffectGuid = Class'RvrClientEffectManager'.static.GetClientEffectManager().StartOnTarget(CE_FireChargeUp, CETarget);
    Super(SFXWeapon).PlayReloadEject();
}
public simulated function ShutOffAllEmitters()
{
    Class'RvrClientEffectManager'.static.GetClientEffectManager().Stop(CE_ChargeUp, ChargeEffectGuid, FALSE);
    Super(SFXWeapon).ShutOffAllEmitters();
}
public simulated function StartChargeEffects()
{
    local RvrClientEffectTarget CETarget;
    
    Super(SFXWeapon).StartChargeEffects();
    CETarget.Instigator = Instigator;
    CETarget.HitBone = 'Flash_2';
    ChargeEffectGuid = Class'RvrClientEffectManager'.static.GetClientEffectManager().StartOnTarget(CE_ChargeUp, CETarget);
}
public simulated function StopChargeEffects()
{
    Super(SFXWeapon).StopChargeEffects();
    Class'RvrClientEffectManager'.static.GetClientEffectManager().Stop(CE_ChargeUp, ChargeEffectGuid, FALSE);
}
public simulated function StopMuzzleFlashEffect()
{
    bPlayingMuzzleFlashEffect = FALSE;
    if (PSC_MuzFlashEmitter != None)
    {
        PSC_MuzFlashEmitter.SetActive(FALSE);
        SetTimer(2.0, FALSE, 'HideMuzzleFlashEmitter', );
    }
    bFiringContinuously = FALSE;
}

// States
simulated state Inactive 
{
    // State Functions
    public simulated function BeginState(Name PreviousStateName)
    {
        // MILAN Change - GUN01 LE3 uses this, we're going to try it out
        local BioPawn BP;
        
        BP = BioPawn(Instigator);
        if (BP != None)
        {
            BP.RmvAnimSet(ShotgunShotAnimset);
        }
	    // END MILAN Change
        Class'RvrClientEffectManager'.static.GetClientEffectManager().Stop(CE_ChargeUp, ChargeEffectGuid, FALSE);
        Super(SFXWeapon).BeginState(PreviousStateName);
    }
    
    // State code
    stop;
};
 // MILAN Change - GUN01 LE3 uses this, we're going to try it out
simulated state Active 
{
    // State Functions
    public simulated function BeginState(Name PreviousStateName)
    {
        local BioPawn BP;
        
        BP = BioPawn(Instigator);
        if (BP != None)
        {
            BP.AddAnimSet(ShotgunShotAnimset);
        }
        Super(SFXWeapon).BeginState(PreviousStateName);
    }
    
    // State code
    stop;
};
 // END MILAN Change
state WeaponFiring 
{
    // State Functions
    public simulated function RefireCheckTimer()
    {
        if (ShouldRefire())
        {
            FireAmmunition();
            SetTimer(GetFireInterval(CurrentFireMode), FALSE, 'RefireCheckTimer', );
            return;
        }
        HandleFinishedFiring();
    }
    public simulated function EndState(Name NextStateName)
    {
        local SFXPawn_Player Player;
        
        Player = SFXPawn_Player(Instigator);
        if (Player != None)
        {
            BioPlayerController(Player.Controller).m_bPermanentWalk = FALSE;
        }
        Super(SFXWeapon).EndState(NextStateName);
    }
    public simulated function BeginState(Name PreviousStateName)
    {
        local SFXPawn_Player Player;
        
        Player = SFXPawn_Player(Instigator);
        if (Player != None)
        {
            BioPlayerController(Player.Controller).m_bPermanentWalk = TRUE;
        }
        FireStartTime = WorldInfo.GameTimeSeconds;
        Super(SFXWeapon).BeginState(PreviousStateName);
    }
    
    // State code
    stop;
};

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    Begin Template Class=ForceFeedbackWaveform Name=EjectRumble0
    End Template
    Begin Template Class=ForceFeedbackWaveform Name=ForceFeedbackWaveformBase
        Samples = ({Duration = 0.125, LeftAmplitude = 75, RightAmplitude = 75, LeftFunction = EWaveformFunction.WF_Noise, RightFunction = EWaveformFunction.WF_Noise}
                  )
    End Template
    Begin Template Class=ForceFeedbackWaveform Name=OutOfAmmoRumble0
    End Template
    Begin Template Class=ParticleSystemComponent Name=AmmoPowerHologram
        ReplacementPrimitive = None
    End Template
    Begin Template Class=ParticleSystemComponent Name=AmmoPowerIconHologram
        ReplacementPrimitive = None
    End Template
    Begin Object Class=ParticleSystemComponent Name=MuzFlashPSC0
        Template = ParticleSystem'BioVFX_DLC_Wpn_BLSk_GUN01.Particles.Flame_Thrower_Blue' // MILAN CHANGE: Use GUN01 asset
        bAutoActivate = FALSE
        ReplacementPrimitive = None
    End Object
    Begin Template Class=ParticleSystemComponent Name=OutOfAmmoEffect0
        ReplacementPrimitive = None
    End Template
    Begin Template Class=ParticleSystemComponent Name=ReloadVent0
        ReplacementPrimitive = None
    End Template
    Begin Object Class=ParticleSystemComponent Name=ShellCasingPSC0
        Template = ParticleSystem'BioVFX_C_Reload.Particles.Reload_VentHeat_Geth_2'
        bAutoActivate = FALSE
        ReplacementPrimitive = None
    End Object
    Begin Template Class=PointLightComponent Name=MuzFlashLight0 // MILAN CHANGE: Add flashlight component
    End Template
    Begin Object Class=SFXAnimSetCookSpec Name=tempAnimInfo
        AnimSet = AnimSet'BIOG_HMM_CB_A.HMM_CB_ShotgunAuto_AlternateSlow'
    End Object
    Begin Template Class=SFXModule_GameEffectManager Name=GEMod0
    End Template
    Begin Template Class=SFXModule_WeaponModManager Name=ModManager0
    End Template
    Begin Template Class=SkeletalMeshComponent Name=PickupMesh
        SkeletalMesh = SkeletalMesh'BIOG_WPN_BLS_K_CON_GUN01.BLSk.WPN_BLSk_MDL' // MILAN CHANGE: Use GUN01 asset
        ReplacementPrimitive = None
    End Template
    Begin Template Class=SkeletalMeshComponent Name=WeaponMesh // MILAN CHANGE: Use GUN01 assets
        SkeletalMesh = SkeletalMesh'BIOG_WPN_BLS_K_CON_GUN01.BLSk.WPN_BLSk_MDL'
        AnimTreeTemplate = AnimTree'BIOG_AnimTree_Weapon.BIOG_WPN_Main_O'
        PhysicsAsset = PhysicsAsset'BIOG_PHY_Weapons_F_CON_GUN01.PHY_WPN_BLSk'
        AnimSets = (AnimSet'BIOG_WPN_A_CON_GUN01.WPN_BLSk_Main')
        ReplacementPrimitive = None
    End Template
    PlayerPowerUpSound1 = WwiseEvent'Wwise_Weapons_S_Quarian_SP.Play_wep_p_quarian_fire_start_SP' // MILAN CHANGE: Use GUN01 assets
    PlayerPowerDownSound1 = WwiseEvent'Wwise_Weapons_S_Quarian_SP.Play_wep_p_quarian_fire_stop_SP' // MILAN CHANGE: Use GUN01 assets
    PowerUpSound1 = WwiseEvent'Wwise_Weapons_S_Quarian_SP.Play_wep_np_quarian_fire_start_SP' // MILAN CHANGE: Use GUN01 assets
    PowerDownSound1 = WwiseEvent'Wwise_Weapons_S_Quarian_SP.Play_wep_np_quarian_fire_stop_SP' // MILAN CHANGE: Use GUN01 assets
    CE_ChargeUp = RvrClientEffect'BioVFX_DLC_Wpn_BLSk_GUN01.VCFX.Lightning_Curst_VCFX' // MILAN CHANGE: Use GUN01 assets
    CE_FireChargeUp = RvrClientEffect'BioVFX_DLC_Wpn_BLSk_GUN01.VCFX.Lightning_Curst_Brighter_VCFX' // MILAN CHANGE: Use GUN01 assets
    ShotgunShotAnimset = AnimSet'BIOG_HMM_CB_CON_GUN01.HMM_CB_ShotgunShoot' // MILAN CHANGE: GUN01 LE3 uses this, we're going to try it out
    MinROF = 250.0
    RampTime = 0.75
    GUIZoomReticleClass = Class'SFXGUI_WeaponReticleSimple'
    FiringShake = {
                   RotAmplitude = {X = 55.0, Y = 20.0, Z = 0.0}, 
                   RotFrequency = {X = 35.0, Y = 60.0, Z = 0.0}, 
                   LocAmplitude = {X = -1.5, Y = 0.0, Z = 0.0}, 
                   LocFrequency = {X = 8.0, Y = 0.0, Z = 0.0}, 
                   TimeDuration = 0.200000003
                  }
    TightAimFiringShake = {
                           RotAmplitude = {X = 55.0, Y = 20.0, Z = 0.0}, 
                           RotFrequency = {X = 35.0, Y = 60.0, Z = 0.0}, 
                           LocAmplitude = {X = -1.5, Y = 0.0, Z = 0.0}, 
                           LocFrequency = {X = 8.0, Y = 0.0, Z = 0.0}, 
                           TimeDuration = 0.200000003
                          }
    ReloadAnimInfo = tempAnimInfo
    PSC_OutOfAmmoEffect = OutOfAmmoEffect0
    OutOfAmmoRumble = OutOfAmmoRumble0
    WeaponFireWaveForm = ForceFeedbackWaveformBase
    EjectRumble = EjectRumble0
    PS_DefaultImpactEffect = ParticleSystem'BioVFX_DLC_Wpn_BLSk_GUN01.Particles.Arc_Blue_Imp'  // MILAN CHANGE: Use GUN01 asset
    DefaultDecalMaterial = MaterialInstanceTimeVarying'BioVFX_C_ParticleBeam.Decals.DECAL_Beam_TINST'
    PSC_ShellCasing = ShellCasingPSC0
    PSC_ReloadVent = ReloadVent0
    PSC_MuzFlashEmitter = MuzFlashPSC0
    LC_MuzzleFlashLight = MuzFlashLight0 // MILAN CHANGE: Add flashlight component
    FlashlightFireColor = {B = 255, G = 255, R = 100, A = 0}
    FlashlightFireBrightnessIncrease = 2.5
    FlashlightFireRadiusIncrease = 0.75
    IconResource = GFxMovieInfo'GUI_SF_ME3_DLC_QuarianSG_GUN01.ME3_DLC_QuarianSG' // MILAN CHANGE: Use GUN01 asset
    FireNoAmmoSound = WwiseEvent'Wwise_Weapons_Geth.Play_weapon_dryfire_geth'
    WeaponReloadSound = WwiseEvent'Wwise_Weapons_Generic.Play_wep_g_reload_shotgun_heavy'
    WeaponSteamReloadSound = WwiseEvent'Wwise_Weapons_Generic.Play_wep_g_noammo_large_alien_sweetener'
    WeaponExpandSound = WwiseEvent'Wwise_Weapons_S_Quarian_SP.Play_wep_s_quarian_expand_SP' // MILAN CHANGE: Use GUN01 asset
    WeaponCollapseSound = WwiseEvent'Wwise_Weapons_S_Quarian_SP.Play_wep_s_quarian_collapse_SP' // MILAN CHANGE: Use GUN01 asset
    NeedReloadNotifySound = WwiseEvent'Wwise_Weapons_Geth.Play_weapon_lowammo_geth'
    SteamReloadNotifySound = WwiseEvent'Wwise_Weapons_Standard_LowAmmo.Play_overheat'
    AmmoPowerPSCO = AmmoPowerHologram
    AmmoPowerIconPSCO = AmmoPowerIconHologram
    // MILAN CHANGE - Muzzle lighting
    MuzzleLightLifetime = 0.150000006
    MuzzleLightBrightness = 1.70000005
    MuzzleLightColor = {B = 255, G = 70, R = 1, A = 0}
    MuzzleLightFalloffExponent = 15.0
    MuzzleLightRadius = 600.0
    // END MILAN CHANGE
    bSuppressTracers = TRUE
    bScaleAnimDurationByFireRate = TRUE
    DefaultFireMode = FireModes.FireMode_FullAuto
    // AnimType = WeaponAnimType.WeaponAnimType_ParticleBeam // MILAN Change: Using GUN01 specific animation. Unsure if it's different even.
    InstantHitMomentum = (0.0, 10.0, 50.0, 1.0) // MILAN NOTE: Requires verification. TestPatch decomp of this was not working at time of this file's creation
    InstantHitDamageTypes = (None, Class'SFXDamageType_Default', Class'SFXDamageType_QuarianShotgun', Class'SFXDamageType_Default')
    FireOffset = {X = 1.0, Y = 0.0, Z = 4.25}
    Mesh = WeaponMesh
    DroppedPickupMesh = PickupMesh
    PickupFactoryMesh = PickupMesh
    Components = (WeaponMesh)
    Modules = (GEMod0, ModManager0)
}