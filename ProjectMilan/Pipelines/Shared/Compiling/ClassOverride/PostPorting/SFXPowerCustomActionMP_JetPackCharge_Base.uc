// Source: LE3, N7Turian_Soldier_MP
// Initial decompilation: 9/7/2024 5:10:37 PM
// MILAN CHANGE - UP3
// Allow Havok Strike kills to trigger melee-passive kill bonuses
Class SFXPowerCustomActionMP_JetPackCharge_Base extends SFXPowerCustomAction
    config(Game);

struct Charge_PendingVolume 
{
    var(Charge_PendingVolume) Volume Volume;
    var(Charge_PendingVolume) bool bTouching;
};
const TELEPORT_VISIBLE_THRESHOLD = 0.5f;
const TELEPORT_HEIGHT_THRESHOLD = 1000.f;

var(SFXPowerCustomActionMP_JetPackCharge_Base) transient string FailedLineCheckName;
var(SFXPowerCustomActionMP_JetPackCharge_Base) array<Charge_PendingVolume> VolumeList;
var Class<SFXRumble_Power> CustomDetonationRumbleClass;
var Class<SFXShake_Power> CustomDetonationScreenShakeClass;
var(SFXPowerCustomActionMP_JetPackCharge_Base) ScreenShakeStruct HitShake;
var(SFXPowerCustomActionMP_JetPackCharge_Base) transient Vector CachedTeleportLocation;
var(SFXPowerCustomActionMP_JetPackCharge_Base) transient Vector CachedTargetLocation;
var(SFXPowerCustomActionMP_JetPackCharge_Base) transient Vector CachedStartingLocation;
var(SFXPowerCustomActionMP_JetPackCharge_Base) transient Vector FailedLineCheckStart;
var(SFXPowerCustomActionMP_JetPackCharge_Base) transient Vector FailedLineCheckEnd;
var config float FrozenTargetForceMult;
var config float ConeAngle;
var(SFXPowerCustomActionMP_JetPackCharge_Base) transient Pawn CachedTarget;
var(SFXPowerCustomActionMP_JetPackCharge_Base) float TeleportStartDelay;
var(SFXPowerCustomActionMP_JetPackCharge_Base) float TeleportDelay;
var(SFXPowerCustomActionMP_JetPackCharge_Base) float ImpactDelay;
var(SFXPowerCustomActionMP_JetPackCharge_Base) float ImpactDelay_Min;
var(SFXPowerCustomActionMP_JetPackCharge_Base) float ImpactDelay_Max;
var(SFXPowerCustomActionMP_JetPackCharge_Base) float TimeStingerDelay;
var(SFXPowerCustomActionMP_JetPackCharge_Base) float CameraImpactDelay;
var(SFXPowerCustomActionMP_JetPackCharge_Base) ParticleSystem PS_TeleportIn;
var(SFXPowerCustomActionMP_JetPackCharge_Base) ParticleSystem PS_TeleportOut;
var RvrClientEffectInterface CE_CrustEffect;
var RvrClientEffectInterface CE_JetCrustEffect;
var RvrClientEffectInterface CE_ChargeImpact;
var RvrClientEffectInterface CE_HeavyChargeImpact;
var(SFXPowerCustomActionMP_JetPackCharge_Base) SFXProjectile_PowerCustomActionMP_JetPack ChargeProjectile;
var(SFXPowerCustomActionMP_JetPackCharge_Base) SFXCameraTransition_VanguardSlam CamTransition;
var(SFXPowerCustomActionMP_JetPackCharge_Base) SFXCameraMode_TurianPack CamMode;
var(SFXPowerCustomActionMP_JetPackCharge_Base) ForceFeedbackWaveform HitForceFeedback;
var(SFXPowerCustomActionMP_JetPackCharge_Base) float CameraDelay;
var WwiseEvent ChargeCast;
var WwiseEvent HenchChargeCast;
var WwiseEvent ChargeImpact;
var WwiseEvent HenchChargeImpact;
var WwiseEvent ChargeTakeoff;
var WwiseEvent HenchChargeTakeoff;
var bool bCachedTargetImpacted;
var bool bUseOwnerRotation;
var transient bool bIsInputLocked;
var(SFXPowerCustomActionMP_JetPackCharge_Base) bool bFailedToMoveCaster;
var(SFXPowerCustomActionMP_JetPackCharge_Base) bool bCollectedVolumes;
var bool bLineCheckToHead;

