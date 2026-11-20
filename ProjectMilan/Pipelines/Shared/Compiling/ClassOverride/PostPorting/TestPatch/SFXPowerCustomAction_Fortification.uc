// Source: ME3, Patch_SFXPwrCustActnFortification
// Decompiled 11/17/2026 7:38:36 AM against BioD_ProEar_200.pcc
Class SFXPowerCustomAction_Fortification extends SFXPowerCustomAction_DefensiveShield
    config(Game);

var config SFXPowerCustomActionBase.PowerData MeleeDamageBonus;
var config SFXPowerCustomActionBase.PowerData MeleeDamageBonusDuration;
var config float Evolve_DamageReductionBonus1;
var config float Evolve_DamageReductionBonus2;
var config float Evolve_MeleeDamageBonus;
var config float Evolve_ShieldRegenBonus;
var config float Evolve_PowerDamageBonus;
var config float Evolve_EncumbranceBonus;

public function EvolvePower(SFXPowerCustomActionBase.EEvolveChoice choice)
{
    Super(SFXPowerCustomActionBase).EvolvePower(choice);
    switch (choice)
    {
        case EEvolveChoice.EvolveChoice1:
            AddEvolvedRankBonus(DamageReduction, Evolve_DamageReductionBonus1);
            break;
        case EEvolveChoice.EvolveChoice2:
            AddEvolvedRankBonus(MeleeDamageBonus, Evolve_MeleeDamageBonus);
            break;
        case EEvolveChoice.EvolveChoice3:
            break;
        case EEvolveChoice.EvolveChoice4:
            break;
        case EEvolveChoice.EvolveChoice5:
            AddEvolvedRankBonus(EncumbrancePenalty, -Evolve_EncumbranceBonus);
            break;
        case EEvolveChoice.EvolveChoice6:
            AddEvolvedRankBonus(DamageReduction, Evolve_DamageReductionBonus2);
            break;
        default:
    }
    RecalculateAllPowerInfo();
}
public function PopulatePowerStatBarEvolves()
{
    PowerStatBars.Length = 4;
    PowerStatBars[0].Data = SFXPawn_Henchman(m_oPawn) == None ? CooldownTime : HenchmanCooldownTime;
    PowerStatBars[0].srDisplayTotalToken = StatBarToken_Time;
    PowerStatBars[0].srStatBarDisplayTitle = StatBarTitle_Cooldown;
    PowerStatBars[1].Data = DamageReduction;
    PowerStatBars[1].Formula = EPowerStatBarFormula.EPowerStatBarFormula_Percent;
    PowerStatBars[1].srDisplayTotalToken = StatBarToken_Percent;
    PowerStatBars[1].srStatBarDisplayTitle = StatBarTitle_DamageReduction;
    PowerStatBars[1].EvolvedBonuses[0] = Evolve_DamageReductionBonus1;
    PowerStatBars[1].EvolvedBonuses[5] = Evolve_DamageReductionBonus2;
    PowerStatBars[2].Data = MeleeDamageBonus;
    PowerStatBars[2].Formula = EPowerStatBarFormula.EPowerStatBarFormula_Percent;
    PowerStatBars[2].srDisplayTotalToken = StatBarToken_Percent;
    PowerStatBars[2].srStatBarDisplayTitle = $694502;
    PowerStatBars[2].EvolvedBonuses[1] = Evolve_MeleeDamageBonus;
    PowerStatBars[3].Data = MeleeDamageBonusDuration;
    PowerStatBars[3].srDisplayTotalToken = StatBarToken_Time;
    PowerStatBars[3].srStatBarDisplayTitle = $724431;
}
public function RecalculateAllPowerData(optional bool bReset = FALSE)
{
    Super.RecalculateAllPowerData(bReset);
    RecalculatePowerData(MeleeDamageBonus, bReset);
    RecalculatePowerData(MeleeDamageBonusDuration, bReset);
}
public function StartPowerCooldown();

