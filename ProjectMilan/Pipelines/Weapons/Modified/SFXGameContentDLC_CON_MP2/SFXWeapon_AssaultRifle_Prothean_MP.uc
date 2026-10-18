// MILAN Weapon
// Source: MP2
// Note: This weapon is unique as it was ported originally from ME3 SP to ME3 MP rather than the reverse.
Class SFXWeapon_AssaultRifle_Prothean_MP extends SFXWeapon_Heavy_Beam_Base_Prothean
    placeable
    config(Weapon);

// Variables
var string AmmoAmountRTPC;
var ScreenShakeStruct HoldShake;
var Guid ClientEffectFiringGuid;
var RvrClientEffectInterface CE_HeatVent;
var config float RechargeRatePerSecond;
var config float PartialRechargeDelay;
var config float FullRechargeDelay;
var float AccumulatedAmmo;
var config float TimeToHeatUp;
var config float TimeToHeatUpAI;
var config float ProtheanDamageMultiplier;
var float FireStartTime; // MILAN Change - use HENPR LE3 firing start time
var float SteamDelay;
var bool bFireSoundPlaying;
var bool bIsHot;
// MILAN Change - Smoothed beam visuals. The beam end point used to snap once per shot (~13 Hz).
// We now aim the beam visual along a smoothed direction and trace each tick so it always lands on real geometry.
var transient Rotator rBeamVisualAim;
var transient bool bBeamVisualAimValid;
var float BeamVisualInterpSpeed;
var float BeamVisualConvergedDot;

// Functions
// MILAN Change - Smoothed beam visuals
public simulated function UpdateBeam(float DeltaTime)
{
    local Vector MuzzleLoc;
    local Vector TargetLoc;
    local Vector ToTarget;
    local Vector VisualDir;
    local Vector VisualEnd;
    local Vector HitLocation;
    local Vector HitNormal;
    local bool bLocalHuman;

    // Sets Impact params to the last shot's hit location and runs AI aim precalc
    Super.UpdateBeam(DeltaTime);
    if (PSC_MuzFlashEmitter == None || Instigator == None)
    {
        return;
    }
    MuzzleLoc = GetMuzzleLoc();
    bLocalHuman = Instigator.IsLocallyControlled() && PlayerController(Instigator.Controller) != None;
    if (bLocalHuman)
    {
        // Our own aim is known every frame - no smoothing needed
        TargetLoc = GetLocalBeamAimTarget();
    }
    else
    {
        // Remote players and AI only learn the end point once per shot
        TargetLoc = vLastHitLocation;
    }
    ToTarget = TargetLoc - MuzzleLoc;
    if (bLocalHuman || !bBeamVisualAimValid)
    {
        rBeamVisualAim = Rotator(ToTarget);
        bBeamVisualAimValid = TRUE;
    }
    else
    {
        rBeamVisualAim = RInterpTo(rBeamVisualAim, Rotator(ToTarget), DeltaTime, BeamVisualInterpSpeed);
    }
    VisualDir = Vector(rBeamVisualAim);
    if (VisualDir Dot Normal(ToTarget) >= BeamVisualConvergedDot)
    {
        VisualEnd = TargetLoc;
    }
    else
    {
        // Sweeping between hits
        VisualEnd = MuzzleLoc + VisualDir * GetTraceRange();
        if (GetTraceOwner().Trace(HitLocation, HitNormal, VisualEnd, MuzzleLoc, TRUE, , , 1) != None)
        {
            VisualEnd = HitLocation;
        }
    }
    PSC_MuzFlashEmitter.SetVectorParameter('Impact', VisualEnd);
    PSC_MuzFlashEmitter.SetVectorParameter('Impact_lag', VisualEnd);
}

