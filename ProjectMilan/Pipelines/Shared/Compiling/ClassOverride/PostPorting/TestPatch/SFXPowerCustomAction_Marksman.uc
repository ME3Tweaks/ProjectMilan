// Source: ME3, Patch_SFXPowerCustomAction_Marksman
// Decompiled 11/17/2026 7:38:38 AM against BioH_Ashley_00.pcc
Class SFXPowerCustomAction_Marksman extends SFXPowerCustomAction
    config(Game);

var config SFXPowerCustomActionBase.PowerData RateOfFireIncrease;
var config SFXPowerCustomActionBase.PowerData HeadShotDamageIncrease;
var config SFXPowerCustomActionBase.PowerData AccuracyIncrease;
var config SFXPowerCustomActionBase.PowerData SquadBonusEffectiveness;
var config float Evolve_AccuracyBonus;
var config float Evolve_RateOfFireBonus;
var config float Evolve_DurationBonus;
var config float Evolve_HeadShotDamageBonus;
var config float Evolve_CooldownBonus;
var config float Evolve_AccuracyAndRoFBonus;
var WwiseEvent MarksmanSound;
var bool bEffectEnded;

public function bool CanUsePower(Actor Target)
{
    local SFXEngine Engine;
    
    if (SFXPawn_Henchman(m_oPawn) != None && !m_bPlayerOrderedPowerUse)
    {
        Engine = Class'SFXEngine'.static.GetSFXEngine();
        if (Engine != None && !Engine.GetProfileSettings().GetSquadPowerConfigOption())
        {
            return FALSE;
        }
    }
    return Super.CanUsePower(Target);
}
public function bool OnImpact(Actor.EPowerResistance Resistance, Actor oImpacted, int nPreviouslyImpacted, Object.Vector HitLocation, Object.Vector HitNormal)
{
    local BioPawn CurrentPawn;
    local SFXWeapon Weapon;
    local SFXHeavyWeapon HeavyWeapon;
    local SFXModule_GameEffectManager GEManager;
    local float EffectivenessModifier;
    
    m_oPawn.PlaySound(MarksmanSound);
    CurrentPawn = BioPawn(oImpacted);
    if (CurrentPawn == None)
    {
        return FALSE;
    }
    if (CurrentPawn.InvManager == None)
    {
        return FALSE;
    }
    if (m_oPawn == oImpacted)
    {
        EffectivenessModifier = 1.0;
    }
    else
    {
        EffectivenessModifier = SquadBonusEffectiveness.CurrentValue;
    }
    foreach CurrentPawn.InvManager.InventoryActors(Class'SFXWeapon', Weapon)
    {
        HeavyWeapon = SFXHeavyWeapon(Weapon);
        if (HeavyWeapon != None)
        {
            continue;
        }
        GEManager = Weapon.GetModule(Class'SFXModule_GameEffectManager');
        if (GEManager == None)
        {
            continue;
        }
        GEManager.RemoveEffectsByTypeAndCategory(Class'SFXWeaponGameEffect_RateOfFireBonus', Name);
        GEManager.RemoveEffectsByTypeAndCategory(Class'SFXWeaponGameEffect_AccuracyBonus', Name);
        ApplyTemporaryGameEffect(Weapon, Class'SFXWeaponGameEffect_RateOfFireBonus', EffectDuration.CurrentValue, RateOfFireIncrease.CurrentValue * EffectivenessModifier, Name, m_oPawn.Controller);
        ApplyTemporaryGameEffect(Weapon, Class'SFXWeaponGameEffect_AccuracyBonus', EffectDuration.CurrentValue, -AccuracyIncrease.CurrentValue * EffectivenessModifier, Name, m_oPawn.Controller);
        m_oPawn.SetTimer(EffectDuration.CurrentValue, FALSE, 'OnEffectEnded', Self);
        if (IsEvolvedWithChoice(3))
        {
            ApplyTemporaryGameEffect(Weapon, Class'SFXGameEffect_ConstraintDmgBonus', EffectDuration.CurrentValue, HeadShotDamageIncrease.CurrentValue * EffectivenessModifier, Name, m_oPawn.Controller);
        }
    }
    return TRUE;
}
public function EvolvePower(SFXPowerCustomActionBase.EEvolveChoice choice)
{
    Super(SFXPowerCustomActionBase).EvolvePower(choice);
    switch (choice)
    {
        case EEvolveChoice.EvolveChoice1:
            AddEvolvedRankBonus(AccuracyIncrease, Evolve_AccuracyBonus);
            break;
        case EEvolveChoice.EvolveChoice2:
            AddEvolvedRankBonus(RateOfFireIncrease, Evolve_RateOfFireBonus);
            break;
        case EEvolveChoice.EvolveChoice3:
            AddEvolvedRankBonus(EffectDuration, Evolve_DurationBonus);
            break;
        case EEvolveChoice.EvolveChoice4:
            AddEvolvedRankBonus(HeadShotDamageIncrease, Evolve_HeadShotDamageBonus);
            break;
        case EEvolveChoice.EvolveChoice5:
            AddEvolvedRankBonus(AccuracyIncrease, Evolve_AccuracyAndRoFBonus);
            AddEvolvedRankBonus(RateOfFireIncrease, Evolve_AccuracyAndRoFBonus);
            break;
        case EEvolveChoice.EvolveChoice6:
            AddEvolvedRankBonus(CooldownTime, Evolve_CooldownBonus);
            AddEvolvedRankBonus(HenchmanCooldownTime, Evolve_CooldownBonus);
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
    PowerStatBars[0].EvolvedBonuses[5] = Evolve_CooldownBonus;
    PowerStatBars[1].Data = EffectDuration;
    PowerStatBars[1].srDisplayTotalToken = StatBarToken_Time;
    PowerStatBars[1].srStatBarDisplayTitle = StatBarTitle_Duration;
    PowerStatBars[1].EvolvedBonuses[2] = Evolve_DurationBonus;
    PowerStatBars[2].Data = RateOfFireIncrease;
    PowerStatBars[2].Formula = EPowerStatBarFormula.EPowerStatBarFormula_Percent;
    PowerStatBars[2].srDisplayTotalToken = StatBarToken_Percent;
    PowerStatBars[2].srStatBarDisplayTitle = $582241;
    PowerStatBars[2].EvolvedBonuses[1] = Evolve_RateOfFireBonus;
    PowerStatBars[2].EvolvedBonuses[4] = Evolve_AccuracyAndRoFBonus;
    PowerStatBars[3].Data = AccuracyIncrease;
    PowerStatBars[3].Formula = EPowerStatBarFormula.EPowerStatBarFormula_Percent;
    PowerStatBars[3].srDisplayTotalToken = StatBarToken_Percent;
    PowerStatBars[3].srStatBarDisplayTitle = $582969;
    PowerStatBars[3].EvolvedBonuses[0] = Evolve_AccuracyBonus;
    PowerStatBars[3].EvolvedBonuses[4] = Evolve_AccuracyAndRoFBonus;
}
public function RecalculateAllPowerData(optional bool bReset = FALSE)
{
    Super(SFXPowerCustomActionBase).RecalculateAllPowerData(bReset);
    RecalculatePowerData(RateOfFireIncrease, bReset);
    RecalculatePowerData(HeadShotDamageIncrease, bReset);
    RecalculatePowerData(AccuracyIncrease, bReset);
    RecalculatePowerData(SquadBonusEffectiveness, bReset);
}
public function StartPower()
{
    Super.StartPower();
    bEffectEnded = FALSE;
}
public function StartPowerCooldown()
{
    local BioCheatManager CheatManager;
    
    if (m_oPawn == None || m_oPawn.PowerManager == None)
    {
        return;
    }
    CheatManager = m_oPawn.PowerManager.GetCheatManager();
    if (CheatManager != None)
    {
        if (CheatManager.m_bEnablePowerCooldown == FALSE)
        {
            return;
        }
    }
    if (bEffectEnded)
    {
        Super.StartPowerCooldown();
    }
    else
    {
        m_oPawn.Controller.ConsoleCommand("SetFakePermaCooldown");
    }
}
public function OnEffectEnded()
{
    local SFXModule_GameEffectManager Manager;
    
    Manager = m_oPawn.GetModule(Class'SFXModule_GameEffectManager');
    if (Manager != None)
    {
        Manager.RemoveEffectsByCategory(Name);
    }
    bEffectEnded = TRUE;
    StartPowerCooldown();
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    RateOfFireIncrease = {
                          DynamicBonuses = (), 
                          RankBonuses[0] = 0.0, 
                          RankBonuses[1] = 0.0, 
                          RankBonuses[2] = 0.0, 
                          RankBonuses[3] = 0.0, 
                          RankBonuses[4] = 0.0, 
                          RankBonuses[5] = 0.0, 
                          BaseValue = 0.300000012, 
                          CurrentValue = 0.0, 
                          Formula = EPowerDataFormula.BonusIsHardValue
                         }
    HeadShotDamageIncrease = {
                              DynamicBonuses = (), 
                              RankBonuses[0] = 0.0, 
                              RankBonuses[1] = 0.0, 
                              RankBonuses[2] = 0.0, 
                              RankBonuses[3] = 0.0, 
                              RankBonuses[4] = 0.0, 
                              RankBonuses[5] = 0.0, 
                              BaseValue = 0.25, 
                              CurrentValue = 0.0, 
                              Formula = EPowerDataFormula.Normal
                             }
    AccuracyIncrease = {
                        DynamicBonuses = (), 
                        RankBonuses[0] = 0.0, 
                        RankBonuses[1] = 0.0, 
                        RankBonuses[2] = 0.0, 
                        RankBonuses[3] = 0.0, 
                        RankBonuses[4] = 0.0, 
                        RankBonuses[5] = 0.0, 
                        BaseValue = 0.300000012, 
                        CurrentValue = 0.0, 
                        Formula = EPowerDataFormula.BonusIsHardValue
                       }
    SquadBonusEffectiveness = {
                               DynamicBonuses = (), 
                               RankBonuses[0] = 0.0, 
                               RankBonuses[1] = 0.0, 
                               RankBonuses[2] = 0.0, 
                               RankBonuses[3] = 0.0, 
                               RankBonuses[4] = 0.0, 
                               RankBonuses[5] = 0.0, 
                               BaseValue = 0.5, 
                               CurrentValue = 0.0, 
                               Formula = EPowerDataFormula.Normal
                              }
    Evolve_AccuracyBonus = 0.300000012
    Evolve_RateOfFireBonus = 0.200000003
    Evolve_DurationBonus = 0.400000006
    Evolve_HeadShotDamageBonus = 0.25
    Evolve_CooldownBonus = 0.400000006
    Evolve_AccuracyAndRoFBonus = 0.200000003
    MarksmanSound = None
    CE_CasterCrustTemplate = RvrClientEffect'BioVFX_C_Marksmen.VCFX.Marksmen_FB_VCFX'
    CastSound = WwiseEvent'Wwise_Power_Soldier_Marksman.Play_power_soldier_P_marksmen_cast'
    HenchmanCastSound = WwiseEvent'Wwise_Power_Soldier_Marksman.Play_power_soldier_NP_marksmen_cast'
    Discipline = EBioCapMode.BIO_CAPMODE_COMBAT
    CooldownTime = {RankBonuses[1] = 0.25, BaseValue = 10.0, Formula = EPowerDataFormula.DivideByBonusSum}
    HenchmanCooldownTime = {RankBonuses[1] = 0.25, BaseValue = 20.0, Formula = EPowerDataFormula.DivideByBonusSum}
    EffectDuration = {RankBonuses[2] = 0.300000012, BaseValue = 6.0}
    Ranks = ({
              Icon = 82, 
              Name = $0, 
              Description = $0, 
              Evolved1Name = $572088, 
              Evolved1Description = $572089, 
              Evolved2Name = $0, 
              Evolved2Description = $0
             }, 
             {
              Icon = 82, 
              Name = $0, 
              Description = $0, 
              Evolved1Name = $572092, 
              Evolved1Description = $572097, 
              Evolved2Name = $0, 
              Evolved2Description = $0
             }, 
             {
              Icon = 82, 
              Name = $0, 
              Description = $0, 
              Evolved1Name = $572093, 
              Evolved1Description = $572098, 
              Evolved2Name = $0, 
              Evolved2Description = $0
             }, 
             {
              Icon = 82, 
              Name = $0, 
              Description = $0, 
              Evolved1Name = $572100, 
              Evolved1Description = $572099, 
              Evolved2Name = $572101, 
              Evolved2Description = $572102
             }, 
             {
              Icon = 82, 
              Name = $0, 
              Description = $0, 
              Evolved1Name = $572103, 
              Evolved1Description = $572104, 
              Evolved2Name = $572105, 
              Evolved2Description = $572106
             }, 
             {
              Icon = 82, 
              Name = $0, 
              Description = $0, 
              Evolved1Name = $572107, 
              Evolved1Description = $572108, 
              Evolved2Name = $572109, 
              Evolved2Description = $572110
             }
            )
    PowerName = 'Marksman'
    PowerCustomActionID = 59
    DisplayName = $572088
    Description = $703576
    Icon = 82
    TalentDescription = $703576
    IsBonusPower = TRUE
    PowerType = EPowerType.PowerType_Buff
    HenchmanPowerType = EPowerType.PowerType_Buff
}