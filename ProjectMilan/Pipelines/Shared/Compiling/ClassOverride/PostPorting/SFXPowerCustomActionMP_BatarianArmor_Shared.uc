// Source: LE3, Batarian_Vanguard_MP
// Initial decompilation: 9/7/2024 5:11:57 PM
// MILAN CHANGE - UP3
// Preserve Blade Armor reflection damage across difficulty levels
Class SFXPowerCustomActionMP_BatarianArmor_Shared extends SFXPowerCustomAction
    config(Game);

var config PowerData DamageReduction;
var config PowerData EncumbrancePenalty;
var config PowerData MeleeDamageBonus;
var config PowerData ThornsDamage;
var config float ThornsDamageCap;
var config float DamageToForceMultiplier;
var config float Evolve_DamageReductionBonus;
var config float Evolve_MeleeDamageBonus;
var config float Evolve_ShieldRegenBonus;
var config float Evolve_ThornsDamageBonus;
var config float Evolve_EncumbranceBonus;
var config float Evolve_DamageReductionBonus2;
var stringref srArmorActive;
var RvrClientEffectInterface CE_BladesOn;
var RvrClientEffectInterface CE_BladesOff;
var WwiseEvent WWise_PlayerCast_On;
var WwiseEvent WWise_NPCCast_On;
var WwiseEvent WWise_PlayerCast_Off;
var WwiseEvent WWise_NPCCast_Off;
var bool bArmorDestroyed;

