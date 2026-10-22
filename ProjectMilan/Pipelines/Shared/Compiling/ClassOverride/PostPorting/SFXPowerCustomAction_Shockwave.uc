
// Source: HumanFemale_Vanguard_MP
// MILAN CHANGE
// Fix rank 4B cone expansion causing impact math to stop being able to hit a target
Class SFXPowerCustomAction_Shockwave extends SFXPowerCustomAction
    config(Game);

var config PowerData NumShockwaveImpacts;
var config PowerData GravityLevel;
var config PowerData GravityDuration;
var config PowerData TimeBetweenImpacts;
var config PowerData LiftDuration;
var config PowerData Range;
var array<Actor> ImpactedActors;
var Class<SFXRumble_Power> ImpactRumbleClass;
var Class<SFXShake_Power> ImpactScreenShakeClass;
var Class<SFXShake_Power> ImpactActorScreenShakeClass;
var RvrClientEffectInterface CE_ShockwaveImpact;
var WwiseEvent ImpactActorSound;
var config float Evolve_DamageBonus;
var config float Evolve_RadiusBonus;
var config float Evolve_BioticComboMult;
var config float Evolve_CooldownBonus;
var config float Evolve_NumShockwavesBonus;
var int NumTargetsHit;

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
public function ApplyBonus(Name Parameter, SFXGameEffect Bonus, optional bool bRemove = FALSE)
{
    Super.ApplyBonus(Parameter, Bonus, bRemove);
    switch (Parameter)
    {
        case 'ImpactRadius':
            ApplyBonusToParameter(ImpactRadius, Bonus, bRemove);
            break;
        case 'EffectDuration':
            ApplyBonusToParameter(LiftDuration, Bonus, bRemove);
            break;
        default:
    }
}
public function ClientDoPowerSubsequentImpact(Actor oActor, optional int CustomActionReactionType, optional float Duration, optional int ImpactCount, optional float Delay, optional bool DoCallback)
{
    local Vector ImpactLocation;
    
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
public function DoImpact(Vector location, Rotator ProjectileRotation)
{
    local Actor HitActor;
    local array<Actor> NearbyActors;
    local Vector Param;
    local int nImpactCount;
    local AreaEffectParameters Params;
    
    if (SFXPawn_Player(m_oPawn) != None)
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
    Param.Y = ImpactRadius.CurrentValue;
    Class'RvrClientEffectManager'.static.GetClientEffectManager().PlayAtLocation(CE_ShockwaveImpact, location, , Param);
    if (m_oPawn != None && m_oPawn.Role == ENetRole.ROLE_Authority)
    {
        Params = DetonationParameters;
        Params.ConeDirection = Vector(ProjectileRotation);
        if (IsEvolvedWithChoice(1))
        {
            Params.ConeAngle = (1.0 + Evolve_RadiusBonus) * DetonationParameters.ConeAngle;
        }
        // MILAN CHANGE - Mgamerz - 2026-10-19
        // Do not change detonation parameters as it is not reset per cast which will cause impact math to be unable to hit target
        // DetonationParameters.ConeAngle *= 1.0 + Evolve_RadiusBonus;
        // END MILAN CHANGE
        nImpactCount = 0;
        GetNearbyActors(NearbyActors, location, ImpactRadius.CurrentValue, ImpactRadius.CurrentValue, Params);
        foreach NearbyActors(HitActor, )
        {
            if (ImpactedActors.Find(HitActor) != -1)
            {
                continue;
            }
            DoSubsequentImpact(HitActor, location, nImpactCount);
            nImpactCount++;
        }
    }
}
public function EvolvePower(EEvolveChoice choice)
{
    Super(SFXPowerCustomActionBase).EvolvePower(choice);
    switch (choice)
    {
        case EEvolveChoice.EvolveChoice1:
            AddEvolvedRankBonus(Force, Evolve_DamageBonus);
            AddEvolvedRankBonus(Damage, Evolve_DamageBonus);
            break;
        case EEvolveChoice.EvolveChoice2:
            AddEvolvedRankBonus(ImpactRadius, Evolve_RadiusBonus);
            break;
        case EEvolveChoice.EvolveChoice3:
            break;
        case EEvolveChoice.EvolveChoice4:
            AddEvolvedRankBonus(NumShockwaveImpacts, Evolve_NumShockwavesBonus);
            AddEvolvedRankBonus(Range, Evolve_NumShockwavesBonus);
            break;
        case EEvolveChoice.EvolveChoice5:
            AddEvolvedRankBonus(CooldownTime, Evolve_CooldownBonus);
            AddEvolvedRankBonus(HenchmanCooldownTime, Evolve_CooldownBonus);
            break;
        case EEvolveChoice.EvolveChoice6:
            break;
        default:
    }
    RecalculateAllPowerInfo();
}
public function OnPowerDetonated(Vector HitLocation, Vector HitNormal, optional SFXProjectile_PowerCustomAction oProjectile, optional Actor HitActor);

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
public function PopulatePowerStatBarEvolves()
{
    PowerStatBars.Length = 5;
    PowerStatBars[0].Data = SFXPawn_Henchman(m_oPawn) == None ? CooldownTime : HenchmanCooldownTime;
    PowerStatBars[0].srDisplayTotalToken = StatBarToken_Time;
    PowerStatBars[0].srStatBarDisplayTitle = StatBarTitle_Cooldown;
    PowerStatBars[0].EvolvedBonuses[4] = Evolve_CooldownBonus;
    PowerStatBars[1].Data = Damage;
    PowerStatBars[1].srDisplayTotalToken = StatBarToken_RawValue;
    PowerStatBars[1].srStatBarDisplayTitle = StatBarTitle_Damage;
    PowerStatBars[1].EvolvedBonuses[0] = Evolve_DamageBonus;
    PowerStatBars[2].Data = Force;
    PowerStatBars[2].srDisplayTotalToken = StatBarToken_Force;
    PowerStatBars[2].srStatBarDisplayTitle = StatBarTitle_Force;
    PowerStatBars[2].EvolvedBonuses[0] = Evolve_DamageBonus;
    PowerStatBars[3].Data = ImpactRadius;
    PowerStatBars[3].Formula = EPowerStatBarFormula.EPowerStatBarFormula_Distance;
    PowerStatBars[3].srDisplayTotalToken = StatBarToken_Distance;
    PowerStatBars[3].srStatBarDisplayTitle = StatBarTitle_ImpactRadius;
    PowerStatBars[3].EvolvedBonuses[1] = Evolve_RadiusBonus;
    PowerStatBars[4].Data = Range;
    PowerStatBars[4].Formula = EPowerStatBarFormula.EPowerStatBarFormula_Distance;
    PowerStatBars[4].srDisplayTotalToken = StatBarToken_Distance;
    PowerStatBars[4].srStatBarDisplayTitle = StatBarTitle_Range;
    PowerStatBars[4].EvolvedBonuses[3] = Evolve_NumShockwavesBonus;
}
public function RecalculateAllPowerData(optional bool bReset = FALSE)
{
    Super(SFXPowerCustomActionBase).RecalculateAllPowerData(bReset);
    RecalculatePowerData(NumShockwaveImpacts, bReset);
    RecalculatePowerData(ImpactRadius, bReset);
    RecalculatePowerData(TimeBetweenImpacts, bReset);
    RecalculatePowerData(LiftDuration, bReset);
    RecalculatePowerData(GravityDuration, bReset);
    RecalculatePowerData(GravityLevel, bReset);
    RecalculatePowerData(Range, bReset);
}
public function SFXProjectile_PowerCustomAction ReleaseProjectilePower()
{
    local Actor HitActor;
    local array<Actor> NearbyActors;
    local int nImpactCount;
    local AreaEffectParameters Params;
    
    ImpactedActors.Remove(0, ImpactedActors.Length);
    ImpactedActors.Length = 0;
    NumTargetsHit = 0;
    if (m_oPawn != None && m_oPawn.Role == ENetRole.ROLE_Authority)
    {
        nImpactCount = 0;
        Params = DetonationParameters;
        Params.ConeDirection = Vector(m_oPawn.Rotation);
        if (IsEvolvedWithChoice(1))
        {
            Params.ConeAngle = (1.0 + Evolve_RadiusBonus) * DetonationParameters.ConeAngle;
        }
        GetNearbyActors(NearbyActors, m_oPawn.location, ImpactRadius.CurrentValue, ImpactRadius.CurrentValue, Params);
        foreach NearbyActors(HitActor, )
        {
            if (ImpactedActors.Find(HitActor) != -1)
            {
                continue;
            }
            DoSubsequentImpact(HitActor, m_oPawn.location, nImpactCount);
            nImpactCount++;
        }
    }
    return SFXProjectile_PowerCustomAction_Shockwave(Super.ReleaseProjectilePower());
}
public function DoSubsequentImpact(Actor HitActor, Vector ImpactLocation, int nImpactCount)
{
    local SFXPawn HitPawn;
    local Vector Momentum;
    local Vector HitNormal;
    local EPowerResistance Resistance;
    local Actor oTargetOverride;
    local float fDamage;
    local bool bHasReacted;
    local SFXModule_GameEffectManager Manager;
    local SFXGameEffect oEffect;
    local SFXGameEffect_PowerCombo_Biotic BioticEffect;
    local Class<SFXDamageType> dmgType;
    local bool bRagdolled;
    
    if (float(NumTargetsHit) >= MaximumImpactTargets.CurrentValue)
    {
        return;
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
    if (MaximumRagdollTargets.CurrentValue > float(0) && float(NumTargetsHit) >= MaximumRagdollTargets.CurrentValue)
    {
        dmgType = Class'SFXDamageType_Shockwave_NoRagdoll';
    }
    Resistance = HitActor.GetPowerResistance(m_oPawn, ImpactLocation, HitNormal, fDamage, Momentum, dmgType, oTargetOverride);
    if (oTargetOverride != None)
    {
        ImpactedActors.AddItem(HitActor);
        HitActor = oTargetOverride;
    }
    bHasReacted = HitActor.ImpactWithPower(Resistance, m_oPawn, ImpactLocation, HitNormal, fDamage, Momentum, dmgType);
    bRagdolled = Resistance == EPowerResistance.Resistance_None && (MaximumRagdollTargets.CurrentValue == float(0) || float(NumTargetsHit) < MaximumRagdollTargets.CurrentValue);
    HitPawn = SFXPawn(HitActor);
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
    Manager = HitActor.GetModule(Class'SFXModule_GameEffectManager');
    if (Manager != None && Manager.HasEffectOfType(Class'SFXGameEffect_PowerCombo_Biotic'))
    {
        if (IsEvolvedWithChoice(2))
        {
            foreach Manager.GameEffects(oEffect, )
            {
                if (oEffect.@Class == Class'SFXGameEffect_PowerCombo_Biotic')
                {
                    BioticEffect = SFXGameEffect_PowerCombo_Biotic(oEffect);
                    if (BioticEffect != None)
                    {
                        BioticEffect.ComboDamage.X *= 1.0 + Evolve_BioticComboMult;
                        BioticEffect.ComboDamage.Y *= 1.0 + Evolve_BioticComboMult;
                        BioticEffect.ComboForce.X *= 1.0 + Evolve_BioticComboMult;
                        BioticEffect.ComboForce.Y *= 1.0 + Evolve_BioticComboMult;
                    }
                }
            }
        }
    }
    if (nImpactCount == 0)
    {
        HitActor.PlaySound(ImpactActorSound, TRUE);
        PlayPowerScreenShake(ImpactActorScreenShakeClass, ImpactLocation);
    }
    CheckForPowerCombo(HitActor, Resistance, ImpactLocation, HitNormal);
    ImpactedActors.AddItem(HitActor);
    NumTargetsHit++;
    if (HitPawn != None && bRagdolled)
    {
        HitPawn.RegisterRBCallback(OnRagdollPhysicsImpact, TRUE);
    }
    if (bHasReacted && HitPawn != None && ShouldReplicate())
    {
        ReplicatePowerSubsequentImpact(HitPawn, HitPawn.CurrentCustomAction);
    }
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    Begin Object Class=BioDynamicAnimSet Name=MY_DYN_HMM_BC_ThrowBiotic
        m_nmOrigSetName = 'HMM_BC_ThrowBiotic'
        Sequences = (AnimSequence'BIOG_HMM_BC_A.HMM_BC_ThrowBiotic_BC_Start', AnimSequence'BIOG_HMM_BC_A.HMM_BC_ThrowBiotic_BC_End')
        m_pBioAnimSetData = BioAnimSetData'BIOG_HMM_BC_A.HMM_BC_ThrowBiotic_BioAnimSetData'
    End Object
    NumShockwaveImpacts = {
                           DynamicBonuses = (), 
                           RankBonuses[0] = 0.0, 
                           RankBonuses[1] = 0.0, 
                           RankBonuses[2] = 0.0, 
                           RankBonuses[3] = 0.0, 
                           RankBonuses[4] = 0.0, 
                           RankBonuses[5] = 0.0, 
                           BaseValue = 6.0, 
                           CurrentValue = 0.0, 
                           Formula = EPowerDataFormula.Normal
                          }
    GravityLevel = {
                    DynamicBonuses = (), 
                    RankBonuses[0] = 0.0, 
                    RankBonuses[1] = 0.0, 
                    RankBonuses[2] = 0.0, 
                    RankBonuses[3] = 0.0, 
                    RankBonuses[4] = 0.0, 
                    RankBonuses[5] = 0.0, 
                    BaseValue = 0.600000024, 
                    CurrentValue = 0.0, 
                    Formula = EPowerDataFormula.Normal
                   }
    GravityDuration = {
                       DynamicBonuses = (), 
                       RankBonuses[0] = 0.0, 
                       RankBonuses[1] = 0.0, 
                       RankBonuses[2] = 0.0, 
                       RankBonuses[3] = 0.0, 
                       RankBonuses[4] = 0.0, 
                       RankBonuses[5] = 0.0, 
                       BaseValue = 1.0, 
                       CurrentValue = 0.0, 
                       Formula = EPowerDataFormula.Normal
                      }
    TimeBetweenImpacts = {
                          DynamicBonuses = (), 
                          RankBonuses[0] = 0.0, 
                          RankBonuses[1] = 0.0, 
                          RankBonuses[2] = 0.0, 
                          RankBonuses[3] = 0.0, 
                          RankBonuses[4] = 0.0, 
                          RankBonuses[5] = 0.0, 
                          BaseValue = 0.180000007, 
                          CurrentValue = 0.0, 
                          Formula = EPowerDataFormula.Normal
                         }
    LiftDuration = {
                    DynamicBonuses = (), 
                    RankBonuses[0] = 0.0, 
                    RankBonuses[1] = 0.0, 
                    RankBonuses[2] = 0.0, 
                    RankBonuses[3] = 0.0, 
                    RankBonuses[4] = 0.0, 
                    RankBonuses[5] = 0.0, 
                    BaseValue = 2.5, 
                    CurrentValue = 0.0, 
                    Formula = EPowerDataFormula.Normal
                   }
    Range = {
             DynamicBonuses = (), 
             RankBonuses[0] = 0.0, 
             RankBonuses[1] = 0.0, 
             RankBonuses[2] = 0.0, 
             RankBonuses[3] = 0.0, 
             RankBonuses[4] = 0.0, 
             RankBonuses[5] = 0.0, 
             BaseValue = 1000.0, 
             CurrentValue = 0.0, 
             Formula = EPowerDataFormula.Normal
            }
    ImpactRumbleClass = Class'SFXRumble_Power_HeavyImpact'
    ImpactScreenShakeClass = Class'SFXShake_Power_Shockwave'
    ImpactActorScreenShakeClass = Class'SFXShake_Power_HeavyImpact'
    CE_ShockwaveImpact = RvrClientEffect'BioVFX_B_Shockwave.VCFX.Shockwave_Impact_VCFX'
    ImpactActorSound = WwiseEvent'wwise_power_biotic_throw.Play_power_biotic_P_throw_impact'
    Evolve_DamageBonus = 0.300000012
    Evolve_RadiusBonus = 0.300000012
    Evolve_BioticComboMult = 0.5
    Evolve_CooldownBonus = 0.400000006
    Evolve_NumShockwavesBonus = 0.5
    ComboDetonators = (Class'SFXGameEffect_PowerCombo_Biotic', Class'SFXGameEffect_PowerCombo_Electric', Class'SFXGameEffect_PowerCombo_Fire', Class'SFXGameEffect_PowerCombo_Cryo')
    EvolvedImpactSounds = ({Sound = WwiseEvent'Wwise_Power_Biotic_Shockwave.Play_power_biotic_P_shockwave_evolripple', bAnyEvolved = TRUE, bReplaceBaseSound = TRUE, EvolveChoice = EEvolveChoice.EvolveChoice1}
                          )
    EvolvedCastSounds = ({Sound = WwiseEvent'Wwise_Power_Biotic_Shockwave.Play_power_biotic_P_shockwave_evolcast', bAnyEvolved = TRUE, bReplaceBaseSound = TRUE, EvolveChoice = EEvolveChoice.EvolveChoice1}
                        )
    HenchmanEvolvedImpactSounds = ({Sound = WwiseEvent'Wwise_Power_Biotic_Shockwave.Play_power_biotic_NP_shockwave_evolripple', bAnyEvolved = TRUE, bReplaceBaseSound = TRUE, EvolveChoice = EEvolveChoice.EvolveChoice1}
                                  )
    HenchmanEvolvedCastSounds = ({Sound = WwiseEvent'Wwise_Power_Biotic_Shockwave.Play_power_biotic_NP_shockwave_evolcast', bAnyEvolved = TRUE, bReplaceBaseSound = TRUE, EvolveChoice = EEvolveChoice.EvolveChoice1}
                                )
    DefaultDamageType = Class'SFXDamageType_Shockwave'
    ProjectileClass = Class'SFXProjectile_PowerCustomAction_Shockwave'
    DetonationParameters = {ConeAngle = 90.0, BlockedByObjects = FALSE}
    CastAnimSet = MY_DYN_HMM_BC_ThrowBiotic
    CE_CasterCrustTemplate = RvrClientEffect'BioVFX_B_Biotics_Charge.VCFX.Biotics_Charge_VCFX'
    CE_ProjectileTemplate = RvrClientEffect'BioVFX_B_Shockwave.VCFX.Shockwave_Projectile_VCFX'
    ImpactSound = WwiseEvent'Wwise_Power_Biotic_Shockwave.Play_power_biotic_P_shockwave_ripple'
    CastSound = WwiseEvent'Wwise_Power_Biotic_Shockwave.Play_power_biotic_P_shockwave_cast'
    HenchmanImpactSound = WwiseEvent'Wwise_Power_Biotic_Shockwave.Play_power_biotic_NP_shockwave_ripple'
    HenchmanCastSound = WwiseEvent'Wwise_Power_Biotic_Shockwave.Play_power_biotic_NP_shockwave_cast'
    ReleaseTime = 0.150000006
    bProjectileUsePawnRotation = TRUE
    bCustomImpactLogic = TRUE
    bCustomImpactSound = TRUE
    Discipline = EBioCapMode.BIO_CAPMODE_BIOTICS
    CooldownTime = {RankBonuses[1] = 0.25, BaseValue = 8.0, Formula = EPowerDataFormula.DivideByBonusSum}
    HenchmanCooldownTime = {RankBonuses[1] = 0.25, BaseValue = 20.0, Formula = EPowerDataFormula.DivideByBonusSum}
    MaximumRange = {BaseValue = 6000.0}
    ImpactRadius = {BaseValue = 200.0}
    MaximumImpactTargets = {BaseValue = 2.0}
    MaximumRagdollTargets = {BaseValue = 2.0}
    EffectDuration = {BaseValue = 1.0}
    Damage = {RankBonuses[2] = 0.200000003, BaseValue = 200.0}
    Force = {RankBonuses[2] = 0.200000003, BaseValue = 600.0}
    ProjectileSpeed = {BaseValue = 1000.0}
    Ranks = ({
              Icon = 50, 
              Name = $0, 
              Description = $0, 
              Evolved1Name = $314056, 
              Evolved1Description = $314057, 
              Evolved2Name = $0, 
              Evolved2Description = $0
             }, 
             {
              Icon = 50, 
              Name = $0, 
              Description = $0, 
              Evolved1Name = $314059, 
              Evolved1Description = $501588, 
              Evolved2Name = $0, 
              Evolved2Description = $0
             }, 
             {
              Icon = 50, 
              Name = $0, 
              Description = $0, 
              Evolved1Name = $244428, 
              Evolved1Description = $190375, 
              Evolved2Name = $0, 
              Evolved2Description = $0
             }, 
             {
              Icon = 50, 
              Name = $0, 
              Description = $0, 
              Evolved1Name = $190921, 
              Evolved1Description = $190922, 
              Evolved2Name = $339358, 
              Evolved2Description = $339357
             }, 
             {
              Icon = 50, 
              Name = $0, 
              Description = $0, 
              Evolved1Name = $195623, 
              Evolved1Description = $501094, 
              Evolved2Name = $501593, 
              Evolved2Description = $501594
             }, 
             {
              Icon = 50, 
              Name = $0, 
              Description = $0, 
              Evolved1Name = $501595, 
              Evolved1Description = $501596, 
              Evolved2Name = $501597, 
              Evolved2Description = $501598
             }
            )
    PowerName = 'Shockwave'
    PowerCustomActionID = 6
    DisplayName = $314056
    Description = $703605
    Icon = 50
    TalentDescription = $703605
    PowerType = EPowerType.PowerType_Projectile
    HenchmanPowerType = EPowerType.PowerType_Projectile
    bDisableLeftHandIK = FALSE
    VocalizationEvent = ESFXVocalizationEventID.SFXVocalizationEvent_Power_ShockWave
}
