// MILAN Weapon
// Source: MP5
Class SFXWeapon_Shotgun_Salarian_MP extends SFXWeapon_Shotgun_Base
    placeable
    config(Weapon);

// Variables
var Guid ChargeEffectGuid;
var(SFXWeapon_Shotgun_Salarian_MP) editinline export ParticleSystemComponent SteamMuzzle;
var(SFXWeapon_Shotgun_Salarian_MP) RvrClientEffectInterface CE_ChargeUp;
var(SFXWeapon_Shotgun_Salarian_MP) ForceFeedbackWaveform ChargeRumble;
var WwiseEvent PlayerShotSound;
var WwiseEvent ShotSound;
var WwiseEvent PlayerChargedShotSound;
var WwiseEvent ChargedShotSound;
var config float ChargedDamageMultiplier;

// Functions
public simulated function Class<Projectile> GetProjectileClass()
{
    if (ChargeAmount >= 1.0)
    {
        return Class'SFXProjectile_SalarianBlastSplitter_MP';
    }
    return Super(Weapon).GetProjectileClass();
}
public simulated function float GetFireModeBaseDamage()
{
    if (ChargeAmount >= 1.0)
    {
        return Super(SFXWeapon).GetFireModeBaseDamage() * ChargedDamageMultiplier;
    }
    return Super(SFXWeapon).GetFireModeBaseDamage();
}
public simulated function InitializeWeapon()
{
    Super(SFXWeapon).InitializeWeapon();
    HackLoadWeaponMods();
}
public simulated function PlayOwnedFireEffects(byte FireModeNum, Vector HitLocation)
{
    if (ChargeAmount >= 1.0)
    {
        PlayerFireSound = PlayerChargedShotSound;
        FireSound = ChargedShotSound;
    }
    else
    {
        PlayerFireSound = PlayerShotSound;
        FireSound = ShotSound;
    }
    Super(SFXWeapon).PlayOwnedFireEffects(FireModeNum, HitLocation);
}
public simulated function StartChargeEffects()
{
    local BioPlayerController PC;
    
    PC = BioPlayerController(Instigator.Controller);
    if (SFXPawn_Player(Instigator) != None)
    {
        PC.ClientPlayForceFeedbackWaveform(ChargeRumble);
    }
    if (!bFired)
    {
        if (Role == ENetRole.ROLE_Authority)
        {
            RepChargeEffect = ChargeEffectType.CET_StartCharge;
        }
        if (ChargeUpPS != None)
        {
            ChargeUpPS.SetActive(TRUE);
        }
        if ((Instigator != None && Instigator.IsHumanControlled()) && Instigator.IsLocallyControlled())
        {
            WeaponPlayWwiseEvent(PowerUpSound);
        }
        else
        {
            WeaponPlayWwiseEvent(NPCPowerUpSound);
        }
        bNeedPowerDownSound = TRUE;
        PC = BioPlayerController(Instigator.Controller);
        if (PC != None && PC.IsLocalPlayerController())
        {
            SFXPlayerCamera(PC.PlayerCamera).AddScreenShake(ChargeCameraShake);
            SetTimer(MaxChargeTime, FALSE, 'StartFullChargeRumble', Self);
        }
        SetFlashlightFireMode();
    }
}
public simulated function StopChargeEffects()
{
    local BioPlayerController PC;
    
    PC = BioPlayerController(Instigator.Controller);
    PC.ClientStopForceFeedbackWaveform(ChargeRumble);
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

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    Begin Template Class=ForceFeedbackWaveform Name=EjectRumble0
    End Template
    Begin Template Class=ForceFeedbackWaveform Name=ForceFeedbackWaveformBase
        Samples = ({Duration = 0.300000012, LeftAmplitude = 80, RightAmplitude = 80, LeftFunction = EWaveformFunction.WF_Sin90to180, RightFunction = EWaveformFunction.WF_Sin90to180}, 
                   {Duration = 0.100000001, LeftAmplitude = 100, RightAmplitude = 100, LeftFunction = EWaveformFunction.WF_Constant, RightFunction = EWaveformFunction.WF_Constant}
                  )
    End Template
    Begin Object Class=ForceFeedbackWaveform Name=ForceFeedbackWaveformBaseCharge
        Samples = ({Duration = 2.0, LeftAmplitude = 75, RightAmplitude = 75, LeftFunction = EWaveformFunction.WF_LinearIncreasing, RightFunction = EWaveformFunction.WF_LinearIncreasing}, 
                   {Duration = 100.0, LeftAmplitude = 75, RightAmplitude = 75, LeftFunction = EWaveformFunction.WF_Noise, RightFunction = EWaveformFunction.WF_Noise}
                  )
        bIsLooping = TRUE
    End Object
    Begin Template Class=ForceFeedbackWaveform Name=OutOfAmmoRumble0
    End Template
    Begin Template Class=ParticleSystemComponent Name=AmmoPowerHologram
        ReplacementPrimitive = None
    End Template
    Begin Template Class=ParticleSystemComponent Name=AmmoPowerIconHologram
        ReplacementPrimitive = None
    End Template
    Begin Object Class=ParticleSystemComponent Name=ChargePSC
        Template = ParticleSystem'BioVFX_Wpn_BLS_M_GUN02.Particles.BLSM_ChargeUp'
        ReplacementPrimitive = None
    End Object
    Begin Object Class=ParticleSystemComponent Name=MuzFlashPSC0
        Template = ParticleSystem'BioVFX_C_Wpn_Scorpion.Particles.Scorpion_Muzzle'
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
        Template = ParticleSystem'BioVFX_C_Reload.Particles.Reload_VentHeat'
        bAutoActivate = FALSE
        ReplacementPrimitive = None
    End Object
    Begin Object Class=ParticleSystemComponent Name=SteamChargePSC0
        Template = ParticleSystem'BioVFX_C_Reload.Particles.Reload_VentHeat'
        ReplacementPrimitive = None
    End Object
    Begin Template Class=PointLightComponent Name=MuzFlashLight0 // MILAN CHANGE - Add muzzle flash
    End Template
    Begin Object Class=SFXAnimSetCookSpec Name=tempAnimInfo
        AnimSet = AnimSet'BIOG_HMM_CB_A.HMM_CB_ShotgunAuto_AlternateSlow'
    End Object
    Begin Template Class=SFXModule_GameEffectManager Name=GEMod0
    End Template
    Begin Template Class=SFXModule_WeaponModManager Name=ModManager0
    End Template
    Begin Template Class=SkeletalMeshComponent Name=PickupMesh
        SkeletalMesh = SkeletalMesh'BIOG_WPN_BLS_M_CON_GUN02.WPN_BLSm_MDL'
        ReplacementPrimitive = None
    End Template
    Begin Template Class=SkeletalMeshComponent Name=WeaponMesh
        SkeletalMesh = SkeletalMesh'BIOG_WPN_BLS_M_CON_GUN02.WPN_BLSm_MDL'
        AnimTreeTemplate = AnimTree'BIOG_AnimTree_Weapon.BIOG_WPN_Main_O' // MILAN CHANGE - Use GUN02 assets
        PhysicsAsset = PhysicsAsset'BIOG_PHY_Weapons_F_CON_GUN02.PHY_WPN_BLSm'
        AnimSets = (AnimSet'BIOG_WPN_A_CON_GUN02.WPN_BLSm_MDL_Anims')
        ReplacementPrimitive = None
    End Template
    SteamMuzzle = SteamChargePSC0
    ChargeRumble = ForceFeedbackWaveformBaseCharge
    PlayerShotSound = WwiseEvent'Wwise_Weapons_S_SalShot.Play_wep_p_salarianshotgun_fire_low'
    ShotSound = WwiseEvent'Wwise_Weapons_S_SalShot.Play_wep_np_salarianshotgun_fire_low'
    PlayerChargedShotSound = WwiseEvent'Wwise_Weapons_S_SalShot.Play_wep_p_salarianshotgun_fire_high'
    ChargedShotSound = WwiseEvent'Wwise_Weapons_S_SalShot.Play_wep_np_salarianshotgun_fire_high'
    ChargedDamageMultiplier = 0.366699994
    AI_AccCone_Min = {X = 1.10000002, Y = 1.10000002}
    AI_AccCone_Max = {X = 1.79999995, Y = 1.79999995}
    ReloadDuration = {X = 2.56999993, Y = 2.56999993}
    Damage = {X = 636.0, Y = 795.0}
    MagSize = {X = 4.0, Y = 4.0}
    MaxSpareAmmo = {X = 12.0, Y = 22.0}
    MinAimError = {X = 2.5, Y = 2.5}
    MaxAimError = {X = 5.0, Y = 5.0}
    MinZoomAimError = {X = 0.75, Y = 0.75}
    MaxZoomAimError = {X = 2.5, Y = 2.5}
    RateOfFire = {X = 80.0, Y = 80.0}
    EncumbranceWeight = {X = 2.0, Y = 1.39999998}
    Recoil = {X = 0.275000006, Y = 0.275000006}
    ZoomRecoil = {X = 0.75, Y = 0.75}
    AccFirePenalty = {X = 320.0, Y = 320.0}
    AccFireInterpSpeed = {X = 420.0, Y = 420.0}
    ZoomAccFirePenalty = {X = 40.0, Y = 40.0}
    ZoomAccFireInterpSpeed = {X = 38.0, Y = 38.0}
    MinZoomCrosshairRange = {X = 32.0, Y = 32.0}
    MaxZoomCrosshairRange = {X = 42.0, Y = 42.0}
    StatBarAccuracy = {X = 50.0, Y = 50.0}
    StatBarDamage = {X = 636.0, Y = 795.0}
    StatBarRateOfFire = {X = 80.0, Y = 80.0}
    GUIImage = "DLC_MPImages.Weapons.bls_Salarian_512x256" // MILAN CHANGE - Use GUN02 assets
    NotificationImage = "DLC_MPImages.Weapons.bls_Salarian_256x128" // MILAN CHANGE - Use GUN02 assets
    ZoomSnapList = ({OuterSnapAngle = 0.0, InnerSnapAngle = 0.0, SnapOffsetMag = 0.0, AimNode = EAimNodes.AimNode_Head}
                   )
    AllowableWeaponMods = ("SFXGameContent.SFXWeaponMod_ShotgunStability")
    WeaponModBodyColours = ({R = 0.00999999978, G = 0.00999999978, B = 0.00999999978, A = 0.0}
                           )
    GUIZoomReticleClass = Class'SFXGUI_WeaponReticleSimple'
    FiringShake = {
                   RotAmplitude = {X = 325.0, Y = 175.0, Z = 100.0}, 
                   RotFrequency = {X = 100.0, Y = 50.0, Z = 50.0}, 
                   LocAmplitude = {X = 4.0, Y = 0.0, Z = 0.0}, 
                   TimeDuration = 0.200000003
                  }
    TightAimFiringShake = {
                           RotAmplitude = {X = 500.0, Y = 100.0, Z = -500.0}, 
                           RotFrequency = {X = 15.0, Y = 10.0, Z = 10.0}, 
                           LocAmplitude = {X = 10.0, Y = 0.0, Z = 0.0}, 
                           LocFrequency = {X = 15.0, Y = 0.0, Z = 0.0}, 
                           TimeDuration = 0.25999999
                          }
    MuzzleIdlePosition = {X = 72.0, Y = 9.0, Z = 34.0}
    AI_BurstFireCount = {X = 1.0, Y = 1.0}
    AI_BurstFireDelay = {X = 0.649999976, Y = 2.29999995}
    ReloadAnimInfo = tempAnimInfo
    PSC_OutOfAmmoEffect = OutOfAmmoEffect0
    OutOfAmmoRumble = OutOfAmmoRumble0
    WeaponFireWaveForm = ForceFeedbackWaveformBase
    EjectRumble = EjectRumble0
    PSC_ShellCasing = ShellCasingPSC0
    PSC_ReloadVent = ReloadVent0
    PSC_MuzFlashEmitter = MuzFlashPSC0
    // MILAN CHANGE - Add muzzle flash properties
    LC_MuzzleFlashLight = MuzFlashLight0
    MuzzleLightLifetime = 0.150000006
    MuzzleLightBrightness = 1.70000005
    MuzzleLightColor = {B = 255, G = 70, R = 1, A = 0}
    MuzzleLightFalloffExponent = 15.0
    MuzzleLightRadius = 600.0
    // END MILAN CHANGE
    EjectShellCasingTimeRatio = 0.405000001
    LowAmmoSoundThreshold = 1.0
    NoAmmoFireSoundDelay = 0.899999976
    LazyRateOfFire = 0.00999999978
    RateOfFireAI = 1.0
    RecoilYawScale = 0.25
    MagneticCorrectionThresholdAngle = 0.0
    MaxMagneticCorrectionAngle = 0.0
    IconResource = GFxMovieInfo'GUI_SF_ME3_DLC_SalrBST.ME3_DLC_SalrBST' // MILAN CHANGE - Use GUN02 assets
    IconRef = 2
    PrettyName = $788084
    ShortPrettyName = $788084
    ShortDescription = $788542
    GeneralDescription = $788085
    FireSound = WwiseEvent'Wwise_Weapons_S_SalShot.Play_wep_np_salarianshotgun_fire_low'
    PlayerFireSound = WwiseEvent'Wwise_Weapons_S_SalShot.Play_wep_p_salarianshotgun_fire_low'
    FireNoAmmoSound = WwiseEvent'Wwise_Weapons_Standard_LowAmmo.Play_weapon_dryfire_shotguns'
    WeaponReloadSound = WwiseEvent'Wwise_Weapons_Generic.Play_wep_g_reload_shotgun_heavy'
    WeaponSteamReloadSound = WwiseEvent'Wwise_Weapons_Generic.Play_wep_g_noammo_small_alien_sweetener'
    WeaponExpandSound = WwiseEvent'Wwise_Generic_Gameplay.Play_foley_weapon_shotgun_expand'
    WeaponCollapseSound = WwiseEvent'Wwise_Generic_Gameplay.Play_foley_weapon_shotgun_collapse'
    AmmoPowerPSCO = AmmoPowerHologram
    AmmoPowerIconPSCO = AmmoPowerIconHologram
    ChargeUpPS = ChargePSC
    PowerUpSound = WwiseEvent'Wwise_Weapons_S_SalShot.Play_wep_p_salarianshotgun_charge'
    NPCPowerUpSound = WwiseEvent'Wwise_Weapons_S_SalShot.Play_wep_np_salarianshotgun_charge'
    MaxChargeTime = 1.0
    bCanBlindUp = FALSE
    WeaponFireTypes = (EWeaponFireType.EWFT_InstantHit, EWeaponFireType.EWFT_Projectile, EWeaponFireType.EWFT_Projectile, EWeaponFireType.EWFT_InstantHit, EWeaponFireType.EWFT_InstantHit)
    WeaponProjectiles = (None, Class'SFXProjectile_SalarianBlast_MP', Class'SFXProjectile_SalarianBlast_MP')
    InstantHitMomentum = (0.0, 100.0, 100.0, 1.0)
    InstantHitDamageTypes = (None, Class'SFXDamageType_SalarianBlast_MP', Class'SFXDamageType_SalarianBlast_MP', Class'SFXDamageType_Default')
    FireOffset = {X = 1.0, Y = -1.0, Z = 1.0}
    Mesh = WeaponMesh
    AIRating = 20.0
    DroppedPickupMesh = PickupMesh
    PickupFactoryMesh = PickupMesh
    Components = (WeaponMesh)
    Modules = (GEMod0, ModManager0)
}