public function bool OnImpact(EPowerResistance Resistance, Actor oImpacted, int nPreviouslyImpacted, Vector HitLocation, Vector HitNormal)
{
    local BioPawn oPawn;
    local SFXModule_GameEffectManager Manager;
    
    if (m_oPawn == None || m_oPawn.Role == ENetRole.ROLE_SimulatedProxy)
    {
        return TRUE;
    }
    oPawn = BioPawn(oImpacted);
    if (oPawn != None)
    {
        Manager = oPawn.GetModule(Class'SFXModule_GameEffectManager');
        if (Manager != None)
        {
            if (Manager.HasEffectOfTypeAndCategory(Class'SFXGameEffect_BatarianArmor_Shared', Name))
            {
                RemoveArmor(FALSE);
                if (ShouldReplicate())
                {
                    ReplicatePowerSubsequentImpact(m_oPawn, , , -2);
                }
            }
            else
            {
                ApplyArmor();
                if (ShouldReplicate())
                {
                    ReplicatePowerSubsequentImpact(m_oPawn, , , -1);
                }
            }
        }
    }
    return TRUE;
}
public event function bool ShouldUsePower(Actor Target, out string sOptionalInfo)
{
    local SFXModule_GameEffectManager Manager;
    
    Manager = m_oPawn.GetModule(Class'SFXModule_GameEffectManager');
    if (Manager != None && Manager.HasEffectOfType(Class'SFXGameEffect_BatarianArmor_Shared'))
    {
        sOptionalInfo = string(srArmorActive);
        return FALSE;
    }
    return TRUE;
}
public function ClientDoPowerSubsequentImpact(Actor oActor, optional int CustomActionReactionType, optional float Duration, optional int ImpactCount, optional float Delay, optional bool DoCallback)
{
    switch (ImpactCount)
    {
        case -1:
            if (m_oPawn.Role != ENetRole.ROLE_AutonomousProxy)
            {
                ApplyArmor();
            }
            else
            {
                TryApplyArmor();
            }
            break;
        case -2:
            ClientResetArmorHealth();
            if (m_oPawn.Role != ENetRole.ROLE_AutonomousProxy)
            {
                RemoveArmor(TRUE);
            }
            else
            {
                RemoveArmor(FALSE);
            }
            break;
        default:
    }
}
public function EvolvePower(EEvolveChoice choice)
{
    Super(SFXPowerCustomActionBase).EvolvePower(choice);
    switch (choice)
    {
        case EEvolveChoice.EvolveChoice1:
            AddEvolvedRankBonus(DamageReduction, Evolve_DamageReductionBonus);
            break;
        case EEvolveChoice.EvolveChoice2:
            AddEvolvedRankBonus(MeleeDamageBonus, Evolve_MeleeDamageBonus);
            break;
        case EEvolveChoice.EvolveChoice3:
            break;
        case EEvolveChoice.EvolveChoice4:
            AddEvolvedRankBonus(ThornsDamage, Evolve_ThornsDamageBonus);
            break;
        case EEvolveChoice.EvolveChoice5:
            AddEvolvedRankBonus(EncumbrancePenalty, -Evolve_EncumbranceBonus);
            break;
        case EEvolveChoice.EvolveChoice6:
            AddEvolvedRankBonus(DamageReduction, Evolve_DamageReductionBonus2);
            break;
        default:
    }
    RecalculateAllPowerData();
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
    PowerStatBars[1].EvolvedBonuses[0] = Evolve_DamageReductionBonus;
    PowerStatBars[1].EvolvedBonuses[5] = Evolve_DamageReductionBonus2;
    PowerStatBars[2].Data = MeleeDamageBonus;
    PowerStatBars[2].Formula = EPowerStatBarFormula.EPowerStatBarFormula_Percent;
    PowerStatBars[2].srDisplayTotalToken = StatBarToken_Percent;
    PowerStatBars[2].srStatBarDisplayTitle = $694502;
    PowerStatBars[2].EvolvedBonuses[1] = Evolve_MeleeDamageBonus;
    PowerStatBars[3].Data = ThornsDamage;
    PowerStatBars[3].Formula = EPowerStatBarFormula.EPowerStatBarFormula_Percent;
    PowerStatBars[3].srDisplayTotalToken = StatBarToken_Percent;
    PowerStatBars[3].srStatBarDisplayTitle = $727722;
    PowerStatBars[3].EvolvedBonuses[3] = Evolve_ThornsDamageBonus;
}
public function RecalculateAllPowerData(optional bool bReset = FALSE)
{
    Super(SFXPowerCustomActionBase).RecalculateAllPowerData(bReset);
    RecalculatePowerData(DamageReduction, bReset);
    RecalculatePowerData(EncumbrancePenalty, bReset);
    RecalculatePowerData(MeleeDamageBonus, bReset);
    RecalculatePowerData(ThornsDamage, bReset);
}
public function RemoveArmor(bool bForced)
{
    local SFXModule_GameEffectManager Manager;
    local SFXGameEffect_BatarianArmor_Shared ArmorEffect;
    local bool bHasEffectArmor;
    local RvrClientEffectTarget CETarget;
    local BioPlayerController PC;
    
    Manager = m_oPawn.GetModule(Class'SFXModule_GameEffectManager');
    if (Manager != None)
    {
        PC = BioPlayerController(m_oPawn.Controller);
        if (PC != None && PC.IsLocalPlayerController())
        {
            m_oPawn.PlaySound(WWise_PlayerCast_Off, TRUE);
        }
        else
        {
            m_oPawn.PlaySound(WWise_NPCCast_Off, TRUE);
        }
        ArmorEffect = SFXGameEffect_BatarianArmor_Shared(Manager.GetFirstEffectOfType(Class'SFXGameEffect_BatarianArmor_Shared'));
        if (ArmorEffect != None)
        {
            bHasEffectArmor = ArmorEffect.DurationType == EDurationType.DurationType_Permanent;
        }
        if (bForced && !bHasEffectArmor)
        {
            Manager.CreateAndApplyEffect(Class'SFXGameEffect_BatarianArmor_Shared', Name, 0.0, 2, -DamageReduction.CurrentValue, m_oPawn.Controller);
            bHasEffectArmor = TRUE;
        }
        if (bHasEffectArmor)
        {
            Manager.RemoveEffectsByCategory(Name);
            bArmorDestroyed = TRUE;
        }
        CETarget.Instigator = m_oPawn;
        Class'RvrClientEffectManager'.static.GetClientEffectManager().PlayOnTarget(CE_BladesOff, CETarget);
    }
}
public function TryApplyArmor()
{
    local SFXModule_GameEffectManager Manager;
    
    Manager = m_oPawn.GetModule(Class'SFXModule_GameEffectManager');
    if (Manager != None && !Manager.HasEffectOfTypeAndCategory(Class'SFXGameEffect_BatarianArmor_Shared', Name))
    {
        ApplyArmor();
    }
}
public function ClientResetArmorHealth()
{
    local SFXModule_Armour ArmourMod;
    local int ArmourIndex;
    
    if (m_oPawn == None)
    {
        return;
    }
    ArmourMod = m_oPawn.GetModule(Class'SFXModule_Armour');
    if (ArmourMod != None)
    {
        for (ArmourIndex = 0; ArmourIndex < 12; ArmourIndex++)
        {
            if (ArmourMod.ActiveArmour[ArmourIndex] != None)
            {
                ArmourMod.ActiveArmour[ArmourIndex].CurrentHealth = 0.0;
            }
        }
    }
}
public final function OnOwnerMeleed(float DamageAmount, Controller EventInstigator, Vector HitLocation, Vector Momentum, Class<DamageType> DamageType, optional TraceHitInfo HitInfo, optional Actor DamageCauser)
{
    local Pawn DamageCauserPawn;
    local BioPawn ImpactedPawn;
    local SFXModule_GameEffectManager Manager;
    local Actor oTargetOverride;
    local EPowerResistance Resistance;
    local Vector vHitNormal;
    local Vector vForce;
    
    DamageCauserPawn = Class'BioPawn'.static.FindAttackingPawn(EventInstigator, DamageCauser);
    if (DamageCauserPawn != None && m_oPawn.IsHostile(DamageCauserPawn))
    {
        Manager = m_oPawn.GetModule(Class'SFXModule_GameEffectManager');
        if (Manager != None && Manager.HasEffectOfTypeAndCategory(Class'SFXGameEffect_BatarianArmor_Shared', Name))
        {
            // MILAN CHANGE - UP3 - Remove difficulty compensation from Blade Armor reflection
            DamageAmount = FClamp(DamageAmount * ThornsDamage.CurrentValue, 0.0, ThornsDamageCap);
            // END MILAN CHANGE
            vHitNormal = Normal(m_oPawn.location - DamageCauserPawn.location);
            vForce = -vHitNormal * DamageAmount * DamageToForceMultiplier;
            Resistance = DamageCauserPawn.GetPowerResistance(m_oPawn, DamageCauserPawn.location, vHitNormal, DamageAmount, vForce, DefaultDamageType, oTargetOverride);
            if (Resistance == EPowerResistance.Resistance_Full)
            {
                return;
            }
            if (oTargetOverride != None)
            {
                DamageCauserPawn = Pawn(oTargetOverride);
            }
            if (DamageCauserPawn != None)
            {
                if (DamageCauserPawn.ImpactWithPower(Resistance, m_oPawn, DamageCauserPawn.location, vHitNormal, DamageAmount, vForce, DefaultDamageType))
                {
                    ImpactedPawn = BioPawn(DamageCauserPawn);
                    if (ImpactedPawn != None)
                    {
                        ImpactedPawn.ReplicateAnimatedReaction(ImpactedPawn.CurrentCustomAction);
                    }
                }
            }
        }
    }
}
public function ApplyArmor()
{
    local SFXModule_GameEffectManager Manager;
    local RvrClientEffectTarget CETarget;
    local BioPlayerController PC;
    
    Manager = m_oPawn.GetModule(Class'SFXModule_GameEffectManager');
    if (Manager != None)
    {
        bArmorDestroyed = FALSE;
        PC = BioPlayerController(m_oPawn.Controller);
        if (PC != None && PC.IsLocalPlayerController())
        {
            m_oPawn.PlaySound(WWise_PlayerCast_On, TRUE);
        }
        else
        {
            m_oPawn.PlaySound(WWise_NPCCast_On, TRUE);
        }
        Manager.CreateAndApplyEffect(Class'SFXGameEffect_BatarianArmor_Shared', Name, 0.0, 2, -DamageReduction.CurrentValue, m_oPawn.Controller);
        Manager.CreateAndApplyEffect(Class'SFXGameEffect_MeleeDamageBonus', Name, 0.0, 2, MeleeDamageBonus.CurrentValue, m_oPawn.Controller);
        m_oPawn.PowerManager.ApplyPowerBonus(m_oPawn, 'CooldownTime', -EncumbrancePenalty.CurrentValue, 0.0, Name, Self, FALSE, TRUE, TRUE, TRUE, FALSE);
        if (IsEvolvedWithChoice(2))
        {
            ApplyPermanentGameEffect(m_oPawn, Class'SFXGameEffect_ShieldRegenBonus', -Evolve_ShieldRegenBonus, Name, m_oPawn.Controller);
        }
        CETarget.Instigator = m_oPawn;
        Class'RvrClientEffectManager'.static.GetClientEffectManager().PlayOnTarget(CE_BladesOn, CETarget);
    }
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    Begin Object Class=BioDynamicAnimSet Name=MY_DYN_HMM_BC_RifleTechToolActivate
        m_nmOrigSetName = 'HMM_BC_RifleTechToolActivate'
        Sequences = (AnimSequence'BIOG_HMM_BC_A.HMM_BC_RifleTechToolActivate_BC_Start', AnimSequence'BIOG_HMM_BC_A.HMM_BC_RifleTechToolActivate_BC_Start_Cover_Neutral', AnimSequence'BIOG_HMM_BC_A.HMM_BC_RifleTechToolActivate_BC_Start_Cover_Neutral_Mid', AnimSequence'BIOG_HMM_BC_A.HMM_BC_RifleTechToolActivate_BC_End', AnimSequence'BIOG_HMM_BC_A.HMM_BC_RifleTechToolActivate_BC_End_Cover_Neutral', AnimSequence'BIOG_HMM_BC_A.HMM_BC_RifleTechToolActivate_BC_End_Cover_Neutral_Mid')
        m_pBioAnimSetData = BioAnimSetData'BIOG_HMM_BC_A.HMM_BC_RifleTechToolActivate_BioAnimSetData'
    End Object
    DamageReduction = {
                       DynamicBonuses = (), 
                       RankBonuses[0] = 0.0, 
                       RankBonuses[1] = 0.0, 
                       RankBonuses[2] = 0.0, 
                       RankBonuses[3] = 0.0, 
                       RankBonuses[4] = 0.0, 
                       RankBonuses[5] = 0.0, 
                       BaseValue = 0.150000006, 
                       CurrentValue = 0.0, 
                       Formula = EPowerDataFormula.BonusIsHardValue
                      }
    EncumbrancePenalty = {
                          DynamicBonuses = (), 
                          RankBonuses[0] = 0.0, 
                          RankBonuses[1] = 0.0, 
                          RankBonuses[2] = 0.0, 
                          RankBonuses[3] = 0.0, 
                          RankBonuses[4] = 0.0, 
                          RankBonuses[5] = 0.0, 
                          BaseValue = 0.800000012, 
                          CurrentValue = 0.0, 
                          Formula = EPowerDataFormula.BonusIsHardValue
                         }
    MeleeDamageBonus = {
                        DynamicBonuses = (), 
                        RankBonuses[0] = 0.0, 
                        RankBonuses[1] = 0.0, 
                        RankBonuses[2] = 0.100000001, 
                        RankBonuses[3] = 0.0, 
                        RankBonuses[4] = 0.0, 
                        RankBonuses[5] = 0.0, 
                        BaseValue = 0.150000006, 
                        CurrentValue = 0.0, 
                        Formula = EPowerDataFormula.BonusIsHardValue
                       }
    ThornsDamage = {
                    DynamicBonuses = (), 
                    RankBonuses[0] = 0.0, 
                    RankBonuses[1] = 0.0, 
                    RankBonuses[2] = 0.0, 
                    RankBonuses[3] = 0.0, 
                    RankBonuses[4] = 0.0, 
                    RankBonuses[5] = 0.0, 
                    BaseValue = 0.75, 
                    CurrentValue = 0.0, 
                    Formula = EPowerDataFormula.BonusIsHardValue
                   }
    ThornsDamageCap = 1000.0
    DamageToForceMultiplier = 2.0
    Evolve_DamageReductionBonus = 0.0500000007
    Evolve_MeleeDamageBonus = 0.150000006
    Evolve_ShieldRegenBonus = 0.150000006
    Evolve_ThornsDamageBonus = 0.75
    Evolve_EncumbranceBonus = 0.300000012
    Evolve_DamageReductionBonus2 = 0.100000001
    srArmorActive = $727713
    CE_BladesOn = RvrClientEffect'BioVFX_DLC_MP1_Bat_2.VCFX.BatSpikeArmor_Spawn_VCFX'
    CE_BladesOff = RvrClientEffect'BioVFX_DLC_MP1_Bat_2.VCFX.BatSpikeArmor_Deactivate_VCFX'
    WWise_PlayerCast_On = WwiseEvent'Wwise_Power_DLC_BatarianArmor.Play_power_DLC_P_baterianarmor_cast'
    WWise_NPCCast_On = WwiseEvent'Wwise_Power_DLC_BatarianArmor.Play_power_DLC_NP_baterianarmor_cast'
    WWise_PlayerCast_Off = WwiseEvent'Wwise_Power_DLC_BatarianArmor.Play_power_DLC_P_baterianarmor_off'
    WWise_NPCCast_Off = WwiseEvent'Wwise_Power_DLC_BatarianArmor.Play_power_DLC_NP_baterianarmor_off'
    DefaultDamageType = Class'SFXDamageType_BatarianArmorThorns_Shared'
    CustomCasterCrustParameters = {X = 1.5, Y = 0.0, Z = 0.0}
    CastAnimSet = MY_DYN_HMM_BC_RifleTechToolActivate
    CE_CasterCrustTemplate = RvrClientEffect'BioVFX_T_TechPowers._OmniTool.VCFX.OmniTool_Arm_Left_VCFX'
    LeanOutToCast = FALSE
    bCustomCasterCrustParameters = TRUE
    Discipline = EBioCapMode.BIO_CAPMODE_TECH
    CooldownTime = {RankBonuses[1] = 0.25, BaseValue = 3.0, Formula = EPowerDataFormula.DivideByBonusSum}
    Ranks = ({
              Icon = 2, 
              Name = $0, 
              Description = $0, 
              Evolved1Name = $727710, 
              Evolved1Description = $727712, 
              Evolved2Name = $0, 
              Evolved2Description = $0
             }, 
             {
              Icon = 2, 
              Name = $0, 
              Description = $0, 
              Evolved1Name = $314039, 
              Evolved1Description = $727714, 
              Evolved2Name = $0, 
              Evolved2Description = $0
             }, 
             {
              Icon = 2, 
              Name = $0, 
              Description = $0, 
              Evolved1Name = $314040, 
              Evolved1Description = $727715, 
              Evolved2Name = $0, 
              Evolved2Description = $0
             }, 
             {
              Icon = 2, 
              Name = $0, 
              Description = $0, 
              Evolved1Name = $338776, 
              Evolved1Description = $727717, 
              Evolved2Name = $727719, 
              Evolved2Description = $727718
             }, 
             {
              Icon = 2, 
              Name = $0, 
              Description = $0, 
              Evolved1Name = $545543, 
              Evolved1Description = $545556, 
              Evolved2Name = $727720, 
              Evolved2Description = $727721
             }, 
             {
              Icon = 2, 
              Name = $0, 
              Description = $0, 
              Evolved1Name = $589474, 
              Evolved1Description = $589475, 
              Evolved2Name = $590037, 
              Evolved2Description = $590038
             }
            )
    PowerName = 'BatarianArmor'
    PowerCustomActionID = 38
    DisplayName = $727710
    Description = $727711
    Icon = 2
    IconResource = GFxMovieInfo'GUI_SF_BatarianArmor.BatarianArmor'
    TalentDescription = $727711
    PowerType = EPowerType.PowerType_Buff
    HenchmanPowerType = EPowerType.PowerType_Buff
}
