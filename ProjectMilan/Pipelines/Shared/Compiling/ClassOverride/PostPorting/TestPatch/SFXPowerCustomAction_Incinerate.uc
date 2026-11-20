// Source: ME3, Patch_SFXPwrCustomActionIncinerate
// Decompiled 11/17/2026 7:38:37 AM against BioH_EDI_00.pcc
Class SFXPowerCustomAction_Incinerate extends SFXPowerCustomAction
    config(Game);

var config float Evolve_DamageBonus;
var config float Evolve_RadiusBonus;
var config float Evolve_DoTDamagePercent;
var config float Evolve_DoTDuration;
var config float Evolve_CooldownBonus;
var config float Evolve_FrozenDamageBonus;
var config float Evolve_ArmorDamageBonus;
var config int LargeFlameCount;
var config float InstantDamagePercent;
var config float DOTDuration;
var RvrClientEffectInterface CE_IncinerateImpact;
var RvrClientEffectInterface CE_FireDoTTemplate;
var WwiseEvent FrozenImpactSound;
var WwiseEvent HenchmanFrozenImpactSound;
var RvrClientEffectInterface CE_DeathEffectTemplate;
var bool bPlayFrozenImpact;

public function bool OnImpact(Actor.EPowerResistance Resistance, Actor oImpacted, int nPreviouslyImpacted, Object.Vector HitLocation, Object.Vector HitNormal)
{
    local SFXModule_GameEffectManager Manager;
    local SFXGameEffect_FireDamageOverTime Effect;
    local Class<SFXDamageType> DamageType;
    local float fDamagePerSecond;
    local RvrClientEffectInterface.RvrClientEffectTarget TargetInfo;
    local SFXGameEffect_FireDeath DeathEffect;
    
    if (oImpacted == None)
    {
        return FALSE;
    }
    Manager = oImpacted.GetModule(Class'SFXModule_GameEffectManager');
    if (Resistance == EPowerResistance.Resistance_None && Manager != None)
    {
        if (!Manager.HasEffectOfTypeAndCategory(Class'SFXGameEffect_HealthRegenPenalty', Name))
        {
            ApplyPermanentGameEffect(oImpacted, Class'SFXGameEffect_HealthRegenPenalty', 1.0, Name, m_oPawn.Controller);
        }
        if (!Manager.HasEffectOfTypeAndCategory(Class'SFXGameEffect_FireDeath', Name))
        {
            DeathEffect = SFXGameEffect_FireDeath(Manager.CreateEffect(Class'SFXGameEffect_FireDeath', Name, 2.0, 1, 0.0, m_oPawn.Controller));
            if (DeathEffect != None)
            {
                DeathEffect.CE_DeathEffectTemplate = CE_DeathEffectTemplate;
            }
        }
    }
    if (Resistance != EPowerResistance.Resistance_Full)
    {
        if (Manager != None)
        {
            fDamagePerSecond = GetTotalDamage(oImpacted, DamageType) * (1.0 - InstantDamagePercent) / DOTDuration;
            Effect = SFXGameEffect_FireDamageOverTime(Manager.CreateEffect(Class'SFXGameEffect_FireDamageOverTime', Name, DOTDuration, 1, fDamagePerSecond, m_oPawn.Controller));
            if (Effect != None)
            {
                Effect.DamageType = DamageType;
                Effect.bCanCauseCombo = FALSE;
                Effect.OnApplied();
            }
            AddComboEffect(oImpacted, Class'SFXGameEffect_PowerCombo_Fire', DOTDuration);
            if (IsEvolvedWithChoice(2))
            {
                fDamagePerSecond = GetTotalDamage(oImpacted, DamageType) * Evolve_DoTDamagePercent / Evolve_DoTDuration;
                Effect = SFXGameEffect_FireDamageOverTime(Manager.CreateEffect(Class'SFXGameEffect_FireDamageOverTime', Name, Evolve_DoTDuration, 1, fDamagePerSecond, m_oPawn.Controller));
                if (Effect != None)
                {
                    Effect.DamageType = DamageType;
                    Effect.bCanCauseCombo = FALSE;
                    Effect.OnApplied();
                }
            }
            TargetInfo.Instigator = oImpacted;
            if (IsEvolvedWithChoice(2))
            {
                TargetInfo.SpawnValue.X = Evolve_DoTDuration;
            }
            else
            {
                TargetInfo.SpawnValue.X = DOTDuration;
            }
            Class'RvrClientEffectManager'.static.GetClientEffectManager().PlayOnTarget(CE_FireDoTTemplate, TargetInfo);
        }
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
        return ShouldUsePowerOnShields(oPawn, Class'SFXDamageType_Incinerate', sOptionalInfo);
    }
    return TRUE;
}
public function StartCustomAction()
{
    bPlayFrozenImpact = FALSE;
    Super.StartCustomAction();
}
public function ApplyBonus(Name Parameter, SFXGameEffect Bonus, optional bool bRemove = FALSE)
{
    Super.ApplyBonus(Parameter, Bonus, bRemove);
    switch (Parameter)
    {
        case 'FireDamage':
            ApplyBonusToParameter(Damage, Bonus, bRemove);
            break;
        default:
    }
}
public function EvolvePower(SFXPowerCustomActionBase.EEvolveChoice choice)
{
    Super(SFXPowerCustomActionBase).EvolvePower(choice);
    switch (choice)
    {
        case EEvolveChoice.EvolveChoice1:
            AddEvolvedRankBonus(Damage, Evolve_DamageBonus);
            break;
        case EEvolveChoice.EvolveChoice2:
            AddEvolvedRankBonus(ImpactRadius, Evolve_RadiusBonus);
            break;
        case EEvolveChoice.EvolveChoice3:
            break;
        case EEvolveChoice.EvolveChoice4:
            AddEvolvedRankBonus(CooldownTime, Evolve_CooldownBonus);
            AddEvolvedRankBonus(HenchmanCooldownTime, Evolve_CooldownBonus);
            break;
        case EEvolveChoice.EvolveChoice5:
            break;
        case EEvolveChoice.EvolveChoice6:
            break;
        default:
    }
    RecalculateAllPowerInfo();
}
public function float GetImpactDamage(Actor oImpacted, out Class<SFXDamageType> DamageType)
{
    return GetTotalDamage(oImpacted, DamageType) * InstantDamagePercent;
}
public function OnPowerDetonated(Object.Vector HitLocation, Object.Vector HitNormal, optional SFXProjectile_PowerCustomAction oProjectile, optional Actor HitActor)
{
    local Object.Vector Params;
    
    Super.OnPowerDetonated(HitLocation, HitNormal, oProjectile, HitActor);
    if (IsEvolvedWithChoice(1))
    {
        Params.Y = 1.0;
    }
    if (bPlayFrozenImpact)
    {
        if (SFXPawn_Henchman(m_oPawn) != None)
        {
            SFXGRI(m_oPawn.WorldInfo.GRI).PlayTransientSound(HenchmanFrozenImpactSound, HitLocation);
        }
        else
        {
            SFXGRI(m_oPawn.WorldInfo.GRI).PlayTransientSound(FrozenImpactSound, HitLocation);
        }
        Params.Z = 1.0;
    }
    Class'RvrClientEffectManager'.static.GetClientEffectManager().PlayAtLocation(CE_IncinerateImpact, HitLocation, HitNormal, Params);
}
public function PopulatePowerStatBarEvolves()
{
    PowerStatBars.Length = 2;
    PowerStatBars[0].Data = SFXPawn_Henchman(m_oPawn) == None ? CooldownTime : HenchmanCooldownTime;
    PowerStatBars[0].srDisplayTotalToken = StatBarToken_Time;
    PowerStatBars[0].srStatBarDisplayTitle = StatBarTitle_Cooldown;
    PowerStatBars[0].EvolvedBonuses[3] = Evolve_CooldownBonus;
    PowerStatBars[1].Data = Damage;
    PowerStatBars[1].srDisplayTotalToken = StatBarToken_RawValue;
    PowerStatBars[1].srStatBarDisplayTitle = StatBarTitle_Damage;
    PowerStatBars[1].EvolvedBonuses[0] = Evolve_DamageBonus;
}
public function float GetTotalDamage(Actor oImpacted, out Class<SFXDamageType> DamageType)
{
    local SFXModule_GameEffectManager Manager;
    local float fDamage;
    local SFXGameEffect Effect;
    local bool bImpactedIsChilled;
    
    fDamage = Damage.CurrentValue;
    if (IsEvolvedWithChoice(5))
    {
        DamageType = Class'SFXDamageType_ImprovedIncinerate';
    }
    else
    {
        DamageType = Class'SFXDamageType_Incinerate';
    }
    if (oImpacted == None)
    {
        return fDamage;
    }
    if (IsEvolvedWithChoice(4))
    {
        Manager = oImpacted.GetModule(Class'SFXModule_GameEffectManager');
        if (Manager != None)
        {
            bImpactedIsChilled = FALSE;
            foreach Manager.GameEffects(Effect, )
            {
                if (Effect.IsA('SFXGameEffect_MovementSpeedBonus') && Effect.EffectValue < float(0) && InStr(string(Effect.Category), "Cryo", , , ) != -1)
                {
                    bImpactedIsChilled = TRUE;
                    break;
                }
            }
            if (bImpactedIsChilled || Manager.HasEffectOfType(Class'SFXGameEffect_DelayedCryoFreeze') || Manager.HasEffectOfType(Class'SFXGameEffect_CryoFreeze'))
            {
                bPlayFrozenImpact = TRUE;
                fDamage *= 1.0 + Evolve_FrozenDamageBonus;
            }
        }
    }
    return fDamage;
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    Begin Object Class=BioDynamicAnimSet Name=MY_DYN_HMM_BC_RifleTechTool
        m_nmOrigSetName = 'HMM_BC_RifleTechTool'
        Sequences = (AnimSequence'BIOG_HMM_BC_A.HMM_BC_RifleTechTool_BC_Start', AnimSequence'BIOG_HMM_BC_A.HMM_BC_RifleTechTool_BC_End')
        m_pBioAnimSetData = BioAnimSetData'BIOG_HMM_BC_A.HMM_BC_RifleTechTool_BioAnimSetData'
    End Object
    Evolve_DamageBonus = 0.300000012
    Evolve_RadiusBonus = 200.0
    Evolve_DoTDamagePercent = 0.400000006
    Evolve_DoTDuration = 8.0
    Evolve_CooldownBonus = 0.25
    Evolve_FrozenDamageBonus = 1.0
    Evolve_ArmorDamageBonus = 0.5
    LargeFlameCount = 3
    InstantDamagePercent = 0.75
    DOTDuration = 3.0
    CE_IncinerateImpact = RvrClientEffect'BioVFX_T_TechPowers.09_Incinerate.VCFX.Incinerate_Imp_VCFX'
    CE_FireDoTTemplate = RvrClientEffect'biovfx_c_fire.VCFX.Fire_Dot_VCFX'
    CE_DeathEffectTemplate = RvrClientEffect'biovfx_c_fire.VCFX.Fire_Death_VCFX'
    ComboDetonators = (Class'SFXGameEffect_PowerCombo_Electric', Class'SFXGameEffect_PowerCombo_Fire', Class'SFXGameEffect_PowerCombo_Cryo')
    EvolvedImpactSounds = ({Sound = WwiseEvent'Wwise_Power_Tech_Incinerate.Play_power_tech_P_incinerate_evolimpact', bAnyEvolved = TRUE, bReplaceBaseSound = TRUE, EvolveChoice = EEvolveChoice.EvolveChoice1}
                          )
    EvolvedCastSounds = ({Sound = WwiseEvent'Wwise_Power_Tech_Incinerate.Play_power_tech_P_incinerate_evolcast', bAnyEvolved = TRUE, bReplaceBaseSound = TRUE, EvolveChoice = EEvolveChoice.EvolveChoice1}
                        )
    HenchmanEvolvedImpactSounds = ({Sound = WwiseEvent'Wwise_Power_Tech_Incinerate.Play_power_tech_NP_incinerate_evolimpact', bAnyEvolved = TRUE, bReplaceBaseSound = TRUE, EvolveChoice = EEvolveChoice.EvolveChoice1}
                                  )
    HenchmanEvolvedCastSounds = ({Sound = WwiseEvent'Wwise_Power_Tech_Incinerate.Play_power_tech_NP_incinerate_evolcast', bAnyEvolved = TRUE, bReplaceBaseSound = TRUE, EvolveChoice = EEvolveChoice.EvolveChoice1}
                                )
    ProjectileClass = Class'SFXProjectile_PowerCustomAction_SuperSeeking'
    DetonationRumbleClass = Class'SFXRumble_Power_HeavyImpact'
    DetonationScreenShakeClass = Class'SFXShake_Power_HeavyImpact'
    CustomCasterCrustParameters = {X = 1.0, Y = 0.0, Z = 0.0}
    ProjectileAttachPoint = 'LeftWrist'
    ReleaseEffectBoneName = 'LeftWrist'
    ReleaseTime = 0.100000001
    CastAnimSet = MY_DYN_HMM_BC_RifleTechTool
    CE_CasterCrustTemplate = RvrClientEffectMulti'BioVFX_T_TechPowers._OmniTool.VCFX.OmniTool_LeftFull_Cbt_VCFX_M'
    CE_ReleaseEffectTemplate = RvrClientEffect'BioVFX_T_TechBall.VCFX.Tech_Attack_Muzzle_VCFX'
    CE_ProjectileTemplate = RvrClientEffect'BioVFX_T_TechPowers.09_Incinerate.VCFX.Incinerate_Projectile_VCFX'
    ImpactSound = WwiseEvent'Wwise_Power_Tech_Incinerate.Play_power_tech_P_incinerate_impact'
    CastSound = WwiseEvent'Wwise_Power_Tech_Incinerate.Play_power_tech_P_incinerate_cast'
    HenchmanImpactSound = WwiseEvent'Wwise_Power_Tech_Incinerate.Play_power_tech_NP_incinerate_impact'
    HenchmanCastSound = WwiseEvent'Wwise_Power_Tech_Incinerate.Play_power_tech_NP_incinerate_cast'
    ImpactDistanceLayer = WwiseEvent'Wwise_Generic_Explosions.Play_power_engineer_P_incinerate_distant'
    HenchmanImpactDistanceLayer = WwiseEvent'Wwise_Generic_Explosions.Play_power_engineer_NP_incinerate_distant'
    bCustomCasterCrustParameters = TRUE
    Discipline = EBioCapMode.BIO_CAPMODE_TECH
    CooldownTime = {RankBonuses[1] = 0.25, BaseValue = 8.0, Formula = EPowerDataFormula.DivideByBonusSum}
    HenchmanCooldownTime = {RankBonuses[1] = 0.25, BaseValue = 16.0, Formula = EPowerDataFormula.DivideByBonusSum}
    MaximumRange = {BaseValue = 6000.0}
    ImpactRadius = {Formula = EPowerDataFormula.BonusIsHardValue}
    EffectDuration = {BaseValue = 3.0}
    Damage = {RankBonuses[2] = 0.200000003, BaseValue = 300.0}
    Force = {BaseValue = 150.0}
    ProjectileSpeed = {BaseValue = 3000.0}
    Ranks = ({
              Icon = 59, 
              Name = $0, 
              Description = $0, 
              Evolved1Name = $244472, 
              Evolved1Description = $244473, 
              Evolved2Name = $0, 
              Evolved2Description = $0
             }, 
             {
              Icon = 59, 
              Name = $0, 
              Description = $0, 
              Evolved1Name = $250283, 
              Evolved1Description = $558805, 
              Evolved2Name = $0, 
              Evolved2Description = $0
             }, 
             {
              Icon = 59, 
              Name = $0, 
              Description = $0, 
              Evolved1Name = $250284, 
              Evolved1Description = $560406, 
              Evolved2Name = $0, 
              Evolved2Description = $0
             }, 
             {
              Icon = 59, 
              Name = $0, 
              Description = $0, 
              Evolved1Name = $244477, 
              Evolved1Description = $558835, 
              Evolved2Name = $558806, 
              Evolved2Description = $558836
             }, 
             {
              Icon = 59, 
              Name = $0, 
              Description = $0, 
              Evolved1Name = $558831, 
              Evolved1Description = $558837, 
              Evolved2Name = $558832, 
              Evolved2Description = $558838
             }, 
             {
              Icon = 59, 
              Name = $0, 
              Description = $0, 
              Evolved1Name = $558833, 
              Evolved1Description = $558839, 
              Evolved2Name = $558834, 
              Evolved2Description = $558840
             }
            )
    PowerName = 'Incinerate'
    PowerCustomActionID = 29
    DisplayName = $244472
    Description = $664218
    Icon = 59
    TalentDescription = $664218
    PowerType = EPowerType.PowerType_Projectile
    VocalizationEvent = ESFXVocalizationEventID.SFXVocalizationEvent_Power_Incinerate
}