public function RemoveArmor()
{
    local BioCheatManager CheatManager;
    
    Super.RemoveArmor();
    if (MeleeDamageBonus.CurrentValue > float(0))
    {
        ApplyTemporaryGameEffect(m_oPawn, Class'SFXGameEffect_MeleeDamageBonus', MeleeDamageBonusDuration.CurrentValue, MeleeDamageBonus.CurrentValue, Name, m_oPawn.Controller);
    }
    if (bRemoveArmorApplyCooldown)
    {
        CheatManager = m_oPawn.PowerManager.GetCheatManager();
        if (CheatManager != None && CheatManager.m_bEnablePowerCooldown == FALSE)
        {
            return;
        }
        m_oPawn.PowerManager.SetSharedCooldown(GetPowerCooldown());
    }
}
public function ApplyArmor()
{
    local SFXModule_GameEffectManager Manager;
    
    Super.ApplyArmor();
    Manager = m_oPawn.GetModule(Class'SFXModule_GameEffectManager');
    if (Manager == None)
    {
        return;
    }
    if (IsEvolvedWithChoice(2))
    {
        ApplyPermanentGameEffect(m_oPawn, Class'SFXGameEffect_ShieldRegenBonus', -Evolve_ShieldRegenBonus, Name, m_oPawn.Controller);
    }
    if (IsEvolvedWithChoice(3))
    {
        m_oPawn.PowerManager.ApplyPowerBonus(m_oPawn, 'Damage', Evolve_PowerDamageBonus, 0.0, Name, Self);
        m_oPawn.PowerManager.ApplyPowerBonus(m_oPawn, 'Force', Evolve_PowerDamageBonus, 0.0, Name, Self);
    }
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    MeleeDamageBonus = {
                        DynamicBonuses = (), 
                        RankBonuses[0] = 0.0, 
                        RankBonuses[1] = 0.0, 
                        RankBonuses[2] = 0.200000003, 
                        RankBonuses[3] = 0.0, 
                        RankBonuses[4] = 0.0, 
                        RankBonuses[5] = 0.0, 
                        BaseValue = 0.5, 
                        CurrentValue = 0.0, 
                        Formula = EPowerDataFormula.BonusIsHardValue
                       }
    MeleeDamageBonusDuration = {
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
    Evolve_DamageReductionBonus1 = 0.0500000007
    Evolve_DamageReductionBonus2 = 0.100000001
    Evolve_MeleeDamageBonus = 0.300000012
    Evolve_ShieldRegenBonus = 0.150000006
    Evolve_PowerDamageBonus = 0.200000003
    Evolve_EncumbranceBonus = 0.300000012
    DamageReduction = {BaseValue = 0.150000006, Formula = EPowerDataFormula.BonusIsHardValue}
    EncumbrancePenalty = {BaseValue = 0.600000024, Formula = EPowerDataFormula.BonusIsHardValue}
    CE_ArmorCrustTemplate = RvrClientEffect'BioVFX_C_Powers.01_Fortification.Fortification_Crust_VCFX'
    EvolvedCastSounds = ({Sound = WwiseEvent'Wwise_Power_Soldier_Fortif.Play_power_soldier_P_fortif_evolcast', bAnyEvolved = TRUE, bReplaceBaseSound = TRUE, EvolveChoice = EEvolveChoice.EvolveChoice1}
                        )
    HenchmanEvolvedCastSounds = ({Sound = WwiseEvent'Wwise_Power_Soldier_Fortif.Play_power_soldier_NP_fortif_evolcast', bAnyEvolved = TRUE, bReplaceBaseSound = TRUE, EvolveChoice = EEvolveChoice.EvolveChoice1}
                                )
    CastSound = WwiseEvent'Wwise_Power_Soldier_Fortif.Play_power_soldier_P_fortif_cast'
    HenchmanCastSound = WwiseEvent'Wwise_Power_Soldier_Fortif.Play_power_soldier_NP_fortif_cast'
    Discipline = EBioCapMode.BIO_CAPMODE_COMBAT
    CooldownTime = {RankBonuses[1] = 0.25, BaseValue = 5.0, Formula = EPowerDataFormula.DivideByBonusSum}
    HenchmanCooldownTime = {RankBonuses[1] = 0.25, BaseValue = 10.0, Formula = EPowerDataFormula.DivideByBonusSum}
    Ranks = ({
              Icon = 66, 
              Name = $0, 
              Description = $0, 
              Evolved1Name = $314036, 
              Evolved1Description = $694498, 
              Evolved2Name = $0, 
              Evolved2Description = $0
             }, 
             {
              Icon = 66, 
              Name = $0, 
              Description = $0, 
              Evolved1Name = $314039, 
              Evolved1Description = $545564, 
              Evolved2Name = $0, 
              Evolved2Description = $0
             }, 
             {
              Icon = 66, 
              Name = $0, 
              Description = $0, 
              Evolved1Name = $314040, 
              Evolved1Description = $694499, 
              Evolved2Name = $0, 
              Evolved2Description = $0
             }, 
             {
              Icon = 66, 
              Name = $0, 
              Description = $0, 
              Evolved1Name = $338776, 
              Evolved1Description = $545547, 
              Evolved2Name = $545542, 
              Evolved2Description = $545555
             }, 
             {
              Icon = 66, 
              Name = $0, 
              Description = $0, 
              Evolved1Name = $545543, 
              Evolved1Description = $545556, 
              Evolved2Name = $545544, 
              Evolved2Description = $545557
             }, 
             {
              Icon = 66, 
              Name = $0, 
              Description = $0, 
              Evolved1Name = $545545, 
              Evolved1Description = $545558, 
              Evolved2Name = $545546, 
              Evolved2Description = $545559
             }
            )
    PowerName = 'Fortification'
    PowerCustomActionID = 16
    DisplayName = $314036
    Description = $314037
    Icon = 66
    TalentDescription = $314037
    IsBonusPower = TRUE
    VocalizationEvent = ESFXVocalizationEventID.SFXVocalizationEvent_Power_Buff
}