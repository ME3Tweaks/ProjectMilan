// Source: ME3, Patch_SFXPwrCustActnMPAsaCmmndoPsiv
// Decompiled 11/17/2026 7:38:09 AM against AsariCommando_Adept_MP.pcc
Class SFXPowerCustomActionMP_AsariCommandoPassive extends SFXPowerCustomActionMP_PassiveBase
    config(Game);

var config SFXPowerCustomActionBase.PowerData PowerDurationBonus;
var config float Evolve_PowerDurationBonus;

public function ApplyGlobalBonus()
{
    local SFXGameEffect_PowerBonus PowerBonusEffect;
    local SFXModule_GameEffectManager GEManager;
    
    Super.ApplyGlobalBonus();
    if (Rank < float(1))
    {
        return;
    }
    GEManager = m_oPawn.GetModule(Class'SFXModule_GameEffectManager');
    if (GEManager == None)
    {
        return;
    }
    if (PowerDurationBonus.CurrentValue > float(0))
    {
        PowerBonusEffect = SFXGameEffect_PowerBonus(GEManager.CreateEffect(Class'SFXGameEffect_PowerBonus', Name, 0.0, 2, PowerDurationBonus.CurrentValue, m_oPawn.Controller));
        if (PowerBonusEffect != None)
        {
            PowerBonusEffect.AffectedParameter = 'EffectDuration';
            PowerBonusEffect.bApplyToBiotics = TRUE;
            PowerBonusEffect.bApplyToTech = TRUE;
            PowerBonusEffect.bApplyToCombat = TRUE;
            PowerBonusEffect.bApplyToWeapons = FALSE;
            PowerBonusEffect.OnApplied();
        }
    }
}
public function EvolvePower(SFXPowerCustomActionBase.EEvolveChoice choice)
{
    Super.EvolvePower(choice);
    switch (choice)
    {
        case EEvolveChoice.EvolveChoice1:
            break;
        case EEvolveChoice.EvolveChoice2:
            AddEvolvedRankBonus(PowerDurationBonus, Evolve_PowerDurationBonus);
            break;
        case EEvolveChoice.EvolveChoice3:
            break;
        case EEvolveChoice.EvolveChoice4:
            break;
        case EEvolveChoice.EvolveChoice5:
            break;
        case EEvolveChoice.EvolveChoice6:
            break;
        default:
    }
    RecalculateAllPowerInfo();
    ApplyGlobalBonus();
}
public function PopulatePowerStatBarEvolves()
{
    PowerStatBars.Length = 3;
    PowerStatBars[0].Data = WeaponDamageBonus;
    PowerStatBars[0].Formula = EPowerStatBarFormula.EPowerStatBarFormula_Percent;
    PowerStatBars[0].srDisplayTotalToken = StatBarToken_Percent;
    PowerStatBars[0].srStatBarDisplayTitle = StatBarTitle_WeaponDamage;
    PowerStatBars[0].EvolvedBonuses[0] = Evolve_WeaponDamageBonus1;
    PowerStatBars[0].EvolvedBonuses[5] = Evolve_WeaponDamageBonus2;
    PowerStatBars[1].Data = PowerDurationBonus;
    PowerStatBars[1].Formula = EPowerStatBarFormula.EPowerStatBarFormula_Percent;
    PowerStatBars[1].srDisplayTotalToken = StatBarToken_Percent;
    PowerStatBars[1].srStatBarDisplayTitle = StatBarTitle_Duration;
    PowerStatBars[1].EvolvedBonuses[1] = Evolve_PowerDurationBonus;
    PowerStatBars[2].Data = WeightCapacityBonus;
    PowerStatBars[2].Formula = EPowerStatBarFormula.EPowerStatBarFormula_Percent;
    PowerStatBars[2].srDisplayTotalToken = StatBarToken_RawValue;
    PowerStatBars[2].srStatBarDisplayTitle = StatBarTitle_WeightCapacity;
    PowerStatBars[2].EvolvedBonuses[1] = Evolve_WeightCapacityBonus;
}
public function RecalculateAllPowerData(optional bool bReset = FALSE)
{
    Super.RecalculateAllPowerData(bReset);
    RecalculatePowerData(PowerDurationBonus, bReset);
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    PowerDamageBonus = {Formula = EPowerDataFormula.BonusIsHardValue}
    WeaponDamageBonus = {RankBonuses[1] = 0.0500000007, BaseValue = 0.0500000007, Formula = EPowerDataFormula.BonusIsHardValue}
    WeightCapacityBonus = {BaseValue = 0.100000001, Formula = EPowerDataFormula.BonusIsHardValue}
    WeaponWeightClasses = (ELoadoutWeapons.LoadoutWeapons_AssaultRifles)
    Evolve_WeaponDamageBonus1 = 0.075000003
    Evolve_WeightCapacityBonus = 0.200000003
    Evolve_PowerDamageBonus2 = 0.150000006
    Evolve_HeadShotBonus = 0.200000003
    Evolve_WeaponEncumbranceBonus = 0.300000012
    Evolve_WeaponDamageBonus2 = 0.100000001
    Ranks = ({
              Icon = 67, 
              Name = $0, 
              Description = $0, 
              Evolved1Name = $677305, 
              Evolved1Description = $727958, 
              Evolved2Name = $0, 
              Evolved2Description = $0
             }, 
             {
              Icon = 67, 
              Name = $0, 
              Description = $0, 
              Evolved1Name = $677160, 
              Evolved1Description = $677161, 
              Evolved2Name = $0, 
              Evolved2Description = $0
             }, 
             {
              Icon = 67, 
              Name = $0, 
              Description = $0, 
              Evolved1Name = $502698, 
              Evolved1Description = $727959, 
              Evolved2Name = $0, 
              Evolved2Description = $0
             }, 
             {
              Icon = 67, 
              Name = $0, 
              Description = $0, 
              Evolved1Name = $677162, 
              Evolved1Description = $677163, 
              Evolved2Name = $727961, 
              Evolved2Description = $727960
             }, 
             {
              Icon = 67, 
              Name = $0, 
              Description = $0, 
              Evolved1Name = $677167, 
              Evolved1Description = $677166, 
              Evolved2Name = $677172, 
              Evolved2Description = $677178
             }, 
             {
              Icon = 67, 
              Name = $0, 
              Description = $0, 
              Evolved1Name = $677192, 
              Evolved1Description = $677195, 
              Evolved2Name = $677196, 
              Evolved2Description = $677197
             }
            )
    DisplayName = $677305
    Description = $727958
    TalentDescription = $727958
}