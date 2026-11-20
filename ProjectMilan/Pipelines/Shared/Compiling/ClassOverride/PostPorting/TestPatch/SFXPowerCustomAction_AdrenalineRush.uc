// Source: ME3, Patch_SFXPwrCustActAdrenalineRush
// Decompiled 11/17/2026 7:38:31 AM against BioP_Char.pcc
Class SFXPowerCustomAction_AdrenalineRush extends SFXPowerCustomAction
    config(Game);

var config SFXPowerCustomActionBase.PowerData TimeDilation;
var config SFXPowerCustomActionBase.PowerData WeaponDamageBonus;
var Object.Guid AdrenalineGuid;
var config float Evolve_HealthShieldDamageTaken;
var config float Evolve_TimeDilationIncrease;
var config float Evolve_DamageBonusIncrease;
var config float Evolve_DurationBonus;
var config float Evolve_MeleeDamageBonus;
var config float Evolve_ShieldIncrease;
var config int Evolve_NumFreePowers;
var RvrClientEffectInterface CE_AdrenalineTemplate;
var bool bEffectEnded;

public function bool OnImpact(Actor.EPowerResistance Resistance, Actor oImpacted, int nPreviouslyImpacted, Object.Vector HitLocation, Object.Vector HitNormal)
{
    local BioPawn oImpactedPawn;
    local float fDuration;
    local Object.Vector Params;
    
    oImpactedPawn = BioPawn(oImpacted);
    if (oImpactedPawn == None)
    {
        return FALSE;
    }
    fDuration = EffectDuration.CurrentValue;
    Params.X = fDuration;
    AdrenalineGuid = Class'RvrClientEffectManager'.static.GetClientEffectManager().Start(CE_AdrenalineTemplate, m_oPawn, Params);
    oImpactedPawn.SetTimer(fDuration, FALSE, 'OnEffectEnded', Self);
    m_oPawn.SetTimer(0.5, TRUE, 'CheckForDeath', Self);
    if (TimeDilation.CurrentValue > float(0) && oImpactedPawn.IsHumanControlled())
    {
        ApplyTemporaryGameEffect(oImpacted, Class'SFXGameEffect_TimeDilation', fDuration, TimeDilation.CurrentValue, Name, m_oPawn.Controller);
    }
    if (WeaponDamageBonus.CurrentValue > float(0))
    {
        ApplyTemporaryGameEffect(oImpacted, Class'SFXGameEffect_WeaponDamageBonus', fDuration, WeaponDamageBonus.CurrentValue, Name, m_oPawn.Controller);
    }
    if (IsEvolvedWithChoice(0))
    {
        ApplyTemporaryGameEffect(oImpacted, Class'SFXGameEffect_DamageTakenBonus', fDuration, -Evolve_HealthShieldDamageTaken, Name, m_oPawn.Controller);
    }
    if (IsEvolvedWithChoice(3))
    {
        ApplyTemporaryGameEffect(oImpacted, Class'SFXGameEffect_MeleeDamageBonus', fDuration, Evolve_MeleeDamageBonus, Name, m_oPawn.Controller);
    }
    if (IsEvolvedWithChoice(4))
    {
        ApplyShieldBonus(oImpactedPawn, Evolve_ShieldIncrease, TRUE, fDuration, Name);
    }
    return TRUE;
}
public function OnPowerReleased(SFXPowerCustomAction oPower)
{
    if (oPower.UsesSharedCooldown)
    {
        SetOffensivePowerCooldowns(CurrentCooldownTime);
    }
}
public function EvolvePower(SFXPowerCustomActionBase.EEvolveChoice choice)
{
    Super(SFXPowerCustomActionBase).EvolvePower(choice);
    switch (choice)
    {
        case EEvolveChoice.EvolveChoice1:
            break;
        case EEvolveChoice.EvolveChoice2:
            AddEvolvedRankBonus(TimeDilation, Evolve_TimeDilationIncrease);
            AddEvolvedRankBonus(WeaponDamageBonus, Evolve_DamageBonusIncrease);
            break;
        case EEvolveChoice.EvolveChoice3:
            AddEvolvedRankBonus(EffectDuration, Evolve_DurationBonus);
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
}
public function PopulatePowerStatBarEvolves()
{
    PowerStatBars.Length = 4;
    PowerStatBars[0].Data = SFXPawn_Henchman(m_oPawn) == None ? CooldownTime : HenchmanCooldownTime;
    PowerStatBars[0].srDisplayTotalToken = StatBarToken_Time;
    PowerStatBars[0].srStatBarDisplayTitle = StatBarTitle_Cooldown;
    PowerStatBars[1].Data = EffectDuration;
    PowerStatBars[1].srDisplayTotalToken = StatBarToken_Time;
    PowerStatBars[1].srStatBarDisplayTitle = StatBarTitle_Duration;
    PowerStatBars[1].EvolvedBonuses[2] = Evolve_DurationBonus;
    PowerStatBars[2].Data = TimeDilation;
    PowerStatBars[2].Formula = EPowerStatBarFormula.EPowerStatBarFormula_Percent;
    PowerStatBars[2].srDisplayTotalToken = StatBarToken_Percent;
    PowerStatBars[2].srStatBarDisplayTitle = $585453;
    PowerStatBars[2].EvolvedBonuses[1] = Evolve_TimeDilationIncrease;
    PowerStatBars[3].Data = WeaponDamageBonus;
    PowerStatBars[3].Formula = EPowerStatBarFormula.EPowerStatBarFormula_Percent;
    PowerStatBars[3].srDisplayTotalToken = StatBarToken_Percent;
    PowerStatBars[3].srStatBarDisplayTitle = $585454;
    PowerStatBars[3].EvolvedBonuses[1] = Evolve_DamageBonusIncrease;
}
public function RecalculateAllPowerData(optional bool bReset = FALSE)
{
    Super(SFXPowerCustomActionBase).RecalculateAllPowerData(bReset);
    RecalculatePowerData(TimeDilation, bReset);
    RecalculatePowerData(WeaponDamageBonus, bReset);
}
public function ReleasePower()
{
    local SFXWeapon oWeapon;
    
    Super.ReleasePower();
    oWeapon = SFXWeapon(m_oPawn.Weapon);
    if (oWeapon != None && SFXHeavyWeapon(oWeapon) == None)
    {
        oWeapon.DoReload();
    }
    if (IsEvolvedWithChoice(5))
    {
        if (m_oPawn != None && m_oPawn.PowerManager != None)
        {
            m_oPawn.PowerManager.SharedCooldownDisabled = TRUE;
            m_oPawn.PowerManager.RegisterPowerReleasedCallback(OnPowerReleased);
            SetOffensivePowerCooldowns(0.0);
        }
    }
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
    Class'RvrClientEffectManager'.static.GetClientEffectManager().@Stop(CE_AdrenalineTemplate, AdrenalineGuid, TRUE, m_oPawn);
    if (IsEvolvedWithChoice(5))
    {
        if (m_oPawn != None && m_oPawn.PowerManager != None)
        {
            m_oPawn.PowerManager.SharedCooldownDisabled = FALSE;
            m_oPawn.PowerManager.UnregisterPowerReleasedCallback(OnPowerReleased);
        }
    }
    m_oPawn.ClearTimer('CheckForDeath', Self);
    bEffectEnded = TRUE;
    StartPowerCooldown();
}
public function SetOffensivePowerCooldowns(float fCooldown)
{
    local SFXPowerCustomActionBase oPowerBase;
    local SFXPowerCustomAction oPower;
    
    foreach m_oPawn.PowerManager.Powers(oPowerBase, )
    {
        oPower = SFXPowerCustomAction(oPowerBase);
        if (oPower != None)
        {
            if (oPower.UsesSharedCooldown && (oPower.PowerType == EPowerType.PowerType_Instant || oPower.PowerType == EPowerType.PowerType_Projectile))
            {
                oPower.CurrentCooldownTime = fCooldown;
                oPower.TotalCooldownTime = fCooldown;
            }
        }
    }
}
public function CheckForDeath()
{
    local BioWorldInfo Info;
    local BioPlayerController PC;
    
    Info = BioWorldInfo(m_oPawn.WorldInfo);
    if (Info != None)
    {
        PC = Info.GetLocalPlayerController();
        if (PC != None && (PC.GameModeManager2.IsActive(8) || PC.GameModeManager2.IsActive(7)))
        {
            OnEffectEnded();
            return;
        }
    }
    if (m_oPawn.IsInState('Downed', ))
    {
        OnEffectEnded();
    }
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    TimeDilation = {
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
    WeaponDamageBonus = {
                         DynamicBonuses = (), 
                         RankBonuses[0] = 0.0, 
                         RankBonuses[1] = 0.0, 
                         RankBonuses[2] = 0.0, 
                         RankBonuses[3] = 0.0, 
                         RankBonuses[4] = 0.0, 
                         RankBonuses[5] = 0.0, 
                         BaseValue = 0.5, 
                         CurrentValue = 0.0, 
                         Formula = EPowerDataFormula.BonusIsHardValue
                        }
    Evolve_HealthShieldDamageTaken = 0.25
    Evolve_TimeDilationIncrease = 0.150000006
    Evolve_DamageBonusIncrease = 0.25
    Evolve_DurationBonus = 0.400000006
    Evolve_MeleeDamageBonus = 0.5
    Evolve_ShieldIncrease = 0.5
    Evolve_NumFreePowers = 1
    CE_AdrenalineTemplate = RvrClientEffect'BioVFX_C_Adrenaline.VCFX.AdrenalineRush_VCFX'
    EvolvedCastSounds = ({Sound = WwiseEvent'Wwise_Power_Soldier_AdrenRush.Play_power_soldier_P_adrenaline_evolcast', bAnyEvolved = TRUE, bReplaceBaseSound = TRUE, EvolveChoice = EEvolveChoice.EvolveChoice1}
                        )
    HenchmanEvolvedCastSounds = ({Sound = WwiseEvent'Wwise_Power_Soldier_AdrenRush.Play_power_soldier_NP_adrenaline_evolcast', bAnyEvolved = TRUE, bReplaceBaseSound = TRUE, EvolveChoice = EEvolveChoice.EvolveChoice1}
                                )
    CastSound = WwiseEvent'Wwise_Power_Soldier_AdrenRush.Play_power_soldier_P_adrenaline_cast'
    HenchmanCastSound = WwiseEvent'Wwise_Power_Soldier_AdrenRush.Play_power_soldier_NP_adrenaline_cast'
    Discipline = EBioCapMode.BIO_CAPMODE_COMBAT
    CooldownTime = {RankBonuses[1] = 0.25, BaseValue = 10.0, Formula = EPowerDataFormula.DivideByBonusSum}
    EffectDuration = {RankBonuses[2] = 0.300000012, BaseValue = 4.0}
    Ranks = ({
              Icon = 63, 
              Name = $0, 
              Description = $0, 
              Evolved1Name = $505301, 
              Evolved1Description = $170428, 
              Evolved2Name = $0, 
              Evolved2Description = $0
             }, 
             {
              Icon = 63, 
              Name = $0, 
              Description = $0, 
              Evolved1Name = $244425, 
              Evolved1Description = $505226, 
              Evolved2Name = $0, 
              Evolved2Description = $0
             }, 
             {
              Icon = 63, 
              Name = $0, 
              Description = $0, 
              Evolved1Name = $244426, 
              Evolved1Description = $505281, 
              Evolved2Name = $0, 
              Evolved2Description = $0
             }, 
             {
              Icon = 63, 
              Name = $0, 
              Description = $0, 
              Evolved1Name = $188935, 
              Evolved1Description = $188938, 
              Evolved2Name = $188936, 
              Evolved2Description = $188939
             }, 
             {
              Icon = 63, 
              Name = $0, 
              Description = $0, 
              Evolved1Name = $505274, 
              Evolved1Description = $505277, 
              Evolved2Name = $505278, 
              Evolved2Description = $505279
             }, 
             {
              Icon = 63, 
              Name = $0, 
              Description = $0, 
              Evolved1Name = $505282, 
              Evolved1Description = $505283, 
              Evolved2Name = $505284, 
              Evolved2Description = $505285
             }
            )
    PowerName = 'AdrenalineRush'
    PowerCustomActionID = 13
    DisplayName = $505301
    Description = $703500
    Icon = 63
    TalentDescription = $703500
    PowerType = EPowerType.PowerType_Buff
    HenchmanPowerType = EPowerType.PowerType_Buff
    VocalizationEvent = ESFXVocalizationEventID.SFXVocalizationEvent_Power_Buff
}