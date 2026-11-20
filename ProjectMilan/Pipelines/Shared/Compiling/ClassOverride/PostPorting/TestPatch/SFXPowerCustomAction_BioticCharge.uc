// Source: ME3, Patch_PowCustomAction_BioticCharge
// Decompiled 11/17/2026 7:38:33 AM against Asari_Vanguard_MP.pcc
Class SFXPowerCustomAction_BioticCharge extends SFXPowerCustomAction
    config(Game);

struct Charge_PendingVolume 
{
    var(Charge_PendingVolume) Volume Volume;
    var(Charge_PendingVolume) bool bTouching;
};
const TELEPORT_VISIBLE_THRESHOLD = 0.5f;
const TELEPORT_HEIGHT_THRESHOLD = 1000.f;

var config SFXPowerCustomActionBase.PowerData DamageReduction;
var config SFXPowerCustomActionBase.PowerData DamageReductionDuration;
var config SFXPowerCustomActionBase.PowerData ShieldsRestored;
var(SFXPowerCustomAction_BioticCharge) Object.InterpCurveFloat TimeCurve;
var(SFXPowerCustomAction_BioticCharge) transient string FailedLineCheckName;
var(SFXPowerCustomAction_BioticCharge) array<SFXPowerCustomAction_BioticCharge.Charge_PendingVolume> VolumeList;
var Class<SFXRumble_Power> CustomDetonationRumbleClass;
var Class<SFXShake_Power> CustomDetonationScreenShakeClass;
var(SFXPowerCustomAction_BioticCharge) GameTypes.ScreenShakeStruct HitShake;
var(SFXPowerCustomAction_BioticCharge) transient Object.Vector CachedTeleportLocation;
var(SFXPowerCustomAction_BioticCharge) transient Object.Vector CachedTargetLocation;
var(SFXPowerCustomAction_BioticCharge) transient Object.Vector CachedStartingLocation;
var(SFXPowerCustomAction_BioticCharge) transient Object.Vector FailedLineCheckStart;
var(SFXPowerCustomAction_BioticCharge) transient Object.Vector FailedLineCheckEnd;
var Name BonusName;
var config float StingerDuration;
var config float StingerSlowPct;
var config float FrozenTargetForceMult;
var config float ConeAngle;
var config float CooldownBonusFromMelee;
var config float CooldownDurationFromMelee;
var config float Evolve_DamageForceBonus;
var config float Evolve_ImpactRadiusBonus;
var config float Evolve_MaxImpactTargetsBonus;
var config float Evolve_TimedWeaponDamageBonus;
var config float Evolve_TimedWeaponDamageDuration;
var config float Evolve_TimedPowerDamageBonus;
var config float Evolve_TimedPowerDamageDuration;
var config float Evolve_NoCooldownChance;
var config float Evolve_ShieldRestoredBonus;
var(SFXPowerCustomAction_BioticCharge) transient Pawn CachedTarget;
var(SFXPowerCustomAction_BioticCharge) float TeleportStartDelay;
var(SFXPowerCustomAction_BioticCharge) float TeleportDelay;
var(SFXPowerCustomAction_BioticCharge) float ImpactDelay;
var(SFXPowerCustomAction_BioticCharge) float ImpactDelay_Min;
var(SFXPowerCustomAction_BioticCharge) float ImpactDelay_Max;
var(SFXPowerCustomAction_BioticCharge) float TimeStingerDelay;
var(SFXPowerCustomAction_BioticCharge) float CounterTimeScaleValue;
var(SFXPowerCustomAction_BioticCharge) float CameraImpactDelay;
var(SFXPowerCustomAction_BioticCharge) ParticleSystem PS_TeleportIn;
var(SFXPowerCustomAction_BioticCharge) ParticleSystem PS_TeleportOut;
var RvrClientEffectInterface CE_CrustEffect;
var RvrClientEffectInterface CE_ChargeImpact;
var(SFXPowerCustomAction_BioticCharge) SFXProjectile_Power_BioticCharge ChargeProjectile;
var(SFXPowerCustomAction_BioticCharge) SFXCameraTransition_VanguardSlam CamTransition;
var(SFXPowerCustomAction_BioticCharge) ForceFeedbackWaveform HitForceFeedback;
var WwiseEvent ChargeCast;
var WwiseEvent HenchChargeCast;
var WwiseEvent ChargeImpact;
var WwiseEvent HenchChargeImpact;
var WwiseEvent ChargeTakeoff;
var WwiseEvent HenchChargeTakeoff;
var bool bCachedTargetImpacted;
var bool bUseOwnerRotation;
var transient bool bIsInputLocked;
var transient bool bClientCanProcessNoCooldown;
var(SFXPowerCustomAction_BioticCharge) bool bFailedToMoveCaster;
var(SFXPowerCustomAction_BioticCharge) bool bCollectedVolumes;
var bool bLineCheckToHead;
var transient SFXPowerCustomAction.EClientNoCooldownDecision ClientNoCooldown;

