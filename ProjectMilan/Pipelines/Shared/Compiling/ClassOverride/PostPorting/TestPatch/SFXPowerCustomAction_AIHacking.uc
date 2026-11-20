// Source: ME3, Patch_SFXPowerCustomActionAIHacking
// Decompiled 11/17/2026 7:38:32 AM against BioD_Gth002_210Tower.pcc
Class SFXPowerCustomAction_AIHacking extends SFXPowerCustomAction
    config(Game);

var config SFXPowerCustomActionBase.PowerData ExplosionDamage;
var config SFXPowerCustomActionBase.PowerData ExplosionForce;
var config SFXPowerCustomActionBase.PowerData ExplosionRadius;
var config SFXPowerCustomActionBase.PowerData WeaponExplosionDamage;
var config SFXPowerCustomActionBase.PowerData TimeHackedRobotIgnored;
var array<float> ShieldStrength;
var array<Actor> m_oCurrentHackedTargets;
var config array<Name> UnaffectedPawns;
var config SFXPreAsyncWorkTicker.AreaEffectParameters ExplosionParameters;
var Name TechPowerDamageTakenBonusEffectCategory;
var config float WeaponHackDuration;
var config int MaxHackedRobots;
var config float Evolve_DurationBonus;
var config float Evolve_CooldownBonus;
var config float Evolve_BerserkDamageBonus;
var config float Evolve_BerserkMoveSpeedBonus;
var config float Evolve_WeaponExplosionDamageBonus;
var config float Evolve_TechPowerDamageBonus;
var config float Evolve_TechPowerDuration;
var RvrClientEffectInterface ExplosionTemplate;
var RvrClientEffectInterface CE_RobotHackTemplate;
var RvrClientEffectInterface CE_RobotSuperHackTemplate;
var RvrClientEffectInterface CE_CustomImpactTemplate;
var bool bRobotHacked;

