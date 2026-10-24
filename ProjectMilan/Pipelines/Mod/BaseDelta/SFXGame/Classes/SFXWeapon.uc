// MILAN CHANGE
// By Mgamerz
// Add flashlight support
// Fix disappearing weapons when holster action is interrupted
Class SFXWeapon extends SFXWeapon_NativeBase
    placeable
    abstract
    config(Weapon);

enum ChargeEffectType
{
    CET_ShutOffAll,
    CET_StopCharge,
    CET_StartCharge,
};
struct WeaponModInfo 
{
    var Class<SFXWeaponMod> ModClass;
    var int ModLevel;
};
enum EPlayerPositionRTPC
{
    EXPLORE,
    UPRIGHT_NORMAL,
    UPRIGHT_IRONSIGHTS,
    UPRIGHT_SCOPE_SNIPER,
    UPRIGHT_SCOPE_OTHER,
    COVER_NORMAL,
    COVER_IRONSIGHTS,
    COVER_SCOPE_SNIPER,
    COVER_SCOPE_OTHER,
};
struct native CoverLeanPosition 
{
    var array<WeaponAnimType> WeaponTypes;
    var Vector Offset;
    var ECoverDirection Direction;
    var ECoverType Type;
};
struct WeaponModMeshOverride 
{
    var array<Name> SocketOverrideNames;
    var Name SocketName;
};
struct ZoomSnapInfo 
{
    var(ZoomSnapInfo) config float OuterSnapAngle;
    var(ZoomSnapInfo) config float InnerSnapAngle;
    var(ZoomSnapInfo) config float SnapOffsetMag;
    var(ZoomSnapInfo) config EAimNodes AimNode;
};
enum EWeaponStatBars
{
    EWeaponStatBarAccuracy,
    EWeaponStatBarDamage,
    EWeaponStatBarFireRate,
    EWeaponStatBarMagSize,
    EWeaponStatBarWeight,
    EWeaponStatBarOther,
    EWeaponStatBar_MAX,
};
struct TracerSpec 
{
    var(TracerSpec) Vector Scale3D;
    var(TracerSpec) StaticMesh StaticMesh;
    var(TracerSpec) ParticleSystem StandardPSTemplate;
    var(TracerSpec) ParticleSystem PlayerPSTemplate;
    var(TracerSpec) float AccelRate;
    var(TracerSpec) float Speed;
    var(TracerSpec) float MaxSpeed;
};
struct SFXWeaponAimMode 
{
    var(SFXWeaponAimMode) config Name ScopeResource;
    var(SFXWeaponAimMode) config float ZoomFOV;
    var(SFXWeaponAimMode) config float FrictionMultiplier;
    var(SFXWeaponAimMode) config float AdhesionMultiplier;
    var(SFXWeaponAimMode) config bool bScoped;
};
enum FireModes
{
    FireMode_None,
    FireMode_SemiAuto,
    FireMode_FullAuto,
    FireMode_Burst,
    FireMode_Reload,
};
enum IKProfiles
{
    IKProfile_Rifle,
    IKProfile_Pistol,
    IKProfile_SMG,
};
enum AimProfiles
{
    AimProfile_Rifle,
    AimProfile_Pistol,
    AimProfile_PistolShield,
};

var(AI) config ScaledFloat AI_AccCone_Min;
var(AI) config ScaledFloat AI_AccCone_Max;
var(SFXWeapon) config ScaledFloat ReloadDuration;
var(SFXWeapon) config ScaledFloat Damage;
var(SFXWeapon) config ScaledFloat MagSize;
var(SFXWeapon) config ScaledFloat MaxSpareAmmo;
var(SFXWeapon) config ScaledFloat MinAimError;
var(SFXWeapon) config ScaledFloat MaxAimError;
var(SFXWeapon) config ScaledFloat MinZoomAimError;
var(SFXWeapon) config ScaledFloat MaxZoomAimError;
var(SFXWeapon) config ScaledFloat RateOfFire;
var(SFXWeapon) ScaledFloat NoAmmoUseChance;
var(SFXWeapon) config ScaledFloat HeadshotDamageMultiplier;
var(SFXWeapon) config ScaledFloat ImpactForceModifier;
var(SFXWeapon) config ScaledFloat ReactionChanceModifier;
var(SFXWeapon) config ScaledFloat MeleeDamageModifier;
var config ScaledFloat EncumbranceWeight;
var(SFXWeapon) config ScaledFloat Recoil;
var(SFXWeapon) config ScaledFloat ZoomRecoil;
var(SFXWeapon) config ScaledFloat AccFirePenalty;
var(SFXWeapon) config ScaledFloat AccFireInterpSpeed;
var(SFXWeapon) config ScaledFloat ZoomAccFirePenalty;
var(SFXWeapon) config ScaledFloat ZoomAccFireInterpSpeed;
var(SFXWeapon) config ScaledFloat MinCrosshairRange;
var(SFXWeapon) config ScaledFloat MaxCrosshairRange;
var(SFXWeapon) config ScaledFloat MinZoomCrosshairRange;
var(SFXWeapon) config ScaledFloat MaxZoomCrosshairRange;
var config ScaledFloat PenetrationBonus;
var config ScaledFloat PenetrationDamageBonus;
var ScaledFloat ArmorPiercing;
var config ScaledFloat StatBarAccuracy;
var config ScaledFloat StatBarDamage;
var config ScaledFloat StatBarRateOfFire;
var transient ScaledFloat ZoomDamageShakeModifier;
var(SFXWeapon) config array<SFXWeaponAimMode> AimModes;
var const array<Name> AimOffsetProfileNames;
var(SFXWeapon) config array<ChangeOverLifeKey> MuzzleLightChangeOverLifeKeys;
var config biodynamicload string GUIImage;
var config biodynamicload string NotificationImage;
var(SFXWeapon) string AmmoRTPCName;
var(SFXWeapon) config array<ZoomSnapInfo> ZoomSnapList;
var config array<Name> FadingParameters;
var const array<stringref> DamageUpgradeTokens;
var const array<stringref> ResearchUpgradeTokens;
var const array<int> ResearchUpgradeIds;
var config transient array<string> AllowableWeaponMods;
var config transient array<WeaponModMeshOverride> WeaponModMeshOverrides;
var globalconfig array<CoverLeanPosition> CoverLeanPositions;
var config array<LinearColor> WeaponModGripColours;
var config array<LinearColor> WeaponModBodyColours;
var config array<LinearColor> WeaponModEmissiveColours;
var string RTPCName;
var array<string> DefaultModOptions;
var transient array<delegate<OnWeaponImpact>> ImpactSubscriptions;
var array<SFXProjectile> PredictedProjectiles;
var Class<DroppedPickup> DroppedAmmoClass;
var Class<SFXGUI_WeaponReticleBase> GUIReticleClass;
var Class<SFXGUI_WeaponReticleBase> GUIZoomReticleClass;
var(SFXWeapon) ScreenShakeStruct FiringShake;
var(SFXWeapon) ScreenShakeStruct TightAimFiringShake;
var ScreenShakeStruct ChargeCameraShake;
var(SFXWeapon) TracerSpec TracerInfo;
var Guid AttachedFlashlightVFXGuid;
var LinearColor WeaponModBaseGripColour;
var LinearColor WeaponModBaseBodyColour;
var LinearColor WeaponModBaseEmissiveColour;
var(Debug) Vector DebugShotStartLoc;
var(Debug) Rotator DebugShotAimRot;
var(SFXWeapon) Vector MuzzleIdlePosition;
var(SFXWeapon) config Vector FrictionTargetOffset;
var Vector DummyFireTargetLoc;
var Vector StartFireLocation;
var Vector StartFireDirection;
var(Melee) Name MeleePowerName;
var(AI) config Vector2D AI_BurstFireCount;
var(AI) config Vector2D AI_BurstFireDelay;
var(AI) config Vector2D AI_AimDelay;
var SFXAnimSetCookSpec ReloadAnimInfo;
var AnimNodeSlot WeaponAnimNode;
var instanced ParticleSystemComponent PSC_OutOfAmmoEffect;
var(SFXWeapon) ForceFeedbackWaveform OutOfAmmoRumble;
var ForceFeedbackWaveform WeaponFireWaveForm;
var(SFXWeapon) ForceFeedbackWaveform EjectRumble;
var(SFXWeapon) ParticleSystem PS_DefaultImpactEffect;
var(SFXWeapon) ParticleSystem PS_DefaultMaterialImpactEffect;
var transient instanced DecalComponent DefaultDecalProperties;
var(SFXWeapon) MaterialInterface DefaultDecalMaterial;
var(SFXWeapon) instanced ParticleSystemComponent PSC_ShellCasing;
var(SFXWeapon) instanced ParticleSystemComponent PSC_ReloadVent;
var(SFXWeapon) instanced ParticleSystemComponent PSC_MuzFlashEmitter;
var(SFXWeapon) instanced PointLightComponent LC_MuzzleFlashLight;
var(SFXWeapon) instanced ParticleSystemComponent PSC_PermanentMuzzle;
var WwiseEvent OnMuzzleSound;
var WwiseEvent OffMuzzleSound;
var(SFXWeapon) Name MuzzleSocketName;
var(SFXWeapon) Name ShellCasingSocketName;
var(SFXWeapon) Light AttachedFlashlight;
var(SFXWeapon) Light AttachedAmbientLight;
var(SFXWeapon) GFxMovieInfo IconResource;
var(SFXWeapon) WwiseEvent DefaultImpactSound;
var(SFXWeapon) WwiseEvent FireSound;
var(SFXWeapon) WwiseEvent PlayerFireSound;
var WwiseEvent WeaponPowerFireSound;
var(SFXWeapon) WwiseEvent FireNoAmmoSound;
var(SFXWeapon) WwiseEvent WeaponWhipSoundLeft;
var(SFXWeapon) WwiseEvent WeaponWhipSoundRight;
var(SFXWeapon) WwiseEvent WeaponReloadSound;
var(SFXWeapon) WwiseEvent WeaponSteamReloadSound;
var(SFXWeapon) WwiseEvent StopWeaponReloadSound;
var(SFXWeapon) WwiseEvent WeaponExpandSound;
var(SFXWeapon) WwiseEvent WeaponCollapseSound;
var(SFXWeapon) WwiseEvent NeedReloadNotifySound;
var(SFXWeapon) WwiseEvent SteamReloadNotifySound;
var WwiseEvent ActivateModScopeZoomWwiseEvent;
var WwiseEvent DeActivateModScopeZoomWwiseEvent;
var(SFXWeapon) config Vector2D FrictionMultiplierRange;
var(SFXWeapon) config Vector2D AdhesionStrengthRange;
var(SFXWeapon) instanced ParticleSystemComponent AmmoPowerPSCO;
var(SFXWeapon) instanced ParticleSystemComponent AmmoPowerIconPSCO;
var transient Name AmmoPowerName;
var transient Name AmmoPowerSourceTag;
var Actor DummyFireParent;
var Actor DummyFireTargetActor;
var Pawn PreDummyFireInstigator;
var SFXCameraSetup CameraSetup;
var RvrClientEffectInterface TaserMeleeModImpactEffect;
var WwiseEvent TaserMeleeModImpactSound;
var ParticleSystem BladeMeleeModImpactEffect;
var WwiseEvent BladeMeleeModImpactSound;
var instanced ParticleSystemComponent ChargeUpPS;
var instanced ParticleSystemComponent ChargeDownPS;
var WwiseEvent PowerUpSound;
var WwiseEvent PowerDownSound;
var WwiseEvent NPCPowerUpSound;
var WwiseEvent NPCPowerDownSound;
var Actor StartFireTarget;
var transient int RemainingBurstFireCount;
var transient int RemainingBurstsToFire;
var(SFXWeapon) int CurrentAimMode;
var(SFXWeapon) config float CoverLeanExitDelay;
var(SFXWeapon) config float CoverPartialLeanExitDelay;
var const int SwitchPriority;
var config float ImpactRelevanceDistance;
var(SFXWeapon) float ImpactScale;
var config float ShowTracerDistance;
var(SFXWeapon) config float TracerSpawnOffset;
var(SFXWeapon) config float MuzzleLightLifetime;
var(SFXWeapon) config float MuzzleLightBrightness;
var(SFXWeapon) config Color MuzzleLightColor;
var(SFXWeapon) config float MuzzleLightFalloffExponent;
var(SFXWeapon) config float MuzzleLightMinShadowFalloffRadius;
var(SFXWeapon) config float MuzzleLightRadius;
var(SFXWeapon) config float MuzzleLightShadowFalloffExponent;
var(SFXWeapon) config float MuzzleLightShadowRadiusMultiplier;
var(SFXWeapon) config float LightStepSize;
var int LightKeyIndex;
var float LightCurrentTime;
var float LightDeltaBrightness;
var float LightDeltaR;
var float LightDeltaG;
var float LightDeltaB;
var float TimeToHideMuzzleFlashPSC;
var float TimeToDeactivateMuzzleFlashPSC;
var(SFXWeapon) Color FlashlightFireColor;
var(SFXWeapon) float FlashlightFireBrightnessIncrease;
var(SFXWeapon) float FlashlightFireRadiusIncrease;
var(SFXWeapon) float FlashlightStopFireDelay;
var float WeaponLevel;
var(SFXWeapon) config float EjectShellCasingTimeRatio;
var(SFXWeapon) config float ReloadReactionWindow;
var config float LastBulletStrongerPercent;
var transient float StealthDamageIncrease;
var(SFXWeapon) config float DamageHench;
var(SFXWeapon) config float LowAmmoSoundThreshold;
var(SFXWeapon) config float SteamSoundThreshold;
var(SFXWeapon) config float NoAmmoFireSoundDelay;
var(SFXWeapon) config float MinRefireTime;
var(SFXWeapon) config float LazyRateOfFire;
var(SFXWeapon) config float RateOfFireAI;
var(SFXWeapon) config float RoundsPerBurst;
var(SFXWeapon) config float ModCrosshairMultiplier;
var config float AmmoPerShot;
var(SFXWeapon) config float RecoilInterpSpeed;
var(SFXWeapon) config float RecoilFadeSpeed;
var(SFXWeapon) config float RecoilZoomFadeSpeed;
var(SFXWeapon) config float RecoilMinFade;
var(SFXWeapon) config float RecoilCap;
var(SFXWeapon) config float ZoomRecoilCap;
var(SFXWeapon) config float RecoilYawScale;
var(SFXWeapon) config float RecoilYawFrequency;
var(SFXWeapon) config float TraceRange;
var(SFXWeapon) config float MeleeRange;
var(SFXWeapon) config float IdealMinRange;
var(SFXWeapon) config float IdealTargetDistance;
var(SFXWeapon) config float IdealMaxRange;
var config float MagneticCorrectionThresholdAngle;
var config float MaxMagneticCorrectionAngle;
var config float DistancePenetrated;
var(SFXWeapon) config int IconRef;
var(SFXWeapon) config stringref PrettyName;
var(SFXWeapon) config stringref ShortPrettyName;
var(SFXWeapon) config stringref GUIClassName;
var(SFXWeapon) config stringref GUIClassDescription;
var(SFXWeapon) config stringref AmmoPrettyName;
var(SFXWeapon) config stringref ShortDescription;
var(SFXWeapon) config stringref GeneralDescription;
var const stringref WeaponUnlockMessage;
var const stringref WeaponUpgradeMessage;
var(SFXWeapon) int GUIWeaponOrder;
var(SFXWeapon) config stringref NuiSpeechName;
var(SFXWeapon) float WeaponLoudness;
var(SFXWeapon) config float MinFrictionDistance;
var(SFXWeapon) config float MaxFrictionDistance;
var(SFXWeapon) config float PeakFrictionDistance;
var(SFXWeapon) config float PeakFrictionRadiusScale;
var(SFXWeapon) config float PeakFrictionHeightScale;
var(SFXWeapon) config float MinAdhesionDistance;
var(SFXWeapon) config float MaxAdhesionDistance;
var(SFXWeapon) config float MinAdhesionVelocity;
var(SFXWeapon) config float CamInputAdhesionDamping;
var(SFXWeapon) config float MaxLateralAdhesionDist;
var(SFXWeapon) config float AimCorrectionAmount;
var(SFXWeapon) config float MinZoomSnapDistance;
var(SFXWeapon) config float MaxZoomSnapDistance;
var const int DamageUpgradeId;
var float DummyFireInaccuracy;
var float DummyFireShotsRemaining;
var config transient int MaxWeaponMods;
var transient float TaserMeleeModStunDuration;
var config float ClientSideHitLeeway;
var config float ClientSideHitMaxDistReallyClose;
var config float ClientSideHitMaxAngle;
var config float ClientSideHitMaxDistClose;
var config float ClientSideHitMaxAngleClose;
var int NumberOfDefaultModsToAttach;
var(SFXWeapon) config float HearNoiseTimeout;
var float ChargeAmount;
var config float MinChargeTime;
var config float MaxChargeTime;
var float MaxChargeFireRumble;
var float MinChargeFireRumble;
var float MaxChargeCameraShake;
var transient float ChargeStartTime;
var transient float LastFireTime;
var config float MaxLevel;
var config int WeaponAcquiredID;
var config int WeaponAcquiredID_NGP;
var int NewGamePlusID;
var int CodexPlotID;
var(Debug) bool bSuperDamage;
var(Debug) bool bSuppressMuzzleFlash;
var(Debug) bool bSuppressTracers;
var(Debug) bool bSuppressImpactFX;
var(Debug) bool bSuppressDecal;
var(Debug) bool bSuppressDamage;
var(Debug) bool bSuppressCameraShake;
var bool bPlayerUsable;
var(SFXWeapon) bool bLoopingFlashEmitter;
var(SFXWeapon) bool bPlayingMuzzleFlashEffect;
var(SFXWeapon) bool bPermanentMuzzle;
var bool bForceSpawnTracer;
var bool bFlashlightAttached;
var(SFXWeapon) bool bWeaponCanBeReloaded;
var transient bool bDrawingWeapon;
var transient bool bHolsteringWeapon;
var transient bool bFiringAnimationPlaying;
var config bool bNotRegularWeaponGUI;
var(SFXWeapon) bool bPlayZoomSound;
var bool bPlaySoundOncePerBurst;
var bool bAIPlaySoundOncePerBurst;
var(SFXWeapon) config bool bFrictionEnabled;
var(SFXWeapon) config bool bFrictionDistanceScalingEnabled;
var(SFXWeapon) config bool bAdhesionEnabled;
var(SFXWeapon) config bool bAdhesionDuringCam;
var(SFXWeapon) config bool bZoomSnapEnabled;
var bool bScaleAnimDurationByFireRate;
var protectedwrite transient bool bWeaponAndEffectsHidden;
var transient bool bNoAmmoPowerTracers;
var bool bDummyFireWeapon;
var bool bDamagesFriends;
var bool bSuppressDummyFireLineCheck;
var bool DummyFireInstigatorSet;
var config bool bDoesNotUnlock;
var transient bool bTaserMeleeModApplied;
var transient bool bBladeMeleeModApplied;
var config bool bAutoModdingEnabled;
var bool bNeedPowerDownSound;
var config bool bForceFireAfterCharge;
var transient bool bFired;
var transient bool bIsCharged;
var const bool bQuickSwitchEligible;
var AimProfiles AimNodeProfileID;
var IKProfiles IKProfileID;
var FireModes DefaultFireMode;
var(SFXWeapon) WeaponAnimType AnimType;
var const EAttachSlot AttachSlot;
var byte FireOnceFiringMode;
var transient byte PendingFireMode;
var byte DummyTeamIndex;
var EPlayerPositionRTPC RTPCPlayerPosition;
var repnotify ChargeEffectType RepChargeEffect;

public event simulated function bool CalculateCoverLeanOutOffset(out Vector Offset, ECoverDirection Direction, ECoverType Type)
{
    local int i;
    local int J;
    
    for (i = 0; i < default.CoverLeanPositions.Length; ++i)
    {
        if (int(default.CoverLeanPositions[i].Direction) == int(Direction) && int(default.CoverLeanPositions[i].Type) == int(Type))
        {
            for (J = 0; J < default.CoverLeanPositions[i].WeaponTypes.Length; ++J)
            {
                if (int(default.CoverLeanPositions[i].WeaponTypes[J]) == int(AnimType))
                {
                    Offset = default.CoverLeanPositions[i].Offset;
                    return TRUE;
                }
            }
        }
    }
    return FALSE;
}
public simulated function CancelReload();

