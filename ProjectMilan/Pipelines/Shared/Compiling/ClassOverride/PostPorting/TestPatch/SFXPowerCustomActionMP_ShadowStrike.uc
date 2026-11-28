// Source: ME3, Patch_SFXPwrCustActnMPShadowStrike
// Decompiled 11/17/2026 7:38:26 AM against N7_Infiltrator_MP.pcc
Class SFXPowerCustomActionMP_ShadowStrike extends SFXPowerCustomAction
    config(Game);

var config array<SFXCustomActionTypes.EAICustomAction> EnemyMovementCAs;
var Object.Vector CachedTeleportLocation;
var Name CloakEffectCategory;
var config float Evolve_DamageBonus1;
var config float Evolve_DamageTakenBonus;
var config float Evolve_DamageTakenDuration;
var config float Evolve_DoTDamagePercent;
var config float Evolve_DoTDamageDuration;
var config float Evolve_CooldownBonus;
var config float Evolve_DamageBonus2;
var config float Evolve_MovementSpeedBonus;
var config float Evolve_MovementSpeedDuration;
var config float StopTargetDuration;
var config float ExtraDistFromTarget;
var BioPawn CachedTarget;
var float TeleportDelay;
var float CameraTransitionDelay;
var float DecloakDelayMax;
var float DecloakDelayMin;
var float RotationInterpTime;
var float CameraTransitionMax;
var float CameraTransitionMin;
var float MeleeAfterDecloakDelay;
var float BloodScale;
var float MachineHealth;
var float EnergyShields;
var WwiseEvent SwordImpact;
var WwiseEvent SwordImpactNP;
var ParticleSystem PS_BloodImpactTemplate;
var ParticleSystem PS_SwordImpactTemplate;
var SFXCameraTransition_ShadowStrike CamTransition;
var bool bIsActive;
var bool bTeleportStarted;
var transient bool bIsInputLocked;
var bool bOverrideReattachWeapon;
var bool bCloakAfterShadowStrike;
var bool bTriggerCooldown;

