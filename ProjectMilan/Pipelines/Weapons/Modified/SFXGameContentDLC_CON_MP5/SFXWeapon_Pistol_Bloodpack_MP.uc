// MILAN Weapon
// Source: MP5
Class SFXWeapon_Pistol_Bloodpack_MP extends SFXWeapon_Pistol_Base
    placeable
    config(Weapon);

// Functions
public simulated function PlayFireEffects(byte FireModeNum, optional Vector HitLocation)
{
    WeaponAnimNode.PlayCustomAnim('WPN_ChargeRelease', 1.0);
    Super(SFXWeapon).PlayFireEffects(FireModeNum, HitLocation);
}
public simulated function DecalComponent GetWeaponSpecificDecalData(SFXPhysicalMaterialDecals DecalEffects, out float FadeTime)
{
    local int DecalLength;
    
    FadeTime = DecalEffects.HandCannonFadeTime;
    DecalLength = DecalEffects.HandCannon.Length;
    if (DecalLength > 0)
    {
        return DecalEffects.HandCannon[Rand(DecalLength)];
    }
    return None;
}
public static simulated function ParticleSystem GetWeaponSpecificImpactEffect(SFXPhysicalMaterialImpactEffects ImpactEffects)
{
    return ImpactEffects.HandCannon;
}
public simulated function WwiseEvent GetWeaponSpecificImpactSound(SFXPhysicalMaterialImpactSounds ImpactSounds)
{
    if (SFXPawn_Player(Instigator) != None && Instigator.IsLocallyControlled())
    {
        return ImpactSounds.HandCannon_Player;
    }
    return ImpactSounds.HandCannon;
}
public simulated function InitializeWeapon()
{
    Super(SFXWeapon).InitializeWeapon();
    HackLoadWeaponMods();
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
        Samples = ({Duration = 0.200000003, LeftAmplitude = 85, RightAmplitude = 85, LeftFunction = EWaveformFunction.WF_Constant, RightFunction = EWaveformFunction.WF_Constant}
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
        Template = ParticleSystem'BioVFX_Wpn_PST_R_GUN02.Particles.PST_R_Muzzle'
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
        SkeletalMesh = SkeletalMesh'BIOG_WPN_PST_R_CON_GUN02.WPN_PSTr_MDL'
        ReplacementPrimitive = None
    End Template
    Begin Template Class=SkeletalMeshComponent Name=WeaponMesh
        SkeletalMesh = SkeletalMesh'BIOG_WPN_PST_R_CON_GUN02.WPN_PSTr_MDL'
        AnimTreeTemplate = AnimTree'BIOG_AnimTree_Weapon.BIOG_WPN_Main_O' // MILAN CHANGE - Use GUN02 assets
        PhysicsAsset = PhysicsAsset'BIOG_PHY_Weapons_F_CON_GUN02.PHY_WPN_PSTr'
        AnimSets = (AnimSet'BIOG_WPN_A_CON_GUN02.WPN_PSTr_Main')
        ReplacementPrimitive = None
    End Template
    AI_AccCone_Min = {X = 1.10000002, Y = 1.10000002}
    AI_AccCone_Max = {X = 1.60000002, Y = 1.60000002}
    ReloadDuration = {X = 1.5, Y = 1.5}
    Damage = {X = 784.900024, Y = 981.099976}
    MaxSpareAmmo = {X = 15.0, Y = 25.0}
    MinAimError = {X = 1.0, Y = 1.0}
    MaxAimError = {X = 6.0, Y = 6.0}
    MinZoomAimError = {X = 0.300000012, Y = 0.300000012}
    MaxZoomAimError = {X = 1.5, Y = 1.5}
    RateOfFire = {X = 60.0, Y = 60.0}
    EncumbranceWeight = {X = 1.20000005, Y = 0.699999988}
    Recoil = {X = 5.80000019, Y = 5.80000019}
    ZoomRecoil = {X = 6.80000019, Y = 6.80000019}
    AccFirePenalty = {X = 6.0, Y = 6.0}
    AccFireInterpSpeed = {X = 20.0, Y = 20.0}
    ZoomAccFirePenalty = {X = 8.0, Y = 8.0}
    ZoomAccFireInterpSpeed = {X = 12.0, Y = 12.0}
    MinZoomCrosshairRange = {X = 25.0, Y = 25.0}
    MaxZoomCrosshairRange = {X = 90.0, Y = 90.0}
    StatBarAccuracy = {X = 65.0, Y = 65.0}
    StatBarDamage = {X = 784.900024, Y = 981.099976}
    StatBarRateOfFire = {X = 60.0, Y = 60.0}
    GUIImage = "DLC_MPImages.Weapons.pst_bloodpack_512x256" // MILAN CHANGE - Use GUN02 asset
    NotificationImage = "DLC_MPImages.Weapons.pst_bloodpack_256x128" // MILAN CHANGE - Use GUN02 asset
    WeaponModBodyColours = ({R = 0.0, G = 0.0, B = 0.0, A = 0.0}
                           )
    FiringShake = {
                   RotAmplitude = {X = 110.0, Y = 20.0, Z = -110.0}, 
                   RotFrequency = {X = 45.0, Y = 25.0, Z = 45.0}, 
                   LocAmplitude = {X = 25.0, Y = 0.0, Z = 0.0}, 
                   LocFrequency = {X = 25.0, Y = 0.0, Z = 0.0}, 
                   TimeDuration = 0.319999993
                  }
    TightAimFiringShake = {
                           RotAmplitude = {X = 145.0, Y = 65.0, Z = 105.0}, 
                           RotFrequency = {X = 100.0, Y = 50.0, Z = 50.0}, 
                           LocAmplitude = {X = 4.0, Y = 0.0, Z = 0.0}, 
                           TimeDuration = 0.300000012
                          }
    TracerInfo = {
                  Scale3D = {X = 2.0, Y = 2.0, Z = 2.0}, 
                  StandardPSTemplate = ParticleSystem'BioVFX_C_Weapons.Tracers.Particles.Tracer_Smoke_Trail_Flak', 
                  PlayerPSTemplate = ParticleSystem'BioVFX_C_Weapons.Tracers.Particles.Tracer_Smoke_Trail_Flak', 
                  AccelRate = 20000.0, 
                  Speed = 22000.0, 
                  MaxSpeed = 26000.0
                 }
    AI_BurstFireCount = {X = 2.0, Y = 3.0}
    AI_BurstFireDelay = {X = 0.649999976, Y = 2.29999995}
    CoverLeanExitDelay = 0.150000006
    CoverPartialLeanExitDelay = 0.200000003
    PSC_OutOfAmmoEffect = OutOfAmmoEffect0
    OutOfAmmoRumble = OutOfAmmoRumble0
    WeaponFireWaveForm = ForceFeedbackWaveformBase
    EjectRumble = EjectRumble0
    PSC_ShellCasing = ShellCasingPSC0
    PSC_ReloadVent = ReloadVent0
    PSC_MuzFlashEmitter = MuzFlashPSC0   
    // MILAN CHANGE - Muzzle flash properties
    LC_MuzzleFlashLight = MuzFlashLight0
    MuzzleLightLifetime = 0.150000006
    MuzzleLightBrightness = 1.39999998
    MuzzleLightColor = {B = 1, G = 120, R = 255, A = 0}
    MuzzleLightFalloffExponent = 15.0
    MuzzleLightRadius = 300.0
    // END MILAN CHANGE
    EjectShellCasingTimeRatio = 0.558000028
    SteamSoundThreshold = 1.0
    NoAmmoFireSoundDelay = 0.800000012
    LazyRateOfFire = 0.00999999978
    RateOfFireAI = 1.0
    RecoilYawScale = 0.200000003
    RecoilYawFrequency = 0.5
    DistancePenetrated = 50.0
    IconResource = GFxMovieInfo'GUI_SF_ME3_DLC_BlpakPSL.ME3_DLC_BlpakPSL' // MILAN CHANGE - Use GUN02 asset
    IconRef = 2
    PrettyName = $788082
    ShortPrettyName = $788082
    ShortDescription = $788541
    GeneralDescription = $788083
    FireSound = WwiseEvent'Wwise_Weapons_S_BP_Pistol.Play_wep_np_bloodpack_pistol_fire'
    PlayerFireSound = WwiseEvent'Wwise_Weapons_S_BP_Pistol.Play_wep_p_bloodpack_pistol_fire'
    FireNoAmmoSound = WwiseEvent'Wwise_Weapons_Standard_LowAmmo.Play_weapon_dryfire_pistols'
    WeaponReloadSound = WwiseEvent'Wwise_Weapons_Generic.Play_wep_g_reload_pistol_normal'
    SteamReloadNotifySound = WwiseEvent'Wwise_Weapons_Standard_LowAmmo.Play_overheat'
    AmmoPowerPSCO = AmmoPowerHologram
    AmmoPowerIconPSCO = AmmoPowerIconHologram
    DefaultFireMode = FireModes.FireMode_SemiAuto
    InstantHitMomentum = (0.0, 40.0, 40.0, 1.0)
    InstantHitDamageTypes = (None, Class'SFXDamageType_Pistol_Bloodpack_MP', Class'SFXDamageType_Pistol_Bloodpack_MP', Class'SFXDamageType_Default')
    FireOffset = {X = 19.0, Y = 0.5, Z = 4.0}
    Mesh = WeaponMesh
    AIRating = 20.0
    DroppedPickupMesh = PickupMesh
    PickupFactoryMesh = PickupMesh
    Components = (WeaponMesh)
    Modules = (GEMod0, ModManager0)
}