// MILAN Weapon
// Based on: MP1 class
Class SFXWeapon_AssaultRifle_Krogan extends SFXWeapon_AssaultRifle_Base
    placeable
    config(Weapon);

// Variables
var transient float FireStartTime;
var float MinROF;
var float RampTime;

// Functions
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
public simulated function WwiseEvent GetWeaponSpecificImpactSound(SFXPhysicalMaterialImpactSounds ImpactSounds)
{
    if (SFXPawn_Player(Instigator) != None && Instigator.IsLocallyControlled())
    {
        return ImpactSounds.SniperRifle_Player;
    }
    return ImpactSounds.SniperRifle;
}
public simulated function InitializeWeapon()
{
    Super(SFXWeapon).InitializeWeapon();
    HackLoadWeaponMods();
}
public simulated function StartChargeEffects()
{
    if (SFXPawn_Player(Instigator) != None)
    {
        WeaponAnimNode.PlayCustomAnim('WPN_ChargeUp', 1.0);
        WeaponAnimNode.PlayCustomAnim('WPN_ChargeHold', 1.0, 1.0, 0.0, TRUE);
    }
    Super(SFXWeapon).StartChargeEffects();
}
public simulated function StopChargeEffects()
{
    WeaponAnimNode.StopCustomAnim(0.200000003);
    WeaponAnimNode.PlayCustomAnim('WPN_ChargeRelease', 1.0);
    Super(SFXWeapon).StopChargeEffects();
}
public simulated function HackLoadWeaponMods()
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
    
    if (Instigator == None || Instigator.IsPlayerOwned() && (SFXPRIMP(Instigator.PlayerReplicationInfo) == None || (SFXPRIMP(Instigator.PlayerReplicationInfo).bIsReplicationValid_CharacterWeapons == FALSE && Role == ENetRole.ROLE_SimulatedProxy) && Instigator.Role == ENetRole.ROLE_SimulatedProxy))
    {
        if (!bDummyFireWeapon)
        {
            SetTimer(0.100000001, FALSE, 'HackLoadWeaponMods', );
            return;
        }
    }
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
    Manager = GetModule(Class'SFXModule_WeaponModManager');
    if (Manager != None)
    {
        Manager.SetWeaponModHidden(FALSE);
    }
}

