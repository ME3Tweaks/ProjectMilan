// MILAN Weapon
// Based on: MP4 class
Class SFXWeapon_SniperRifle_Collector extends SFXWeapon_Heavy_Beam_Collector_Sniper
    placeable
    config(Weapon);

// Variables
var string AmmoAmountRTPC;
var ScreenShakeStruct HoldShake;
var Guid ClientEffectFiringGuid;
var Guid ChargeEffectGuid;
var config float RechargeRatePerSecond;
var config float PartialRechargeDelay;
var config float FullRechargeDelay;
var float AccumulatedAmmo;
var transient int CollectorAmmoUsedCount;
var RvrClientEffectInterface CE_HeatVent;
var RvrClientEffectInterface CE_SteamVent;
var config float TimeToHeatUp;
var config float TimeToHeatUpAI;
var config float ProtheanDamageMultiplier;
var float SteamDelay;
var float HeatDelay;
var RvrClientEffectInterface CE_ChargeUp;
var WwiseEvent PowerUpSound1;
var WwiseEvent PowerDownSound1;
var WwiseEvent NPCPowerUpSound1;
var WwiseEvent NPCPowerDownSound1;
var WwiseEvent WeaponReloadRechargeSound;
var transient float ClientDoReloadTriggerReplicationTime;
var transient repnotify int ClientDoReloadTrigger;
var float RechargeSoundDelay;
var bool bFireSoundPlaying;
var bool bIsHot;
var bool bCanPlayRechargeSound;
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
        // Same as CalcWeaponFire: start level with the pawn so we don't hit things between camera and pawn
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
public event simulated function ReplicatedEvent(Name VarName)
{
    if (VarName == 'ClientDoReloadTrigger')
    {
        StopMuzzleFlashEffect();
        Super(Weapon).SendToFiringState(4);
    }
    Super(SFXWeapon).ReplicatedEvent(VarName);
}
public simulated function Tick(float DeltaTime)
{
    local SFXPlayerController PC;
    local float ShakeStrength;
    
    Super.Tick(DeltaTime);
    if (int(CurrentFireMode) == 2)
    {
        Class'WwiseAudioComponent'.static.SetGlobalRTPCFromScript(AmmoAmountRTPC, float(GetCurrentTotalAmmo()));
    }
    if (CollectorAmmoUsedCount == GetMagazineSize())
    {
        bWeaponCanBeReloaded = TRUE;
    }
    else if (WorldInfo.GameTimeSeconds - LastFireTime >= PartialRechargeDelay)
    {
        bWeaponCanBeReloaded = FALSE;
        RechargeAmmo(DeltaTime);
    }
    if (Instigator != None && int(CurrentFireMode) == 2)
    {
        PC = SFXPlayerController(Instigator.Controller);
        ShakeStrength = FClamp((WorldInfo.GameTimeSeconds - LastFireTime) / TimeToHeatUp, 0.0, 1.0);
        PC.PlayScaledCameraShake(HoldShake, ShakeStrength);
    }
}
public simulated function ConsumeAmmo(byte FireModeNum)
{
    if (bIsHot == TRUE && GetMagazineSize() - CollectorAmmoUsedCount > 1)
    {
        AmmoPerShot = 2.0;
    }
    else
    {
        AmmoPerShot = 1.0;
    }
    ConsumeAmmoCollector(FireModeNum);
    AmmoPerShot = 1.0;
}
public simulated function FireModeUpdated(byte FiringMode, bool bViaReplication)
{
    if (int(FiringMode) == 4)
    {
        return;
    }
    Super(SFXWeapon).FireModeUpdated(FiringMode, bViaReplication);
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
    if (!Instigator.IsLocallyControlled())
    {
        return TRUE;
    }
    if (float(Amount) < AmmoPerShot)
    {
        Amount = int(AmmoPerShot);
    }
    MagazineSize = GetMagazineSize();
    if (MagazineSize >= 0 && CollectorAmmoUsedCount + Amount > MagazineSize)
    {
        return FALSE;
    }
    return TRUE;
}
public simulated function PlayFireEffects(byte FireModeNum, optional Vector HitLocation)
{
    local RvrClientEffectTarget CETarget;
    
    Super.PlayFireEffects(FireModeNum, HitLocation);
    if (!bFireSoundPlaying)
    {
        bFireSoundPlaying = TRUE;
        GetModule(Class'SFXModule_GameEffectManager').RemoveEffectsByType(Class'SFXGameEffect_WeaponVFXChange');
        GunIsCold();
        if (SFXPawn_Player(Instigator).IsLocallyControlled())
        {
            WeaponPlayWwiseEvent(PowerUpSound1);
        }
        else
        {
            WeaponPlayWwiseEvent(NPCPowerUpSound1);
        }
        CETarget.Instigator = Instigator;
        CETarget.HitBone = 'Flash_2';
        ChargeEffectGuid = Class'RvrClientEffectManager'.static.GetClientEffectManager().StartOnTarget(CE_ChargeUp, CETarget);
        if (SFXPawn_Player(Instigator) != None)
        {
            SetTimer(TimeToHeatUp, FALSE, 'GunIsHot', );
        }
        else if (SFXPawn_Henchman(Instigator) != None)
        {
            SetTimer(TimeToHeatUpAI, FALSE, 'GunIsHot', );
        }
    }
}
public simulated function SendToFiringState(byte FireModeNum)
{
    if (int(FireModeNum) == 4)
    {
        if (Instigator != None && Instigator.IsLocallyControlled())
        {
            if (Instigator.Role == ENetRole.ROLE_Authority)
            {
                ClientDoReloadTrigger++;
                ClientDoReloadTriggerReplicationTime = WorldInfo.TimeSeconds + 3.0;
            }
            else
            {
                ServerDoReload();
            }
        }
        else
        {
            return;
        }
    }
    Super(Weapon).SendToFiringState(FireModeNum);
}
public simulated function StopFireEffects(byte FireModeNum)
{
    Super(SFXWeapon).StopFireEffects(FireModeNum);
    if (bFireSoundPlaying)
    {
        bFireSoundPlaying = FALSE;
        Class'RvrClientEffectManager'.static.GetClientEffectManager().Stop(CE_ChargeUp, ChargeEffectGuid, FALSE);
        if (SFXPawn_Player(Instigator).IsLocallyControlled())
        {
            WeaponPlayWwiseEvent(PowerDownSound1);
        }
        else
        {
            WeaponPlayWwiseEvent(NPCPowerDownSound1);
        }
        GunIsCold();
        ClearTimer('GunIsHot');
    }
}
public simulated function WeaponFired(byte FiringMode, bool bViaReplication, optional Vector HitLocation)
{
    Super.WeaponFired(FiringMode, bViaReplication, HitLocation);
    LastFireTime = WorldInfo.GameTimeSeconds;
}
public simulated function bool CanReload()
{
    local BioPawn Pawn;
    
    Pawn = BioPawn(Instigator);
    if (Pawn != None && Pawn.CanReload() == FALSE)
    {
        return FALSE;
    }
    return (bWeaponCanBeReloaded && CollectorAmmoUsedCount > 0) && HasSpareAmmo();
}
public simulated function DoReload()
{
    __OnWeaponReload__Delegate(Self);
    UpdateCollectorAmmoUsedCount(CollectorAmmoUsedCount - 1);
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
public simulated function int GetAmmoCountInMagazine()
{
    return GetMagazineSize() - CollectorAmmoUsedCount;
}
public simulated function int GetAmmoRestoredPerReload()
{
    return int(float(GetCurrentSpareAmmo()) - FMax(float(GetCurrentSpareAmmo() - CollectorAmmoUsedCount), 0.0));
}
public simulated function int GetCurrentSpareAmmo()
{
    return 0;
}
public simulated function float GetFireModeBaseDamage()
{
    local float BaseDamage;
    
    BaseDamage = Super(SFXWeapon_SniperRifle_Base).GetFireModeBaseDamage();
    if (bIsHot)
    {
        BaseDamage *= ProtheanDamageMultiplier;
    }
    return BaseDamage;
}
public static simulated function ParticleSystem GetWeaponSpecificImpactEffect(SFXPhysicalMaterialImpactEffects ImpactEffects);

public simulated function WwiseEvent GetWeaponSpecificImpactSound(SFXPhysicalMaterialImpactSounds ImpactSounds);

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
public simulated function ResetAmmoOnHolster()
{
    if (bInfiniteAmmo)
    {
        UpdateCollectorAmmoUsedCount(0);
    }
}
public simulated function bool ShouldAutoReload()
{
    if (!Instigator.IsLocallyControlled())
    {
        return FALSE;
    }
    return (CanReload() && GetMagazineSize() > 0) && CollectorAmmoUsedCount >= GetMagazineSize();
}
public simulated function ShutOffAllEmitters()
{
    Class'RvrClientEffectManager'.static.GetClientEffectManager().Stop(CE_ChargeUp, ChargeEffectGuid, FALSE);
    Super(SFXWeapon).ShutOffAllEmitters();
}
public simulated function ConsumeAmmoCollector(byte FireModeNum)
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
    OldAmmoUsedCount = CollectorAmmoUsedCount;
    UpdateCollectorAmmoUsedCount(int(float(CollectorAmmoUsedCount) + AmmoPerShot));
    if (Instigator != None && Instigator.IsHumanControlled())
    {
        PC = BioPlayerController(Instigator.Controller);
        if (PC != None && PC.IsLocalPlayerController())
        {
            PC.HintSystem.HintEvent('Fire', Class.Name);
        }
        Class'WwiseAudioComponent'.static.SetGlobalRTPCFromScript(AmmoRTPCName, 1.0 - float(CollectorAmmoUsedCount / GetMagazineSize()));
    }
    if (float(MagazineSize - CollectorAmmoUsedCount) <= LowAmmoSoundThreshold && Instigator.IsHumanControlled())
    {
        if (float(MagazineSize - OldAmmoUsedCount) >= LowAmmoSoundThreshold)
        {
            WeaponPlayWwiseEvent(NeedReloadNotifySound, 0.0);
            if ((Instigator.Role == ENetRole.ROLE_Authority && Instigator.IsHumanControlled()) && CurrentSpareAmmo == 0)
            {
                SFXGRI(WorldInfo.GRI).TriggerVocalizationEvent(105, BioPawn(Instigator), , , , TRUE);
            }
        }
        if (MagazineSize - CollectorAmmoUsedCount == 0 && CurrentSpareAmmo == 0)
        {
            SFXGRI(WorldInfo.GRI).TriggerVocalizationEvent(106, BioPawn(Instigator));
        }
    }
    if (float(GetMagazineSize() - CollectorAmmoUsedCount) < SteamSoundThreshold && Instigator.IsHumanControlled())
    {
        if (float(GetMagazineSize() - OldAmmoUsedCount) >= SteamSoundThreshold)
        {
            WeaponPlayWwiseEvent(SteamReloadNotifySound, 0.0);
        }
    }
    if (MagazineSize >= 0 && float(CollectorAmmoUsedCount) + AmmoPerShot > float(MagazineSize))
    {
        if (SFXPawn_Player(Owner) != None && SFXPawn_Player(Owner).OutOfAmmoTimestamp == 0.0)
        {
            SFXPawn_Player(Owner).OutOfAmmoTimestamp = WorldInfo.GameTimeSeconds;
        }
        // MILAN CHANGE - Remove ammo telemetry
        //if (Instigator.IsHumanControlled() && OutOfAmmo())
        //{
        //  Class'SFXTelemetry'.static.SendString('TelemetryHook_OutOfAmmo', Class'SFXTelemetry'.static.GenerateUniqueClassId(Self));
        //  GLogger = Class'BioRemoteLogger'.static.GetLogger();
        //  if (GLogger != None)
        //  {
        //      GLogger.SendPlayerEvent(69, "", "", "", "", 0, 0, 0, 0);
        //  }
        //}
    }
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
public simulated function PlayRechargeSound()
{
    bCanPlayRechargeSound = TRUE;
}
public simulated function PlayReloadHeat()
{
    Class'RvrClientEffectManager'.static.GetClientEffectManager().Play(CE_HeatVent, Instigator);
}
public simulated function PlayReloadSteam()
{
    Class'RvrClientEffectManager'.static.GetClientEffectManager().Play(CE_SteamVent, Instigator);
}
public simulated function RechargeAmmo(float DeltaTime)
{
    local int AmmoRounded;
    local float fMagSize;
    
    fMagSize = float(GetMagazineSize());
    AccumulatedAmmo += (RechargeRatePerSecond * DeltaTime) * fMagSize;
    AccumulatedAmmo = FClamp(AccumulatedAmmo, 0.0, float(CollectorAmmoUsedCount));
    if (AccumulatedAmmo >= 1.0)
    {
        AmmoRounded = int(AccumulatedAmmo);
        UpdateCollectorAmmoUsedCount(CollectorAmmoUsedCount - AmmoRounded);
        AccumulatedAmmo -= float(AmmoRounded);
        if (CollectorAmmoUsedCount == 0 && bCanPlayRechargeSound == TRUE)
        {
            WeaponPlayWwiseEvent(WeaponReloadRechargeSound, 0.0);
            bCanPlayRechargeSound = FALSE;
            SetTimer(RechargeSoundDelay, FALSE, 'PlayRechargeSound', );
        }
    }
}
public reliable server function ServerDoReload()
{
    ClientDoReloadTrigger++;
    ClientDoReloadTriggerReplicationTime = WorldInfo.TimeSeconds + 3.0;
    StopMuzzleFlashEffect();
    Super(Weapon).SendToFiringState(4);
}
public simulated function UpdateCollectorAmmoUsedCount(int Count)
{
    CollectorAmmoUsedCount = Count;
    AmmoUsedCount = CollectorAmmoUsedCount;
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

// States
simulated state Reloading 
{
    // State Functions
    public simulated function DoAReload()
    {
        Super(SFXWeapon).DoAReload();
        SetTimer(SteamDelay, FALSE, 'PlayReloadSteam', );
        SetTimer(HeatDelay, FALSE, 'PlayReloadHeat', );
    }
    
    // State code
    stop;
};
simulated state WeaponPuttingDown 
{
    // State Functions
    public simulated function BeginState(Name PreviousStateName)
    {
        Class'RvrClientEffectManager'.static.GetClientEffectManager().Stop(CE_ChargeUp, ChargeEffectGuid, FALSE);
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
        Class'RvrClientEffectManager'.static.GetClientEffectManager().Stop(CE_ChargeUp, ChargeEffectGuid, FALSE);
        Super(SFXWeapon).BeginState(PreviousStateName);
    }
    
    // State code
    stop;
};

replication
{
    if ((((!bNetInitial && !bNetOwner) && bNetDirty) && Role == ENetRole.ROLE_Authority) && WorldInfo.TimeSeconds < ClientDoReloadTriggerReplicationTime)
        ClientDoReloadTrigger;
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    Begin Template Class=ForceFeedbackWaveform Name=EjectRumble0
    End Template
    Begin Template Class=ForceFeedbackWaveform Name=ForceFeedbackWaveformBase
        Samples = ({Duration = 0.200000003, LeftAmplitude = 100, RightAmplitude = 100, LeftFunction = EWaveformFunction.WF_LinearIncreasing, RightFunction = EWaveformFunction.WF_LinearIncreasing}, 
                   {Duration = 0.25, LeftAmplitude = 100, RightAmplitude = 100, LeftFunction = EWaveformFunction.WF_Constant, RightFunction = EWaveformFunction.WF_Constant}
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
        Template = ParticleSystem'BioVFX_MP4_ColSnipe.Particles.Hvy_Wpn_Beam_Snipe'
        bAutoActivate = FALSE
        ReplacementPrimitive = None
        bIgnoreHiddenActorsMembership = TRUE
    End Object
    Begin Template Class=ParticleSystemComponent Name=OutOfAmmoEffect0
        Template = ParticleSystem'BioVFX_C_Reload.Particles.Reload_VentHeat'
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
    Begin Object Class=SFXAnimSetCookSpec Name=tempAnimInfo
        AnimSet = AnimSet'BIOG_DLC_MP4_CBT_A.HMM_CB_ProtheanRifleReload'
    End Object
    Begin Template Class=SFXCameraSetup Name=CameraSetup0
        Begin Template Class=SFXCameraMode_Combat Name=Aimback0
        End Template
        Begin Template Class=SFXCameraMode_Combat Name=BlindLeftCrouch0
        End Template
        Begin Template Class=SFXCameraMode_Combat Name=BlindLeftStand0
        End Template
        Begin Template Class=SFXCameraMode_Combat Name=BlindRightCrouch0
        End Template
        Begin Template Class=SFXCameraMode_Combat Name=BlindRightStand0
        End Template
        Begin Template Class=SFXCameraMode_Combat Name=CombatCam0
        End Template
        Begin Template Class=SFXCameraMode_Combat Name=DefaultCrouch0
        End Template
        Begin Template Class=SFXCameraMode_Combat Name=DefaultStand0
        End Template
        Begin Template Class=SFXCameraMode_Combat Name=PeekLeftCrouch0
        End Template
        Begin Template Class=SFXCameraMode_Combat Name=PeekLeftStand0
        End Template
        Begin Template Class=SFXCameraMode_Combat Name=PeekRightCrouch0
        End Template
        Begin Template Class=SFXCameraMode_Combat Name=PeekRightStand0
        End Template
        Begin Template Class=SFXCameraMode_Combat Name=PowerCover0
        End Template
        Begin Template Class=SFXCameraMode_Combat Name=PowerCoverMidLeft0
        End Template
        Begin Template Class=SFXCameraMode_Combat Name=PowerCoverMidRight0
        End Template
        Begin Template Class=SFXCameraMode_Combat Name=PowerCoverStdLeft0
        End Template
        Begin Template Class=SFXCameraMode_Combat Name=PowerCoverStdRight0
        End Template
        Begin Template Class=SFXCameraMode_CombatStorm Name=CombatStormCam0
        End Template
        Begin Template Class=SFXCameraMode_EnterCover Name=EnterCoverCam0
        End Template
        Begin Template Class=SFXCameraMode_Explore Name=ExploreCam0
        End Template
        Begin Template Class=SFXCameraMode_ExploreStorm Name=ExploreStormCam0
        End Template
        Begin Template Class=SFXCameraMode_HipAimCover Name=BlindUp0
        End Template
        Begin Template Class=SFXCameraMode_HitReaction Name=HitReact0
        End Template
        Begin Template Class=SFXCameraMode_LadderDown Name=LadderDown0
        End Template
        Begin Template Class=SFXCameraMode_LadderUp Name=LadderUp0
        End Template
        Begin Template Class=SFXCameraMode_Melee Name=MeleeCam0
        End Template
        Begin Template Class=SFXCameraMode_Roll Name=RollCam0
        End Template
        Begin Template Class=SFXCameraMode_SplitScreenCombat Name=SSCombatCam0
        End Template
        Begin Template Class=SFXCameraTransition_ZoomSnap Name=ZoomSnapTransition0
        End Template
        CombatCam = CombatCam0
        RollCam = RollCam0
        ExploreCam = ExploreCam0
        CombatStormCam = CombatStormCam0
        ExploreStormCam = ExploreStormCam0
        SSCombatCam = SSCombatCam0
        EnterCoverCam = EnterCoverCam0
        MeleeCam = MeleeCam0
        LadderUp = LadderUp0
        LadderDown = LadderDown0
        HitReact = HitReact0
        ZoomSnapTransition = ZoomSnapTransition0
        DefaultCrouch = DefaultCrouch0
        DefaultStand = DefaultStand0
        PeekLeftCrouch = PeekLeftCrouch0
        PeekLeftStand = PeekLeftStand0
        PeekRightCrouch = PeekRightCrouch0
        PeekRightStand = PeekRightStand0
        DefaultAimback = Aimback0
        BlindLeftCrouch = BlindLeftCrouch0
        BlindLeftStand = BlindLeftStand0
        BlindRightCrouch = BlindRightCrouch0
        BlindRightStand = BlindRightStand0
        BlindUp = BlindUp0
        PowerCoverPopup = PowerCover0
        PowerCoverMidLeanLeft = PowerCoverMidLeft0
        PowerCoverMidLeanRight = PowerCoverMidRight0
        PowerCoverStdLeanLeft = PowerCoverStdLeft0
        PowerCoverStdLeanRight = PowerCoverStdRight0
    End Template
    Begin Template Class=SFXModule_GameEffectManager Name=GEMod0
    End Template
    Begin Template Class=SFXModule_WeaponModManager Name=ModManager0
    End Template
    Begin Template Class=SkeletalMeshComponent Name=PickupMesh
        SkeletalMesh = SkeletalMesh'BIOG_WPN_SNP_M_CON_MP4.WPN_SNPm_MDL'
        ReplacementPrimitive = None
    End Template
    Begin Template Class=SkeletalMeshComponent Name=WeaponMesh
        SkeletalMesh = SkeletalMesh'BIOG_WPN_SNP_M_CON_MP4.WPN_SNPm_MDL'
        AnimTreeTemplate = AnimTree'biog_animtree_weapon.BIOG_WPN_Main_O'
        PhysicsAsset = PhysicsAsset'BIOG_PHY_Weapons_F_CON_MP4.WPN_PHY_SNPm'
        AnimSets = (AnimSet'BIOG_WPN_A_CON_MP4.WPN_SNPm_Main')
        ReplacementPrimitive = None
    End Template
    HoldShake = {
                 RotAmplitude = {X = 50.0, Y = 25.0, Z = 40.0}, 
                 RotFrequency = {X = 125.0, Y = 50.0, Z = 50.0}, 
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
    PartialRechargeDelay = 1.0
    FullRechargeDelay = 3.0
    CE_HeatVent = RvrClientEffect'BioVFX_MP4_ColSnipe.VCFX.ColSnipe_Overheat'
    CE_SteamVent = RvrClientEffect'BioVFX_MP4_ColSnipe.VCFX.ColSnipe_Overheat_2'
    TimeToHeatUp = 0.25
    TimeToHeatUpAI = 1.0
    ProtheanDamageMultiplier = 4.0
    SteamDelay = 0.25
    HeatDelay = 0.699999988
    CE_ChargeUp = RvrClientEffect'BioVFX_MP4_ColSnipe.VCFX.ColSnipe_Idle'
    PowerUpSound1 = WwiseEvent'Wwise_Weapons_S_ColSniper.Play_wep_p_colsniper_start'
    PowerDownSound1 = WwiseEvent'Wwise_Weapons_S_ColSniper.Stop_wep_p_colsniper_stop'
    NPCPowerUpSound1 = WwiseEvent'Wwise_Weapons_S_ColSniper.Play_wep_np_colsniper_start'
    NPCPowerDownSound1 = WwiseEvent'Wwise_Weapons_S_ColSniper.Play_wep_np_colsniper_stop'
    WeaponReloadRechargeSound = WwiseEvent'Wwise_Weapons_S_ColSniper.Play_wep_s_colsniper_recharge'
    RechargeSoundDelay = 2.0
    bCanPlayRechargeSound = TRUE
    BeamInterpSpeed = {X = 20.0, Y = 20.0}
    DecalFrequency = 5
    BeamInterpTime = 0.5
    VFXUpdateInterval = 0.00999999978
    BeamVisualInterpSpeed = 20.0
    BeamVisualConvergedDot = 0.99999
    ActivateSniperZoomWwiseEvent = WwiseEvent'Wwise_Weapons_S_ColSniper.Play_wep_p_colsniper_zoom_in'
    DeActivateSniperZoomWwiseEvent = WwiseEvent'Wwise_Weapons_S_ColSniper.Play_wep_p_colsniper_zoom_out'
    SniperRifleDamagePenalty = 0.75
    AI_AccCone_Min = {X = 1.20000005, Y = 1.20000005}
    AI_AccCone_Max = {X = 1.79999995, Y = 1.79999995}
    ReloadDuration = {X = 5.0, Y = 5.0}
    Damage = {X = 66.6999969, Y = 83.4000015}
    MagSize = {X = 25.0, Y = 35.0}
    MaxSpareAmmo = {X = 1000000.0, Y = 1000000.0}
    MinAimError = {X = 0.0, Y = 0.0}
    MaxAimError = {X = 0.0, Y = 0.0}
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
    StatBarDamage = {X = 66.6999969, Y = 83.4000015}
    StatBarRateOfFire = {X = 800.0, Y = 800.0}
    GUIImage = "GUI_MPImages_MP4.snp_collector_512x256"
    NotificationImage = "GUI_MPImages_MP4.snp_collector_256x128"
    WeaponModBodyColours = ({R = 1.0, G = 0.239999995, B = 0.180000007, A = 0.0}, 
                            {R = 1.0, G = 0.74000001, B = 0.300000012, A = 0.0}, 
                            {R = 0.370000005, G = 0.50999999, B = 0.25, A = 0.0}, 
                            {R = 0.379999995, G = 0.389999986, B = 0.649999976, A = 0.0}, 
                            {R = 0.0799999982, G = 0.0900000036, B = 0.150000006, A = 0.0}
                           )
    GUIZoomReticleClass = Class'SFXGUI_CollectorSniperZoomReticle'
    FiringShake = {
                   RotAmplitude = {X = 45.0, Y = 25.0, Z = 40.0}, 
                   RotFrequency = {X = 125.0, Y = 50.0, Z = 50.0}, 
                   LocAmplitude = {X = 4.0, Y = 0.0, Z = 0.0}, 
                   TimeDuration = 0.100000001
                  }
    TightAimFiringShake = {
                           RotAmplitude = {X = 45.0, Y = 25.0, Z = 40.0}, 
                           RotFrequency = {X = 125.0, Y = 50.0, Z = 50.0}, 
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
    PS_DefaultImpactEffect = ParticleSystem'BioVFX_MP4_ColSnipe.Particles.ColSnipe_Impact'
    PS_DefaultMaterialImpactEffect = ParticleSystem'BioVFX_MP4_ColSnipe.Particles.ColSnipe_Impact'
    DefaultDecalMaterial = None
    PSC_ShellCasing = ShellCasingPSC0
    PSC_ReloadVent = ReloadVent0
    PSC_MuzFlashEmitter = MuzFlashPSC0
    EjectShellCasingTimeRatio = 0.800000012
    SteamSoundThreshold = 1.0
    NoAmmoFireSoundDelay = 0.5
    RateOfFireAI = 1.0
    RecoilInterpSpeed = 1.0
    RecoilFadeSpeed = 1.0
    RecoilZoomFadeSpeed = 1.0
    TraceRange = 4000.0
    IdealMinRange = 300.0
    IdealTargetDistance = 800.0
    IdealMaxRange = 1000.0
    IconResource = GFxMovieInfo'GUI_SF_ME3_DLC_CollctSnp.ME3_DLC_CollctSnp'
    PrettyName = $766350
    ShortPrettyName = $766350
    ShortDescription = $766351
    GeneralDescription = $766352
    DefaultImpactSound = WwiseEvent'Wwise_Weapons_S_ColSniper.Play_wep_s_colsniper_impact'
    FireNoAmmoSound = WwiseEvent'Wwise_Weapons_Standard_LowAmmo.Play_weapon_dryfire_shotguns'
    WeaponReloadSound = WwiseEvent'Wwise_Weapons_S_ColSniper.Play_wep_s_colsniper_overheat'
    WeaponSteamReloadSound = WwiseEvent'Wwise_Weapons_Generic.Play_wep_g_noammo_large_alien_sweetener'
    WeaponExpandSound = WwiseEvent'Wwise_Weapons_S_ColSniper.Play_wep_s_colsniper_expand'
    WeaponCollapseSound = WwiseEvent'Wwise_Weapons_S_ColSniper.Play_wep_s_colsniper_collapse'
    AmmoPowerPSCO = AmmoPowerHologram
    AmmoPowerIconPSCO = AmmoPowerIconHologram
    CameraSetup = CameraSetup0
    bSuppressTracers = TRUE
    bZoomSnapEnabled = FALSE
    DefaultFireMode = FireModes.FireMode_FullAuto
    AnimType = WeaponAnimType.WeaponAnimType_Rifle
    bInfiniteAmmo = TRUE
    InstantHitMomentum = (0.0, 10.0, 0.0, 1.0)
    InstantHitDamageTypes = (None, Class'SFXDamageType_Default', Class'SFXDamageType_CollectorSniper', Class'SFXDamageType_Default')
    FireOffset = {X = 61.0, Y = -0.5, Z = 7.25}
    Mesh = WeaponMesh
    DroppedPickupMesh = PickupMesh
    PickupFactoryMesh = PickupMesh
    Components = (WeaponMesh)
    Modules = (GEMod0, ModManager0)
}