public event simulated function Destroyed()
{
    // MILAN CHANGE - Mgamerz - 2026-10-16
    // Ensure flashlight is detached when weapon is destroyed
    DetachFlashlight();
    // END MILAN CHANGE
    Super(Weapon).Destroyed();
    HideMuzzleFlashEmitter();
    HideMuzzleFlashLight();
    HideReloadEmitters();
}
public event simulated function DummyFire(byte FireModeNum, Vector TargetLoc, optional Actor AttachedTo, optional float AimErrorDeg, optional Actor TargetActor)
{
    local ImpactInfo InstantHitImpact;
    local Vector StartLoc;
    local Vector EndLoc;
    local Rotator AimRot;
    local float AimErrorUnr;
    local int idx;
    local array<ImpactInfo> ImpactList;
    
    if (Pawn(AttachedTo) != None && DummyFireInstigatorSet == FALSE)
    {
        PreDummyFireInstigator = Instigator;
        DummyFireInstigatorSet = TRUE;
        Instigator = Pawn(AttachedTo);
    }
    DummyFireParent = AttachedTo;
    bDummyFireWeapon = TRUE;
    DummyFireTargetLoc = TargetLoc;
    DummyFireTargetActor = TargetActor;
    DummyFireInaccuracy = AimErrorDeg;
    if (int(FireModeNum) == 0)
    {
        FireModeNum = DefaultFireMode;
    }
    SetCurrentFireMode(FireModeNum);
    switch (WeaponFireTypes[int(FireModeNum)])
    {
        case 1:
            ProjectileFireSimple(AimErrorDeg);
            break;
        case 0:
            StartLoc = GetPhysicalFireStartLoc();
            AimRot = Rotator(DummyFireTargetLoc - StartLoc);
            if (AimErrorDeg != 0.0)
            {
                AimErrorUnr = AimErrorDeg * 182.044006;
                AimRot.Pitch += int(AimErrorUnr * (0.5 - FRand()));
                AimRot.Yaw += int(AimErrorUnr * (0.5 - FRand()));
            }
            EndLoc = StartLoc + Vector(AimRot) * float(30000);
            if (bSuppressDummyFireLineCheck)
            {
                InstantHitImpact.HitActor = None;
            }
            else
            {
                InstantHitImpact = CalcWeaponFire(StartLoc, EndLoc, ImpactList);
            }
            if (InstantHitImpact.HitActor != None)
            {
                WeaponFired(FireModeNum, FALSE, InstantHitImpact.HitLocation);
                for (idx = 0; idx < ImpactList.Length; idx++)
                {
                    if (ImpactList[idx].HitActor != None)
                    {
                        CalcRemoteImpactEffects(FireModeNum, ImpactList[idx].HitLocation, FALSE);
                    }
                }
            }
            else
            {
                WeaponFired(FireModeNum, FALSE, EndLoc);
            }
            break;
        case 2:
        default:
            break;
    }
}
public simulated function Vector GetMuzzleLoc()
{
    local SkeletalMeshComponent WeapMesh;
    local Vector Loc;
    local Vector X;
    local Vector Y;
    local Vector Z;
    local Rotator Rot;
    local SFXPawn Pawn;
    
    Pawn = SFXPawn(Instigator);
    if (Pawn != None && Pawn.bSupportsVisibleWeapons == FALSE)
    {
        if (Pawn.MuzzleSocketName != 'None' && Pawn.Mesh.GetSocketWorldLocationAndRotation(Pawn.MuzzleSocketName, Loc, Rot))
        {
            return Loc;
        }
        else
        {
            return Instigator.location;
        }
    }
    WeapMesh = SkeletalMeshComponent(Mesh);
    if (WeapMesh != None && MuzzleSocketName != 'None')
    {
        if (WeapMesh.GetSocketWorldLocationAndRotation(MuzzleSocketName, Loc, Rot))
        {
            return Loc;
        }
    }
    else if (Instigator != None && Instigator.Mesh != None && MuzzleSocketName != 'None')
    {
        if (Instigator.Mesh.GetSocketWorldLocationAndRotation(MuzzleSocketName, Loc, Rot))
        {
            return Loc;
        }
    }
    if (BioPawn(Instigator) != None && BioPawn(Instigator).GetWeaponHandPosition(Loc, Rot))
    {
        GetAxes(Rot, X, Y, Z);
        return Loc + FireOffset.X * X + FireOffset.Y * Y + FireOffset.Z * Z;
    }
    if (Instigator != None)
    {
        return Instigator.location;
    }
    return location;
}
public event simulated function float GetPenetrationDepth()
{
    if (Instigator != None && Instigator.GetTeam().TeamIndex == 0)
    {
        return DistancePenetrated + (PenetrationBonus.Value - 1.0) * 100.0;
    }
    else
    {
        return 0.0;
    }
}
public simulated function Vector GetPhysicalFireStartLoc(optional Vector AimDir)
{
    return GetMuzzleLoc();
}
public simulated function float GetReloadDuration()
{
    return ReloadDuration.Value;
}
public simulated function float GetTraceRange()
{
    return TraceRange;
}
public event simulated function bool HasLoopingFire()
{
    if (DefaultFireMode == FireModes.FireMode_SemiAuto)
    {
        return FALSE;
    }
    return TRUE;
}
public simulated function PostBeginPlay()
{
    Super(Actor).PostBeginPlay();
    DeferredPostBeginPlay();
}
public simulated function PostInitAnimTree(SkeletalMeshComponent SkelComp)
{
    Super(Actor).PostInitAnimTree(SkelComp);
    CacheAnimNodes();
}
public static simulated function PrecacheVFX(SFXObjectPool ObjectPool, RvrClientEffectManager ClientEffects)
{
    local PhysicalMaterial PhysMat;
    local ParticleSystem PhysMatEffect;
    local Class<Projectile> ProjectileClass;
    local int ExpectedRateOfFire;
    
    ExpectedRateOfFire = Max(1, int(default.RateOfFire.Y / 60.0));
    ObjectPool.PrecacheImpactParticleSystemComponent(default.PS_DefaultMaterialImpactEffect, ExpectedRateOfFire);
    ObjectPool.PrecacheImpactParticleSystemComponent(default.PS_DefaultImpactEffect, ExpectedRateOfFire);
    foreach Class'PhysicalMaterial'.static.AllPhysicalMaterials(PhysMat)
    {
        PhysMatEffect = GetImpactEffect(PhysMat);
        while (PhysMatEffect == None && PhysMat.Parent != None)
        {
            PhysMat = PhysMat.Parent;
            PhysMatEffect = GetImpactEffect(PhysMat);
        }
        if (PhysMatEffect != None)
        {
            ObjectPool.PrecacheImpactParticleSystemComponent(PhysMatEffect, ExpectedRateOfFire);
        }
    }
    ObjectPool.PrecacheTracer(default.TracerInfo.StaticMesh, default.TracerInfo.PlayerPSTemplate, ExpectedRateOfFire);
    ObjectPool.PrecacheTracer(default.TracerInfo.StaticMesh, default.TracerInfo.StandardPSTemplate, ExpectedRateOfFire);
    foreach default.WeaponProjectiles(ProjectileClass, )
    {
        if (Class<SFXProjectile>(ProjectileClass) != None)
        {
            Class<SFXProjectile>(ProjectileClass).static.PrecacheVFX(ObjectPool, ClientEffects);
            ObjectPool.PrecacheProjectile(Class<SFXProjectile>(ProjectileClass));
        }
    }
}
public simulated function ProcessInstantHit(byte FiringMode, ImpactInfo Impact, optional int NumHits)
{
    local SFXModule_Armour ArmMod;
    local int idx;
    local int ArmourHitIdx;
    
    if (Instigator != None)
    {
        if (Instigator.Role < ENetRole.ROLE_Authority && Instigator.IsLocallyControlled())
        {
            if (Impact.HitActor != None)
            {
                ArmourHitIdx = -1;
                ArmMod = Impact.HitActor.GetModule(Class'SFXModule_Armour');
                if (ArmMod != None)
                {
                    for (idx = 0; idx < 12; idx++)
                    {
                        if (ArmMod.ActiveArmour[idx] != None && ArmMod.ActiveArmour[idx].AttachInstance != None && ArmMod.ActiveArmour[idx].AttachInstance == Impact.HitInfo.HitComponent)
                        {
                            ArmourHitIdx = idx;
                            break;
                        }
                    }
                }
            }
            ServerProcessInstantHit(FiringMode, Impact, ArmourHitIdx, bSuppressAudio, NumHits);
        }
        else if (Instigator.Role == ENetRole.ROLE_Authority && Instigator.IsLocallyControlled() == FALSE && Impact.HitActor != None && (Impact.HitActor.RemoteRole == ENetRole.ROLE_SimulatedProxy || Impact.HitActor.RemoteRole == ENetRole.ROLE_AutonomousProxy || Impact.HitActor.bStatic || Impact.HitActor.bNoDelete))
        {
            return;
        }
    }
    SFXGRI(WorldInfo.GRI).PreAsyncWorker.ProcessInstantHit(Self, FiringMode, Impact, bSuppressAudio, NumHits);
}
public simulated function ProcessInstantHit_Internal(byte FiringMode, ImpactInfo Impact, optional int NumHits)
{
    local Pawn PossiblyHitPawn;
    local Class<SFXDamageType> DamageTypeToUse;
    local float MomentumMag;
    local int idx;
    local delegate<OnWeaponImpact> ImpactDelegate;
    local float fDamage;
    
    OnWeaponImpact(Self, Impact);
    for (idx = 0; idx < ImpactSubscriptions.Length; ++idx)
    {
        ImpactDelegate = ImpactSubscriptions[idx];
        if (ImpactDelegate != None)
        {
            ImpactDelegate(Self, Impact);
        }
    }
    DamageTypeToUse = GetDamageType(FiringMode);
    MomentumMag = FMax(1.0, InstantHitMomentum[int(FiringMode)]);
    if (!bSuppressDamage && Impact.HitActor != None)
    {
        fDamage = GetFireModeBaseDamage();
        if (Impact.PenetrationDepth > 0.0)
        {
            fDamage *= PenetrationDamageBonus.Value;
        }
        Impact.HitActor.TakeDamage(fDamage, Instigator != None ? Instigator.Controller : None, Impact.HitLocation, MomentumMag * Impact.RayDir, DamageTypeToUse, Impact.HitInfo, Self);
    }
    if (Trigger(Impact.HitActor) != None || TriggerVolume(Impact.HitActor) != None)
    {
        return;
    }
    if (WorldInfo.NetMode != ENetMode.NM_Client)
    {
        if (Pawn(Impact.HitActor) == None)
        {
            ProcessInstantHitNearMiss(Impact.StartTrace, Impact.HitLocation);
        }
    }
    if (WorldInfo.NetMode != ENetMode.NM_DedicatedServer)
    {
        if (Impact.HitActor != None)
        {
            PossiblyHitPawn = Pawn(Impact.HitActor);
            if (PossiblyHitPawn == None && Pawn(Impact.HitActor.Base) == None)
            {
                SpawnImpactEffects(Impact);
                SpawnImpactSounds(Impact);
                SpawnADecal(Impact);
            }
        }
    }
}
public event simulated function ReplicatedEvent(Name VarName)
{
    Super(Actor).ReplicatedEvent(VarName);
    switch (VarName)
    {
        case 'CharacterSlot':
            CharacterSlotUpdated();
            break;
        case 'FizzleCount':
            if (int(FizzleCount) == 0)
            {
                ClearTimer('PlayNoAmmoFireSound');
            }
            else
            {
                PlayNoAmmoEffects();
            }
            break;
        case 'RepChargeEffect':
            switch (RepChargeEffect)
            {
                case ChargeEffectType.CET_ShutOffAll:
                    ShutOffAllEmitters();
                    break;
                case ChargeEffectType.CET_StopCharge:
                    StopChargeEffects();
                    break;
                case ChargeEffectType.CET_StartCharge:
                    StartChargeEffects();
                    break;
                default:
            }
            break;
        default:
    }
}
public simulated function SetZoomed(bool bState)
{
    local BioPlayerController PC;
    local SFXWeapon_SniperRifle_Base SniperRifle;
    local SFXModule_WeaponModManager ModManager;
    local SFXWeaponMod Mod;
    local bool bIsInCover;
    
    bIsZoomed = bState;
    ServerSetIsZoomed(bState);
    CurrentAimMode = 0;
    PC = BioPlayerController(Instigator.Controller);
    if (PC == None)
    {
        return;
    }
    ModManager = GetModule(Class'SFXModule_WeaponModManager');
    if (bState)
    {
        if (PC.IsLocalPlayerController())
        {
            PC.HintSystem.HintEvent('Zoom', @Class.Name);
        }
        if (ModManager != None)
        {
            foreach ModManager.WeaponMods(Mod, )
            {
                if (Mod.bIsScoped)
                {
                    SFXPawn_Player(Owner).PlaySound(ActivateModScopeZoomWwiseEvent, TRUE);
                    bPlayZoomSound = TRUE;
                    break;
                }
            }
        }
    }
    bIsInCover = PC.IsInCoverState();
    if (bIsZoomed && bIsInCover)
    {
        if (AimModes[CurrentAimMode].bScoped)
        {
            SniperRifle = SFXWeapon_SniperRifle_Base(Self);
            if (SniperRifle == None)
            {
                SetRTPCPlayerPosition(8);
            }
            else
            {
                SetRTPCPlayerPosition(7);
            }
        }
        else
        {
            SetRTPCPlayerPosition(6);
        }
    }
    else if (bIsZoomed && !bIsInCover)
    {
        if (AimModes[CurrentAimMode].bScoped)
        {
            SniperRifle = SFXWeapon_SniperRifle_Base(Self);
            if (SniperRifle == None)
            {
                SetRTPCPlayerPosition(4);
            }
            else
            {
                SetRTPCPlayerPosition(3);
            }
        }
        else
        {
            SetRTPCPlayerPosition(2);
        }
    }
    else if (!bIsZoomed && bIsInCover)
    {
        SetRTPCPlayerPosition(5);
    }
    else
    {
        SetRTPCPlayerPosition(1);
        if (ModManager != None)
        {
            foreach ModManager.WeaponMods(Mod, )
            {
                if (Mod.bIsScoped)
                {
                    if (bPlayZoomSound)
                    {
                        SFXPawn_Player(Owner).PlaySound(DeActivateModScopeZoomWwiseEvent, TRUE);
                        bPlayZoomSound = FALSE;
                    }
                }
            }
        }
    }
}
public event simulated function WeaponStoppedFiring(byte FiringMode)
{
    if (Instigator != None)
    {
        Instigator.ShotCount = 0;
    }
    StopFireEffects(FiringMode);
    HideReloadEmitters();
}
public simulated function bool EffectIsRelevant(Vector SpawnLocation, bool bForceDedicated, optional float CullDistance)
{
    if (Instigator == None)
    {
        return TRUE;
    }
    else
    {
        return Super(Actor).EffectIsRelevant(SpawnLocation, bForceDedicated, CullDistance);
    }
}
public static function string GetPrettyName(optional int Level = -1)
{
    local string sName;
    
    if (Level >= 0)
    {
        SetCustomToken(0, Class'SFXWeaponUIDataManager'.static.GetRomanNumeral(Level));
    }
    else
    {
        SetCustomToken(0, "");
    }
    sName = GetTokenisedString(default.PrettyName);
    ClearCustomTokens();
    return sName;
}
public static final function GetWeaponStatBarValues(EWeaponStatBars StatBar, out float WeaponValue)
{
    switch (StatBar)
    {
        case EWeaponStatBars.EWeaponStatBarAccuracy:
            WeaponValue = default.StatBarAccuracy.X;
            break;
        case EWeaponStatBars.EWeaponStatBarDamage:
            WeaponValue = default.Damage.X;
            break;
        case EWeaponStatBars.EWeaponStatBarFireRate:
            WeaponValue = default.RateOfFire.X;
            break;
        case EWeaponStatBars.EWeaponStatBarMagSize:
            WeaponValue = default.MaxSpareAmmo.X;
            break;
        case EWeaponStatBars.EWeaponStatBarWeight:
            WeaponValue = default.EncumbranceWeight.X;
            break;
        default:
            WeaponValue = 0.0;
    }
}
public simulated function int AddAmmo(int Amount)
{
    local int AmmoConsumed;
    local int OldTotalAmmo;
    
    if (GetMaxSpareAmmo() <= 0)
    {
        return 0;
    }
    if (!IsActiveWeapon() && Amount >= 0)
    {
        AmmoConsumed = Min(Amount, AmmoUsedCount);
        AmmoUsedCount -= AmmoConsumed;
        Amount -= AmmoConsumed;
    }
    OldTotalAmmo = GetCurrentSpareAmmo();
    CurrentSpareAmmo = Max(0, Min(GetCurrentSpareAmmo() + Amount, GetMaxSpareAmmo()));
    return CurrentSpareAmmo - OldTotalAmmo;
}
public simulated function AttachWeaponTo(SkeletalMeshComponent MeshCpnt, optional Name SocketName)
{
    local SkeletalMeshComponent WeaponSkelMesh;
    local SFXPawn Pawn;
    local SFXHeavyWeapon HeavyWeapon;
    
    Pawn = SFXPawn(Instigator);
    WeaponSkelMesh = SkeletalMeshComponent(Mesh);
    if (Pawn == None || Pawn.bSupportsVisibleWeapons)
    {
        if (Mesh != None && MeshCpnt.IsComponentAttached(Mesh, SocketName) == FALSE)
        {
            Mesh.SetShadowParent(MeshCpnt);
            Mesh.SetLightEnvironment(MeshCpnt.LightEnvironment);
            Mesh.SetDepthPriorityGroup(MeshCpnt.DepthPriorityGroup);
            if (MeshCpnt.GetSocketByName(SocketName) != None)
            {
                MeshCpnt.AttachComponentToSocket(WeaponSkelMesh, SocketName);
            }
            AttachMuzzleEffectsComponents(WeaponSkelMesh, MuzzleSocketName, ShellCasingSocketName);
        }
    }
    else if (Pawn != None)
    {
        AttachMuzzleEffectsComponents(MeshCpnt, Pawn.MuzzleSocketName, Pawn.ShellCasingSocketName);
    }
    HeavyWeapon = SFXHeavyWeapon(Self);
    if (HeavyWeapon != None && HeavyWeapon.bHiddenVariant && Pawn != None && MeshCpnt == Pawn.Mesh)
    {
        HeavyWeapon.bHiddenVariantStowed = SocketName != Pawn.RightHandSocketName;
        SetWeaponHidden(HeavyWeapon.bHiddenVariantRequestedHidden);
    }
}
public simulated function CacheAnimNodes()
{
    local AnimNodeSlot SlotNode;
    local SkeletalMeshComponent MeshCmpt;
    
    MeshCmpt = SkeletalMeshComponent(Mesh);
    WeaponAnimNode = None;
    if (MeshCmpt != None && MeshCmpt.Animations != None)
    {
        foreach MeshCmpt.AllAnimNodes(Class'AnimNodeSlot', SlotNode)
        {
            if (SlotNode.NodeName == 'None')
            {
                continue;
            }
            if (SlotNode.NodeName == 'Custom_Weapon')
            {
                WeaponAnimNode = SlotNode;
            }
        }
    }
}
public simulated function ImpactInfo CalcWeaponFire(Vector StartTrace, Vector EndTrace, optional out array<ImpactInfo> ImpactList, optional Vector Extent)
{
    local SFXPlayerCamera Camera;
    local Vector ToPC;
    local Vector CamRot;
    local float PenetrationMax;
    
    DrawDebugShot(StartTrace, EndTrace);
    if (Instigator != None && Instigator.IsHumanControlled() && Instigator.Controller != None)
    {
        Camera = SFXPlayerCamera(PlayerController(Instigator.Controller).PlayerCamera);
        if (Camera != None)
        {
            ToPC = Instigator.location - StartTrace;
            CamRot = Vector(Camera.CameraCache.POV.Rotation);
            StartTrace += CamRot * (ToPC Dot CamRot);
        }
    }
    if (Instigator != None && Instigator.GetTeam().TeamIndex == 0)
    {
        PenetrationMax = DistancePenetrated + (PenetrationBonus.Value - 1.0) * 100.0;
    }
    else
    {
        PenetrationMax = 0.0;
    }
    return CalcWeaponFire_Native(StartTrace, EndTrace, ImpactList, PenetrationMax, Extent);
}
public simulated function bool CanThrow()
{
    if (SFXPawn_Henchman(Owner) != None)
    {
        return FALSE;
    }
    else if (SFXPawn_Player(Owner) != None)
    {
        return TRUE;
    }
    else
    {
        return bCanDropWeapon || bCanDropAmmo;
    }
}
public simulated function ClearFlashLocation()
{
    if (Instigator != None)
    {
        Instigator.ClearFlashLocation(Self);
    }
}
public reliable client function ClientWeaponSet(bool bOptionalSet, optional bool bDoNotActivate);

