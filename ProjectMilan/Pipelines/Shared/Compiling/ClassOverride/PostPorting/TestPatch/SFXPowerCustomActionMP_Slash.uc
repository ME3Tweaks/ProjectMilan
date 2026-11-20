// Source: ME3, Patch_SFXPowerCustomActionMP_Slash
// Decompiled 11/17/2026 7:38:28 AM against N7_Infiltrator_MP.pcc
Class SFXPowerCustomActionMP_Slash extends SFXPowerCustomAction
    config(Game);

var config SFXPowerCustomActionBase.PowerData Range;
var config SFXPowerCustomActionBase.PowerData NumShockwaveImpacts;
var config SFXPowerCustomActionBase.PowerData GravityLevel;
var config SFXPowerCustomActionBase.PowerData GravityDuration;
var config SFXPowerCustomActionBase.PowerData TimeBetweenImpacts;
var config SFXPowerCustomActionBase.PowerData EarlyImpactRadius;
var config SFXPowerCustomActionBase.PowerData MaximumEarlyImpactTargets;
var array<Actor> ImpactedActors;
var Class<SFXRumble_Power> ImpactRumbleClass;
var Class<SFXShake_Power> ImpactScreenShakeClass;
var Class<SFXShake_Power> ImpactActorScreenShakeClass;
var const Class<SFXDamageType> EarlyImpactDamageType;
var config SFXPreAsyncWorkTicker.AreaEffectParameters EarlyImpactParameters;
var Object.Guid GUID_Slash;
var Name SwordSocket;
var const RvrClientEffectInterface CE_Slash;
var const WwiseEvent ImpactActorSound;
var const WwiseEvent EarlySlashSound;
var const RvrClientEffectInterface CE_ShockwaveImpact;
var const ParticleSystem PS_Slice;
var float SliceDistance;
var instanced StaticMeshComponent SwordMesh;
var config float GravityValue;
var config float GravityEffectDuration;
var config float StopMovementDuration;
var config float EarlyImpactDamagePercent;
var config float LeaveCoverDistance;
var config float ForceEndLeaveCoverTime;
var const float EarlyImpactTime1;
var const float EarlyImpactTime2;
var int NumTargetsHit;
var bool bDoingEarlyImpact;

