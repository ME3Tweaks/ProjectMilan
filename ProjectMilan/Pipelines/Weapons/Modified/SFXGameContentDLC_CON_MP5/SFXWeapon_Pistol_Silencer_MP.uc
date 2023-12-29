// MILAN Weapon
// Source: MP5
Class SFXWeapon_Pistol_Silencer_MP extends SFXWeapon_Pistol_Base
    placeable
    config(Weapon);

// Functions
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
        Samples = ({Duration = 0.100000001, LeftAmplitude = 50, RightAmplitude = 50, LeftFunction = EWaveformFunction.WF_Constant, RightFunction = EWaveformFunction.WF_Constant}
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
        Template = ParticleSystem'BioVFX_C_Wpn_Tmp.Particles.CR2_Muzzle'
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
    Begin Template Class=PointLightComponent Name=MuzFlashLight0 // MILAN CHANGE - Add muzzle flashlight
    End Template
    Begin Template Class=SFXModule_GameEffectManager Name=GEMod0
    End Template
    Begin Template Class=SFXModule_WeaponModManager Name=ModManager0
    End Template
    Begin Template Class=SkeletalMeshComponent Name=PickupMesh
        SkeletalMesh = SkeletalMesh'BIOG_WPN_PSTs_R.PSTs.WPN_PSTs_MDL'
        ReplacementPrimitive = None
    End Template
    Begin Template Class=SkeletalMeshComponent Name=WeaponMesh
        SkeletalMesh = SkeletalMesh'BIOG_WPN_PSTs_R.PSTs.WPN_PSTs_MDL'
        AnimTreeTemplate = AnimTree'BIOG_AnimTree_Weapon.BIOG_WPN_Main_O'  
        PhysicsAsset = PhysicsAsset'BIOG_PHY_Weapons_F_CON_EXP03.WPN_PHY_PSTs'
        AnimSets = (AnimSet'BIOG_WPN_A_CON_EXP003.WPN_PSTs_Main')
        ReplacementPrimitive = None
    End Template
    AI_AccCone_Min = {X = 1.10000002, Y = 1.10000002}
    AI_AccCone_Max = {X = 2.0999999, Y = 2.0999999}
    ReloadDuration = {X = 1.5, Y = 1.5}
    Damage = {X = 125.699997, Y = 157.100006}
    MagSize = {X = 6.0, Y = 6.0}
    MaxSpareAmmo = {X = 30.0, Y = 40.0}
    MinAimError = {X = 1.0, Y = 1.0}
    MaxAimError = {X = 3.0, Y = 3.0}
    MinZoomAimError = {X = 0.349999994, Y = 0.349999994}
    MaxZoomAimError = {X = 1.25, Y = 1.25}
    RateOfFire = {X = 600.0, Y = 600.0}
    HeadshotDamageMultiplier = {X = 4.0, Y = 4.0}
    EncumbranceWeight = {X = 1.20000005, Y = 0.699999988}
    Recoil = {X = 0.075000003, Y = 0.075000003}
    ZoomRecoil = {X = 0.100000001, Y = 0.100000001}
    AccFirePenalty = {X = 260.0, Y = 260.0}
    AccFireInterpSpeed = {X = 420.0, Y = 420.0}
    ZoomAccFirePenalty = {X = 24.0, Y = 24.0}
    ZoomAccFireInterpSpeed = {X = 31.0, Y = 31.0}
    MinZoomCrosshairRange = {X = 27.0, Y = 27.0}
    MaxZoomCrosshairRange = {X = 45.0, Y = 45.0}
    StatBarAccuracy = {X = 55.0, Y = 55.0}
    StatBarDamage = {X = 125.699997, Y = 157.100006}
    StatBarRateOfFire = {X = 600.0, Y = 600.0}
    GUIImage = "DLC_MPImages.Weapons.pst_carniflexSli_512x256" // MILAN CHANGE - Use EXP_Pack003 version
    NotificationImage = "DLC_MPImages.Weapons.pst_carniflexSli_256x128" // MILAN CHANGE - Use EXP_Pack003 version
    WeaponModBodyColours = ({R = 0.0, G = 0.0, B = 0.0, A = 0.0}
                           )
    FiringShake = {
                   RotAmplitude = {X = 45.0, Y = 22.5, Z = 11.25}, 
                   RotFrequency = {X = 80.0, Y = 50.0, Z = 20.0}, 
                   TimeDuration = 0.100000001
                  }
    TightAimFiringShake = {
                           RotAmplitude = {X = 6.0, Y = 6.0, Z = 2.5}, 
                           RotFrequency = {X = 6.0, Y = 8.0, Z = 11.0}, 
                           TimeDuration = 0.100000001
                          }
    TracerInfo = {
                  Scale3D = {X = 2.0, Y = 2.0, Z = 2.0}, 
                  StandardPSTemplate = ParticleSystem'BioVFX_C_Weapons.Tracers.Particles.Tracer_Smoke_Trail', 
                  PlayerPSTemplate = ParticleSystem'BioVFX_C_Weapons.Tracers.Particles.Tracer_Smoke_Trail', 
                  AccelRate = 20000.0, 
                  Speed = 22000.0, 
                  MaxSpeed = 26000.0
                 }
    AI_BurstFireCount = {X = 4.0, Y = 6.0}
    AI_BurstFireDelay = {X = 0.649999976, Y = 2.29999995}
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
    MuzzleLightBrightness = 0.300000012
    MuzzleLightColor = {B = 1, G = 120, R = 255, A = 0}
    MuzzleLightFalloffExponent = 15.0
    MuzzleLightRadius = 300.0
    // END MILAN CHANGE
    EjectShellCasingTimeRatio = 0.558000028
    LowAmmoSoundThreshold = 2.0
    SteamSoundThreshold = 1.0
    NoAmmoFireSoundDelay = 0.800000012
    LazyRateOfFire = 0.00999999978
    RateOfFireAI = 1.0
    RecoilYawScale = 0.200000003
    RecoilYawFrequency = 0.5
    IconResource = GFxMovieInfo'GUI_SF_ME3_DLC_SliCarfxPSL.ME3_DLC_SliCarfxPSL' // MILAN CHANGE - Use EXPPack_003 asset
    IconRef = 29
    PrettyName = $793182
    ShortPrettyName = $793182
    ShortDescription = $793183
    GeneralDescription = $793184
    WeaponLoudness = 0.0  // MILAN CHANGE - Make silencer... silent? This is not in MP5. This may make this weapon too cheesy.
    FireSound = WwiseEvent'Wwise_Weapons_NP_M11Sup.Play_wep_np_m11sup_fire'
    PlayerFireSound = WwiseEvent'Wwise_Weapons_P_M11Sup.Play_wep_p_m11sup_fire'
    WeaponReloadSound = WwiseEvent'Wwise_Weapons_Generic.Play_wep_g_reload_pistol_normal'
    AmmoPowerPSCO = AmmoPowerHologram
    AmmoPowerIconPSCO = AmmoPowerIconHologram
    DefaultFireMode = FireModes.FireMode_SemiAuto
    InstantHitMomentum = (0.0, 15.0, 15.0, 1.0)
    InstantHitDamageTypes = (None, Class'SFXDamageType_HeavyPistol', Class'SFXDamageType_HeavyPistol', Class'SFXDamageType_Default')
    Mesh = WeaponMesh
    DroppedPickupMesh = PickupMesh
    PickupFactoryMesh = PickupMesh
    Components = (WeaponMesh)
    Modules = (GEMod0, ModManager0)
}