public reliable client function ClientWeaponThrown()
{
    local BioPawn BP;
    
    BP = BioPawn(Owner);
    if (BP != None && BP.Weapon == Self)
    {
        BP.SetupWeaponAnimations(None, Self);
    }
    Super(Weapon).ClientWeaponThrown();
}
public simulated function ConsumeAmmo(byte FireModeNum)
{
    local int MagazineSize;
    local int OldAmmoUsedCount;
    local BioRemoteLogger GLogger;
    local BioPlayerController PC;
    
    if (NoAmmoUseChance.Value - 1.0 > float(0) && FRand() < NoAmmoUseChance.Value - 1.0)
    {
        return;
    }
    MagazineSize = GetMagazineSize();
    OldAmmoUsedCount = AmmoUsedCount;
    AmmoUsedCount += int(AmmoPerShot);
    if (Instigator != None && Instigator.IsHumanControlled())
    {
        PC = BioPlayerController(Instigator.Controller);
        if (PC != None && PC.IsLocalPlayerController())
        {
            PC.HintSystem.HintEvent('Fire', @Class.Name);
        }
        Class'WwiseAudioComponent'.static.SetGlobalRTPCFromScript(AmmoRTPCName, 1.0 - float(AmmoUsedCount / GetMagazineSize()));
    }
    if (float(MagazineSize - AmmoUsedCount) <= LowAmmoSoundThreshold && Instigator.IsHumanControlled())
    {
        if (float(MagazineSize - OldAmmoUsedCount) >= LowAmmoSoundThreshold)
        {
            WeaponPlayWwiseEvent(NeedReloadNotifySound, 0.0);
            if (Instigator.Role == ENetRole.ROLE_Authority && Instigator.IsHumanControlled() && SFXHeavyWeapon(Self) == None && CurrentSpareAmmo == 0)
            {
                SFXGRI(WorldInfo.GRI).TriggerVocalizationEvent(105, BioPawn(Instigator), , , , TRUE);
            }
        }
        if (MagazineSize - AmmoUsedCount == 0 && CurrentSpareAmmo == 0)
        {
            SFXGRI(WorldInfo.GRI).TriggerVocalizationEvent(106, BioPawn(Instigator));
        }
    }
    if (float(GetMagazineSize() - AmmoUsedCount) < SteamSoundThreshold && Instigator.IsHumanControlled())
    {
        if (float(GetMagazineSize() - OldAmmoUsedCount) >= SteamSoundThreshold)
        {
            WeaponPlayWwiseEvent(SteamReloadNotifySound, 0.0);
        }
    }
    if (MagazineSize >= 0 && float(AmmoUsedCount) + AmmoPerShot > float(MagazineSize))
    {
        if (SFXPawn_Player(Owner) != None && SFXPawn_Player(Owner).OutOfAmmoTimestamp == 0.0)
        {
            SFXPawn_Player(Owner).OutOfAmmoTimestamp = WorldInfo.GameTimeSeconds;
        }
        if (Instigator.IsHumanControlled() && OutOfAmmo())
        {
            GLogger = Class'BioRemoteLogger'.static.GetLogger();
            if (GLogger != None)
            {
                GLogger.SendPlayerEvent(69, "", "", "", "", 0, 0, 0, 0);
            }
        }
    }
}
public simulated function DetachWeapon()
{
    local SkeletalMeshComponent PawnMesh;
    
    if (Mesh != None)
    {
        if (Instigator != None && Instigator.Mesh != None)
        {
            PawnMesh = Instigator.Mesh;
            if (PawnMesh != None && PawnMesh.IsComponentAttached(Mesh))
            {
                PawnMesh.DetachComponent(Mesh);
            }
        }
        Mesh.SetShadowParent(None);
        Mesh.SetLightEnvironment(None);
        if (bPermanentMuzzle)
        {
            PSC_PermanentMuzzle.SetActive(FALSE);
        }
    }
}
public function DropFrom(Vector StartLocation, Vector StartVelocity)
{
    local SFXDroppedPickup P;
    local SFXDroppedAmmo Ammo;
    local bool bDropWeapon;
    local Actor OwnerCache;
    local PlayerController PC;
    local bool bOnSameNetwork;
    
    if (!CanThrow())
    {
        return;
    }
    OwnerCache = Owner;
    ForceEndFire();
    DetachWeapon();
    GotoState('Inactive', , , );
    if (Instigator != None && Instigator.InvManager != None)
    {
        Instigator.InvManager.RemoveFromInventory(Self);
    }
    if (DroppedPickupClass == None && DroppedAmmoClass == None)
    {
        Destroy();
        return;
    }
    if (bCanDropAmmo && DroppedAmmoClass != None && SFXGRI(WorldInfo.GRI) != None && SFXGRI(WorldInfo.GRI).bMultiplayer == FALSE && SFXPawn(Instigator) != None && SFXPawn(Instigator).bCanDropAmmo && FRand() <= SFXPawn(Instigator).AmmoDropPct)
    {
        foreach WorldInfo.AllControllers(Class'PlayerController', PC)
        {
            if (PC != None && PC.Pawn != None && PC.Pawn.IsOnSamePathNetwork(Instigator))
            {
                bOnSameNetwork = TRUE;
                break;
            }
        }
        if (bOnSameNetwork)
        {
            Ammo = SFXDroppedAmmo(SFXGRI(WorldInfo.GRI).ObjectPool.GetDroppedAmmo(DroppedAmmoClass, StartLocation));
            if (Ammo == None)
            {
                Destroy();
                return;
            }
            Ammo.SetPhysics(2);
            Ammo.Inventory = Self;
            Ammo.InventoryClass = DroppedAmmoClass.default.InventoryClass;
            Ammo.Velocity = StartVelocity;
            Ammo.Instigator = Instigator;
            Ammo.SetCollisionCylinderSize(12.0, 2.0);
            Instigator = None;
            GotoState('None', , , );
        }
    }
    bDropWeapon = SFXPawn_Player(OwnerCache) != None ? TRUE : bCanDropWeapon;
    if (bDropWeapon && DroppedPickupClass != None)
    {
        P = SFXDroppedPickup(Spawn(DroppedPickupClass, , , StartLocation));
        if (P == None)
        {
            Destroy();
            return;
        }
        P.Inventory = Self;
        P.InventoryClass = @Class;
        P.Velocity = StartVelocity;
        P.Instigator = Instigator;
        P.SetPickupMesh(Mesh);
        P.SetPickupParticles(DroppedPickupParticles);
        LifeSpan = SFXGRI(WorldInfo.GRI).gameconfig.DroppedWeaponLifespan;
        Instigator = None;
        GotoState('None', , , );
    }
    else
    {
        Destroy();
        return;
    }
}
public simulated function EndFire(byte FireModeNum)
{
    Super(Weapon).EndFire(FireModeNum);
    CurrentFireMode = 0;
}
public simulated function FireModeUpdated(byte FiringMode, bool bViaReplication)
{
    if (bViaReplication)
    {
        if (int(FiringMode) == 4)
        {
            StartFire(4);
        }
        else
        {
            GotoState('Active', , , );
        }
    }
}
public simulated function ForceEndFire()
{
    ClearTimer('PlayNoAmmoFireSound');
    ClearFizzleCount();
    Super(Weapon).ForceEndFire();
}
public simulated function Rotator GetAdjustedAim(Vector StartFireLoc)
{
    local Rotator AimRot;
    local float AimingError;
    
    AimRot = Instigator.GetAdjustedAimFor(Self, StartFireLoc);
    if (Instigator != None && Instigator.IsHumanControlled())
    {
        AimingError = GetPlayerAimError(SFXPlayerInventoryManager(InvManager).Accuracy) * 182.044449;
        if (AimingError > float(0))
        {
            AimRot.Pitch += int(AimingError * (0.5 - FRand()));
            AimRot.Yaw += int(AimingError * (0.5 - FRand()));
        }
    }
    return AimRot;
}
public simulated function float GetFireInterval(byte FireModeNum)
{
    return 60.0 / GetRateOfFire();
}
public simulated function GetWeaponDebug(out array<string> DebugInfo)
{
    Super(Weapon).GetWeaponDebug(DebugInfo);
    DebugInfo[DebugInfo.Length] = "CharacterSlot:" $ CharacterSlot;
    DebugInfo[DebugInfo.Length] = "bWeaponExpanded:" $ bWeaponExpanded;
}
public function GivenTo(Pawn thisPawn, optional bool bDoNotActivate)
{
    if (SFXInventoryManager(InvManager) != None)
    {
        if (SFXInventoryManager(InvManager).GetWeaponInSlot(AttachSlot, TRUE) == None)
        {
            bInstantExpansion = TRUE;
            AssignToSlot(AttachSlot);
        }
    }
    Super(Inventory).GivenTo(thisPawn, TRUE);
}
public simulated function HandleFinishedFiring()
{
    local float ReFireDelay;
    
    if (AIController != None)
    {
        if (RemainingBurstsToFire > 0 && ShouldAutoReload() == FALSE)
        {
            RemainingBurstFireCount = GetBurstFireCount();
            RemainingBurstsToFire--;
            if (RemainingBurstsToFire > 0)
            {
                ClearTimer('RefireCheckTimer');
                ClearFlashCount();
                ClearFlashLocation();
                ReFireDelay = FMax(0.00999999978, GetRangeValueByPct(AI_BurstFireDelay, FRand()));
                SetTimer(ReFireDelay, FALSE, 'NotifyWeaponRefireDelayExpired', );
                return;
            }
        }
        AIController.StopFiring();
    }
    GotoState('Active', , , );
}
public simulated function bool HasAmmo(byte FireModeNum, optional int Amount)
{
    local int MagazineSize;
    
    if (int(FireModeNum) == 4)
    {
        return TRUE;
    }
    if (!Instigator.IsHumanControlled())
    {
        return TRUE;
    }
    if (float(Amount) < AmmoPerShot)
    {
        Amount = int(AmmoPerShot);
    }
    MagazineSize = GetMagazineSize();
    if (MagazineSize >= 0 && AmmoUsedCount + Amount > MagazineSize)
    {
        return FALSE;
    }
    return TRUE;
}
public simulated function bool HasAnyAmmo()
{
    return HasAmmo(DefaultFireMode) || HasSpareAmmo();
}
public function HolderDied()
{
    Super(Weapon).HolderDied();
    GotoState('Inactive', , , );
}
public simulated function InstantFire()
{
    local Vector StartTrace;
    local Vector EndTrace;
    local array<ImpactInfo> ImpactList;
    local int idx;
    local ImpactInfo RealImpact;
    
    if (Instigator != None && Instigator.IsLocallyControlled())
    {
        SFXInventoryManager(InvManager).bWeaponFired = TRUE;
        StartTrace = Instigator.GetWeaponStartTraceLocation();
        EndTrace = StartTrace + Vector(GetAdjustedAim(StartTrace)) * GetTraceRange();
        RealImpact = CalcWeaponFire(StartTrace, EndTrace, ImpactList);
        SetFlashLocation(RealImpact.HitLocation);
        for (idx = 0; idx < ImpactList.Length; idx++)
        {
            ProcessInstantHit(CurrentFireMode, ImpactList[idx]);
        }
    }
}
public function NotifyWeaponFired(byte FireMode)
{
    if (AIController != None)
    {
        if (RemainingBurstFireCount > 0)
        {
            RemainingBurstFireCount--;
        }
    }
    Super(Weapon).NotifyWeaponFired(FireMode);
}
public simulated function PlayFireEffects(byte FireModeNum, optional Vector HitLocation)
{
    local BioPlayerController PC;
    
    if (Instigator != None)
    {
        PC = BioPlayerController(Instigator.Controller);
        if (PC != None && PC.IsLocalPlayerController())
        {
            if (bIsZoomed)
            {
                PC.ClientPlayForceFeedbackWaveform(WeaponFireWaveForm);
                if (!bSuppressCameraShake)
                {
                    SFXPlayerCamera(PC.PlayerCamera).AddScreenShake(TightAimFiringShake);
                }
            }
            else
            {
                PC.ClientPlayForceFeedbackWaveform(WeaponFireWaveForm);
                if (!bSuppressCameraShake)
                {
                    SFXPlayerCamera(PC.PlayerCamera).AddScreenShake(FiringShake);
                }
            }
        }
    }
    PlayMuzzleFlashEffect();
    PlayOwnedFireEffects(FireModeNum, HitLocation);
}
public simulated function Projectile ProjectileFire()
{
    if (Instigator == None || Instigator.IsLocallyControlled())
    {
        StartFireTarget = SelectTarget();
        GetProjectileFirePosition(StartFireLocation, StartFireDirection);
        if (Role != ENetRole.ROLE_Authority)
        {
            ServerProjectileFire(StartFireTarget, StartFireLocation, StartFireDirection * 100.0);
        }
        return Internal_ProjectileFire();
    }
    return None;
}
public reliable server function ServerStopFire(byte FireModeNum)
{
    LogInternal(WorldInfo.TimeSeconds @ "Self:" @ Self @ "Instigator:" @ Instigator @ GetStateName() $ "::" $ GetFuncName() @ "FireModeNum =" @ FireModeNum, 'Inventory');
    if (WorldInfo == None || WorldInfo.NetMode == ENetMode.NM_Client)
    {
        return;
    }
    StopFire(FireModeNum);
}
public simulated function SetFlashLocation(Vector HitLocation)
{
    if (Instigator != None)
    {
        Instigator.SetFlashLocation(Self, CurrentFireMode, HitLocation);
    }
}
public simulated function bool ShouldRefire()
{
    local BioPawn BP;
    
    if (AIController != None)
    {
        if (!SFXAI_Core(AIController).CanFireWeaponNoLOS(Self, CurrentFireMode))
        {
            StopFire(CurrentFireMode);
            return FALSE;
        }
        if (RemainingBurstFireCount <= 0)
        {
            return FALSE;
        }
    }
    else
    {
        BP = BioPawn(Instigator);
        if (BP != None && BP.CanFireWeapon() == FALSE)
        {
            return FALSE;
        }
    }
    return Super(Weapon).ShouldRefire();
}
public simulated function StartFire(byte FireModeNum)
{
    if (int(CurrentFireMode) == int(FireModeNum))
    {
        return;
    }
    if (AIController != None)
    {
        if (HasAnyAmmo() == FALSE || AIController.CanFireWeapon(Self, FireModeNum) == FALSE)
        {
            return;
        }
        SetupWeaponFire(FireModeNum);
    }
    Super(Weapon).StartFire(FireModeNum);
}
public simulated function StopFireEffects(byte FireModeNum)
{
    if (MaxChargeTime > float(0))
    {
        SetTimer(TimeToDeactivateMuzzleFlashPSC, FALSE, 'StopMuzzleFlashEffect', );
    }
    else
    {
        StopMuzzleFlashEffect();
    }
}
public simulated function WeaponFired(byte FiringMode, bool bViaReplication, optional Vector HitLocation)
{
    if (Instigator != None)
    {
        Instigator.ShotCount++;
    }
    PlayFireEffects(FiringMode, HitLocation);
}
public simulated function AdjustLightPropertiesByDeltas()
{
    local Color NewColor;
    local float NewBrightness;
    
    NewBrightness = LC_MuzzleFlashLight.Brightness + LightDeltaBrightness;
    NewColor.R = byte(float(LC_MuzzleFlashLight.LightColor.R) + LightDeltaR);
    NewColor.G = byte(float(LC_MuzzleFlashLight.LightColor.G) + LightDeltaG);
    NewColor.B = byte(float(LC_MuzzleFlashLight.LightColor.B) + LightDeltaB);
    LC_MuzzleFlashLight.SetLightProperties(NewBrightness, NewColor);
}
public final function ApplyDefaultWeaponMods(optional bool bClearOldMods = FALSE)
{
    local SFXModule_WeaponModManager ModManager;
    local SFXEngine MyEngine;
    local array<WeaponModInfo> PossibleMods;
    local array<WeaponModInfo> ChosenMods;
    local array<Name> ChosenModClassPaths;
    local int ReplacementIndex;
    local Name WeaponClassPath;
    local int idx;
    local int Idx2;
    local bool bWeaponFound;
    local bool bModAdded;
    local WeaponModSaveRecord NewSaveRecord;
    local WeaponModInfo ModInfo;
    
    if (!bAutoModdingEnabled)
    {
        return;
    }
    ModManager = GetModule(Class'SFXModule_WeaponModManager');
    if (ModManager == None)
    {
        return;
    }
    MyEngine = SFXEngine(Class'Engine'.static.GetEngine());
    if (MyEngine == None)
    {
        return;
    }
    if (bClearOldMods == FALSE && ModManager.WeaponMods.Length > 0)
    {
        return;
    }
    else if (bClearOldMods)
    {
        ModManager.RemoveAllMods();
    }
    for (idx = 0; idx < DefaultModOptions.Length; idx++)
    {
        ModInfo.ModClass = Class'SFXWeaponMod'.static.LoadModClass(DefaultModOptions[idx]);
        if (ModInfo.ModClass != None && ModInfo.ModClass.static.IsUnlocked(ModInfo.ModLevel))
        {
            PossibleMods.AddItem(ModInfo);
        }
    }
    for (idx = 0; idx < PossibleMods.Length; idx++)
    {
        if (ChosenMods.Length < NumberOfDefaultModsToAttach)
        {
            ChosenMods.AddItem(PossibleMods[idx]);
            continue;
        }
        ReplacementIndex = -1;
        for (Idx2 = 0; Idx2 < ChosenMods.Length; Idx2++)
        {
            if (MyEngine.GetPlayerVariable(ChosenMods[Idx2].ModClass.Name) < MyEngine.GetPlayerVariable(PossibleMods[idx].ModClass.Name))
            {
                if (ReplacementIndex < 0)
                {
                    ReplacementIndex = Idx2;
                    continue;
                }
                if (MyEngine.GetPlayerVariable(ChosenMods[Idx2].ModClass.Name) <= MyEngine.GetPlayerVariable(ChosenMods[ReplacementIndex].ModClass.Name))
                {
                    ReplacementIndex = Idx2;
                }
            }
        }
        if (ReplacementIndex >= 0)
        {
            ChosenMods[ReplacementIndex] = PossibleMods[idx];
        }
    }
    for (idx = 0; idx < ChosenMods.Length; idx++)
    {
        bModAdded = ModManager.AddMod(ChosenMods[idx].ModClass, ChosenMods[idx].ModLevel) || bModAdded;
    }
    if (!bModAdded)
    {
        return;
    }
    WeaponClassPath = Name(PathName(@Class));
    for (idx = 0; idx < ChosenMods.Length; idx++)
    {
        ChosenModClassPaths.AddItem(Name(PathName(ChosenMods[idx].ModClass)));
    }
    for (idx = 0; idx < MyEngine.PlayerWeaponMods.Length; idx++)
    {
        if (MyEngine.PlayerWeaponMods[idx].WeaponClassName == WeaponClassPath)
        {
            bWeaponFound = TRUE;
            MyEngine.PlayerWeaponMods[idx].WeaponModClassNames.Length = 0;
            for (Idx2 = 0; Idx2 < ChosenModClassPaths.Length; Idx2++)
            {
                MyEngine.PlayerWeaponMods[idx].WeaponModClassNames.AddItem(ChosenModClassPaths[Idx2]);
            }
            break;
        }
    }
    if (!bWeaponFound)
    {
        NewSaveRecord.WeaponClassName = WeaponClassPath;
        for (idx = 0; idx < ChosenModClassPaths.Length; idx++)
        {
            NewSaveRecord.WeaponModClassNames.AddItem(ChosenModClassPaths[idx]);
        }
        MyEngine.PlayerWeaponMods.AddItem(NewSaveRecord);
    }
}
public simulated function AssignToSlot(EAttachSlot Slot)
{
    if (int(Slot) < 5)
    {
        CharacterSlot = Slot;
        Internal_AssignToSlot();
    }
}
// MILAN CHANGE - Mgamerz - 2026-10-16
// Attach flashlights to sockets
public final simulated function AttachFlashlight()
{
    local SkeletalMeshComponent WeaponMesh;
    local SFXInventoryManager Manager;
    local RvrClientEffectTarget CETarget;

    if (Instigator == None)
    {
        return;
    }
    Manager = SFXInventoryManager(Instigator.InvManager);
    if (Manager == None || !Manager.bFlashlightAttached || bFlashlightAttached)
    {
        return;
    }
    WeaponMesh = SkeletalMeshComponent(Mesh);
    if (Manager.AttachedFlashlight != None && (Manager.AttachedFlashlight.LightComponent == None || WeaponMesh == None || WeaponMesh.GetSocketByName('Flash_2') == None))
    {
        return;
    }
    bFlashlightAttached = TRUE;
    if (Manager.AttachedAmbientLight != None && Manager.AttachedAmbientLight.LightComponent != None)
    {
        AttachedAmbientLight = Manager.AttachedAmbientLight;
        AttachedAmbientLight.bEnabled = TRUE;
        AttachedAmbientLight.LightComponent.SetEnabled(TRUE);
    }
    if (Manager.AttachedFlashlight != None)
    {
        AttachedFlashlight = Manager.AttachedFlashlight;
        WeaponMesh.AttachComponentToSocket(AttachedFlashlight.LightComponent, 'Flash_2');
        AttachedFlashlight.bEnabled = TRUE;
        AttachedFlashlight.LightComponent.SetEnabled(TRUE);
    }
    if (Manager.AttachedFlashlightVFX != None)
    {
        CETarget.Instigator = Instigator;
        CETarget.HitLocation = Instigator.Location;
        CETarget.SpawnValue.X = float(Manager.FlashlightCachedColor.R);
        CETarget.SpawnValue.Y = float(Manager.FlashlightCachedColor.G);
        CETarget.SpawnValue.Z = float(Manager.FlashlightCachedColor.B);
        CETarget.HitBone = 'Flash_2';
        AttachedFlashlightVFXGuid = Class'RvrClientEffectManager'.static.GetClientEffectManager().StartOnTarget(Manager.AttachedFlashlightVFX, CETarget);
    }
    RestoreFlashlightToNormal();
}
// END MILAN CHANGE

public simulated function AttachMuzzleEffectsComponents(SkeletalMeshComponent SkelMesh, optional Name MuzzleSocket, optional Name CasingSocket)
{
    if (SkelMesh != None)
    {
        if (MuzzleSocket != 'None' && PSC_MuzFlashEmitter != None && PSC_MuzFlashEmitter.Owner != SkelMesh.Owner)
        {
            if (SkelMesh.GetSocketByName(MuzzleSocket) != None)
            {
                SkelMesh.AttachComponentToSocket(PSC_MuzFlashEmitter, MuzzleSocket);
                if (LC_MuzzleFlashLight != None)
                {
                    SkelMesh.AttachComponentToSocket(LC_MuzzleFlashLight, MuzzleSocket);
                }
            }
            else
            {
                SkelMesh.AttachComponent(PSC_MuzFlashEmitter, 'Root');
                if (LC_MuzzleFlashLight != None)
                {
                    SkelMesh.AttachComponent(LC_MuzzleFlashLight, 'Root');
                }
            }
            PSC_MuzFlashEmitter.SetDepthPriorityGroup(SkelMesh.DepthPriorityGroup);
            PSC_MuzFlashEmitter.SetTickGroup(3);
            HideMuzzleFlashEmitter();
            if (LC_MuzzleFlashLight != None)
            {
                LC_MuzzleFlashLight.FalloffExponent = MuzzleLightFalloffExponent;
                LC_MuzzleFlashLight.MinShadowFalloffRadius = MuzzleLightMinShadowFalloffRadius;
                LC_MuzzleFlashLight.Radius = MuzzleLightRadius;
                LC_MuzzleFlashLight.ShadowFalloffExponent = MuzzleLightShadowFalloffExponent;
                LC_MuzzleFlashLight.ShadowRadiusMultiplier = MuzzleLightShadowRadiusMultiplier;
                HideMuzzleFlashLight();
            }
        }
        if (CasingSocket != 'None')
        {
            if (PSC_ShellCasing != None && PSC_ShellCasing.Owner != SkelMesh.Owner)
            {
                if (SkelMesh.GetSocketByName(CasingSocket) != None)
                {
                    SkelMesh.AttachComponentToSocket(PSC_ShellCasing, CasingSocket);
                }
                else
                {
                    SkelMesh.AttachComponent(PSC_ShellCasing, 'Root');
                }
                PSC_ShellCasing.SetDepthPriorityGroup(SkelMesh.DepthPriorityGroup);
                PSC_ShellCasing.SetTickGroup(3);
            }
            if (PSC_ReloadVent != None && PSC_ReloadVent.Owner != SkelMesh.Owner)
            {
                if (SkelMesh.GetSocketByName(CasingSocket) != None)
                {
                    SkelMesh.AttachComponentToSocket(PSC_ReloadVent, CasingSocket);
                }
                else
                {
                    SkelMesh.AttachComponent(PSC_ReloadVent, 'Root');
                }
                PSC_ReloadVent.SetDepthPriorityGroup(SkelMesh.DepthPriorityGroup);
                PSC_ReloadVent.SetTickGroup(3);
            }
            if (PSC_OutOfAmmoEffect != None && PSC_OutOfAmmoEffect.Owner != SkelMesh.Owner)
            {
                if (SkelMesh.GetSocketByName(CasingSocket) != None)
                {
                    SkelMesh.AttachComponentToSocket(PSC_OutOfAmmoEffect, CasingSocket);
                }
                else
                {
                    SkelMesh.AttachComponent(PSC_OutOfAmmoEffect, 'Root');
                }
                PSC_OutOfAmmoEffect.SetDepthPriorityGroup(SkelMesh.DepthPriorityGroup);
                PSC_OutOfAmmoEffect.SetTickGroup(3);
            }
            HideReloadEmitters();
            if (ChargeUpPS != None && ChargeUpPS.Owner != SkelMesh.Owner && SkelMesh.GetSocketByName('Flash_1') != None)
            {
                SkelMesh.AttachComponentToSocket(ChargeUpPS, 'Flash_1');
                ChargeUpPS.SetDepthPriorityGroup(SkelMesh.DepthPriorityGroup);
                ChargeUpPS.SetTickGroup(3);
                ChargeUpPS.SetActive(FALSE);
            }
            if (ChargeDownPS != None && ChargeDownPS.Owner != SkelMesh.Owner && SkelMesh.GetSocketByName('Flash_1') != None)
            {
                SkelMesh.AttachComponentToSocket(ChargeDownPS, 'Flash_1');
                ChargeDownPS.SetDepthPriorityGroup(SkelMesh.DepthPriorityGroup);
                ChargeDownPS.SetTickGroup(3);
                ChargeDownPS.SetActive(FALSE);
            }
        }
    }
}
public simulated function BeginDummyFire(byte FiringMode, optional Actor AttachedTo);

public simulated function CalcRemoteImpactEffects(byte FireModeNum, Vector GivenHitLocation, bool bViaReplication)
{
    local Vector TraceOffset;
    local Vector AimDir;
    local Vector WeaponLoc;
    local ImpactInfo TestImpact;
    local float HitDistance;
    
    WeaponLoc = Instigator != None ? Instigator.location : location;
    if (bViaReplication && ShouldSpawnTracerFX())
    {
        HitDistance = VSize(GivenHitLocation - WeaponLoc);
        SpawnTracerEffect(GivenHitLocation, HitDistance);
    }
    AimDir = Normal(GivenHitLocation - WeaponLoc);
    TraceOffset = AimDir * 16.0;
    TestImpact = CalcWeaponFire(GivenHitLocation - TraceOffset, GivenHitLocation + TraceOffset);
    if (TestImpact.HitActor == None)
    {
        TestImpact.HitLocation = GivenHitLocation;
    }
    ProcessInstantHit(FireModeNum, TestImpact);
}
public simulated function CalculateBonus(Vector HitLocation, out DamageCalculationAlgorithm DamageCalc, optional Actor HitActor)
{
    local SFXModule_GameEffectManager GameEffectManager;
    
    DamageCalc.BaseDamage = Damage.Value;
    DamageCalc.Weapon_StealthDamageMultiplier = 0.0;
    if (StealthDamageIncrease > float(0))
    {
        DamageCalc.Weapon_StealthDamageMultiplier = StealthDamageIncrease;
    }
    if (Instigator != None)
    {
        GameEffectManager = Instigator.GetModule(Class'SFXModule_GameEffectManager');
        if (GameEffectManager != None)
        {
            DamageCalc.Weapon_PawnEffectsDamageMultiplier = GameEffectManager.WeaponPassiveDamageBonus.Value - 1.0;
        }
        else
        {
            DamageCalc.Weapon_PawnEffectsDamageMultiplier = 0.0;
        }
    }
    GameEffectManager = GetModule(Class'SFXModule_GameEffectManager');
    if (GameEffectManager != None)
    {
        DamageCalc.Weapon_WeaponEffectsDamageMultiplier = GameEffectManager.WeaponModDamageBonus.Value - 1.0 + (GameEffectManager.WeaponMatchConsumableDamageBonus.Value - 1.0);
    }
    else
    {
        DamageCalc.Weapon_WeaponEffectsDamageMultiplier = 0.0;
    }
    if (bSuperDamage)
    {
        DamageCalc.Global_DamageTakenMultiplier = 100.0;
    }
}
public simulated function CalculateEffectLightDeltas(float StartBrightness, float EndBrightness, Color StartColor, Color EndColor, float DeltaTime)
{
    local float Factor;
    
    if (DeltaTime <= float(0))
    {
        return;
    }
    Factor = LightStepSize / DeltaTime;
    LightDeltaBrightness = (EndBrightness - StartBrightness) * Factor;
    LightDeltaR = float((int(EndColor.R) - int(StartColor.R))) * Factor;
    LightDeltaG = float((int(EndColor.G) - int(StartColor.G))) * Factor;
    LightDeltaB = float((int(EndColor.B) - int(StartColor.B))) * Factor;
}
public simulated function bool CanFire()
{
    return TRUE;
}
public simulated function bool CanReload()
{
    local BioPawn Pawn;
    
    Pawn = BioPawn(Instigator);
    if (Pawn != None && Pawn.CanReload() == FALSE)
    {
        return FALSE;
    }
    return bWeaponCanBeReloaded && AmmoUsedCount > 0 && HasSpareAmmo();
}
public simulated function CharacterSlotUpdated()
{
    local BioPawn Pawn;
    
    Pawn = BioPawn(Instigator);
    if (int(CharacterSlot) < 5)
    {
        if (Pawn != None)
        {
            if (Pawn.Weapon != Self)
            {
                AttachWeaponTo(Pawn.Mesh, Pawn.AttachSlots[int(CharacterSlot)]);
            }
            ClearTimer('CharacterSlotUpdated');
        }
        else
        {
            SetTimer(0.100000001, FALSE, 'CharacterSlotUpdated', );
        }
    }
}
public simulated function CheckTimerFireOnce()
{
    StopFireEffects(FireOnceFiringMode);
}
public event simulated function CleanUpDummyFire()
{
    ClearTimer('DummyFireTimerFunction');
    WeaponStoppedFiring(DefaultFireMode);
    if (DummyFireInstigatorSet)
    {
        Instigator = PreDummyFireInstigator;
        PreDummyFireInstigator = None;
        DummyFireInstigatorSet = FALSE;
    }
    DummyFireParent = None;
    bDummyFireWeapon = FALSE;
    DummyFireTargetLoc = vect(0.0, 0.0, 0.0);
    DummyFireTargetActor = None;
    DummyFireInaccuracy = 0.0;
    DummyFireShotsRemaining = 0.0;
}
public final function ClearFizzleCount()
{
    FizzleCount = 0;
}
public simulated function ClearWeaponModMaterialParameters()
{
    local MaterialInstance MatInstance;
    
    if (Mesh != None && Mesh.Materials.Length > 0)
    {
        MatInstance = MaterialInstance(Mesh.Materials[0]);
        if (MatInstance != None)
        {
            MatInstance.SetVectorParameterValue('Grip_Colour', WeaponModBaseGripColour);
            MatInstance.SetVectorParameterValue('Body_Colour', WeaponModBaseBodyColour);
            MatInstance.SetVectorParameterValue('Light_Colour', WeaponModBaseEmissiveColour);
        }
    }
}
public simulated function ClientDoImpact(BioPawn InImpactedPawn)
{
    if (InImpactedPawn.ReplicatedWeaponImpactInfo.CustomActionReactionType != 0 && InImpactedPawn.CurrentCustomAction != InImpactedPawn.ReplicatedWeaponImpactInfo.CustomActionReactionType)
    {
        InImpactedPawn.ClientPlayAnimatedReaction(InImpactedPawn.ReplicatedWeaponImpactInfo.CustomActionReactionType);
    }
}
public simulated function Collapse()
{
    bWeaponExpanded = FALSE;
    if (!bInstantExpansion)
    {
    }
}
public simulated function DeferredPostBeginPlay()
{
    if (Instigator == None || Instigator.PlayerReplicationInfo == None && Instigator.IsPlayerOwned())
    {
        if (!bDummyFireWeapon)
        {
            SetTimer(0.100000001, FALSE, 'DeferredPostBeginPlay', );
        }
    }
    else
    {
        InitializeWeapon();
    }
}
public simulated function DelayedRestoreFlashlightToNormal()
{
    if (FlashlightStopFireDelay > float(0))
    {
        SetTimer(FlashlightStopFireDelay, FALSE, 'RestoreFlashlightToNormal', );
    }
    else
    {
        RestoreFlashlightToNormal();
    }
}

