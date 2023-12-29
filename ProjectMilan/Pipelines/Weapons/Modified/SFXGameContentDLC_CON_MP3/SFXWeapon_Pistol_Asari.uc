// MILAN Weapon
// Source: MP3
Class SFXWeapon_Pistol_Asari extends SFXWeapon_Pistol_Base
    placeable
    config(Weapon);

// Variables
var Guid ChargeEffectGuid;
var(SFXWeapon_Pistol_Asari) ForceFeedbackWaveform ChargeRumble;
var(SFXWeapon_Pistol_Asari) RvrClientEffectInterface CE_ChargeUp;

// Functions
public simulated function PlayFireEffects(byte FiringMode, optional Vector HitLocation)
{
    WeaponAnimNode.StopCustomAnim(0.200000003);
    WeaponAnimNode.PlayCustomAnim('WPN_ChargeRelease', 1.0);
    Super(SFXWeapon).PlayFireEffects(FiringMode, HitLocation);
}
public simulated function InitializeWeapon()
{
    Super(SFXWeapon).InitializeWeapon();
    HackLoadWeaponMods();
}
public simulated function StartChargeEffects()
{
    local float PlayRate;
    local RvrClientEffectTarget CETarget;
    
    Super(SFXWeapon).StartChargeEffects();
    if (SFXPawn_Player(Instigator) != None)
    {
        PlayRate = 1.0 / MinChargeTime;
        CETarget.Instigator = Instigator;
        CETarget.HitBone = 'Flash_2';
        ChargeEffectGuid = Class'RvrClientEffectManager'.static.GetClientEffectManager().StartOnTarget(CE_ChargeUp, CETarget);
        BioPlayerController(Instigator.Controller).ClientPlayForceFeedbackWaveform(ChargeRumble);
        WeaponAnimNode.PlayCustomAnim('WPN_ChargeUp', PlayRate);
        WeaponAnimNode.PlayCustomAnim('WPN_ChargeHold', 1.0, 1.0, 0.0, TRUE);
    }
}
public simulated function StopChargeEffects()
{
    Super(SFXWeapon).StopChargeEffects();
    Class'RvrClientEffectManager'.static.GetClientEffectManager().Stop(CE_ChargeUp, ChargeEffectGuid, FALSE);
    BioPlayerController(Instigator.Controller).ClientStopForceFeedbackWaveform(ChargeRumble);
    WeaponAnimNode.StopCustomAnim(0.200000003);
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
        Samples = ({Duration = 0.25, LeftAmplitude = 70, RightAmplitude = 70, LeftFunction = EWaveformFunction.WF_Constant, RightFunction = EWaveformFunction.WF_Constant}
                  )
    End Template
    Begin Object Class=ForceFeedbackWaveform Name=ForceFeedbackWaveformBaseCharge
        Samples = ({Duration = 2.0, LeftAmplitude = 75, RightAmplitude = 75, LeftFunction = EWaveformFunction.WF_LinearIncreasing, RightFunction = EWaveformFunction.WF_LinearIncreasing}, 
                   {Duration = 9.85000038, LeftAmplitude = 75, RightAmplitude = 75, LeftFunction = EWaveformFunction.WF_Noise, RightFunction = EWaveformFunction.WF_Noise}
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
        Template = ParticleSystem'BioVFX_DLC_GUN02_Disciple.Particles.Pistol_ChargeUp2' // MILAN CHANGE - Use GUN02 asset
        ReplacementPrimitive = None
    End Object
    Begin Object Class=ParticleSystemComponent Name=MuzFlashPSC0
        Template = ParticleSystem'BioVFX_DLC_GUN02_Disciple.Particles.Pistol_Muzzle_Flash' // MILAN CHANGE - Use GUN02 asset
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
        Template = ParticleSystem'BioVFX_DLC_GUN02_Disciple.Particles.Pistol_Reload' // MILAN CHANGE - Use GUN02 asset
        bAutoActivate = FALSE
        ReplacementPrimitive = None
    End Object
    Begin Template Class=PointLightComponent Name=MuzFlashLight0 // MILAN CHANGE - Add flashlight component
    End Template
    Begin Template Class=SFXModule_GameEffectManager Name=GEMod0
    End Template
    Begin Template Class=SFXModule_WeaponModManager Name=ModManager0
    End Template
    Begin Template Class=SkeletalMeshComponent Name=PickupMesh
        SkeletalMesh = SkeletalMesh'BIOG_WPN_PST_L_CON_MP3.PSTo.WPN_PSTo_MDL'
        ReplacementPrimitive = None
    End Template
    Begin Template Class=SkeletalMeshComponent Name=WeaponMesh
        SkeletalMesh = SkeletalMesh'BIOG_WPN_PST_L_CON_MP3.PSTo.WPN_PSTo_MDL'
        AnimTreeTemplate = AnimTree'BIOG_AnimTree_Weapon.BIOG_WPN_Main_O'  // MILAN CHANGE - Use GUN02 assets
        PhysicsAsset = PhysicsAsset'BIOG_PHY_Weapons_F_CON_GUN02.WPN_PHY_PSTo'
        AnimSets = (AnimSet'BIOG_WPN_A_CON_GUN02.WPN_PSTo_Main')
        ReplacementPrimitive = None
    End Template
    ChargeRumble = ForceFeedbackWaveformBaseCharge
    CE_ChargeUp = RvrClientEffectMulti'BioVFX_DLC_GUN02_Disciple.VCFX.Pistol_Side_Whole_VCFX' // MILAN CHANGE - Use GUN02 asset
    AI_AccCone_Min = {X = 1.10000002, Y = 1.10000002}
    AI_AccCone_Max = {X = 1.5, Y = 1.5}
    ReloadDuration = {X = 1.5, Y = 1.5}
    Damage = {X = 420.200012, Y = 490.0}
    MagSize = {X = 3.0, Y = 3.0}
    MaxSpareAmmo = {X = 12.0, Y = 24.0}
    MinAimError = {X = 0.200000003, Y = 0.200000003}
    MaxAimError = {X = 0.400000006, Y = 0.400000006}
    MinZoomAimError = {X = 0.00999999978, Y = 0.00999999978}
    MaxZoomAimError = {X = 0.100000001, Y = 0.100000001}
    RateOfFire = {X = 80.0, Y = 80.0}
    EncumbranceWeight = {X = 0.5, Y = 0.200000003}
    Recoil = {X = 0.261999995, Y = 0.261999995}
    ZoomRecoil = {X = 0.349999994, Y = 0.349999994}
    AccFirePenalty = {X = 20.7999992, Y = 20.7999992}
    AccFireInterpSpeed = {X = 20.0, Y = 20.0}
    ZoomAccFirePenalty = {X = 10.3999996, Y = 10.3999996}
    ZoomAccFireInterpSpeed = {X = 10.0, Y = 10.0}
    MinZoomCrosshairRange = {X = 25.0, Y = 25.0}
    MaxZoomCrosshairRange = {X = 32.0, Y = 32.0}
    StatBarAccuracy = {X = 50.0, Y = 50.0}
    StatBarDamage = {X = 420.200012, Y = 490.0}
    StatBarRateOfFire = {X = 80.0, Y = 80.0}
    GUIImage = "DLC_MPImages.pst_acolyte_512x256" // MILAN CHANGE - Use GUN02 asset
    NotificationImage = "DLC_MPImages.pst_acolyte_256x128" // MILAN CHANGE - Use GUN02 asset
    WeaponModBodyColours = ({R = 0.0500000007, G = 0.0599999987, B = 0.0700000003, A = 1.0}
                           )
    GUIZoomReticleClass = Class'SFXGUI_WeaponReticleSimple'
    FiringShake = {
                   RotAmplitude = {X = 500.0, Y = 100.0, Z = -500.0}, 
                   RotFrequency = {X = 25.0, Y = 10.0, Z = 10.0}, 
                   LocAmplitude = {X = 10.0, Y = 0.0, Z = 0.0}, 
                   LocFrequency = {X = 15.0, Y = 0.0, Z = 0.0}, 
                   TimeDuration = 0.150000006
                  }
    TightAimFiringShake = {
                           RotAmplitude = {X = 600.0, Y = 100.0, Z = -600.0}, 
                           RotFrequency = {X = 25.0, Y = 15.0, Z = 15.0}, 
                           LocAmplitude = {X = 15.0, Y = 0.0, Z = 0.0}, 
                           LocFrequency = {X = 25.0, Y = 0.0, Z = 0.0}, 
                           TimeDuration = 0.150000006
                          }
    AI_BurstFireCount = {X = 1.0, Y = 2.0}
    AI_BurstFireDelay = {X = 0.649999976, Y = 2.29999995}
    PSC_OutOfAmmoEffect = OutOfAmmoEffect0
    OutOfAmmoRumble = OutOfAmmoRumble0
    WeaponFireWaveForm = ForceFeedbackWaveformBase
    EjectRumble = EjectRumble0
    PSC_ShellCasing = ShellCasingPSC0
    PSC_ReloadVent = ReloadVent0
    TracerSpawnOffset = 3.0
    PSC_MuzFlashEmitter = MuzFlashPSC0
    LC_MuzzleFlashLight = MuzFlashLight0 // MILAN CHANGE - Use flashlight component
    EjectShellCasingTimeRatio = 0.558000028
    LowAmmoSoundThreshold = 1.0
    LazyRateOfFire = 0.00999999978
    RateOfFireAI = 1.0
    RecoilYawScale = 0.200000003
    RecoilYawFrequency = 0.5
    IconResource = GFxMovieInfo'GUI_SF_ME3_DLC_Gun02.ME3_DLC_Acolyte' // MILAN CHANGE - Use GUN02 asset
    IconRef = 2
    PrettyName = $744302
    ShortPrettyName = $744302
    ShortDescription = $744303
    GeneralDescription = $744304
    FireSound = WwiseEvent'Wwise_Weapons_S_Nesu.Play_wep_np_nesu_fire'
    PlayerFireSound = WwiseEvent'Wwise_Weapons_S_Nesu.Play_wep_p_nesu_fire'
    FireNoAmmoSound = WwiseEvent'Wwise_Weapons_Standard_LowAmmo.Play_weapon_dryfire_pistols'
    WeaponReloadSound = WwiseEvent'Wwise_Weapons_Generic.Play_wep_g_reload_pistol_normal'
    WeaponSteamReloadSound = WwiseEvent'Wwise_Weapons_Generic.Play_wep_g_noammo_small_alien_sweetener'
    SteamReloadNotifySound = WwiseEvent'Wwise_Weapons_Standard_LowAmmo.Play_weapon_reload_air_release'
    AmmoPowerPSCO = AmmoPowerHologram
    AmmoPowerIconPSCO = AmmoPowerIconHologram
    ChargeUpPS = ChargePSC
    PowerUpSound = WwiseEvent'Wwise_Weapons_S_Nesu.Play_wep_s_nesu_charge_start'
    PowerDownSound = WwiseEvent'Wwise_Weapons_S_Nesu.Play_wep_s_nesu_charge_stop'
    // MILAN CHANGE - Flashlight component properties
    MuzzleLightLifetime = 0.150000006
    MuzzleLightBrightness = 1.39999998
    MuzzleLightColor = {B = 255, G = 1, R = 70, A = 0}
    MuzzleLightFalloffExponent = 15.0
    MuzzleLightRadius = 300.0
    // END MILAN CHANGE
    MinChargeTime = 1.0
    MaxChargeTime = 1.10000002
    DefaultFireMode = FireModes.FireMode_SemiAuto
    bCanBlindUp = FALSE
    WeaponFireTypes = (EWeaponFireType.EWFT_InstantHit, EWeaponFireType.EWFT_Projectile, EWeaponFireType.EWFT_Projectile, EWeaponFireType.EWFT_InstantHit, EWeaponFireType.EWFT_InstantHit)
    WeaponProjectiles = (None, Class'SFXProjectile_Asari', Class'SFXProjectile_Asari')
    InstantHitMomentum = (0.0, 100.0, 100.0, 1.0)
    InstantHitDamageTypes = (None, Class'SFXDamageType_Asari', Class'SFXDamageType_Asari', Class'SFXDamageType_Default')
    FireOffset = {X = 0.00999999978, Y = 0.00999999978, Z = 0.00999999978}
    Mesh = WeaponMesh
    AIRating = 20.0
    DroppedPickupMesh = PickupMesh
    PickupFactoryMesh = PickupMesh
    Components = (WeaponMesh)
    Modules = (GEMod0, ModManager0)
}