// States
state WeaponFiring 
{
    // State Functions
    public simulated function RefireCheckTimer()
    {
        if (bWeaponPutDown)
        {
            PutDownWeapon();
            return;
        }
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
        if (SFXPawn_Player(Instigator) != None)
        {
            BioPlayerController(Player.Controller).m_bPermanentWalk = FALSE;
        }
        Super(SFXWeapon).EndState(NextStateName);
    }
    public simulated function BeginState(Name PreviousStateName)
    {
        local SFXPawn_Player Player;
        
        Player = SFXPawn_Player(Instigator);
        if (SFXPawn_Player(Instigator) != None)
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
        Samples = ({Duration = 0.150000006, LeftAmplitude = 50, RightAmplitude = 50, LeftFunction = EWaveformFunction.WF_Constant, RightFunction = EWaveformFunction.WF_Constant}, 
                   {Duration = 0.579999983, LeftAmplitude = 0, RightAmplitude = 0, LeftFunction = EWaveformFunction.WF_Constant, RightFunction = EWaveformFunction.WF_Constant}, 
                   {Duration = 0.150000006, LeftAmplitude = 50, RightAmplitude = 50, LeftFunction = EWaveformFunction.WF_Constant, RightFunction = EWaveformFunction.WF_Constant}
                  )
    End Template
    Begin Template Class=ForceFeedbackWaveform Name=ForceFeedbackWaveformBase
        Samples = ({Duration = 0.300000012, LeftAmplitude = 90, RightAmplitude = 90, LeftFunction = EWaveformFunction.WF_Sin90to180, RightFunction = EWaveformFunction.WF_Sin90to180}, 
                   {Duration = 0.100000001, LeftAmplitude = 100, RightAmplitude = 100, LeftFunction = EWaveformFunction.WF_Constant, RightFunction = EWaveformFunction.WF_Constant}
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
        Template = ParticleSystem'BioVFX_DLC_GUN02_Striker.Particles.Muzzle_KroASL' // MILAN CHANGE - Use GUN02 asset
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
        Template = ParticleSystem'BioVFX_C_Reload.Particles.Reload_HeatSinkEject'
        bAutoActivate = FALSE
        ReplacementPrimitive = None
    End Object
    Begin Template Class=PointLightComponent Name=MuzFlashLight0  // MILAN CHANGE - Use GUN02 flashlight component
    End Template
    Begin Object Class=SFXAnimSetCookSpec Name=tempAnimInfo
        AnimSet = AnimSet'BIOG_HMM_CB_A.HMM_CB_RifleAuto_SlowAlternate'
    End Object
    Begin Template Class=SFXModule_GameEffectManager Name=GEMod0
    End Template
    Begin Template Class=SFXModule_WeaponModManager Name=ModManager0
    End Template
    Begin Template Class=SkeletalMeshComponent Name=PickupMesh
        SkeletalMesh = SkeletalMesh'BIOG_WPN_ASL_R_CON_GUN02.ASLn.WPN_ASLn_MDL'  // MILAN CHANGE - Use GUN02 asset
        ReplacementPrimitive = None
    End Template
    Begin Template Class=SkeletalMeshComponent Name=WeaponMesh  // MILAN CHANGE - Use GUN02 assets
        SkeletalMesh = SkeletalMesh'BIOG_WPN_ASL_R_CON_GUN02.ASLn.WPN_ASLn_MDL'
        AnimTreeTemplate = AnimTree'BIOG_AnimTree_Weapon.BIOG_WPN_Main_O'
        PhysicsAsset = PhysicsAsset'BIOG_PHY_Weapons_F_CON_GUN02.PHY_WPN_ASLn'
        AnimSets = (AnimSet'BIOG_WPN_A_CON_GUN02.WPN_ASLn_Main')
        ReplacementPrimitive = None
    End Template
    MinROF = 125.0
    RampTime = 0.800000012
    ReloadDuration = {X = 2.9000001, Y = 2.9000001}
    Damage = {X = 144.699997, Y = 180.899994}
    MagSize = {X = 12.0, Y = 12.0}
    MaxSpareAmmo = {X = 48.0, Y = 60.0}
    MinAimError = {X = 0.5, Y = 0.5}
    MaxAimError = {X = 1.0, Y = 1.0}
    MinZoomAimError = {X = 0.25, Y = 0.25}
    MaxZoomAimError = {X = 1.0, Y = 1.0}
    RateOfFire = {X = 275.0, Y = 275.0}
    EncumbranceWeight = {X = 2.0, Y = 1.39999998}
    Recoil = {X = 2.21199989, Y = 2.21199989}
    ZoomRecoil = {X = 2.21199989, Y = 2.21199989}
    AccFirePenalty = {X = 19.0, Y = 19.0}
    AccFireInterpSpeed = {X = 18.0, Y = 18.0}
    ZoomAccFirePenalty = {X = 37.0, Y = 37.0}
    ZoomAccFireInterpSpeed = {X = 35.0, Y = 35.0}
    MinZoomCrosshairRange = {X = 33.0, Y = 33.0}
    MaxZoomCrosshairRange = {X = 55.0, Y = 55.0}
    StatBarAccuracy = {X = 15.0, Y = 15.0}
    StatBarDamage = {X = 144.699997, Y = 180.899994}
    StatBarRateOfFire = {X = 275.0, Y = 275.0}
    GUIImage = "DLC_MPImages.Weapons.asl_krogan_512x256"
    NotificationImage = "DLC_MPImages.Weapons.asl_krogan_256x128"
    WeaponModBodyColours = ({R = 0.0500000007, G = 0.0599999987, B = 0.0599999987, A = 0.0}
                           )
    GUIZoomReticleClass = Class'SFXGUI_ShotgunReticle'
    FiringShake = {
                   RotAmplitude = {X = 500.0, Y = 100.0, Z = -500.0}, 
                   RotFrequency = {X = 15.0, Y = 10.0, Z = 10.0}, 
                   LocAmplitude = {X = 10.0, Y = 0.0, Z = 0.0}, 
                   LocFrequency = {X = 15.0, Y = 0.0, Z = 0.0}, 
                   TimeDuration = 0.125
                  }
    TightAimFiringShake = {
                           RotAmplitude = {X = 500.0, Y = 100.0, Z = -500.0}, 
                           RotFrequency = {X = 15.0, Y = 10.0, Z = 10.0}, 
                           LocAmplitude = {X = 10.0, Y = 0.0, Z = 0.0}, 
                           LocFrequency = {X = 15.0, Y = 0.0, Z = 0.0}, 
                           TimeDuration = 0.125
                          }
    TracerInfo = {
                  Scale3D = {X = 1.5, Y = 1.5, Z = 1.5}, 
                  AccelRate = 8000.0, 
                  Speed = 18000.0, 
                  MaxSpeed = 20000.0
                 }
    ReloadAnimInfo = tempAnimInfo
    PSC_OutOfAmmoEffect = OutOfAmmoEffect0
    OutOfAmmoRumble = OutOfAmmoRumble0
    WeaponFireWaveForm = ForceFeedbackWaveformBase
    EjectRumble = EjectRumble0
    PSC_ShellCasing = ShellCasingPSC0
    PSC_ReloadVent = ReloadVent0
    PSC_MuzFlashEmitter = MuzFlashPSC0
    // MILAN CHANGE - Use Muzzle flashlight components from GUN02
    LC_MuzzleFlashLight = MuzFlashLight0
    TracerSpawnOffset = 2.0
    MuzzleLightLifetime = 0.0500000007
    MuzzleLightBrightness = 0.5
    MuzzleLightColor = {B = 1, G = 120, R = 255, A = 0}
    MuzzleLightFalloffExponent = 15.0
    MuzzleLightRadius = 600.0
    // END MILAN CHANGE
    EjectShellCasingTimeRatio = 0.460000008
    LowAmmoSoundThreshold = 2.0
    MinRefireTime = 0.75
    LazyRateOfFire = 0.00999999978
    RecoilYawScale = 0.200000003
    RecoilYawFrequency = 0.5
    DistancePenetrated = 50.0
    IconResource = GFxMovieInfo'GUI_SF_ME3_DLC_Gun02.ME3_DLC_Krogan_Gun02' // MILAN CHANGE - Use GUN02 asset
    IconRef = 2
    PrettyName = $728040
    ShortPrettyName = $728040
    ShortDescription = $728041
    GeneralDescription = $728042
    FireSound = WwiseEvent'Wwise_Weapons_S_Krogan.Play_wep_np_krogan_fire'
    PlayerFireSound = WwiseEvent'Wwise_Weapons_S_Krogan.Play_wep_p_krogan_fire'
    WeaponReloadSound = WwiseEvent'Wwise_Weapons_Generic.Play_wep_g_reload_assault_heavy'
    WeaponExpandSound = WwiseEvent'Wwise_Weapons_S_Krogan.Play_wep_s_krogan_expand'
    WeaponCollapseSound = None
    AmmoPowerPSCO = AmmoPowerHologram
    AmmoPowerIconPSCO = AmmoPowerIconHologram
    bScaleAnimDurationByFireRate = TRUE
    WeaponFireTypes = (EWeaponFireType.EWFT_InstantHit, EWeaponFireType.EWFT_InstantHit, EWeaponFireType.EWFT_Projectile, EWeaponFireType.EWFT_InstantHit, EWeaponFireType.EWFT_InstantHit)
    WeaponProjectiles = (None, None, Class'SFXProjectile_KroganAR_GUN02') // MILAN CHANGE - Use GUN02 asset
    InstantHitMomentum = (0.0, 1.0, 35.0, 1.0)
    InstantHitDamageTypes = (None, Class'SFXDamageType_Default', Class'SFXDamageType_AssaultRifle_Krogan', Class'SFXDamageType_Default')
    Mesh = WeaponMesh
    DroppedPickupMesh = PickupMesh
    PickupFactoryMesh = PickupMesh
    Components = (WeaponMesh)
    Modules = (GEMod0, ModManager0)
}