public final simulated function DetachFlashlight()
{
    local SkeletalMeshComponent WeaponMesh;
    local SFXInventoryManager Manager;

    if (!bFlashlightAttached)
    {
        return;
    }
    bFlashlightAttached = FALSE;
    if (AttachedAmbientLight != None)
    {
        AttachedAmbientLight.bEnabled = FALSE;
        if (AttachedAmbientLight.LightComponent != None)
        {
            AttachedAmbientLight.LightComponent.SetEnabled(FALSE);
        }
        AttachedAmbientLight = None;
    }
    if (AttachedFlashlight != None)
    {
        AttachedFlashlight.bEnabled = FALSE;
        if (AttachedFlashlight.LightComponent != None)
        {
            AttachedFlashlight.LightComponent.SetEnabled(FALSE);
            WeaponMesh = SkeletalMeshComponent(Mesh);
            if (WeaponMesh != None)
            {
                WeaponMesh.DetachComponent(AttachedFlashlight.LightComponent);
            }
        }
        AttachedFlashlight = None;
    }
    if (Instigator != None)
    {
        Manager = SFXInventoryManager(Instigator.InvManager);
    }
    if (Manager != None && Manager.AttachedFlashlightVFX != None)
    {
        Class'RvrClientEffectManager'.static.GetClientEffectManager().@Stop(Manager.AttachedFlashlightVFX, AttachedFlashlightVFXGuid, TRUE, Owner);
    }
}

public simulated function DoAReload();

