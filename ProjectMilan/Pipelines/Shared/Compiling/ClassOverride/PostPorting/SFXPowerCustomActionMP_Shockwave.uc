// Source: LE3, HumanFemale_Vanguard_MP
// MILAN CHANGE - UP3/Mgamerz
// Apply per-pulse Shockwave limits within tunable cast-wide hit and ragdoll budgets
Class SFXPowerCustomActionMP_Shockwave extends SFXPowerCustomAction_Shockwave
    config(Game);

var config int MaxImpactTargetsPerPulse;
var config int MaxRagdollTargetsPerPulse;
var config int MaxDetonations;
var transient int PulseTargetsHit;
var transient int PulseRagdollsHit;
var transient int CastRagdollsHit;
var transient int CastDetonations;

// ImpactCount carries these flags through the existing subsequent-impact RPC.
const NoRagdollImpactFlag = 1;
const NotFirstPulseHitFlag = 2;

private final function int GetShockwaveHitLimit()
{
    return Max(0, int(MaximumImpactTargets.CurrentValue));
}

private final function int GetShockwaveRagdollLimit()
{
    return Min(Max(0, int(MaximumRagdollTargets.CurrentValue)), int(float(GetShockwaveHitLimit()) * 0.5));
}

// MILAN CHANGE - UP3/Mgamerz - Reset budgets once and let the parent perform the initial hit pass
public function SFXProjectile_PowerCustomAction ReleaseProjectilePower()
{
    PulseTargetsHit = 0;
    PulseRagdollsHit = 0;
    CastRagdollsHit = 0;
    CastDetonations = 0;
    return Super.ReleaseProjectilePower();
}
// END MILAN CHANGE

// MILAN CHANGE - UP3/Mgamerz - Reset only the pulse budgets for each traveling ripple
public function DoImpact(Vector location, Rotator ProjectileRotation)
{
    PulseTargetsHit = 0;
    PulseRagdollsHit = 0;
    Super.DoImpact(location, ProjectileRotation);
}
// END MILAN CHANGE

private final function SFXGameEffect_PowerCombo FindShockwaveCombo(Actor Target, EPowerResistance Resistance)
{
    local SFXModule_GameEffectManager Manager;
    local SFXGameEffect Effect;
    local SFXGameEffect_PowerCombo ComboEffect;
    local SFXGameEffect_PowerCombo LatestComboEffect;
    local BioPawn TargetPawn;

    if (m_oPawn == None || m_oPawn.Role != ENetRole.ROLE_Authority || CastDetonations >= MaxDetonations)
    {
        return None;
    }
    TargetPawn = BioPawn(Target);
    if (TargetPawn == None || Resistance == EPowerResistance.Resistance_Full || ComboDetonators.Length == 0)
    {
        return None;
    }
    Manager = Target.GetModule(Class'SFXModule_GameEffectManager');
    if (Manager == None)
    {
        return None;
    }
    // Match CheckForPowerCombo's selection without spending a slot on an unprimed hit
    foreach Manager.GameEffects(Effect, )
    {
        ComboEffect = SFXGameEffect_PowerCombo(Effect);
        if (ComboEffect != None && ComboEffect.SourcePower != None)
        {
            if (ComboDetonators.Find(ComboEffect.Class) != -1 && ComboEffect.SourcePower.PowerName != PowerName)
            {
                if (!ComboEffect.bOnlyOnDeath || TargetPawn.IsDead())
                {
                    if (LatestComboEffect == None || ComboEffect.CurrentTime < LatestComboEffect.CurrentTime)
                    {
                        LatestComboEffect = ComboEffect;
                    }
                }
            }
        }
    }
    return LatestComboEffect;
}

