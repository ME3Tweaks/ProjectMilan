// MILAN Weapon
// Source: MP5
Class SFXWeapon_SMG_Bloodpack_MP extends SFXWeapon_SMG_Base
    placeable
    config(Weapon);

// Variables
var Class<SFXDamageType> APDamageType;
var WwiseEvent APFireSound;
var WwiseEvent APPlayerFireSound;
var(SFXWeapon_SMG_Bloodpack_MP) editinline export ParticleSystemComponent PSC_APRoundMuzzle;
var Name APMuzzleSocketName;
var config int ShotsPerAPRound;
var config float APDamageMultiplier;
var config float APRecoilMultiplier;
var config float APZoomRecoilMultiplier;

// Functions
public simulated function AttachMuzzleEffectsComponents(SkeletalMeshComponent SkelMesh, optional Name MuzzleSocket, optional Name CasingSocket)
{
    local SkeletalMeshComponent SMC;
    
    Super(SFXWeapon).AttachMuzzleEffectsComponents(SkelMesh, MuzzleSocket, CasingSocket);
    SMC = SkeletalMeshComponent(Mesh);
    if (SMC != None)
    {
        SMC.AttachComponentToSocket(PSC_APRoundMuzzle, APMuzzleSocketName);
    }
    PSC_APRoundMuzzle.SetActive(FALSE);
    PSC_APRoundMuzzle.SetHidden(TRUE);
    PSC_APRoundMuzzle.SetDepthPriorityGroup(SMC.DepthPriorityGroup);
    PSC_APRoundMuzzle.SetTickGroup(3);
}
public simulated function Class<SFXDamageType> GetDamageType(optional byte FiringMode)
{
    if (ShouldFireAPRound())
    {
        return APDamageType;
    }
    return Super(SFXWeapon).GetDamageType(FiringMode);
}
public simulated function float GetFireModeBaseDamage()
{
    if (ShouldFireAPRound())
    {
        return Super(SFXWeapon).GetFireModeBaseDamage() * APDamageMultiplier;
    }
    return Super(SFXWeapon).GetFireModeBaseDamage();
}
public simulated function float GetWeaponRecoil()
{
    if (ShouldFireAPRound())
    {
        if (bIsZoomed)
        {
            return Super(SFXWeapon).GetWeaponRecoil() * APZoomRecoilMultiplier;
        }
        return Super(SFXWeapon).GetWeaponRecoil() * APRecoilMultiplier;
    }
    return Super(SFXWeapon).GetWeaponRecoil();
}
public simulated function DecalComponent GetWeaponSpecificDecalData(SFXPhysicalMaterialDecals DecalEffects, out float FadeTime)
{
    local int DecalLength;
    
    FadeTime = DecalEffects.SMGFadeTime;
    DecalLength = DecalEffects.SMG.Length;
    if (DecalLength > 0)
    {
        return DecalEffects.SMG[Rand(DecalLength)];
    }
    return None;
}
public simulated function WwiseEvent GetWeaponSpecificImpactSound(SFXPhysicalMaterialImpactSounds ImpactSounds)
{
    if (ShouldFireAPRound())
    {
        if (SFXPawn_Player(Instigator) != None && Instigator.IsLocallyControlled())
        {
            return ImpactSounds.MassCannon_Player;
        }
        return ImpactSounds.MassCannon;
    }
    if (SFXPawn_Player(Instigator) != None && Instigator.IsLocallyControlled())
    {
        return ImpactSounds.SMG_Player;
    }
    return ImpactSounds.SMG;
}
public simulated function HideMuzzleFlashEmitter()
{
    Super(SFXWeapon).HideMuzzleFlashEmitter();
    if (PSC_APRoundMuzzle != None)
    {
        PSC_APRoundMuzzle.SetHidden(TRUE);
    }
}
public simulated function InitializeWeapon()
{
    Super(SFXWeapon).InitializeWeapon();
    HackLoadWeaponMods();
}
public simulated function PlayMuzzleFlashEffect()
{
    Super(SFXWeapon).PlayMuzzleFlashEffect();
    if (ShouldFireAPRound())
    {
        if (SFXPawn_Player(Instigator) != None && Instigator.IsLocallyControlled())
        {
            PlaySound(APPlayerFireSound, TRUE);
        }
        else
        {
            PlaySound(APFireSound, TRUE);
        }
        PSC_APRoundMuzzle.SetHidden(FALSE);
        PSC_APRoundMuzzle.SetActive(FALSE);
        PSC_APRoundMuzzle.SetActive(TRUE);
    }
}
public simulated function StopMuzzleFlashEffect()
{
    Super(SFXWeapon).StopMuzzleFlashEffect();
    if (PSC_APRoundMuzzle != None)
    {
        PSC_APRoundMuzzle.SetActive(FALSE);
    }
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
public simulated function bool ShouldFireAPRound()
{
    if (Instigator.ShotCount > 0 && Instigator.ShotCount %  ShotsPerAPRound == 0)
    {
        return TRUE;
    }
    return FALSE;
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    Begin Template Class=ForceFeedbackWaveform Name=EjectRumble0
    End Template
    Begin Template Class=ForceFeedbackWaveform Name=ForceFeedbackWaveformBase
        Samples = ({Duration = 0.150000006, LeftAmplitude = 85, RightAmplitude = 85, LeftFunction = EWaveformFunction.WF_Sin90to180, RightFunction = EWaveformFunction.WF_Sin90to180}
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
        Template = ParticleSystem'BioVFX_Wpn_PST_P_GUN01.Particles.PST_P_Muzzle'
        bAutoActivate = FALSE
        ReplacementPrimitive = None
    End Object
    Begin Object Class=ParticleSystemComponent Name=MuzFlashPSC1
        Template = ParticleSystem'BioVFX_Wpn_PST_P_GUN01.Particles.PST_P_Muzzle_02'
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
    Begin Template Class=PointLightComponent Name=MuzFlashLight0 // MILAN CHANGE - Add muzzle flash
    End Template
    Begin Template Class=SFXModule_GameEffectManager Name=GEMod0
    End Template
    Begin Template Class=SFXModule_WeaponModManager Name=ModManager0
    End Template
    Begin Template Class=SkeletalMeshComponent Name=PickupMesh
        SkeletalMesh = SkeletalMesh'BIOG_WPN_PST_P_CON_GUN01.WPN_PSTp_MDL'
        ReplacementPrimitive = None
    End Template
    Begin Template Class=SkeletalMeshComponent Name=WeaponMesh
        SkeletalMesh = SkeletalMesh'BIOG_WPN_PST_P_CON_GUN01.WPN_PSTp_MDL'
        AnimTreeTemplate = AnimTree'BIOG_AnimTree_Weapon.BIOG_WPN_Main_O' // MILAN CHANGE - Use GUN01 assets
        PhysicsAsset = PhysicsAsset'BIOG_PHY_Weapons_F_CON_GUN01.WPN_PHY_PSTp'
        AnimSets = (AnimSet'BIOG_WPN_A_CON_GUN01.WPN_PSTp_Main')
        ReplacementPrimitive = None
    End Template
    APDamageType = Class'SFXDamageType_BloodpackAPRound_MP'
    APMuzzleSocketName = 'SecondaryBarrel'
    ShotsPerAPRound = 8
    APDamageMultiplier = 5.0
    APRecoilMultiplier = 5.0
    APZoomRecoilMultiplier = 5.0
    APFireSound = WwiseEvent'Wwise_Weapons_S_Bloodpack.Play_wep_np_bloodack_secondary'
    APPlayerFireSound = WwiseEvent'Wwise_Weapons_S_Bloodpack.Play_wep_p_bloodack_secondary'
    PSC_APRoundMuzzle = MuzFlashPSC1
    AI_AccCone_Min = {X = 1.39999998, Y = 1.39999998}
    AI_AccCone_Max = {X = 2.9000001, Y = 2.9000001}
    ReloadDuration = {X = 1.5, Y = 1.5}
    Damage = {X = 38.2000008, Y = 47.75}
    MagSize = {X = 40.0, Y = 40.0}
    MaxSpareAmmo = {X = 320.0, Y = 400.0}
    MinAimError = {X = 2.9000001, Y = 2.9000001}
    MaxAimError = {X = 7.0, Y = 7.0}
    MinZoomAimError = {X = 1.5, Y = 1.5}
    MaxZoomAimError = {X = 3.5, Y = 3.5}
    RateOfFire = {X = 600.0, Y = 600.0}
    EncumbranceWeight = {X = 0.850000024, Y = 0.449999988}
    Recoil = {X = 0.349999994, Y = 0.349999994}
    ZoomRecoil = {X = 0.5, Y = 0.5}
    AccFirePenalty = {X = 6.5, Y = 6.5}
    AccFireInterpSpeed = {X = 8.0, Y = 8.0}
    ZoomAccFirePenalty = {X = 12.0, Y = 12.0}
    ZoomAccFireInterpSpeed = {X = 12.5, Y = 12.5}
    MinZoomCrosshairRange = {X = 45.0, Y = 45.0}
    MaxZoomCrosshairRange = {X = 90.0, Y = 90.0}
    StatBarAccuracy = {X = 22.5, Y = 22.5}
    StatBarDamage = {X = 62.0999985, Y = 77.5999985}
    StatBarRateOfFire = {X = 600.0, Y = 600.0}
    GUIImage = "DLC_MPImages.Weapons.smg_bloodpack_512x256" // MILAN CHANGE - Use GUN01 asset
    NotificationImage = "DLC_MPImages.Weapons.smg_bloodpack_256x128" // MILAN CHANGE - Use GUN01 asset
    WeaponModBodyColours = ({R = 0.0299999993, G = 0.0299999993, B = 0.0299999993, A = 0.0}
                           )
    FiringShake = {
                   RotAmplitude = {X = 45.0, Y = 20.0, Z = 0.0}, 
                   RotFrequency = {X = 35.0, Y = 60.0, Z = 0.0}, 
                   LocAmplitude = {X = -1.0, Y = 0.0, Z = 0.0}, 
                   LocFrequency = {X = 6.0, Y = 0.0, Z = 0.0}, 
                   TimeDuration = 0.125
                  }
    TightAimFiringShake = {
                           RotAmplitude = {X = 45.0, Y = 20.0, Z = 0.0}, 
                           RotFrequency = {X = 35.0, Y = 60.0, Z = 0.0}, 
                           LocAmplitude = {X = -1.0, Y = 0.0, Z = 0.0}, 
                           LocFrequency = {X = 6.0, Y = 0.0, Z = 0.0}, 
                           TimeDuration = 0.125
                          }
    TracerInfo = {
                  Scale3D = {X = 1.14999998, Y = 1.14999998, Z = 1.14999998}, 
                  StandardPSTemplate = ParticleSystem'BioVFX_C_Weapons.Tracers.Particles.Tracer_Smoke_Trail', 
                  PlayerPSTemplate = ParticleSystem'BioVFX_C_Weapons.Tracers.Particles.Tracer_Smoke_Trail', 
                  AccelRate = 8000.0, 
                  Speed = 18000.0, 
                  MaxSpeed = 20000.0
                 }
    AI_BurstFireCount = {X = 15.0, Y = 25.0}
    AI_BurstFireDelay = {X = 0.649999976, Y = 2.29999995}
    PSC_OutOfAmmoEffect = OutOfAmmoEffect0
    OutOfAmmoRumble = OutOfAmmoRumble0
    WeaponFireWaveForm = ForceFeedbackWaveformBase
    EjectRumble = EjectRumble0
    PSC_ShellCasing = ShellCasingPSC0
    PSC_ReloadVent = ReloadVent0
    TracerSpawnOffset = 3.0
    PSC_MuzFlashEmitter = MuzFlashPSC0
    // MILAN CHANGE - Add muzzle flash properties
    LC_MuzzleFlashLight = MuzFlashLight0
    MuzzleLightLifetime = 0.0299999993
    MuzzleLightBrightness = 1.39999998
    MuzzleLightColor = {B = 1, G = 120, R = 255, A = 0}
    MuzzleLightFalloffExponent = 15.0
    MuzzleLightRadius = 300.0
    // END MILAN CHANGE
    FlashlightFireColor = {B = 255, G = 255, R = 100, A = 0}
    FlashlightFireBrightnessIncrease = 2.5
    FlashlightFireRadiusIncrease = 0.75
    EjectShellCasingTimeRatio = 0.558000028
    LowAmmoSoundThreshold = 10.0
    SteamSoundThreshold = 1.0
    NoAmmoFireSoundDelay = 0.5
    MinRefireTime = 0.150000006
    LazyRateOfFire = 0.00999999978
    RateOfFireAI = 1.0
    RecoilYawScale = 0.200000003
    RecoilYawFrequency = 4.0
    IconResource = GFxMovieInfo'GUI_SF_ME3_DLC_BloodPak.ME3_DLC_BloodPakSMG' // MILAN CHANGE - Use GUN01 asset
    IconRef = 2
    PrettyName = $766089
    ShortPrettyName = $766089
    ShortDescription = $766090
    GeneralDescription = $766091
    FireSound = WwiseEvent'Wwise_Weapons_S_Bloodpack.Play_wep_np_bloodpack_fire'
    PlayerFireSound = WwiseEvent'Wwise_Weapons_S_Bloodpack.Play_wep_p_bloodpack_fire'
    WeaponReloadSound = WwiseEvent'Wwise_Weapons_Generic.Play_wep_g_reload_pistol_normal'
    WeaponExpandSound = WwiseEvent'Wwise_Weapons_S_Bloodpack.Play_wep_s_bloodpack_expand'
    WeaponCollapseSound = WwiseEvent'Wwise_Weapons_S_Bloodpack.Play_wep_s_bloodpack_collapse'
    AmmoPowerPSCO = AmmoPowerHologram
    AmmoPowerIconPSCO = AmmoPowerIconHologram
    bLoopingFlashEmitter = TRUE
    AnimType = WeaponAnimType.WeaponAnimType_AutoPistol
    InstantHitMomentum = (0.0, 1.0, 15.0, 1.0)
    InstantHitDamageTypes = (None, Class'SFXDamageType_Default', Class'SFXDamageType_Bloodpack_MP', Class'SFXDamageType_Default')
    Mesh = WeaponMesh
    DroppedPickupMesh = PickupMesh
    PickupFactoryMesh = PickupMesh
    Components = (WeaponMesh)
    Modules = (GEMod0, ModManager0)
}