public simulated function DoReload()
{
    local int Amount;
    
    OnWeaponReload(Self);
    if (bInfiniteAmmo || Instigator.IsHumanControlled() == FALSE)
    {
        AmmoUsedCount = 0;
    }
    else if (GetMaxSpareAmmo() > 0 && float(GetCurrentSpareAmmo()) > 0.0)
    {
        Amount = GetAmmoRestoredPerReload();
        AmmoUsedCount -= Amount;
        CurrentSpareAmmo -= Amount;
    }
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
public simulated function DrawDebugShot(Vector StartLocation, Vector EndLocation)
{
    local BioPawn Pawn;
    
    Pawn = BioPawn(Instigator);
    if (Pawn != None && Pawn.bWeaponDebug_Accuracy)
    {
        FlushPersistentDebugLines();
        DrawDebugLine(StartLocation, EndLocation, 255, 255, 255, TRUE);
    }
}
public simulated function DummyFireNumTimes(int nNumTimes, Vector vHitLocation, optional Actor AttachedTo, optional float fInaccuracy, optional Actor TargetActor)
{
    BeginDummyFire(DefaultFireMode, AttachedTo);
    DummyFire(DefaultFireMode, vHitLocation, AttachedTo, fInaccuracy, TargetActor);
    ClearTimer('DummyFireTimerFunction');
    DummyFireShotsRemaining = float(nNumTimes - 1);
    SetTimer(GetFireInterval(DefaultFireMode), TRUE, 'DummyFireTimerFunction', );
}
public simulated function DummyFireTimerFunction()
{
    if (DummyFireShotsRemaining == float(0))
    {
        CleanUpDummyFire();
        return;
    }
    else
    {
        WeaponStoppedFiring(DefaultFireMode);
    }
    DummyFire(DefaultFireMode, DummyFireTargetLoc, DummyFireParent, DummyFireInaccuracy, DummyFireTargetActor);
    DummyFireShotsRemaining = DummyFireShotsRemaining - float(1);
}
public simulated function EquipFinished();

public simulated function EquipNearFinished();

public simulated function EquipTimedOut();

public simulated function Expand()
{
    bWeaponExpanded = TRUE;
    if (!bInstantExpansion)
    {
    }
}
public static final function Class<SFXWeapon> FindWeaponClass(string WeaponClassName)
{
    local string WeaponFullName;
    local bool bValidName;
    
    WeaponFullName = WeaponClassName;
    bValidName = Class'SFXEngine'.static.IsSeekFreeObjectSupported(WeaponFullName);
    if (!bValidName)
    {
        WeaponFullName = "SFXGameContent." $ WeaponClassName;
        bValidName = Class'SFXEngine'.static.IsSeekFreeObjectSupported(WeaponFullName);
    }
    if (bValidName)
    {
        return Class<SFXWeapon>(Class'SFXEngine'.static.GetSeekFreeObject(WeaponFullName, Class'Class'));
    }
    else
    {
        return None;
    }
}
public function float GetAIAimDelay()
{
    return RandRange(AI_AimDelay.X, AI_AimDelay.Y);
}
public simulated function int GetAmmoCountInMagazine()
{
    return GetMagazineSize() - AmmoUsedCount;
}
public simulated function int GetAmmoRestoredPerReload()
{
    return int(float(GetCurrentSpareAmmo()) - FMax(float(GetCurrentSpareAmmo() - AmmoUsedCount), 0.0));
}
public function int GetBurstFireCount()
{
    local int AmmoRemaining;
    local int BurstCount;
    
    AmmoRemaining = Max(0, GetMagazineSize() - AmmoUsedCount);
    BurstCount = Min(AmmoRemaining, int(GetRangeValueByPct(AI_BurstFireCount, FRand())));
    if (BurstCount == 0)
    {
        BurstCount = AmmoRemaining;
    }
    return BurstCount;
}
public function int GetBurstsToFire()
{
    local SFXAI_Core AI;
    
    AI = SFXAI_Core(AIController);
    if (AI != None && AI.DesiredBurstsToFire > 0)
    {
        return AI.DesiredBurstsToFire;
    }
    return -1;
}
public simulated function int GetCurrentSpareAmmo()
{
    return CurrentSpareAmmo;
}
public final simulated function int GetCurrentTotalAmmo()
{
    return GetCurrentSpareAmmo() + GetAmmoCountInMagazine();
}
public simulated function Class<SFXDamageType> GetDamageType(optional byte FiringMode)
{
    if (int(FiringMode) == 0)
    {
        return Class<SFXDamageType>(InstantHitDamageTypes[int(DefaultFireMode)]);
    }
    return Class<SFXDamageType>(InstantHitDamageTypes[int(FiringMode)]);
}
public delegate function float GetDamageVocProbabilityMod();

public simulated function DecalComponent GetDecalData(PhysicalMaterial PhysMat, out float FadeTime)
{
    local SFXPhysicalMaterialProperty PhysMatProp;
    
    if (PhysMat != None)
    {
        PhysMatProp = SFXPhysicalMaterialProperty(PhysMat.PhysicalMaterialProperty);
        if (PhysMatProp != None)
        {
            if (PhysMatProp.PhysicalMaterialDecals != None)
            {
                return GetWeaponSpecificDecalData(PhysMatProp.PhysicalMaterialDecals, FadeTime);
            }
        }
    }
    return None;
}
public simulated function float GetFireModeBaseDamage()
{
    local float BaseDamage;
    
    BaseDamage = Damage.Value;
    if (Instigator != None && SFXPawn_Henchman(Instigator) != None)
    {
        BaseDamage *= DamageHench;
    }
    return BaseDamage;
}
public static function string GetGeneralDescription()
{
    return Class'SFXGame'.static.GetSimpleString(default.GeneralDescription);
}
public static simulated function ParticleSystem GetImpactEffect(PhysicalMaterial PhysMat)
{
    local SFXPhysicalMaterialProperty PhysMatProp;
    
    if (PhysMat != None)
    {
        PhysMatProp = SFXPhysicalMaterialProperty(PhysMat.PhysicalMaterialProperty);
        if (PhysMatProp != None)
        {
            if (PhysMatProp.PhysicalMaterialImpactEffects != None)
            {
                return GetWeaponSpecificImpactEffect(PhysMatProp.PhysicalMaterialImpactEffects);
            }
        }
    }
    return None;
}
public simulated function WwiseEvent GetImpactSound(PhysicalMaterial PhysMat)
{
    local SFXPhysicalMaterialProperty PhysMatProp;
    
    if (PhysMat != None)
    {
        PhysMatProp = SFXPhysicalMaterialProperty(PhysMat.PhysicalMaterialProperty);
        if (PhysMatProp != None)
        {
            if (PhysMatProp.PhysicalMaterialImpactSounds != None)
            {
                return GetWeaponSpecificImpactSound(PhysMatProp.PhysicalMaterialImpactSounds);
            }
        }
    }
    return None;
}
public simulated function float GetInitialDummyFireDelay();

public simulated function float GetLazyFireInterval(byte FireModeNum)
{
    return FMax(0.00999999978, 60.0 / LazyRateOfFire - 60.0 / GetRateOfFire());
}
public final simulated function int GetMagazineSize()
{
    return int(MagSize.Value);
}
public final simulated function int GetMaxSpareAmmo(optional bool bIgnoreCurrentMag)
{
    if (!bIgnoreCurrentMag)
    {
        return int(MaxSpareAmmo.Value + float(AmmoUsedCount));
    }
    return int(MaxSpareAmmo.Value);
}
public final simulated function int GetMaxTotalAmmo()
{
    return GetMaxSpareAmmo(TRUE) + GetMagazineSize();
}
public simulated function bool GetModifiedFOV(out float FOV)
{
    if (bIsZoomed)
    {
        FOV = GetZoomFOV();
        return TRUE;
    }
    return FALSE;
}
public simulated function float GetPlayerAimError(float Accuracy)
{
    local Vector2D AimErrorRange;
    
    AimErrorRange = GetWeaponAimErrorRange();
    return Lerp(AimErrorRange.X, AimErrorRange.Y, Accuracy);
}
public simulated function GetProjectileFirePosition(out Vector out_ProjLoc, out Vector out_ProjDir)
{
    local Vector StartTrace;
    local Vector EndTrace;
    local ImpactInfo TestImpact;
    
    if (Instigator.IsHumanControlled() == FALSE)
    {
        out_ProjLoc = GetMuzzleLoc();
        out_ProjDir = Vector(GetAdjustedAim(out_ProjLoc));
    }
    else
    {
        StartTrace = Instigator.GetWeaponStartTraceLocation();
        out_ProjDir = Vector(GetAdjustedAim(StartTrace));
        out_ProjLoc = GetPhysicalFireStartLoc(out_ProjDir);
        if (StartTrace != out_ProjLoc)
        {
            EndTrace = StartTrace + out_ProjDir * GetTraceRange();
            TestImpact = CalcWeaponFire(StartTrace, EndTrace);
            if (!FastTrace(TestImpact.HitLocation, out_ProjLoc, , ))
            {
                out_ProjLoc = StartTrace;
            }
            out_ProjDir = Normal(TestImpact.HitLocation - out_ProjLoc);
        }
    }
}
public simulated function float GetRateOfFire()
{
    local float fRateOfFire;
    
    fRateOfFire = RateOfFire.Value;
    if (Instigator != None && Instigator.IsHumanControlled() == FALSE)
    {
        fRateOfFire *= RateOfFireAI;
    }
    return fRateOfFire > 0.0 ? fRateOfFire : 60.0;
}
public event simulated function float GetReactionChanceModifier()
{
    return ReactionChanceModifier.Value;
}
public static function string GetShortDescription()
{
    return Class'SFXGame'.static.GetSimpleString(default.ShortDescription);
}
public static function EAttachSlot GetStoreQualification()
{
    return EAttachSlot.EASlot_RightShoulder;
}
public simulated function Vector2D GetWeaponAimErrorRange()
{
    local Vector2D AimErrorRange;
    local BioPawn oPawn;
    
    if (bIsZoomed)
    {
        AimErrorRange.X = MinZoomAimError.Value;
        AimErrorRange.Y = MaxZoomAimError.Value;
    }
    else
    {
        AimErrorRange.X = MinAimError.Value;
        AimErrorRange.Y = MaxAimError.Value;
    }
    oPawn = BioPawn(Instigator);
    if (oPawn != None && !oPawn.IsInCover() && SFXWeapon_Shotgun_Base(oPawn.Weapon) == None && !oPawn.bInjuredPawn)
    {
        AimErrorRange.X *= 1.5;
        AimErrorRange.Y *= 1.5;
    }
    return AimErrorRange;
}
public simulated function EWeaponFireType GetWeaponFireType()
{
    return WeaponFireTypes[int(DefaultFireMode)];
}
public simulated function float GetWeaponRecoil()
{
    local float fRecoil;
    local SFXPRI OwnerPRI;
    local BioPlayerController PC;
    local BioPawn oPawn;
    
    PC = BioPlayerController(Instigator.Controller);
    oPawn = BioPawn(PC.Pawn);
    if (oPawn.IsInCover())
    {
        return Recoil.Value;
    }
    if (bIsZoomed)
    {
        fRecoil = ZoomRecoil.Value * 1.5;
    }
    else
    {
        fRecoil = Recoil.Value * 1.5;
    }
    OwnerPRI = SFXPRI(Instigator.Controller.PlayerReplicationInfo);
    if (OwnerPRI != None)
    {
        fRecoil *= Instigator.GetModule(Class'SFXModule_GameEffectManager').RecoilBonus;
    }
    if (!WorldInfo.GRI.IsMultiplayerGame())
    {
        if (int(PC.ProfileSettings.GetDifficultyConfigOption()) == 0 || int(PC.ProfileSettings.GetDifficultyConfigOption()) == 1)
        {
            fRecoil *= 0.25;
        }
    }
    return fRecoil;
}
public simulated function DecalComponent GetWeaponSpecificDecalData(SFXPhysicalMaterialDecals DecalEffects, out float FadeTime);

public static simulated function ParticleSystem GetWeaponSpecificImpactEffect(SFXPhysicalMaterialImpactEffects ImpactEffects);

public simulated function WwiseEvent GetWeaponSpecificImpactSound(SFXPhysicalMaterialImpactSounds ImpactSounds);

public simulated function float GetZoomFOV()
{
    return AimModes[CurrentAimMode].ZoomFOV;
}
public final function GiveWeaponCodex()
{
    local BioWorldInfo WI;
    local BioGlobalVariableTable VarTable;
    
    WI = BioWorldInfo(WorldInfo);
    if (WI == None)
    {
        return;
    }
    VarTable = WI.GetGlobalVariables();
    if (VarTable == None)
    {
        return;
    }
    VarTable.SetBool(CodexPlotID, TRUE);
}
public simulated function bool HasSpareAmmo()
{
    if (Instigator.IsHumanControlled() == FALSE)
    {
        return TRUE;
    }
    return bInfiniteAmmo || float(GetCurrentSpareAmmo()) > 0.0;
}
public simulated function HearNoiseTimer();

public simulated function HideMuzzleFlashEmitter()
{
    if (PSC_MuzFlashEmitter != None)
    {
        PSC_MuzFlashEmitter.SetHidden(TRUE);
    }
}
public simulated function HideMuzzleFlashLight()
{
    if (LC_MuzzleFlashLight != None)
    {
        LC_MuzzleFlashLight.SetEnabled(FALSE);
    }
}
public simulated function HideReloadEmitters()
{
    if (PSC_ShellCasing != None)
    {
        PSC_ShellCasing.SetHidden(TRUE);
        PSC_ShellCasing.SetActive(FALSE);
    }
    if (PSC_ReloadVent != None)
    {
        PSC_ReloadVent.SetHidden(TRUE);
        PSC_ReloadVent.SetActive(FALSE);
    }
    if (PSC_OutOfAmmoEffect != None)
    {
        PSC_OutOfAmmoEffect.SetHidden(TRUE);
        PSC_OutOfAmmoEffect.SetActive(FALSE);
    }
}
public final function IncrementFizzleCount()
{
    if (int(++FizzleCount) == 0)
    {
        FizzleCount = 1;
    }
}
public simulated function InitDefaultDecalProperties()
{
    DefaultDecalProperties = new (Self) Class'DecalComponent';
    DefaultDecalProperties.Width = 9.0;
    DefaultDecalProperties.Height = 9.0;
    DefaultDecalProperties.FarPlane = 5.0;
    DefaultDecalProperties.NearPlane = -5.0;
    DefaultDecalProperties.bNoClip = FALSE;
    DefaultDecalProperties.SetDecalMaterial(DefaultDecalMaterial);
}
public simulated function InitializeAmmo()
{
    AddAmmo(int(MaxSpareAmmo.Value));
}
public simulated function InitializeWeapon()
{
    local MaterialInstanceConstant MIC;
    local SFXPawn_Player pPawn;
    local SkeletalMeshComponent oSkeletalMesh;
    
    ScaleWeapon();
    InitializeAmmo();
    InitDefaultDecalProperties();
    pPawn = SFXPawn_Player(Owner);
    if (pPawn != None)
    {
        pPawn.UpdateWeaponEncumbrance();
    }
    CoverLeanPositions.Length = 0;
    if (Instigator != None && Instigator.IsHumanControlled() == FALSE)
    {
        DefaultFireMode = FireModes.FireMode_FullAuto;
    }
    if (Mesh != None && Mesh.Materials.Length == 0)
    {
        MIC = Mesh.CreateAndSetMaterialInstanceConstant(0);
        if (MIC != None)
        {
            MIC.GetVectorParameterValue('Grip_Colour', WeaponModBaseGripColour);
            MIC.GetVectorParameterValue('Body_Colour', WeaponModBaseBodyColour);
            MIC.GetVectorParameterValue('Light_Colour', WeaponModBaseEmissiveColour);
        }
    }
    RemainingBurstFireCount = -1;
    RemainingBurstsToFire = -1;
    oSkeletalMesh = SkeletalMeshComponent(Mesh);
    if (oSkeletalMesh != None && Instigator != None)
    {
        if (AmmoPowerPSCO != None)
        {
            oSkeletalMesh.AttachComponentToSocket(AmmoPowerPSCO, 'Modal');
            AmmoPowerPSCO.SetDepthPriorityGroup(oSkeletalMesh.DepthPriorityGroup);
            SFXGRI(Instigator.WorldInfo.GRI).ObjectPool.ApplyLODLevel(AmmoPowerPSCO, location);
        }
        if (AmmoPowerIconPSCO != None)
        {
            oSkeletalMesh.AttachComponentToSocket(AmmoPowerIconPSCO, 'Ammo');
            AmmoPowerIconPSCO.SetDepthPriorityGroup(oSkeletalMesh.DepthPriorityGroup);
            SFXGRI(Instigator.WorldInfo.GRI).ObjectPool.ApplyLODLevel(AmmoPowerIconPSCO, location);
        }
    }
    bIsInitialized = TRUE;
}
public simulated function Internal_AssignToSlot()
{
    local BioPawn Pawn;
    
    Pawn = BioPawn(Instigator);
    if (int(CharacterSlot) < 5)
    {
        if (Pawn != None)
        {
            AttachWeaponTo(Pawn.Mesh, Pawn.AttachSlots[int(CharacterSlot)]);
            ClearTimer('Internal_AssignToSlot');
        }
        else
        {
            SetTimer(0.100000001, FALSE, 'Internal_AssignToSlot', );
        }
    }
}
public simulated function Projectile Internal_ProjectileFire()
{
    local SFXProjectile SpawnedProjectile;
    local Class<SFXProjectile> ProjectileClass;
    local int i;
    
    ProjectileClass = Class<SFXProjectile>(GetProjectileClass());
    if (ProjectileClass == None && Instigator != None && Instigator.IsLocallyControlled() == FALSE)
    {
        for (i = 0; i < WeaponProjectiles.Length; i++)
        {
            if (Class<SFXProjectile>(WeaponProjectiles[i]) != None)
            {
                ProjectileClass = Class<SFXProjectile>(WeaponProjectiles[i]);
                break;
            }
        }
    }
    IncrementFlashCount();
    if (Instigator == None && Role != ENetRole.ROLE_Authority || Instigator != None && Instigator.Role == ENetRole.ROLE_SimulatedProxy || Instigator != None && Instigator.Role == ENetRole.ROLE_AutonomousProxy && ProjectileClass.default.bClientPredictProjectile == FALSE)
    {
        return None;
    }
    SpawnedProjectile = SFXGRI(WorldInfo.GRI).ObjectPool.GetProjectile(ProjectileClass, Self, Self.Instigator, StartFireLocation, Rotator(StartFireDirection));
    if (SpawnedProjectile != None && !SpawnedProjectile.bDeleteMe)
    {
        if (Instigator != None && Instigator.Role == ENetRole.ROLE_AutonomousProxy)
        {
            SpawnedProjectile.SetPrediction(TRUE, FALSE);
            PredictedProjectiles.AddItem(SpawnedProjectile);
        }
        SpawnedProjectile.Init(StartFireDirection);
        SpawnedProjectile.bSuppressAudio = bSuppressAudio;
    }
    return SpawnedProjectile;
}
public simulated function bool IsAnimTypePistol()
{
    return AnimType == WeaponAnimType.WeaponAnimType_AutoPistol || AnimType == WeaponAnimType.WeaponAnimType_Pistol;
}
public simulated function bool IsAnimTypeShotgun()
{
    return AnimType == WeaponAnimType.WeaponAnimType_Shotgun || AnimType == WeaponAnimType.WeaponAnimType_AutoShotgun;
}
public simulated function bool IsAnimTypeSniper()
{
    return AnimType == WeaponAnimType.WeaponAnimType_Sniper;
}
public final simulated function bool IsCameraWithinRadius(Vector TestLocation, float Radius)
{
    local PlayerController PC;
    local Vector CamLoc;
    local Rotator CamRot;
    
    foreach LocalPlayerControllers(Class'PlayerController', PC)
    {
        PC.GetPlayerViewPoint(CamLoc, CamRot);
        if (VSize(TestLocation - CamLoc) <= Radius)
        {
            return TRUE;
        }
    }
    return FALSE;
}
public final simulated function bool IsChargingWeapon()
{
    return MaxChargeTime > float(0) && SFXPawn_Player(Instigator) != None;
}
public simulated function bool IsClientReadyToInitialize()
{
    return Mesh.Materials.Length > 0;
}
public simulated function bool IsMuzzleFlashRelevant()
{
    if (Instigator == None || Instigator.IsHumanControlled())
    {
        return TRUE;
    }
    if (WorldInfo.bAggressiveLOD && WorldInfo.TimeSeconds - Instigator.LastRenderTime > 1.0)
    {
        return FALSE;
    }
    if (WorldInfo.TimeSeconds - Instigator.LastRenderTime > 2.0 && IsCameraWithinRadius(Instigator.location, 256.0) == FALSE)
    {
        return FALSE;
    }
    return TRUE;
}
public static function bool IsWeaponAlreadyAwarded(Class<SFXWeapon> WeaponClass)
{
    local BioWorldInfo WI;
    local bool bNewGamePlus;
    local BioGlobalVariableTable VarTable;
    
    if (WeaponClass == None)
    {
        return FALSE;
    }
    WI = BioWorldInfo(Class'WorldInfo'.static.GetWorldInfo());
    if (WI == None)
    {
        return FALSE;
    }
    VarTable = WI.GetGlobalVariables();
    if (VarTable == None)
    {
        return FALSE;
    }
    if (WI.CheckConditional(default.NewGamePlusID) == TRUE)
    {
        bNewGamePlus = TRUE;
    }
    if (!bNewGamePlus)
    {
        if (VarTable.GetBool(WeaponClass.default.WeaponAcquiredID) == TRUE)
        {
            return TRUE;
        }
    }
    else if (VarTable.GetBool(WeaponClass.default.WeaponAcquiredID_NGP) == TRUE)
    {
        return TRUE;
    }
    return FALSE;
}
public static function bool IsWeaponUnlocked(Class<SFXWeapon> WeaponClass)
{
    local SFXEngine Eng;
    
    if (WeaponClass == None)
    {
        return FALSE;
    }
    if (WeaponClass.default.bDoesNotUnlock)
    {
        return TRUE;
    }
    Eng = SFXEngine(Class'Engine'.static.GetEngine());
    if (Eng == None)
    {
        return FALSE;
    }
    if (Eng.GetPlayerVariable(Name(PathName(WeaponClass))) > 0)
    {
        return TRUE;
    }
    return FALSE;
}
public static final function Class<SFXWeapon> LoadWeaponClass(string WeaponClassName)
{
    return Class<SFXWeapon>(Class'SFXEngine'.static.GetSeekFreeObject(WeaponClassName, Class'Class'));
}
public function NotifyUnpossessed();

public function NotifyWeaponRefireDelayExpired()
{
    if (StillFiring(CurrentFireMode) && AIController.CanFireWeapon(Self, CurrentFireMode))
    {
        FireAmmunition();
        TimeWeaponFiring(CurrentFireMode);
    }
    else
    {
        AIController.StopFiring();
        GotoState('Active', , , );
    }
}
public final simulated function OnClientProjectileSpawned(SFXProjectile NewProjectile)
{
    local int i;
    local SFXProjectile oProjIter;
    
    for (i = PredictedProjectiles.Length - 1; i >= 0; i--)
    {
        oProjIter = PredictedProjectiles[i];
        if (oProjIter == None || oProjIter.bActive == FALSE || oProjIter.IsShuttingDown() == TRUE)
        {
            PredictedProjectiles.Remove(i, 1);
        }
    }
    if (NewProjectile.Role == ENetRole.ROLE_SimulatedProxy && NewProjectile.bClientPredictProjectile == TRUE)
    {
        if (PredictedProjectiles.Length > 0)
        {
            oProjIter = PredictedProjectiles[0];
            oProjIter.SetPredictionTarget(NewProjectile);
            NewProjectile.SetPrediction(TRUE, TRUE);
            PredictedProjectiles.Remove(0, 1);
        }
    }
}
public delegate function OnWeaponEquip(SFXWeapon Weapon);

public delegate function OnWeaponImpact(SFXWeapon Weapon, ImpactInfo Impact);

public delegate function OnWeaponReload(SFXWeapon Weapon);

public delegate function OnWeaponUnequip(SFXWeapon Weapon);

public simulated function bool OutOfAmmo()
{
    return GetCurrentTotalAmmo() == 0;
}
public simulated function PlayFireEffectsOnce(optional Vector HitLocation)
{
    PlayFireEffects(DefaultFireMode, HitLocation);
    FireOnceFiringMode = DefaultFireMode;
    SetTimer(GetFireInterval(DefaultFireMode), FALSE, 'CheckTimerFireOnce', );
}
public simulated function PlayMuzzleFlashEffect()
{
    if (!bSuppressMuzzleFlash && IsMuzzleFlashRelevant())
    {
        PlayMuzzleFlashLightEffect();
    }
    if (bPlayingMuzzleFlashEffect && bLoopingFlashEmitter && int(CurrentFireMode) == 2)
    {
        return;
    }
    if (!bSuppressMuzzleFlash && IsMuzzleFlashRelevant())
    {
        if (PSC_MuzFlashEmitter != None)
        {
            if (bPlayingMuzzleFlashEffect)
            {
                PSC_MuzFlashEmitter.SetActive(FALSE);
            }
            ClearTimer('HideMuzzleFlashEmitter');
            PSC_MuzFlashEmitter.SetHidden(FALSE);
            PSC_MuzFlashEmitter.SetActive(TRUE);
        }
        bPlayingMuzzleFlashEffect = TRUE;
    }
}
public simulated function PlayMuzzleFlashLightEffect()
{
    if (LC_MuzzleFlashLight == None || MuzzleLightLifetime == float(0))
    {
        return;
    }
    LC_MuzzleFlashLight.SetEnabled(TRUE);
    SetTimer(MuzzleLightLifetime, FALSE, 'HideMuzzleFlashLight', );
    LightCurrentTime = 0.0;
    if (MuzzleLightChangeOverLifeKeys.Length == 0 || MuzzleLightChangeOverLifeKeys[0].Time != float(0))
    {
        LC_MuzzleFlashLight.SetLightProperties(MuzzleLightBrightness, MuzzleLightColor);
        if (MuzzleLightChangeOverLifeKeys.Length > 0)
        {
            LightKeyIndex = -1;
            CalculateEffectLightDeltas(MuzzleLightBrightness, MuzzleLightChangeOverLifeKeys[0].Brightness, MuzzleLightColor, MuzzleLightChangeOverLifeKeys[0].Color, MuzzleLightChangeOverLifeKeys[0].Time);
            SetTimer(LightStepSize, TRUE, 'StepMuzzleLight', );
        }
    }
    else if (MuzzleLightChangeOverLifeKeys.Length > 1)
    {
        LC_MuzzleFlashLight.SetLightProperties(MuzzleLightChangeOverLifeKeys[0].Brightness, MuzzleLightChangeOverLifeKeys[0].Color);
        LightKeyIndex = 0;
        CalculateEffectLightDeltas(MuzzleLightChangeOverLifeKeys[0].Brightness, MuzzleLightChangeOverLifeKeys[1].Brightness, MuzzleLightChangeOverLifeKeys[0].Color, MuzzleLightChangeOverLifeKeys[1].Color, MuzzleLightChangeOverLifeKeys[1].Time);
        SetTimer(LightStepSize, TRUE, 'StepMuzzleLight', );
    }
}
public simulated function PlayNoAmmoEffects()
{
    PlayNoAmmoFireSound();
    if (bHolsteringWeapon == FALSE && bWeaponPutDown == FALSE)
    {
        PSC_OutOfAmmoEffect.SetHidden(FALSE);
        PSC_OutOfAmmoEffect.SetActive(TRUE);
        if (Mesh != None && int(PSC_OutOfAmmoEffect.DepthPriorityGroup) != int(Mesh.DepthPriorityGroup))
        {
            PSC_OutOfAmmoEffect.SetDepthPriorityGroup(Mesh.DepthPriorityGroup);
        }
        if (SFXPawn_Player(Instigator) != None && SFXPawn_Player(Instigator).Controller.IsLocalPlayerController())
        {
            BioPlayerController(Instigator.Controller).ClientPlayForceFeedbackWaveform(OutOfAmmoRumble);
        }
        SetTimer(5.0, FALSE, 'HideReloadEmitters', );
        RestoreFlashlightToNormal();
    }
    if (NoAmmoFireSoundDelay > 0.0)
    {
        SetTimer(NoAmmoFireSoundDelay, TRUE, 'PlayNoAmmoFireSound', );
    }
}
public simulated function PlayNoAmmoFireSound()
{
    WeaponPlayWwiseEvent(FireNoAmmoSound);
}
public simulated function PlayOwnedFireEffects(byte FireModeNum, Vector HitLocation)
{
    if ((bForceSpawnTracer || ShouldSpawnTracerFX()) && IsZero(HitLocation) == FALSE)
    {
        if (Instigator != None)
        {
            SpawnTracerEffect(HitLocation, VSize(HitLocation - Instigator.location));
        }
        else
        {
            SpawnTracerEffect(HitLocation, VSize(HitLocation - GetMuzzleLoc()));
        }
    }
    if (WeaponPowerFireSound != None)
    {
        WeaponPlayWwiseEvent(WeaponPowerFireSound, 1.0);
    }
    if (Instigator == None)
    {
        WeaponPlayWwiseEvent(FireSound, WeaponLoudness, , 'NoiseType_WeaponFire');
    }
    else if (Instigator.IsHumanControlled() && Instigator.IsLocallyControlled())
    {
        SetWeaponRecoil(GetWeaponRecoil() * 182.044449);
        if (!bPlaySoundOncePerBurst)
        {
            if (PlayerFireSound != None)
            {
                WeaponPlayWwiseEvent(PlayerFireSound, WeaponLoudness, , 'NoiseType_WeaponFire');
            }
            else
            {
                WeaponPlayWwiseEvent(FireSound, WeaponLoudness, , 'NoiseType_WeaponFire');
            }
        }
    }
    else if (SFXAI_Core(Instigator.Controller) == None && bPlaySoundOncePerBurst == FALSE || bAIPlaySoundOncePerBurst == FALSE)
    {
        WeaponPlayWwiseEvent(FireSound, WeaponLoudness, , 'NoiseType_WeaponFire');
    }
}
public simulated function PlayReloadEject()
{
    if (PSC_ShellCasing != None)
    {
        PSC_ShellCasing.SetHidden(FALSE);
        PSC_ShellCasing.SetActive(TRUE);
        if (Mesh != None && int(PSC_ShellCasing.DepthPriorityGroup) != int(Mesh.DepthPriorityGroup))
        {
            PSC_ShellCasing.SetDepthPriorityGroup(Mesh.DepthPriorityGroup);
        }
    }
    if (PSC_ReloadVent != None)
    {
        PSC_ReloadVent.SetHidden(FALSE);
        PSC_ReloadVent.SetActive(TRUE);
        if (Mesh != None && int(PSC_ReloadVent.DepthPriorityGroup) != int(Mesh.DepthPriorityGroup))
        {
            PSC_ReloadVent.SetDepthPriorityGroup(Mesh.DepthPriorityGroup);
        }
    }
    if (SFXPawn_Player(Instigator) != None && SFXPawn_Player(Instigator).Controller != None && SFXPawn_Player(Instigator).Controller.IsLocalPlayerController())
    {
        WeaponPlayWwiseEvent(WeaponSteamReloadSound, 0.0);
        BioPlayerController(Instigator.Controller).ClientPlayForceFeedbackWaveform(EjectRumble);
    }
    SetTimer(5.0, FALSE, 'HideReloadEmitters', );
}
private final simulated function ProcessInstantHitNearMiss(Vector StartTrace, Vector HitLocation)
{
    local AIController CheckController;
    local Vector LineDir;
    local float MaxNearMissDistance;
    local SFXAI_Core AI;
    local Pawn FireTarget;
    
    if (Instigator != None)
    {
        LineDir = Normal(HitLocation - StartTrace);
        if (Instigator.IsHumanControlled())
        {
            MaxNearMissDistance = FMax(200.0, 35.0);
            foreach BioWorldInfo(WorldInfo).AllControllersCloseToSegment(Class'AIController', CheckController, StartTrace, HitLocation, MaxNearMissDistance)
            {
                CheckController.CheckNearMiss(Instigator, Self, StartTrace, LineDir, HitLocation);
            }
        }
        else
        {
            AI = SFXAI_Core(Instigator.Controller);
            if (AI != None)
            {
                FireTarget = Pawn(AI.FireTarget);
                if (FireTarget != None)
                {
                    if (FireTarget.Controller != None)
                    {
                        FireTarget.Controller.CheckNearMiss(Instigator, Self, StartTrace, LineDir, HitLocation);
                    }
                }
            }
        }
    }
}
public event simulated function Projectile ProjectileFireSimple(optional float AimErrorDeg)
{
    local Vector RealStartLoc;
    local Vector AimDir;
    local Projectile SpawnedProjectile;
    local Rotator AimRot;
    local float AimErrorUnr;
    
    if (WorldInfo.NetMode != ENetMode.NM_Client)
    {
        RealStartLoc = GetPhysicalFireStartLoc();
        AimRot = Rotator(DummyFireTargetLoc - RealStartLoc);
        if (AimErrorDeg != 0.0)
        {
            AimErrorUnr = AimErrorDeg * 182.044006;
            AimRot.Pitch += int(AimErrorUnr * (0.5 - FRand()));
            AimRot.Yaw += int(AimErrorUnr * (0.5 - FRand()));
        }
        AimDir = Vector(AimRot);
        SpawnedProjectile = Spawn(GetProjectileClass(), Self, , RealStartLoc);
        if (SpawnedProjectile != None && !SpawnedProjectile.bDeleteMe)
        {
            SpawnedProjectile.Init(AimDir);
            SFXProjectile(SpawnedProjectile).bSuppressAudio = bSuppressAudio;
        }
        return SpawnedProjectile;
    }
    return None;
}
public simulated function ReloadNearFinished();

public function ReplicateImpact(BioPawn ImpactedPawn, optional SFXProjectile InProjectile, optional float fDelay)
{
    local BioCustomAction CurrentCA;
    
    ImpactedPawn.ReplicatedWeaponImpactInfo.TriggerCounter++;
    ImpactedPawn.ReplicatedWeaponImpactInfo.oWeapon = Self;
    ImpactedPawn.ReplicatedWeaponImpactInfo.oProjectile = InProjectile;
    ImpactedPawn.ReplicatedWeaponImpactInfo.Delay = byte(fDelay * 10.0);
    if (ImpactedPawn.GetCurrentCustomAction(CurrentCA) && CurrentCA != None && CurrentCA.IsA('SFXCustomAction_DamageReaction'))
    {
        ImpactedPawn.ReplicatedWeaponImpactInfo.CustomActionReactionType = ImpactedPawn.CurrentCustomAction;
    }
    else
    {
        ImpactedPawn.ReplicatedWeaponImpactInfo.CustomActionReactionType = 0;
    }
}
public simulated function ResetAmmoOnHolster()
{
    if (bInfiniteAmmo)
    {
        AmmoUsedCount = 0;
    }
}
public simulated function RestoreFlashlightToNormal()
{
    local SpotLightComponent oSpotLightComp;
    local SFXInventoryManager Manager;
    
    Manager = SFXInventoryManager(Instigator.InvManager);
    if (Manager == None)
    {
        return;
    }
    if (AttachedAmbientLight != None && AttachedAmbientLight.LightComponent != None)
    {
        AttachedAmbientLight.LightComponent.SetLightProperties(Manager.AmbientLightCachedBrightness, Manager.AmbientLightCachedColor);
    }
    if (AttachedFlashlight != None && AttachedFlashlight.LightComponent != None)
    {
        oSpotLightComp = SpotLightComponent(AttachedFlashlight.LightComponent);
        if (oSpotLightComp != None)
        {
            oSpotLightComp.OuterConeAngle = Manager.FlashlightCachedRadius;
        }
        AttachedFlashlight.LightComponent.SetLightProperties(Manager.FlashlightCachedBrightness, Manager.FlashlightCachedColor);
    }
}
public simulated function ScaleWeapon()
{
    local int MaxLevelForCalc;
    local SFXEngine Engine;
    
    WeaponLevel = 0.0;
    if (Instigator != None && Instigator.PlayerReplicationInfo != None && SFXPawn_Henchman(Instigator) == None)
    {
        WeaponLevel = float(SFXPRI(Instigator.PlayerReplicationInfo).GetWeaponLevel(Name(PathName(@Class))) - 1);
    }
    else
    {
        Engine = Class'SFXEngine'.static.GetSFXEngine();
        if (Engine != None)
        {
            WeaponLevel = float(Engine.GetPlayerVariable(Name(PathName(@Class))) - 1);
        }
    }
    WeaponLevel = float(Max(int(WeaponLevel), 0));
    MaxLevelForCalc = int(MaxLevel - float(1));
    Damage.Level = int(WeaponLevel);
    Damage.MaxLevel = MaxLevelForCalc;
    Damage.StaticBonus = 1.0;
    MinAimError.Level = int(WeaponLevel);
    MinAimError.MaxLevel = MaxLevelForCalc;
    MaxAimError.Level = int(WeaponLevel);
    MaxAimError.MaxLevel = MaxLevelForCalc;
    MinZoomAimError.Level = int(WeaponLevel);
    MinZoomAimError.MaxLevel = MaxLevelForCalc;
    MaxZoomAimError.Level = int(WeaponLevel);
    MaxZoomAimError.MaxLevel = MaxLevelForCalc;
    RateOfFire.Level = int(WeaponLevel);
    RateOfFire.MaxLevel = MaxLevelForCalc;
    Recoil.Level = int(WeaponLevel);
    Recoil.MaxLevel = MaxLevelForCalc;
    ZoomRecoil.Level = int(WeaponLevel);
    ZoomRecoil.MaxLevel = MaxLevelForCalc;
    MagSize.Level = int(WeaponLevel);
    MagSize.MaxLevel = MaxLevelForCalc;
    MaxSpareAmmo.Level = int(WeaponLevel);
    MaxSpareAmmo.MaxLevel = MaxLevelForCalc;
    MinCrosshairRange.Level = int(WeaponLevel);
    MinCrosshairRange.MaxLevel = MaxLevelForCalc;
    MaxCrosshairRange.Level = int(WeaponLevel);
    MaxCrosshairRange.MaxLevel = MaxLevelForCalc;
    MinZoomCrosshairRange.Level = int(WeaponLevel);
    MinZoomCrosshairRange.MaxLevel = MaxLevelForCalc;
    MaxZoomCrosshairRange.Level = int(WeaponLevel);
    MaxZoomCrosshairRange.MaxLevel = MaxLevelForCalc;
    ReloadDuration.Level = int(WeaponLevel);
    ReloadDuration.MaxLevel = MaxLevelForCalc;
    HeadshotDamageMultiplier.Level = int(WeaponLevel);
    HeadshotDamageMultiplier.MaxLevel = MaxLevelForCalc;
    AccFirePenalty.Level = int(WeaponLevel);
    AccFirePenalty.MaxLevel = MaxLevelForCalc;
    AccFireInterpSpeed.Level = int(WeaponLevel);
    AccFireInterpSpeed.MaxLevel = MaxLevelForCalc;
    ZoomAccFirePenalty.Level = int(WeaponLevel);
    ZoomAccFirePenalty.MaxLevel = MaxLevelForCalc;
    ZoomAccFireInterpSpeed.Level = int(WeaponLevel);
    ZoomAccFireInterpSpeed.MaxLevel = MaxLevelForCalc;
    AI_AccCone_Min.Level = int(WeaponLevel);
    AI_AccCone_Min.MaxLevel = MaxLevelForCalc;
    AI_AccCone_Max.Level = int(WeaponLevel);
    AI_AccCone_Max.MaxLevel = MaxLevelForCalc;
    ImpactForceModifier.Level = int(WeaponLevel);
    ImpactForceModifier.MaxLevel = MaxLevelForCalc;
    ReactionChanceModifier.Level = int(WeaponLevel);
    ReactionChanceModifier.MaxLevel = MaxLevelForCalc;
    MeleeDamageModifier.Level = int(WeaponLevel);
    MeleeDamageModifier.MaxLevel = MaxLevelForCalc;
    NoAmmoUseChance.Level = int(WeaponLevel);
    NoAmmoUseChance.MaxLevel = MaxLevelForCalc;
    EncumbranceWeight.Level = int(WeaponLevel);
    EncumbranceWeight.MaxLevel = MaxLevelForCalc;
    PenetrationBonus.Level = int(WeaponLevel);
    PenetrationBonus.MaxLevel = MaxLevelForCalc;
    ArmorPiercing.Level = int(WeaponLevel);
    ArmorPiercing.MaxLevel = MaxLevelForCalc;
    PenetrationDamageBonus.Level = int(WeaponLevel);
    PenetrationDamageBonus.MaxLevel = MaxLevelForCalc;
    Class'SFXGame'.static.ReCalculate(Damage);
    Class'SFXGame'.static.ReCalculate(MinAimError);
    Class'SFXGame'.static.ReCalculate(MaxAimError);
    Class'SFXGame'.static.ReCalculate(MinZoomAimError);
    Class'SFXGame'.static.ReCalculate(MaxZoomAimError);
    Class'SFXGame'.static.ReCalculate(RateOfFire);
    Class'SFXGame'.static.ReCalculate(Recoil);
    Class'SFXGame'.static.ReCalculate(ZoomRecoil);
    Class'SFXGame'.static.ReCalculate(MagSize);
    Class'SFXGame'.static.ReCalculate(MaxSpareAmmo);
    Class'SFXGame'.static.ReCalculate(MinCrosshairRange);
    Class'SFXGame'.static.ReCalculate(MaxCrosshairRange);
    Class'SFXGame'.static.ReCalculate(MinZoomCrosshairRange);
    Class'SFXGame'.static.ReCalculate(MaxZoomCrosshairRange);
    Class'SFXGame'.static.ReCalculate(ReloadDuration);
    Class'SFXGame'.static.ReCalculate(HeadshotDamageMultiplier);
    Class'SFXGame'.static.ReCalculate(AccFirePenalty);
    Class'SFXGame'.static.ReCalculate(AccFireInterpSpeed);
    Class'SFXGame'.static.ReCalculate(ZoomAccFirePenalty);
    Class'SFXGame'.static.ReCalculate(ZoomAccFireInterpSpeed);
    Class'SFXGame'.static.ReCalculate(AI_AccCone_Min);
    Class'SFXGame'.static.ReCalculate(AI_AccCone_Max);
    Class'SFXGame'.static.ReCalculate(ImpactForceModifier);
    Class'SFXGame'.static.ReCalculate(ReactionChanceModifier);
    Class'SFXGame'.static.ReCalculate(MeleeDamageModifier);
    Class'SFXGame'.static.ReCalculate(ZoomDamageShakeModifier);
    Class'SFXGame'.static.ReCalculate(NoAmmoUseChance);
    Class'SFXGame'.static.ReCalculate(EncumbranceWeight);
    Class'SFXGame'.static.ReCalculate(PenetrationBonus);
    Class'SFXGame'.static.ReCalculate(ArmorPiercing);
    Class'SFXGame'.static.ReCalculate(PenetrationDamageBonus);
    if (Recoil.Value < float(0))
    {
        Recoil.Value = 0.0;
    }
    if (ZoomRecoil.Value < float(0))
    {
        ZoomRecoil.Value = 0.0;
    }
}
public simulated function Actor SelectTarget()
{
    if (BioAiController(AIController) != None)
    {
        return BioAiController(AIController).FireTarget;
    }
    else if (Instigator != None && Instigator.Controller != None && Instigator.Controller.IsLocalPlayerController() == TRUE)
    {
        return BioPlayerController(Instigator.Controller).m_oPlayerSelection.m_oCurrentSelectionTarget;
    }
    return None;
}
public reliable server function ServerCancelReload()
{
    CancelReload();
}
public reliable server function ServerFireChargedShot(float SentChargeAmount);

public reliable server function ServerProcessInstantHit(byte FiringMode, ImpactInfo Impact, int HitArmourIdx, bool bSuppressedAudio, optional int NumHits)
{
    local SFXModule_Armour ArmMod;
    local Vector AimDir;
    local Vector StartLoc;
    local Box HitBox;
    local Vector BoxExtent;
    local Vector BoxCenter;
    local bool bShouldFire;
    local bool bAudioWasSuppressed;
    local float fDist;
    local float fAngle;
    local PlayerController PC;
    
    if (Impact.HitActor == None && Impact.HitInfo.HitComponent != None)
    {
        Impact.HitActor = Impact.HitInfo.HitComponent.Owner;
    }
    if (HitArmourIdx != -1 && Impact.HitActor != None && Impact.HitInfo.HitComponent == None)
    {
        ArmMod = Impact.HitActor.GetModule(Class'SFXModule_Armour');
        if (ArmMod != None && ArmMod.ActiveArmour[HitArmourIdx].AttachInstance != None)
        {
            Impact.HitInfo.HitComponent = ArmMod.ActiveArmour[HitArmourIdx].AttachInstance;
        }
    }
    if (Instigator != None)
    {
        PC = PlayerController(Instigator.Controller);
        if (PC.PlayerCamera != None)
        {
            AimDir = Vector(Instigator.GetBaseAimRotation());
        }
        else
        {
            AimDir = Vector(PC.Rotation);
        }
        StartLoc = Instigator.GetWeaponStartTraceLocation();
        fDist = VSizeSq(Impact.HitLocation - StartLoc);
        fAngle = AimDir Dot Normal(Impact.HitLocation - StartLoc);
        if (Impact.HitActor == None || Impact.HitActor.bStatic)
        {
            bShouldFire = TRUE;
        }
        else if (fDist < ClientSideHitMaxDistReallyClose || fAngle > ClientSideHitMaxAngle || fDist < ClientSideHitMaxDistClose && fAngle > ClientSideHitMaxAngleClose)
        {
            Impact.HitActor.GetComponentsBoundingBox(HitBox);
            BoxExtent = 0.5 * (HitBox.Max - HitBox.Min);
            BoxExtent *= ClientSideHitLeeway;
            BoxCenter = (HitBox.Min + HitBox.Max) * 0.5;
            if (Abs(Impact.HitLocation.Z - BoxCenter.Z) < BoxExtent.Z && Abs(Impact.HitLocation.X - BoxCenter.X) < BoxExtent.X && Abs(Impact.HitLocation.Y - BoxCenter.Y) < BoxExtent.Y)
            {
                bShouldFire = TRUE;
            }
        }
        if (bShouldFire)
        {
            SFXGRI(WorldInfo.GRI).PreAsyncWorker.ProcessInstantHit(Self, FiringMode, Impact, bSuppressedAudio, NumHits);
            SFXInventoryManager(InvManager).bWeaponFired = TRUE;
            bAudioWasSuppressed = bSuppressAudio;
            bSuppressAudio = bSuppressedAudio;
            SetFlashLocation(Impact.HitLocation);
            bSuppressAudio = bAudioWasSuppressed;
        }
    }
}
public reliable server function ServerProjectileFire(Actor Target, Vector ProjLocation, Vector ProjDirection)
{
    StartFireTarget = Target;
    StartFireLocation = ProjLocation;
    StartFireDirection = ProjDirection * 0.00999999978;
    Internal_ProjectileFire();
}
public reliable server function ServerSetIsZoomed(bool bState)
{
    bIsZoomed = bState;
}
public simulated function SetAmmoPowerHologramEnabled(bool bEnabled, optional bool bForceEnabled)
{
    if (bWeaponAndEffectsHidden)
    {
        bEnabled = FALSE;
    }
    if (AmmoPowerPSCO != None && AmmoPowerPSCO.Template != None)
    {
        if (bEnabled)
        {
            if (bForceEnabled || !AmmoPowerPSCO.bIsActive && !AmmoPowerPSCO.bWasCompleted)
            {
                AmmoPowerPSCO.SetActive(TRUE);
                AmmoPowerPSCO.SetHidden(FALSE);
            }
        }
        else
        {
            AmmoPowerPSCO.SetActive(FALSE);
            AmmoPowerPSCO.SetHidden(TRUE);
        }
    }
    if (AmmoPowerIconPSCO != None && AmmoPowerIconPSCO.Template != None)
    {
        AmmoPowerIconPSCO.SetActive(bEnabled);
        AmmoPowerIconPSCO.SetHidden(!bEnabled);
    }
    if (PSC_PermanentMuzzle != None)
    {
        PSC_PermanentMuzzle.SetActive(bEnabled);
    }
}
public simulated function SetAmmoPowerHologramTemplates(ParticleSystem Template, ParticleSystem IconTemplate)
{
    if (AmmoPowerPSCO != None && Template != None && AmmoPowerPSCO.Template != Template)
    {
        AmmoPowerPSCO.SetTemplate(Template);
    }
    if (AmmoPowerIconPSCO != None && IconTemplate != None && AmmoPowerIconPSCO.Template != IconTemplate)
    {
        AmmoPowerIconPSCO.SetTemplate(IconTemplate);
    }
}
public simulated function SetFlashlightFireMode()
{
    local SpotLightComponent oSpotLightComp;
    local SFXInventoryManager Manager;
    
    Manager = SFXInventoryManager(Instigator.InvManager);
    if (Manager == None)
    {
        return;
    }
    if (AttachedAmbientLight != None && AttachedAmbientLight.LightComponent != None)
    {
        AttachedAmbientLight.LightComponent.SetLightProperties(Manager.AmbientLightCachedBrightness * (1.0 + FlashlightFireBrightnessIncrease), FlashlightFireColor);
    }
    if (AttachedFlashlight != None && AttachedFlashlight.LightComponent != None)
    {
        oSpotLightComp = SpotLightComponent(AttachedFlashlight.LightComponent);
        if (oSpotLightComp != None)
        {
            oSpotLightComp.OuterConeAngle = Manager.FlashlightCachedRadius * (1.0 + FlashlightFireRadiusIncrease);
        }
        AttachedFlashlight.LightComponent.SetLightProperties(Manager.FlashlightCachedBrightness * (1.0 + FlashlightFireBrightnessIncrease), FlashlightFireColor);
    }
}
public simulated function SetRTPCPlayerPosition(EPlayerPositionRTPC NewPlayerPosition)
{
    RTPCPlayerPosition = NewPlayerPosition;
    Class'WwiseAudioComponent'.static.SetGlobalRTPCFromScript(RTPCName, float(RTPCPlayerPosition));
}
public function SetupWeaponFire(byte FireModeNum)
{
    RemainingBurstFireCount = -1;
    RemainingBurstsToFire = -1;
    if (int(FireModeNum) != 0 && int(FireModeNum) != 4)
    {
        RemainingBurstFireCount = GetBurstFireCount();
        RemainingBurstsToFire = GetBurstsToFire();
    }
}
// MILAN CHANGE
// Restore weapon visibilty so it doesn't disappear if interrupted
public final simulated function RestoreStowedWeaponVisibility()
{
    local BioPawn Pawn;
    local BioCustomAction CurrentAction;
    local SFXGRI GRI;

    GRI = SFXGRI(WorldInfo.GRI);
    Pawn = BioPawn(Instigator);
    if (GRI == None || !GRI.bIsMultiplayerCharacter || Pawn == None || !bWeaponAndEffectsHidden)
    {
        return;
    }
    Pawn.GetCurrentCustomAction(CurrentAction);
    if (CurrentAction != None && CurrentAction.bHideWeapon)
    {
        SetWeaponHidden(FALSE);
    }
}
public final simulated function SetWeaponHidden(bool bWeaponHidden)
{
    local SFXModule_WeaponModManager Manager;
    local SFXHeavyWeapon HeavyWeapon;

    HeavyWeapon = SFXHeavyWeapon(Self);
    if (HeavyWeapon != None && HeavyWeapon.bHiddenVariant)
    {
        // Keep custom-action hiding separate so drawing only removes stowed concealment.
        HeavyWeapon.bHiddenVariantRequestedHidden = bWeaponHidden;
        bWeaponHidden = bWeaponHidden || HeavyWeapon.bHiddenVariantStowed;
    }

    bWeaponAndEffectsHidden = bWeaponHidden;
    if (Mesh != None)
    {
        Mesh.SetHidden(bWeaponHidden);
    }
    Manager = GetModule(Class'SFXModule_WeaponModManager');
    if (Manager != None)
    {
        Manager.SetWeaponModHidden(bWeaponHidden);
    }
    SetAmmoPowerHologramEnabled(!bWeaponHidden);
}
public simulated function SetWeaponModBodyColour(int ModLevel)
{
    local LinearColor gripColour;
    local MaterialInterface MatInt;
    local MaterialInstance MatInstance;
    local int nIndex;
    
    if (WeaponModBodyColours.Length > 0 && ModLevel > 0)
    {
        if (ModLevel > WeaponModBodyColours.Length)
        {
            nIndex = WeaponModBodyColours.Length - 1;
        }
        else
        {
            nIndex = ModLevel - 1;
        }
        gripColour = WeaponModBodyColours[nIndex];
        foreach Mesh.Materials(MatInt, )
        {
            MatInstance = MaterialInstance(MatInt);
            if (MatInstance != None)
            {
                MatInstance.SetVectorParameterValue('Body_Colour', gripColour);
            }
        }
    }
}
public simulated function SetWeaponModEmissiveValue(int ModLevel)
{
    local LinearColor emissiveColour;
    local MaterialInterface MatInt;
    local MaterialInstance MatInstance;
    local int nIndex;
    
    if (WeaponModEmissiveColours.Length > 0 && ModLevel > 0)
    {
        if (ModLevel > WeaponModEmissiveColours.Length)
        {
            nIndex = WeaponModEmissiveColours.Length - 1;
        }
        else
        {
            nIndex = ModLevel - 1;
        }
        emissiveColour = WeaponModEmissiveColours[nIndex];
        foreach Mesh.Materials(MatInt, )
        {
            MatInstance = MaterialInstance(MatInt);
            if (MatInstance != None)
            {
                MatInstance.SetVectorParameterValue('Light_Colour', emissiveColour);
            }
        }
    }
}
public simulated function SetWeaponModGripColour(int ModLevel)
{
    local LinearColor gripColour;
    local MaterialInterface MatInt;
    local MaterialInstance MatInstance;
    local int nIndex;
    
    if (WeaponModGripColours.Length > 0 && ModLevel > 0)
    {
        if (ModLevel > WeaponModGripColours.Length)
        {
            nIndex = WeaponModGripColours.Length - 1;
        }
        else
        {
            nIndex = ModLevel - 1;
        }
        gripColour = WeaponModGripColours[nIndex];
        foreach Mesh.Materials(MatInt, )
        {
            MatInstance = MaterialInstance(MatInt);
            if (MatInstance != None)
            {
                MatInstance.SetVectorParameterValue('Grip_Colour', gripColour);
            }
        }
    }
}
public simulated function SetWeaponRecoil(float PitchRecoil)
{
    local SFXInventoryManager Inv;
    
    Inv = SFXInventoryManager(InvManager);
    if (Inv != None)
    {
        Inv.SetWeaponRecoil(PitchRecoil);
    }
}
public simulated function bool ShouldAutoReload()
{
    return CanReload() && GetMagazineSize() > 0 && AmmoUsedCount >= GetMagazineSize();
}
public simulated function bool ShouldSpawnTracerFX()
{
    return !bSuppressTracers;
}
public simulated function ShutOffAllEmitters()
{
    local BioPlayerController PC;
    
    if (Role == ENetRole.ROLE_Authority)
    {
        RepChargeEffect = ChargeEffectType.CET_ShutOffAll;
    }
    if (ChargeUpPS != None)
    {
        ChargeUpPS.SetActive(FALSE);
    }
    PC = BioPlayerController(Instigator.Controller);
    if (PC != None && PC.IsLocalPlayerController())
    {
        SFXPlayerCamera(PC.PlayerCamera).ScreenShakeModifier.RemoveScreenShake(ChargeCameraShake.ShakeName);
    }
    if (bNeedPowerDownSound)
    {
        WeaponPlayWwiseEvent(PowerDownSound);
        bNeedPowerDownSound = FALSE;
    }
    RestoreFlashlightToNormal();
}
public simulated function SpawnADecal(ImpactInfo Impact)
{
    local PhysicalMaterial ParentPhysMaterial;
    local DecalComponent ImpactDecal;
    local float FadeTime;
    
    if (bSuppressImpactFX || bSuppressDecal)
    {
        return;
    }
    if (Impact.HitInfo.PhysMaterial != None)
    {
        ImpactDecal = GetDecalData(Impact.HitInfo.PhysMaterial, FadeTime);
        ParentPhysMaterial = Impact.HitInfo.PhysMaterial.Parent;
    }
    else if (Impact.HitInfo.Material != None)
    {
        ImpactDecal = GetDecalData(Impact.HitInfo.Material.PhysMaterial, FadeTime);
        if (Impact.HitInfo.Material.PhysMaterial != None)
        {
            ParentPhysMaterial = Impact.HitInfo.Material.PhysMaterial.Parent;
        }
    }
    while (ImpactDecal == None && ParentPhysMaterial != None)
    {
        ImpactDecal = GetDecalData(ParentPhysMaterial, FadeTime);
        ParentPhysMaterial = ParentPhysMaterial.Parent;
    }
    if (ImpactDecal == None)
    {
        ImpactDecal = DefaultDecalProperties;
    }
    if (ImpactDecal != None)
    {
        SFXGRI(WorldInfo.GRI).DuringAsyncWorker.SpawnImpactDecal(Instigator, ImpactDecal.GetDecalMaterial(), Impact, ImpactDecal.Width, ImpactDecal.Height, ImpactDecal.FarPlane, ImpactDecal.bNoClip, FadeTime, FadingParameters);
    }
}
public simulated function SpawnImpactEffects(ImpactInfo Impact)
{
    local PhysicalMaterial ParentPhysMaterial;
    local ParticleSystem ImpactEffect;
    
    if (bSuppressImpactFX)
    {
        return;
    }
    if (Impact.HitInfo.PhysMaterial != None)
    {
        ImpactEffect = GetImpactEffect(Impact.HitInfo.PhysMaterial);
        ParentPhysMaterial = Impact.HitInfo.PhysMaterial.Parent;
    }
    else if (Impact.HitInfo.Material != None)
    {
        ImpactEffect = GetImpactEffect(Impact.HitInfo.Material.PhysMaterial);
        if (Impact.HitInfo.Material.PhysMaterial != None)
        {
            ParentPhysMaterial = Impact.HitInfo.Material.PhysMaterial.Parent;
        }
    }
    while (ImpactEffect == None && ParentPhysMaterial != None)
    {
        ImpactEffect = GetImpactEffect(ParentPhysMaterial);
        ParentPhysMaterial = ParentPhysMaterial.Parent;
    }
    if (ImpactEffect == None)
    {
        ImpactEffect = PS_DefaultMaterialImpactEffect;
    }
    SFXGRI(WorldInfo.GRI).DuringAsyncWorker.SpawnImpactEffect(Instigator, PS_DefaultImpactEffect, Impact, ImpactScale);
    SFXGRI(WorldInfo.GRI).DuringAsyncWorker.SpawnImpactEffect(Instigator, ImpactEffect, Impact, ImpactScale);
}
public simulated function SpawnImpactSounds(ImpactInfo Impact)
{
    local PhysicalMaterial ParentPhysMaterial;
    local WwiseEvent ImpactSound;
    
    if (bSuppressImpactFX)
    {
        return;
    }
    if (Impact.HitInfo.PhysMaterial != None)
    {
        ImpactSound = GetImpactSound(Impact.HitInfo.PhysMaterial);
        ParentPhysMaterial = Impact.HitInfo.PhysMaterial.Parent;
    }
    else if (Impact.HitInfo.Material != None)
    {
        ImpactSound = GetImpactSound(Impact.HitInfo.Material.PhysMaterial);
        if (Impact.HitInfo.Material.PhysMaterial != None)
        {
            ParentPhysMaterial = Impact.HitInfo.Material.PhysMaterial.Parent;
        }
    }
    while (ImpactSound == None && ParentPhysMaterial != None)
    {
        ImpactSound = GetImpactSound(ParentPhysMaterial);
        ParentPhysMaterial = ParentPhysMaterial.Parent;
    }
    if (ImpactSound == None)
    {
        ImpactSound = DefaultImpactSound;
    }
    WeaponPlayWwiseEvent(ImpactSound, 1.0, Impact.HitLocation);
}
public simulated function SpawnTracerEffect(Vector HitLocation, float HitDistance)
{
    if (HitDistance > ShowTracerDistance)
    {
        if (Instigator != None && Instigator.Controller != None && Instigator.Controller.IsLocalPlayerController() && TracerInfo.PlayerPSTemplate != None)
        {
            SFXGRI(WorldInfo.GRI).DuringAsyncWorker.SpawnTracer(Instigator, TracerInfo.StaticMesh, TracerInfo.PlayerPSTemplate, TracerInfo.Scale3D, TracerInfo.Speed, TracerSpawnOffset, GetMuzzleLoc(), HitLocation);
        }
        else
        {
            SFXGRI(WorldInfo.GRI).DuringAsyncWorker.SpawnTracer(Instigator, TracerInfo.StaticMesh, TracerInfo.StandardPSTemplate, TracerInfo.Scale3D, TracerInfo.Speed, TracerSpawnOffset, GetMuzzleLoc(), HitLocation);
        }
    }
}
public simulated function StartChargeEffects()
{
    local BioPlayerController PC;
    
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
        if (Instigator != None && Instigator.IsHumanControlled())
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
public simulated function StartFullChargeRumble()
{
    local BioPlayerController PC;
    
    PC = BioPlayerController(Instigator.Controller);
    if (PC != None && PC.IsLocalPlayerController() && bFired == FALSE)
    {
        PC.HintSystem.HintEvent('StartWeaponCharge', Self.@Class.Name);
    }
}
public simulated function StepMuzzleLight()
{
    local ChangeOverLifeKey NextKey;
    
    NextKey = MuzzleLightChangeOverLifeKeys[LightKeyIndex + 1];
    LightCurrentTime += LightStepSize;
    if (LightCurrentTime >= NextKey.Time)
    {
        LightKeyIndex++;
        LC_MuzzleFlashLight.SetLightProperties(NextKey.Brightness, NextKey.Color);
        if (MuzzleLightChangeOverLifeKeys.Length > LightKeyIndex + 1)
        {
            CalculateEffectLightDeltas(NextKey.Brightness, MuzzleLightChangeOverLifeKeys[LightKeyIndex + 1].Brightness, NextKey.Color, MuzzleLightChangeOverLifeKeys[LightKeyIndex + 1].Color, MuzzleLightChangeOverLifeKeys[LightKeyIndex + 1].Time - NextKey.Time);
        }
        else
        {
            ClearTimer('StepMuzzleLight');
        }
        return;
    }
    AdjustLightPropertiesByDeltas();
}
public simulated function StopChargeEffects()
{
    local BioPlayerController PC;
    
    if (ChargeUpPS != None)
    {
        ChargeUpPS.SetActive(FALSE);
    }
    if (ChargeDownPS != None)
    {
        ChargeDownPS.SetActive(TRUE);
    }
    if (Role == ENetRole.ROLE_Authority)
    {
        RepChargeEffect = ChargeEffectType.CET_StopCharge;
    }
    PC = BioPlayerController(Instigator.Controller);
    if (PC != None && PC.IsLocalPlayerController())
    {
        SFXPlayerCamera(BioPlayerController(Instigator.Controller).PlayerCamera).ScreenShakeModifier.RemoveScreenShake(ChargeCameraShake.ShakeName);
    }
    if (Instigator != None && Instigator.IsHumanControlled())
    {
        WeaponPlayWwiseEvent(PowerDownSound);
    }
    else
    {
        WeaponPlayWwiseEvent(NPCPowerDownSound);
    }
    bNeedPowerDownSound = FALSE;
    RestoreFlashlightToNormal();
}
public simulated function StopMuzzleFlashEffect()
{
    if (PSC_MuzFlashEmitter != None)
    {
        bPlayingMuzzleFlashEffect = FALSE;
        PSC_MuzFlashEmitter.SetActive(FALSE);
        if (!IsTimerActive('HideMuzzleFlashEmitter'))
        {
            SetTimer(TimeToHideMuzzleFlashPSC, FALSE, 'HideMuzzleFlashEmitter', );
        }
    }
    if (bPermanentMuzzle)
    {
        PlaySound(OffMuzzleSound);
    }
}
public final simulated function SubscribeToImpactNotifications(delegate<OnWeaponImpact> Callback)
{
    if (ImpactSubscriptions.Find(Callback) == -1)
    {
        ImpactSubscriptions.AddItem(Callback);
    }
}
public simulated function TryReload(optional bool bDisplayHint = TRUE)
{
    local BioPlayerController PC;
    
    if (CanReload())
    {
        if (bDisplayHint)
        {
            PC = BioPlayerController(Instigator.Controller);
            if (PC != None && PC.IsLocalPlayerController())
            {
                PC.HintSystem.HintEvent('ManualReload', @Class.Name);
            }
        }
        StartFire(4);
    }
}
public simulated function UnEquipFinished();

public simulated function UnEquipTimedOut();

public final simulated function UnsubscribeFromImpactNotifications(delegate<OnWeaponImpact> Callback)
{
    ImpactSubscriptions.RemoveItem(Callback);
}
public static function bool Upgrade(SFXPawn_Player Player, Class<SFXWeapon> WeaponClass, optional bool bNoNotification = FALSE, optional bool bIsMultiplayer = FALSE, optional bool bDoesNotCountasNGPFound, optional bool bUnlockOnly)
{
    local SFXEngine Eng;
    local int CurrentRank;
    local bool bUpgraded;
    local BioGlobalVariableTable VarTable;
    local BioWorldInfo BioWI;
    local stringref NotificationTitle;
    local BioPlayerController PC;
    
    if (WeaponClass == None || Player == None)
    {
        return FALSE;
    }
    BioWI = BioWorldInfo(Player.WorldInfo);
    if (BioWI == None)
    {
        return FALSE;
    }
    if (!WeaponClass.default.bPlayerUsable || WeaponClass.default.bDoesNotUnlock)
    {
        return FALSE;
    }
    Eng = Class'SFXEngine'.static.GetSFXEngine();
    if (Eng == None)
    {
        return FALSE;
    }
    if (Eng.GetPlayerVariable(Name(PathName(WeaponClass))) <= 0)
    {
        Eng.SetPlayerVariable(Name(PathName(WeaponClass)), 1);
        bUpgraded = TRUE;
        NotificationTitle = WeaponClass.default.WeaponUnlockMessage;
    }
    else if (!bUnlockOnly)
    {
        CurrentRank = Eng.GetPlayerVariable(Name(PathName(WeaponClass)));
        if (float(CurrentRank) < default.MaxLevel)
        {
            Eng.SetPlayerVariable(Name(PathName(WeaponClass)), CurrentRank + 1);
            bUpgraded = TRUE;
            NotificationTitle = WeaponClass.default.WeaponUpgradeMessage;
        }
    }
    if (bIsMultiplayer == FALSE && BioWI != None)
    {
        VarTable = BioWI.GetGlobalVariables();
        if (VarTable != None)
        {
            if (default.WeaponAcquiredID != 0)
            {
                VarTable.SetBool(default.WeaponAcquiredID, TRUE, FALSE);
            }
            if (bDoesNotCountasNGPFound == FALSE && BioWI.CheckConditional(1690) == TRUE && default.WeaponAcquiredID_NGP != 0)
            {
                VarTable.SetBool(default.WeaponAcquiredID_NGP, TRUE, FALSE);
            }
        }
    }
    PC = BioPlayerController(Player.Controller);
    if (PC != None && CurrentRank > 1)
    {
        PC.SetAccomplishmentProgression('WeaponLevel', CurrentRank + 1);
    }
    if (bNoNotification == FALSE && bUpgraded == TRUE)
    {
        BioHintSystem(BioPlayerController(Player.Controller).HintSystem).AddNotification_Weapon(GetPrettyName(CurrentRank + 1), Class'SFXGame'.static.GetSimpleString(NotificationTitle), "", WeaponClass.default.NotificationImage);
        return TRUE;
    }
    return bUpgraded;
}
public simulated function bool UseFirstPersonCamera()
{
    return FALSE;
}
public simulated function WeaponPlayWwiseEvent(WwiseEvent Sound, optional float NoiseLoudness, optional Vector SoundLoc, optional Name NoiseType)
{
    if (Sound == None || bSuppressAudio)
    {
        return;
    }
    if (!IsZero(SoundLoc))
    {
        SFXGRI(WorldInfo.GRI).PlayTransientSound(Sound, SoundLoc);
    }
    else if (Instigator != None)
    {
        Instigator.PlaySound(Sound, TRUE);
    }
    else if (Owner != None)
    {
        Owner.PlaySound(Sound, TRUE);
    }
    else
    {
        PlaySound(Sound, TRUE);
    }
    if (NoiseLoudness > 0.0 && Instigator != None && !IsTimerActive('HearNoiseTimer'))
    {
        SetTimer(HearNoiseTimeout, FALSE, 'HearNoiseTimer', );
        Instigator.MakeNoise(NoiseLoudness, NoiseType);
    }
}

simulated state WeaponEquipping 
{
    public simulated function ForceAnimSets()
    {
        local BioPawn BP;
        local SFXWeapon PrevWeapon;
        
        BP = BioPawn(Instigator);
        PrevWeapon = SFXWeapon(BP.WeaponFromLastGameState);
        BP.SetupWeaponAnimations(Self, PrevWeapon, FALSE);
    }
    public simulated function EquipFinished()
    {
        bDrawingWeapon = FALSE;
        OnWeaponEquip(Self);
    }
    public simulated function EquipNearFinished()
    {
        local SFXModule_WeaponModManager Manager;
        
        bDrawingWeaponBlendOut = TRUE;
        Manager = GetModule(Class'SFXModule_WeaponModManager');
        if (Manager != None && Mesh != None && !Mesh.HiddenGame)
        {
            Manager.SetWeaponModHidden(FALSE);
        }
    }
    public simulated function BeginState(Name PreviousStateName)
    {
        local BioPawn Pawn;
        
        bWeaponPutDown = FALSE;
        bDrawingWeapon = TRUE;
        bDrawingWeaponBlendOut = FALSE;
        Pawn = BioPawn(Instigator);
        if (Pawn != None)
        {
            if (Pawn.WeaponFromLastGameState == None)
            {
                Pawn.SetupWeaponAnimations(Self, None, FALSE);
            }
            else
            {
                Pawn.SetupWeaponAnimations(Self, None, TRUE);
            }
        }
        if (BioPawn(Instigator) != None && BioPawn(Instigator).StartCustomAction(12))
        {
            SetTimer(3.0, FALSE, 'EquipTimedOut', );
        }
        else
        {
            EquipFinished();
        }
    }
    public simulated function EquipTimedOut()
    {
        bDrawingWeapon = FALSE;
    }
    public function bool TryPutDown();
    
    public function Activate();
    
    
Begin:
    while (bDrawingWeapon)
    {
        Sleep(0.100000001);
    }
    ClearTimer('EquipTimedOut');
    DetachWeapon();
    AttachWeaponTo(BioPawn(Instigator).Mesh, BioPawn(Instigator).RightHandSocketName);
    ForceAnimSets();
    if (!bWeaponExpanded)
    {
        bInstantExpansion = TRUE;
        Expand();
    }
    GotoState('Active', , , );
    stop;
};
simulated state WeaponPuttingDown
{
    public simulated function UnEquipFinished()
    {
        bHolsteringWeapon = FALSE;
    }
    public simulated function BeginState(Name PreviousStateName)
    {
        local SFXModule_WeaponModManager Manager;

        bWeaponPutDown = FALSE;
        bPlayZoomSound = FALSE;
        bHolsteringWeapon = TRUE;
        ForceEndFire();
        OnWeaponUnequip(Self);
        Manager = GetModule(Class'SFXModule_WeaponModManager');
        if (Manager != None)
        {
            Manager.SetWeaponModHidden(TRUE);
        }
    }
    public simulated function UnEquipTimedOut()
    {
        bHolsteringWeapon = FALSE;
    }
    public function FireModeUpdated(byte FiringMode, bool bViaReplication);

    public function bool TryPutDown();


Begin:
    while (BioPawn(Instigator) != None && BioPawn(Instigator).bStorming)
    {
        Sleep(0.100000001);
    }
    if (BioPawn(Instigator) != None && BioPawn(Instigator).StartCustomAction(11))
    {
        SetTimer(2.0, FALSE, 'UnEquipTimedOut', );
    }
    else
    {
        UnEquipFinished();
    }
    DetachFlashlight();
    if (PSC_PermanentMuzzle != None)
    {
        PSC_PermanentMuzzle.SetActive(FALSE);
    }
    ShutOffAllEmitters();
    while (bHolsteringWeapon)
    {
        Sleep(0.100000001);
    }

    ClearTimer('UnEquipTimedOut');
    DetachWeapon();
    AttachWeaponTo(BioPawn(Instigator).Mesh, BioPawn(Instigator).AttachSlots[int(CharacterSlot)]);
    RestoreStowedWeaponVisibility();
    
    if (bWeaponExpanded)
    {
        bInstantExpansion = TRUE;
        Collapse();
    }
    if (InvManager.PendingWeapon == None)
    {
        BioPawn(Instigator).SetupWeaponAnimations(None, SFXWeapon(Instigator.Weapon));
    }
    InvManager.ChangedWeapon();
    GotoState('Inactive', , , );
    stop;
};
simulated state Reloading 
{
    public simulated function bool CanPlayerReload()
    {
        local BioPawn Pawn;
        
        Pawn = BioPawn(Instigator);
        if (Pawn != None && Instigator.IsHumanControlled())
        {
            if (Pawn.IsInCoverLeaning() || Pawn.IsInAnimatedTransition())
            {
                return FALSE;
            }
        }
        return TRUE;
    }
    public simulated function CancelReload()
    {
        ClearTimer('DoReload');
        GotoState('Active', , , );
        if (Role < ENetRole.ROLE_Authority)
        {
            ServerCancelReload();
        }
    }
    public simulated function bool TryPutDown()
    {
        PutDownWeapon();
        return TRUE;
    }
    public simulated function ReloadNearFinished()
    {
        bReloadWeaponBlendOut = TRUE;
    }
    public simulated function EndState(Name NextStateName)
    {
        EndFire(4);
        WeaponPlayWwiseEvent(StopWeaponReloadSound, 0.0);
        SetCurrentFireMode(0);
        if (AIController(Instigator.Controller) != None)
        {
            AIController(Instigator.Controller).NotifyWeaponFinishedFiring(Self, 4);
        }
        if (BioPawn(Instigator) != None)
        {
            BioPawn(Instigator).StopReloadWeapon();
        }
        bReloadWeaponBlendOut = FALSE;
        ClearTimer('DoReload');
    }
    public simulated function DoAReload()
    {
        local float ReloadTime;
        
        ReloadTime = GetReloadDuration() * EjectShellCasingTimeRatio;
        WeaponPlayWwiseEvent(WeaponReloadSound, 0.0);
        SetTimer(ReloadTime, FALSE, 'DoReload', );
        RestoreFlashlightToNormal();
        if (BioPawn(Instigator) != None)
        {
            BioPawn(Instigator).StopReloadWeapon();
            BioPawn(Instigator).ReloadWeapon();
        }
    }
    public simulated function BeginState(Name PreviousStateName)
    {
        local BioPlayerController PC;
        
        PC = BioPlayerController(Instigator.Controller);
        if (PC != None && PC.IsLocalPlayerController())
        {
            PC.GenerateTutorialEvent(6);
            PC.HintSystem.HintEvent('RELOAD', @Class.Name);
        }
        SetCurrentFireMode(4);
        bReloadWeaponBlendOut = FALSE;
    }
    public function RefireCheckTimer();
    
    public function TryReload(optional bool bDisplayHint);
    
    
Begin:
    while (CanPlayerReload() == FALSE)
    {
        Sleep(0.100000001);
    }
    DoAReload();
    if (Role == ENetRole.ROLE_Authority || Instigator.IsLocallyControlled())
    {
        Sleep(GetReloadDuration());
        GotoState('Active', , , );
    }
    stop;
};
state WeaponDisabled 
{
    public simulated function StopFire(byte FireModeNum)
    {
        Super(Weapon).StopFire(FireModeNum);
        ClearTimer('TriggerHeld');
        if (IsTimerActive('CooldownExpired') == FALSE)
        {
            GotoState('Active', , , );
            return;
        }
    }
    public simulated function TriggerHeld();
    
    public simulated function CooldownExpired()
    {
        if (!IsTimerActive('TriggerHeld'))
        {
            GotoState('Active', , , );
        }
    }
    public simulated function BeginState(Name PreviousStateName)
    {
        SetTimer(FMax(0.00999999978, MinRefireTime - GetFireInterval(CurrentFireMode)), FALSE, 'CooldownExpired', );
        if (PendingFire(int(CurrentFireMode)))
        {
            SetTimer(5.0, TRUE, 'TriggerHeld', );
        }
    }
    public simulated function EndState(Name NextStateName)
    {
        ClearTimer('CooldownExpired');
        ClearTimer('TriggerHeld');
        Super(Object).EndState(NextStateName);
    }
    public function SendToFiringState(byte FireModeNum);
    
    
    stop;
};
simulated state WeaponFiring_Burst extends WeaponFiring 
{
    public simulated function HandleFinishedFiring()
    {
        WeaponStoppedFiring(CurrentFireMode);
        GotoState('WeaponDisabled', , , );
    }
    public simulated function bool ShouldRefire()
    {
        if (!HasAmmo(CurrentFireMode) || RemainingBurstFireCount == 0)
        {
            return FALSE;
        }
        return TRUE;
    }
    public simulated function NotifyWeaponFired(byte FireMode)
    {
        RemainingBurstFireCount--;
        Super.NotifyWeaponFired(FireMode);
    }
    public simulated function EndState(Name NextStateName)
    {
        Super.EndState(NextStateName);
    }
    public simulated function BeginState(Name PreviousStateName)
    {
        RemainingBurstFireCount = int(RoundsPerBurst);
        if (bPlaySoundOncePerBurst && PlayerFireSound != None && Instigator.IsHumanControlled() && Instigator.IsLocallyControlled())
        {
            WeaponPlayWwiseEvent(PlayerFireSound, WeaponLoudness, , 'NoiseType_WeaponFire');
        }
        else if (bAIPlaySoundOncePerBurst && FireSound != None)
        {
            WeaponPlayWwiseEvent(FireSound, WeaponLoudness, , 'NoiseType_WeaponFire');
        }
        Super.BeginState(PreviousStateName);
    }
    
    stop;
};
simulated state WeaponFiring_SemiAuto extends WeaponFiring 
{
    public simulated function EndFire(byte FireModeNum)
    {
        Super.EndFire(FireModeNum);
        if (IsTimerActive('NotifySemiAutoRefireDelayExpired'))
        {
            GotoState('Active', , , );
        }
    }
    public simulated function HandleFinishedFiring()
    {
        if (Global.ShouldRefire() && LazyRateOfFire > 0.0)
        {
            ClearTimer('RefireCheckTimer');
            ClearFlashLocation();
            ClearFlashCount();
            SetTimer(GetLazyFireInterval(CurrentFireMode), FALSE, 'NotifySemiAutoRefireDelayExpired', );
            return;
        }
        GotoState('Active', , , );
    }
    public simulated function NotifySemiAutoRefireDelayExpired()
    {
        if (Global.ShouldRefire())
        {
            FireAmmunition();
            TimeWeaponFiring(CurrentFireMode);
        }
    }
    public simulated function bool ShouldRefire()
    {
        return FALSE;
    }
    public simulated function EndState(Name NextStateName)
    {
        Super.EndState(NextStateName);
        ClearTimer('NotifySemiAutoRefireDelayExpired');
    }
    
    stop;
};
simulated state WeaponFiring 
{
    public reliable server function ServerFireChargedShot(float SentChargeAmount)
    {
        ChargeAmount = SentChargeAmount;
        FireChargedShot();
    }
    public simulated function RefireCheckTimer()
    {
        if (IsChargingWeapon() && ChargeStartTime > 0.0)
        {
            return;
        }
        Super(Weapon).RefireCheckTimer();
    }
    public simulated function StopCharge(byte FireModeNum)
    {
        ChargeAmount = FClamp((WorldInfo.GameTimeSeconds - ChargeStartTime) / MaxChargeTime, 0.0, 1.0);
        if (CanFireChargedShot())
        {
            FireChargedShot();
        }
        else
        {
            StopChargeEffects();
        }
        ChargeStartTime = 0.0;
        bIsCharged = FALSE;
        ClearTimer('ForceFire');
    }
    public simulated function FireChargedShot()
    {
        if (Role < ENetRole.ROLE_Authority)
        {
            ServerFireChargedShot(ChargeAmount);
        }
        bFired = TRUE;
        StopChargeEffects();
        FireAmmunition();
        LastFireTime = WorldInfo.GameTimeSeconds;
        TimeWeaponFiring(CurrentFireMode);
        bIsCharged = FALSE;
    }
    public simulated function bool CanFireChargedShot()
    {
        local bool bInCover;
        local bool bInLeanout;
        
        if (bIsCharged == TRUE && bFired == FALSE && ChargeAmount > MinChargeTime / MaxChargeTime)
        {
            bInCover = SFXPawn_Player(Instigator).IsInCover();
            bInLeanout = SFXPawn_Player(Instigator).IsLeaning();
            return !bInCover || bInLeanout;
        }
        return FALSE;
    }
    public simulated function StopFire(byte FireModeNum)
    {
        local bool bChargeWeapon;
        
        bChargeWeapon = IsChargingWeapon();
        if (bChargeWeapon)
        {
            StopCharge(FireModeNum);
        }
        Super(Weapon).StopFire(FireModeNum);
        DelayedRestoreFlashlightToNormal();
        if (bChargeWeapon && !bFired)
        {
            HandleFinishedFiring();
        }
    }
    public simulated function ForceFire()
    {
        ChargeAmount = 1.0;
        FireChargedShot();
    }
    public simulated function StartCharge()
    {
        bIsCharged = TRUE;
        bFired = FALSE;
        ChargeStartTime = WorldInfo.GameTimeSeconds;
        StartChargeEffects();
        if (bForceFireAfterCharge && Instigator.IsLocallyControlled())
        {
            SetTimer(MaxChargeTime, FALSE, 'ForceFire', );
        }
    }
    public simulated function EndState(Name NextStateName)
    {
        if (bIsCharged)
        {
            StopChargeEffects();
        }
        Super(Weapon).EndState(NextStateName);
    }
    public simulated function Tick(float DeltaTime)
    {
        Global.Tick(DeltaTime);
        if (bIsCharged && InvManager != None && InvManager.PendingWeapon != None)
        {
            StopFire(CurrentFireMode);
            PutDownWeapon();
        }
    }
    public simulated function BeginState(Name PreviousStateName)
    {
        if (IsChargingWeapon())
        {
            StartCharge();
        }
        else
        {
            LogInternal(WorldInfo.TimeSeconds @ "Self:" @ Self @ "Instigator:" @ Instigator @ GetStateName() $ "::" $ GetFuncName() @ "PreviousStateName:" @ PreviousStateName, 'Inventory');
            FireAmmunition();
        }
        TimeWeaponFiring(CurrentFireMode);
        SetFlashlightFireMode();
    }
    
    stop;
};
simulated state Inactive 
{
    public simulated function BeginState(Name PreviousStateName)
    {
        local SFXModule_WeaponModManager Manager;
        
        Super(Weapon).BeginState(PreviousStateName);
        if (bPermanentMuzzle)
        {
            PSC_PermanentMuzzle.SetActive(FALSE);
        }
        DetachFlashlight();
        bWeaponPutDown = FALSE;
        ShutOffAllEmitters();
        Manager = GetModule(Class'SFXModule_WeaponModManager');
        if (Manager != None)
        {
            Manager.SetWeaponModHidden(TRUE);
        }
    }
    
    stop;
};
simulated state Active 
{
    public simulated function EndFire(byte FireModeNum)
    {
        Global.EndFire(FireModeNum);
        ClearTimer('PlayNoAmmoFireSound');
        ClearFizzleCount();
        if (int(FireModeNum) != int(CurrentFireMode))
        {
            StopFireEffects(FireModeNum);
        }
    }
    public simulated function CheckBeginFire()
    {
        if (IsInPortArms())
        {
            SetTimer(0.200000003, FALSE, 'CheckBeginFire', );
            return;
        }
        if (int(PendingFireMode) != 0)
        {
            BeginFire(PendingFireMode);
            PendingFireMode = 0;
        }
        else
        {
            EnablePortArms(TRUE);
        }
    }
    public simulated function BeginFire(byte FireModeNum)
    {
        EnablePortArms(FALSE);
        if (IsInPortArms())
        {
            PendingFireMode = FireModeNum;
            SetTimer(0.200000003, FALSE, 'CheckBeginFire', );
        }
        else if (bDeleteMe == FALSE && Instigator != None)
        {
            Global.BeginFire(FireModeNum);
            if (PendingFire(int(FireModeNum)))
            {
                if (HasAnyAmmo())
                {
                    if (HasAmmo(FireModeNum))
                    {
                        SendToFiringState(FireModeNum);
                    }
                    else if (int(FireModeNum) != 4 && ShouldAutoReload())
                    {
                        SendToFiringState(4);
                    }
                }
                else
                {
                    PlayNoAmmoEffects();
                    IncrementFizzleCount();
                    DelayedRestoreFlashlightToNormal();
                }
            }
        }
    }
    public final simulated function bool IsInPortArms()
    {
        local BioPawn MyPawn;
        
        MyPawn = BioPawn(Owner);
        if (MyPawn != None)
        {
            return MyPawn.bPlayingPortArmsAnim;
        }
        return FALSE;
    }
    public final simulated function EnablePortArms(bool bEnabled)
    {
        local BioPawn MyPawn;
        
        MyPawn = BioPawn(Owner);
        if (MyPawn != None)
        {
            MyPawn.bPortArmsEnabled = bEnabled;
        }
    }
    public simulated function EndState(Name NextStateName)
    {
        Super(Object).EndState(NextStateName);
        if (bPermanentMuzzle)
        {
            PSC_PermanentMuzzle.SetActive(FALSE);
        }
        ClearTimer('CheckBeginFire');
    }
    public simulated function BeginState(Name PreviousStateName)
    {
        local int i;
        local BioPlayerController oBPC;
        local SFXGUIInteraction oGUI;
        local SFXSFHandler_HUD oHud;
        local SFXModule_WeaponModManager Manager;
        
        oBPC = BioWorldInfo(WorldInfo).GetLocalPlayerController();
        oGUI = Class'SFXGUIInteraction'.static.GetInstance();
        if (oGUI != None)
        {
            oHud = oGUI.CastGetMovie(Class'SFXSFHandler_HUD', oBPC, oGUI.MovieTag_HUD);
            if (oHud != None)
            {
                oHud.m_bForceUpdateDisplayNextTick = TRUE;
            }
        }
        if (Role == ENetRole.ROLE_Authority)
        {
            AIController = AIController(Instigator.Controller);
        }
        EnablePortArms(TRUE);
        AttachFlashlight();
        Manager = GetModule(Class'SFXModule_WeaponModManager');
        if (Manager != None && Mesh != None && !Mesh.HiddenGame)
        {
            Manager.SetWeaponModHidden(FALSE);
        }
        if (InvManager.PendingWeapon != None && InvManager.PendingWeapon != Self)
        {
            LogInternal(WorldInfo.TimeSeconds @ "Self:" @ Self @ "Instigator:" @ Instigator @ GetStateName() $ "::" $ GetFuncName() @ "Warning: forcing bWeaponPutDown because inventory manager has a different pending weapon", 'Inventory');
            bWeaponPutDown = TRUE;
        }
        if (bWeaponPutDown)
        {
            PutDownWeapon();
        }
        if (bPermanentMuzzle)
        {
            if (Instigator.IsHumanControlled())
            {
                PSC_PermanentMuzzle.SetActive(TRUE);
                PlaySound(OnMuzzleSound);
                if (PSC_PermanentMuzzle.bAttached == FALSE)
                {
                    SkeletalMeshComponent(Mesh).AttachComponentToSocket(PSC_PermanentMuzzle, 'Flash_2');
                }
            }
        }
        else if (PreviousStateName != 'Reloading' && (GetCurrentSpareAmmo() > 0 || bInfiniteAmmo) && (PendingFire(4) || ShouldAutoReload()))
        {
            BeginFire(4);
        }
        else if (InvManager != None)
        {
            for (i = 0; i < InvManager.GetPendingFireLength(None); i++)
            {
                if (PendingFire(i))
                {
                    BeginFire(byte(i));
                }
            }
        }
    }
    
    stop;
};

replication
{
    if (Role == ENetRole.ROLE_Authority && bNetDirty && !bNetOwner)
        RepChargeEffect;
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    Begin Object Class=ParticleSystemComponent Name=OutOfAmmoEffect0
        Template = ParticleSystem'BioVFX_C_Reload.Particles.Reload_VentHeat_Med'
        bAutoActivate = FALSE
        ReplacementPrimitive = None
    End Object
    Begin Object Class=SkeletalMeshComponent Name=WeaponMesh
        ReplacementPrimitive = None
        MotionBlurScale = 0.200000003
    End Object
    Begin Object Class=SkeletalMeshComponent Name=PickupMesh
        ReplacementPrimitive = None
        MotionBlurScale = 0.200000003
    End Object
    Begin Object Class=ParticleSystemComponent Name=ReloadVent0
        Template = ParticleSystem'BioVFX_C_Reload.Particles.ClipEnd_VentHeat'
        bAutoActivate = FALSE
        ReplacementPrimitive = None
    End Object
    Begin Object Class=PointLightComponent Name=MuzFlashLight0
        Radius = 230.0
        FalloffExponent = 13.0
        Brightness = 3.0
        LightingChannels = {CompositeDynamic = FALSE}
        LightAffectsClassification = ELightAffectsClassification.LAC_DYNAMIC_AND_STATIC_AFFECTING
    End Object
    Begin Object Class=ParticleSystemComponent Name=AmmoPowerHologram
        bAutoActivate = FALSE
        ReplacementPrimitive = None
    End Object
    Begin Object Class=ParticleSystemComponent Name=AmmoPowerIconHologram
        bAutoActivate = FALSE
        ReplacementPrimitive = None
    End Object
    Begin Object Class=ForceFeedbackWaveform Name=OutOfAmmoRumble0
        Samples = ({Duration = 0.449999988, LeftAmplitude = 25, RightAmplitude = 25, LeftFunction = EWaveformFunction.WF_Constant, RightFunction = EWaveformFunction.WF_Constant}
                  )
    End Object
    Begin Object Class=ForceFeedbackWaveform Name=ForceFeedbackWaveformBase
    End Object
    Begin Object Class=SFXModule_GameEffectManager Name=GEMod0
    End Object
    Begin Object Class=SFXModule_WeaponModManager Name=ModManager0
    End Object
    AI_AccCone_Min = {
                      Bonuses = (), 
                      X = 100.0, 
                      Y = 100.0, 
                      MaxLevel = 100, 
                      Level = 0, 
                      Value = 0.0, 
                      StaticBonus = 1.0
                     }
    AI_AccCone_Max = {
                      Bonuses = (), 
                      X = 100.0, 
                      Y = 100.0, 
                      MaxLevel = 100, 
                      Level = 0, 
                      Value = 0.0, 
                      StaticBonus = 1.0
                     }
    ReloadDuration = {
                      Bonuses = (), 
                      X = 1.0, 
                      Y = 1.0, 
                      MaxLevel = 100, 
                      Level = 0, 
                      Value = 0.0, 
                      StaticBonus = 1.0
                     }
    Damage = {
              Bonuses = (), 
              X = 0.0, 
              Y = 0.0, 
              MaxLevel = 100, 
              Level = 0, 
              Value = 0.0, 
              StaticBonus = 1.0
             }
    MagSize = {
               Bonuses = (), 
               X = 1.0, 
               Y = 1.0, 
               MaxLevel = 100, 
               Level = 0, 
               Value = 0.0, 
               StaticBonus = 1.0
              }
    MaxSpareAmmo = {
                    Bonuses = (), 
                    X = 0.0, 
                    Y = 0.0, 
                    MaxLevel = 100, 
                    Level = 0, 
                    Value = 0.0, 
                    StaticBonus = 1.0
                   }
    MinAimError = {
                   Bonuses = (), 
                   X = 100.0, 
                   Y = 100.0, 
                   MaxLevel = 100, 
                   Level = 0, 
                   Value = 0.0, 
                   StaticBonus = 1.0
                  }
    MaxAimError = {
                   Bonuses = (), 
                   X = 100.0, 
                   Y = 100.0, 
                   MaxLevel = 100, 
                   Level = 0, 
                   Value = 0.0, 
                   StaticBonus = 1.0
                  }
    MinZoomAimError = {
                       Bonuses = (), 
                       X = 100.0, 
                       Y = 100.0, 
                       MaxLevel = 100, 
                       Level = 0, 
                       Value = 0.0, 
                       StaticBonus = 1.0
                      }
    MaxZoomAimError = {
                       Bonuses = (), 
                       X = 100.0, 
                       Y = 100.0, 
                       MaxLevel = 100, 
                       Level = 0, 
                       Value = 0.0, 
                       StaticBonus = 1.0
                      }
    RateOfFire = {
                  Bonuses = (), 
                  X = 1.0, 
                  Y = 1.0, 
                  MaxLevel = 100, 
                  Level = 0, 
                  Value = 0.0, 
                  StaticBonus = 1.0
                 }
    NoAmmoUseChance = {
                       Bonuses = (), 
                       X = 1.0, 
                       Y = 1.0, 
                       MaxLevel = 100, 
                       Level = 0, 
                       Value = 0.0, 
                       StaticBonus = 1.0
                      }
    HeadshotDamageMultiplier = {
                                Bonuses = (), 
                                X = 2.5, 
                                Y = 2.5, 
                                MaxLevel = 100, 
                                Level = 0, 
                                Value = 0.0, 
                                StaticBonus = 1.0
                               }
    ImpactForceModifier = {
                           Bonuses = (), 
                           X = 1.0, 
                           Y = 1.0, 
                           MaxLevel = 100, 
                           Level = 0, 
                           Value = 0.0, 
                           StaticBonus = 1.0
                          }
    ReactionChanceModifier = {
                              Bonuses = (), 
                              X = 1.0, 
                              Y = 1.0, 
                              MaxLevel = 100, 
                              Level = 0, 
                              Value = 1.0, 
                              StaticBonus = 1.0
                             }
    MeleeDamageModifier = {
                           Bonuses = (), 
                           X = 1.0, 
                           Y = 1.0, 
                           MaxLevel = 100, 
                           Level = 0, 
                           Value = 0.0, 
                           StaticBonus = 1.0
                          }
    EncumbranceWeight = {
                         Bonuses = (), 
                         X = 0.0, 
                         Y = 0.0, 
                         MaxLevel = 100, 
                         Level = 0, 
                         Value = 0.0, 
                         StaticBonus = 1.0
                        }
    Recoil = {
              Bonuses = (), 
              X = 10.0, 
              Y = 10.0, 
              MaxLevel = 100, 
              Level = 0, 
              Value = 0.0, 
              StaticBonus = 1.0
             }
    ZoomRecoil = {
                  Bonuses = (), 
                  X = 10.0, 
                  Y = 10.0, 
                  MaxLevel = 100, 
                  Level = 0, 
                  Value = 0.0, 
                  StaticBonus = 1.0
                 }
    AccFirePenalty = {
                      Bonuses = (), 
                      X = 100.0, 
                      Y = 100.0, 
                      MaxLevel = 100, 
                      Level = 0, 
                      Value = 0.0, 
                      StaticBonus = 1.0
                     }
    AccFireInterpSpeed = {
                          Bonuses = (), 
                          X = 100.0, 
                          Y = 100.0, 
                          MaxLevel = 100, 
                          Level = 0, 
                          Value = 0.0, 
                          StaticBonus = 1.0
                         }
    ZoomAccFirePenalty = {
                          Bonuses = (), 
                          X = 100.0, 
                          Y = 100.0, 
                          MaxLevel = 100, 
                          Level = 0, 
                          Value = 0.0, 
                          StaticBonus = 1.0
                         }
    ZoomAccFireInterpSpeed = {
                              Bonuses = (), 
                              X = 100.0, 
                              Y = 100.0, 
                              MaxLevel = 100, 
                              Level = 0, 
                              Value = 0.0, 
                              StaticBonus = 1.0
                             }
    MinCrosshairRange = {
                         Bonuses = (), 
                         X = 8.0, 
                         Y = 8.0, 
                         MaxLevel = 100, 
                         Level = 0, 
                         Value = 0.0, 
                         StaticBonus = 1.0
                        }
    MaxCrosshairRange = {
                         Bonuses = (), 
                         X = 9999.0, 
                         Y = 9999.0, 
                         MaxLevel = 100, 
                         Level = 0, 
                         Value = 0.0, 
                         StaticBonus = 1.0
                        }
    MinZoomCrosshairRange = {
                             Bonuses = (), 
                             X = 100.0, 
                             Y = 100.0, 
                             MaxLevel = 100, 
                             Level = 0, 
                             Value = 0.0, 
                             StaticBonus = 1.0
                            }
    MaxZoomCrosshairRange = {
                             Bonuses = (), 
                             X = 100.0, 
                             Y = 100.0, 
                             MaxLevel = 100, 
                             Level = 0, 
                             Value = 0.0, 
                             StaticBonus = 1.0
                            }
    PenetrationBonus = {
                        Bonuses = (), 
                        X = 1.0, 
                        Y = 1.0, 
                        MaxLevel = 100, 
                        Level = 0, 
                        Value = 0.0, 
                        StaticBonus = 1.0
                       }
    PenetrationDamageBonus = {
                              Bonuses = (), 
                              X = 1.0, 
                              Y = 1.0, 
                              MaxLevel = 100, 
                              Level = 0, 
                              Value = 0.0, 
                              StaticBonus = 1.0
                             }
    ArmorPiercing = {
                     Bonuses = (), 
                     X = 1.0, 
                     Y = 1.0, 
                     MaxLevel = 100, 
                     Level = 0, 
                     Value = 0.0, 
                     StaticBonus = 1.0
                    }
    StatBarAccuracy = {
                       Bonuses = (), 
                       X = 0.0, 
                       Y = 0.0, 
                       MaxLevel = 100, 
                       Level = 0, 
                       Value = 0.0, 
                       StaticBonus = 1.0
                      }
    StatBarDamage = {
                     Bonuses = (), 
                     X = 0.0, 
                     Y = 0.0, 
                     MaxLevel = 100, 
                     Level = 0, 
                     Value = 0.0, 
                     StaticBonus = 1.0
                    }
    StatBarRateOfFire = {
                         Bonuses = (), 
                         X = 0.0, 
                         Y = 0.0, 
                         MaxLevel = 100, 
                         Level = 0, 
                         Value = 0.0, 
                         StaticBonus = 1.0
                        }
    ZoomDamageShakeModifier = {
                               Bonuses = (), 
                               X = 1.0, 
                               Y = 1.0, 
                               MaxLevel = 100, 
                               Level = 0, 
                               Value = 0.0, 
                               StaticBonus = 1.0
                              }
    AimModes = ({ScopeResource = 'None', ZoomFOV = 39.4300003, FrictionMultiplier = 1.0, AdhesionMultiplier = 1.0, bScoped = FALSE}
               )
    AimOffsetProfileNames = ('Default')
    NotificationImage = "GUI_GlobalIcons.Notifications.NewTech_256"
    AmmoRTPCName = "Weapon_Current_Ammo"
    ZoomSnapList = ({OuterSnapAngle = 5.0, InnerSnapAngle = 0.5, SnapOffsetMag = 20.0, AimNode = EAimNodes.AimNode_Cover}, 
                    {OuterSnapAngle = 3.0, InnerSnapAngle = 0.5, SnapOffsetMag = 15.0, AimNode = EAimNodes.AimNode_Head}, 
                    {OuterSnapAngle = 10.0, InnerSnapAngle = 1.0, SnapOffsetMag = 50.0, AimNode = EAimNodes.AimNode_Chest}
                   )
    FadingParameters = ('glow', 'inner_glow', 'Fade_Off')
    DamageUpgradeTokens = ($339507, 
                           $339508, 
                           $339509, 
                           $339510, 
                           $339511, 
                           $339512, 
                           $339513, 
                           $339514, 
                           $339515, 
                           $339516
                          )
    ResearchUpgradeTokens = ($339517, $339518, $339519, $339520, $339521)
    CoverLeanPositions = ({
                           WeaponTypes = (WeaponAnimType.WeaponAnimType_Pistol), 
                           Offset = {X = 0.0, Y = 42.7890015, Z = 0.0}, 
                           Direction = ECoverDirection.CD_Right, 
                           Type = ECoverType.CT_MidLevel
                          }, 
                          {
                           WeaponTypes = (WeaponAnimType.WeaponAnimType_Pistol), 
                           Offset = {X = 0.0, Y = -81.5230026, Z = 0.0}, 
                           Direction = ECoverDirection.CD_Left, 
                           Type = ECoverType.CT_MidLevel
                          }, 
                          {
                           WeaponTypes = (WeaponAnimType.WeaponAnimType_Pistol), 
                           Offset = {X = 0.0, Y = 64.038002, Z = 0.0}, 
                           Direction = ECoverDirection.CD_Right, 
                           Type = ECoverType.CT_Standing
                          }, 
                          {
                           WeaponTypes = (WeaponAnimType.WeaponAnimType_Pistol), 
                           Offset = {X = 0.0, Y = -60.2770004, Z = 0.0}, 
                           Direction = ECoverDirection.CD_Left, 
                           Type = ECoverType.CT_Standing
                          }, 
                          {
                           WeaponTypes = (WeaponAnimType.WeaponAnimType_Shotgun, 
                                          WeaponAnimType.WeaponAnimType_Rifle, 
                                          WeaponAnimType.WeaponAnimType_Sniper, 
                                          WeaponAnimType.WeaponAnimType_GrenadeLauncher, 
                                          WeaponAnimType.WeaponAnimType_MissileLauncher, 
                                          WeaponAnimType.WeaponAnimType_NukeLauncher, 
                                          WeaponAnimType.WeaponAnimType_ParticleBeam, 
                                          WeaponAnimType.WeaponAnimType_RepulsorBeam, 
                                          WeaponAnimType.WeaponAnimType_AutoShotgun, 
                                          WeaponAnimType.WeaponAnimType_AutoSniper, 
                                          WeaponAnimType.WeaponAnimType_AutoPistol
                                         ), 
                           Offset = {X = 0.0, Y = 42.7890015, Z = 0.0}, 
                           Direction = ECoverDirection.CD_Right, 
                           Type = ECoverType.CT_MidLevel
                          }, 
                          {
                           WeaponTypes = (WeaponAnimType.WeaponAnimType_Shotgun, 
                                          WeaponAnimType.WeaponAnimType_Rifle, 
                                          WeaponAnimType.WeaponAnimType_Sniper, 
                                          WeaponAnimType.WeaponAnimType_GrenadeLauncher, 
                                          WeaponAnimType.WeaponAnimType_MissileLauncher, 
                                          WeaponAnimType.WeaponAnimType_NukeLauncher, 
                                          WeaponAnimType.WeaponAnimType_ParticleBeam, 
                                          WeaponAnimType.WeaponAnimType_RepulsorBeam, 
                                          WeaponAnimType.WeaponAnimType_AutoShotgun, 
                                          WeaponAnimType.WeaponAnimType_AutoSniper, 
                                          WeaponAnimType.WeaponAnimType_AutoPistol
                                         ), 
                           Offset = {X = 0.0, Y = -81.5230026, Z = 0.0}, 
                           Direction = ECoverDirection.CD_Left, 
                           Type = ECoverType.CT_MidLevel
                          }, 
                          {
                           WeaponTypes = (WeaponAnimType.WeaponAnimType_Shotgun, 
                                          WeaponAnimType.WeaponAnimType_Rifle, 
                                          WeaponAnimType.WeaponAnimType_Sniper, 
                                          WeaponAnimType.WeaponAnimType_GrenadeLauncher, 
                                          WeaponAnimType.WeaponAnimType_MissileLauncher, 
                                          WeaponAnimType.WeaponAnimType_NukeLauncher, 
                                          WeaponAnimType.WeaponAnimType_ParticleBeam, 
                                          WeaponAnimType.WeaponAnimType_RepulsorBeam, 
                                          WeaponAnimType.WeaponAnimType_AutoShotgun, 
                                          WeaponAnimType.WeaponAnimType_AutoSniper, 
                                          WeaponAnimType.WeaponAnimType_AutoPistol
                                         ), 
                           Offset = {X = 0.0, Y = 64.038002, Z = 0.0}, 
                           Direction = ECoverDirection.CD_Right, 
                           Type = ECoverType.CT_Standing
                          }, 
                          {
                           WeaponTypes = (WeaponAnimType.WeaponAnimType_Shotgun, 
                                          WeaponAnimType.WeaponAnimType_Rifle, 
                                          WeaponAnimType.WeaponAnimType_Sniper, 
                                          WeaponAnimType.WeaponAnimType_GrenadeLauncher, 
                                          WeaponAnimType.WeaponAnimType_MissileLauncher, 
                                          WeaponAnimType.WeaponAnimType_NukeLauncher, 
                                          WeaponAnimType.WeaponAnimType_ParticleBeam, 
                                          WeaponAnimType.WeaponAnimType_RepulsorBeam, 
                                          WeaponAnimType.WeaponAnimType_AutoShotgun, 
                                          WeaponAnimType.WeaponAnimType_AutoSniper, 
                                          WeaponAnimType.WeaponAnimType_AutoPistol
                                         ), 
                           Offset = {X = 0.0, Y = -60.2770004, Z = 0.0}, 
                           Direction = ECoverDirection.CD_Left, 
                           Type = ECoverType.CT_Standing
                          }
                         )
    WeaponModGripColours = ({R = 0.788999975, G = 0.61500001, B = 0.513000011, A = 0.0}, 
                            {R = 1.0, G = 1.0, B = 1.0, A = 0.0}, 
                            {R = 0.519999981, G = 0.680000007, B = 1.0, A = 0.0}, 
                            {R = 0.239999995, G = 0.239999995, B = 0.239999995, A = 0.0}, 
                            {R = 0.129999995, G = 0.100000001, B = 0.0799999982, A = 0.0}
                           )
    WeaponModEmissiveColours = ({R = 0.0, G = 0.0590000004, B = 1.0, A = 1.0}, 
                                {R = 0.550000012, G = 1.0, B = 0.5, A = 1.0}, 
                                {R = 0.910000026, G = 1.0, B = 0.0, A = 1.0}, 
                                {R = 1.0, G = 0.300000012, B = 0.0, A = 1.0}, 
                                {R = 1.0, G = 0.0, B = 0.0, A = 1.0}
                               )
    RTPCName = "Player_Position"
    DroppedAmmoClass = Class'SFXDroppedAmmo'
    GUIReticleClass = Class'SFXGUI_WeaponReticleSimpleAlpha'
    GUIZoomReticleClass = Class'SFXGUI_CrosshairReticle'
    ChargeCameraShake = {
                         RotAmplitude = {X = 100.0, Y = 100.0, Z = 200.0}, 
                         RotFrequency = {X = 10.0, Y = 10.0, Z = 25.0}, 
                         RotSinOffset = {X = 0.0, Y = 0.0, Z = 0.0}, 
                         LocAmplitude = {X = 0.0, Y = 3.0, Z = 5.0}, 
                         LocFrequency = {X = 1.0, Y = 10.0, Z = 20.0}, 
                         LocSinOffset = {X = 0.0, Y = 0.0, Z = 0.0}, 
                         ShakeName = 'None', 
                         TimeToGo = 0.0, 
                         TimeDuration = 0.0, 
                         RotParam = {X = EShakeParam.ESP_OffsetRandom, Y = EShakeParam.ESP_OffsetRandom, Z = EShakeParam.ESP_OffsetRandom, Padding = 0}, 
                         LocParam = {X = EShakeParam.ESP_OffsetRandom, Y = EShakeParam.ESP_OffsetRandom, Z = EShakeParam.ESP_OffsetRandom, Padding = 0}, 
                         FOVAmplitude = 2.0, 
                         FOVFrequency = 5.0, 
                         FOVSinOffset = 0.0, 
                         TargetingDampening = 0.0, 
                         bOverrideTargetingDampening = FALSE, 
                         FOVParam = EShakeParam.ESP_OffsetRandom
                        }
    WeaponModBaseGripColour = {R = 0.0, G = 0.0, B = 0.0, A = 1.0}
    WeaponModBaseBodyColour = {R = 0.0, G = 0.0, B = 0.0, A = 1.0}
    WeaponModBaseEmissiveColour = {R = 0.0, G = 0.0, B = 0.0, A = 1.0}
    MuzzleIdlePosition = {X = 80.0, Y = 0.0, Z = 30.0}
    FrictionTargetOffset = {X = 0.0, Y = 0.0, Z = 22.0}
    MeleePowerName = 'Rifle_Butt'
    PSC_OutOfAmmoEffect = OutOfAmmoEffect0
    OutOfAmmoRumble = OutOfAmmoRumble0
    WeaponFireWaveForm = ForceFeedbackWaveformBase
    PS_DefaultImpactEffect = ParticleSystem'BioVFX_C_Impacts.Generic.Particles.Generic_Imp'
    PS_DefaultMaterialImpactEffect = ParticleSystem'BioVFX_C_Impacts.Generic.Particles.Generic_Material_Imp'
    DefaultDecalMaterial = MaterialInstanceTimeVarying'BioVFX_C_Impacts.Generic.Decals.DECAL_Blast_Generic_TINST'
    PSC_ReloadVent = ReloadVent0
    LC_MuzzleFlashLight = MuzFlashLight0
    MuzzleSocketName = 'Flash_2'
    ShellCasingSocketName = 'Cooldown'
    IconResource = GFxMovieInfo'GUI_SF_ME2_Weapon_Icons.ME2_Weapon_Icons'
    WeaponWhipSoundLeft = None
    WeaponWhipSoundRight = None
    StopWeaponReloadSound = WwiseEvent'Wwise_Weapons_Generic.Stop_wep_g_reload_all'
    ActivateModScopeZoomWwiseEvent = WwiseEvent'Wwise_Weapons_Generic.Play_wep_g_mod_scope_in'
    DeActivateModScopeZoomWwiseEvent = WwiseEvent'Wwise_Weapons_Generic.Play_wep_g_mod_scope_out'
    FrictionMultiplierRange = {X = 0.0, Y = 0.379999995}
    AdhesionStrengthRange = {X = 0.0, Y = 1.0}
    AmmoPowerPSCO = AmmoPowerHologram
    AmmoPowerIconPSCO = AmmoPowerIconHologram
    CoverLeanExitDelay = 0.100000001
    CoverPartialLeanExitDelay = 0.150000006
    ImpactRelevanceDistance = 8000.0
    ImpactScale = 1.0
    ShowTracerDistance = 350.0
    MuzzleLightLifetime = 0.100000001
    MuzzleLightColor = {B = 255, G = 255, R = 255, A = 0}
    MuzzleLightFalloffExponent = 13.0
    MuzzleLightRadius = 230.0
    MuzzleLightShadowFalloffExponent = 2.0
    MuzzleLightShadowRadiusMultiplier = 1.10000002
    LightStepSize = 0.100000001
    TimeToHideMuzzleFlashPSC = 2.0
    TimeToDeactivateMuzzleFlashPSC = 0.100000001
    FlashlightFireColor = {B = 255, G = 255, R = 255, A = 0}
    FlashlightFireBrightnessIncrease = 2.0
    FlashlightFireRadiusIncrease = 0.5
    EjectShellCasingTimeRatio = 0.5
    ReloadReactionWindow = 0.00100000005
    DamageHench = 0.300000012
    MinRefireTime = 0.25
    RateOfFireAI = 0.100000001
    RoundsPerBurst = 1.0
    ModCrosshairMultiplier = 0.5
    AmmoPerShot = 1.0
    RecoilInterpSpeed = 100.0
    RecoilCap = 40.0
    ZoomRecoilCap = 40.0
    RecoilYawFrequency = 1.0
    TraceRange = 8000.0
    MeleeRange = 300.0
    IdealMinRange = 300.0
    IdealTargetDistance = 1200.0
    IdealMaxRange = 4000.0
    MagneticCorrectionThresholdAngle = 0.5
    MaxMagneticCorrectionAngle = 0.25
    IconRef = 1
    ShortDescription = $209740
    GeneralDescription = $209740
    WeaponUnlockMessage = $546165
    WeaponUpgradeMessage = $707488
    GUIWeaponOrder = 999
    WeaponLoudness = 1.0
    MaxFrictionDistance = 5000.0
    PeakFrictionDistance = 2000.0
    PeakFrictionRadiusScale = 1.25
    PeakFrictionHeightScale = 0.400000006
    MinAdhesionDistance = 100.0
    MaxAdhesionDistance = 6000.0
    MinAdhesionVelocity = 80.0
    CamInputAdhesionDamping = 0.400000006
    MaxLateralAdhesionDist = 125.0
    MinZoomSnapDistance = 500.0
    MaxZoomSnapDistance = 4000.0
    MaxWeaponMods = 2
    ClientSideHitLeeway = 4.19999981
    ClientSideHitMaxDistReallyClose = 5000.0
    ClientSideHitMaxAngle = 0.600000024
    ClientSideHitMaxDistClose = 30000.0
    ClientSideHitMaxAngleClose = 0.200000003
    NumberOfDefaultModsToAttach = 2
    HearNoiseTimeout = 1.0
    MaxLevel = 10.0
    NewGamePlusID = 1690
    bPlayerUsable = TRUE
    bFrictionEnabled = TRUE
    bAdhesionEnabled = TRUE
    bAdhesionDuringCam = TRUE
    bZoomSnapEnabled = TRUE
    bQuickSwitchEligible = TRUE
    DefaultFireMode = FireModes.FireMode_FullAuto
    AttachSlot = EAttachSlot.EASlot_RightShoulder
    bCanDropAmmo = TRUE
    bCanBlindUp = TRUE
    CharacterSlot = None
    FiringStatesArray = ('None', 'WeaponFiring_SemiAuto', 'WeaponFiring', 'WeaponFiring_Burst', 'Reloading')
    WeaponFireTypes = (EWeaponFireType.EWFT_InstantHit, EWeaponFireType.EWFT_InstantHit, EWeaponFireType.EWFT_InstantHit, EWeaponFireType.EWFT_InstantHit, EWeaponFireType.EWFT_InstantHit)
    InstantHitMomentum = (0.0, 1.0, 1.0, 1.0)
    InstantHitDamageTypes = (None, Class'SFXDamageType_Default', Class'SFXDamageType_Default', Class'SFXDamageType_Default')
    Mesh = WeaponMesh
    AIRating = 10.0
    DroppedPickupClass = Class'SFXDroppedPickup'
    PickupFactoryMesh = PickupMesh
    RespawnTime = 120.0
    Components = (WeaponMesh)
    Modules = (GEMod0, ModManager0)
    NetPriority = 2.20000005
    bOnlyRelevantToOwner = FALSE
    bOnlyDirtyReplication = TRUE
}