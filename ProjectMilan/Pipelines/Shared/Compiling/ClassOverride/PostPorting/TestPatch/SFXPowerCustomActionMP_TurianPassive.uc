// Source: ME3, Patch_PwrCustActnMP_TurianPassive
// Decompiled 11/17/2026 7:38:29 AM against N7Turian_Infiltrator_MP.pcc
Class SFXPowerCustomActionMP_TurianPassive extends SFXPowerCustomActionMP_PassiveBase
    config(Game);

var config SFXPowerCustomActionBase.PowerData WeaponStability;
var config float Evolve_WeaponStabilityBonus1;
var config float Evolve_WeaponStabilityBonus2;

public function ApplyGlobalBonus()
{
    local SFXWeapon Weapon;
    local SFXModule_GameEffectManager Manager;
    
    Super.ApplyGlobalBonus();
    if (Rank < float(1))
    {
        return;
    }
    if (WeaponStability.CurrentValue > float(0))
    {
        foreach m_oPawn.InvManager.InventoryActors(Class'SFXWeapon', Weapon)
        {
            if (SFXHeavyWeapon(Weapon) != None)
            {
                continue;
            }
            Manager = Weapon.GetModule(Class'SFXModule_GameEffectManager');
            if (Manager != None)
            {
                Manager.RemoveEffectsByCategory(Name);
            }
            ApplyPermanentGameEffect(Weapon, Class'SFXGameEffect_WeaponStabilityBonus', -WeaponStability.CurrentValue, Name, m_oPawn.Controller);
        }
    }
}
public function EvolvePower(SFXPowerCustomActionBase.EEvolveChoice choice)
{
    Super.EvolvePower(choice);
    switch (choice)
    {
        case EEvolveChoice.EvolveChoice1:
            AddEvolvedRankBonus(WeaponStability, Evolve_WeaponStabilityBonus1);
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
            AddEvolvedRankBonus(WeaponStability, Evolve_WeaponStabilityBonus2);
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
    PowerStatBars[1].Data = WeaponStability;
    PowerStatBars[1].Formula = EPowerStatBarFormula.EPowerStatBarFormula_Percent;
    PowerStatBars[1].srDisplayTotalToken = StatBarToken_Percent;
    PowerStatBars[1].srStatBarDisplayTitle = $702153;
    PowerStatBars[1].EvolvedBonuses[0] = Evolve_WeaponStabilityBonus1;
    PowerStatBars[1].EvolvedBonuses[5] = Evolve_WeaponStabilityBonus2;
    PowerStatBars[2].Data = WeightCapacityBonus;
    PowerStatBars[2].Formula = EPowerStatBarFormula.EPowerStatBarFormula_Percent;
    PowerStatBars[2].srDisplayTotalToken = StatBarToken_RawValue;
    PowerStatBars[2].srStatBarDisplayTitle = StatBarTitle_WeightCapacity;
    PowerStatBars[2].EvolvedBonuses[1] = Evolve_WeightCapacityBonus;
}
public function RecalculateAllPowerData(optional bool bReset = FALSE)
{
    Super.RecalculateAllPowerData(bReset);
    RecalculatePowerData(WeaponStability, bReset);
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    WeaponStability = {
                       DynamicBonuses = (), 
                       RankBonuses[0] = 0.0, 
                       RankBonuses[1] = 0.150000006, 
                       RankBonuses[2] = 0.0, 
                       RankBonuses[3] = 0.0, 
                       RankBonuses[4] = 0.0, 
                       RankBonuses[5] = 0.0, 
                       BaseValue = 0.200000003, 
                       CurrentValue = 0.0, 
                       Formula = EPowerDataFormula.BonusIsHardValue
                      }
    Evolve_WeaponStabilityBonus1 = 0.100000001
    Evolve_WeaponStabilityBonus2 = 0.100000001
    PowerDamageBonus = {Formula = EPowerDataFormula.BonusIsHardValue}
    WeaponDamageBonus = {RankBonuses[2] = 0.0500000007, BaseValue = 0.075000003, Formula = EPowerDataFormula.BonusIsHardValue}
    WeightCapacityBonus = {BaseValue = 0.150000006, Formula = EPowerDataFormula.BonusIsHardValue}
    WeaponWeightClasses = (ELoadoutWeapons.LoadoutWeapons_AssaultRifles)
    Evolve_WeaponDamageBonus1 = 0.075000003
    Evolve_PowerDamageBonus1 = 0.100000001
    Evolve_WeightCapacityBonus = 0.25
    Evolve_PowerDamageBonus2 = 0.150000006
    Evolve_HeadShotBonus = 0.200000003
    Evolve_WeaponEncumbranceBonus = 0.300000012
    Evolve_WeaponDamageBonus2 = 0.100000001
    Ranks = ({
              Icon = 67, 
              Name = $0, 
              Description = $0, 
              Evolved1Name = $677321, 
              Evolved1Description = $677322, 
              Evolved2Name = $0, 
              Evolved2Description = $0
             }, 
             {
              Icon = 67, 
              Name = $0, 
              Description = $0, 
              Evolved1Name = $702149, 
              Evolved1Description = $702150, 
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
              Evolved1Name = $717047, 
              Evolved1Description = $702152, 
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
              Evolved1Name = $677192, 
              Evolved1Description = $677195, 
              Evolved2Name = $717047, 
              Evolved2Description = $702151
             }
            )
    DisplayName = $677321
    Description = $703882
    TalentDescription = $703882
}