public function bool CanUsePower(Actor oTarget)
{
    local BioPlayerController PC;
    local Vector TargetLocation;
    local Vector CamLocation;
    
    if (!Super.CanUsePower(oTarget))
    {
        return FALSE;
    }
    if (BioPawn(m_oTargetToAimAt) == None)
    {
        return FALSE;
    }
    if (m_oPawn != None && m_oPawn.IsHumanControlled())
    {
        if (m_oPawn.Role == ENetRole.ROLE_SimulatedProxy)
        {
            CachedTarget = BioPawn(m_oTargetToAimAt);
            CachedTeleportLocation = m_vLocationToAimAt;
            CachedTargetLocation = vect(0.0, 0.0, 0.0);
            return TRUE;
        }
        else
        {
            PC = BioPlayerController(m_oPawn.Controller);
            if (PC != None)
            {
                CachedTarget = BioPawn(m_oTargetToAimAt);
                if (CachedTarget != None && m_oPawn.IsHostile(CachedTarget) && ValidateTarget())
                {
                    if (PC.IsLocalPlayerController())
                    {
                        CamLocation = PC.PlayerCamera.CameraCache.POV.location;
                    }
                    else
                    {
                        CamLocation = PC.RemoteCameraLocation;
                    }
                    BioPawn(CachedTarget).GetAimNodeLocation(1, TargetLocation);
                    if (bLineCheckToHead && CachedTarget.FastTrace(TargetLocation, CamLocation, , TRUE))
                    {
                        return TRUE;
                    }
                    else
                    {
                        FailedLineCheckStart = TargetLocation;
                        FailedLineCheckEnd = CamLocation;
                        FailedLineCheckName = "Failed visibility test to head. Will try chest next.";
                        BioPawn(CachedTarget).GetAimNodeLocation(4, TargetLocation);
                        if (CachedTarget.FastTrace(TargetLocation, CamLocation, , TRUE))
                        {
                            return TRUE;
                        }
                        else
                        {
                            FailedLineCheckStart = TargetLocation;
                            FailedLineCheckEnd = CamLocation;
                            FailedLineCheckName = "Failed visibility test to chest";
                        }
                    }
                }
            }
        }
    }
    PlayFailedChargeEffects();
    return FALSE;
}
public function bool DoPowerDetonatedForActor(Actor oActor, Vector HitLocation, Vector HitNormal, int nImpactCount, bool bFirstTarget, optional SFXProjectile_PowerCustomAction oProjectile);

