// Source: LE3, Cerberus_Vanguard_MP
// Initial decompilation: 9/7/2024 4:00:32 PM
// MILAN CHANGE - UP3
// Allow armor combo detonations while keeping armored targets ineligible for lift
Class SFXPowerCustomActionMP_Lash extends SFXPowerCustomAction
    config(Game);

struct LashForceMultiplier
{
    var Name PawnType;
    var float ForceMultiplier;
};

var config PowerData PullForce;
var config PowerData PowerComboDuration;
var config array<LashForceMultiplier> ForceMultipliers;
var Class<SFXDamageType> PullDamageType;
var Vector PawnHitNormal;
var config float AntiGravityAmount;
var config float InitialForce;
var config float TowardCasterScale;
var config float Evolve_DamageBonus;
var config float Evolve_PowerComboBonus;
var config float Evolve_RechargeBonus;
var config float Evolve_DoTPercent;
var config float Evolve_DoTDuration;
var config float Evolve_NoCooldownChance;
var config float Evolve_ComboDurationBonus;
var config float GuardianShieldForceModifier;
var config float ResistanceForceMultiplier;
var SFXPawn PawnToPull;
var float PullAnimDelayAfterRelease;
var float TimeSinceRelease;
var WwiseEvent PullSound;
var WwiseEvent NPPullSound;
var bool bStopMovement;
var transient bool bClientCanProcessNoCooldown;
var bool bPowerCancelled;
var transient EClientNoCooldownDecision ClientNoCooldown;