public function bool CanUsePower(Actor oTarget)
{
    if (m_oPawn.CoverType == ECoverType.CT_Standing && m_oPawn.CoverAction != ECoverAction.CA_Aimback && !CanLeaveCoverRight(m_oPawn.CoverAction) && !CanLeaveCoverLeft(m_oPawn.CoverAction))
    {
        return FALSE;
    }
    return Super.CanUsePower(oTarget);
}
public function bool LeaveCover()
{
    local bool SetDestination;
    
    if (CanLeaveCoverRight(m_oPawn.CoverAction))
    {
        SetReachPreciseDestination(m_oPawn.location + (Vector(m_oPawn.Rotation) >> rot(0, 8192, 8192)) * LeaveCoverDistance);
        SetDestination = TRUE;
    }
    else if (CanLeaveCoverLeft(m_oPawn.CoverAction))
    {
        SetReachPreciseDestination(m_oPawn.location + (Vector(m_oPawn.Rotation) >> rot(0, -8192, 0)) * LeaveCoverDistance);
        SetDestination = TRUE;
    }
    if (SetDestination)
    {
        ERootMotionMode = ERootMotionMode.RMM_Translate;
    }
    return SetDestination;
}
public function bool ShouldUsePower(Actor Target, out string sOptionalInfo)
{
    local BioPawn oPawn;
    
    oPawn = BioPawn(Target);
    if (oPawn == None)
    {
        return TRUE;
    }
    if (Target != None && VSizeSq(Target.location - m_oPawn.location) > Range.CurrentValue * Range.CurrentValue)
    {
        return FALSE;
    }
    if (int(oPawn.GetCurrentResistance()) != 0)
    {
        return ShouldUsePowerOnShields(oPawn, DefaultDamageType, sOptionalInfo);
    }
    return TRUE;
}
public function StartCustomAction()
{
    local BioPlayerController PC;
    local bool LeftCover;
    
    LeftCover = LeaveCover();
    m_oPawn.LeaveCover();
    Super(BioCustomAction).StartCustomAction();
    if (VocalizationEvent != ESFXVocalizationEventID.SFXVocalizationEvent_None && SFXGRI(m_oPawn.WorldInfo.GRI) != None)
    {
        SFXGRI(m_oPawn.WorldInfo.GRI).TriggerVocalizationEvent(VocalizationEvent, m_oPawn, None, 0.0);
    }
    PC = BioPlayerController(m_oPawn.Controller);
    if (CastCameraAnim != None && PC != None && PC.PlayerCamera != None)
    {
        PC.PlayerCamera.PlayCameraAnim(CastCameraAnim, CameraAnimPlayRate, 1.0, CameraAnimBlendIn, CameraAnimBlendOut, FALSE, FALSE, CameraAnimDuration, TRUE);
    }
    if (LeftCover)
    {
        WaitingOnLeanOut = TRUE;
        m_oPawn.SetTimer(ForceEndLeaveCoverTime, FALSE, 'ForceEndLeaveCover', Self);
    }
    else
    {
        StartCastAnimations();
    }
}
public event function TickCustomAction(float fDeltaTime)
{
    local SFXAI_Henchman Henchman;
    local SFXModule_GameEffectManager GameEffectManager;
    local float CooldownMultiplier;
    
    Super(BioCustomAction).TickCustomAction(fDeltaTime);
    TimeSinceStart += fDeltaTime;
    if (CurrentCooldownTime > float(0))
    {
        GameEffectManager = m_oPawn.GetModule(Class'SFXModule_GameEffectManager');
        CooldownMultiplier = 1.0;
        if (GameEffectManager != None)
        {
            CooldownMultiplier = GameEffectManager.GlobalCooldownBonus.Value;
        }
        CurrentCooldownTime -= fDeltaTime * CooldownMultiplier;
        if (CurrentCooldownTime < float(0))
        {
            CurrentCooldownTime = 0.0;
            if (BioPlayerController(m_oPawn.Controller) != None)
            {
                BioPlayerController(m_oPawn.Controller).ConsoleCommand("ResetForcedCooldown");
            }
        }
        if (CurrentCooldownTime == float(0))
        {
            Henchman = m_oPawn != None ? SFXAI_Henchman(m_oPawn.Controller) : None;
            if (Henchman != None)
            {
                Henchman.PowerCooldownFinished();
            }
        }
    }
    if (TimeUntilNextUse > 0.0)
    {
        TimeUntilNextUse -= fDeltaTime;
        if (TimeUntilNextUse < 0.0)
        {
            TimeUntilNextUse = 0.0;
        }
    }
    if (WaitingOnLeanOut)
    {
        if (!bReachPreciseDestination)
        {
            WaitingOnLeanOut = FALSE;
            StartCastAnimations();
        }
    }
    else if (bPowerStarted && !bPowerReleased && TimeSinceStart >= ReleaseTime && !m_oPawn.IsBlindFiring())
    {
        ReleasePower();
    }
}
public function ClientDoPowerSubsequentImpact(Actor oActor, optional int CustomActionReactionType, optional float Duration, optional int ImpactCount, optional float Delay, optional bool DoCallback)
{
    local Object.Vector ImpactLocation;
    
    if (Projectiles.Length > 0 && Projectiles[0] != None)
    {
        ImpactLocation = Projectiles[0].location;
    }
    else
    {
        ImpactLocation = m_oPawn.location;
    }
    if (BioPawn(oActor) != None)
    {
        BioPawn(oActor).ClientPlayAnimatedReaction(CustomActionReactionType);
    }
    DoSubsequentImpact(oActor, ImpactLocation, ImpactCount);
}
public function DoImpact(Object.Vector location, Object.Rotator ProjectileRotation, int ImpactNumber)
{
    if (ImpactNumber % 2 == 1)
    {
        if (SFXPawn_Player(m_oPawn).IsLocallyControlled())
        {
            PlayImpactSounds(location, ImpactSound, EvolvedImpactSounds);
        }
        else
        {
            PlayImpactSounds(location, HenchmanImpactSound, HenchmanEvolvedImpactSounds);
        }
        if (ImpactRumbleClass != None)
        {
            PlayPowerControllerRumble(ImpactRumbleClass, location);
        }
        if (ImpactScreenShakeClass != None)
        {
            PlayPowerScreenShake(ImpactScreenShakeClass, location);
        }
        if (CE_ShockwaveImpact != None)
        {
            Class'RvrClientEffectManager'.static.GetClientEffectManager().PlayAtLocation(CE_ShockwaveImpact, location, -Vector(ProjectileRotation), GetDefaultClientEffectParams());
        }
    }
    InternalDoImpact(location, ProjectileRotation, ImpactNumber, DetonationParameters, ImpactRadius.CurrentValue, int(MaximumImpactTargets.CurrentValue));
}
public function bool GetCustomActionCamera(out SFXCameraMode oNewCameraMode, out float fTransitionIn, out float fTransitionOut)
{
    local SFXPlayerController PC;
    
    PC = SFXPlayerController(m_oPawn.Controller);
    if (PC != None && PlayerCameraMode != None)
    {
        if (oPlayerCamera == None)
        {
            oPlayerCamera = new (PC.GetGameModeDefault()) PlayerCameraMode;
        }
        oNewCameraMode = oPlayerCamera;
        fTransitionIn = fCameraTransitionIn;
        fTransitionOut = fCameraTransitionOut;
        return TRUE;
    }
    return FALSE;
}
public function float GetImpactDamage(Actor oImpacted, out Class<SFXDamageType> DamageType)
{
    if (bDoingEarlyImpact)
    {
        DamageType = EarlyImpactDamageType;
        return Damage.CurrentValue * EarlyImpactDamagePercent;
    }
    else
    {
        DamageType = DefaultDamageType;
        return Damage.CurrentValue;
    }
}
public function OnPowerDetonated(Object.Vector HitLocation, Object.Vector HitNormal, optional SFXProjectile_PowerCustomAction oProjectile, optional Actor HitActor);

