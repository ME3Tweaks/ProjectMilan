// MILAN Weapon
// Source: MP3
Class SFXWeapon_AssaultRifle_LMG extends SFXWeapon_AssaultRifle_Base
    placeable
    config(Weapon);

// Variables
var WwiseEvent PowerUpSound1;
var WwiseEvent PowerDownSound1;
var WwiseEvent NPPowerUpSound;
var WwiseEvent NPPowerDownSound;
var transient float FireStartTime;
var editinline export ParticleSystemComponent SteamMuzzle;
var config float MinROF;
var config float RampTime;
var config float DamageMultiplier;
var config float GetHotTime;
var config float FullyChargedTime;
var config float DamageReductionAmount;
var bool bIsHot;

// Functions
public simulated function Destroyed()
{
    local SFXModule_GameEffectManager GEManager;
    
    GEManager = Instigator.GetModule(Class'SFXModule_GameEffectManager');
    if (GEManager != None)
    {
        GEManager.RemoveEffectsByCategory(Name);
    }
    Super(SFXWeapon).Destroyed();
}
public event simulated function WeaponStoppedFiring(byte FiringMode)
{
    Super(SFXWeapon).WeaponStoppedFiring(FiringMode);
    WeaponAnimNode.StopCustomAnim(0.200000003);
    if (bDummyFireWeapon)
    {
        bIsHot = FALSE;
        WeaponPlayWwiseEvent(PowerDownSound1);
    }
}
public simulated function ConsumeAmmo(byte FireModeNum)
{
    if (bIsHot == TRUE && GetMagazineSize() - AmmoUsedCount > 1)
    {
        AmmoPerShot = 2.0;
    }
    else
    {
        AmmoPerShot = 1.0;
    }
    Super(SFXWeapon).ConsumeAmmo(FireModeNum);
    AmmoPerShot = 1.0;
}
public simulated function FireModeUpdated(byte FiringMode, bool bViaReplication)
{
    if (bViaReplication)
    {
        if (int(FiringMode) == 2)
        {
            PlayWindUpEffects();
        }
        else
        {
            PlayWindDownEffects();
        }
    }
    Super(SFXWeapon).FireModeUpdated(FiringMode, bViaReplication);
}
public simulated function TimeWeaponFiring(byte FireModeNum)
{
    if (!IsTimerActive('RefireCheckTimer'))
    {
        SetTimer(GetFireInterval(FireModeNum), FALSE, 'RefireCheckTimer', );
    }
}
public simulated function BeginDummyFire(byte FiringMode, optional Actor AttachedTo)
{
    Super(SFXWeapon).BeginDummyFire(FiringMode);
    WeaponPlayWwiseEvent(PowerUpSound1);
}
public simulated function float GetFireModeBaseDamage()
{
    local float BaseDamage;
    
    if (bIsHot)
    {
        BaseDamage = Damage.Value * DamageMultiplier;
    }
    else if (!bIsHot)
    {
        BaseDamage = Damage.Value;
    }
    return BaseDamage;
}
public simulated function float GetRateOfFire()
{
    local float fRateOfFire;
    
    fRateOfFire = Super(SFXWeapon).GetRateOfFire();
    fRateOfFire = FClamp(Lerp(0.0, fRateOfFire, (WorldInfo.GameTimeSeconds - FireStartTime) / RampTime), MinROF, fRateOfFire);
    return fRateOfFire;
}
public simulated function InitializeWeapon()
{
    Super(SFXWeapon).InitializeWeapon();
    HackLoadWeaponMods();
}
public simulated function PlayNoAmmoEffects()
{
    Super(SFXWeapon).PlayNoAmmoEffects();
    SteamMuzzle.SetActive(TRUE);
    SkeletalMeshComponent(Mesh).AttachComponentToSocket(SteamMuzzle, 'Flash_1');
}
public simulated function PlayReloadEject()
{
    if (SFXPawn_Player(Instigator) != None)
    {
        WeaponAnimNode.StopCustomAnim(0.200000003);
        WeaponAnimNode.PlayCustomAnim('WPN_ChargeRelease', 1.0);
    }
    Super(SFXWeapon).PlayReloadEject();
}
public simulated function FullyCharged()
{
    WeaponAnimNode.PlayCustomAnim('WPN_ChargeHold', 1.0, 1.0, 0.0, TRUE);
}
public simulated function GunIsHot()
{
    bIsHot = TRUE;
    if (SFXPawn_Player(Instigator) != None)
    {
        WeaponAnimNode.PlayCustomAnim('WPN_ChargeUp', 1.0);
        SetTimer(FullyChargedTime, FALSE, 'FullyCharged', );
    }
}
public simulated function PlayWindDownEffects()
{
    if (SFXPawn_Player(Instigator) != None && Instigator.IsLocallyControlled())
    {
        WeaponPlayWwiseEvent(PowerDownSound1);
    }
    else
    {
        WeaponPlayWwiseEvent(NPPowerDownSound);
    }
    ClearTimer('GunIsHot');
    WeaponAnimNode.StopCustomAnim(0.200000003);
    if (bIsHot)
    {
        bIsHot = FALSE;
        WeaponAnimNode.PlayCustomAnim('WPN_ChargeRelease', 1.0);
    }
}
public simulated function PlayWindUpEffects()
{
    if (SFXPawn_Player(Instigator) != None && Instigator.IsLocallyControlled())
    {
        WeaponPlayWwiseEvent(PowerUpSound1);
    }
    else
    {
        WeaponPlayWwiseEvent(NPPowerUpSound);
    }
    SetTimer(GetHotTime, FALSE, 'GunIsHot', );
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
            bIsHot = FALSE;
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
        Super(SFXWeapon).EndState(NextStateName);
        SetCurrentFireMode(0);
        PlayWindDownEffects();
    }
    public simulated function BeginState(Name PreviousStateName)
    {
        FireStartTime = WorldInfo.GameTimeSeconds;
        Super(SFXWeapon).BeginState(PreviousStateName);
        SetCurrentFireMode(2);
        PlayWindUpEffects();
    }
    
    // State code
    stop;
};
simulated state Inactive 
{
    // State Functions
    public simulated function BeginState(Name PreviousStateName)
    {
        local SFXModule_GameEffectManager GEManager;
        
        GEManager = Instigator.GetModule(Class'SFXModule_GameEffectManager');
        if (GEManager != None)
        {
            GEManager.RemoveEffectsByCategory(Name);
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
        local SFXModule_GameEffectManager GEManager;
        
        GEManager = Instigator.GetModule(Class'SFXModule_GameEffectManager');
        if (GEManager != None)
        {
            GEManager.RemoveEffectsByCategory(Name);
            GEManager.CreateAndApplyEffect(Class'SFXGameEffect_LMGDamageTakenBonus', Name, 0.0, 2, -DamageReductionAmount, Instigator.Controller);
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
        Samples = ({Duration = 0.150000006, LeftAmplitude = 50, RightAmplitude = 50, LeftFunction = EWaveformFunction.WF_Constant, RightFunction = EWaveformFunction.WF_Constant}, 
                   {Duration = 0.579999983, LeftAmplitude = 0, RightAmplitude = 0, LeftFunction = EWaveformFunction.WF_Constant, RightFunction = EWaveformFunction.WF_Constant}, 
                   {Duration = 0.150000006, LeftAmplitude = 50, RightAmplitude = 50, LeftFunction = EWaveformFunction.WF_Constant, RightFunction = EWaveformFunction.WF_Constant}
                  )
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
        Template = ParticleSystem'BioVFX_DLC_GUN02_Typhoon.Particles.LMG_Muzzle' // MILAN CHANGE - Use GUN02 asset
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
    Begin Template Class=PointLightComponent Name=MuzFlashLight0 // MILAN CHANGE - Add flashlight component
    End Template
    Begin Object Class=SFXAnimSetCookSpec Name=tempAnimInfo
        AnimSet = AnimSet'BIOG_HMM_CB_A.HMM_CB_RifleAuto_SlowAlternate'
    End Object
    Begin Template Class=SFXModule_GameEffectManager Name=GEMod0
    End Template
    Begin Template Class=SFXModule_WeaponModManager Name=ModManager0
    End Template
    Begin Template Class=SkeletalMeshComponent Name=PickupMesh
        SkeletalMesh = SkeletalMesh'BIOG_WPN_ASL_P_CON_MP3.ASLp.WPN_ASLp_MDL'
        ReplacementPrimitive = None
    End Template
    Begin Template Class=SkeletalMeshComponent Name=WeaponMesh
        SkeletalMesh = SkeletalMesh'BIOG_WPN_ASL_P_CON_MP3.ASLp.WPN_ASLp_MDL'
        AnimTreeTemplate = AnimTree'BIOG_AnimTree_Weapon.BIOG_WPN_Main_O' // MILAN CHANGE - Use GUN02 assets
        PhysicsAsset = PhysicsAsset'BIOG_PHY_Weapons_F_CON_GUN02.WPN_PHY_ASLp'
        AnimSets = (AnimSet'BIOG_WPN_A_CON_GUN02.WPN_ASLp_Main')
        ReplacementPrimitive = None
    End Template
    PowerUpSound1 = WwiseEvent'Wwise_Weapons_S_LMG.Play_wep_p_LMG_start'
    PowerDownSound1 = WwiseEvent'Wwise_Weapons_S_LMG.Play_wep_p_LMG_stop'
    NPPowerUpSound = WwiseEvent'Wwise_Weapons_S_LMG.Play_wep_np_LMG_start'
    NPPowerDownSound = WwiseEvent'Wwise_Weapons_S_LMG.Play_wep_np_LMG_stop'
    MinROF = 250.0
    RampTime = 0.75
    DamageMultiplier = 2.0
    GetHotTime = 0.75
    FullyChargedTime = 1.5
    DamageReductionAmount = 0.400000006
    AI_AccCone_Min = {X = 1.5, Y = 1.5}
    AI_AccCone_Max = {X = 1.5, Y = 1.5}
    ReloadDuration = {X = 2.9000001, Y = 2.9000001}
    Damage = {X = 44.4000015, Y = 55.5}
    MagSize = {X = 100.0, Y = 100.0}
    MaxSpareAmmo = {X = 400.0, Y = 500.0}
    MinAimError = {X = 1.75, Y = 1.75}
    MaxAimError = {X = 3.5, Y = 3.5}
    MinZoomAimError = {X = 0.649999976, Y = 0.649999976}
    MaxZoomAimError = {X = 1.20000005, Y = 1.20000005}
    RateOfFire = {X = 650.0, Y = 650.0}
    EncumbranceWeight = {X = 2.5, Y = 2.0}
    Recoil = {X = 0.109999999, Y = 1.11000001}
    ZoomRecoil = {X = 0.209999993, Y = 1.14999998}
    AccFirePenalty = {X = 6.0, Y = 6.0}
    AccFireInterpSpeed = {X = 20.0, Y = 20.0}
    ZoomAccFirePenalty = {X = 37.0, Y = 37.0}
    ZoomAccFireInterpSpeed = {X = 35.0, Y = 35.0}
    MinZoomCrosshairRange = {X = 25.0, Y = 25.0}
    MaxZoomCrosshairRange = {X = 55.0, Y = 55.0}
    StatBarAccuracy = {X = 30.0, Y = 30.0}
    StatBarDamage = {X = 60.2000008, Y = 90.0}
    StatBarRateOfFire = {X = 650.0, Y = 650.0}
    GUIImage = "DLC_MPImages.asl_N7LMG_512x256" // MILAN CHANGE - Use GUN02 asset
    NotificationImage = "DLC_MPImages.asl_N7LMG_256x128" // MILAN CHANGE - Use GUN02 asset
    WeaponModBodyColours = ({R = 0.189999998, G = 0.189999998, B = 0.219999999, A = 0.0}
                           )
    FiringShake = {
                   RotAmplitude = {X = 60.0, Y = 30.0, Z = 15.0}, 
                   RotFrequency = {X = 80.0, Y = 50.0, Z = 20.0}, 
                   LocAmplitude = {X = -1.5, Y = 0.0, Z = 0.0}, 
                   LocFrequency = {X = 12.0, Y = 0.0, Z = 0.0}, 
                   TimeDuration = 0.25
                  }
    TightAimFiringShake = {
                           RotAmplitude = {X = 60.0, Y = 30.0, Z = 15.0}, 
                           RotFrequency = {X = 80.0, Y = 50.0, Z = 20.0}, 
                           LocAmplitude = {X = -1.5, Y = 0.0, Z = 0.0}, 
                           LocFrequency = {X = 12.0, Y = 0.0, Z = 0.0}, 
                           TimeDuration = 0.25
                          }
    TracerInfo = {
                  Scale3D = {X = 5.0, Y = 5.0, Z = 5.0}, 
                  StaticMesh = StaticMesh'BioVFX_C_Weapons.Tracers.Meshes.Tracer_Generic_Mesh', 
                  StandardPSTemplate = ParticleSystem'BioVFX_C_Weapons.Tracers.Particles.Tracer_Smoke_Trail', 
                  PlayerPSTemplate = ParticleSystem'BioVFX_C_Weapons.Tracers.Particles.Tracer_Smoke_Trail', 
                  AccelRate = 18000.0, 
                  Speed = 22000.0, 
                  MaxSpeed = 25000.0
                 }
    AI_BurstFireCount = {X = 30.0, Y = 50.0}
    AI_BurstFireDelay = {X = 1.25, Y = 2.25}
    ShellCasingSocketName = 'CoolDown01'
    ReloadAnimInfo = tempAnimInfo
    PSC_OutOfAmmoEffect = OutOfAmmoEffect0
    OutOfAmmoRumble = OutOfAmmoRumble0
    WeaponFireWaveForm = ForceFeedbackWaveformBase
    EjectRumble = EjectRumble0
    ImpactRelevanceDistance = 100000.0
    PS_DefaultImpactEffect = ParticleSystem'BioVFX_DLC_GUN02_Typhoon.Particles.LMG_Imp' // MILAN CHANGE - Use GUN02 asset
    PSC_ShellCasing = ShellCasingPSC0
    PSC_ReloadVent = ReloadVent0
    PSC_MuzFlashEmitter = MuzFlashPSC0
    // MILAN CHANGE - Muzzle light data
    LC_MuzzleFlashLight = MuzFlashLight0
    MuzzleLightLifetime = 0.0500000007
    MuzzleLightBrightness = 0.300000012
    MuzzleLightColor = {B = 255, G = 1, R = 70, A = 0}
    MuzzleLightFalloffExponent = 15.0
    MuzzleLightRadius = 600.0
    // END MILAN CHANGE
    EjectShellCasingTimeRatio = 0.460000008
    LowAmmoSoundThreshold = 20.0
    SteamSoundThreshold = 10.0
    NoAmmoFireSoundDelay = 0.5
    RateOfFireAI = 1.0
    RecoilInterpSpeed = 0.0
    RecoilYawScale = 2.25
    RecoilYawFrequency = 2.25
    TraceRange = 100000.0
    DistancePenetrated = 100.0
    IconResource = GFxMovieInfo'GUI_SF_ME3_DLC_Gun02.ME3_DLC_N7LMG' // MILAN CHANGE - Use GUN02 asset
    IconRef = 2
    PrettyName = $744335
    ShortPrettyName = $744335
    ShortDescription = $744336
    GeneralDescription = $744351
    FireSound = WwiseEvent'Wwise_Weapons_S_LMG.Play_wep_np_LMG_fire'
    PlayerFireSound = WwiseEvent'Wwise_Weapons_S_LMG.Play_wep_p_LMG_fire'
    FireNoAmmoSound = WwiseEvent'Wwise_Weapons_Standard_LowAmmo.Play_weapon_dryfire_machineguns'
    WeaponReloadSound = WwiseEvent'Wwise_Weapons_Generic.Play_wep_g_reload_assault_heavy'
    SteamReloadNotifySound = WwiseEvent'Wwise_Weapons_S_LMG.Play_wep_s_LMG_steam' // MILAN NOTE: Will have to be fixed in Audio pipeline
    AmmoPowerPSCO = AmmoPowerHologram
    AmmoPowerIconPSCO = AmmoPowerIconHologram
    InstantHitMomentum = (0.0, 1.0, 50.0, 1.0)
    InstantHitDamageTypes = (None, Class'SFXDamageType_Default', Class'SFXDamageType_HeavyMachinegun', Class'SFXDamageType_Default')
    Mesh = WeaponMesh
    DroppedPickupMesh = PickupMesh
    PickupFactoryMesh = PickupMesh
    Components = (WeaponMesh)
    Modules = (GEMod0, ModManager0)
}