public static function PrecacheVFX(SFXObjectPool ObjectPool, RvrClientEffectManager ClientEffects)
{
    Super.PrecacheVFX(ObjectPool, ClientEffects);
    ObjectPool.PrecacheImpactEmitter(default.PS_TeleportOut);
    ObjectPool.PrecacheGenericParticleSystemComponent(default.PS_TeleportIn);
}
public function SpawnProjectile()
{
    ChargeProjectile = m_oPawn.Spawn(Class'SFXProjectile_PowerCustomActionMP_JetPack', m_oPawn, , m_oPawn.location, m_oPawn.Rotation);
    if (ChargeProjectile != None)
    {
        ChargeProjectile.Speed = VSize(CachedTarget.location - m_oPawn.location) / (ImpactDelay - TeleportDelay);
        ChargeProjectile.Init(Normal(CachedTarget.location - m_oPawn.location));
    }
}
public function StartCustomAction()
{
    local RvrClientEffectTarget CETarget;
    local float fDistanceToTarget;
    
    if (m_oPawn.Role < ENetRole.ROLE_Authority && InternalCanDoCustomAction(None, TRUE) == FALSE)
    {
        InterruptThisCustomAction();
        return;
    }
    Super.StartCustomAction();
    RestoreCoverAction = FALSE;
    if (m_oTargetToAimAt == None || Pawn(m_oTargetToAimAt) == None)
    {
        return;
    }
    m_oPawn.LeaveCover();
    bFailedToMoveCaster = FALSE;
    CachedTarget = Pawn(m_oTargetToAimAt);
    CachedStartingLocation = m_oPawn.location;
    fDistanceToTarget = VSize(CachedTarget.location - m_oPawn.location);
    fDistanceToTarget = FClamp(fDistanceToTarget / 4000.0, 0.0, 1.0);
    ImpactDelay = Lerp(ImpactDelay_Min, ImpactDelay_Max, fDistanceToTarget);
    m_oPawn.SetTimer(TeleportStartDelay, FALSE, 'StartTeleport', Self);
    m_oPawn.SetTimer(TeleportDelay, FALSE, 'Teleport', Self);
    m_oPawn.SetTimer(ImpactDelay, FALSE, 'Impact', Self);
    m_oPawn.SetTimer(CameraDelay, FALSE, 'CameraMove', Self);
    ApplyTemporaryGameEffect(m_oPawn, Class'SFXGameEffect_DamageImmunity', ImpactDelay, 0.0, Name, m_oPawn.Controller);
    ApplyTemporaryGameEffect(CachedTarget, Class'SFXGameEffect_MovementSpeedBonus', 1.0, -1.0, Name, m_oPawn.Controller);
    CETarget.Instigator = m_oPawn;
    Class'RvrClientEffectManager'.static.GetClientEffectManager().PlayOnTarget(CE_JetCrustEffect, CETarget);
    if (SFXPawn_Player(m_oPawn) != None && m_oPawn.Controller != None && m_oPawn.Controller.IsLocalPlayerController())
    {
        SFXGRI(m_oPawn.WorldInfo.GRI).PlayTransientSound(ChargeCast, m_oPawn.location);
    }
    else
    {
        SFXGRI(m_oPawn.WorldInfo.GRI).PlayTransientSound(HenchChargeCast, m_oPawn.location);
    }
}
public function Teleport()
{
    if (InternalCanDoCustomAction(None, TRUE) == FALSE)
    {
        InterruptThisCustomAction();
        return;
    }
    SpawnProjectile();
    FinalizePawnMove(CachedTeleportLocation, CachedTargetLocation);
    m_oPawn.SetPhysics(2);
    m_oPawn.LastPhysicsSetter = Self;
}
public function ClientDoPowerSubsequentImpact(Actor oActor, optional int CustomActionReactionType, optional float Duration, optional int ImpactCount, optional float Delay, optional bool DoCallback)
{
    if (ImpactCount == -3)
    {
        m_oPawn.SetLocation(CachedStartingLocation, );
        ResetPowerCooldown();
    }
    else
    {
        DetonationParameters.ConeDirection = Vector(m_oPawn.Rotation);
        if (oActor != None)
        {
            DoAreaExplosionForActor(oActor, m_oPawn.location, ImpactCount, Damage.CurrentValue, DefaultDamageType, Force.CurrentValue, DetonationParameters, 0, OnChargeImpact);
        }
        if (BioPawn(oActor) != None)
        {
            BioPawn(oActor).ClientPlayAnimatedReaction(CustomActionReactionType);
        }
    }
}
public function float GetImpactForce(Actor oImpacted)
{
    local float fForce;
    local SFXModule_GameEffectManager Manager;
    
    fForce = Force.CurrentValue;
    if (oImpacted != None)
    {
        Manager = oImpacted.GetModule(Class'SFXModule_GameEffectManager');
        if (Manager != None && (Manager.HasEffectOfType(Class'SFXGameEffect_CryoFreeze') || Manager.HasEffectOfType(Class'SFXGameEffect_DelayedCryoFreeze')))
        {
            fForce *= FrozenTargetForceMult;
        }
    }
    return fForce;
}
protected function bool InternalCanDoCustomAction(BioPawn SyncPawn, bool bForced)
{
    if (m_oPawn == None || m_oPawn.IsDead() || m_oPawn.Physics == EPhysics.PHYS_RigidBody)
    {
        return FALSE;
    }
    else
    {
        return Super.InternalCanDoCustomAction(SyncPawn, bForced);
    }
}
public function InterruptThisCustomAction()
{
    m_oPawn.ClearTimer('StartTeleport', Self);
    m_oPawn.ClearTimer('Teleport', Self);
    m_oPawn.ClearTimer('Impact', Self);
    if (ChargeProjectile != None)
    {
        ChargeProjectile.Destroy();
    }
    bCollectedVolumes = FALSE;
    m_oPawn.SetHidden(FALSE);
    m_oPawn.CustomTimeDilation = 1.0;
    if (m_oPawn.LastPhysicsSetter == Self && m_oPawn.Physics != EPhysics.PHYS_RigidBody)
    {
        if (OriginalRole != ENetRole.ROLE_SimulatedProxy)
        {
            m_oPawn.SetPhysics(2);
        }
        else
        {
            m_oPawn.SetPhysics(1);
        }
    }
    Super(BioCustomAction).InterruptThisCustomAction();
}
public function OnRagdollPhysicsImpact(Pawn oPawn, Actor oImpactActor, Vector vImpactDir)
{
    local BioPawn oBioPawn;
    
    oBioPawn = BioPawn(oPawn);
    if (oBioPawn != None)
    {
        oBioPawn.m_bRagdollEnteredPendingBodyFallSound = TRUE;
    }
    RagdollPhysicsImpact(oPawn, oImpactActor, vImpactDir);
}
public function Replicate()
{
    Super.Replicate();
    if (m_oPawn != None)
    {
        m_oPawn.ReplicatedCustomActionInfo.Target = CachedTarget;
        m_oPawn.ReplicatedCustomActionInfo.TargetLocation = CachedTeleportLocation;
    }
}
public function StopCustomAction()
{
    local PlayerController PC;
    
    PC = PlayerController(m_oPawn.Controller);
    if (PC != None && bIsInputLocked)
    {
        PC.IgnoreLookInput(FALSE);
        PC.IgnoreMoveInput(FALSE);
        bIsInputLocked = FALSE;
    }
    Super.StopCustomAction();
}
public function bool ValidateTarget()
{
    local Vector NewLocation;
    local Vector NewTargetLocation;
    local Vector Dir;
    local float MoveDist;
    local BioPawn oTargetPawn;
    
    if (m_oPawn != None && m_oPawn.IsLocallyControlled() && m_oPawn.WorldInfo.TimeSeconds - CachedTarget.LastRenderTime > 0.5)
    {
        return FALSE;
    }
    oTargetPawn = BioPawn(CachedTarget);
    if (oTargetPawn != None && !oTargetPawn.CanBeBioticCharged())
    {
        return FALSE;
    }
    Dir = CachedTarget.location - m_oPawn.location;
    Dir.Z = 0.0;
    Dir = Normal(Dir);
    if (oTargetPawn.CurrentCustomAction == 31)
    {
        NewLocation = CachedTarget.Anchor.location;
        NewLocation.Z -= CachedTarget.Anchor.CylinderComponent.CollisionHeight;
    }
    else
    {
        MoveDist = FMax(CachedTarget.CylinderComponent.CollisionRadius, m_oPawn.CylinderComponent.CollisionRadius) + 120.0;
        NewLocation = CachedTarget.location - Dir * MoveDist;
        NewLocation.Z -= CachedTarget.CylinderComponent.CollisionHeight;
    }
    NewLocation.Z += m_oPawn.CylinderComponent.CollisionHeight;
    if (TryMove(NewLocation, Dir, m_oPawn))
    {
        CachedTeleportLocation = NewLocation;
        CachedTargetLocation = vect(0.0, 0.0, 0.0);
        return TRUE;
    }
    NewLocation = CachedTarget.location;
    NewLocation.Z += m_oPawn.CylinderComponent.CollisionHeight - CachedTarget.CylinderComponent.CollisionHeight;
    NewTargetLocation = CachedTarget.location + Dir * MoveDist;
    if (TryMove(NewLocation, Dir, CachedTarget))
    {
        CachedTeleportLocation = NewLocation;
        CachedTargetLocation = NewTargetLocation;
        return TRUE;
    }
    NewLocation = CachedTarget.location + Dir * MoveDist * 0.5;
    NewLocation.Z += m_oPawn.CylinderComponent.CollisionHeight - CachedTarget.CylinderComponent.CollisionHeight;
    NewTargetLocation = CachedTarget.location + Dir * MoveDist * 1.5;
    if (TryMove(NewLocation, Dir, CachedTarget))
    {
        CachedTeleportLocation = NewLocation;
        CachedTargetLocation = NewTargetLocation;
        return TRUE;
    }
    return FALSE;
}
public function CollectVolumes()
{
    local PlayerController PC;
    local TriggerVolume ChkVolume;
    local array<TriggerVolume> AllVolumes;
    local NavigationPoint Nav;
    local NavigationPoint TargetNav;
    local int idx;
    local int VolumeIdx;
    local Charge_PendingVolume NewVolume;
    local Vector Extent;
    
    PC = PlayerController(m_oPawn.Controller);
    if (PC == None)
    {
        return;
    }
    VolumeList.Length = 0;
    foreach m_oPawn.AllActors(Class'TriggerVolume', ChkVolume, )
    {
        if (ChkVolume.IsA('BioTriggerStream') == FALSE && m_oPawn.IsInVolume(ChkVolume) == FALSE)
        {
            AllVolumes.AddItem(ChkVolume);
        }
    }
    Extent = m_oPawn.GetCollisionExtent();
    foreach PC.RouteCache(Nav, idx)
    {
        if (idx < PC.RouteCache.Length - 1)
        {
            TargetNav = PC.RouteCache[idx + 1];
            for (VolumeIdx = AllVolumes.Length - 1; VolumeIdx >= 0; VolumeIdx--)
            {
                ChkVolume = AllVolumes[VolumeIdx];
                if (ChkVolume.bCollideActors && ChkVolume.ScriptLineCheck(Nav.location, TargetNav.location, Extent))
                {
                    NewVolume.Volume = ChkVolume;
                    NewVolume.bTouching = FALSE;
                    VolumeList.AddItem(NewVolume);
                    AllVolumes.Remove(VolumeIdx, 1);
                }
            }
        }
    }
    bCollectedVolumes = TRUE;
}
public function bool FindSpace(out Vector NearLocation, Vector Extent, Actor TraceActor)
{
    local Vector X;
    local Vector Y;
    local Vector Z;
    local Vector HitLocation;
    local Vector HitNormal;
    local Vector TestLoc;
    local Rotator RotToTarget;
    local float XIdx;
    local float YIdx;
    
    RotToTarget = Rotator(NearLocation - m_oPawn.location);
    RotToTarget.Pitch = 0;
    RotToTarget.Roll = 0;
    GetAxes(RotToTarget, X, Y, Z);
    X *= Extent.X * 0.5;
    Y *= Extent.Y * 0.5;
    if (TraceActor.Trace(HitLocation, HitNormal, NearLocation, NearLocation, FALSE, Extent, , ) == None)
    {
        return TRUE;
    }
    XIdx = -1.0;
    while (XIdx <= 1.0)
    {
        YIdx = -1.0;
        while (YIdx <= 1.0)
        {
            if (XIdx != 0.0 || YIdx != 0.0)
            {
                TestLoc = NearLocation + X * XIdx + Y * YIdx;
                if (TraceActor.Trace(HitLocation, HitNormal, TestLoc, TestLoc, FALSE, Extent, , ) == None)
                {
                    NearLocation = TestLoc;
                    return TRUE;
                }
            }
            YIdx += 1.0;
        }
        XIdx += 1.0;
    }
    return FALSE;
}
public function bool OnChargeImpact(EPowerResistance Resistance, Actor oImpacted, int nPreviouslyImpacted, Vector HitLocation, Vector HitNormal)
{
    local SFXAI_Core AI;
    local SFXPawn HitBioPawn;
    local RvrClientEffectTarget CETarget;
    local SFXModule_GameEffectManager Manager;
    local bool bRagdolled;
    local SFXPowerCustomActionBase oPower;
    
    HitBioPawn = SFXPawn(oImpacted);
    if (HitBioPawn != None)
    {
        AI = SFXAI_Core(HitBioPawn.Controller);
        if (AI != None)
        {
            AI.FireTarget = m_oPawn;
        }
        if (CachedTarget == oImpacted)
        {
            bCachedTargetImpacted = TRUE;
        }
        bRagdolled = Resistance == EPowerResistance.Resistance_None && (MaximumRagdollTargets.CurrentValue == float(0) || float(nPreviouslyImpacted) < MaximumRagdollTargets.CurrentValue);
        if (Resistance != EPowerResistance.Resistance_Full)
        {
            HitBioPawn.AddPowerAssistEvent(m_oPawn, DisplayName, bRagdolled ? PowerAssistFullControlValue : PowerAssistPartialControlValue);
        }
        if (bRagdolled)
        {
            HitBioPawn.RegisterRBCallback(OnRagdollPhysicsImpact, TRUE);
        }
        CETarget.Instigator = oImpacted;
        CETarget.SpawnValue.X = 1.0;
        if (IsEvolvedWithChoice(5))
        {
            Class'RvrClientEffectManager'.static.GetClientEffectManager().PlayOnTarget(CE_HeavyChargeImpact, CETarget);
        }
        else
        {
            Class'RvrClientEffectManager'.static.GetClientEffectManager().PlayOnTarget(CE_ChargeImpact, CETarget);
        }
        Manager = HitBioPawn.GetModule(Class'SFXModule_GameEffectManager');
        if (Manager != None)
        {
            Manager.RemoveEffectsByType(Class'SFXGameEffect_MovementSpeedBonus');
        }
        CheckForPowerCombo(HitBioPawn, Resistance, HitLocation, HitNormal);
        // MILAN CHANGE - UP3 - Notify the melee passive when Havok Strike kills a target
        if (Manager != None && HitBioPawn.IsDead() && m_oPawn != None && m_oPawn.PowerManager != None)
        {
            foreach m_oPawn.PowerManager.Powers(oPower, )
            {
                if (SFXPowerCustomAction_MeleePassivePower(oPower) != None)
                {
                    SFXPowerCustomAction_MeleePassivePower(oPower).OnHeavyMeleeKill(HitBioPawn);
                    break;
                }
            }
        }
        // END MILAN CHANGE
        return TRUE;
    }
    return FALSE;
}
public function PlayFailedChargeEffects()
{
    local RvrClientEffectTarget CETarget;
    
    if (m_oPawn.InCombat())
    {
        SFXGRI(m_oPawn.WorldInfo.GRI).TriggerVocalizationEvent(89, m_oPawn, m_oPawn);
    }
    CETarget.Instigator = m_oPawn;
    CETarget.SpawnValue.X = 1.0;
    Class'RvrClientEffectManager'.static.GetClientEffectManager().PlayOnTarget(CE_CrustEffect, CETarget);
}
public function StartTeleport()
{
    local SFXEmitter TeleportOut;
    
    TeleportOut = SFXGRI(m_oPawn.WorldInfo.GRI).ObjectPool.GetImpactEmitter(PS_TeleportOut, m_oPawn.location, m_oPawn.Rotation);
    if (TeleportOut != None)
    {
        TeleportOut.SetLifetime(2.0);
        TeleportOut.ParticleSystemComponent.SetScale(0.25);
        TeleportOut.ParticleSystemComponent.SetActive(TRUE);
        if (SFXPawn_Player(m_oPawn) != None && m_oPawn.Controller != None && m_oPawn.Controller.IsLocalPlayerController())
        {
            SFXGRI(m_oPawn.WorldInfo.GRI).PlayTransientSound(ChargeTakeoff, m_oPawn.location);
        }
        else
        {
            SFXGRI(m_oPawn.WorldInfo.GRI).PlayTransientSound(HenchChargeTakeoff, m_oPawn.location);
        }
    }
}
public function bool TryMove(Vector NewLocation, Vector Dir, Pawn CollisionActor)
{
    if (!FindSpace(NewLocation, m_oPawn.CylinderComponent.Bounds.BoxExtent, m_oPawn))
    {
        return FALSE;
    }
    if (!ValidateTargetLocation(NewLocation))
    {
        return FALSE;
    }
    return TRUE;
}
public function CameraMove()
{
    local BioPlayerController PC;
    local SFXPlayerCamera Camera;
    local float fCameraTransitionTime;
    
    PC = BioPlayerController(m_oPawn.Controller);
    if (PC != None)
    {
        if (CamTransition == None)
        {
            CamTransition = new (PC.GetGameModeDefault()) Class'SFXCameraTransition_VanguardSlam';
        }
        if (CamMode == None)
        {
            CamMode = new (PC.GetGameModeDefault()) Class'SFXCameraMode_TurianPack';
        }
        CamTransition.TargetActor = m_oTargetToAimAt;
        CamTransition.FirstPhaseLength = TeleportDelay;
        Camera = SFXPlayerCamera(PC.PlayerCamera);
        if (Camera != None)
        {
            fCameraTransitionTime = ImpactDelay + CameraImpactDelay;
            Camera.PlayCameraTransition(CamTransition, fCameraTransitionTime);
        }
        if (!bIsInputLocked)
        {
            PC.IgnoreLookInput(TRUE);
            PC.IgnoreMoveInput(TRUE);
            bIsInputLocked = TRUE;
        }
    }
}
private final function FinalizePawnMove(out Vector Loc, optional out Vector TargetLoc)
{
    local Vector Dir;
    
    if (m_oPawn.SetLocation(Loc, ) == FALSE)
    {
        bFailedToMoveCaster = TRUE;
        if (m_oPawn.Role == ENetRole.ROLE_Authority)
        {
            ResetPowerCooldown();
            ReplicatePowerSubsequentImpact(m_oPawn, , , -3);
        }
    }
    m_oPawn.LeaveCover();
    if (IsZero(TargetLoc) == FALSE)
    {
        Dir = TargetLoc - Loc;
        Dir.Z = 0.0;
        Dir = Normal(Dir);
        CachedTarget.SetLocation(TargetLoc, );
        if (BioPawn(CachedTarget) != None)
        {
            BioPawn(CachedTarget).LeaveCover();
        }
    }
    else
    {
        Dir = CachedTarget.location - Loc;
        Dir.Z = 0.0;
        Dir = Normal(Dir);
    }
    m_oPawn.SetDesiredRotation(Rotator(Dir));
}
public final function Vector NewVector(float X, float Y, float Z)
{
    local Vector V;
    
    V.X = X;
    V.Y = Y;
    V.Z = Z;
    return V;
}
public final function bool TestPathReachability(const out Vector StartLocation, NavigationPoint Anchor, Vector Extent)
{
    local Vector AnchorLocation;
    
    AnchorLocation = Anchor.location;
    AnchorLocation.Z -= Anchor.CylinderComponent.CollisionHeight;
    AnchorLocation.Z += m_oPawn.CylinderComponent.CollisionHeight + 2.0;
    if (!FindSpace(AnchorLocation, Extent, m_oPawn))
    {
        FailedLineCheckStart = AnchorLocation - Extent;
        FailedLineCheckEnd = AnchorLocation + Extent;
        FailedLineCheckName = "Failed to find spot around nav";
        return FALSE;
    }
    if (!CachedTarget.FastTrace(AnchorLocation, StartLocation, Extent, FALSE))
    {
        FailedLineCheckStart = AnchorLocation;
        FailedLineCheckEnd = StartLocation;
        FailedLineCheckName = "Failed target to nav";
        return FALSE;
    }
    return TRUE;
}
public final function bool ValidateTargetLocation(Vector TargetLocation)
{
    local NavigationPoint TargetAnchor;
    local NavigationPoint Nav;
    local Actor FirstTarget;
    local Actor HitActor;
    local float DistToAnchor;
    local PlayerController PC;
    local float CylHeight;
    local float CylWidth;
    local Vector HitLocation;
    local Vector HitNormal;
    local TraceHitInfo HitInfo;
    
    if (Abs(TargetLocation.Z - m_oPawn.location.Z) > 1000.0)
    {
        return FALSE;
    }
    CylHeight = m_oPawn.CylinderComponent.CollisionHeight;
    CylWidth = m_oPawn.CylinderComponent.CollisionRadius;
    HitActor = CachedTarget.Trace(HitLocation, HitNormal, TargetLocation + NewVector(0.0, 0.0, -CylHeight * float(4)), TargetLocation, FALSE, NewVector(CylWidth, CylWidth, 0.0), HitInfo, );
    if (HitActor == None)
    {
        FailedLineCheckStart = TargetLocation + NewVector(0.0, 0.0, -CylHeight * float(4));
        FailedLineCheckEnd = TargetLocation;
        FailedLineCheckName = "Failed ground test";
        return FALSE;
    }
    else if (!HitActor.bCanStepUpOn)
    {
        FailedLineCheckStart = TargetLocation + NewVector(0.0, 0.0, -CylHeight * float(4));
        FailedLineCheckEnd = TargetLocation;
        FailedLineCheckName = "Failed CanStepUpOn test";
        return FALSE;
    }
    TargetAnchor = CachedTarget.Anchor;
    if (TargetAnchor == None || !TestPathReachability(TargetLocation, TargetAnchor, NewVector(CylWidth, CylWidth, CylHeight * 0.75)))
    {
        TargetAnchor = CachedTarget.GetBestAnchor(CachedTarget, TargetLocation, TRUE, TRUE, DistToAnchor);
        if (TargetAnchor == None)
        {
            return FALSE;
        }
        if (!TestPathReachability(TargetLocation, TargetAnchor, NewVector(CylWidth, CylWidth, CylHeight * 0.75)))
        {
            return FALSE;
        }
    }
    Nav = m_oPawn.GetBestAnchor(m_oPawn, m_oPawn.location, TRUE, TRUE, DistToAnchor);
    if (Nav == None)
    {
        Nav = m_oPawn.GetBestAnchor(m_oPawn, m_oPawn.location, FALSE, TRUE, DistToAnchor);
        if (Nav == None)
        {
            return FALSE;
        }
    }
    if (Nav.NetworkID != TargetAnchor.NetworkID)
    {
        return FALSE;
    }
    if (Nav != TargetAnchor)
    {
        PC = PlayerController(m_oPawn.Controller);
        if (PC != None)
        {
            m_oPawn.SetAnchor(Nav);
            if (Class'Goal_AtActor'.static.AtActor(m_oPawn, TargetAnchor, 0.0, FALSE))
            {
                Class'Path_TowardGoal'.static.TowardGoal(m_oPawn, TargetAnchor);
                FirstTarget = PC.FindPathToward(TargetAnchor, , , );
            }
            m_oPawn.SetAnchor(None);
        }
        if (FirstTarget == None)
        {
            return FALSE;
        }
    }
    if (!bCollectedVolumes)
    {
        CollectVolumes();
    }
    return TRUE;
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    HitShake = {
                RotAmplitude = {X = 100.0, Y = 100.0, Z = 200.0}, 
                RotFrequency = {X = 10.0, Y = 10.0, Z = 25.0}, 
                RotSinOffset = {X = 0.0, Y = 0.0, Z = 0.0}, 
                LocAmplitude = {X = 0.0, Y = 3.0, Z = 5.0}, 
                LocFrequency = {X = 1.0, Y = 10.0, Z = 20.0}, 
                LocSinOffset = {X = 0.0, Y = 0.0, Z = 0.0}, 
                ShakeName = 'None', 
                TimeToGo = 0.0, 
                TimeDuration = 1.0, 
                RotParam = {X = EShakeParam.ESP_OffsetRandom, Y = EShakeParam.ESP_OffsetRandom, Z = EShakeParam.ESP_OffsetRandom, Padding = 0}, 
                LocParam = {X = EShakeParam.ESP_OffsetRandom, Y = EShakeParam.ESP_OffsetRandom, Z = EShakeParam.ESP_OffsetRandom, Padding = 0}, 
                FOVAmplitude = 2.0, 
                FOVFrequency = 5.0, 
                FOVSinOffset = 0.0, 
                TargetingDampening = 0.0, 
                bOverrideTargetingDampening = FALSE, 
                FOVParam = EShakeParam.ESP_OffsetRandom
               }
    bLineCheckToHead = TRUE
    bCustomImpactLogic = TRUE
    LeanOutToCast = FALSE
}
