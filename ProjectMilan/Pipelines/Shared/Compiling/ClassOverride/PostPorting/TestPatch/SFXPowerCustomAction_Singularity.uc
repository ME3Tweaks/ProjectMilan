// Source: ME3, Patch_SFXPwrCustActn_Singularity
// Decompiled 11/17/2026 7:38:40 AM against BioH_Liara_00.pcc
Class SFXPowerCustomAction_Singularity extends SFXPowerCustomAction
    config(Game);

var config SFXPowerCustomActionBase.PowerData Evolve_DoTDamage;
var config SFXPowerCustomActionBase.PowerData DetonateForce;
var config SFXPowerCustomActionBase.PowerData DetonateDamage;
var config SFXPowerCustomActionBase.PowerData DetonateRadius;
var config SFXPowerCustomActionBase.PowerData NumCharges;
var config SFXPowerCustomActionBase.PowerData SingularityDuration;
var config SFXPowerCustomActionBase.PowerData PushAwayForce;
var array<Actor> AffectedActors;
var array<Actor> ComboAppliedActors;
var config SFXPreAsyncWorkTicker.AreaEffectParameters ExplosionParam;
var Object.Guid SingularityGuid;
var Object.Vector m_vSingularityLocation;
var config float Evolve_RadiusBonus;
var config float Evolve_DurationBonus;
var config float Evolve_ExpandAmount;
var config float Evolve_ExpandDuration;
var config float Evolve_AdditionalCharges;
var config float Evolve_RechargeSpeed;
var config int DetonateMaxRagdollCount;
var RvrClientEffectInterface CE_Singularity;
var RvrClientEffectInterface CE_GrowingSingularity;
var RvrClientEffectInterface CE_ExplodingSingularity;
var RvrClientEffectInterface CE_TargetCrust;
var RvrClientEffectInterface CE_DrainTargetCrust;
var float m_fSingularityRadius;
var float m_fSingularityTimer;
var float m_fSingularityCharges;
var float m_fHitPlayerMinDuration;
var float m_fLookupActorTimer;
var config float m_fLookupActorInterval;
var float m_fGrowTimer;
var WwiseEvent Release;
var config float NonRagdollChargeUse;
var config float RagdollChargeUse;
var config float ComboNonRagdollDuration;
var config float Evolve_DamageBonus;
var bool m_bSingularityActive;
var config bool Patch4IterationApplied;

