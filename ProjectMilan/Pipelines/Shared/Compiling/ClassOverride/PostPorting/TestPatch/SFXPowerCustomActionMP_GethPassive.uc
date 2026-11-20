// Source: ME3, Patch_SFXPwrCustActnMP_GethPassive
// Decompiled 11/17/2026 7:38:17 AM against Geth_Engineer_MP.pcc
Class SFXPowerCustomActionMP_GethPassive extends SFXPowerCustomActionMP_PassiveBase
    config(Game);

var config SFXPowerCustomActionBase.PowerData GethWeaponDamage;
var config array<string> RegisteredGethWeapons;
var config float Evolve_GethWeaponDamage;

public function ApplyGlobalBonus()
{
    local SFXWeapon Weapon;
    local SFXModule_GameEffectManager Manager;
    
    Super.ApplyGlobalBonus();
    if (Rank < float(1))
    {
        return;
    }
    if (GethWeaponDamage.CurrentValue > float(0))
    {
        foreach m_oPawn.InvManager.InventoryActors(Class'SFXWeapon', Weapon)
        {
            if (RegisteredGethWeapons.Find(PathName(Weapon.@Class)) == -1)
            {
                continue;
            }
            if (SFXHeavyWeapon(Weapon) == None)
            {
                Manager = Weapon.GetModule(Class'SFXModule_GameEffectManager');
                if (Manager != None)
                {
                    Manager.RemoveEffectsByCategory(Name);
                }
                ApplyPermanentGameEffect(Weapon, Class'SFXWeaponGameEffect_DamageBonus', GethWeaponDamage.CurrentValue, Name, m_oPawn.Controller);
            }
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
            break;
        case EEvolveChoice.EvolveChoice3:
            break;
        case EEvolveChoice.EvolveChoice4:
            break;
        case EEvolveChoice.EvolveChoice5:
            break;
        case EEvolveChoice.EvolveChoice6:
            AddEvolvedRankBonus(GethWeaponDamage, Evolve_GethWeaponDamage);
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
    PowerStatBars[1].Data = GethWeaponDamage;
    PowerStatBars[1].Formula = EPowerStatBarFormula.EPowerStatBarFormula_Percent;
    PowerStatBars[1].srDisplayTotalToken = StatBarToken_Percent;
    PowerStatBars[1].srStatBarDisplayTitle = $727544;
    PowerStatBars[1].EvolvedBonuses[5] = Evolve_GethWeaponDamage;
    PowerStatBars[2].Data = PowerDamageBonus;
    PowerStatBars[2].Formula = EPowerStatBarFormula.EPowerStatBarFormula_Percent;
    PowerStatBars[2].srDisplayTotalToken = StatBarToken_Percent;
    PowerStatBars[2].srStatBarDisplayTitle = StatBarTitle_PowerDamage;
    PowerStatBars[2].EvolvedBonuses[1] = Evolve_PowerDamageBonus1;
    PowerStatBars[2].EvolvedBonuses[2] = Evolve_PowerDamageBonus2;
    PowerStatBars[3].Data = WeightCapacityBonus;
    PowerStatBars[3].Formula = EPowerStatBarFormula.EPowerStatBarFormula_Percent;
    PowerStatBars[3].srDisplayTotalToken = StatBarToken_RawValue;
    PowerStatBars[3].srStatBarDisplayTitle = StatBarTitle_WeightCapacity;
    PowerStatBars[3].EvolvedBonuses[1] = Evolve_WeightCapacityBonus;
}
public function RecalculateAllPowerData(optional bool bReset = FALSE)
{
    Super.RecalculateAllPowerData(bReset);
    RecalculatePowerData(GethWeaponDamage, bReset);
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    PowerDamageBonus = {RankBonuses[2] = 0.100000001, BaseValue = 0.0500000007, Formula = EPowerDataFormula.BonusIsHardValue}
    WeaponDamageBonus = {RankBonuses[1] = 0.0250000004, BaseValue = 0.0250000004, Formula = EPowerDataFormula.BonusIsHardValue}
    WeightCapacityBonus = {BaseValue = 0.100000001, Formula = EPowerDataFormula.BonusIsHardValue}
    WeaponWeightClasses = (ELoadoutWeapons.LoadoutWeapons_AssaultRifles, ELoadoutWeapons.LoadoutWeapons_SniperRifles)
    Evolve_WeaponDamageBonus1 = 0.075000003
    Evolve_PowerDamageBonus1 = 0.100000001
    Evolve_WeightCapacityBonus = 0.200000003
    Evolve_PowerDamageBonus2 = 0.150000006
    Evolve_HeadShotBonus = 0.200000003
    Evolve_WeaponEncumbranceBonus = 0.25
    Evolve_WeaponDamageBonus2 = 0.100000001
    Ranks = ({
              Icon = 67, 
              Name = $0, 
              Description = $0, 
              Evolved1Name = $727537, 
              Evolved1Description = $727538, 
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
              Evolved1Name = $677158, 
              Evolved1Description = $677159, 
              Evolved2Name = $0, 
              Evolved2Description = $0
             }, 
             {
              Icon = 67, 
              Name = $0, 
              Description = $0, 
              Evolved1Name = $677162, 
              Evolved1Description = $677163, 
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
              Evolved1Name = $727545, 
              Evolved1Description = $727546, 
              Evolved2Name = $677196, 
              Evolved2Description = $727547
             }
            )
    DisplayName = $727537
    Description = $727538
    TalentDescription = $727538
}