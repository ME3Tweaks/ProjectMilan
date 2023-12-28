// MILAN Weapon
// Source: MP3
Class SFXWeapon_Shotgun_Assault extends SFXWeapon_Shotgun_Base
    placeable
    config(Weapon);

// Variables
var WwiseEvent ShellSound;
var AnimSet ShotgunShotAnimset;

// Functions
public simulated function WeaponFired(byte FiringMode, bool bViaReplication, optional Vector HitLocation)
{
    Super(SFXWeapon).WeaponFired(FiringMode, bViaReplication, HitLocation);
    WeaponAnimNode.PlayCustomAnim('WPN_ChargeRelease', 1.0);
}
public simulated function InitializeWeapon()
{
    Super(SFXWeapon).InitializeWeapon();
    HackLoadWeaponMods();
}
public simulated function PlayMuzzleFlashEffect()
{
    Super(SFXWeapon).PlayMuzzleFlashEffect();
    PlayReloadEject();
    WeaponPlayWwiseEvent(ShellSound);
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
simulated state Inactive 
{
    // State Functions
    public simulated function BeginState(Name PreviousStateName)
    {
        local BioPawn BP;
        
        BP = BioPawn(Instigator);
        if (BP != None)
        {
            BP.RmvAnimSet(ShotgunShotAnimset);
        }
        Super(SFXWeapon).BeginState(PreviousStateName);
    }
    
    // State code
    stop;
};
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
    Begin Template Class=ForceFeedbackWaveform Name=OutOfAmmoRumble0
    End Template
    Begin Template Class=ParticleSystemComponent Name=AmmoPowerHologram
        ReplacementPrimitive = None
    End Template
    Begin Template Class=ParticleSystemComponent Name=AmmoPowerIconHologram
        ReplacementPrimitive = None
    End Template
    Begin Object Class=ParticleSystemComponent Name=MuzFlashPSC0
        Template = ParticleSystem'BioVFX_DLC_GUN02_Piranha.Particles.ShotGun_Imp' // MILAN CHANGE - Use GUN02 asset
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
    Begin Object Class=SFXAnimSetCookSpec Name=tempAnimInfo
        AnimSet = AnimSet'BIOG_HMM_CB_A.HMM_CB_ShotgunAuto_AlternateSlow'
    End Object
    Begin Template Class=SFXModule_GameEffectManager Name=GEMod0
    End Template
    Begin Template Class=SFXModule_WeaponModManager Name=ModManager0
    End Template
    Begin Template Class=SkeletalMeshComponent Name=PickupMesh
        SkeletalMesh = SkeletalMesh'BIOG_WPN_BLS_L_CON_MP3.BLSl.WPN_BLSl_MDL'
        ReplacementPrimitive = None
    End Template
    Begin Template Class=SkeletalMeshComponent Name=WeaponMesh
        SkeletalMesh = SkeletalMesh'BIOG_WPN_BLS_L_CON_MP3.BLSl.WPN_BLSl_MDL'
        AnimTreeTemplate = AnimTree'BIOG_AnimTree_Weapon.BIOG_WPN_Main_O' // MILAN CHANGE - Use GUN02 assets
        PhysicsAsset = PhysicsAsset'BIOG_PHY_Weapons_F_CON_GUN02.WPN_PHY_BLSl'
        AnimSets = (AnimSet'BIOG_WPN_A_CON_GUN02.WPN_BLSl_Main')
        ReplacementPrimitive = None
    End Template
    ShellSound = WwiseEvent'Wwise_Weapon_DLC_Des_Assault.Play_foley_weapon_des_assault_expand'
    ShotgunShotAnimset = AnimSet'BIOG_HMM_CB_CON_GUN02.HMM_CB_ShotgunShoot' // MILAN CHANGE - Use GUN02 animation
    PelletSpread = ({X = -1024.0, Y = -256.0}, 
                    {X = -1024.0, Y = 256.0}, 
                    {X = 1024.0, Y = -256.0}, 
                    {X = 1024.0, Y = 256.0}, 
                    {X = -256.0, Y = 1024.0}, 
                    {X = -256.0, Y = -1024.0}, 
                    {X = 256.0, Y = 1024.0}, 
                    {X = 256.0, Y = -1024.0}
                   )
    AI_AccCone_Min = {X = 1.10000002, Y = 1.10000002}
    AI_AccCone_Max = {X = 1.79999995, Y = 1.79999995}
    ReloadDuration = {X = 2.56999993, Y = 2.56999993}
    Damage = {X = 63.5999985, Y = 79.5999985}
    MagSize = {X = 8.0, Y = 8.0}
    MaxSpareAmmo = {X = 48.0, Y = 64.0}
    MinAimError = {X = 0.0, Y = 0.0}
    MaxAimError = {X = 0.0, Y = 0.0}
    MinZoomAimError = {X = 0.0, Y = 0.0}
    MaxZoomAimError = {X = 0.0, Y = 0.0}
    RateOfFire = {X = 150.0, Y = 150.0}
    EncumbranceWeight = {X = 1.5, Y = 0.899999976}
    Recoil = {X = 2.18000007, Y = 2.18000007}
    ZoomRecoil = {X = 2.5, Y = 2.5}
    AccFirePenalty = {X = 0.25, Y = 0.25}
    AccFireInterpSpeed = {X = 1.0, Y = 1.0}
    ZoomAccFirePenalty = {X = 0.25, Y = 0.25}
    ZoomAccFireInterpSpeed = {X = 1.0, Y = 1.0}
    MinZoomCrosshairRange = {X = 180.0, Y = 180.0}
    MaxZoomCrosshairRange = {X = 400.0, Y = 400.0}
    StatBarAccuracy = {X = 10.0, Y = 10.0}
    StatBarDamage = {X = 384.799988, Y = 481.600006}
    StatBarRateOfFire = {X = 150.0, Y = 150.0}
    GUIImage = "DLC_MPImages.asl_N7Shotgun_512x256" // MILAN CHANGE - Use GUN02 asset
    NotificationImage = "DLC_MPImages.asl_N7Shotgun_256x128" // MILAN CHANGE - Use GUN02 asset
    WeaponModBodyColours = ({R = 0.0799999982, G = 0.0900000036, B = 0.100000001, A = 0.0}
                           )
    FiringShake = {
                   RotAmplitude = {X = 500.0, Y = 100.0, Z = -500.0}, 
                   RotFrequency = {X = 15.0, Y = 10.0, Z = 10.0}, 
                   LocAmplitude = {X = 10.0, Y = 0.0, Z = 0.0}, 
                   LocFrequency = {X = 15.0, Y = 0.0, Z = 0.0}, 
                   TimeDuration = 0.25999999
                  }
    TightAimFiringShake = {
                           RotAmplitude = {X = 700.0, Y = 100.0, Z = -700.0}, 
                           RotFrequency = {X = 25.0, Y = 15.0, Z = 15.0}, 
                           LocAmplitude = {X = 15.0, Y = 0.0, Z = 0.0}, 
                           LocFrequency = {X = 25.0, Y = 0.0, Z = 0.0}, 
                           TimeDuration = 0.25999999
                          }
    TracerInfo = {
                  Scale3D = {X = 1.5, Y = 1.0, Z = 1.0}, 
                  PlayerPSTemplate = ParticleSystem'BioVFX_C_Weapons.Tracers.Particles.Tracer_Smoke_Trail_Flak', 
                  AccelRate = 15000.0, 
                  Speed = 3500.0, 
                  MaxSpeed = 15000.0
                 }
    MuzzleIdlePosition = {X = 72.0, Y = 9.0, Z = 34.0}
    AI_BurstFireCount = {X = 2.0, Y = 3.0}
    AI_BurstFireDelay = {X = 0.649999976, Y = 2.29999995}
    ReloadAnimInfo = tempAnimInfo
    PSC_OutOfAmmoEffect = OutOfAmmoEffect0
    OutOfAmmoRumble = OutOfAmmoRumble0
    WeaponFireWaveForm = ForceFeedbackWaveformBase
    EjectRumble = EjectRumble0
    PS_DefaultImpactEffect = ParticleSystem'BioVFX_DLC_GUN02_Piranha.Particles.ShotGun_Imp' // MILAN CHANGE - Use GUN02 asset
    PSC_ShellCasing = ShellCasingPSC0
    PSC_ReloadVent = ReloadVent0
    PSC_MuzFlashEmitter = MuzFlashPSC0
    LC_MuzzleFlashLight = MuzFlashLight0 // MILAN CHANGE - Flashlight component
    ShellCasingSocketName = 'CoolDown1'
    EjectShellCasingTimeRatio = 0.405000001
    LowAmmoSoundThreshold = 2.0
    NoAmmoFireSoundDelay = 0.899999976
    LazyRateOfFire = 0.00999999978
    RateOfFireAI = 1.0
    RecoilYawScale = 0.5
    IconResource = GFxMovieInfo'GUI_SF_ME3_DLC_Gun02.ME3_DLC_N7Shotgun' // MILAN CHANGE - Use GUN02 asset
    IconRef = 2
    PrettyName = $744389
    ShortPrettyName = $744389
    ShortDescription = $744425
    GeneralDescription = $744427
    FireSound = WwiseEvent'Wwise_Weapons_S_AssaultShot.Play_wep_np_assault_fire'
    PlayerFireSound = WwiseEvent'Wwise_Weapons_S_AssaultShot.Play_wep_p_assault_fire'
    FireNoAmmoSound = WwiseEvent'Wwise_Weapons_Standard_LowAmmo.Play_weapon_dryfire_shotguns'
    WeaponReloadSound = WwiseEvent'Wwise_Weapons_Generic.Play_wep_g_reload_shotgun_heavy'
    WeaponExpandSound = WwiseEvent'Wwise_Generic_Gameplay.Play_foley_weapon_shotgun_expand'
    WeaponCollapseSound = WwiseEvent'Wwise_Generic_Gameplay.Play_foley_weapon_shotgun_collapse'
    AmmoPowerPSCO = AmmoPowerHologram
    AmmoPowerIconPSCO = AmmoPowerIconHologram
    bScaleAnimDurationByFireRate = TRUE
    DefaultFireMode = FireModes.FireMode_FullAuto
    InstantHitMomentum = (0.0, 50.0, 50.0, 1.0)
    InstantHitDamageTypes = (None, Class'SFXDamageType_Shotgun', Class'SFXDamageType_Shotgun', Class'SFXDamageType_Default')
    FireOffset = {X = 1.0, Y = -1.0, Z = 1.0}
    Mesh = WeaponMesh
    AIRating = 1.0
    DroppedPickupMesh = PickupMesh
    PickupFactoryMesh = PickupMesh
    Components = (WeaponMesh)
    Modules = (GEMod0, ModManager0)
}