public function bool OnImpact(Actor.EPowerResistance Resistance, Actor oImpacted, int nPreviouslyImpacted, Object.Vector HitLocation, Object.Vector HitNormal)
{
    local BioPawn oPawn;
    local SFXModule_GameEffectManager Manager;
    local SFXGameEffect_WeaponSabotage Sabotage;
    
    oPawn = BioPawn(oImpacted);
    if (oPawn == None)
    {
        return FALSE;
    }
    if (Resistance != EPowerResistance.Resistance_Full)
    {
        if (oPawn.RaceType == ERaceType.RaceType_Machine)
        {
            if (!bRobotHacked)
            {
                bRobotHacked = TRUE;
                UnHackPreviousTargets();
            }
            if (m_oPawn != None && m_oPawn.Role == ENetRole.ROLE_Authority && CanHackNewRobot(oPawn))
            {
                HackNewRobot(SFXPawn(oPawn));
            }
        }
        else
        {
            Manager = oPawn.GetModule(Class'SFXModule_GameEffectManager');
            if (Manager != None)
            {
                Sabotage = SFXGameEffect_WeaponSabotage(Manager.CreateEffect(Class'SFXGameEffect_WeaponSabotage', Name, WeaponHackDuration, 1, WeaponExplosionDamage.CurrentValue, m_oPawn.Controller));
                if (Sabotage != None)
                {
                    Sabotage.Power = Self;
                    Sabotage.OnApplied();
                }
            }
        }
        if (IsEvolvedWithChoice(5))
        {
            Manager = oPawn.GetModule(Class'SFXModule_GameEffectManager');
            if (Manager != None)
            {
                Manager.RemoveEffectsByTypeAndCategory(Class'SFXGameEffect_TechPowerDamageTakenBonus', TechPowerDamageTakenBonusEffectCategory);
            }
            ApplyTemporaryGameEffect(oPawn, Class'SFXGameEffect_TechPowerDamageTakenBonus', Evolve_TechPowerDuration, Evolve_TechPowerDamageBonus, TechPowerDamageTakenBonusEffectCategory, m_oPawn.Controller);
        }
    }
    return TRUE;
}
public function bool ShouldUsePower(Actor Target, out string sOptionalInfo)
{
    local SFXPawn oPawn;
    local Name PawnName;
    
    oPawn = SFXPawn(Target);
    if (oPawn != None && oPawn.PowerControlResistance >= 1.0)
    {
        sOptionalInfo = string(NotRecommended_TargetImmune);
        return FALSE;
    }
    if (Target != None)
    {
        foreach UnaffectedPawns(PawnName, )
        {
            if (Target.IsA(PawnName))
            {
                return FALSE;
            }
        }
    }
    return TRUE;
}
public function ApplyBonus(Name Parameter, SFXGameEffect Bonus, optional bool bRemove = FALSE)
{
    Super.ApplyBonus(Parameter, Bonus, bRemove);
    switch (Parameter)
    {
        case 'Damage':
            ApplyBonusToParameter(ExplosionDamage, Bonus, bRemove);
            ApplyBonusToParameter(WeaponExplosionDamage, Bonus, bRemove);
            break;
        case 'Force':
            ApplyBonusToParameter(ExplosionForce, Bonus, bRemove);
            break;
        case 'ImpactRadius':
            ApplyBonusToParameter(ExplosionRadius, Bonus, bRemove);
            break;
        case 'EffectDuration':
            ApplyBonusToParameter(TimeHackedRobotIgnored, Bonus, bRemove);
            break;
        default:
    }
}
public function ClientDoPowerSubsequentImpact(Actor oActor, optional int CustomActionReactionType, optional float Duration, optional int ImpactCount, optional float Delay, optional bool DoCallback)
{
    if (ImpactCount < 0)
    {
        RemoveWeakerHack(BioPawn(oActor), EffectDuration.CurrentValue);
        HackNewRobot(SFXPawn(oActor));
    }
    else
    {
        DoAreaExplosionForActor(oActor, oActor.location, ImpactCount, ExplosionDamage.CurrentValue, Class'SFXDamageType_Power_Ragdoll', ExplosionForce.CurrentValue, ExplosionParameters, 0, None);
    }
}
public function EvolvePower(SFXPowerCustomActionBase.EEvolveChoice choice)
{
    Super(SFXPowerCustomActionBase).EvolvePower(choice);
    switch (choice)
    {
        case EEvolveChoice.EvolveChoice1:
            AddEvolvedRankBonus(EffectDuration, Evolve_DurationBonus);
            AddEvolvedRankBonus(TimeHackedRobotIgnored, Evolve_DurationBonus);
            break;
        case EEvolveChoice.EvolveChoice2:
            AddEvolvedRankBonus(WeaponExplosionDamage, Evolve_WeaponExplosionDamageBonus);
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
public function PlayDetonationEffects(Object.Vector ImpactLocation, Object.Vector ImpactNormal, optional SFXProjectile_PowerCustomAction oProjectile)
{
    Super.PlayDetonationEffects(ImpactLocation, ImpactNormal, oProjectile);
    Class'RvrClientEffectManager'.static.GetClientEffectManager().PlayAtLocation(CE_CustomImpactTemplate, ImpactLocation, ImpactNormal);
}
public function PopulatePowerStatBarEvolves()
{
    PowerStatBars.Length = 4;
    PowerStatBars[0].Data = SFXPawn_Henchman(m_oPawn) == None ? CooldownTime : HenchmanCooldownTime;
    PowerStatBars[0].srDisplayTotalToken = StatBarToken_Time;
    PowerStatBars[0].srStatBarDisplayTitle = StatBarTitle_Cooldown;
    PowerStatBars[0].EvolvedBonuses[3] = Evolve_CooldownBonus;
    PowerStatBars[1].Data = EffectDuration;
    PowerStatBars[1].srDisplayTotalToken = StatBarToken_Time;
    PowerStatBars[1].srStatBarDisplayTitle = $702600;
    PowerStatBars[1].EvolvedBonuses[0] = Evolve_DurationBonus;
    PowerStatBars[2].Data = ImpactRadius;
    PowerStatBars[2].Formula = EPowerStatBarFormula.EPowerStatBarFormula_Distance;
    PowerStatBars[2].srDisplayTotalToken = StatBarToken_Distance;
    PowerStatBars[2].srStatBarDisplayTitle = StatBarTitle_ImpactRadius;
    PowerStatBars[3].Data = WeaponExplosionDamage;
    PowerStatBars[3].Formula = EPowerStatBarFormula.EPowerStatBarFormula_Normal;
    PowerStatBars[3].srDisplayTotalToken = StatBarToken_RawValue;
    PowerStatBars[3].srStatBarDisplayTitle = $560131;
    PowerStatBars[3].EvolvedBonuses[1] = Evolve_WeaponExplosionDamageBonus;
}
public function RecalculateAllPowerData(optional bool bReset = FALSE)
{
    Super(SFXPowerCustomActionBase).RecalculateAllPowerData(bReset);
    RecalculatePowerData(ExplosionDamage, bReset);
    RecalculatePowerData(ExplosionForce, bReset);
    RecalculatePowerData(ExplosionRadius, bReset);
    RecalculatePowerData(TimeHackedRobotIgnored, bReset);
    RecalculatePowerData(WeaponExplosionDamage, bReset);
}
public function StartPower()
{
    Super.StartPower();
    bRobotHacked = FALSE;
}
public final function bool CanHackNewRobot(BioPawn oPawn)
{
    if (m_oCurrentHackedTargets.Length >= MaxHackedRobots)
    {
        return FALSE;
    }
    if (SFXPawn(oPawn).PowerControlResistance >= 1.0)
    {
        return FALSE;
    }
    if (IsHacked(oPawn))
    {
        if (!RemoveWeakerHack(oPawn, EffectDuration.CurrentValue))
        {
            return FALSE;
        }
    }
    return TRUE;
}
public function bool IsHacked(BioPawn oPawn)
{
    local SFXModule_GameEffectManager Manager;
    local SFXGameEffect oEffect;
    
    if (oPawn == None)
    {
        return FALSE;
    }
    Manager = oPawn.GetModule(Class'SFXModule_GameEffectManager');
    if (Manager != None)
    {
        foreach Manager.GameEffects(oEffect, )
        {
            if (oEffect.@Class == Class'SFXGameEffect_AIHacking')
            {
                return TRUE;
            }
        }
    }
    return FALSE;
}
public function bool RemoveWeakerHack(BioPawn oPawn, float fNewDuration)
{
    local SFXModule_GameEffectManager Manager;
    local SFXGameEffect oEffect;
    local Name EffectCategory;
    
    if (oPawn == None)
    {
        return TRUE;
    }
    Manager = oPawn.GetModule(Class'SFXModule_GameEffectManager');
    if (Manager == None)
    {
        return TRUE;
    }
    foreach Manager.GameEffects(oEffect, )
    {
        if (oEffect.@Class == Class'SFXGameEffect_AIHacking')
        {
            if (oEffect.Duration - oEffect.CurrentTime < fNewDuration)
            {
                EffectCategory = oEffect.Category;
                break;
            }
            else
            {
                return FALSE;
            }
        }
    }
    Manager.RemoveEffectsByCategory(EffectCategory);
    return TRUE;
}
public function SetupEffect(SFXGameEffect_AIHacking HackingEffect)
{
    HackingEffect.Caster = m_oPawn;
    if (IsEvolvedWithChoice(2))
    {
        HackingEffect.bExplodeOnDeath = TRUE;
    }
}
public function UnHackPreviousTargets()
{
    local Actor oActor;
    local SFXModule_GameEffectManager Manager;
    
    foreach m_oCurrentHackedTargets(oActor, )
    {
        if (oActor != None)
        {
            Manager = oActor.GetModule(Class'SFXModule_GameEffectManager');
            if (Manager != None)
            {
                Manager.RemoveEffectsByCategory(Name);
            }
        }
    }
    m_oCurrentHackedTargets.Length = 0;
}
public final function HackNewRobot(SFXPawn oPawn)
{
    local SFXModule_GameEffectManager Manager;
    local SFXGameEffect_AIHacking HackingEffect;
    local float fHackDuration;
    local SFXGameEffect_IgnorePawn IgnoreEffect;
    
    Manager = oPawn.GetModule(Class'SFXModule_GameEffectManager');
    if (Manager == None)
    {
        return;
    }
    fHackDuration = EffectDuration.CurrentValue * (1.0 - oPawn.PowerControlResistance);
    if (fHackDuration <= float(0))
    {
        return;
    }
    HackingEffect = SFXGameEffect_AIHacking(Manager.CreateEffect(Class'SFXGameEffect_AIHacking', Name, fHackDuration, 1, 1.0, m_oPawn.Controller));
    if (HackingEffect != None)
    {
        SetupEffect(HackingEffect);
        HackingEffect.Power = Self;
        if (IsEvolvedWithChoice(4))
        {
            HackingEffect.CE_TargetCrust = CE_RobotSuperHackTemplate;
        }
        else
        {
            HackingEffect.CE_TargetCrust = CE_RobotHackTemplate;
        }
        HackingEffect.OnApplied();
    }
    IgnoreEffect = SFXGameEffect_IgnorePawn(Manager.CreateEffect(Class'SFXGameEffect_IgnorePawn', Name, TimeHackedRobotIgnored.CurrentValue, 1, 1.0, m_oPawn.Controller));
    if (IgnoreEffect != None)
    {
        IgnoreEffect.bAffectHenchmen = FALSE;
        IgnoreEffect.OnApplied();
    }
    ApplyTemporaryGameEffect(oPawn, Class'SFXGameEffect_IgnorePlayerSquad', fHackDuration, 1.0, m_oPawn.Name, m_oPawn.Controller);
    ApplyTemporaryGameEffect(oPawn, Class'SFXGameEffect_HenchmenIgnorePawn', fHackDuration, 1.0, m_oPawn.Name, m_oPawn.Controller);
    if (IsEvolvedWithChoice(4))
    {
        ApplyTemporaryGameEffect(oPawn, Class'SFXGameEffect_WeaponDamageBonus', fHackDuration, Evolve_BerserkDamageBonus, Name, m_oPawn.Controller);
        ApplyTemporaryGameEffect(oPawn, Class'SFXGameEffect_MovementSpeedBonus', fHackDuration, Evolve_BerserkMoveSpeedBonus, Name, m_oPawn.Controller);
    }
    if (m_oCurrentHackedTargets.Find(oPawn) == -1)
    {
        m_oCurrentHackedTargets.AddItem(oPawn);
    }
    oPawn.PowerControlResistance += (1.0 - oPawn.PowerControlResistance) * 0.5;
    if (oPawn.PowerControlResistance > 0.899999976)
    {
        oPawn.PowerControlResistance = 1.0;
    }
    oPawn.AddPowerAssistEvent(m_oPawn, DisplayName, PowerAssistFullControlValue);
    SFXGRI(oPawn.WorldInfo.GRI).TriggerVocalizationEvent(38, oPawn, None, 0.0);
    if (oPawn.@Class.Name == 'SFXPawn_GethPrime' && oPawn.Squad != None)
    {
        HackGethPrime(oPawn);
    }
    if (ShouldReplicate())
    {
        ReplicatePowerSubsequentImpact(oPawn, , , -1);
    }
}
public final function OnHackedTargetDied(BioPawn oPawn)
{
    local RvrClientEffectInterface.RvrClientEffectTarget TargetInfo;
    
    if (oPawn == None)
    {
        return;
    }
    oPawn.SetHidden(TRUE);
    TargetInfo.Instigator = oPawn;
    Class'RvrClientEffectManager'.static.GetClientEffectManager().PlayOnTarget(ExplosionTemplate, TargetInfo);
    AreaExplosion(oPawn.location, ExplosionRadius.CurrentValue, ExplosionDamage.CurrentValue, Class'SFXDamageType_Power_Ragdoll', ExplosionForce.CurrentValue, ExplosionParameters, 0);
}
public function HackGethPrime(BioPawn oPawn)
{
    local BioAiController oController;
    
    foreach oPawn.Squad.SquadMembers(oController)
    {
        if (oController.Pawn.@Class.Name == 'SFXPawn_GethPrimeTurret' || oController.Pawn.@Class.Name == 'SFXPawn_GethPrimeShieldDrone')
        {
            HackNewRobot(SFXPawn(oController.Pawn));
        }
    }
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    Begin Object Class=BioDynamicAnimSet Name=MY_DYN_HMM_BC_RifleTechTool
        m_nmOrigSetName = 'HMM_BC_RifleTechTool'
        Sequences = (AnimSequence'BIOG_HMM_BC_A.HMM_BC_RifleTechTool_BC_Start', AnimSequence'BIOG_HMM_BC_A.HMM_BC_RifleTechTool_BC_End')
        m_pBioAnimSetData = BioAnimSetData'BIOG_HMM_BC_A.HMM_BC_RifleTechTool_BioAnimSetData'
    End Object
    ExplosionDamage = {
                       DynamicBonuses = (), 
                       RankBonuses[0] = 0.0, 
                       RankBonuses[1] = 0.0, 
                       RankBonuses[2] = 0.0, 
                       RankBonuses[3] = 0.0, 
                       RankBonuses[4] = 0.0, 
                       RankBonuses[5] = 0.0, 
                       BaseValue = 350.0, 
                       CurrentValue = 0.0, 
                       Formula = EPowerDataFormula.Normal
                      }
    ExplosionForce = {
                      DynamicBonuses = (), 
                      RankBonuses[0] = 0.0, 
                      RankBonuses[1] = 0.0, 
                      RankBonuses[2] = 0.0, 
                      RankBonuses[3] = 0.0, 
                      RankBonuses[4] = 0.0, 
                      RankBonuses[5] = 0.0, 
                      BaseValue = 500.0, 
                      CurrentValue = 0.0, 
                      Formula = EPowerDataFormula.Normal
                     }
    ExplosionRadius = {
                       DynamicBonuses = (), 
                       RankBonuses[0] = 0.0, 
                       RankBonuses[1] = 0.0, 
                       RankBonuses[2] = 0.0, 
                       RankBonuses[3] = 0.0, 
                       RankBonuses[4] = 0.0, 
                       RankBonuses[5] = 0.0, 
                       BaseValue = 400.0, 
                       CurrentValue = 0.0, 
                       Formula = EPowerDataFormula.Normal
                      }
    WeaponExplosionDamage = {
                             DynamicBonuses = (), 
                             RankBonuses[0] = 0.0, 
                             RankBonuses[1] = 0.0, 
                             RankBonuses[2] = 0.0, 
                             RankBonuses[3] = 0.0, 
                             RankBonuses[4] = 0.0, 
                             RankBonuses[5] = 0.0, 
                             BaseValue = 150.0, 
                             CurrentValue = 0.0, 
                             Formula = EPowerDataFormula.Normal
                            }
    TimeHackedRobotIgnored = {
                              DynamicBonuses = (), 
                              RankBonuses[0] = 0.0, 
                              RankBonuses[1] = 0.0, 
                              RankBonuses[2] = 0.400000006, 
                              RankBonuses[3] = 0.0, 
                              RankBonuses[4] = 0.0, 
                              RankBonuses[5] = 0.0, 
                              BaseValue = 2.0, 
                              CurrentValue = 0.0, 
                              Formula = EPowerDataFormula.Normal
                             }
    UnaffectedPawns = ('SFXPawn_Husk', 'SFXPawn_Ravager', 'SFXPawn_Brute', 'SFXPawn_Banshee')
    ExplosionParameters = {
                           ConeDirection = {X = 0.0, Y = 0.0, Z = 0.0}, 
                           HitDirectionOffset = {Pitch = 0, Yaw = 0, Roll = 0}, 
                           ConeAngle = 0.0, 
                           ImpactFriends = FALSE, 
                           ImpactDeadPawns = FALSE, 
                           ImpactPlaceables = TRUE, 
                           BlockedByObjects = TRUE, 
                           DistancedSorted = FALSE
                          }
    TechPowerDamageTakenBonusEffectCategory = 'AIHacking_TechPowerDamageTakenBonus'
    WeaponHackDuration = 2.0
    MaxHackedRobots = 2
    Evolve_DurationBonus = 0.5
    Evolve_CooldownBonus = 0.25
    Evolve_BerserkDamageBonus = 1.0
    Evolve_BerserkMoveSpeedBonus = 0.200000003
    Evolve_WeaponExplosionDamageBonus = 0.300000012
    Evolve_TechPowerDamageBonus = 1.0
    Evolve_TechPowerDuration = 10.0
    ExplosionTemplate = RvrClientEffect'BioVFX_Crt_Geth_SiegePulse.VCFX.geth_Emp_Explosion_VCFX'
    CE_RobotHackTemplate = RvrClientEffect'BioVFX_T_TechPowers.01_Hacking.VCFX.Hack_Rbt_Crust_VCFX'
    CE_RobotSuperHackTemplate = RvrClientEffect'BioVFX_T_TechPowers.01_Hacking.VCFX.Super_Hack_Rbt_Crust_VCFX'
    CE_CustomImpactTemplate = RvrClientEffect'BioVFX_T_TechPowers.01_Hacking.VCFX.Hacking_Imp_VCFX'
    DefaultDamageType = Class'SFXDamageType_AIHacking'
    CustomCasterCrustParameters = {X = 1.0, Y = 0.0, Z = 0.0}
    ReleaseEffectBoneName = 'LeftWrist'
    ReleaseTime = 0.200000003
    CastAnimSet = MY_DYN_HMM_BC_RifleTechTool
    CE_CasterCrustTemplate = RvrClientEffectMulti'BioVFX_T_TechPowers._OmniTool.VCFX.OmniTool_LeftFull_Cbt_VCFX_M'
    CE_ReleaseEffectTemplate = RvrClientEffect'BioVFX_T_TechBall.VCFX.Tech_Attack_Muzzle_VCFX'
    ImpactSound = WwiseEvent'Wwise_VFX_Tech.Play_vfx_hacking_imp'
    bCustomCasterCrustParameters = TRUE
    Discipline = EBioCapMode.BIO_CAPMODE_TECH
    CooldownTime = {RankBonuses[1] = 0.25, BaseValue = 8.0, Formula = EPowerDataFormula.DivideByBonusSum}
    HenchmanCooldownTime = {RankBonuses[1] = 0.25, BaseValue = 30.0, Formula = EPowerDataFormula.DivideByBonusSum}
    MaximumRange = {BaseValue = 4000.0}
    ImpactRadius = {RankBonuses[2] = 0.300000012, BaseValue = 250.0}
    MaximumImpactTargets = {BaseValue = 3.0}
    EffectDuration = {BaseValue = 12.0}
    Force = {BaseValue = 50.0}
    Ranks = ({
              Icon = 6, 
              Name = $0, 
              Description = $0, 
              Evolved1Name = $536448, 
              Evolved1Description = $170544, 
              Evolved2Name = $0, 
              Evolved2Description = $0
             }, 
             {
              Icon = 6, 
              Name = $0, 
              Description = $0, 
              Evolved1Name = $170384, 
              Evolved1Description = $155495, 
              Evolved2Name = $0, 
              Evolved2Description = $0
             }, 
             {
              Icon = 6, 
              Name = $0, 
              Description = $0, 
              Evolved1Name = $158722, 
              Evolved1Description = $155497, 
              Evolved2Name = $0, 
              Evolved2Description = $0
             }, 
             {
              Icon = 6, 
              Name = $0, 
              Description = $0, 
              Evolved1Name = $155499, 
              Evolved1Description = $560136, 
              Evolved2Name = $560131, 
              Evolved2Description = $560137
             }, 
             {
              Icon = 6, 
              Name = $0, 
              Description = $0, 
              Evolved1Name = $560132, 
              Evolved1Description = $560138, 
              Evolved2Name = $560133, 
              Evolved2Description = $560139
             }, 
             {
              Icon = 6, 
              Name = $0, 
              Description = $0, 
              Evolved1Name = $560134, 
              Evolved1Description = $560142, 
              Evolved2Name = $560135, 
              Evolved2Description = $560143
             }
            )
    PowerName = 'Hacking'
    PowerCustomActionID = 33
    DisplayName = $536448
    Description = $664221
    Icon = 6
    TalentDescription = $664221
    VocalizationEvent = ESFXVocalizationEventID.SFXVocalizationEvent_Power_AIHack
}