public function CancelPower()
{
    bPowerCancelled = TRUE;
    DestroyProjectile();
}
// MILAN CHANGE - UP3 - Accept armor hits for combos without applying temporary lift effects
public function bool OnImpact(EPowerResistance Resistance, Actor oImpacted, int nPreviouslyImpacted, Vector HitLocation, Vector HitNormal)
{
    local SFXPawn oPawn;
    local bool bGuardian;
    local SFXModule_GameEffectManager Manager;
    local SFXGameEffect_PowerCombo_Biotic BioticEffect;
    local SFXGameEffect oEffect;
    local SFXGameEffect_DamageOverTime DOTEffect;
    local float fTimeUntilPull;

    if (bPowerCancelled)
    {
        return FALSE;
    }
    oPawn = SFXPawn(oImpacted);
    if (oPawn == None)
    {
        return FALSE;
    }
    Manager = oPawn.GetModule(Class'SFXModule_GameEffectManager');
    if (Manager == None)
    {
        return FALSE;
    }
    if (Resistance != EPowerResistance.Resistance_Full && IsEvolvedWithChoice(3))
    {
        DOTEffect = SFXGameEffect_DamageOverTime(Manager.CreateEffect(Class'SFXGameEffect_DamageOverTime', Name, Evolve_DoTDuration, 1, Evolve_DoTPercent * Damage.CurrentValue / Evolve_DoTDuration, m_oPawn.Controller));
        if (DOTEffect != None)
        {
            DOTEffect.DamageType = DefaultDamageType;
            DOTEffect.OnApplied();
        }
    }
    bGuardian = oPawn.IsA('SFXPawn_Guardian');
    if (Resistance == EPowerResistance.Resistance_Full && !bGuardian)
    {
        return FALSE;
    }
    PawnHitNormal = HitNormal;
    PawnToPull = oPawn;
    fTimeUntilPull = PullAnimDelayAfterRelease - (m_oPawn.WorldInfo.GameTimeSeconds - TimeSinceRelease);
    if (!oPawn.HasResistance(3) && (Resistance == EPowerResistance.Resistance_None || Resistance == EPowerResistance.Resistance_Partial && IsEvolvedWithChoice(5)))
    {
        if (fTimeUntilPull > float(0))
        {
            ApplyTemporaryGameEffect(oPawn, Class'SFXGameEffect_AntiGravity', fTimeUntilPull * 2.0, AntiGravityAmount, Name, m_oPawn.Controller);
            ApplyTemporaryGameEffect(oPawn, Class'SFXGameEffect_Ragdoll', fTimeUntilPull * 2.0, 0.0, Name, m_oPawn.Controller);
            ApplyTemporaryGameEffect(oPawn, Class'SFXGameEffect_LashLift', fTimeUntilPull * 2.0, 0.0, Name, m_oPawn.Controller);
        }
    }
    if (IsEvolvedWithChoice(1))
    {
        foreach Manager.GameEffects(oEffect, )
        {
            BioticEffect = SFXGameEffect_PowerCombo_Biotic(oEffect);
            if (BioticEffect != None)
            {
                BioticEffect.ComboDamage.X *= 1.0 + Evolve_PowerComboBonus;
                BioticEffect.ComboDamage.Y *= 1.0 + Evolve_PowerComboBonus;
                BioticEffect.ComboForce.X *= 1.0 + Evolve_PowerComboBonus;
                BioticEffect.ComboForce.Y *= 1.0 + Evolve_PowerComboBonus;
            }
        }
    }
    if (fTimeUntilPull > float(0))
    {
        m_oPawn.SetTimer(fTimeUntilPull, FALSE, 'PullTarget', Self);
    }
    else
    {
        PullTarget();
    }
    return TRUE;
}
// END MILAN CHANGE
public function StartCustomAction()
{
    local SFXPlayerController PC;

    Super.StartCustomAction();
    bPowerCancelled = FALSE;
    PC = SFXPlayerController(m_oPawn.Controller);
    if (PC != None && bStopMovement == FALSE)
    {
        PC.m_bPermanentWalk = TRUE;
        bStopMovement = TRUE;
    }
}
public function ApplyBonus(Name Parameter, SFXGameEffect Bonus, optional bool bRemove = FALSE)
{
    Super.ApplyBonus(Parameter, Bonus, bRemove);
    switch (Parameter)
    {
        case 'Force':
            ApplyBonusToParameter(PullForce, Bonus, bRemove);
            break;
        case 'EffectDuration':
            ApplyBonusToParameter(PowerComboDuration, Bonus, bRemove);
            break;
        default:
    }
}
public function ClientDoPowerSubsequentImpact(Actor oActor, optional int CustomActionReactionType, optional float Duration, optional int ImpactCount, optional float Delay, optional bool DoCallback)
{
    switch (ImpactCount)
    {
        case -1:
            if (bClientCanProcessNoCooldown)
            {
                ResetPowerCooldown();
            }
            ClientNoCooldown = EClientNoCooldownDecision.NoCooldown_Success;
            break;
        case -2:
            ClientNoCooldown = EClientNoCooldownDecision.NoCooldown_Failure;
            break;
        default:
    }
    if (ImpactCount > -3 && ImpactCount < 0 && bClientCanProcessNoCooldown)
    {
        bClientCanProcessNoCooldown = FALSE;
        ClientNoCooldown = EClientNoCooldownDecision.NoCooldown_NoDecision;
    }
}
public function EvolvePower(EEvolveChoice choice)
{
    Super(SFXPowerCustomActionBase).EvolvePower(choice);
    switch (choice)
    {
        case EEvolveChoice.EvolveChoice1:
            AddEvolvedRankBonus(Damage, Evolve_DamageBonus);
            break;
        case EEvolveChoice.EvolveChoice2:
            break;
        case EEvolveChoice.EvolveChoice3:
            AddEvolvedRankBonus(CooldownTime, Evolve_RechargeBonus);
            break;
        case EEvolveChoice.EvolveChoice4:
            break;
        case EEvolveChoice.EvolveChoice5:
            AddEvolvedRankBonus(PowerComboDuration, Evolve_ComboDurationBonus);
            break;
        case EEvolveChoice.EvolveChoice6:
            break;
        default:
    }
    RecalculateAllPowerInfo();
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
public function PopulatePowerStatBarEvolves()
{
    PowerStatBars.Length = 3;
    PowerStatBars[0].Data = SFXPawn_Henchman(m_oPawn) == None ? CooldownTime : HenchmanCooldownTime;
    PowerStatBars[0].srDisplayTotalToken = StatBarToken_Time;
    PowerStatBars[0].srStatBarDisplayTitle = StatBarTitle_Cooldown;
    PowerStatBars[0].EvolvedBonuses[2] = Evolve_RechargeBonus;
    PowerStatBars[1].Data = Damage;
    PowerStatBars[1].srDisplayTotalToken = StatBarToken_RawValue;
    PowerStatBars[1].srStatBarDisplayTitle = StatBarTitle_Damage;
    PowerStatBars[1].EvolvedBonuses[0] = Evolve_DamageBonus;
    PowerStatBars[2].Data = PullForce;
    PowerStatBars[2].srDisplayTotalToken = StatBarToken_Force;
    PowerStatBars[2].srStatBarDisplayTitle = StatBarTitle_Force;
}
public function RecalculateAllPowerData(optional bool bReset = FALSE)
{
    Super(SFXPowerCustomActionBase).RecalculateAllPowerData(bReset);
    RecalculatePowerData(PullForce, bReset);
    RecalculatePowerData(PowerComboDuration, bReset);
}
public function ReleasePower()
{
    Super.ReleasePower();
    TimeSinceRelease = m_oPawn.WorldInfo.GameTimeSeconds;
}
public function StartPowerCooldown()
{
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
    local SFXPlayerController PC;

    Super.StopCustomAction();
    PC = SFXPlayerController(m_oPawn.Controller);
    if (PC != None && bStopMovement)
    {
        PC.m_bPermanentWalk = FALSE;
        bStopMovement = FALSE;
    }
    CancelPower();
}
public function DestroyProjectile()
{
    local SFXProjectile_PowerCustomAction oProjectile;

    if (m_oPawn.Role == ENetRole.ROLE_Authority)
    {
        foreach Projectiles(oProjectile, )
        {
            oProjectile.Explode(oProjectile.location, Normal(oProjectile.Velocity));
        }
    }
}
// MILAN CHANGE - UP3 - Keep armored Lash targets out of ragdoll and lift-primer processing
public function PullTarget()
{
    local float fDamage;
    local Vector vForce;
    local Actor oTargetOverride;
    local EPowerResistance Resistance;
    local bool bRagdolled;
    local SFXModule_GameEffectManager Manager;
    local SFXGameEffect_CustomFlag oWhipEffect;
    local SFXGameEffect_PowerCombo_Biotic ComboEffect;
    local bool bIsGuardian;
    local int idx;

    if (PawnToPull == None)
    {
        return;
    }
    PawnHitNormal *= 1.0 - TowardCasterScale;
    PawnHitNormal = Normal(PawnHitNormal + Normal(m_oPawn.location - PawnToPull.location) * TowardCasterScale);
    vForce = PawnHitNormal * PullForce.CurrentValue;
    Manager = PawnToPull.GetModule(Class'SFXModule_GameEffectManager');
    oWhipEffect = SFXGameEffect_CustomFlag(Manager.GetFirstEffectOfTypeAndCategory(Class'SFXGameEffect_CustomFlag', 'WhipSmash'));
    if (oWhipEffect != None)
    {
        vForce *= oWhipEffect.EffectValue;
    }
    Resistance = PawnToPull.GetPowerResistance(m_oPawn, PawnToPull.location, PawnHitNormal, fDamage, vForce, DefaultDamageType, oTargetOverride);
    if (oTargetOverride != None)
    {
        PawnToPull = SFXPawn(oTargetOverride);
        if (PawnToPull == None)
        {
            return;
        }
    }
    bIsGuardian = PawnToPull.IsA('SFXPawn_Guardian');
    if (bIsGuardian && Resistance == EPowerResistance.Resistance_Full)
    {
        vForce *= GuardianShieldForceModifier;
    }
    if (Resistance == EPowerResistance.Resistance_Partial && IsEvolvedWithChoice(5))
    {
        vForce *= ResistanceForceMultiplier;
    }
    for (idx = 0; idx < ForceMultipliers.Length; idx++)
    {
        if (PawnToPull.IsA(ForceMultipliers[idx].PawnType))
        {
            vForce *= ForceMultipliers[idx].ForceMultiplier;
            break;
        }
    }
    if (Resistance == EPowerResistance.Resistance_Partial && IsEvolvedWithChoice(5) && PawnToPull.HasResistance(3) == FALSE)
    {
        Resistance = EPowerResistance.Resistance_None;
    }
    PawnToPull.ImpactWithPower(Resistance, m_oPawn, PawnToPull.location, PawnHitNormal, fDamage, vForce, DefaultDamageType);
    if (m_oPawn.IsLocallyControlled() && m_oPawn.IsHumanControlled())
    {
        PawnToPull.PlaySound(PullSound);
    }
    else
    {
        PawnToPull.PlaySound(NPPullSound);
    }
    bRagdolled = !PawnToPull.HasResistance(3) && (Resistance == EPowerResistance.Resistance_None || Resistance == EPowerResistance.Resistance_Partial && IsEvolvedWithChoice(5));
    if (bIsGuardian)
    {
        PawnToPull.AddPowerAssistEvent(m_oPawn, DisplayName, PowerAssistFullControlValue);
    }
    else
    {
        PawnToPull.AddPowerAssistEvent(m_oPawn, DisplayName, bRagdolled ? PowerAssistFullControlValue : PowerAssistPartialControlValue);
    }
    if (bRagdolled)
    {
        ComboEffect = SFXGameEffect_PowerCombo_Biotic(AddComboEffect(PawnToPull, Class'SFXGameEffect_PowerCombo_Biotic', PowerComboDuration.CurrentValue));
        if (ComboEffect != None && IsEvolvedWithChoice(1))
        {
            ComboEffect.ComboDamage.X *= 1.0 + Evolve_PowerComboBonus;
            ComboEffect.ComboDamage.Y *= 1.0 + Evolve_PowerComboBonus;
            ComboEffect.ComboForce.X *= 1.0 + Evolve_PowerComboBonus;
            ComboEffect.ComboForce.Y *= 1.0 + Evolve_PowerComboBonus;
        }
        PawnToPull.RegisterRBCallback(OnRagdollPhysicsImpact, TRUE);
        Manager.RemoveEffectsByTypeAndCategory(Class'SFXGameEffect_AntiGravity', Name);
        Manager.RemoveEffectsByTypeAndCategory(Class'SFXGameEffect_Ragdoll', Name);
        Manager.RemoveEffectsByTypeAndCategory(Class'SFXGameEffect_LashLift', Name);
    }
    PawnToPull = None;
}
// END MILAN CHANGE

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    Begin Object Class=BioDynamicAnimSet Name=MY_DYN_HMM_CB_XCerberus
        m_nmOrigSetName = 'HMM_CB_XCerberus'
        Sequences = (AnimSequence'BIOG_HMM_CB_CON_MP2.HMM_CB_XCerberus_CB_Whip_Begin', AnimSequence'BIOG_HMM_CB_CON_MP2.HMM_CB_XCerberus_CB_Whip_End')
        m_pBioAnimSetData = BioAnimSetData'BIOG_HMM_CB_CON_MP2.BioAnimSetData_0'
    End Object
    PullForce = {
                 DynamicBonuses = (),
                 RankBonuses[0] = 0.0,
                 RankBonuses[1] = 0.0,
                 RankBonuses[2] = 0.0,
                 RankBonuses[3] = 0.0,
                 RankBonuses[4] = 0.0,
                 RankBonuses[5] = 0.0,
                 BaseValue = 1200.0,
                 CurrentValue = 0.0,
                 Formula = EPowerDataFormula.Normal
                }
    PowerComboDuration = {
                          DynamicBonuses = (),
                          RankBonuses[0] = 0.0,
                          RankBonuses[1] = 0.0,
                          RankBonuses[2] = 0.0,
                          RankBonuses[3] = 0.0,
                          RankBonuses[4] = 0.0,
                          RankBonuses[5] = 0.0,
                          BaseValue = 3.0,
                          CurrentValue = 0.0,
                          Formula = EPowerDataFormula.Normal
                         }
    ForceMultipliers = ({PawnType = 'SFXPawn_Centurion', ForceMultiplier = 1.39999998},
                        {PawnType = 'SFXPawn_Guardian', ForceMultiplier = 1.20000005}
                       )
    TowardCasterScale = 0.25
    Evolve_DamageBonus = 0.300000012
    Evolve_PowerComboBonus = 0.5
    Evolve_RechargeBonus = 0.349999994
    Evolve_DoTPercent = 1.0
    Evolve_DoTDuration = 10.0
    Evolve_NoCooldownChance = 0.349999994
    Evolve_ComboDurationBonus = 1.0
    GuardianShieldForceModifier = 0.0199999996
    ResistanceForceMultiplier = 0.5
    PullAnimDelayAfterRelease = 0.600000024
    PullSound = WwiseEvent'Wwise_Power_DLC_Lash.Play_power_DLC_P_Lash_pull'
    NPPullSound = WwiseEvent'Wwise_Power_DLC_Lash.Play_power_DLC_NP_Lash_pull'
    ComboDetonators = (Class'SFXGameEffect_PowerCombo_Biotic', Class'SFXGameEffect_PowerCombo_Electric', Class'SFXGameEffect_PowerCombo_Cryo', Class'SFXGameEffect_PowerCombo_Fire')
    BS_StartCastAnimation = {
                             AnimName = ('None',
                                         'CB_Whip_Begin',
                                         'CB_Whip_Begin',
                                         'CB_Whip_Begin',
                                         'CB_Whip_Begin',
                                         'CB_Whip_Begin',
                                         'CB_Whip_Begin',
                                         'CB_Whip_Begin',
                                         'None',
                                         'None',
                                         'None',
                                         'CB_Whip_Begin'
                                        )
                            }
    BS_EndCastAnimation = {
                           AnimName = ('None',
                                       'CB_Whip_End',
                                       'CB_Whip_End',
                                       'CB_Whip_End',
                                       'CB_Whip_End',
                                       'CB_Whip_End',
                                       'CB_Whip_End',
                                       'CB_Whip_End',
                                       'None',
                                       'None',
                                       'None',
                                       'CB_Whip_End'
                                      )
                          }
    DefaultDamageType = Class'SFXDamageType_Lash'
    ProjectileClass = Class'SFXProjectile_PowerCustomAction_Lash'
    DetonationParameters = {ImpactPlaceables = FALSE, BlockedByObjects = FALSE}
    ReleaseTime = 0.300000012
    CastAnimSet = MY_DYN_HMM_CB_XCerberus
    fStartAnimBlendOutTime = 0.699999988
    CE_CasterCrustTemplate = RvrClientEffect'BioVFX_B_Biotics_Charge.VCFX.Biotics_Charge_VCFX'
    CE_ProjectileTemplate = RvrClientEffect'BioVFX_DLC_B_whip.VCFX.Whip_Projectile_VCFX'
    CE_ImpactTemplate = RvrClientEffect'BioVFX_B_Pull.VCFX.Pull_Impact_VCFX'
    ImpactSound = WwiseEvent'Wwise_Power_DLC_Lash.Play_power_DLC_P_Lash_impact'
    CastSound = WwiseEvent'Wwise_Power_DLC_Lash.Play_power_DLC_P_Lash_cast'
    HenchmanImpactSound = WwiseEvent'Wwise_Power_DLC_Lash.Play_power_DLC_NP_Lash_impact'
    HenchmanCastSound = WwiseEvent'Wwise_Power_DLC_Lash.Play_power_DLC_NP_Lash_cast'
    Discipline = EBioCapMode.BIO_CAPMODE_BIOTICS
    CooldownTime = {RankBonuses[1] = 0.25, BaseValue = 6.0, Formula = EPowerDataFormula.DivideByBonusSum}
    MaximumRange = {BaseValue = 4000.0}
    ImpactRadius = {BaseValue = 150.0, Formula = EPowerDataFormula.BonusIsHardValue}
    MaximumImpactTargets = {BaseValue = 1.0}
    Damage = {RankBonuses[2] = 0.200000003, BaseValue = 150.0}
    Force = {BaseValue = 800.0}
    ProjectileSpeed = {BaseValue = 4000.0}
    Ranks = ({
              Icon = 2,
              Name = $0,
              Description = $0,
              Evolved1Name = $729452,
              Evolved1Description = $731540,
              Evolved2Name = $0,
              Evolved2Description = $0
             },
             {
              Icon = 2,
              Name = $0,
              Description = $0,
              Evolved1Name = $251101,
              Evolved1Description = $619264,
              Evolved2Name = $0,
              Evolved2Description = $0
             },
             {
              Icon = 2,
              Name = $0,
              Description = $0,
              Evolved1Name = $731541,
              Evolved1Description = $731542,
              Evolved2Name = $0,
              Evolved2Description = $0
             },
             {
              Icon = 2,
              Name = $0,
              Description = $0,
              Evolved1Name = $731541,
              Evolved1Description = $731543,
              Evolved2Name = $731544,
              Evolved2Description = $731545
             },
             {
              Icon = 2,
              Name = $0,
              Description = $0,
              Evolved1Name = $731546,
              Evolved1Description = $731547,
              Evolved2Name = $731548,
              Evolved2Description = $731549
             },
             {
              Icon = 2,
              Name = $0,
              Description = $0,
              Evolved1Name = $731550,
              Evolved1Description = $731551,
              Evolved2Name = $731552,
              Evolved2Description = $731553
             }
            )
    PowerName = 'Lash'
    PowerCustomActionID = 41
    DisplayName = $729452
    Description = $731540
    Icon = 2
    IconResource = GFxMovieInfo'GUI_SF_Lash.Lash'
    TalentDescription = $731540
    PowerType = EPowerType.PowerType_Projectile
    DamageReductionLength = 1.0
    DamageReductionAmount = 0.5
    bDisableMovement = TRUE
    bDisableLeftHandIK = FALSE
    bAllowDamageReduction = TRUE
    VocalizationEvent = ESFXVocalizationEventID.SFXVocalizationEvent_Power_Pull
}