// MILAN CHANGE - UP3/Mgamerz - Bound all direct hits, pets included, and limit ragdolls to half the cast hit budget
// This allows future mods to scale up this power (like zombie mod) so it can work in high enemy count scenarios
public function DoSubsequentImpact(Actor HitActor, Vector ImpactLocation, int nImpactCount)
{
    local SFXPawn HitPawn;
    local Vector Momentum;
    local Vector HitNormal;
    local EPowerResistance Resistance;
    local Actor oTargetOverride;
    local float fDamage;
    local bool bHasReacted;
    local bool bAuthority;
    local bool bCanRagdoll;
    local bool bRagdolled;
    local bool bFirstPulseHit;
    local Class<SFXDamageType> dmgType;
    local SFXGameEffect_PowerCombo ComboEffect;
    local SFXGameEffect_PowerCombo_Biotic BioticEffect;
    local int ReplicationFlags;

    if (HitActor == None || m_oPawn == None)
    {
        return;
    }
    bAuthority = m_oPawn.Role == ENetRole.ROLE_Authority;
    if (bAuthority)
    {
        if (NumTargetsHit >= GetShockwaveHitLimit() || PulseTargetsHit >= MaxImpactTargetsPerPulse || ImpactedActors.Find(HitActor) != -1)
        {
            return;
        }
        bCanRagdoll = CastRagdollsHit < GetShockwaveRagdollLimit() && PulseRagdollsHit < MaxRagdollTargetsPerPulse;
        bFirstPulseHit = PulseTargetsHit == 0;
    }
    else
    {
        // Use replicated flag as client
        bCanRagdoll = (nImpactCount & NoRagdollImpactFlag) == 0;
        bFirstPulseHit = (nImpactCount & NotFirstPulseHitFlag) == 0;
    }

    HitNormal = Normal(ImpactLocation - HitActor.location);
    Momentum = -HitNormal;
    if (IsEvolvedWithChoice(5))
    {
        Momentum.Z = 1.0;
        Momentum = Normal(Momentum) * Force.CurrentValue;
    }
    else
    {
        if (Momentum.Z < float(0))
        {
            Momentum.Z = 0.200000003;
        }
        else if (Momentum.Z > 0.800000012)
        {
            Momentum.X += FRand() * 0.400000006 - 0.200000003;
            Momentum.Y += FRand() * 0.400000006 - 0.200000003;
        }
        Momentum = Normal(Momentum) * Force.CurrentValue;
    }
    fDamage = Damage.CurrentValue;
    dmgType = DefaultDamageType;
    if (!bCanRagdoll)
    {
        dmgType = Class'SFXDamageType_Shockwave_NoRagdoll';
    }
    Resistance = HitActor.GetPowerResistance(m_oPawn, ImpactLocation, HitNormal, fDamage, Momentum, dmgType, oTargetOverride);
    if (oTargetOverride != None)
    {
        if (bAuthority)
        {
            ImpactedActors.AddItem(HitActor);
            if (ImpactedActors.Find(oTargetOverride) != -1)
            {
                return;
            }
        }
        HitActor = oTargetOverride;
    }
    HitPawn = SFXPawn(HitActor);
    bRagdolled = bCanRagdoll && HitPawn != None && Resistance == EPowerResistance.Resistance_None;
    if (bAuthority)
    {
        // Update counts before actual impact
        ImpactedActors.AddItem(HitActor);
        NumTargetsHit++;
        PulseTargetsHit++;
        if (bRagdolled)
        {
            CastRagdollsHit++;
            PulseRagdollsHit++;
        }
    }
    bHasReacted = HitActor.ImpactWithPower(Resistance, m_oPawn, ImpactLocation, HitNormal, fDamage, Momentum, dmgType);
    if (HitPawn != None && Resistance != EPowerResistance.Resistance_Full)
    {
        HitPawn.AddPowerAssistEvent(m_oPawn, DisplayName, bRagdolled ? PowerAssistFullControlValue : PowerAssistPartialControlValue);
    }
    if (bRagdolled)
    {
        if (IsEvolvedWithChoice(5))
        {
            ApplyTemporaryGameEffect(HitActor, Class'SFXGameEffect_ShockwaveLift', LiftDuration.CurrentValue, 1.0, Name, m_oPawn.Controller);
            AddComboEffect(HitActor, Class'SFXGameEffect_PowerCombo_Biotic', LiftDuration.CurrentValue);
        }
        else
        {
            ApplyTemporaryGameEffect(HitActor, Class'SFXGameEffect_AntiGravity', GravityDuration.CurrentValue, GravityLevel.CurrentValue, Name, m_oPawn.Controller);
        }
    }
    if (bFirstPulseHit)
    {
        HitActor.PlaySound(ImpactActorSound, TRUE);
        PlayPowerScreenShake(ImpactActorScreenShakeClass, ImpactLocation);
    }
    ComboEffect = FindShockwaveCombo(HitActor, Resistance);
    if (ComboEffect != None)
    {
        BioticEffect = SFXGameEffect_PowerCombo_Biotic(ComboEffect);
        if (BioticEffect != None && IsEvolvedWithChoice(2))
        {
            BioticEffect.ComboDamage.X *= 1.0 + Evolve_BioticComboMult;
            BioticEffect.ComboDamage.Y *= 1.0 + Evolve_BioticComboMult;
            BioticEffect.ComboForce.X *= 1.0 + Evolve_BioticComboMult;
            BioticEffect.ComboForce.Y *= 1.0 + Evolve_BioticComboMult;
        }
        CastDetonations++;
        DoPowerCombo(ComboEffect, HitPawn, ImpactLocation, HitNormal);
    }
    if (HitPawn != None && bRagdolled)
    {
        HitPawn.RegisterRBCallback(OnRagdollPhysicsImpact, TRUE);
    }
    if (bHasReacted && HitPawn != None && ShouldReplicate())
    {
        if (!bRagdolled)
        {
            ReplicationFlags += NoRagdollImpactFlag;
        }
        if (!bFirstPulseHit)
        {
            ReplicationFlags += NotFirstPulseHitFlag;
        }
        ReplicatePowerSubsequentImpact(HitPawn, HitPawn.CurrentCustomAction, , ReplicationFlags);
    }
}
// END MILAN CHANGE

defaultproperties
{
    Begin Object Class=BioDynamicAnimSet Name=MY_DYN_HMM_BC_ThrowBiotic
        m_nmOrigSetName = 'HMM_BC_ThrowBiotic'
        Sequences = (AnimSequence'BIOG_HMM_BC_A.HMM_BC_ThrowBiotic_BC_Start', AnimSequence'BIOG_HMM_BC_A.HMM_BC_ThrowBiotic_BC_End')
        m_pBioAnimSetData = BioAnimSetData'BIOG_HMM_BC_A.HMM_BC_ThrowBiotic_BioAnimSetData'
    End Object
    CastAnimSet = MY_DYN_HMM_BC_ThrowBiotic
    MaxImpactTargetsPerPulse = 2
    MaxRagdollTargetsPerPulse = 1
    MaxDetonations = 2
    MaximumImpactTargets = {BaseValue = 8.0}
    MaximumRagdollTargets = {BaseValue = 4.0}
}