public function OnRagdollPhysicsImpact(Pawn oPawn, Actor oImpactActor, Object.Vector vImpactDir)
{
    local BioPawn oBioPawn;
    
    oBioPawn = BioPawn(oPawn);
    if (oBioPawn != None)
    {
        oBioPawn.m_bRagdollEnteredPendingBodyFallSound = TRUE;
    }
    RagdollPhysicsImpact(oPawn, oImpactActor, vImpactDir);
}
public function RecalculateAllPowerData(optional bool bReset = FALSE)
{
    Super(SFXPowerCustomActionBase).RecalculateAllPowerData(bReset);
    RecalculatePowerData(NumShockwaveImpacts, bReset);
    RecalculatePowerData(TimeBetweenImpacts, bReset);
    RecalculatePowerData(GravityDuration, bReset);
    RecalculatePowerData(GravityLevel, bReset);
    RecalculatePowerData(Range, bReset);
    RecalculatePowerData(EarlyImpactRadius, bReset);
    RecalculatePowerData(MaximumEarlyImpactTargets, bReset);
}
public function StartCastAnimations()
{
    local RvrClientEffectInterface.RvrClientEffectTarget CETarget;
    
    m_oPawn.ClearTimer('ForceEndLeaveCover', Self);
    RestoreCoverAction = FALSE;
    TimeSinceStart = 0.0;
    ERootMotionMode = default.ERootMotionMode;
    Super.StartCastAnimations();
    AttachSword();
    CETarget.Instigator = m_oPawn;
    GUID_Slash = Class'RvrClientEffectManager'.static.GetClientEffectManager().StartOnTarget(CE_Slash, CETarget);
    if (m_oPawn != None && EarlyImpactRadius.CurrentValue > 0.0)
    {
        if (EarlyImpactTime1 > 0.0)
        {
            m_oPawn.SetTimer(EarlyImpactTime1, FALSE, 'FirstEarlyImpact', Self);
        }
        if (EarlyImpactTime2 > 0.0)
        {
            m_oPawn.SetTimer(EarlyImpactTime2, FALSE, 'SecondEarlyImpact', Self);
        }
    }
    ImpactedActors.Length = 0;
    NumTargetsHit = 0;
    bDoingEarlyImpact = TRUE;
    ApplyTemporaryGameEffect(Pawn(m_oTargetToAimAt), Class'SFXGameEffect_MovementSpeedBonus', StopMovementDuration, -1.0, Name, m_oPawn.Controller);
}
public function StopCustomAction()
{
    DetachSwordMesh();
    StopSlash();
    m_oPawn.ClearTimer('FirstEarlyImpact', Self);
    m_oPawn.ClearTimer('SecondEarlyImpact', Self);
    m_oPawn.ClearTimer('StartCastAnimations', Self);
    m_oPawn.ClearTimer('ForceEndLeaveCover', Self);
    Super.StopCustomAction();
}
public function DoSubsequentImpact(Actor HitActor, Object.Vector ImpactLocation, int nImpactCount)
{
    local SFXPawn HitPawn;
    local Object.Vector HitNormal;
    local Actor.EPowerResistance Resistance;
    local Actor oTargetOverride;
    local float fDamage;
    local Object.Vector vInitialForce;
    local SFXModule_GameEffectManager Manager;
    local Class<SFXDamageType> dmgType;
    local bool bRagdolled;
    
    HitNormal = Normal(ImpactLocation - HitActor.location);
    fDamage = GetImpactDamage(HitActor, dmgType);
    if (MaximumRagdollTargets.CurrentValue > float(0) && float(NumTargetsHit) >= MaximumRagdollTargets.CurrentValue)
    {
        dmgType = GetNonRagdollDamageType();
    }
    HitPawn = SFXPawn(HitActor);
    if (HitPawn == None)
    {
        return;
    }
    if (bDoingEarlyImpact)
    {
        PlayDetonationEffects(HitActor.location, HitNormal);
    }
    vInitialForce = Normal(Normal(HitPawn.location - m_oPawn.location) + vect(0.0, 0.0, 1.0)) * Force.CurrentValue;
    Resistance = HitActor.GetPowerResistance(m_oPawn, ImpactLocation, HitNormal, fDamage, vInitialForce, dmgType, oTargetOverride);
    if (oTargetOverride != None)
    {
        HitActor = oTargetOverride;
    }
    HitActor.ImpactWithPower(Resistance, m_oPawn, ImpactLocation, HitNormal, fDamage, vInitialForce, dmgType);
    Manager = HitActor.GetModule(Class'SFXModule_GameEffectManager');
    if (Resistance == EPowerResistance.Resistance_None && GravityEffectDuration > 0.0)
    {
        bRagdolled = TRUE;
        Manager.CreateAndApplyEffect(Class'SFXGameEffect_AntiGravity', Name, GravityEffectDuration, 1, GravityValue, m_oPawn.Controller);
        HitPawn.RegisterRBCallback(OnRagdollPhysicsImpact, TRUE);
    }
    if (Resistance != EPowerResistance.Resistance_Full)
    {
        HitPawn.AddPowerAssistEvent(m_oPawn, DisplayName, bRagdolled ? PowerAssistFullControlValue : PowerAssistPartialControlValue);
    }
    if (nImpactCount == 0)
    {
        if (ImpactActorSound != None)
        {
            HitActor.PlaySound(ImpactActorSound, TRUE);
        }
        if (ImpactActorScreenShakeClass != None)
        {
            PlayPowerScreenShake(ImpactActorScreenShakeClass, ImpactLocation);
        }
    }
    CheckForPowerCombo(HitActor, Resistance, ImpactLocation, HitNormal);
    ImpactedActors.AddItem(HitActor);
    NumTargetsHit++;
    if (HitPawn != None && ShouldReplicate())
    {
        ReplicatePowerSubsequentImpact(HitPawn, HitPawn.CurrentCustomAction);
    }
}
public function AttachSword()
{
    if (m_oPawn.Mesh != None)
    {
        m_oPawn.Mesh.AttachComponentToSocket(SwordMesh, SwordSocket);
    }
}
private final function bool CanLeaveCoverLeft(CoverLink.ECoverAction CoverAction)
{
    return CoverAction == ECoverAction.CA_BlindLeft || CoverAction == ECoverAction.CA_LeanLeft || CoverAction == ECoverAction.CA_PeekLeft;
}
private final function bool CanLeaveCoverRight(CoverLink.ECoverAction CoverAction)
{
    return CoverAction == ECoverAction.CA_BlindRight || CoverAction == ECoverAction.CA_LeanRight || CoverAction == ECoverAction.CA_PeekRight;
}
public function DetachSwordMesh()
{
    if (m_oPawn.Mesh != None)
    {
        m_oPawn.Mesh.DetachComponent(SwordMesh);
    }
}
private final function EarlyImpact()
{
    local Object.Rotator Dir;
    
    if (EarlySlashSound != None)
    {
        m_oPawn.PlaySound(EarlySlashSound, TRUE);
    }
    InternalDoImpact(m_oPawn.location, m_oPawn.Rotation, 0, EarlyImpactParameters, EarlyImpactRadius.CurrentValue, int(MaximumEarlyImpactTargets.CurrentValue));
    if (PS_Slice != None)
    {
        if (m_oPawn.IsLocallyControlled())
        {
            Dir = m_oPawn.Controller.Rotation;
        }
        else
        {
            Dir = m_oPawn.Rotation;
        }
        SFXGRI(m_oPawn.WorldInfo.GRI).DuringAsyncWorker.SpawnEffectAtLocation(m_oPawn, PS_Slice, m_oPawn.location + SliceDistance * Vector(Dir), Dir);
    }
}
public function FirstEarlyImpact()
{
    EarlyImpact();
}
public function ForceEndLeaveCover()
{
    ResetReachPreciseDestination();
}
public function float GetRadiusBonus()
{
    return 0.0;
}
private final function InternalDoImpact(Object.Vector location, Object.Rotator ProjectileRotation, int ImpactNumber, SFXPreAsyncWorkTicker.AreaEffectParameters Params, float Radius, int MaxImpactTargets)
{
    local Actor HitActor;
    local array<Actor> NearbyActors;
    local int nImpactCount;
    
    if (m_oPawn != None && m_oPawn.Role == ENetRole.ROLE_Authority)
    {
        Params.ConeDirection = Vector(ProjectileRotation);
        Params.ConeAngle *= 1.0 + GetRadiusBonus();
        nImpactCount = 0;
        GetNearbyActors(NearbyActors, location, Radius, Radius, Params);
        foreach NearbyActors(HitActor, )
        {
            if (NumTargetsHit >= MaxImpactTargets)
            {
                break;
            }
            if (ImpactedActors.Find(HitActor) != -1)
            {
                continue;
            }
            DoSubsequentImpact(HitActor, location, nImpactCount);
            nImpactCount++;
        }
    }
}
public function SecondEarlyImpact()
{
    EarlyImpact();
    ImpactedActors.Length = 0;
    NumTargetsHit = 0;
    bDoingEarlyImpact = FALSE;
}
public final function StopSlash()
{
    Class'RvrClientEffectManager'.static.GetClientEffectManager().@Stop(CE_Slash, GUID_Slash, TRUE);
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    ERootMotionMode = ERootMotionMode.RMM_Accel
    PowerType = EPowerType.PowerType_Projectile
    HenchmanPowerType = EPowerType.PowerType_Projectile
    MoveSpeed = 1000.0
    bBreakFromCover = TRUE
    bDisableMovement = TRUE
    bHideWeapon = TRUE
    bProceduralMovement = TRUE
    VocalizationEvent = ESFXVocalizationEventID.SFXVocalizationEvent_Power_ShockWave
}