public function bool CanUsePower(Actor oTarget)
{
    local BioPlayerController PC;
    local Object.Vector TargetLocation;
    local Object.Vector CamLocation;
    
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
public function bool DoPowerDetonatedForActor(Actor oActor, Object.Vector HitLocation, Object.Vector HitNormal, int nImpactCount, bool bFirstTarget, optional SFXProjectile_PowerCustomAction oProjectile);

public function Impact()
{
    local PlayerController PC;
    local RvrClientEffectInterface.RvrClientEffectTarget CETarget;
    local SFXShield_Base Shield;
    local SFXModule_GameEffectManager Manager;
    
    if (ChargeProjectile != None)
    {
        ChargeProjectile.Destroy();
    }
    PC = PlayerController(m_oPawn.Controller);
    m_oPawn.SetHidden(FALSE);
    m_oPawn.CustomTimeDilation = 1.0;
    SFXGRI(m_oPawn.WorldInfo.GRI).DuringAsyncWorker.SpawnEffectAtLocation(m_oPawn, PS_TeleportIn, m_oPawn.location + Normal(Vector(m_oPawn.Rotation)) * 50.0, m_oPawn.Rotation);
    if (!bFailedToMoveCaster)
    {
        if (m_oPawn.Role == ENetRole.ROLE_Authority)
        {
            bCachedTargetImpacted = FALSE;
            DetonationParameters.ConeDirection = Vector(m_oPawn.Rotation);
            DetonationParameters.ConeDirection.Z += 0.5;
            DetonationParameters.ConeDirection = Normal(DetonationParameters.ConeDirection);
            AreaExplosion(m_oPawn.location, ImpactRadius.CurrentValue, Damage.CurrentValue, DefaultDamageType, Force.CurrentValue, DetonationParameters, int(MaximumImpactTargets.CurrentValue), OnChargeImpact);
            m_oPawn.SetTimer(TimeStingerDelay, FALSE, 'TimeStinger', Self);
        }
        if (SFXPawn_Player(m_oPawn) != None && m_oPawn.Controller != None && m_oPawn.Controller.IsLocalPlayerController())
        {
            SFXGRI(m_oPawn.WorldInfo.GRI).PlayTransientSound(ChargeImpact, m_oPawn.location);
        }
        else
        {
            SFXGRI(m_oPawn.WorldInfo.GRI).PlayTransientSound(HenchChargeImpact, m_oPawn.location);
        }
        Manager = m_oPawn.GetModule(Class'SFXModule_GameEffectManager');
        if (Manager != None)
        {
            Manager.RemoveEffectsByCategory(BonusName);
            Manager.RemoveEffectsByCategory(Name);
        }
        Shield = m_oPawn.GetShields();
        Shield.SetCurrentShields(FClamp(Shield.GetCurrentShields() + Shield.GetMaxShields() * ShieldsRestored.CurrentValue, 0.0, Shield.GetMaxShields()));
        if (m_oPawn.Role == ENetRole.ROLE_Authority)
        {
            ApplyTemporaryGameEffect(m_oPawn, Class'SFXGameEffect_DamageTakenBonus', DamageReductionDuration.CurrentValue, -DamageReduction.CurrentValue, Name, m_oPawn.Controller);
            if (IsEvolvedWithChoice(2))
            {
                ApplyTemporaryGameEffect(m_oPawn, Class'SFXGameEffect_WeaponDamageBonus', Evolve_TimedWeaponDamageDuration, Evolve_TimedWeaponDamageBonus, Name, m_oPawn.Controller);
            }
            if (IsEvolvedWithChoice(3))
            {
                m_oPawn.PowerManager.ApplyPowerBonus(m_oPawn, 'Damage', Evolve_TimedPowerDamageBonus, Evolve_TimedPowerDamageDuration, Name);
                m_oPawn.PowerManager.ApplyPowerBonus(m_oPawn, 'Force', Evolve_TimedPowerDamageBonus, Evolve_TimedPowerDamageDuration, Name);
            }
        }
        CETarget.Instigator = m_oPawn;
        CETarget.SpawnValue.X = DamageReductionDuration.CurrentValue;
        Class'RvrClientEffectManager'.static.GetClientEffectManager().PlayOnTarget(CE_CrustEffect, CETarget);
    }
    if (PC != None && bIsInputLocked)
    {
        PC.IgnoreLookInput(FALSE);
        PC.IgnoreMoveInput(FALSE);
        bIsInputLocked = FALSE;
    }
    bCollectedVolumes = FALSE;
    if (CustomDetonationRumbleClass != None)
    {
        PlayPowerControllerRumble(CustomDetonationRumbleClass, m_oPawn.location);
    }
    if (CustomDetonationScreenShakeClass != None)
    {
        PlayPowerScreenShake(CustomDetonationScreenShakeClass, m_oPawn.location);
    }
}
public static function PrecacheVFX(SFXObjectPool ObjectPool, RvrClientEffectManager ClientEffects)
{
    Super.PrecacheVFX(ObjectPool, ClientEffects);
    ObjectPool.PrecacheImpactEmitter(default.PS_TeleportOut);
    ObjectPool.PrecacheGenericParticleSystemComponent(default.PS_TeleportIn);
}
public function SpawnProjectile()
{
    ChargeProjectile = m_oPawn.Spawn(Class'SFXProjectile_Power_BioticCharge', m_oPawn, , m_oPawn.location, m_oPawn.Rotation);
    if (ChargeProjectile != None)
    {
        if (SFXGRI(m_oPawn.WorldInfo.GRI).bAllowTimeDilation)
        {
            ChargeProjectile.CustomTimeDilation = CounterTimeScaleValue;
        }
        ChargeProjectile.Speed = VSize(CachedTarget.location - m_oPawn.location) / (ImpactDelay - TeleportDelay);
        ChargeProjectile.Init(Normal(CachedTarget.location - m_oPawn.location));
    }
}
public function StartCustomAction()
{
    local BioPlayerController PC;
    local SFXPlayerCamera Camera;
    local float fDistanceToTarget;
    local float fCameraTransitionTime;
    
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
    if (SFXGRI(m_oPawn.WorldInfo.GRI).bAllowTimeDilation)
    {
        SFXGame(m_oPawn.WorldInfo.Game).RequestTimeDilation(TimeCurve, ImpactDelay / CounterTimeScaleValue);
        m_oPawn.CustomTimeDilation = CounterTimeScaleValue;
    }
    m_oPawn.SetTimer(TeleportStartDelay, FALSE, 'StartTeleport', Self);
    m_oPawn.SetTimer(TeleportDelay, FALSE, 'Teleport', Self);
    m_oPawn.SetTimer(ImpactDelay, FALSE, 'Impact', Self);
    ApplyTemporaryGameEffect(m_oPawn, Class'SFXGameEffect_DamageImmunity', ImpactDelay, 0.0, Name, m_oPawn.Controller);
    ApplyTemporaryGameEffect(CachedTarget, Class'SFXGameEffect_MovementSpeedBonus', 1.0, -1.0, Name, m_oPawn.Controller);
    PC = BioPlayerController(m_oPawn.Controller);
    if (PC != None)
    {
        if (CamTransition == None)
        {
            CamTransition = new (PC.GetGameModeDefault()) Class'SFXCameraTransition_VanguardSlam';
        }
        CamTransition.TargetActor = m_oTargetToAimAt;
        CamTransition.FirstPhaseLength = TeleportDelay;
        if (SFXGRI(m_oPawn.WorldInfo.GRI).bAllowTimeDilation)
        {
            CamTransition.FirstPhaseLength /= CounterTimeScaleValue;
        }
        Camera = SFXPlayerCamera(PC.PlayerCamera);
        if (Camera != None)
        {
            fCameraTransitionTime = ImpactDelay + CameraImpactDelay;
            if (SFXGRI(m_oPawn.WorldInfo.GRI).bAllowTimeDilation)
            {
                fCameraTransitionTime /= CounterTimeScaleValue;
            }
            Camera.PlayCameraTransition(CamTransition, fCameraTransitionTime);
        }
        if (!bIsInputLocked)
        {
            PC.IgnoreLookInput(TRUE);
            PC.IgnoreMoveInput(TRUE);
            bIsInputLocked = TRUE;
        }
    }
    if (SFXPawn_Player(m_oPawn) != None && m_oPawn.Controller != None && m_oPawn.Controller.IsLocalPlayerController())
    {
        SFXGRI(m_oPawn.WorldInfo.GRI).PlayTransientSound(ChargeCast, m_oPawn.location);
    }
    else
    {
        SFXGRI(m_oPawn.WorldInfo.GRI).PlayTransientSound(HenchChargeCast, m_oPawn.location);
    }
}
public event function TickCustomAction(float fDeltaTime)
{
    local int idx;
    local array<SequenceEvent> EventsList;
    local SequenceEvent Event;
    local SeqEvent_Touch TouchEvent;
    local bool OldOverlapping;
    
    Super.TickCustomAction(fDeltaTime);
    if (VolumeList.Length > 0)
    {
        for (idx = 0; idx < VolumeList.Length; idx++)
        {
            if (VolumeList[idx].bTouching == FALSE)
            {
                VolumeList[idx].bTouching = TRUE;
                if (VolumeList[idx].Volume.FindEventsOfClass(Class'SeqEvent_Touch', EventsList))
                {
                    foreach EventsList(Event, )
                    {
                        TouchEvent = SeqEvent_Touch(Event);
                        if (TouchEvent != None)
                        {
                            OldOverlapping = TouchEvent.bForceOverlapping;
                            TouchEvent.bForceOverlapping = FALSE;
                            TouchEvent.CheckTouchActivate(m_oPawn, m_oPawn);
                            TouchEvent.bForceOverlapping = OldOverlapping;
                        }
                    }
                }
                break;
                continue;
            }
            if (VolumeList[idx].Volume.FindEventsOfClass(Class'SeqEvent_Touch', EventsList))
            {
                foreach EventsList(Event, )
                {
                    TouchEvent = SeqEvent_Touch(Event);
                    if (TouchEvent != None)
                    {
                        TouchEvent.CheckUnTouchActivate(m_oPawn, m_oPawn);
                    }
                }
            }
            VolumeList.Remove(idx, 1);
            idx--;
        }
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
    m_oPawn.SetHidden(TRUE);
    m_oPawn.SetPhysics(2);
    m_oPawn.LastPhysicsSetter = Self;
}
public function ApplyBonus(Name Parameter, SFXGameEffect Bonus, optional bool bRemove = FALSE)
{
    Super.ApplyBonus(Parameter, Bonus, bRemove);
    switch (Parameter)
    {
        case 'ChargeCooldown':
            ApplyBonusToParameter(CooldownTime, Bonus, bRemove);
            break;
        default:
    }
}
public function ClientDoPowerSubsequentImpact(Actor oActor, optional int CustomActionReactionType, optional float Duration, optional int ImpactCount, optional float Delay, optional bool DoCallback)
{
    if (ImpactCount == -1)
    {
        if (bClientCanProcessNoCooldown)
        {
            ResetPowerCooldown();
        }
        ClientNoCooldown = EClientNoCooldownDecision.NoCooldown_Success;
    }
    else if (ImpactCount == -2)
    {
        ClientNoCooldown = EClientNoCooldownDecision.NoCooldown_Failure;
    }
    else if (ImpactCount == -3)
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
    if (ImpactCount < 0 && bClientCanProcessNoCooldown)
    {
        bClientCanProcessNoCooldown = FALSE;
        ClientNoCooldown = EClientNoCooldownDecision.NoCooldown_NoDecision;
    }
}
public function EvolvePower(SFXPowerCustomActionBase.EEvolveChoice choice)
{
    Super(SFXPowerCustomActionBase).EvolvePower(choice);
    switch (choice)
    {
        case EEvolveChoice.EvolveChoice1:
            AddEvolvedRankBonus(Force, Evolve_DamageForceBonus);
            AddEvolvedRankBonus(Damage, Evolve_DamageForceBonus);
            break;
        case EEvolveChoice.EvolveChoice2:
            DetonationParameters.ConeAngle = 0.0;
            AddEvolvedRankBonus(MaximumImpactTargets, Evolve_MaxImpactTargetsBonus);
            AddEvolvedRankBonus(ImpactRadius, Evolve_ImpactRadiusBonus);
            break;
        case EEvolveChoice.EvolveChoice3:
            break;
        case EEvolveChoice.EvolveChoice4:
            break;
        case EEvolveChoice.EvolveChoice5:
            break;
        case EEvolveChoice.EvolveChoice6:
            AddEvolvedRankBonus(ShieldsRestored, Evolve_ShieldRestoredBonus);
            break;
        default:
    }
    RecalculateAllPowerData();
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
public function PopulatePowerStatBarEvolves()
{
    PowerStatBars.Length = 4;
    PowerStatBars[0].Data = SFXPawn_Henchman(m_oPawn) == None ? CooldownTime : HenchmanCooldownTime;
    PowerStatBars[0].srDisplayTotalToken = StatBarToken_Time;
    PowerStatBars[0].srStatBarDisplayTitle = StatBarTitle_Cooldown;
    PowerStatBars[1].Data = Damage;
    PowerStatBars[1].srDisplayTotalToken = StatBarToken_RawValue;
    PowerStatBars[1].srStatBarDisplayTitle = StatBarTitle_Damage;
    PowerStatBars[1].EvolvedBonuses[0] = Evolve_DamageForceBonus;
    PowerStatBars[2].Data = Force;
    PowerStatBars[2].srDisplayTotalToken = StatBarToken_Force;
    PowerStatBars[2].srStatBarDisplayTitle = StatBarTitle_Force;
    PowerStatBars[2].EvolvedBonuses[0] = Evolve_DamageForceBonus;
    PowerStatBars[3].Data = ShieldsRestored;
    PowerStatBars[3].Formula = EPowerStatBarFormula.EPowerStatBarFormula_Percent;
    PowerStatBars[3].srDisplayTotalToken = StatBarToken_Percent;
    PowerStatBars[3].srStatBarDisplayTitle = $634681;
    PowerStatBars[3].EvolvedBonuses[5] = Evolve_ShieldRestoredBonus;
}
public function RecalculateAllPowerData(optional bool bReset = FALSE)
{
    Super(SFXPowerCustomActionBase).RecalculateAllPowerData(bReset);
    RecalculatePowerData(DamageReduction, bReset);
    RecalculatePowerData(DamageReductionDuration, bReset);
    RecalculatePowerData(ShieldsRestored, bReset);
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
public function ResetPower()
{
    Super(SFXPowerCustomActionBase).ResetPower();
    DetonationParameters = default.DetonationParameters;
}
public function StartPowerCooldown()
{
    if (m_oPawn == None)
    {
        return;
    }
    bClientCanProcessNoCooldown = TRUE;
    if (!IsEvolvedWithChoice(4) || m_oPawn.Role != ENetRole.ROLE_Authority || FRand() > Evolve_NoCooldownChance)
    {
        if (m_oPawn.Role == ENetRole.ROLE_Authority || ClientNoCooldown != EClientNoCooldownDecision.NoCooldown_Success)
        {
            Super.StartPowerCooldown();
        }
        if (m_oPawn.Role == ENetRole.ROLE_Authority)
        {
            ReplicatePowerSubsequentImpact(m_oPawn, , , -2);
        }
    }
    else if (m_oPawn.Role == ENetRole.ROLE_Authority)
    {
        ReplicatePowerSubsequentImpact(m_oPawn, , , -1);
    }
    if (m_oPawn.Role != ENetRole.ROLE_Authority && ClientNoCooldown != EClientNoCooldownDecision.NoCooldown_NoDecision)
    {
        bClientCanProcessNoCooldown = FALSE;
        ClientNoCooldown = EClientNoCooldownDecision.NoCooldown_NoDecision;
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
    local Object.Vector NewLocation;
    local Object.Vector NewTargetLocation;
    local Object.Vector Dir;
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
public function bool OnChargeImpact(Actor.EPowerResistance Resistance, Actor oImpacted, int nPreviouslyImpacted, Object.Vector HitLocation, Object.Vector HitNormal)
{
    local SFXAI_Core AI;
    local SFXPawn HitBioPawn;
    local RvrClientEffectInterface.RvrClientEffectTarget CETarget;
    local SFXModule_GameEffectManager Manager;
    local bool bRagdolled;
    
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
        Class'RvrClientEffectManager'.static.GetClientEffectManager().PlayOnTarget(CE_ChargeImpact, CETarget);
        Manager = HitBioPawn.GetModule(Class'SFXModule_GameEffectManager');
        if (Manager != None)
        {
            Manager.RemoveEffectsByType(Class'SFXGameEffect_MovementSpeedBonus');
        }
        CheckForPowerCombo(HitBioPawn, Resistance, HitLocation, HitNormal);
        return TRUE;
    }
    return FALSE;
}
public function PlayFailedChargeEffects()
{
    local RvrClientEffectInterface.RvrClientEffectTarget CETarget;
    
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
        if (SFXGRI(m_oPawn.WorldInfo.GRI).bAllowTimeDilation)
        {
            TeleportOut.CustomTimeDilation = CounterTimeScaleValue;
        }
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
public function bool TryMove(Object.Vector NewLocation, Object.Vector Dir, Pawn CollisionActor)
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
private final function FinalizePawnMove(out Object.Vector Loc, optional out Object.Vector TargetLoc)
{
    local Object.Vector Dir;
    
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
public final function Object.Vector NewVector(float X, float Y, float Z)
{
    local Object.Vector V;
    
    V.X = X;
    V.Y = Y;
    V.Z = Z;
    return V;
}
public final function bool TestPathReachability(const out Object.Vector StartLocation, NavigationPoint Anchor, Object.Vector Extent)
{
    local Object.Vector AnchorLocation;
    
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
private final function TimeStinger()
{
    if (StingerDuration > float(0) && StingerSlowPct > float(0))
    {
        ApplyTemporaryGameEffect(m_oPawn, Class'SFXGameEffect_TimeDilation', StingerDuration, StingerSlowPct, 'Shockwave', m_oPawn.Controller);
    }
}
public final function bool ValidateTargetLocation(Object.Vector TargetLocation)
{
    local NavigationPoint TargetAnchor;
    local NavigationPoint Nav;
    local Actor FirstTarget;
    local Actor HitActor;
    local float DistToAnchor;
    local PlayerController PC;
    local float CylHeight;
    local float CylWidth;
    local Object.Vector HitLocation;
    local Object.Vector HitNormal;
    local Actor.TraceHitInfo HitInfo;
    
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
public function CollectVolumes()
{
    local PlayerController PC;
    local TriggerVolume ChkVolume;
    local array<TriggerVolume> AllVolumes;
    local NavigationPoint Nav;
    local NavigationPoint TargetNav;
    local int idx;
    local int VolumeIdx;
    local SFXPowerCustomAction_BioticCharge.Charge_PendingVolume NewVolume;
    local Object.Vector Extent;
    
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
public function bool FindSpace(out Object.Vector NearLocation, Object.Vector Extent, Actor TraceActor)
{
    local Object.Vector X;
    local Object.Vector Y;
    local Object.Vector Z;
    local Object.Vector HitLocation;
    local Object.Vector HitNormal;
    local Object.Vector TestLoc;
    local Object.Rotator RotToTarget;
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

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    DamageReduction = {
                       DynamicBonuses = (), 
                       RankBonuses[0] = 0.0, 
                       RankBonuses[1] = 0.0, 
                       RankBonuses[2] = 0.0, 
                       RankBonuses[3] = 0.0, 
                       RankBonuses[4] = 0.0, 
                       RankBonuses[5] = 0.0, 
                       BaseValue = 0.5, 
                       CurrentValue = 0.0, 
                       Formula = EPowerDataFormula.Normal
                      }
    DamageReductionDuration = {
                               DynamicBonuses = (), 
                               RankBonuses[0] = 0.0, 
                               RankBonuses[1] = 0.0, 
                               RankBonuses[2] = 0.0, 
                               RankBonuses[3] = 0.0, 
                               RankBonuses[4] = 0.0, 
                               RankBonuses[5] = 0.0, 
                               BaseValue = 4.0, 
                               CurrentValue = 0.0, 
                               Formula = EPowerDataFormula.Normal
                              }
    ShieldsRestored = {
                       DynamicBonuses = (), 
                       RankBonuses[0] = 0.0, 
                       RankBonuses[1] = 0.0, 
                       RankBonuses[2] = 0.0, 
                       RankBonuses[3] = 0.0, 
                       RankBonuses[4] = 0.0, 
                       RankBonuses[5] = 0.0, 
                       BaseValue = 0.5, 
                       CurrentValue = 0.0, 
                       Formula = EPowerDataFormula.BonusIsHardValue
                      }
    TimeCurve = {
                 Points = ({InVal = 0.0, OutVal = 0.200000003, ArriveTangent = 0.0, LeaveTangent = 0.0, InterpMode = EInterpCurveMode.CIM_Linear}, 
                           {InVal = 1.0, OutVal = 0.200000003, ArriveTangent = 0.0, LeaveTangent = 0.0, InterpMode = EInterpCurveMode.CIM_Linear}
                          ), 
                 InterpMethod = EInterpMethodType.IMT_UseFixedTangentEvalAndNewAutoTangents
                }
    CustomDetonationRumbleClass = Class'SFXRumble_Power_BioticCharge'
    CustomDetonationScreenShakeClass = Class'SFXShake_Power_BioticCharge'
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
    BonusName = 'ChargeCooldownBonusFromMelee'
    StingerDuration = 1.0
    StingerSlowPct = 0.5
    FrozenTargetForceMult = 3.0
    CooldownBonusFromMelee = 1.0
    CooldownDurationFromMelee = 30.0
    Evolve_DamageForceBonus = 0.300000012
    Evolve_ImpactRadiusBonus = 200.0
    Evolve_MaxImpactTargetsBonus = 2.0
    Evolve_TimedWeaponDamageBonus = 0.150000006
    Evolve_TimedWeaponDamageDuration = 3.0
    Evolve_TimedPowerDamageBonus = 0.25
    Evolve_TimedPowerDamageDuration = 15.0
    Evolve_NoCooldownChance = 0.25
    Evolve_ShieldRestoredBonus = 0.5
    TeleportStartDelay = 0.5
    TeleportDelay = 0.866699994
    ImpactDelay_Min = 1.10000002
    ImpactDelay_Max = 1.79999995
    TimeStingerDelay = 0.300000012
    CounterTimeScaleValue = 5.0
    CameraImpactDelay = 0.5
    PS_TeleportIn = ParticleSystem'BioVFX_B_Vanguard.Particles.Charge_Blast'
    PS_TeleportOut = ParticleSystem'BioVFX_Crt_Praetorian.Particles.Teleport__out'
    CE_CrustEffect = RvrClientEffect'BioVFX_B_Pull.VCFX.Pull_Lift_Crust_VCFX'
    CE_ChargeImpact = RvrClientEffect'BioVFX_B_Vanguard.VCFX.Charge_Imp_VCFX'
    ChargeCast = WwiseEvent'wwise_power_biotic_charge.Play_power_biotic_P_charge_cast'
    HenchChargeCast = WwiseEvent'wwise_power_biotic_charge.Play_power_biotic_NP_charge_cast'
    ChargeImpact = WwiseEvent'wwise_power_biotic_charge.Play_power_biotic_P_charge_impact'
    HenchChargeImpact = WwiseEvent'wwise_power_biotic_charge.Play_power_biotic_NP_charge_impact'
    ChargeTakeoff = WwiseEvent'wwise_power_biotic_charge.Play_power_biotic_P_charge_takeoff'
    HenchChargeTakeoff = WwiseEvent'wwise_power_biotic_charge.Play_power_biotic_NP_charge_takeoff'
    bLineCheckToHead = TRUE
    ComboDetonators = (Class'SFXGameEffect_PowerCombo_Biotic', Class'SFXGameEffect_PowerCombo_Electric', Class'SFXGameEffect_PowerCombo_Fire', Class'SFXGameEffect_PowerCombo_Cryo')
    BS_StartCastAnimation = {
                             AnimName = ('BC_Start', 
                                         'None', 
                                         'None', 
                                         'None', 
                                         'None', 
                                         'None', 
                                         'None', 
                                         'None', 
                                         'None', 
                                         'None', 
                                         'None', 
                                         'None'
                                        )
                            }
    BS_EndCastAnimation = {
                           AnimName = ('BC_End', 
                                       'None', 
                                       'None', 
                                       'None', 
                                       'None', 
                                       'None', 
                                       'None', 
                                       'None', 
                                       'None', 
                                       'None', 
                                       'None', 
                                       'None'
                                      )
                          }
    DefaultDamageType = Class'SFXDamageType_BioticCharge'
    NonRagdollDamageType = Class'SFXDamageType_BioticCharge_NoRagdoll'
    DetonationParameters = {ConeAngle = 120.0, BlockedByObjects = FALSE}
    ReleaseTime = 0.400000006
    CastAnimSet = AnimSet'BIOG_HMM_BC_A.HMM_BC_TeleportDash'
    bCustomImpactLogic = TRUE
    LeanOutToCast = FALSE
    Discipline = EBioCapMode.BIO_CAPMODE_BIOTICS
    CooldownTime = {RankBonuses[1] = 0.25, BaseValue = 10.0, Formula = EPowerDataFormula.DivideByBonusSum}
    HenchmanCooldownTime = {RankBonuses[1] = 0.25, BaseValue = 20.0, Formula = EPowerDataFormula.DivideByBonusSum}
    MaximumRange = {BaseValue = 4000.0}
    ImpactRadius = {BaseValue = 200.0, Formula = EPowerDataFormula.BonusIsHardValue}
    MaximumImpactTargets = {BaseValue = 1.0, Formula = EPowerDataFormula.BonusIsHardValue}
    MaximumRagdollTargets = {BaseValue = 2.0}
    Damage = {RankBonuses[2] = 0.200000003, BaseValue = 250.0}
    Force = {RankBonuses[2] = 0.200000003, BaseValue = 500.0}
    ConeHalfAngle = {BaseValue = 0.865999997}
    Ranks = ({
              Icon = 65, 
              Name = $0, 
              Description = $0, 
              Evolved1Name = $634683, 
              Evolved1Description = $634684, 
              Evolved2Name = $0, 
              Evolved2Description = $0
             }, 
             {
              Icon = 65, 
              Name = $0, 
              Description = $0, 
              Evolved1Name = $645154, 
              Evolved1Description = $645155, 
              Evolved2Name = $0, 
              Evolved2Description = $0
             }, 
             {
              Icon = 65, 
              Name = $0, 
              Description = $0, 
              Evolved1Name = $645156, 
              Evolved1Description = $645157, 
              Evolved2Name = $0, 
              Evolved2Description = $0
             }, 
             {
              Icon = 65, 
              Name = $0, 
              Description = $0, 
              Evolved1Name = $645158, 
              Evolved1Description = $645159, 
              Evolved2Name = $645160, 
              Evolved2Description = $645161
             }, 
             {
              Icon = 65, 
              Name = $0, 
              Description = $0, 
              Evolved1Name = $645162, 
              Evolved1Description = $645163, 
              Evolved2Name = $645164, 
              Evolved2Description = $645165
             }, 
             {
              Icon = 65, 
              Name = $0, 
              Description = $0, 
              Evolved1Name = $645166, 
              Evolved1Description = $645167, 
              Evolved2Name = $645168, 
              Evolved2Description = $645169
             }
            )
    PowerName = 'BioticCharge'
    PowerCustomActionID = 37
    DisplayName = $634683
    Description = $703606
    Icon = 65
    TalentDescription = $703606
    bClientPredictCustomAction = FALSE
    bForceLocalSimulation = TRUE
}