private final simulated function Vector GetLocalBeamAimTarget()
{
    local Vector StartTrace;
    local Vector EndTrace;
    local Vector CamDir;
    local Vector HitLocation;
    local Vector HitNormal;
    local SFXPlayerCamera Camera;

    StartTrace = Instigator.GetWeaponStartTraceLocation();
    Camera = SFXPlayerCamera(PlayerController(Instigator.Controller).PlayerCamera);
    if (Camera != None)
    {
        CamDir = Vector(Camera.CameraCache.POV.Rotation);
        StartTrace += CamDir * ((Instigator.Location - StartTrace) Dot CamDir);
    }
    EndTrace = StartTrace + Vector(Instigator.GetBaseAimRotation()) * GetTraceRange();
    if (GetTraceOwner().Trace(HitLocation, HitNormal, EndTrace, StartTrace, TRUE, , , 1) != None)
    {
        return HitLocation;
    }
    return EndTrace;
}

public simulated function StopMuzzleFlashEffect()
{
    Super.StopMuzzleFlashEffect();
    bBeamVisualAimValid = FALSE;
}

public simulated function Tick(float DeltaTime)
{
    local SFXPlayerController PC;
    local float ShakeStrength;
    
    Super.Tick(DeltaTime);
    if (IsInState('WeaponFiring', )) // MILAN Change - Switch from current fire mode to HENPR WeaponFiring
    {
        Class'WwiseAudioComponent'.static.SetGlobalRTPCFromScript(AmmoAmountRTPC, float(GetCurrentTotalAmmo()));
    }
    if (AmmoUsedCount == GetMagazineSize())
    {
        bWeaponCanBeReloaded = TRUE;
    }
    else if (WorldInfo.GameTimeSeconds - LastFireTime >= PartialRechargeDelay)
    {
        bWeaponCanBeReloaded = FALSE;
        RechargeAmmo(DeltaTime);
    }
    if (Instigator != None && IsInState('WeaponFiring', )) // MILAN Change - Switch from current fire mode to HENPR WeaponFiring
    {
        PC = SFXPlayerController(Instigator.Controller);
        ShakeStrength = FClamp((WorldInfo.GameTimeSeconds - FireStartTime) / TimeToHeatUp, 0.0, 1.0); // MILAN Change - ShakeStrength uses local start firing time now
        PC.PlayScaledCameraShake(HoldShake, ShakeStrength);
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
public simulated function PlayFireEffects(byte FireModeNum, optional Vector HitLocation)
{
    Super.PlayFireEffects(FireModeNum, HitLocation);
    if (!bFireSoundPlaying)
    {
        bFireSoundPlaying = TRUE;
        GetModule(Class'SFXModule_GameEffectManager').RemoveEffectsByType(Class'SFXGameEffect_WeaponVFXChange');
        GunIsCold();
        WeaponPlayWwiseEvent(PowerUpSound);
        WeaponAnimNode.PlayCustomAnim('WPN_ChargeUp', 1.0);
        if (SFXPawn_Player(Instigator) != None)
        {
            SetTimer(TimeToHeatUp, FALSE, 'GunIsHot', );
            SetTimer(TimeToHeatUp, FALSE, 'PlayLoopingAnim', );
        }
        else if (SFXPawn_Henchman(Instigator) != None)
        {
            SetTimer(TimeToHeatUpAI, FALSE, 'GunIsHot', );
        }
    }
}
public simulated function StopFireEffects(byte FireModeNum)
{
    Super(SFXWeapon).StopFireEffects(FireModeNum);
    if (bFireSoundPlaying)
    {
        bFireSoundPlaying = FALSE;
        WeaponPlayWwiseEvent(PowerDownSound);
        GunIsCold();
        WeaponAnimNode.StopCustomAnim(0.200000003);
        ClearTimer('GunIsHot');
        ClearTimer('PlayLoopingAnim');
        if (bIsHot)
        {
            WeaponAnimNode.PlayCustomAnim('WPN_ChargeRelease', 1.0);
        }
    }
}
public simulated function WeaponFired(byte FiringMode, bool bViaReplication, optional Vector HitLocation)
{
    // 09/11/2026 - This commented out version was our original change. It seems to have broken the end-trace updates due to bIsFiring being directly in super
    // I am not really sure why this was changed. -Mgamerz
    //Super(SFXWeapon).WeaponFired(FiringMode, bViaReplication, HitLocation); // MILAN Change - Use supersuper version of function as we track our firing time locally now (LE3 HENPR)
    // Restore original logic
    Super.WeaponFired(FiringMode, bViaReplication, HitLocation);
    LastFireTime = WorldInfo.GameTimeSeconds;
}
public simulated function DoReload()
{
    __OnWeaponReload__Delegate(Self);
    AmmoUsedCount -= 1;
    PlayReloadEject();
    if (SFXPawn_Player(Owner) != None)
    {
        SFXPawn_Player(Owner).bIsFullAmmo = FALSE;
    }
    if (SFXPawn_Player(Owner) != None)
    {
        SFXPawn_Player(Owner).OutOfAmmoTimestamp = 0.0;
    }
}
public simulated function int GetCurrentSpareAmmo()
{
    return 0;
}
public simulated function float GetFireModeBaseDamage()
{
    local float BaseDamage;
    
    BaseDamage = Super(SFXWeapon).GetFireModeBaseDamage();
    if (bIsHot)
    {
        BaseDamage *= ProtheanDamageMultiplier;
    }
    return BaseDamage;
}

// ME3 originals:
//public static simulated function ParticleSystem GetWeaponSpecificImpactEffect(SFXPhysicalMaterialImpactEffects ImpactEffects);
//public simulated function WwiseEvent GetWeaponSpecificImpactSound(SFXPhysicalMaterialImpactSounds ImpactSounds);
// MILAN Change - Use HENPR LE3 functions
public static simulated function ParticleSystem GetWeaponSpecificImpactEffect(SFXPhysicalMaterialImpactEffects ImpactEffects)
{
    return None;
}
public simulated function WwiseEvent GetWeaponSpecificImpactSound(SFXPhysicalMaterialImpactSounds ImpactSounds)
{
    return None;
}
public simulated function InitDefaultDecalProperties()
{
    DefaultDecalProperties = new (Self) Class'DecalComponent';
    DefaultDecalProperties.Width = 0.0;
    DefaultDecalProperties.Height = 0.0;
    DefaultDecalProperties.TileX = 0.0;
    DefaultDecalProperties.DepthBias = -0.0;
    DefaultDecalProperties.bNoClip = TRUE;
    DefaultDecalProperties.SetDecalMaterial(DefaultDecalMaterial);
}
public simulated function InitializeWeapon()
{
    Super(SFXWeapon).InitializeWeapon();
    HackLoadWeaponMods();
}
public simulated function bool IsMuzzleFlashRelevant()
{
    if (Instigator == None || Instigator.IsHumanControlled())
    {
        return TRUE;
    }
    if (WorldInfo.bAggressiveLOD)
    {
        return FALSE;
    }
    return TRUE;
}
public simulated function bool OutOfAmmo()
{
    return FALSE;
}
public simulated function GunIsHot()
{
    local Vector IntensityVector;
    local float IntensityScalar;
    
    bIsHot = TRUE;
    IntensityVector.X = 0.5;
    IntensityVector.Y = 0.5;
    IntensityVector.Z = 0.5;
    IntensityScalar = 0.5;
    PSC_MuzFlashEmitter.SetVectorParameter('Intensity', IntensityVector);
    PSC_MuzFlashEmitter.SetFloatParameter('Intensity', IntensityScalar);
}
public simulated function GunIsCold()
{
    local Vector IntensityVector;
    local float IntensityScalar;
    
    bIsHot = FALSE;
    IntensityVector.X = 0.0;
    IntensityVector.Y = 0.0;
    IntensityVector.Z = 0.0;
    IntensityScalar = 0.0;
    PSC_MuzFlashEmitter.SetVectorParameter('Intensity', IntensityVector);
    PSC_MuzFlashEmitter.SetFloatParameter('Intensity', IntensityScalar);
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
public simulated function PlayLoopingAnim()
{
    WeaponAnimNode.PlayCustomAnim('WPN_ChargeHold', 1.5, 0.0, 0.200000003, TRUE);
}
public simulated function PlayReloadSteam()
{
    Class'RvrClientEffectManager'.static.GetClientEffectManager().Play(CE_HeatVent, Instigator);
}
public simulated function RechargeAmmo(float DeltaTime)
{
    local int AmmoRounded;
    local float fMagSize;
    
    fMagSize = float(GetMagazineSize());
    AccumulatedAmmo += (RechargeRatePerSecond * DeltaTime) * fMagSize;
    AccumulatedAmmo = FClamp(AccumulatedAmmo, 0.0, float(AmmoUsedCount));
    if (AccumulatedAmmo >= 1.0)
    {
        AmmoRounded = int(AccumulatedAmmo);
        AmmoUsedCount -= AmmoRounded;
        AccumulatedAmmo -= float(AmmoRounded);
    }
}
 // MILAN Change: Use HENPR LE3 StopFireSounds()
public simulated function StopFireSounds()
{
    if (bFireSoundPlaying)
    {
        WeaponPlayWwiseEvent(PowerDownSound);
        bFireSoundPlaying = FALSE;
    }
}

// States
simulated state Reloading 
{
    // State Functions
    public simulated function DoAReload()
    {
        Super(SFXWeapon).DoAReload();
        SetTimer(SteamDelay, FALSE, 'PlayReloadSteam', );
    }
    
    // State code
    stop;
};
 // MILAN Change: Use HENPR LE3 WeaponFiring state. It should work as functions are marked as simulated
state WeaponFiring 
{
    // State Functions
    public simulated function StopFire(byte FireModeNum)
    {
        Super(SFXWeapon).StopFire(FireModeNum);
        StopFireSounds();
    }
    public event simulated function EndState(Name NextStateName)
    {
        Super(SFXWeapon).EndState(NextStateName);
        StopFireSounds();
        GunIsCold();
        WeaponAnimNode.StopCustomAnim(0.200000003);
        ClearTimer('GunIsHot');
        ClearTimer('PlayLoopingAnim');
        if (bIsHot)
        {
            WeaponAnimNode.PlayCustomAnim('WPN_ChargeRelease', 1.0);
        }
        Super(SFXWeapon).EndState(NextStateName);
    }
    public simulated function BeginState(Name PreviousStateName)
    {
        GetModule(Class'SFXModule_GameEffectManager').RemoveEffectsByType(Class'SFXGameEffect_WeaponVFXChange');
        GunIsCold();
        FireStartTime = WorldInfo.GameTimeSeconds;
        Super(SFXWeapon).BeginState(PreviousStateName);
        if (!bFireSoundPlaying)
        {
            WeaponPlayWwiseEvent(PowerUpSound);
            bFireSoundPlaying = TRUE;
        }
        WeaponAnimNode.PlayCustomAnim('WPN_ChargeUp', 1.0);
        Super(SFXWeapon).BeginState(PreviousStateName);
        if (SFXPawn_Player(Owner) != None)
        {
            SetTimer(TimeToHeatUp, FALSE, 'GunIsHot', );
            SetTimer(TimeToHeatUp, FALSE, 'PlayLoopingAnim', );
        }
        else if (SFXPawn_Henchman(Owner) != None)
        {
            SetTimer(TimeToHeatUpAI, FALSE, 'GunIsHot', );
        }
    }
    
    // State code
    stop;
};
state Inactive 
{
    // State Functions
    public event simulated function BeginState(Name PreviousStateName)
    {
        StopFireSounds();
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
        Samples = ({Duration = 0.100000001, LeftAmplitude = 35, RightAmplitude = 35, LeftFunction = EWaveformFunction.WF_Sin90to180, RightFunction = EWaveformFunction.WF_Sin90to180}
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
        Template = ParticleSystem'biovfx_c_wpn_hen_pr.Particles.HEN_PR_Beam'
        bAutoActivate = FALSE
        ReplacementPrimitive = None
        bIgnoreHiddenActorsMembership = TRUE
    End Object
    Begin Template Class=ParticleSystemComponent Name=OutOfAmmoEffect0
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
    Begin Template Class=PointLightComponent Name=MuzFlashLight0 // MILAN Change - Add HENPR Flashlight Component
    End Template
    Begin Object Class=SFXAnimSetCookSpec Name=tempAnimInfo
        AnimSet = AnimSet'BIOG_HMM_CB_HEN_PR.HMM_CB_ProtheanRifleReload'
    End Object
    Begin Template Class=SFXModule_GameEffectManager Name=GEMod0
    End Template
    Begin Template Class=SFXModule_WeaponModManager Name=ModManager0
    End Template
    Begin Template Class=SkeletalMeshComponent Name=PickupMesh
        ReplacementPrimitive = None
    End Template
    Begin Template Class=SkeletalMeshComponent Name=WeaponMesh
        SkeletalMesh = SkeletalMesh'BIOG_WPN_ASL_R_HEN_PR.ASLm.WPN_ASLm_MDL'
        AnimTreeTemplate = AnimTree'BIOG_AnimTree_Weapon.BIOG_WPN_Main_O'
        PhysicsAsset = PhysicsAsset'BIOG_PHY_Weapons_f_HEN_PR.PHY_WPN_ASLm'
        AnimSets = (AnimSet'BIOG_WPN_A_HEN_PR.WPN_ASLm_Main')
        ReplacementPrimitive = None
    End Template
    HoldShake = {
                 RotAmplitude = {X = 25.0, Y = 25.0, Z = 40.0}, 
                 RotFrequency = {X = 100.0, Y = 50.0, Z = 50.0}, 
                 RotSinOffset = {X = 0.0, Y = 0.0, Z = 0.0}, 
                 LocAmplitude = {X = 4.0, Y = 0.0, Z = 0.0}, 
                 LocFrequency = {X = 0.0, Y = 0.0, Z = 0.0}, 
                 LocSinOffset = {X = 0.0, Y = 0.0, Z = 0.0}, 
                 ShakeName = 'ProtheanGunShake', 
                 TimeToGo = 0.0, 
                 TimeDuration = 0.100000001, 
                 RotParam = {X = EShakeParam.ESP_OffsetRandom, Y = EShakeParam.ESP_OffsetRandom, Z = EShakeParam.ESP_OffsetRandom, Padding = 0}, 
                 LocParam = {X = EShakeParam.ESP_OffsetRandom, Y = EShakeParam.ESP_OffsetRandom, Z = EShakeParam.ESP_OffsetRandom, Padding = 0}, 
                 FOVAmplitude = 0.0, 
                 FOVFrequency = 0.0, 
                 FOVSinOffset = 0.0, 
                 TargetingDampening = 0.0, 
                 bOverrideTargetingDampening = FALSE, 
                 FOVParam = EShakeParam.ESP_OffsetRandom
                }
    RechargeRatePerSecond = 0.349999994
    PartialRechargeDelay = 1.5
    FullRechargeDelay = 5.0
    CE_HeatVent = RvrClientEffect'BioVFX_C_Wpn_HEN_PR.VCFX.Pro_Overheat'
    TimeToHeatUp = 2.0
    TimeToHeatUpAI = 1.0
    ProtheanDamageMultiplier = 4.0
    SteamDelay = 0.699999988
    BeamInterpSpeed = {X = 20.0, Y = 20.0}
    DecalFrequency = 5
    BeamInterpTime = 0.5
    VFXUpdateInterval = 0.00999999978
    BeamVisualInterpSpeed = 20.0
    BeamVisualConvergedDot = 0.99999
    AI_AccCone_Min = {X = 1.20000005, Y = 1.20000005}
    AI_AccCone_Max = {X = 1.79999995, Y = 1.79999995}
    ReloadDuration = {X = 5.0, Y = 5.0}
    Damage = {X = 17.2000008, Y = 21.3999996}
    MagSize = {X = 100.0, Y = 100.0}
    MaxSpareAmmo = {X = 1000000.0, Y = 1000000.0}
    MinAimError = {X = 0.0, Y = 0.0}
    MaxAimError = {X = 0.0, Y = 0.0}
    MinZoomAimError = {X = 0.0, Y = 0.0}
    MaxZoomAimError = {X = 0.0, Y = 0.0}
    RateOfFire = {X = 800.0, Y = 800.0}
    EncumbranceWeight = {X = 2.0, Y = 1.39999998}
    Recoil = {X = 0.0, Y = 0.0}
    ZoomRecoil = {X = 0.0, Y = 0.0}
    AccFirePenalty = {X = 0.0, Y = 0.0}
    AccFireInterpSpeed = {X = 0.0, Y = 0.0}
    ZoomAccFirePenalty = {X = 0.0, Y = 0.0}
    ZoomAccFireInterpSpeed = {X = 0.0, Y = 0.0}
    MinCrosshairRange = {X = 20.0, Y = 20.0}
    MaxCrosshairRange = {X = 20.0, Y = 20.0}
    MinZoomCrosshairRange = {X = 20.0, Y = 20.0}
    MaxZoomCrosshairRange = {X = 20.0, Y = 20.0}
    StatBarAccuracy = {X = 40.0, Y = 40.0}
    StatBarDamage = {X = 17.2000008, Y = 21.3999996}
    StatBarRateOfFire = {X = 800.0, Y = 800.0}
    GUIImage = "GUI_PR_Images.asl_prothean_512x256"
    NotificationImage = "GUI_PR_Images.asl_prothean_256x128"
    WeaponModBodyColours = ({R = 1.0, G = 0.239999995, B = 0.180000007, A = 0.0}, 
                            {R = 1.0, G = 0.74000001, B = 0.300000012, A = 0.0}, 
                            {R = 0.370000005, G = 0.50999999, B = 0.25, A = 0.0}, 
                            {R = 0.379999995, G = 0.389999986, B = 0.649999976, A = 0.0}, 
                            {R = 0.0799999982, G = 0.0900000036, B = 0.150000006, A = 0.0}
                           )
    GUIZoomReticleClass = Class'SFXGUI_WeaponReticleSimple'
    FiringShake = {
                   RotAmplitude = {X = 25.0, Y = 25.0, Z = 40.0}, 
                   RotFrequency = {X = 100.0, Y = 50.0, Z = 50.0}, 
                   LocAmplitude = {X = 4.0, Y = 0.0, Z = 0.0}, 
                   TimeDuration = 0.100000001
                  }
    TightAimFiringShake = {
                           RotAmplitude = {X = 25.0, Y = 25.0, Z = 40.0}, 
                           RotFrequency = {X = 100.0, Y = 50.0, Z = 50.0}, 
                           LocAmplitude = {X = 4.0, Y = 0.0, Z = 0.0}, 
                           TimeDuration = 0.100000001
                          }
    AI_BurstFireCount = {X = 20.0, Y = 40.0}
    AI_BurstFireDelay = {X = 0.699999988, Y = 1.10000002}
    ReloadAnimInfo = tempAnimInfo
    PSC_OutOfAmmoEffect = OutOfAmmoEffect0
    OutOfAmmoRumble = OutOfAmmoRumble0
    WeaponFireWaveForm = ForceFeedbackWaveformBase
    EjectRumble = EjectRumble0
    PS_DefaultImpactEffect = ParticleSystem'BioVFX_C_Wpn_HEN_PR.Particles.HEN_PR_Generic_Impact'
    PS_DefaultMaterialImpactEffect = ParticleSystem'BioVFX_C_Wpn_HEN_PR.Particles.HEN_PR_Generic_Impact'
    DefaultDecalMaterial = None
    PSC_ShellCasing = ShellCasingPSC0
    PSC_ReloadVent = ReloadVent0
    PSC_MuzFlashEmitter = MuzFlashPSC0
    LC_MuzzleFlashLight = MuzFlashLight0 // MILAN Change: Add flashlight component
    EjectShellCasingTimeRatio = 0.800000012
    SteamSoundThreshold = 1.0
    NoAmmoFireSoundDelay = 0.5
    RateOfFireAI = 1.0
    RecoilInterpSpeed = 1.0
    RecoilFadeSpeed = 1.0
    RecoilZoomFadeSpeed = 1.0
    TraceRange = 4000.0
    IdealTargetDistance = 800.0
    IdealMaxRange = 1000.0
    IconResource = GFxMovieInfo'GUI_SF_ME3_DLC_Prothean.ME3_DLC_Prothean'
    IconRef = 2
    PrettyName = $727492
    ShortPrettyName = $727492
    ShortDescription = $727493
    GeneralDescription = $727494
    DefaultImpactSound = WwiseEvent'Wwise_Weapons_S_Prothean.Play_wep_np_prothean_impact' // MILAN Change: Use HENPR asset
    WeaponReloadSound = WwiseEvent'Wwise_Weapons_S_Prothean.Play_wep_s_prothean_overheat' // MILAN Change: Use HENPR asset
    WeaponSteamReloadSound = WwiseEvent'Wwise_Weapons_Generic.Play_wep_g_noammo_large_alien_sweetener'
    WeaponExpandSound = WwiseEvent'Wwise_Weapons_S_Prothean_MP.Play_wep_s_prothean_expand_MP' // MILAN Note: Must be fixed with audio pipeline
    WeaponCollapseSound = WwiseEvent'Wwise_Weapons_S_Prothean_MP.Play_wep_s_prothean_collapse_MP' // MILAN Note: Must be fixed with audio pipeline
    AmmoPowerPSCO = AmmoPowerHologram
    AmmoPowerIconPSCO = AmmoPowerIconHologram
    PowerUpSound = WwiseEvent'Wwise_Weapons_S_Prothean.Play_wep_p_prothean_start' // MILAN Change: Use HENPR asset
    PowerDownSound = WwiseEvent'Wwise_Weapons_S_Prothean.Play_wep_p_prothean_stop' // MILAN Change: Use HENPR asset
    NPCPowerUpSound = WwiseEvent'Wwise_Weapons_S_Prothean.Play_wep_np_prothean_start' // MILAN Change: Use HENPR asset
    NPCPowerDownSound = WwiseEvent'Wwise_Weapons_S_Prothean.Play_wep_np_prothean_stop' // MILAN Change: Use HENPR asset
    WeaponAcquiredID = 22746
    WeaponAcquiredID_NGP = 22747
    bSuppressTracers = TRUE
    bWeaponCanBeReloaded = FALSE
    bZoomSnapEnabled = FALSE
    bInfiniteAmmo = TRUE
    InstantHitMomentum = (0.0, 1.0, 0.0, 1.0)
    InstantHitDamageTypes = (None, Class'SFXDamageType_Default', Class'SFXDamageType_Prothean_MP', Class'SFXDamageType_Default')
    FireOffset = {X = 61.0, Y = -0.5, Z = 7.25}
    Mesh = WeaponMesh
    DroppedPickupMesh = WeaponMesh
    PickupFactoryMesh = WeaponMesh
    Components = (WeaponMesh)
    Modules = (GEMod0, ModManager0)
}