public function CancelPower()
{
    ResetPowerCooldown();
    PowerIsComplete();
}
public function bool CanUsePower(Actor oTarget)
{
    local bool bValidTarget;
    
    if (bIsActive)
    {
        return FALSE;
    }
    if (!Super.CanUsePower(oTarget))
    {
        return FALSE;
    }
    if (m_oPawn.Role == ENetRole.ROLE_Authority)
    {
        CachedTarget = BioPawn(m_oTargetToAimAt);
        CachedTeleportLocation = m_vLocationToAimAt;
        if (CachedTarget != None)
        {
            if (FindTeleportLocation(CachedTarget, CachedTeleportLocation))
            {
                bValidTarget = TRUE;
            }
        }
        if (!bValidTarget)
        {
            return FALSE;
        }
    }
    return TRUE;
}
public function bool OnImpact(Actor.EPowerResistance Resistance, Actor oImpacted, int nPreviouslyImpacted, Object.Vector HitLocation, Object.Vector HitNormal)
{
    local SFXPawn ImpactedPawn;
    local float ShieldDrainAmount;
    local SFXShield_Base MyShields;
    local SFXModule_GameEffectManager Manager;
    local SFXGameEffect_DamageOverTime DamageEffect;
    local float fDamagePerSecond;
    local SFXPowerCustomActionBase oPower;
    local SFXEmitter oEmitter;
    local SFXObjectPool Pool;
    local Object.Vector vImpactLocation;
    
    ImpactedPawn = SFXPawn(oImpacted);
    if (ImpactedPawn == None || Resistance == EPowerResistance.Resistance_Full)
    {
        return FALSE;
    }
    Pool = SFXGRI(m_oPawn.WorldInfo.GRI).ObjectPool;
    if (Pool != None)
    {
        if (ImpactedPawn.GetAimNodeLocation(1, vImpactLocation))
        {
            oEmitter = Pool.GetImpactEmitter(PS_BloodImpactTemplate, vImpactLocation, Rotator(HitNormal));
            if (oEmitter != None)
            {
                Pool.ApplyBloodColor(oEmitter.ParticleSystemComponent, ImpactedPawn);
                oEmitter.ParticleSystemComponent.SetScale(BloodScale);
                oEmitter.ParticleSystemComponent.SetActive(TRUE);
            }
            oEmitter = Pool.GetImpactEmitter(PS_SwordImpactTemplate, vImpactLocation, Rotator(HitNormal));
            if (oEmitter != None)
            {
                oEmitter.ParticleSystemComponent.SetActive(TRUE);
            }
        }
    }
    Manager = ImpactedPawn.GetModule(Class'SFXModule_GameEffectManager');
    if (Manager == None)
    {
        return FALSE;
    }
    if (IsEvolvedWithChoice(2))
    {
        fDamagePerSecond = Evolve_DoTDamagePercent * Damage.CurrentValue / Evolve_DoTDamageDuration;
        DamageEffect = SFXGameEffect_DamageOverTime(Manager.CreateEffect(Class'SFXGameEffect_DamageOverTime', Name, Evolve_DoTDamageDuration, 1, fDamagePerSecond, m_oPawn.Controller));
        if (DamageEffect != None)
        {
            DamageEffect.DamageType = DefaultDamageType;
            DamageEffect.OnApplied();
            AddComboEffect(ImpactedPawn, Class'SFXGameEffect_PowerCombo_Electric', Evolve_DoTDamageDuration);
        }
    }
    if (IsEvolvedWithChoice(5))
    {
        ShieldDrainAmount += EnergyShields - GetCurrentEnergyShields(ImpactedPawn);
        if (ShieldDrainAmount > float(0))
        {
            MyShields = m_oPawn.GetShields();
            if (MyShields != None)
            {
                MyShields.SetCurrentShields(FClamp(MyShields.GetCurrentShields() + ShieldDrainAmount, 0.0, MyShields.GetMaxShields()));
            }
        }
    }
    if (m_oPawn.PowerManager != None && ImpactedPawn.IsDead())
    {
        foreach m_oPawn.PowerManager.Powers(oPower, )
        {
            if (SFXPowerCustomAction_MeleePassivePower(oPower) != None)
            {
                SFXPowerCustomAction_MeleePassivePower(oPower).OnHeavyMeleeKill(ImpactedPawn);
                break;
            }
        }
    }
    return TRUE;
}
public function StartCustomAction()
{
    if (m_oPawn.Role < ENetRole.ROLE_Authority && InternalCanDoCustomAction(None, TRUE) == FALSE)
    {
        InterruptThisCustomAction();
        return;
    }
    bIsActive = TRUE;
    bTeleportStarted = FALSE;
    Super.StartCustomAction();
}
public function ApplyBonus(Name Parameter, SFXGameEffect Bonus, optional bool bRemove = FALSE)
{
    Super.ApplyBonus(Parameter, Bonus, bRemove);
    switch (Parameter)
    {
        case 'MeleeDamage':
            ApplyBonusToParameter(Damage, Bonus, bRemove);
            ApplyBonusToParameter(Force, Bonus, bRemove);
            break;
        default:
    }
}
public function ClientDoCustomAction(optional bool bForced)
{
    if (m_oPawn != None)
    {
        CachedTarget = BioPawn(m_oPawn.ReplicatedCustomActionInfo.Target);
        CachedTeleportLocation = m_oPawn.ReplicatedCustomActionInfo.TargetLocation;
        Super.ClientDoCustomAction(bForced);
    }
}
public function ClientDoPowerSubsequentImpact(Actor oActor, optional int CustomActionReactionType, optional float Duration, optional int ImpactCount, optional float Delay, optional bool DoCallback)
{
    local Class<SFXDamageType> dmgType;
    local float fDamage;
    
    if (ImpactCount == -1)
    {
        HandleInterruption();
    }
    else if (ImpactCount == -2)
    {
        CancelPower();
        EndThisCustomAction();
    }
    else if (BioPawn(oActor) != None)
    {
        fDamage = GetImpactDamage(oActor, dmgType);
        DoAreaExplosionForActor(oActor, m_oPawn.location, 0, fDamage, dmgType, Force.CurrentValue, DetonationParameters, 0, OnImpact);
        BioPawn(oActor).ClientPlayAnimatedReaction(CustomActionReactionType);
    }
}
public function EvolvePower(SFXPowerCustomActionBase.EEvolveChoice choice)
{
    Super(SFXPowerCustomActionBase).EvolvePower(choice);
    switch (choice)
    {
        case EEvolveChoice.EvolveChoice1:
            AddEvolvedRankBonus(Damage, Evolve_DamageBonus1);
            break;
        case EEvolveChoice.EvolveChoice2:
            break;
        case EEvolveChoice.EvolveChoice3:
            break;
        case EEvolveChoice.EvolveChoice4:
            AddEvolvedRankBonus(CooldownTime, Evolve_CooldownBonus);
            break;
        case EEvolveChoice.EvolveChoice5:
            AddEvolvedRankBonus(Damage, Evolve_DamageBonus2);
            break;
        case EEvolveChoice.EvolveChoice6:
            break;
        default:
    }
    RecalculateAllPowerInfo();
}
public function float GetImpactDamage(Actor oImpacted, out Class<SFXDamageType> DamageType)
{
    local BioPawn ImpactedPawn;
    local SFXModule_GameEffectManager Manager;
    local SFXGameEffect_MeleeDamageType MeleeDamageTypeEffect;
    
    MachineHealth = 0.0;
    EnergyShields = 0.0;
    ImpactedPawn = BioPawn(oImpacted);
    if (ImpactedPawn != None)
    {
        EnergyShields = GetCurrentEnergyShields(ImpactedPawn);
        if (IsMachineRace(ImpactedPawn))
        {
            MachineHealth = ImpactedPawn.GetCurrentHealth();
        }
    }
    DamageType = DefaultDamageType;
    Manager = m_oPawn.GetModule(Class'SFXModule_GameEffectManager');
    if (Manager != None)
    {
        MeleeDamageTypeEffect = SFXGameEffect_MeleeDamageType(Manager.GetFirstEffectOfType(Class'SFXGameEffect_MeleeDamageType'));
        if (MeleeDamageTypeEffect != None)
        {
            DamageType = MeleeDamageTypeEffect.ShadowStrikeDamageType;
        }
    }
    return Damage.CurrentValue;
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
public function PopulatePowerStatBarEvolves()
{
    PowerStatBars.Length = 2;
    PowerStatBars[0].Data = CooldownTime;
    PowerStatBars[0].srDisplayTotalToken = StatBarToken_Time;
    PowerStatBars[0].srStatBarDisplayTitle = StatBarTitle_Cooldown;
    PowerStatBars[0].EvolvedBonuses[3] = Evolve_CooldownBonus;
    PowerStatBars[1].Data = Damage;
    PowerStatBars[1].srDisplayTotalToken = StatBarToken_RawValue;
    PowerStatBars[1].srStatBarDisplayTitle = StatBarTitle_Damage;
    PowerStatBars[1].EvolvedBonuses[0] = Evolve_DamageBonus1;
    PowerStatBars[1].EvolvedBonuses[4] = Evolve_DamageBonus2;
}
public function ReleaseInstantPower()
{
    local float fDistanceToTarget;
    local float fDecloakDelay;
    local SFXModule_GameEffectManager Manager;
    local SFXGameEffect_CloakN7 CloakEffect;
    local BioPlayerController PC;
    local SFXPowerCustomActionMP_Cloak_N7Infiltrator CloakPower;
    
    bCloakAfterShadowStrike = FALSE;
    if (CachedTarget == None)
    {
        CancelPower();
        EndThisCustomAction();
        ReplicatePowerSubsequentImpact(m_oPawn, , , -2);
        return;
    }
    m_oPawn.LeaveCover();
    PC = BioPlayerController(m_oPawn.Controller);
    if (!bIsInputLocked && PC != None)
    {
        PC.IgnoreLookInput(TRUE);
        PC.IgnoreMoveInput(TRUE);
        bIsInputLocked = TRUE;
    }
    m_oPawn.SetTimer(TeleportDelay, FALSE, 'TeleportPlayer', Self);
    fDistanceToTarget = VSize(CachedTarget.location - m_oPawn.location);
    fDistanceToTarget = FClamp(fDistanceToTarget / 4000.0, 0.0, 1.0);
    fDecloakDelay = Lerp(DecloakDelayMin, DecloakDelayMax, fDistanceToTarget);
    m_oPawn.SetTimer(fDecloakDelay, FALSE, 'DoneTeleporting', Self);
    if (EnemyMovementCAs.Find(byte(CachedTarget.CurrentCustomAction)) == -1)
    {
        ApplyTemporaryGameEffect(CachedTarget, Class'SFXGameEffect_MovementSpeedBonus', fDecloakDelay + StopTargetDuration, -1.0, Name, m_oPawn.Controller);
    }
    Manager = m_oPawn.GetModule(Class'SFXModule_GameEffectManager');
    if (Manager != None)
    {
        CloakEffect = SFXGameEffect_CloakN7(Manager.GetFirstEffectOfType(Class'SFXGameEffect_CloakN7'));
        if (CloakEffect != None)
        {
            CloakPower = SFXPowerCustomActionMP_Cloak_N7Infiltrator(m_oPawn.PowerManager.GetPowerByClass(Class'SFXPowerCustomActionMP_Cloak_N7Infiltrator'));
            if (CloakPower != None && CloakPower.IsEvolvedWithChoice(4) && !CloakPower.bFirstPowerReleased)
            {
                CloakEffect.Duration = FMax(CloakEffect.CurrentTime + fDecloakDelay + 0.5, CloakEffect.Duration);
                bCloakAfterShadowStrike = TRUE;
            }
            else
            {
                CloakEffect.Duration = CloakEffect.CurrentTime + fDecloakDelay;
            }
            CloakEffect.OnAppliedFromShadowStrike();
        }
        else
        {
            CloakEffect = SFXGameEffect_CloakN7(Manager.CreateEffect(Class'SFXGameEffect_CloakN7', CloakEffectCategory, fDecloakDelay, 1, 0.0, m_oPawn.Controller));
            if (CloakEffect != None)
            {
                CloakEffect.OnAppliedFromShadowStrike();
            }
        }
    }
}
public function ReleasePower()
{
    bTriggerCooldown = FALSE;
    m_oPawn.Controller.ConsoleCommand("SetFakePermaCooldown");
    Super.ReleasePower();
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
public function StartPowerCooldown()
{
    if (bTriggerCooldown)
    {
        Super.StartPowerCooldown();
    }
}
public function StopCustomAction()
{
    if (bCloakAfterShadowStrike)
    {
        ReturnToNormalCloak();
    }
    bTriggerCooldown = TRUE;
    if (!bTeleportStarted)
    {
        CancelPower();
    }
    else
    {
        StartPowerCooldown();
    }
    PowerIsComplete();
    if (!bOverrideReattachWeapon && m_oPawn.Role > ENetRole.ROLE_SimulatedProxy)
    {
        HandleInterruption();
    }
    Super.StopCustomAction();
}
public function float GetCurrentEnergyShields(BioPawn oPawn)
{
    local float fEnergyShieldsLeft;
    local SFXShield_Base EnergyShield;
    
    if (oPawn != None && oPawn.InvManager != None)
    {
        foreach oPawn.InvManager.InventoryActors(Class'SFXShield_Base', EnergyShield)
        {
            fEnergyShieldsLeft += EnergyShield.GetCurrentShields();
        }
    }
    return fEnergyShieldsLeft;
}
public function DoneTeleporting()
{
    local SFXModule_GameEffectManager Manager;
    
    m_oPawn.SetPhysics(2);
    m_oPawn.LastPhysicsSetter = Self;
    Manager = m_oPawn.GetModule(Class'SFXModule_GameEffectManager');
    if (Manager != None)
    {
        Manager.RemoveEffectsByCategory(Name);
    }
    if (IsEvolvedWithChoice(1))
    {
        ApplyTemporaryGameEffect(m_oPawn, Class'SFXGameEffect_DamageTakenBonus', Evolve_DamageTakenDuration, -Evolve_DamageTakenBonus, Name, m_oPawn.Controller);
    }
    if (IsEvolvedWithChoice(5))
    {
        ApplyTemporaryGameEffect(m_oPawn, Class'SFXGameEffect_MovementSpeedBonus', Evolve_MovementSpeedDuration, Evolve_MovementSpeedBonus, Name, m_oPawn.Controller);
    }
    if (bCloakAfterShadowStrike)
    {
        ReturnToNormalCloak();
    }
    if (m_oPawn.Role > ENetRole.ROLE_SimulatedProxy)
    {
        bOverrideReattachWeapon = TRUE;
        if (m_oPawn.StartCustomAction(61, CachedTarget) == FALSE)
        {
            HandleInterruption();
        }
        bOverrideReattachWeapon = FALSE;
    }
}
public function bool FindTeleportLocation(BioPawn oTarget, out Object.Vector NewLocation)
{
    local float fDistance;
    local Object.Vector HitLocation;
    local Object.Vector HitNormal;
    local Object.Vector TraceStart;
    local Object.Vector TraceEnd;
    local Actor.TraceHitInfo HitInfo;
    local NavigationPoint TargetAnchor;
    local float fDist;
    local Actor PathFindResult;
    local PlayerController PC;
    local Object.Vector CachedPawnLocation;
    local bool bPointReachable;
    
    if (oTarget == None)
    {
        return FALSE;
    }
    PC = PlayerController(m_oPawn.Controller);
    if (PC == None)
    {
        return FALSE;
    }
    if (!m_oPawn.IsHostile(oTarget))
    {
        return FALSE;
    }
    if (m_oPawn.Anchor == None)
    {
        TargetAnchor = m_oPawn.GetBestAnchor(m_oPawn, m_oPawn.location, TRUE, TRUE, fDist);
        if (TargetAnchor == None)
        {
            return FALSE;
        }
        m_oPawn.SetAnchor(TargetAnchor);
    }
    if (oTarget.Anchor == None)
    {
        TargetAnchor = oTarget.GetBestAnchor(oTarget, oTarget.location, TRUE, TRUE, fDist);
        if (TargetAnchor == None)
        {
            return FALSE;
        }
        oTarget.SetAnchor(TargetAnchor);
    }
    TargetAnchor = oTarget.Anchor;
    if (Class'Goal_AtActor'.static.AtActor(m_oPawn, TargetAnchor, 0.0, FALSE))
    {
        Class'Path_TowardGoal'.static.TowardGoal(m_oPawn, TargetAnchor);
        PathFindResult = PC.FindPathToward(TargetAnchor, , , );
        if (PathFindResult == None)
        {
            return FALSE;
        }
    }
    fDistance = oTarget.GetCollisionRadius() + m_oPawn.GetCollisionRadius() + ExtraDistFromTarget;
    NewLocation = oTarget.location - Vector(oTarget.Rotation) * fDistance;
    NewLocation.Z -= oTarget.GetCollisionHeight() - m_oPawn.GetCollisionHeight();
    TraceStart = NewLocation;
    TraceEnd = NewLocation;
    TraceEnd.Z -= 200.0;
    if (m_oPawn.Trace(HitLocation, HitNormal, TraceEnd, TraceStart, FALSE, m_oPawn.GetCollisionExtent(), HitInfo, ) != None)
    {
        if (m_oPawn.FindNearestOpenLocation(HitLocation, NewLocation))
        {
            CachedPawnLocation = m_oPawn.location;
            m_oPawn.SetLocation(NewLocation, );
            // MILAN CHANGE - 11/27/2026 - Mgamerz
            // Use ActorReachable instead of PointReachable on target for validating
            bPointReachable = m_oPawn.Controller.ActorReachable(oTarget);
            m_oPawn.SetLocation(CachedPawnLocation, );
            if (bPointReachable)
            {
                return TRUE;
            }
        }
    }
    NewLocation = oTarget.location + Vector(oTarget.Rotation) * fDistance;
    NewLocation.Z -= oTarget.GetCollisionHeight() - m_oPawn.GetCollisionHeight();
    TraceStart = NewLocation;
    TraceEnd = NewLocation;
    TraceEnd.Z -= 200.0;
    if (m_oPawn.Trace(HitLocation, HitNormal, TraceEnd, TraceStart, FALSE, m_oPawn.GetCollisionExtent(), HitInfo, ) != None)
    {
        if (m_oPawn.FindNearestOpenLocation(HitLocation, NewLocation))
        {
            CachedPawnLocation = m_oPawn.location;
            m_oPawn.SetLocation(NewLocation, );
            // MILAN CHANGE - 11/27/2026 - Mgamerz
            bPointReachable = m_oPawn.Controller.ActorReachable(oTarget);
            m_oPawn.SetLocation(CachedPawnLocation, );
            return bPointReachable;
        }
    }
    return FALSE;
}
public function HandleInterruption()
{
    local SFXPawn_PlayerMP_Infiltrator_N7 Caster;
    
    Caster = SFXPawn_PlayerMP_Infiltrator_N7(m_oPawn);
    if (Caster != None && Caster.bWeaponDetached)
    {
        Caster.ReattachWeapon();
        Caster.AttachSwordToBack();
    }
    if (ShouldReplicate())
    {
        ReplicatePowerSubsequentImpact(m_oPawn, , , -1);
    }
}
public function OnMeleeImpact(BioPawn oTarget)
{
    local Class<SFXDamageType> dmgType;
    local float fDamage;
    
    if (oTarget == None)
    {
        return;
    }
    if (m_oPawn.IsLocallyControlled())
    {
        m_oPawn.PlaySound(SwordImpact, TRUE);
    }
    else
    {
        m_oPawn.PlaySound(SwordImpactNP, TRUE);
    }
    PlayPowerControllerRumble(DetonationRumbleClass, m_oPawn.location);
    PlayPowerScreenShake(DetonationScreenShakeClass, m_oPawn.location);
    if (m_oPawn.Role == ENetRole.ROLE_Authority)
    {
        fDamage = GetImpactDamage(oTarget, dmgType);
        DoAreaExplosionForActor(oTarget, m_oPawn.location, 0, fDamage, dmgType, Force.CurrentValue, DetonationParameters, 0, OnImpact);
    }
}
public function PowerIsComplete()
{
    local BioPlayerController PC;
    
    if (!bIsActive)
    {
        return;
    }
    bIsActive = FALSE;
    m_oPawn.ClearTimer('TeleportPlayer', Self);
    m_oPawn.ClearTimer('DoneTeleporting', Self);
    PC = BioPlayerController(m_oPawn.Controller);
    if (PC != None && bIsInputLocked)
    {
        PC.IgnoreLookInput(FALSE);
        PC.IgnoreMoveInput(FALSE);
        bIsInputLocked = FALSE;
    }
}
public function ReturnToNormalCloak()
{
    local SFXModule_GameEffectManager Manager;
    local SFXGameEffect_CloakN7 CloakEffect;
    local SFXPawn_PlayerMP_Infiltrator_N7 Caster;
    
    Manager = m_oPawn.GetModule(Class'SFXModule_GameEffectManager');
    if (Manager != None)
    {
        CloakEffect = SFXGameEffect_CloakN7(Manager.GetFirstEffectOfType(Class'SFXGameEffect_CloakN7'));
        if (CloakEffect != None)
        {
            Caster = SFXPawn_PlayerMP_Infiltrator_N7(m_oPawn);
            if (Caster != None)
            {
                Caster.ReattachWeapon();
                Caster.AttachSwordToHand();
            }
            CloakEffect.ReturnToCloakFromShadowStrike();
            bCloakAfterShadowStrike = FALSE;
        }
    }
}
public function TeleportPlayer()
{
    local Object.Rotator DesiredRot;
    local float fDistanceToTarget;
    local float fScaledDistToTarget;
    local SFXPlayerCamera Camera;
    local float fCameraTransitionTime;
    local BioPlayerController PC;
    local Object.Vector CamOffset;
    local SFXModule_GameEffectManager Manager;
    local Object.Vector CachedPlayerLocation;
    
    if (InternalCanDoCustomAction(None, TRUE) == FALSE)
    {
        InterruptThisCustomAction();
        return;
    }
    if (CachedTarget == None)
    {
        CancelPower();
        EndThisCustomAction();
        ReplicatePowerSubsequentImpact(m_oPawn, , , -2);
        return;
    }
    CachedPlayerLocation = m_oPawn.location;
    PC = BioPlayerController(m_oPawn.Controller);
    if (PC != None)
    {
        if (CamTransition == None)
        {
            CamTransition = new (PC.GetGameModeDefault()) Class'SFXCameraTransition_ShadowStrike';
        }
        Camera = SFXPlayerCamera(PC.PlayerCamera);
        if (Camera != None && Camera.CurrentCameraMode.GetActorCameraHook(CamOffset))
        {
            DesiredRot = Rotator(Normal(CachedTarget.location - CachedTeleportLocation));
            DesiredRot.Pitch = Camera.CameraCache.POV.Rotation.Pitch;
            CamOffset = Camera.CameraCache.POV.location - m_oPawn.location;
            CamOffset = TransformVectorByRotation(DesiredRot - Camera.CameraCache.POV.Rotation, CamOffset);
            CamTransition.EndLocation = CamOffset + CachedTeleportLocation;
            CamTransition.EndRotation = DesiredRot;
        }
    }
    if (m_oPawn.SetLocation(CachedTeleportLocation, ) == FALSE)
    {
        CancelPower();
        EndThisCustomAction();
        ReplicatePowerSubsequentImpact(m_oPawn, , , -2);
        return;
    }
    bTeleportStarted = TRUE;
    m_oPawn.LeaveCover();
    if (CachedTarget != None)
    {
        DesiredRot = Rotator(Normal(CachedTarget.location - m_oPawn.location));
        m_oPawn.SetRotation(DesiredRot);
        if (PC != None)
        {
            PC.SetRotation(DesiredRot);
        }
    }
    if (PC != None)
    {
        if (Camera != None)
        {
            fDistanceToTarget = VSize(CachedTarget.location - CachedPlayerLocation);
            fScaledDistToTarget = FClamp(fDistanceToTarget / 4000.0, 0.0, 1.0);
            fCameraTransitionTime = Lerp(CameraTransitionMin, CameraTransitionMax, fScaledDistToTarget);
            Camera.PlayCameraTransition(CamTransition, fCameraTransitionTime);
        }
    }
    Manager = m_oPawn.GetModule(Class'SFXModule_GameEffectManager');
    if (Manager != None)
    {
        Manager.CreateAndApplyEffect(Class'SFXGameEffect_IgnorePawn', Name, fCameraTransitionTime + MeleeAfterDecloakDelay, 1, 0.0, m_oPawn.Controller);
    }
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    Begin Object Class=BioDynamicAnimSet Name=MY_DYN_HMM_BC_RifleTechToolActivate
        m_nmOrigSetName = 'HMM_BC_RifleTechToolActivate'
        Sequences = (AnimSequence'BIOG_HMM_BC_A.HMM_BC_RifleTechToolActivate_BC_Start', AnimSequence'BIOG_HMM_BC_A.HMM_BC_RifleTechToolActivate_BC_Start_Cover_Neutral', AnimSequence'BIOG_HMM_BC_A.HMM_BC_RifleTechToolActivate_BC_Start_Cover_Neutral_Mid', AnimSequence'BIOG_HMM_BC_A.HMM_BC_RifleTechToolActivate_BC_End', AnimSequence'BIOG_HMM_BC_A.HMM_BC_RifleTechToolActivate_BC_End_Cover_Neutral', AnimSequence'BIOG_HMM_BC_A.HMM_BC_RifleTechToolActivate_BC_End_Cover_Neutral_Mid')
        m_pBioAnimSetData = BioAnimSetData'BIOG_HMM_BC_A.HMM_BC_RifleTechToolActivate_BioAnimSetData'
    End Object
    CloakEffectCategory = 'BreakableStealth'
    TeleportDelay = 0.400000006
    DecloakDelayMax = 2.0
    DecloakDelayMin = 1.0
    RotationInterpTime = 0.200000003
    CameraTransitionMax = 1.5
    CameraTransitionMin = 0.899999976
    MeleeAfterDecloakDelay = 1.0
    BloodScale = 2.5
    SwordImpact = WwiseEvent'Wwise_Power_DLC_MP3_Inf.Play_inf_mp3_strike_imp_P'
    SwordImpactNP = WwiseEvent'Wwise_Power_DLC_MP3_Inf.Play_inf_mp3_strike_imp_NP'
    PS_BloodImpactTemplate = ParticleSystem'BioVFX_C_Impacts.Blood.Particles.Blood_Red_CriticalHit_Misty_nSound'
    PS_SwordImpactTemplate = ParticleSystem'BioVFX_MP3_Sword.Particles.Sword_Impact'
    DefaultDamageType = Class'SFXDamageType_ShadowStrike'
    DetonationRumbleClass = Class'SFXRumble_Power_ShadowStrike'
    DetonationScreenShakeClass = Class'SFXShake_Power_ShadowStrike'
    CastAnimSet = MY_DYN_HMM_BC_RifleTechToolActivate
    fAnimPlayRate = 0.349999994
    CastSound = WwiseEvent'Wwise_Power_Tech_TactCloak.Play_power_tech_P_cloak_cast'
    HenchmanCastSound = WwiseEvent'Wwise_Power_Tech_TactCloak.Play_power_tech_NP_cloak_cast'
    bCustomImpactLogic = TRUE
    LeanOutToCast = FALSE
    Discipline = EBioCapMode.BIO_CAPMODE_TECH
    Ranks = ({
              Icon = 2, 
              Name = $0, 
              Description = $0, 
              Evolved1Name = $739525, 
              Evolved1Description = $739526, 
              Evolved2Name = $0, 
              Evolved2Description = $0
             }, 
             {
              Icon = 2, 
              Name = $0, 
              Description = $0, 
              Evolved1Name = $314059, 
              Evolved1Description = $501588, 
              Evolved2Name = $0, 
              Evolved2Description = $0
             }, 
             {
              Icon = 2, 
              Name = $0, 
              Description = $0, 
              Evolved1Name = $740297, 
              Evolved1Description = $560406, 
              Evolved2Name = $0, 
              Evolved2Description = $0
             }, 
             {
              Icon = 2, 
              Name = $0, 
              Description = $0, 
              Evolved1Name = $740297, 
              Evolved1Description = $740298, 
              Evolved2Name = $740299, 
              Evolved2Description = $740300
             }, 
             {
              Icon = 2, 
              Name = $0, 
              Description = $0, 
              Evolved1Name = $740306, 
              Evolved1Description = $740301, 
              Evolved2Name = $740328, 
              Evolved2Description = $740353
             }, 
             {
              Icon = 2, 
              Name = $0, 
              Description = $0, 
              Evolved1Name = $740297, 
              Evolved1Description = $740355, 
              Evolved2Name = $740693, 
              Evolved2Description = $740692
             }
            )
    PowerName = 'SHADOWSTRIKE'
    PowerCustomActionID = 62
    DisplayName = $739525
    Description = $739526
    Icon = 2
    IconResource = GFxMovieInfo'GUI_SF_Shadow.Shadow'
    TalentDescription = $739526
    AimingIgnoresObstructions = TRUE
    bTurnOffZoom = TRUE
    bClientPredictCustomAction = FALSE
}