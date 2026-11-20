// Source: ME3, Patch_SFXPowerCustomAction_Reave
// Decompiled 11/17/2026 7:38:39 AM against AsariCommando_Adept_MP.pcc
Class SFXPowerCustomAction_Reave extends SFXPowerCustomAction
    config(Game);

var config SFXPowerCustomActionBase.PowerData DamageReduction;
var WwiseEvent HealSound;
var config float Evolve_DurationBonus;
var config float Evolve_Radius;
var config float Evolve_DamageReductionBonus;
var config float Evolve_RechargeSpeedBonus;
var config float Evolve_DamageBonus;
var config float Evolve_DurationBonus2;
var config float Evolve_DamageReductionBonus2;
var config float Evolve_ArmorBarrierBonus;
var RvrClientEffectInterface CE_CasterCrustTemplateOrganic;
var RvrClientEffectInterface CE_CasterCrustTemplateRobotic;
var RvrClientEffectInterface CE_CasterCrustTemplateMiss;
var RvrClientEffectInterface CE_TargetCrustTemplateOrganic;
var RvrClientEffectInterface CE_TargetCrustTemplateRobotic;
var WwiseEvent ConfirmStartSound;
var WwiseEvent ConfirmStopSound;
var WwiseEvent HenchmanConfirmStartSound;
var WwiseEvent HenchmanConfirmStopSound;

