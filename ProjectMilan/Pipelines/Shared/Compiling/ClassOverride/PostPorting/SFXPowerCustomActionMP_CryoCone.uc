// Source: LE3, N7_Sentinel_MP
// Initial decompilation: 9/7/2024 4:01:38 PM
// MILAN CHANGE - UP3
// Detonate Snap Freeze combos at the target and apply the intended combo evolution.
Class SFXPowerCustomActionMP_CryoCone extends SFXPowerCustomAction
    config(Game);

var config PowerData ArmorWeakness;
var config PowerData SpeedReduction;
var Guid GUID_CryoCone;
var config float Evolve_Damage1;
var config float Evolve_Range;
var config float Evolve_DurationBonus;
var config float Evolve_SpeedReductionBonus;
var config float Evolve_DamageTakenBonus;
var config float Evolve_ArmorReductionBonus;
var config float Evolve_Damage2;
var config float Evolve_ComboBonus;
var config float SnapFreezeDelay;
var int RagdollCount;
var RvrClientEffectInterface CE_HalfFrozenTemplate;
var RvrClientEffectInterface CE_CryoCone;
var float VFXDuration;

// MILAN CHANGE - UP3 - Center Snap Freeze combo detonations on the impacted target
public function bool DoPowerDetonatedForActor(Actor oActor, Object.Vector HitLocation, Object.Vector HitNormal, int nImpactCount, bool bFirstTarget, optional SFXProjectile_PowerCustomAction oProjectile)
{
    local BioPawn oPawn;
    local Object.Vector Direction;
    local Object.Vector vForce;
    local float fDamage;
    local float fForce;
    local Class<SFXDamageType> DamageType;
    local Actor.EPowerResistance Resistance;
    local Actor oTargetOverride;
    local bool bHasImpacted;
    
    oPawn = BioPawn(oActor);
    Direction = -HitNormal;
    fForce = GetImpactForce(oActor);
    if (Abs(fForce) > float(0))
    {
        if (oProjectile != None)
        {
            if (bFirstTarget && SFXProjectile_PowerCustomAction_Grenade(oProjectile) == None)
            {
                Direction = Normal(oProjectile.Velocity);
            }
            else
            {
                Direction = Normal(oActor.location - HitLocation);
            }
        }
        else if (!bFirstTarget)
        {
            Direction = Normal(oActor.location - HitLocation);
        }
        Direction = Vector(Rotator(Direction) + DetonationParameters.HitDirectionOffset);
        vForce = Direction * fForce;
    }
    if (oPawn != None)
    {
        oPawn.NotifyImpactedByPower(Self, m_oPawn);
    }
    fDamage = GetImpactDamage(oActor, DamageType);
    if (MaximumRagdollTargets.CurrentValue > float(0) && float(nImpactCount) >= MaximumRagdollTargets.CurrentValue)
    {
        DamageType = GetNonRagdollDamageType();
    }
    Resistance = oActor.GetPowerResistance(m_oPawn, HitLocation, -Direction, fDamage, vForce, DamageType, oTargetOverride);
    if (oTargetOverride != None)
    {
        oActor = oTargetOverride;
    }
    oActor.ImpactWithPower(Resistance, m_oPawn, HitLocation, -Direction, fDamage, vForce, DamageType);
    bHasImpacted = OnImpact(Resistance, oActor, nImpactCount, HitLocation, -Direction);
    if (bHasImpacted)
    {
        PlayImpactEffects(oActor, HitLocation, HitNormal);
        if (!bOverrideComboDetonate)
        {
            CheckForPowerCombo(oActor, Resistance, oActor.location, HitNormal);
        }
    }
    if (ShouldReplicate() == TRUE)
    {
        ReplicateImpact(oPawn, nImpactCount, bFirstTarget, HitLocation, HitNormal, oPawn.CurrentCustomAction);
    }
    return bHasImpacted;
}
// END MILAN CHANGE
public function bool OnImpact(EPowerResistance Resistance, Actor oImpacted, int nPreviouslyImpacted, Vector HitLocation, Vector HitNormal)
{
    local SFXPawn oImpactedPawn;
    local SFXModule_GameEffectManager Manager;
    local bool bForcePartialResistance;
    local SFXGameEffect_PowerCombo ComboEffect;
    local int idx;
    
    oImpactedPawn = SFXPawn(oImpacted);
    if (oImpactedPawn == None)
    {
        return FALSE;
    }
    Manager = oImpactedPawn.GetModule(Class'SFXModule_GameEffectManager');
    if (Manager == None)
    {
        return FALSE;
    }
    if (Resistance == EPowerResistance.Resistance_None)
    {
        if (float(RagdollCount) >= MaximumRagdollTargets.CurrentValue)
        {
            bForcePartialResistance = TRUE;
        }
        else if (m_oPawn != None)
        {
            oImpactedPawn.AddPowerAssistEvent(m_oPawn, DisplayName, PowerAssistFullControlValue);
            if (m_oPawn.Role == ENetRole.ROLE_Authority)
            {
                ApplyFreezeEffect(oImpactedPawn, EffectDuration.CurrentValue, SnapFreezeDelay);
                RagdollCount++;
            }
        }
    }
    if (Resistance == EPowerResistance.Resistance_Partial || bForcePartialResistance == TRUE)
    {
        oImpactedPawn.AddPowerAssistEvent(m_oPawn, DisplayName, PowerAssistPartialControlValue);
        if (m_oPawn.Role == ENetRole.ROLE_Authority)
        {
            ApplySlowdownEffect(oImpactedPawn, EffectDuration.CurrentValue);
        }
    }
    if (Resistance != EPowerResistance.Resistance_Full)
    {
        Manager.RemoveEffectsByTypeAndCategory(Class'SFXGameEffect_ArmorWeakness', Name);
        ApplyTemporaryGameEffect(oImpacted, Class'SFXGameEffect_ArmorWeakness', EffectDuration.CurrentValue, -ArmorWeakness.CurrentValue, Name, m_oPawn.Controller);
        if (IsEvolvedWithChoice(3) == TRUE)
        {
            Manager.RemoveEffectsByTypeAndCategory(Class'SFXGameEffect_DamageTakenBonus', Name);
            Manager.CreateAndApplyEffect(Class'SFXGameEffect_DamageTakenBonus', Name, EffectDuration.CurrentValue, 1, Evolve_DamageTakenBonus, m_oPawn.Controller);
        }
        AddComboEffect(oImpacted, Class'SFXGameEffect_PowerCombo_Cryo', EffectDuration.CurrentValue);
        // MILAN CHANGE - UP3 - Apply rank 6B combo damage and force bonuses to all tech primers
        if (IsEvolvedWithChoice(5))
        {
            for (idx = 0; idx < Manager.GameEffects.Length; idx++)
            {
                ComboEffect = SFXGameEffect_PowerCombo(Manager.GameEffects[idx]);
                if (ComboEffect != None)
                {
                    if (ComboEffect.IsA('SFXGameEffect_PowerCombo_Cryo') || ComboEffect.IsA('SFXGameEffect_PowerCombo_Electric') || ComboEffect.IsA('SFXGameEffect_PowerCombo_Fire'))
                    {
                        ComboEffect.ComboDamage.X *= 1.0 + Evolve_ComboBonus;
                        ComboEffect.ComboDamage.Y *= 1.0 + Evolve_ComboBonus;
                        ComboEffect.ComboForce.X *= 1.0 + Evolve_ComboBonus;
                        ComboEffect.ComboForce.Y *= 1.0 + Evolve_ComboBonus;
                    }
                }
            }
        }
        // END MILAN CHANGE
    }
    return TRUE;
}
public function bool ShouldUsePower(Actor Target, out string sOptionalInfo)
{
    return TRUE;
}
public function ClientDoPowerSubsequentImpact(Actor oActor, optional int CustomActionReactionType, optional float Duration, optional int ImpactCount, optional float Delay, optional bool DoCallback)
{
    switch (ImpactCount)
    {
        case -1:
            ApplyFreezeEffect(BioPawn(oActor), Duration, Delay);
            BioPawn(oActor).ClientPlayAnimatedReaction(CustomActionReactionType);
            break;
        case -2:
            ApplySlowdownEffect(BioPawn(oActor), Duration);
            break;
        default:
            Super.ClientDoPowerSubsequentImpact(oActor, CustomActionReactionType, Duration, ImpactCount, Delay, DoCallback);
            break;
    }
}
public function EvolvePower(EEvolveChoice choice)
{
    Super(SFXPowerCustomActionBase).EvolvePower(choice);
    switch (choice)
    {
        case EEvolveChoice.EvolveChoice1:
            AddEvolvedRankBonus(Damage, Evolve_Damage1);
            break;
        case EEvolveChoice.EvolveChoice2:
            AddEvolvedRankBonus(ImpactRadius, Evolve_Range);
            break;
        case EEvolveChoice.EvolveChoice3:
            AddEvolvedRankBonus(SpeedReduction, Evolve_SpeedReductionBonus);
            AddEvolvedRankBonus(EffectDuration, Evolve_DurationBonus);
            break;
        case EEvolveChoice.EvolveChoice4:
            break;
        case EEvolveChoice.EvolveChoice5:
            AddEvolvedRankBonus(Damage, Evolve_Damage2);
            AddEvolvedRankBonus(ArmorWeakness, Evolve_ArmorReductionBonus);
            break;
        case EEvolveChoice.EvolveChoice6:
            break;
        default:
    }
    RecalculateAllPowerInfo();
}
public function OnPowerDetonated(Vector HitLocation, Vector HitNormal, optional SFXProjectile_PowerCustomAction oProjectile, optional Actor HitActor)
{
    local BioPlayerController PC;
    
    RagdollCount = 0;
    PC = BioPlayerController(m_oPawn.Controller);
    if (PC != None)
    {
        DetonationParameters.ConeDirection = Vector(PC.Rotation);
    }
    else
    {
        DetonationParameters.ConeDirection = Vector(m_oPawn.Rotation);
    }
    HitNormal = -DetonationParameters.ConeDirection;
    HitLocation = m_oPawn.location;
    Super.OnPowerDetonated(HitLocation, HitNormal, oProjectile, HitActor);
}
public function PopulatePowerStatBarEvolves()
{
    PowerStatBars.Length = 5;
    PowerStatBars[0].Data = SFXPawn_Henchman(m_oPawn) == None ? CooldownTime : HenchmanCooldownTime;
    PowerStatBars[0].srDisplayTotalToken = StatBarToken_Time;
    PowerStatBars[0].srStatBarDisplayTitle = StatBarTitle_Cooldown;
    PowerStatBars[1].Data = Damage;
    PowerStatBars[1].srDisplayTotalToken = StatBarToken_RawValue;
    PowerStatBars[1].srStatBarDisplayTitle = StatBarTitle_Damage;
    PowerStatBars[1].EvolvedBonuses[0] = Evolve_Damage1;
    PowerStatBars[1].EvolvedBonuses[4] = Evolve_Damage2;
    PowerStatBars[2].Data = ImpactRadius;
    PowerStatBars[2].Formula = EPowerStatBarFormula.EPowerStatBarFormula_Distance;
    PowerStatBars[2].srDisplayTotalToken = StatBarToken_Distance;
    PowerStatBars[2].srStatBarDisplayTitle = StatBarTitle_Range;
    PowerStatBars[2].EvolvedBonuses[1] = Evolve_Range;
    PowerStatBars[3].Data = EffectDuration;
    PowerStatBars[3].srDisplayTotalToken = StatBarToken_Time;
    PowerStatBars[3].srStatBarDisplayTitle = StatBarTitle_FreezeDuration;
    PowerStatBars[3].EvolvedBonuses[2] = Evolve_DurationBonus;
    PowerStatBars[4].Data = SpeedReduction;
    PowerStatBars[4].Formula = EPowerStatBarFormula.EPowerStatBarFormula_Percent;
    PowerStatBars[4].srDisplayTotalToken = StatBarToken_NegativePercent;
    PowerStatBars[4].srStatBarDisplayTitle = $700193;
    PowerStatBars[4].EvolvedBonuses[2] = Evolve_SpeedReductionBonus;
}
public function RecalculateAllPowerData(optional bool bReset = FALSE)
{
    Super(SFXPowerCustomActionBase).RecalculateAllPowerData(bReset);
    RecalculatePowerData(ArmorWeakness, bReset);
    RecalculatePowerData(SpeedReduction, bReset);
}
public function StartPower()
{
    local RvrClientEffectTarget CETarget;
    
    Super.StartPower();
    StopCryoCone();
    CETarget.Instigator = m_oPawn;
    GUID_CryoCone = Class'RvrClientEffectManager'.static.GetClientEffectManager().StartOnTarget(CE_CryoCone, CETarget);
    if (m_oPawn != None)
    {
        m_oPawn.SetTimer(VFXDuration, FALSE, 'StopCryoCone', Self);
    }
}
public final function ApplyFreezeEffect(BioPawn Victim, float Duration, float Delay)
{
    local SFXModule_GameEffectManager Manager;
    local SFXGameEffect_CryoConeFreeze FreezeEffect;
    
    if (Victim != None)
    {
        Manager = Victim.GetModule(Class'SFXModule_GameEffectManager');
        if (Victim.Role != ENetRole.ROLE_Authority)
        {
            Manager.RemoveEffectsByType(Class'SFXGameEffect_DelayedCryoFreeze');
            Manager.RemoveEffectsByType(Class'SFXGameEffect_CryoFreeze');
            Manager.RemoveEffectsByType(Class'SFXGameEffect_CryoConeFreeze');
        }
        if (Manager != None && Manager.HasEffectOfType(Class'SFXGameEffect_DelayedCryoFreeze') == FALSE && Manager.HasEffectOfType(Class'SFXGameEffect_CryoFreeze') == FALSE && Manager.HasEffectOfType(Class'SFXGameEffect_CryoConeFreeze') == FALSE)
        {
            FreezeEffect = SFXGameEffect_CryoConeFreeze(Manager.CreateEffect(Class'SFXGameEffect_CryoConeFreeze', Name, EffectDuration.CurrentValue, 1, 0.0, m_oPawn.Controller));
            if (FreezeEffect != None)
            {
                FreezeEffect.OnApplied();
                if (ShouldReplicate())
                {
                    ReplicatePowerSubsequentImpact(Victim, , Duration, -1, Delay);
                }
            }
        }
    }
}
public final function ApplySlowdownEffect(BioPawn oPawn, float Duration)
{
    local SFXModule_GameEffectManager Manager;
    local RvrClientEffectTarget TargetInfo;
    local SFXGameEffect_MovementSpeedBonus SpeedEffect;
    local SFXGameEffect Effect;
    
    if (oPawn != None)
    {
        Manager = oPawn.GetModule(Class'SFXModule_GameEffectManager');
        if (Manager != None)
        {
            foreach Manager.GameEffects(Effect, )
            {
                SpeedEffect = SFXGameEffect_MovementSpeedBonus(Effect);
                if (SpeedEffect != None && SpeedEffect.EffectValue < float(0))
                {
                    if (SpeedEffect.EffectValue <= -SpeedReduction.CurrentValue)
                    {
                        return;
                    }
                    else
                    {
                        SpeedEffect.CurrentTime = SpeedEffect.Duration + float(1);
                        SpeedEffect.DurationType = EDurationType.DurationType_Temporary;
                    }
                }
            }
            Manager.CreateAndApplyEffect(Class'SFXGameEffect_MovementSpeedBonus', Name, Duration, 1, -SpeedReduction.CurrentValue, m_oPawn.Controller);
            TargetInfo.Instigator = oPawn;
            TargetInfo.SpawnValue.X = Duration;
            Class'RvrClientEffectManager'.static.GetClientEffectManager().PlayOnTarget(CE_HalfFrozenTemplate, TargetInfo);
            if (ShouldReplicate())
            {
                ReplicatePowerSubsequentImpact(oPawn, , Duration, -2);
            }
        }
    }
}
public function StopCryoCone()
{
    if (m_oPawn != None)
    {
        m_oPawn.ClearTimer('StopCryoCone', Self);
    }
    Class'RvrClientEffectManager'.static.GetClientEffectManager().Stop(CE_CryoCone, GUID_CryoCone, TRUE);
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    Begin Object Class=BioDynamicAnimSet Name=MY_DYN_HMM_CB_Sentinel_CON_MP3
        m_nmOrigSetName = 'HMM_CB_Sentinel_CON_MP3'
        Sequences = (AnimSequence'BIOG_HMM_CB_CON_MP3.HMM_CB_Sentinel_CON_MP3_CB_Sentinel_ConeOfColdness')
        m_pBioAnimSetData = BioAnimSetData'BIOG_HMM_CB_CON_MP3.HMM_CB_Sentinel_CON_MP3_BioAnimSetData'
    End Object
    ArmorWeakness = {
                     DynamicBonuses = (), 
                     RankBonuses[0] = 0.0, 
                     RankBonuses[1] = 0.0, 
                     RankBonuses[2] = 0.0, 
                     RankBonuses[3] = 0.0, 
                     RankBonuses[4] = 0.0, 
                     RankBonuses[5] = 0.0, 
                     BaseValue = 0.25, 
                     CurrentValue = 0.0, 
                     Formula = EPowerDataFormula.BonusIsHardValue
                    }
    SpeedReduction = {
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
    Evolve_Damage1 = 0.300000012
    Evolve_Range = 0.5
    Evolve_DurationBonus = 0.5
    Evolve_SpeedReductionBonus = 0.200000003
    Evolve_DamageTakenBonus = 0.100000001
    Evolve_ArmorReductionBonus = 0.25
    Evolve_Damage2 = 0.400000006
    Evolve_ComboBonus = 1.0
    CE_HalfFrozenTemplate = RvrClientEffect'BioVFX_C_CryoBlaster.VCFX.Cryo_Half_Frozen_VCFX'
    CE_CryoCone = RvrClientEffectMulti'BioVFX_MP3_Cone_Cold.VCFX.Cone_Cold_Whole_VCFX'
    VFXDuration = 2.0
    ComboDetonators = (Class'SFXGameEffect_PowerCombo_Electric', Class'SFXGameEffect_PowerCombo_Fire', Class'SFXGameEffect_PowerCombo_Cryo')
    BS_StartCastAnimation = {
                             AnimName = ('None', 
                                         'CB_Sentinel_ConeOfColdness', 
                                         'CB_Sentinel_ConeOfColdness', 
                                         'CB_Sentinel_ConeOfColdness', 
                                         'CB_Sentinel_ConeOfColdness', 
                                         'CB_Sentinel_ConeOfColdness', 
                                         'CB_Sentinel_ConeOfColdness', 
                                         'CB_Sentinel_ConeOfColdness', 
                                         'None', 
                                         'None', 
                                         'None', 
                                         'CB_Sentinel_ConeOfColdness'
                                        )
                            }
    DefaultDamageType = Class'SFXDamageType_CryoCone'
    NonRagdollDamageType = Class'SFXDamageType_CryoCone'
    DetonationRumbleClass = Class'SFXRumble_Power_HeavyImpact'
    DetonationScreenShakeClass = Class'SFXShake_Power_HeavyImpact'
    DetonationParameters = {ConeAngle = 90.0, BlockedByObjects = FALSE}
    ReleaseTime = 0.300000012
    CastAnimSet = MY_DYN_HMM_CB_Sentinel_CON_MP3
    CastSound = WwiseEvent'Wwise_Power_DLC_CCone.Play_power_DLC_P_cryocone_cast'
    HenchmanCastSound = WwiseEvent'Wwise_Power_DLC_CCone.Play_power_DLC_NP_cryocone_cast'
    bPlayEndCastAnim = FALSE
    Discipline = EBioCapMode.BIO_CAPMODE_TECH
    CooldownTime = {RankBonuses[1] = 0.25, BaseValue = 8.0, Formula = EPowerDataFormula.DivideByBonusSum}
    MaximumRange = {BaseValue = 6000.0}
    ImpactRadius = {BaseValue = 1000.0}
    MaximumImpactTargets = {BaseValue = 3.0}
    MaximumRagdollTargets = {BaseValue = 1.0}
    EffectDuration = {BaseValue = 6.0}
    Damage = {RankBonuses[2] = 0.200000003, BaseValue = 250.0}
    Force = {BaseValue = 250.0}
    Ranks = ({
              Icon = 2, 
              Name = $0, 
              Description = $0, 
              Evolved1Name = $739807, 
              Evolved1Description = $755974, 
              Evolved2Name = $0, 
              Evolved2Description = $0
             }, 
             {
              Icon = 2, 
              Name = $0, 
              Description = $0, 
              Evolved1Name = $314059, 
              Evolved1Description = $501588, 
              Evolved2Name = $0, 
              Evolved2Description = $0
             }, 
             {
              Icon = 2, 
              Name = $0, 
              Description = $0, 
              Evolved1Name = $731541, 
              Evolved1Description = $731542, 
              Evolved2Name = $0, 
              Evolved2Description = $0
             }, 
             {
              Icon = 2, 
              Name = $0, 
              Description = $0, 
              Evolved1Name = $731541, 
              Evolved1Description = $734238, 
              Evolved2Name = $501593, 
              Evolved2Description = $734237
             }, 
             {
              Icon = 2, 
              Name = $0, 
              Description = $0, 
              Evolved1Name = $739897, 
              Evolved1Description = $739899, 
              Evolved2Name = $313987, 
              Evolved2Description = $558684
             }, 
             {
              Icon = 2, 
              Name = $0, 
              Description = $0, 
              Evolved1Name = $739900, 
              Evolved1Description = $739901, 
              Evolved2Name = $739903, 
              Evolved2Description = $739904
             }
            )
    PowerName = 'CryoCone'
    PowerCustomActionID = 6
    DisplayName = $739807
    Description = $739895
    Icon = 2
    IconResource = GFxMovieInfo'GUI_SF_CryoCone.CryoCone'
    TalentDescription = $739895
    bBreakFromCover = TRUE
    bHideWeapon = TRUE
}
