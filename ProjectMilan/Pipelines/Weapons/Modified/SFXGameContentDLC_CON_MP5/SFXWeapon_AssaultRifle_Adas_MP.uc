// MILAN Weapon 
// Source: MP5
// Note: This gun was originally in GUN02 and ported to MP.
Class SFXWeapon_AssaultRifle_Adas_MP extends SFXWeapon_AssaultRifle_Base
    placeable
    config(Weapon);

// Variables
var Guid WeaponCrustGuid;
var RvrClientEffectInterface CE_WeaponCrust;
var bool bWeaponCrustActive;

// Functions
public simulated function InitializeWeapon()
{
    Super(SFXWeapon).InitializeWeapon();
    HackLoadWeaponMods();
}
public simulated function SetAmmoPowerHologramEnabled(bool bEnabled, optional bool bForceEnabled)
{
    Super(SFXWeapon).SetAmmoPowerHologramEnabled(bEnabled, bForceEnabled);
    if (bEnabled)
    {
        StartWeaponCrust();
    }
    else
    {
        EndWeaponCrust();
    }
}
public simulated function ShutOffAllEmitters()
{
    EndWeaponCrust();
    Super(SFXWeapon).ShutOffAllEmitters();
}
public function EndWeaponCrust()
{
    if (!bWeaponCrustActive)
    {
        return;
    }
    bWeaponCrustActive = FALSE;
    Class'RvrClientEffectManager'.static.GetClientEffectManager().Stop(None, WeaponCrustGuid, TRUE);
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
public function StartWeaponCrust()
{
    local RvrClientEffectTarget TargetInfo;
    
    if (bWeaponCrustActive)
    {
        return;
    }
    bWeaponCrustActive = TRUE;
    TargetInfo.Instigator = Instigator;
    TargetInfo.HitBone = 'Flash_2';
    WeaponCrustGuid = Class'RvrClientEffectManager'.static.GetClientEffectManager().StartOnTarget(CE_WeaponCrust, TargetInfo);
}

// States
state WeaponFiring 
{
    // State Functions
    public simulated function EndState(Name NextStateName)
    {
        WeaponAnimNode.StopCustomAnim(0.200000003);
        WeaponAnimNode.PlayCustomAnim('WPN_ChargeRelease', 1.0);
        Super(SFXWeapon).EndState(NextStateName);
    }
    public simulated function BeginState(Name PreviousStateName)
    {
        WeaponAnimNode.PlayCustomAnim('WPN_ChargeUp', 1.0);
        WeaponAnimNode.PlayCustomAnim('WPN_ChargeHold', 1.0, 1.0, 0.0, TRUE);
        Super(SFXWeapon).BeginState(PreviousStateName);
    }
    
    // State code
    stop;
};
simulated state WeaponPuttingDown 
{
    // State Functions
    public simulated function BeginState(Name PreviousStateName)
    {
        EndWeaponCrust();
        Super(SFXWeapon).BeginState(PreviousStateName);
    }
    
    // State code
    stop;
};
simulated state Inactive 
{
    // State Functions
    public simulated function BeginState(Name PreviousStateName)
    {
        EndWeaponCrust();
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
        StartWeaponCrust();
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
        Samples = ({Duration = 0.125, LeftAmplitude = 55, RightAmplitude = 55, LeftFunction = EWaveformFunction.WF_Sin90to180, RightFunction = EWaveformFunction.WF_Sin90to180}
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
        Template = ParticleSystem'BioVFX_DLC_Wpn_Quarian_GUN01.Particles.Quarian_Mzl' // MILAN CHANGE - Use GUN01 asset
        bAutoActivate = FALSE
        ReplacementPrimitive = None
    End Object
    Begin Template Class=ParticleSystemComponent Name=OutOfAmmoEffect0
        Template = ParticleSystem'BioVFX_C_Reload.Particles.Reload_VentHeat_Geth_2'
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
    Begin Template Class=PointLightComponent Name=MuzFlashLight0 // MILAN CHANGE - Add muzzle flash component
    End Template
    Begin Object Class=SFXAnimSetCookSpec Name=tempAnimInfo
        AnimSet = AnimSet'BIOG_HMM_CB_A.HMM_CB_RifleAuto_SlowAlternate'
    End Object
    Begin Template Class=SFXModule_GameEffectManager Name=GEMod0
    End Template
    Begin Template Class=SFXModule_WeaponModManager Name=ModManager0
    End Template
    Begin Template Class=SkeletalMeshComponent Name=PickupMesh
        SkeletalMesh = SkeletalMesh'BIOG_WPN_ASL_R.ASLc.WPN_ASLc_MDL'
        ReplacementPrimitive = None
    End Template
    Begin Template Class=SkeletalMeshComponent Name=WeaponMesh
        SkeletalMesh = SkeletalMesh'BIOG_WPN_ASL_Q_CON_GUN01.WPN_ASLq_MDL'
        AnimTreeTemplate = AnimTree'BIOG_AnimTree_Weapon.BIOG_WPN_Main_O'  // MILAN CHANGE - Use GUN01 assets
        PhysicsAsset = PhysicsAsset'BIOG_PHY_Weapons_F_CON_GUN01.WPN_PHY_ASLq'
        AnimSets = (AnimSet'BIOG_WPN_A_CON_GUN01.WPN_ASLq_Main')
        ReplacementPrimitive = None
    End Template
    CE_WeaponCrust = RvrClientEffect'BioVFX_DLC_Wpn_Quarian_GUN01.VCFX.Quarian_Gun_Crust_VCFX' // MILAN CHANGE - Use GUN01 asset
    AI_AccCone_Min = {X = 1.5, Y = 1.5}
    AI_AccCone_Max = {X = 3.5, Y = 3.5}
    ReloadDuration = {X = 2.9000001, Y = 2.9000001}
    Damage = {X = 129.5, Y = 161.899994}
    MagSize = {X = 24.0, Y = 24.0}
    MaxSpareAmmo = {X = 72.0, Y = 96.0}
    MinAimError = {X = 0.5, Y = 0.5}
    MaxAimError = {X = 1.0, Y = 1.0}
    MinZoomAimError = {X = 0.25, Y = 0.25}
    MaxZoomAimError = {X = 1.0, Y = 1.0}
    RateOfFire = {X = 125.0, Y = 125.0}
    EncumbranceWeight = {X = 2.0, Y = 1.39999998}
    Recoil = {X = 0.0120000001, Y = 0.0120000001}
    ZoomRecoil = {X = 0.0120000001, Y = 0.0120000001}
    AccFirePenalty = {X = 19.0, Y = 19.0}
    AccFireInterpSpeed = {X = 18.0, Y = 18.0}
    ZoomAccFirePenalty = {X = 37.0, Y = 37.0}
    ZoomAccFireInterpSpeed = {X = 35.0, Y = 35.0}
    MinZoomCrosshairRange = {X = 33.0, Y = 33.0}
    MaxZoomCrosshairRange = {X = 55.0, Y = 55.0}
    StatBarAccuracy = {X = 15.0, Y = 15.0}
    StatBarDamage = {X = 129.5, Y = 161.899994}
    StatBarRateOfFire = {X = 150.0, Y = 150.0}
    GUIImage = "DLC_MPImages.Weapons.asl_quarian_512x256" // MILAN CHANGE - Use GUN01 asset
    NotificationImage = "DLC_MPImages.Weapons.asl_quarian_256x128" // MILAN CHANGE - Use GUN01 asset
    WeaponModBodyColours = ({R = 0.189999998, G = 0.189999998, B = 0.219999999, A = 0.0}
                           )
    GUIZoomReticleClass = Class'SFXGUI_WeaponReticleSimple'
    FiringShake = {
                   RotAmplitude = {X = 85.0, Y = 40.0, Z = 0.0}, 
                   RotFrequency = {X = 65.0, Y = 90.0, Z = 0.0}, 
                   LocAmplitude = {X = -1.5, Y = 0.0, Z = 0.0}, 
                   LocFrequency = {X = 12.0, Y = 0.0, Z = 0.0}, 
                   TimeDuration = 0.125
                  }
    TightAimFiringShake = {
                           RotAmplitude = {X = 85.0, Y = 40.0, Z = 0.0}, 
                           RotFrequency = {X = 65.0, Y = 90.0, Z = 0.0}, 
                           LocAmplitude = {X = -1.5, Y = 0.0, Z = 0.0}, 
                           LocFrequency = {X = 12.0, Y = 0.0, Z = 0.0}, 
                           TimeDuration = 0.125
                          }
    AI_BurstFireCount = {X = 25.0, Y = 40.0}
    AI_BurstFireDelay = {X = 0.649999976, Y = 1.25}
    ReloadAnimInfo = tempAnimInfo
    PSC_OutOfAmmoEffect = OutOfAmmoEffect0
    OutOfAmmoRumble = OutOfAmmoRumble0
    WeaponFireWaveForm = ForceFeedbackWaveformBase
    EjectRumble = EjectRumble0
    PSC_ShellCasing = ShellCasingPSC0
    PSC_ReloadVent = ReloadVent0
    TracerSpawnOffset = 2.0
    PSC_MuzFlashEmitter = MuzFlashPSC0  
    // MILAN CHANGE - Muzzle lights
    LC_MuzzleFlashLight = MuzFlashLight0 
    MuzzleLightLifetime = 0.0500000007
    MuzzleLightBrightness = 0.300000012
    MuzzleLightColor = {B = 150, G = 200, R = 1, A = 0}
    MuzzleLightFalloffExponent = 15.0
    MuzzleLightRadius = 600.0
    // END MILAN CHANGE
    EjectShellCasingTimeRatio = 0.460000008
    LowAmmoSoundThreshold = 2.0
    SteamSoundThreshold = 1.0
    NoAmmoFireSoundDelay = 0.5
    MinRefireTime = 0.75
    LazyRateOfFire = 0.00999999978
    RateOfFireAI = 1.0
    RecoilYawScale = 0.200000003
    RecoilYawFrequency = 0.5
    DistancePenetrated = 50.0
    IconResource = GFxMovieInfo'GUI_SF_ME3_DLC_QuarianAst.ME3_DLC_QuarianAssalt' // MILAN CHANGE - Use GUN01 asset
    IconRef = 2
    PrettyName = $766086
    ShortPrettyName = $766086
    ShortDescription = $766087
    GeneralDescription = $766088
    FireSound = WwiseEvent'Wwise_Weapons_S_Quarian_AR.Play_wep_np_quarian_fire'
    PlayerFireSound = WwiseEvent'Wwise_Weapons_S_Quarian_AR.Play_wep_p_quarian_fire'
    FireNoAmmoSound = WwiseEvent'Wwise_Weapons_Standard_LowAmmo.Play_weapon_dryfire_machineguns'
    WeaponReloadSound = WwiseEvent'Wwise_Weapons_Generic.Play_wep_g_reload_assault_heavy'
    WeaponExpandSound = WwiseEvent'Wwise_Weapons_S_Quarian_AR.Play_wep_s_quarian_ar_expand'
    WeaponCollapseSound = WwiseEvent'Wwise_Weapons_S_Quarian_AR.Play_wep_s_quarian_ar_collapse'
    SteamReloadNotifySound = WwiseEvent'Wwise_Weapons_Standard_LowAmmo.Play_overheat'
    AmmoPowerPSCO = AmmoPowerHologram
    AmmoPowerIconPSCO = AmmoPowerIconHologram
    bLoopingFlashEmitter = TRUE
    bNotRegularWeaponGUI = TRUE
    bScaleAnimDurationByFireRate = TRUE
    WeaponFireTypes = (EWeaponFireType.EWFT_InstantHit, EWeaponFireType.EWFT_InstantHit, EWeaponFireType.EWFT_Projectile, EWeaponFireType.EWFT_InstantHit, EWeaponFireType.EWFT_InstantHit)
    WeaponProjectiles = (None, None, Class'SFXProjectile_Adas_MP')
    InstantHitMomentum = (0.0, 1.0, 35.0, 1.0)
    InstantHitDamageTypes = (None, Class'SFXDamageType_Default', Class'SFXDamageType_Adas', Class'SFXDamageType_Default')
    Mesh = WeaponMesh
    AIRating = 30.0
    DroppedPickupMesh = PickupMesh
    PickupFactoryMesh = PickupMesh
    Components = (WeaponMesh)
    Modules = (GEMod0, ModManager0)
}