public function bool OnImpact(Actor.EPowerResistance Resistance, Actor oImpacted, int nPreviouslyImpacted, Object.Vector HitLocation, Object.Vector HitNormal)
{
    local BioPawn oTargetPawn;
    local SFXModule_GameEffectManager Manager;
    local SFXGameEffect_Reave REAVE;
    local RvrClientEffectInterface.RvrClientEffectTarget CETarget;
    
    if (m_oPawn == None)
    {
        return FALSE;
    }
    oTargetPawn = BioPawn(oImpacted);
    if (oTargetPawn == None)
    {
        return FALSE;
    }
    Manager = oTargetPawn.GetModule(Class'SFXModule_GameEffectManager');
    if (Manager == None)
    {
        return FALSE;
    }
    REAVE = SFXGameEffect_Reave(Manager.CreateEffect(Class'SFXGameEffect_Reave', Name, EffectDuration.CurrentValue, 1, Damage.CurrentValue, m_oPawn.Controller));
    if (REAVE != None)
    {
        REAVE.Instigator = m_oPawn.Controller;
        if (IsEvolvedWithChoice(4))
        {
            REAVE.DamageType = Class'SFXDamageType_Reave_Improved';
        }
        REAVE.OnApplied();
        if (Resistance != EPowerResistance.Resistance_Full)
        {
            Manager = m_oPawn.GetModule(Class'SFXModule_GameEffectManager');
            Manager.RemoveEffectsByTypeAndCategory(Class'SFXGameEffect_DamageTakenBonus', Name);
            Manager.CreateAndApplyEffect(Class'SFXGameEffect_DamageTakenBonus', Name, EffectDuration.CurrentValue, 1, -DamageReduction.CurrentValue, m_oPawn.Controller);
        }
    }
    AddComboEffect(oImpacted, Class'SFXGameEffect_PowerCombo_Biotic', EffectDuration.CurrentValue);
    SFXGRI(m_oPawn.WorldInfo.GRI).PlayTransientSound(HealSound, m_oPawn.location);
    if (!Manager.HasEffectOfType(Class'SFXGameEffect_HealthRegenPenalty') && Resistance != EPowerResistance.Resistance_Full)
    {
        ApplyTemporaryGameEffect(oTargetPawn, Class'SFXGameEffect_HealthRegenPenalty', EffectDuration.CurrentValue, 1.0, Name, m_oPawn.Controller);
    }
    CETarget.Instigator = oTargetPawn;
    CETarget.SpawnValue = GetDefaultClientEffectParams();
    if (IsMachineRace(oTargetPawn) && CE_TargetCrustTemplateRobotic != None)
    {
        Class'RvrClientEffectManager'.static.GetClientEffectManager().PlayOnTarget(CE_TargetCrustTemplateRobotic, CETarget, m_oTargetToAimAt);
    }
    else if (!IsMachineRace(oTargetPawn) && CE_TargetCrustTemplateOrganic != None)
    {
        Class'RvrClientEffectManager'.static.GetClientEffectManager().PlayOnTarget(CE_TargetCrustTemplateOrganic, CETarget, m_oTargetToAimAt);
    }
    return TRUE;
}
public function bool ShouldUsePower(Actor Target, out string sOptionalInfo)
{
    local BioPawn oPawn;
    
    oPawn = BioPawn(Target);
    if (oPawn == None)
    {
        return TRUE;
    }
    if (int(oPawn.GetCurrentResistance()) != 0)
    {
        return ShouldUsePowerOnShields(oPawn, Class'SFXDamageType_Reave', sOptionalInfo);
    }
    return TRUE;
}
public function EvolvePower(SFXPowerCustomActionBase.EEvolveChoice choice)
{
    Super(SFXPowerCustomActionBase).EvolvePower(choice);
    switch (choice)
    {
        case EEvolveChoice.EvolveChoice1:
            AddEvolvedRankBonus(EffectDuration, Evolve_DurationBonus);
            break;
        case EEvolveChoice.EvolveChoice2:
            AddEvolvedRankBonus(ImpactRadius, Evolve_Radius);
            break;
        case EEvolveChoice.EvolveChoice3:
            AddEvolvedRankBonus(DamageReduction, Evolve_DamageReductionBonus);
            break;
        case EEvolveChoice.EvolveChoice4:
            AddEvolvedRankBonus(CooldownTime, Evolve_RechargeSpeedBonus);
            AddEvolvedRankBonus(HenchmanCooldownTime, Evolve_RechargeSpeedBonus);
            break;
        case EEvolveChoice.EvolveChoice5:
            break;
        case EEvolveChoice.EvolveChoice6:
            AddEvolvedRankBonus(Damage, Evolve_DamageBonus);
            AddEvolvedRankBonus(EffectDuration, Evolve_DurationBonus2);
            AddEvolvedRankBonus(DamageReduction, Evolve_DamageReductionBonus2);
            break;
        default:
    }
    RecalculateAllPowerInfo();
}
public function float GetImpactDamage(Actor oImpacted, out Class<SFXDamageType> DamageType)
{
    return 0.0;
}
public function OnPowerDetonated(Object.Vector HitLocation, Object.Vector HitNormal, optional SFXProjectile_PowerCustomAction oProjectile, optional Actor HitActor)
{
    Super.OnPowerDetonated(HitLocation, HitNormal, oProjectile, HitActor);
    if (HitActor != None)
    {
        if (IsMachineRace(HitActor) && CE_CasterCrustTemplateRobotic != None)
        {
            Class'RvrClientEffectManager'.static.GetClientEffectManager().Play(CE_CasterCrustTemplateRobotic, m_oPawn, GetDefaultClientEffectParams());
        }
        else if (!IsMachineRace(HitActor) && CE_CasterCrustTemplateOrganic != None)
        {
            Class'RvrClientEffectManager'.static.GetClientEffectManager().Play(CE_CasterCrustTemplateOrganic, m_oPawn, GetDefaultClientEffectParams());
        }
    }
    else
    {
        Class'RvrClientEffectManager'.static.GetClientEffectManager().Play(CE_CasterCrustTemplateMiss, m_oPawn, GetDefaultClientEffectParams());
    }
}
public function PopulatePowerStatBarEvolves()
{
    PowerStatBars.Length = 4;
    PowerStatBars[0].Data = SFXPawn_Henchman(m_oPawn) == None ? CooldownTime : HenchmanCooldownTime;
    PowerStatBars[0].srDisplayTotalToken = StatBarToken_Time;
    PowerStatBars[0].srStatBarDisplayTitle = StatBarTitle_Cooldown;
    PowerStatBars[0].EvolvedBonuses[3] = Evolve_RechargeSpeedBonus;
    PowerStatBars[1].Data = Damage;
    PowerStatBars[1].srDisplayTotalToken = StatBarToken_RawValue;
    PowerStatBars[1].srStatBarDisplayTitle = StatBarTitle_DamagePerSecond;
    PowerStatBars[1].EvolvedBonuses[5] = Evolve_DamageBonus;
    PowerStatBars[2].Data = EffectDuration;
    PowerStatBars[2].srDisplayTotalToken = StatBarToken_Time;
    PowerStatBars[2].srStatBarDisplayTitle = StatBarTitle_Duration;
    PowerStatBars[2].EvolvedBonuses[0] = Evolve_DurationBonus;
    PowerStatBars[2].EvolvedBonuses[5] = Evolve_DurationBonus2;
    PowerStatBars[3].Data = DamageReduction;
    PowerStatBars[3].Formula = EPowerStatBarFormula.EPowerStatBarFormula_Percent;
    PowerStatBars[3].srDisplayTotalToken = StatBarToken_Percent;
    PowerStatBars[3].srStatBarDisplayTitle = StatBarTitle_DamageReduction;
    PowerStatBars[3].EvolvedBonuses[2] = Evolve_DamageReductionBonus;
    PowerStatBars[3].EvolvedBonuses[5] = Evolve_DamageReductionBonus2;
}
public function RecalculateAllPowerData(optional bool bReset = FALSE)
{
    Super(SFXPowerCustomActionBase).RecalculateAllPowerData(bReset);
    RecalculatePowerData(DamageReduction, bReset);
}
public function StopSounds()
{
    if (SFXPawn_Player(m_oPawn) != None && m_oPawn.IsLocallyControlled())
    {
        m_oPawn.StopSound(ConfirmStartSound);
        m_oPawn.PlaySound(ConfirmStopSound, TRUE);
    }
    else
    {
        m_oPawn.StopSound(HenchmanConfirmStartSound);
        m_oPawn.PlaySound(HenchmanConfirmStopSound, TRUE);
    }
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    Begin Object Class=BioDynamicAnimSet Name=MY_DYN_HMM_BC_RifleTelekenesis
        m_nmOrigSetName = 'HMM_BC_RifleTelekenesis'
        Sequences = (AnimSequence'BIOG_HMM_BC_A.HMM_BC_RifleTelekenesis_BC_Start', AnimSequence'BIOG_HMM_BC_A.HMM_BC_RifleTelekenesis_BC_End')
        m_pBioAnimSetData = BioAnimSetData'BIOG_HMM_BC_A.HMM_BC_RifleTelekenesis_BioAnimSetData'
    End Object
    DamageReduction = {
                       DynamicBonuses = (), 
                       RankBonuses[0] = 0.0, 
                       RankBonuses[1] = 0.0, 
                       RankBonuses[2] = 0.0, 
                       RankBonuses[3] = 0.0, 
                       RankBonuses[4] = 0.0, 
                       RankBonuses[5] = 0.0, 
                       BaseValue = 0.150000006, 
                       CurrentValue = 0.0, 
                       Formula = EPowerDataFormula.BonusIsHardValue
                      }
    HealSound = WwiseEvent'Wwise_VFX_Biotics.vfx_biotic_reave_cast'
    Evolve_DurationBonus = 0.400000006
    Evolve_Radius = 300.0
    Evolve_DamageReductionBonus = 0.100000001
    Evolve_RechargeSpeedBonus = 0.349999994
    Evolve_DamageBonus = 0.300000012
    Evolve_DurationBonus2 = 0.300000012
    Evolve_DamageReductionBonus2 = 0.150000006
    Evolve_ArmorBarrierBonus = 0.75
    CE_CasterCrustTemplateOrganic = RvrClientEffect'BioVFX_Hch_Morinth.VCFX.Reave_Charge_2_VCFX'
    CE_CasterCrustTemplateRobotic = RvrClientEffect'BioVFX_Hch_Morinth.VCFX.Reave_Charge_VCFX'
    CE_CasterCrustTemplateMiss = RvrClientEffect'BioVFX_B_Biotics_Charge.VCFX.Biotics_Charge_VCFX'
    CE_TargetCrustTemplateOrganic = RvrClientEffect'BioVFX_Hch_Morinth.VCFX.Reave_Target_Crust_VCFX'
    CE_TargetCrustTemplateRobotic = RvrClientEffect'BioVFX_B_Pull.VCFX.Pull_Lift_Crust_VCFX'
    ConfirmStartSound = WwiseEvent'Wwise_Power_Biotic_Reave.Play_power_biotic_P_reave_confirm'
    ConfirmStopSound = WwiseEvent'Wwise_Power_Biotic_Reave.Stop_power_biotic_P_reave_confirm'
    HenchmanConfirmStartSound = WwiseEvent'Wwise_Power_Biotic_Reave.Play_power_biotic_NP_reave_confirm'
    HenchmanConfirmStopSound = WwiseEvent'Wwise_Power_Biotic_Reave.Stop_power_biotic_NP_reave_confirm'
    ComboDetonators = (Class'SFXGameEffect_PowerCombo_Biotic')
    DefaultDamageType = Class'SFXDamageType_Reave'
    DetonationRumbleClass = Class'SFXRumble_Power_HeavyImpact'
    DetonationScreenShakeClass = Class'SFXShake_Power_HeavyImpact'
    ReleaseTime = 0.400000006
    CastAnimSet = MY_DYN_HMM_BC_RifleTelekenesis
    CastCameraAnim = CameraAnim'BioVFX_C_CamAnim.Powers.BC_RifleTelekinesis'
    CE_ImpactTemplate = RvrClientEffect'BioVFX_Hch_Morinth.VCFX.Reave_Impact_VCFX'
    ImpactSound = WwiseEvent'Wwise_Power_Biotic_Reave.Play_power_biotic_P_reave_impact'
    CastSound = WwiseEvent'Wwise_Power_Biotic_Reave.Play_power_biotic_P_reave_cast'
    HenchmanImpactSound = WwiseEvent'Wwise_Power_Biotic_Reave.Play_power_biotic_NP_reave_impact'
    HenchmanCastSound = WwiseEvent'Wwise_Power_Biotic_Reave.Play_power_biotic_NP_reave_cast'
    Discipline = EBioCapMode.BIO_CAPMODE_BIOTICS
    CooldownTime = {RankBonuses[1] = 0.25, BaseValue = 8.0, Formula = EPowerDataFormula.DivideByBonusSum}
    HenchmanCooldownTime = {RankBonuses[1] = 0.25, BaseValue = 16.0, Formula = EPowerDataFormula.DivideByBonusSum}
    MaximumRange = {BaseValue = 6000.0}
    ImpactRadius = {Formula = EPowerDataFormula.BonusIsHardValue}
    EffectDuration = {RankBonuses[2] = 0.349999994, BaseValue = 4.0}
    Damage = {BaseValue = 70.0}
    Force = {BaseValue = 150.0}
    Ranks = ({
              Icon = 51, 
              Name = $0, 
              Description = $0, 
              Evolved1Name = $314880, 
              Evolved1Description = $314884, 
              Evolved2Name = $0, 
              Evolved2Description = $0
             }, 
             {
              Icon = 51, 
              Name = $0, 
              Description = $0, 
              Evolved1Name = $314881, 
              Evolved1Description = $690826, 
              Evolved2Name = $0, 
              Evolved2Description = $0
             }, 
             {
              Icon = 51, 
              Name = $0, 
              Description = $0, 
              Evolved1Name = $314882, 
              Evolved1Description = $690827, 
              Evolved2Name = $0, 
              Evolved2Description = $0
             }, 
             {
              Icon = 51, 
              Name = $0, 
              Description = $0, 
              Evolved1Name = $314883, 
              Evolved1Description = $339491, 
              Evolved2Name = $339489, 
              Evolved2Description = $339490
             }, 
             {
              Icon = 51, 
              Name = $0, 
              Description = $0, 
              Evolved1Name = $690828, 
              Evolved1Description = $690829, 
              Evolved2Name = $690830, 
              Evolved2Description = $690831
             }, 
             {
              Icon = 51, 
              Name = $0, 
              Description = $0, 
              Evolved1Name = $690832, 
              Evolved1Description = $690833, 
              Evolved2Name = $690834, 
              Evolved2Description = $690835
             }
            )
    PowerName = 'REAVE'
    PowerCustomActionID = 1
    DisplayName = $314878
    Description = $314879
    Icon = 51
    TalentDescription = $314879
    IsBonusPower = TRUE
    bDisableLeftHandIK = FALSE
    VocalizationEvent = ESFXVocalizationEventID.SFXVocalizationEvent_Power_Reave
}