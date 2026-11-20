// Source: ME3, Patch_PwrCustActnMPMaleQuarPassive
// Decompiled 11/17/2026 7:38:21 AM against QuarianMale_Engineer_MP.pcc
Class SFXPowerCustomActionMP_MaleQuarianPassive extends SFXPowerCustomActionMP_PassiveBase
    config(Game);

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    PowerDamageBonus = {RankBonuses[2] = 0.100000001, BaseValue = 0.100000001, Formula = EPowerDataFormula.BonusIsHardValue}
    WeaponDamageBonus = {RankBonuses[1] = 0.0250000004, BaseValue = 0.0250000004, Formula = EPowerDataFormula.BonusIsHardValue}
    WeightCapacityBonus = {BaseValue = 0.100000001, Formula = EPowerDataFormula.BonusIsHardValue}
    WeaponWeightClasses = (ELoadoutWeapons.LoadoutWeapons_AssaultRifles, ELoadoutWeapons.LoadoutWeapons_Shotguns, ELoadoutWeapons.LoadoutWeapons_SniperRifles, ELoadoutWeapons.LoadoutWeapons_AutoPistols, ELoadoutWeapons.LoadoutWeapons_HeavyPistols)
    Evolve_WeaponDamageBonus1 = 0.075000003
    Evolve_PowerDamageBonus1 = 0.100000001
    Evolve_WeightCapacityBonus = 0.200000003
    Evolve_PowerDamageBonus2 = 0.150000006
    Evolve_HeadShotBonus = 0.200000003
    Evolve_WeaponEncumbranceBonus = 0.200000003
    Evolve_WeaponDamageBonus2 = 0.100000001
    Ranks = ({
              Icon = 67, 
              Name = $0, 
              Description = $0, 
              Evolved1Name = $677313, 
              Evolved1Description = $677314, 
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
              Evolved1Name = $718077, 
              Evolved1Description = $718078, 
              Evolved2Name = $677196, 
              Evolved2Description = $677197
             }
            )
    DisplayName = $677313
    Description = $703880
    TalentDescription = $703880
}