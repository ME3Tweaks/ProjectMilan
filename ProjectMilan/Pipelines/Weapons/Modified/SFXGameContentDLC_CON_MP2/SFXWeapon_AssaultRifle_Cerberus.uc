// MILAN Weapon
// Source: MP2
Class SFXWeapon_AssaultRifle_Cerberus extends SFXWeapon_AssaultRifle_Base
    placeable
    config(Weapon);

// Functions
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
        Samples = ({Duration = 0.349999994, LeftAmplitude = 85, RightAmplitude = 85, LeftFunction = EWaveformFunction.WF_LinearDecreasing, RightFunction = EWaveformFunction.WF_LinearDecreasing}
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
        Template = ParticleSystem'BioVFX_DLC_Wpn_ASLo_GUN01.Particles.ASL_Muzzle' // MILAN CHANGE - Use GUN01 Asset
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
    Begin Template Class=PointLightComponent Name=MuzFlashLight0 // MILAN CHANGE - Add flashlight component
    End Template
    Begin Template Class=SFXModule_GameEffectManager Name=GEMod0
    End Template
    Begin Template Class=SFXModule_WeaponModManager Name=ModManager0
    End Template
    Begin Template Class=SkeletalMeshComponent Name=PickupMesh
        SkeletalMesh = SkeletalMesh'BIOG_WPN_ASL_O_CON_GUN01.ASLo.WPN_ASLo_MDL'// MILAN CHANGE - Use GUN01 Asset
        ReplacementPrimitive = None
    End Template
    Begin Template Class=SkeletalMeshComponent Name=WeaponMesh // MILAN CHANGE - Use GUN01 assets
        SkeletalMesh = SkeletalMesh'BIOG_WPN_ASL_O_CON_GUN01.ASLo.WPN_ASLo_MDL'
        AnimTreeTemplate = AnimTree'BIOG_AnimTree_Weapon.BIOG_WPN_Main_O'
        PhysicsAsset = PhysicsAsset'BIOG_PHY_Weapons_F_CON_GUN01.PHY_WPN_ASLo'
        AnimSets = (AnimSet'BIOG_WPN_A_CON_GUN01.WPN_ASLo_Main')
        ReplacementPrimitive = None
    End Template
    AI_AccCone_Min = {X = 1.20000005, Y = 1.20000005}
    AI_AccCone_Max = {X = 1.79999995, Y = 1.79999995}
    ReloadDuration = {X = 1.37, Y = 1.37}
    Damage = {X = 106.199997, Y = 129.5}
    MagSize = {X = 20.0, Y = 20.0}
    MaxSpareAmmo = {X = 80.0, Y = 100.0}
    MinAimError = {X = 2.5, Y = 2.5}
    MaxAimError = {X = 4.5, Y = 4.5}
    MinZoomAimError = {X = 0.100000001, Y = 0.100000001}
    MaxZoomAimError = {X = 0.449999988, Y = 0.449999988}
    RateOfFire = {X = 550.0, Y = 550.0}
    EncumbranceWeight = {X = 1.75, Y = 1.0}
    Recoil = {X = 4.5, Y = 4.5}
    ZoomRecoil = {X = 1.5, Y = 1.5}
    AccFirePenalty = {X = 19.0, Y = 19.0}
    AccFireInterpSpeed = {X = 18.0, Y = 18.0}
    ZoomAccFirePenalty = {X = 37.0, Y = 37.0}
    ZoomAccFireInterpSpeed = {X = 35.0, Y = 35.0}
    MinZoomCrosshairRange = {X = 22.0, Y = 22.0}
    MaxZoomCrosshairRange = {X = 44.0, Y = 44.0}
    StatBarAccuracy = {X = 65.0, Y = 65.0}
    StatBarDamage = {X = 93.1999969, Y = 116.5}
    GUIImage = "GUI_MPImages_GUN01.asl_cerberus_512x256" // MILAN CHANGE - Use GUN01 asset
    NotificationImage = "GUI_MPImages_GUN01.asl_cerberus_256x128" // MILAN CHANGE - Use GUN01 asset
    WeaponModBodyColours = ({R = 0.0199999996, G = 0.0199999996, B = 0.0399999991, A = 0.0}
                           )
    FiringShake = {
                   RotAmplitude = {X = 75.0, Y = 100.0, Z = 75.0}, 
                   RotFrequency = {X = 100.0, Y = 50.0, Z = 50.0}, 
                   LocAmplitude = {X = 4.0, Y = 0.0, Z = 0.0}, 
                   TimeDuration = 0.0500000007
                  }
    TightAimFiringShake = {
                           RotAmplitude = {X = 75.0, Y = 100.0, Z = 75.0}, 
                           RotFrequency = {X = 100.0, Y = 50.0, Z = 50.0}, 
                           LocAmplitude = {X = 4.0, Y = 0.0, Z = 0.0}, 
                           TimeDuration = 0.0500000007
                          }
    TracerInfo = {
                  Scale3D = {X = 1.5, Y = 1.0, Z = 1.0}, 
                  StaticMesh = StaticMesh'BioVFX_C_Wpn_Mtk.Meshes.Tracer_CR2_Mesh', 
                  StandardPSTemplate = ParticleSystem'BioVFX_C_Weapons.Tracers.Particles.Tracer_Smoke_Trail', 
                  PlayerPSTemplate = ParticleSystem'BioVFX_C_Weapons.Tracers.Particles.Tracer_Smoke_Trail', 
                  AccelRate = 11000.0, 
                  Speed = 22000.0, 
                  MaxSpeed = 26000.0
                 }
    AI_BurstFireCount = {X = 3.0, Y = 6.0}
    AI_BurstFireDelay = {X = 0.899999976, Y = 1.5}
    CoverLeanExitDelay = 0.150000006
    CoverPartialLeanExitDelay = 0.200000003
    PSC_OutOfAmmoEffect = OutOfAmmoEffect0
    OutOfAmmoRumble = OutOfAmmoRumble0
    WeaponFireWaveForm = ForceFeedbackWaveformBase
    EjectRumble = EjectRumble0
    PS_DefaultImpactEffect = ParticleSystem'BioVFX_DLC_Wpn_ASLo_GUN01.Particles.ALC_Imp' // MILAN Change - Use GUN01 asset
    PSC_ShellCasing = ShellCasingPSC0
    PSC_ReloadVent = ReloadVent0
    TracerSpawnOffset = 2.0
    PSC_MuzFlashEmitter = MuzFlashPSC0
    // MILAN Change - Flashlight component vars
    LC_MuzzleFlashLight = MuzFlashLight0
    MuzzleLightLifetime = 0.0500000007
    MuzzleLightBrightness = 0.300000012
    MuzzleLightColor = {B = 255, G = 1, R = 100, A = 0}
    MuzzleLightFalloffExponent = 15.0
    MuzzleLightRadius = 600.0
    // End Milan change
    EjectShellCasingTimeRatio = 0.486000001
    LowAmmoSoundThreshold = 5.0
    LazyRateOfFire = 0.00999999978
    RateOfFireAI = 1.0
    RecoilInterpSpeed = 15.0
    RecoilFadeSpeed = 3.0
    RecoilZoomFadeSpeed = 0.949999988
    RecoilYawScale = 0.200000003
    RecoilYawFrequency = 60.0
    IconResource = GFxMovieInfo'GUI_SF_ME3_DLC_Cerbrs_GUN01.ME3_DLC_CerberusAssault' // MILAN Change - Use Gun01 asset
    IconRef = 2
    PrettyName = $731643
    ShortPrettyName = $731643
    ShortDescription = $731644
    GeneralDescription = $731645
    FireSound = WwiseEvent'Wwise_Weapons_S_Cerb_SP.Play_wep_np_cerberus_fire_SP' // MILAN Change - Use Gun01 asset
    PlayerFireSound = WwiseEvent'Wwise_Weapons_S_Cerb_SP.Play_wep_p_cerberus_fire_SP' // MILAN Change - Use Gun01 asset
    WeaponReloadSound = WwiseEvent'Wwise_Weapons_Generic.Play_wep_g_reload_assault_normal'
    WeaponExpandSound = WwiseEvent'Wwise_Weapons_S_Cerb_SP.Play_wep_s_cerberus_expand_SP' // MILAN Change - Use Gun01 asset
    WeaponCollapseSound = WwiseEvent'Wwise_Weapons_S_Cerb_SP.Play_wep_s_cerberus_collapse_SP' // MILAN Change - Use Gun01 asset
    AmmoPowerPSCO = AmmoPowerHologram
    AmmoPowerIconPSCO = AmmoPowerIconHologram
    InstantHitMomentum = (0.0, 1.0, 30.0, 1.0)
    InstantHitDamageTypes = (None, Class'SFXDamageType_Default', Class'SFXDamageType_MattockAssaultRifle', Class'SFXDamageType_Default')
    Mesh = WeaponMesh
    DroppedPickupMesh = PickupMesh
    PickupFactoryMesh = PickupMesh
    Components = (WeaponMesh)
    Modules = (GEMod0, ModManager0)
}