public function CombatEnded()
{
    m_oPawn.SetTimer(3.0, FALSE, 'TurnOffSingularity', Self);
}
public function bool ShouldUsePower(Actor Target, out string sOptionalInfo)
{
    local BioPawn oPawn;
    local SFXModule_GameEffectManager Manager;
    
    oPawn = BioPawn(Target);
    if (oPawn != None)
    {
        Manager = oPawn.GetModule(Class'SFXModule_GameEffectManager');
        if (Manager == None || Manager.HasEffectOfType(Class'SFXGameEffect_Stasis'))
        {
            return FALSE;
        }
    }
    return TRUE;
}
public function StartCustomAction()
{
    if (m_bSingularityActive)
    {
        TurnOffSingularity(FALSE);
    }
    Super.StartCustomAction();
}
public event function TickCustomAction(float fDeltaTime)
{
    local Actor NearbyActor;
    local array<Actor> NearbyActors;
    local BioWorldInfo Info;
    local BioPlayerController PC;
    local Actor.EPowerResistance Resistance;
    local Actor oTarget;
    local Actor oTargetOverride;
    local float fDamage;
    local Object.Vector vForce;
    local Object.Vector vHitNormal;
    
    Super.TickCustomAction(fDeltaTime);
    if (!m_bSingularityActive)
    {
        return;
    }
    Info = BioWorldInfo(m_oPawn.WorldInfo);
    if (Info != None)
    {
        PC = Info.GetLocalPlayerController();
        if (PC != None && (PC.GameModeManager2.IsActive(8) || PC.GameModeManager2.IsActive(7)))
        {
            TurnOffSingularity();
            return;
        }
    }
    if (m_oPawn != None && m_oPawn.Role == ENetRole.ROLE_Authority)
    {
        m_fSingularityTimer += fDeltaTime;
        if (m_fSingularityTimer > SingularityDuration.CurrentValue)
        {
            if (IsEvolvedWithChoice(5))
            {
                SingularityExplosion();
            }
            else
            {
                TurnOffSingularity();
            }
            return;
        }
        m_fLookupActorTimer += fDeltaTime;
        if (!Patch4IterationApplied && IsEvolvedWithChoice(4) && m_fGrowTimer > 0.0)
        {
            m_fSingularityRadius += fDeltaTime / Evolve_ExpandDuration * (ImpactRadius.CurrentValue * Evolve_ExpandAmount);
            m_fGrowTimer -= fDeltaTime;
        }
        if (m_fLookupActorTimer > m_fLookupActorInterval)
        {
            m_fLookupActorTimer = 0.0;
            GetNearbyActors(NearbyActors, m_vSingularityLocation, m_fSingularityRadius, m_fSingularityRadius, DetonationParameters);
            foreach NearbyActors(NearbyActor, )
            {
                if (SFXPawn_Player(NearbyActor) != None)
                {
                    if (SFXPawn_Henchman(m_oPawn) != None || NearbyActor == m_oPawn && m_fSingularityTimer > m_fHitPlayerMinDuration)
                    {
                        TurnOffSingularity();
                        return;
                    }
                }
                if (m_oPawn.IsFriendly(Pawn(NearbyActor)))
                {
                    continue;
                }
                if (NearbyActor.CollisionComponent != None && !NearbyActor.bWorldGeometry && NearbyActor.bProjTarget)
                {
                    if (Patch4IterationApplied)
                    {
                        oTarget = NearbyActor;
                        fDamage = Damage.CurrentValue * m_fLookupActorInterval;
                        vHitNormal = Normal(m_vSingularityLocation - NearbyActor.location);
                        Resistance = oTarget.GetPowerResistance(m_oPawn, m_vSingularityLocation, vHitNormal, fDamage, vForce, Class'SFXDamageType_Singularity_NoRagdoll', oTargetOverride);
                        if (oTargetOverride != None)
                        {
                            oTarget = oTargetOverride;
                        }
                        oTarget.ImpactWithPower(Resistance, m_oPawn, m_vSingularityLocation, vHitNormal, fDamage, vForce, Class'SFXDamageType_Singularity_NoRagdoll');
                        if (Resistance != EPowerResistance.Resistance_Full)
                        {
                            if (ApplyBioticComboEffect(oTarget))
                            {
                                ReplicateImpact(BioPawn(oTarget), -3, , , , BioPawn(oTarget).CurrentCustomAction);
                            }
                        }
                    }
                    ImpactNewTarget(NearbyActor);
                    if (m_fSingularityCharges < 0.0)
                    {
                        if (IsEvolvedWithChoice(5))
                        {
                            SingularityExplosion();
                        }
                        else
                        {
                            TurnOffSingularity();
                        }
                    }
                }
            }
        }
    }
}
public function ApplyBonus(Name Parameter, SFXGameEffect Bonus, optional bool bRemove = FALSE)
{
    Super.ApplyBonus(Parameter, Bonus, bRemove);
    switch (Parameter)
    {
        case 'Damage':
            ApplyBonusToParameter(Evolve_DoTDamage, Bonus, bRemove);
            ApplyBonusToParameter(DetonateDamage, Bonus, bRemove);
            break;
        case 'Force':
            ApplyBonusToParameter(DetonateForce, Bonus, bRemove);
            break;
        case 'ImpactRadius':
            ApplyBonusToParameter(DetonateRadius, Bonus, bRemove);
            break;
        case 'CooldownTime_Singularity':
            ApplyBonusToParameter(CooldownTime, Bonus, bRemove);
            ApplyBonusToParameter(HenchmanCooldownTime, Bonus, bRemove);
            break;
        default:
    }
}
public function ClientDoCustomActionImpact(Actor oActor, int ImpactCount, optional bool bFirstTarget, optional Object.Vector HitLocation, optional Object.Vector HitNormal, optional int CustomActionReactionType)
{
    switch (ImpactCount)
    {
        case -1:
            if (m_bSingularityActive)
            {
                ImpactNewTarget(oActor);
                if (BioPawn(oActor) != None)
                {
                    BioPawn(oActor).ClientPlayAnimatedReaction(CustomActionReactionType);
                }
            }
            break;
        case -2:
            if (!m_bSingularityActive)
            {
                m_vSingularityLocation = HitLocation;
                SpawnSingularity();
            }
            break;
        case -3:
            if (m_bSingularityActive)
            {
                ApplyBioticComboEffect(oActor);
            }
            break;
        default:
            Super.ClientDoCustomActionImpact(oActor, ImpactCount, bFirstTarget, HitLocation, HitNormal, CustomActionReactionType);
            break;
    }
}
public function ClientDoPowerSubsequentImpact(Actor oActor, optional int CustomActionReactionType, optional float Duration, optional int ImpactCount, optional float Delay, optional bool DoCallback)
{
    if (oActor == None)
    {
        return;
    }
    if (ImpactCount == -1)
    {
        TurnOffSingularity(FALSE);
    }
    else if (ImpactCount == -2)
    {
        SingularityExplosion();
    }
    else
    {
        DoAreaExplosionForActor(oActor, m_vSingularityLocation, ImpactCount, DetonateDamage.CurrentValue, Class'SFXDamageType_Singularity_Explosion', DetonateForce.CurrentValue, ExplosionParam, 0, None);
        if (BioPawn(oActor) != None)
        {
            BioPawn(oActor).ClientPlayAnimatedReaction(CustomActionReactionType);
        }
    }
}
public function DoJoinInProgress()
{
    if (m_bSingularityActive && ShouldReplicate())
    {
        ReplicateImpact(m_oPawn, -2, , m_vSingularityLocation);
    }
}
public function EvolvePower(SFXPowerCustomActionBase.EEvolveChoice choice)
{
    Super(SFXPowerCustomActionBase).EvolvePower(choice);
    switch (choice)
    {
        case EEvolveChoice.EvolveChoice1:
            if (Patch4IterationApplied)
            {
                AddEvolvedRankBonus(SingularityDuration, Evolve_DurationBonus);
            }
            else
            {
                AddEvolvedRankBonus(EffectDuration, Evolve_DurationBonus);
                AddEvolvedRankBonus(NumCharges, Evolve_AdditionalCharges);
            }
            break;
        case EEvolveChoice.EvolveChoice2:
            AddEvolvedRankBonus(ImpactRadius, Evolve_RadiusBonus);
            break;
        case EEvolveChoice.EvolveChoice3:
            break;
        case EEvolveChoice.EvolveChoice4:
            AddEvolvedRankBonus(CooldownTime, Evolve_RechargeSpeed);
            AddEvolvedRankBonus(HenchmanCooldownTime, Evolve_RechargeSpeed);
            break;
        case EEvolveChoice.EvolveChoice5:
            if (Patch4IterationApplied)
            {
                AddEvolvedRankBonus(Damage, Evolve_DamageBonus);
                AddEvolvedRankBonus(Evolve_DoTDamage, Evolve_DamageBonus);
            }
            break;
        case EEvolveChoice.EvolveChoice6:
            break;
        default:
    }
    RecalculateAllPowerInfo();
}
public function float GetImpactForce(Actor oImpacted)
{
    return -Force.CurrentValue;
}
public function OnOwnerDestroyed()
{
    if (m_bSingularityActive)
    {
        TurnOffSingularity(FALSE);
    }
}
public function OnPowerDetonated(Object.Vector HitLocation, Object.Vector HitNormal, optional SFXProjectile_PowerCustomAction oProjectile, optional Actor HitActor)
{
    local Object.Vector ProjectileVelocity;
    
    Super.OnPowerDetonated(HitLocation, HitNormal, oProjectile, HitActor);
    if (m_bSingularityActive)
    {
        TurnOffSingularity();
    }
    m_fLookupActorTimer = m_fLookupActorInterval - 0.25;
    if (oProjectile != None)
    {
        ProjectileVelocity = oProjectile.Velocity;
    }
    m_vSingularityLocation = HitLocation + Normal(ProjectileVelocity) * -50.0;
    SpawnSingularity();
}
public function OnPowerRankIncreased()
{
    Super(SFXPowerCustomActionBase).OnPowerRankIncreased();
    if (m_bSingularityActive)
    {
        TurnOffSingularity();
    }
}
public function OnPowersLoaded()
{
    Super(SFXPowerCustomActionBase).OnPowersLoaded();
    ComboDetonators.AddItem(Class'SFXGameEffect_PowerCombo_Biotic');
}
public function OnRagdollPhysicsImpact(Pawn oPawn, Actor oImpactActor, Object.Vector vImpactDir)
{
    RagdollPhysicsImpact(oPawn, oImpactActor, vImpactDir);
}
public function PopulatePowerStatBarEvolves()
{
    PowerStatBars.Length = 3;
    PowerStatBars[0].Data = SFXPawn_Henchman(m_oPawn) == None ? CooldownTime : HenchmanCooldownTime;
    PowerStatBars[0].srDisplayTotalToken = StatBarToken_Time;
    PowerStatBars[0].srStatBarDisplayTitle = StatBarTitle_Cooldown;
    PowerStatBars[0].EvolvedBonuses[3] = Evolve_RechargeSpeed;
    PowerStatBars[1].Data = EffectDuration;
    PowerStatBars[1].srDisplayTotalToken = StatBarToken_Time;
    PowerStatBars[1].srStatBarDisplayTitle = StatBarTitle_Duration;
    PowerStatBars[1].EvolvedBonuses[0] = Evolve_DurationBonus;
    PowerStatBars[2].Data = ImpactRadius;
    PowerStatBars[2].Formula = EPowerStatBarFormula.EPowerStatBarFormula_Distance;
    PowerStatBars[2].srDisplayTotalToken = StatBarToken_Distance;
    PowerStatBars[2].srStatBarDisplayTitle = StatBarTitle_ImpactRadius;
    PowerStatBars[2].EvolvedBonuses[1] = Evolve_RadiusBonus;
}
public function RecalculateAllPowerData(optional bool bReset = FALSE)
{
    Super(SFXPowerCustomActionBase).RecalculateAllPowerData(bReset);
    RecalculatePowerData(Evolve_DoTDamage, bReset);
    RecalculatePowerData(DetonateDamage, bReset);
    RecalculatePowerData(DetonateForce, bReset);
    RecalculatePowerData(DetonateRadius, bReset);
    RecalculatePowerData(SingularityDuration, bReset);
    RecalculatePowerData(NumCharges, bReset);
    RecalculatePowerData(PushAwayForce, bReset);
}
public function ReleasePower()
{
    Super.ReleasePower();
    SFXGRI(m_oPawn.WorldInfo.GRI).PlayTransientSound(Release, m_oPawn.location);
}
public function bool OnExplosionImpact(Actor.EPowerResistance Resistance, Actor oImpacted, int nPreviouslyImpacted, Object.Vector HitLocation, Object.Vector HitNormal)
{
    if (Resistance != EPowerResistance.Resistance_Full)
    {
        CheckForPowerCombo(oImpacted, Resistance, HitLocation, HitNormal);
    }
    return TRUE;
}
public function OnGameEffectEnded(Actor oActor)
{
    AffectedActors.RemoveItem(oActor);
}
public function SingularityExplosion()
{
    AreaExplosion(m_vSingularityLocation, DetonateRadius.CurrentValue, DetonateDamage.CurrentValue, Class'SFXDamageType_Singularity_Explosion', DetonateForce.CurrentValue, ExplosionParam, 0, OnExplosionImpact, DetonateMaxRagdollCount, Class'SFXDamageType_Singularity_NoRagdoll');
    Class'RvrClientEffectManager'.static.GetClientEffectManager().PlayAtLocation(CE_ExplodingSingularity, m_vSingularityLocation);
    if (ShouldReplicate())
    {
        ReplicatePowerSubsequentImpact(m_oPawn, , , -2);
    }
    Internal_TurnOffSingularity();
}
public function SpawnSingularity()
{
    if (m_oPawn == None)
    {
        return;
    }
    m_fSingularityTimer = 0.0;
    m_fSingularityRadius = ImpactRadius.CurrentValue;
    m_fSingularityCharges = NumCharges.CurrentValue;
    m_bSingularityActive = TRUE;
    SpawnSingularityVFX();
}
public function TurnOffSingularity(optional bool bDoReplication = TRUE)
{
    if (m_bSingularityActive)
    {
        if (bDoReplication && ShouldReplicate())
        {
            ReplicatePowerSubsequentImpact(m_oPawn, , , -1);
        }
        Internal_TurnOffSingularity();
    }
}
public final function SpawnSingularityVFX()
{
    local Object.Vector vParams;
    local RvrClientEffectManager Manager;
    
    Manager = Class'RvrClientEffectManager'.static.GetClientEffectManager();
    if (Manager != None)
    {
        vParams.X = SingularityDuration.CurrentValue;
        if (!Patch4IterationApplied && IsEvolvedWithChoice(4))
        {
            SingularityGuid = Manager.StartAtLocation(CE_GrowingSingularity, m_vSingularityLocation, , vParams);
            m_fGrowTimer = Evolve_ExpandDuration;
        }
        else
        {
            SingularityGuid = Manager.StartAtLocation(CE_Singularity, m_vSingularityLocation, , vParams);
        }
    }
    else
    {
        m_oPawn.SetTimer(0.100000001, FALSE, 'SpawnSingularityVFX', Self);
    }
}
public function bool ApplyBioticComboEffect(Actor oTarget)
{
    local SFXGameEffect_PowerCombo_Biotic ComboEffect;
    local SFXModule_GameEffectManager Manager;
    
    if (oTarget != None)
    {
        Manager = oTarget.GetModule(Class'SFXModule_GameEffectManager');
        if (Manager != None)
        {
            ComboEffect = SFXGameEffect_PowerCombo_Biotic(Manager.GetFirstEffectOfTypeAndCategory(Class'SFXGameEffect_PowerCombo_Biotic', Name));
            if (ComboEffect != None)
            {
                ComboEffect.CurrentTime = 0.0;
                return TRUE;
            }
            else if (ComboAppliedActors.Find(oTarget) == -1)
            {
                AddComboEffect(oTarget, Class'SFXGameEffect_PowerCombo_Biotic', ComboNonRagdollDuration);
                ComboAppliedActors.AddItem(oTarget);
                return TRUE;
            }
        }
    }
    return FALSE;
}
public function bool CanPutInSingularity(Actor oActor)
{
    local SFXModule_GameEffectManager Manager;
    local SFXGameEffect oEffect;
    
    if (oActor == None)
    {
        return FALSE;
    }
    if (m_oPawn.IsFriendly(Pawn(oActor)))
    {
        return FALSE;
    }
    Manager = oActor.GetModule(Class'SFXModule_GameEffectManager');
    if (Manager != None)
    {
        foreach Manager.GameEffects(oEffect, )
        {
            if (oEffect.@Class == Class'SFXGameEffect_Singularity' && oEffect.Category == Name)
            {
                return FALSE;
            }
        }
    }
    return TRUE;
}
public function bool ImpactNewTarget(Actor oImpacted)
{
    local SFXModule_GameEffectManager Manager;
    local SFXGameEffect_Singularity oSingularityEffect;
    local SFXGameEffect oEffect;
    local SFXPawn oPawn;
    local Object.Vector VParam;
    local Object.Vector vForce;
    local Object.Vector HitNormal;
    local Actor.EPowerResistance Resistance;
    local Actor oTargetOverride;
    local Actor oTarget;
    local float fDamage;
    local bool bHasReacted;
    local bool bRagdolled;
    
    if (oImpacted == None)
    {
        return FALSE;
    }
    Manager = oImpacted.GetModule(Class'SFXModule_GameEffectManager');
    if (Manager == None)
    {
        return FALSE;
    }
    if (Manager.HasEffectOfTypeAndCategory(Class'SFXGameEffect_Singularity', Name))
    {
        if (oImpacted.Role == ENetRole.ROLE_SimulatedProxy)
        {
            Manager.RemoveEffectsByCategory(Name);
        }
        else
        {
            return FALSE;
        }
    }
    oTarget = oImpacted;
    if (!Patch4IterationApplied)
    {
        fDamage = Damage.CurrentValue * m_fLookupActorInterval;
    }
    if (MaximumRagdollTargets.CurrentValue > float(0) && float(AffectedActors.Length) >= MaximumRagdollTargets.CurrentValue)
    {
        HitNormal = Normal(oImpacted.location - m_vSingularityLocation);
        vForce = HitNormal * PushAwayForce.CurrentValue;
        Resistance = oTarget.GetPowerResistance(m_oPawn, m_vSingularityLocation, HitNormal, fDamage, vForce, Class'SFXDamageType_Singularity_NoRagdoll', oTargetOverride);
        if (oTargetOverride != None)
        {
            oTarget = oTargetOverride;
        }
        bHasReacted = oTarget.ImpactWithPower(Resistance, m_oPawn, m_vSingularityLocation, HitNormal, fDamage, vForce, Class'SFXDamageType_Singularity_NoRagdoll');
        bRagdolled = FALSE;
    }
    else
    {
        HitNormal = Normal(m_vSingularityLocation - oImpacted.location);
        vForce = HitNormal * Force.CurrentValue;
        Resistance = oTarget.GetPowerResistance(m_oPawn, m_vSingularityLocation, HitNormal, fDamage, vForce, DefaultDamageType, oTargetOverride);
        if (oTargetOverride != None)
        {
            oTarget = oTargetOverride;
        }
        bHasReacted = oTarget.ImpactWithPower(Resistance, m_oPawn, m_vSingularityLocation, HitNormal, fDamage, vForce, DefaultDamageType);
        bRagdolled = Resistance == EPowerResistance.Resistance_None;
    }
    oPawn = SFXPawn(oTarget);
    if (oPawn != None && Resistance != EPowerResistance.Resistance_Full)
    {
        oPawn.AddPowerAssistEvent(m_oPawn, DisplayName, bRagdolled ? PowerAssistFullControlValue : PowerAssistPartialControlValue);
    }
    if (bRagdolled || bHasReacted)
    {
        ReplicateImpact(BioPawn(oImpacted), -1, , , , BioPawn(oImpacted).CurrentCustomAction);
    }
    if (!bRagdolled)
    {
        m_fSingularityCharges -= NonRagdollChargeUse;
        return bHasReacted;
    }
    m_fSingularityCharges -= RagdollChargeUse;
    oTarget.ExceededPhysicsThreshold(m_oPawn);
    if (oPawn != None)
    {
        oPawn.RegisterRBCallback(OnRagdollPhysicsImpact, TRUE);
    }
    if (!Patch4IterationApplied)
    {
        AddComboEffect(oImpacted, Class'SFXGameEffect_PowerCombo_Biotic', EffectDuration.CurrentValue);
    }
    oEffect = Manager.CreateEffect(Class'SFXGameEffect_Ragdoll', Name, EffectDuration.CurrentValue, 1, 0.0, m_oPawn.Controller);
    if (oEffect != None)
    {
        oEffect.OnApplied();
    }
    oEffect = Manager.CreateEffect(Class'SFXGameEffect_AntiGravity', Name, EffectDuration.CurrentValue, 1, 0.0, m_oPawn.Controller);
    if (oEffect != None)
    {
        oEffect.OnApplied();
    }
    oSingularityEffect = SFXGameEffect_Singularity(Manager.CreateEffect(Class'SFXGameEffect_Singularity', Name, EffectDuration.CurrentValue, 1, 1.0, m_oPawn.Controller));
    if (oSingularityEffect != None)
    {
        oSingularityEffect.SingularityLocation = m_vSingularityLocation;
        oSingularityEffect.ForcePerSecond = Force.CurrentValue;
        oSingularityEffect.Caster = m_oPawn;
        oSingularityEffect.DamagePerSecond = IsEvolvedWithChoice(2) ? Evolve_DoTDamage.CurrentValue : 0.0;
        oSingularityEffect.SingularityRadius = m_fSingularityRadius;
        oSingularityEffect.Power = Self;
        oSingularityEffect.OnApplied();
    }
    VParam.X = EffectDuration.CurrentValue;
    if (IsEvolvedWithChoice(2))
    {
        Class'RvrClientEffectManager'.static.GetClientEffectManager().Play(CE_DrainTargetCrust, oTarget, VParam);
    }
    else
    {
        Class'RvrClientEffectManager'.static.GetClientEffectManager().Play(CE_TargetCrust, oTarget, VParam);
    }
    AffectedActors.AddItem(oImpacted);
    return bHasReacted;
}
public function Internal_TurnOffSingularity()
{
    local Actor oActor;
    local SFXModule_GameEffectManager Manager;
    local SFXGameEffect oEffect;
    
    Class'RvrClientEffectManager'.static.GetClientEffectManager().@Stop(None, SingularityGuid, TRUE);
    foreach AffectedActors(oActor, )
    {
        if (oActor != None)
        {
            Manager = oActor.GetModule(Class'SFXModule_GameEffectManager');
            if (Manager != None)
            {
                foreach Manager.GameEffects(oEffect, )
                {
                    if (oEffect.Category == Name)
                    {
                        oEffect.CurrentTime = oEffect.Duration + float(1);
                    }
                }
            }
        }
    }
    AffectedActors.Length = 0;
    ComboAppliedActors.Length = 0;
    m_bSingularityActive = FALSE;
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    Begin Object Class=BioDynamicAnimSet Name=MY_DYN_HMM_BC_RifleTelekenesis
        m_nmOrigSetName = 'HMM_BC_RifleTelekenesis'
        Sequences = (AnimSequence'BIOG_HMM_BC_A.HMM_BC_RifleTelekenesis_BC_Start', AnimSequence'BIOG_HMM_BC_A.HMM_BC_RifleTelekenesis_BC_End')
        m_pBioAnimSetData = BioAnimSetData'BIOG_HMM_BC_A.HMM_BC_RifleTelekenesis_BioAnimSetData'
    End Object
    Evolve_DoTDamage = {
                        DynamicBonuses = (), 
                        RankBonuses[0] = 0.0, 
                        RankBonuses[1] = 0.0, 
                        RankBonuses[2] = 0.0, 
                        RankBonuses[3] = 0.0, 
                        RankBonuses[4] = 0.0, 
                        RankBonuses[5] = 0.0, 
                        BaseValue = 20.0, 
                        CurrentValue = 0.0, 
                        Formula = EPowerDataFormula.Normal
                       }
    DetonateForce = {
                     DynamicBonuses = (), 
                     RankBonuses[0] = 0.0, 
                     RankBonuses[1] = 0.0, 
                     RankBonuses[2] = 0.0, 
                     RankBonuses[3] = 0.0, 
                     RankBonuses[4] = 0.0, 
                     RankBonuses[5] = 0.0, 
                     BaseValue = 600.0, 
                     CurrentValue = 0.0, 
                     Formula = EPowerDataFormula.Normal
                    }
    DetonateDamage = {
                      DynamicBonuses = (), 
                      RankBonuses[0] = 0.0, 
                      RankBonuses[1] = 0.0, 
                      RankBonuses[2] = 0.0, 
                      RankBonuses[3] = 0.0, 
                      RankBonuses[4] = 0.0, 
                      RankBonuses[5] = 0.0, 
                      BaseValue = 300.0, 
                      CurrentValue = 0.0, 
                      Formula = EPowerDataFormula.Normal
                     }
    DetonateRadius = {
                      DynamicBonuses = (), 
                      RankBonuses[0] = 0.0, 
                      RankBonuses[1] = 0.0, 
                      RankBonuses[2] = 0.0, 
                      RankBonuses[3] = 0.0, 
                      RankBonuses[4] = 0.0, 
                      RankBonuses[5] = 0.0, 
                      BaseValue = 500.0, 
                      CurrentValue = 0.0, 
                      Formula = EPowerDataFormula.Normal
                     }
    NumCharges = {
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
    SingularityDuration = {
                           DynamicBonuses = (), 
                           RankBonuses[0] = 0.0, 
                           RankBonuses[1] = 0.0, 
                           RankBonuses[2] = 0.0, 
                           RankBonuses[3] = 0.0, 
                           RankBonuses[4] = 0.0, 
                           RankBonuses[5] = 0.0, 
                           BaseValue = 15.0, 
                           CurrentValue = 0.0, 
                           Formula = EPowerDataFormula.Normal
                          }
    PushAwayForce = {
                     DynamicBonuses = (), 
                     RankBonuses[0] = 0.0, 
                     RankBonuses[1] = 0.0, 
                     RankBonuses[2] = 0.0, 
                     RankBonuses[3] = 0.0, 
                     RankBonuses[4] = 0.0, 
                     RankBonuses[5] = 0.0, 
                     BaseValue = 500.0, 
                     CurrentValue = 0.0, 
                     Formula = EPowerDataFormula.Normal
                    }
    Evolve_RadiusBonus = 0.25
    Evolve_DurationBonus = 0.300000012
    Evolve_ExpandAmount = 0.349999994
    Evolve_ExpandDuration = 10.0
    Evolve_AdditionalCharges = 2.0
    Evolve_RechargeSpeed = 0.300000012
    DetonateMaxRagdollCount = 2
    CE_Singularity = RvrClientEffect'BioVFX_B_Singularity.VCFX.Singularity_Imp_VCFX'
    CE_GrowingSingularity = RvrClientEffect'BioVFX_B_Singularity.VCFX.Singularity_Imp_Growing_VCFX'
    CE_ExplodingSingularity = RvrClientEffect'BioVFX_B_Singularity.VCFX.Singularity_Explosion_VCFX'
    CE_TargetCrust = RvrClientEffect'BioVFX_B_Singularity.VCFX.Singularity_Lift_Crust_VCFX'
    CE_DrainTargetCrust = RvrClientEffect'BioVFX_B_Singularity.VCFX.Singularity_Damage_Crust_VCFX'
    m_fHitPlayerMinDuration = 2.0
    m_fLookupActorInterval = 0.75
    Release = WwiseEvent'Wwise_VFX_Biotics.Play_vfx_biotic_throw_cast'
    NonRagdollChargeUse = 0.25
    RagdollChargeUse = 1.0
    EvolvedImpactSounds = ({Sound = WwiseEvent'Wwise_Power_Biotic_Singularity.Play_power_biotic_P_singularity_evolimpact', bAnyEvolved = TRUE, bReplaceBaseSound = TRUE, EvolveChoice = EEvolveChoice.EvolveChoice1}
                          )
    EvolvedCastSounds = ({Sound = WwiseEvent'Wwise_Power_Biotic_Singularity.Play_power_biotic_P_singularity_evolcast', bAnyEvolved = TRUE, bReplaceBaseSound = TRUE, EvolveChoice = EEvolveChoice.EvolveChoice1}
                        )
    HenchmanEvolvedImpactSounds = ({Sound = WwiseEvent'Wwise_Power_Biotic_Singularity.Play_power_biotic_NP_singularity_evolimpact', bAnyEvolved = TRUE, bReplaceBaseSound = TRUE, EvolveChoice = EEvolveChoice.EvolveChoice1}
                                  )
    HenchmanEvolvedCastSounds = ({Sound = WwiseEvent'Wwise_Power_Biotic_Singularity.Play_power_biotic_NP_singularity_evolcast', bAnyEvolved = TRUE, bReplaceBaseSound = TRUE, EvolveChoice = EEvolveChoice.EvolveChoice1}
                                )
    DefaultDamageType = Class'SFXDamageType_Singularity'
    ProjectileClass = Class'SFXProjectile_PowerCustomAction_SuperSeeking'
    DetonationParameters = {ImpactFriends = TRUE, BlockedByObjects = FALSE, DistancedSorted = FALSE}
    ReleaseTime = 0.400000006
    CastAnimSet = MY_DYN_HMM_BC_RifleTelekenesis
    CastCameraAnim = CameraAnim'BioVFX_C_CamAnim.Powers.BC_RifleTelekinesis'
    CE_CasterCrustTemplate = RvrClientEffect'BioVFX_B_Biotics_Charge.VCFX.Biotics_Charge_VCFX'
    CE_ProjectileTemplate = RvrClientEffect'BioVFX_B_Singularity.VCFX.Singularity_Projectile_VCFX'
    ImpactSound = WwiseEvent'Wwise_Power_Biotic_Singularity.Play_power_biotic_P_singularity_impact'
    CastSound = WwiseEvent'Wwise_Power_Biotic_Singularity.Play_power_biotic_P_singularity_cast'
    HenchmanImpactSound = WwiseEvent'Wwise_Power_Biotic_Singularity.Play_power_biotic_NP_singularity_impact'
    HenchmanCastSound = WwiseEvent'Wwise_Power_Biotic_Singularity.Play_power_biotic_NP_singularity_cast'
    ImpactDistanceLayer = WwiseEvent'Wwise_Power_Shared.Play_power_shared_P_singularity_distant'
    HenchmanImpactDistanceLayer = WwiseEvent'Wwise_Power_Shared.Play_power_shared_NP_singularity_distant'
    bCustomImpactLogic = TRUE
    bOverrideComboDetonate = TRUE
    Discipline = EBioCapMode.BIO_CAPMODE_BIOTICS
    CooldownTime = {RankBonuses[1] = 0.25, BaseValue = 4.5, Formula = EPowerDataFormula.DivideByBonusSum}
    HenchmanCooldownTime = {RankBonuses[1] = 0.25, BaseValue = 9.0, Formula = EPowerDataFormula.DivideByBonusSum}
    MaximumRange = {BaseValue = 6000.0}
    ImpactRadius = {RankBonuses[2] = 0.200000003, BaseValue = 150.0}
    MaximumRagdollTargets = {BaseValue = 2.0}
    EffectDuration = {RankBonuses[2] = 0.200000003, BaseValue = 4.0}
    Damage = {BaseValue = 20.0}
    Force = {BaseValue = 100.0}
    ProjectileSpeed = {BaseValue = 3000.0}
    Ranks = ({
              Icon = 27, 
              Name = $0, 
              Description = $0, 
              Evolved1Name = $127058, 
              Evolved1Description = $155064, 
              Evolved2Name = $0, 
              Evolved2Description = $0
             }, 
             {
              Icon = 27, 
              Name = $0, 
              Description = $0, 
              Evolved1Name = $287414, 
              Evolved1Description = $619263, 
              Evolved2Name = $0, 
              Evolved2Description = $0
             }, 
             {
              Icon = 27, 
              Name = $0, 
              Description = $0, 
              Evolved1Name = $287415, 
              Evolved1Description = $501537, 
              Evolved2Name = $0, 
              Evolved2Description = $0
             }, 
             {
              Icon = 27, 
              Name = $0, 
              Description = $0, 
              Evolved1Name = $287424, 
              Evolved1Description = $287425, 
              Evolved2Name = $287427, 
              Evolved2Description = $287428
             }, 
             {
              Icon = 27, 
              Name = $0, 
              Description = $0, 
              Evolved1Name = $501497, 
              Evolved1Description = $501499, 
              Evolved2Name = $501502, 
              Evolved2Description = $501500
             }, 
             {
              Icon = 27, 
              Name = $0, 
              Description = $0, 
              Evolved1Name = $501501, 
              Evolved1Description = $501503, 
              Evolved2Name = $501498, 
              Evolved2Description = $501504
             }
            )
    PowerName = 'Singularity'
    PowerCustomActionID = 4
    DisplayName = $127058
    Description = $703579
    Icon = 27
    TalentDescription = $703579
    PowerType = EPowerType.PowerType_Projectile
    bDisableLeftHandIK = FALSE
    VocalizationEvent = ESFXVocalizationEventID.SFXVocalizationEvent_Power_Singularity
}