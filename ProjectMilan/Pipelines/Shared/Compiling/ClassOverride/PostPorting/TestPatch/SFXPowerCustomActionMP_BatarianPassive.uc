// Source: ME3, Patch_SFXPwrCustActnMP_BataPassive
// Decompiled 11/17/2026 7:38:11 AM against Batarian_Sentinel_MP.pcc
Class SFXPowerCustomActionMP_BatarianPassive extends SFXPowerCustomActionMP_PassiveBase
    config(Game);

var config SFXPowerCustomActionBase.PowerData WeaponSpareAmmoBonus;
var config float Evolve_WeaponSpareAmmo1;
var config float Evolve_WeaponSpareAmmo2;

public function ApplyGlobalBonus()
{
    Super.ApplyGlobalBonus();
    if (Rank < float(1))
    {
        return;
    }
    if (WeaponSpareAmmoBonus.CurrentValue > float(0))
    {
        ApplyPermanentGameEffect(m_oPawn, Class'SFXGameEffect_PassiveMaxAmmoBonus', WeaponSpareAmmoBonus.CurrentValue, Name, m_oPawn.Controller);
    }
}
public function EvolvePower(SFXPowerCustomActionBase.EEvolveChoice choice)
{
    Super.EvolvePower(choice);
    switch (choice)
    {
        case EEvolveChoice.EvolveChoice1:
            AddEvolvedRankBonus(WeaponSpareAmmoBonus, Evolve_WeaponSpareAmmo1);
            break;
        case EEvolveChoice.EvolveChoice2:
            break;
        case EEvolveChoice.EvolveChoice3:
            break;
        case EEvolveChoice.EvolveChoice4:
            break;
        case EEvolveChoice.EvolveChoice5:
            break;
        case EEvolveChoice.EvolveChoice6:
            AddEvolvedRankBonus(WeaponSpareAmmoBonus, Evolve_WeaponSpareAmmo2);
            break;
        default:
    }
    RecalculateAllPowerInfo();
    ApplyGlobalBonus();
}
public function PopulatePowerStatBarEvolves()
{
    PowerStatBars.Length = 4;
    PowerStatBars[0].Data = WeaponDamageBonus;
    PowerStatBars[0].Formula = EPowerStatBarFormula.EPowerStatBarFormula_Percent;
    PowerStatBars[0].srDisplayTotalToken = StatBarToken_Percent;
    PowerStatBars[0].srStatBarDisplayTitle = StatBarTitle_WeaponDamage;
    PowerStatBars[0].EvolvedBonuses[0] = Evolve_WeaponDamageBonus1;
    PowerStatBars[0].EvolvedBonuses[5] = Evolve_WeaponDamageBonus2;
    PowerStatBars[1].Data = PowerDamageBonus;
    PowerStatBars[1].Formula = EPowerStatBarFormula.EPowerStatBarFormula_Percent;
    PowerStatBars[1].srDisplayTotalToken = StatBarToken_Percent;
    PowerStatBars[1].srStatBarDisplayTitle = StatBarTitle_PowerDamage;
    PowerStatBars[1].EvolvedBonuses[1] = Evolve_PowerDamageBonus1;
    PowerStatBars[1].EvolvedBonuses[2] = Evolve_PowerDamageBonus2;
    PowerStatBars[2].Data = WeaponSpareAmmoBonus;
    PowerStatBars[2].Formula = EPowerStatBarFormula.EPowerStatBarFormula_Percent;
    PowerStatBars[2].srDisplayTotalToken = StatBarToken_Percent;
    PowerStatBars[2].srStatBarDisplayTitle = $727962;
    PowerStatBars[2].EvolvedBonuses[0] = Evolve_WeaponSpareAmmo1;
    PowerStatBars[2].EvolvedBonuses[5] = Evolve_WeaponSpareAmmo2;
    PowerStatBars[3].Data = WeightCapacityBonus;
    PowerStatBars[3].Formula = EPowerStatBarFormula.EPowerStatBarFormula_Percent;
    PowerStatBars[3].srDisplayTotalToken = StatBarToken_RawValue;
    PowerStatBars[3].srStatBarDisplayTitle = StatBarTitle_WeightCapacity;
    PowerStatBars[3].EvolvedBonuses[1] = Evolve_WeightCapacityBonus;
}
public function RecalculateAllPowerData(optional bool bReset = FALSE)
{
    Super.RecalculateAllPowerData(bReset);
    RecalculatePowerData(WeaponSpareAmmoBonus, bReset);
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    WeaponSpareAmmoBonus = {
                            DynamicBonuses = (), 
                            RankBonuses[0] = 0.0, 
                            RankBonuses[1] = 0.0, 
                            RankBonuses[2] = 0.0, 
                            RankBonuses[3] = 0.0, 
                            RankBonuses[4] = 0.0, 
                            RankBonuses[5] = 0.0, 
                            BaseValue = 0.100000001, 
                            CurrentValue = 0.0, 
                            Formula = EPowerDataFormula.BonusIsHardValue
                           }
    PowerDamageBonus = {RankBonuses[1] = 0.0500000007, BaseValue = 0.0250000004, Formula = EPowerDataFormula.BonusIsHardValue}
    WeaponDamageBonus = {RankBonuses[2] = 0.0500000007, BaseValue = 0.0250000004, Formula = EPowerDataFormula.BonusIsHardValue}
    WeightCapacityBonus = {BaseValue = 0.150000006, Formula = EPowerDataFormula.BonusIsHardValue}
    WeaponWeightClasses = (ELoadoutWeapons.LoadoutWeapons_Shotguns, ELoadoutWeapons.LoadoutWeapons_SniperRifles)
    Evolve_WeaponDamageBonus1 = 0.075000003
    Evolve_PowerDamageBonus1 = 0.100000001
    Evolve_WeightCapacityBonus = 0.25
    Evolve_PowerDamageBonus2 = 0.150000006
    Evolve_HeadShotBonus = 0.200000003
    Evolve_WeaponEncumbranceBonus = 0.25
    Evolve_WeaponDamageBonus2 = 0.100000001
    Ranks = ({
              Icon = 67, 
              Name = $0, 
              Description = $0, 
              Evolved1Name = $727832, 
              Evolved1Description = $727833, 
              Evolved2Name = $0, 
              Evolved2Description = $0
             }, 
             {
              Icon = 67, 
              Name = $0, 
              Description = $0, 
              Evolved1Name = $727834, 
              Evolved1Description = $727835, 
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
              Evolved1Name = $727836, 
              Evolved1Description = $727837, 
              Evolved2Name = $677164, 
              Evolved2Description = $677165
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
              Evolved1Name = $727838, 
              Evolved1Description = $727839, 
              Evolved2Name = $727840, 
              Evolved2Description = $727841
             }
            )
    DisplayName = $727832
    Description = $727833
    TalentDescription = $727833
}