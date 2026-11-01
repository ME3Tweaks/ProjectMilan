// Source: LE3, Vorcha_Engineer_MP
// Initial decompilation: 9/7/2024 5:11:04 PM
// MILAN CHANGE - UP3
// Preserve Submission Net damage per second with duration bonuses
Class SFXPowerCustomActionMP_BatarianNet_Shared extends SFXPowerCustomAction
    config(Game);

var config PowerData DoTDamage;
var config PowerData IncapacitateDuration;
var config PowerData Evolve_AoEPulseDamage;
var config PowerData Evolve_SlowTargetDuration;
var clearcrosslevel BioPawn LastTarget;
var config float IncapacitateResistThreshold;
var config float Evolve_DamageBonus;
var config float Evolve_IncapacitateBonus;
var config float Evolve_DamageBonus2;
var config float Evolve_SlowTargetAmount;
var config float Evolve_RechargeSpeedBonus;
var config float Evolve_ShieldDamageBonus;
var config float Evolve_AoEPulseFrequency;
var config float Evolve_AoEPulseRange;
var ParticleSystem PS_ImpactWall;

public function bool OnImpact(EPowerResistance Resistance, Actor oImpacted, int nPreviouslyImpacted, Vector HitLocation, Vector HitNormal)
{
    local SFXPawn oPawn;
    local SFXModule_GameEffectManager Manager;
    local SFXGameEffect_DamageOverTime DamageEffect;
    local SFXGameEffect_MovementSpeedBonus SpeedEffect;
    local SFXGameEffect Effect;
    local bool bApplySlow;
    local float fDuration;
    
    oPawn = SFXPawn(oImpacted);
    if (oPawn == None || Resistance == EPowerResistance.Resistance_Full)
    {
        return FALSE;
    }
    Manager = oPawn.GetModule(Class'SFXModule_GameEffectManager');
    if (Manager == None)
    {
        return FALSE;
    }
    fDuration = EffectDuration.CurrentValue;
    if (!oPawn.HasResistance(3) && oPawn.bCanRagdoll && oPawn.bAffectedByRagdollPowers)
    {
        fDuration = EffectDuration.CurrentValue * (1.0 - oPawn.PowerControlResistance);
        if (fDuration > float(0) && m_oPawn.Role == ENetRole.ROLE_Authority)
        {
            PutInNet(oPawn, fDuration);
        }
    }
    else if (Manager != None)
    {
        bApplySlow = TRUE;
        foreach Manager.GameEffects(Effect, )
        {
            SpeedEffect = SFXGameEffect_MovementSpeedBonus(Effect);
            if (SpeedEffect != None && SpeedEffect.EffectValue < float(0))
            {
                if (SpeedEffect.EffectValue <= -Evolve_SlowTargetAmount)
                {
                    bApplySlow = FALSE;
                    break;
                }
                else
                {
                    SpeedEffect.CurrentTime = SpeedEffect.Duration + float(1);
                    SpeedEffect.DurationType = EDurationType.DurationType_Temporary;
                }
            }
        }
        if (bApplySlow)
        {
            Manager.CreateAndApplyEffect(Class'SFXGameEffect_MovementSpeedBonus', Name, Evolve_SlowTargetDuration.CurrentValue, 1, -Evolve_SlowTargetAmount, m_oPawn.Controller);
        }
    }
    // MILAN CHANGE - UP3 - Preserve Submission Net DPS when duration increases
    DamageEffect = SFXGameEffect_DamageOverTime(Manager.CreateEffect(Class'SFXGameEffect_DamageOverTime', Name, EffectDuration.CurrentValue, 1, DoTDamage.CurrentValue / EffectDuration.BaseValue, m_oPawn.Controller, m_oPawn));
    // END MILAN CHANGE
    if (DamageEffect != None)
    {
        DamageEffect.DamageType = IsEvolvedWithChoice(4) ? Class'SFXDamageType_BatarianNet_Shields_Shared' : Class'SFXDamageType_BatarianNet_Shared';
        DamageEffect.OnApplied();
    }
    AddComboEffect(oPawn, Class'SFXGameEffect_PowerCombo_Electric', fDuration);
    return TRUE;
}
public event function bool ShouldUsePower(Actor Target, out string sOptionalInfo)
{
    local SFXPawn oPawn;
    
    oPawn = SFXPawn(Target);
    if (oPawn != None && oPawn.PowerControlResistance >= 1.0)
    {
        sOptionalInfo = string(NotRecommended_TargetImmune);
        return FALSE;
    }
    return TRUE;
}
public function StartCustomAction()
{
    local SFXProjectile_PowerCustomAction oProjectile;
    
    UnTrapLastTarget();
    if (m_oPawn.Role == ENetRole.ROLE_Authority)
    {
        foreach Projectiles(oProjectile, )
        {
            oProjectile.Explode(oProjectile.location, vect(0.0, 0.0, 1.0));
        }
    }
    Projectiles.Length = 0;
    Super.StartCustomAction();
}
public function ApplyBonus(Name Parameter, SFXGameEffect Bonus, optional bool bRemove = FALSE)
{
    Super.ApplyBonus(Parameter, Bonus, bRemove);
    switch (Parameter)
    {
        case 'Damage':
            ApplyBonusToParameter(DoTDamage, Bonus, bRemove);
            ApplyBonusToParameter(Evolve_AoEPulseDamage, Bonus, bRemove);
            break;
        case 'EffectDuration':
            ApplyBonusToParameter(IncapacitateDuration, Bonus, bRemove);
            ApplyBonusToParameter(Evolve_SlowTargetDuration, Bonus, bRemove);
            break;
        default:
    }
}
public function ClientDoCustomActionImpact(Actor oActor, int ImpactCount, optional bool bFirstTarget, optional Vector HitLocation, optional Vector HitNormal, optional int CustomActionReactionType)
{
    if (ImpactCount == -1)
    {
        SpawnWallImpactEffect(HitLocation, Rotator(HitNormal));
    }
    else if (ImpactCount == -2)
    {
        CreateBeam(oActor);
    }
    else
    {
        Super.ClientDoCustomActionImpact(oActor, ImpactCount, bFirstTarget, HitLocation, HitNormal, CustomActionReactionType);
    }
}
public function ClientDoPowerSubsequentImpact(Actor oActor, optional int CustomActionReactionType, optional float Duration, optional int ImpactCount, optional float Delay, optional bool DoCallback)
{
    if (ImpactCount == -1)
    {
        PutInNet(SFXPawn(oActor), Duration);
    }
}
public function EvolvePower(EEvolveChoice choice)
{
    Super(SFXPowerCustomActionBase).EvolvePower(choice);
    switch (choice)
    {
        case EEvolveChoice.EvolveChoice1:
            AddEvolvedRankBonus(DoTDamage, Evolve_DamageBonus);
            AddEvolvedRankBonus(Evolve_AoEPulseDamage, Evolve_DamageBonus);
            break;
        case EEvolveChoice.EvolveChoice2:
            AddEvolvedRankBonus(IncapacitateDuration, Evolve_IncapacitateBonus);
            break;
        case EEvolveChoice.EvolveChoice3:
            AddEvolvedRankBonus(DoTDamage, Evolve_DamageBonus2);
            AddEvolvedRankBonus(Evolve_AoEPulseDamage, Evolve_DamageBonus2);
            break;
        case EEvolveChoice.EvolveChoice4:
            AddEvolvedRankBonus(CooldownTime, Evolve_RechargeSpeedBonus);
            break;
        case EEvolveChoice.EvolveChoice5:
            break;
        case EEvolveChoice.EvolveChoice6:
            break;
        default:
    }
    RecalculateAllPowerData();
}
public function OnPowerDetonated(Vector HitLocation, Vector HitNormal, optional SFXProjectile_PowerCustomAction oProjectile, optional Actor HitActor)
{
    Super.OnPowerDetonated(HitLocation, HitNormal, oProjectile, HitActor);
    if (m_ImpactedActors.Length == 0 && m_oPawn.Role == ENetRole.ROLE_Authority)
    {
        SpawnWallImpactEffect(HitLocation, Rotator(HitNormal));
        if (ShouldReplicate())
        {
            ReplicateImpact(m_oPawn, -1, , HitLocation, HitNormal);
        }
    }
}
public function PopulatePowerStatBarEvolves()
{
    PowerStatBars.Length = 4;
    PowerStatBars[0].Data = SFXPawn_Henchman(m_oPawn) == None ? CooldownTime : HenchmanCooldownTime;
    PowerStatBars[0].srDisplayTotalToken = StatBarToken_Time;
    PowerStatBars[0].srStatBarDisplayTitle = StatBarTitle_Cooldown;
    PowerStatBars[0].EvolvedBonuses[3] = Evolve_RechargeSpeedBonus;
    PowerStatBars[1].Data = EffectDuration;
    PowerStatBars[1].srDisplayTotalToken = StatBarToken_Time;
    PowerStatBars[1].srStatBarDisplayTitle = $727760;
    PowerStatBars[2].Data = IncapacitateDuration;
    PowerStatBars[2].srDisplayTotalToken = StatBarToken_Time;
    PowerStatBars[2].srStatBarDisplayTitle = $727759;
    PowerStatBars[2].EvolvedBonuses[1] = Evolve_IncapacitateBonus;
    PowerStatBars[3].Data = DoTDamage;
    PowerStatBars[3].srDisplayTotalToken = StatBarToken_RawValue;
    PowerStatBars[3].srStatBarDisplayTitle = StatBarTitle_Damage;
    PowerStatBars[3].EvolvedBonuses[0] = Evolve_DamageBonus;
    PowerStatBars[3].EvolvedBonuses[2] = Evolve_DamageBonus2;
}
public function RecalculateAllPowerData(optional bool bReset = FALSE)
{
    Super(SFXPowerCustomActionBase).RecalculateAllPowerData(bReset);
    RecalculatePowerData(DoTDamage, bReset);
    RecalculatePowerData(IncapacitateDuration, bReset);
    RecalculatePowerData(Evolve_SlowTargetDuration, bReset);
    RecalculatePowerData(Evolve_AoEPulseDamage, bReset);
}
public function SpawnWallImpactEffect(Vector HitLocation, Rotator HitNormal)
{
    SFXGRI(m_oPawn.WorldInfo.GRI).DuringAsyncWorker.SpawnEffectAtLocation(m_oPawn, PS_ImpactWall, HitLocation, HitNormal);
}
public function UnTrapLastTarget()
{
    local SFXModule_GameEffectManager Manager;
    
    if (LastTarget != None)
    {
        Manager = LastTarget.GetModule(Class'SFXModule_GameEffectManager');
        if (Manager != None)
        {
            Manager.RemoveEffectsByTypeAndCategory(Class'SFXGameEffect_BatarianNet_Shared', Name);
        }
        LastTarget = None;
    }
}
public function CreateBeam(Actor oActor)
{
    local SFXModule_GameEffectManager Manager;
    local SFXGameEffect_BatarianNet_Shared Effect;
    
    if (LastTarget != None)
    {
        Manager = LastTarget.GetModule(Class'SFXModule_GameEffectManager');
        if (Manager != None)
        {
            Effect = SFXGameEffect_BatarianNet_Shared(Manager.GetFirstEffectOfTypeAndCategory(Class'SFXGameEffect_BatarianNet_Shared', Name));
            if (Effect != None)
            {
                Effect.CreateBeam(BioPawn(oActor), LastTarget.location);
            }
        }
    }
}
public function PutInNet(SFXPawn oPawn, float fDuration)
{
    local SFXModule_GameEffectManager Manager;
    local SFXGameEffect_BatarianNet_Shared NetEffect;
    
    LastTarget = oPawn;
    if (oPawn == None)
    {
        return;
    }
    Manager = oPawn.GetModule(Class'SFXModule_GameEffectManager');
    if (Manager != None)
    {
        NetEffect = SFXGameEffect_BatarianNet_Shared(Manager.CreateEffect(Class'SFXGameEffect_BatarianNet_Shared', Name, fDuration, 1, 0.0, m_oPawn.Controller, m_oPawn));
        if (NetEffect != None)
        {
            NetEffect.Power = Self;
            NetEffect.IncapacitateDuration = IncapacitateDuration.CurrentValue * (1.0 - oPawn.PowerControlResistance);
            NetEffect.IncapacitateResistThreshold = IncapacitateResistThreshold;
            if (IsEvolvedWithChoice(5))
            {
                NetEffect.ElectricPulseDamage = Evolve_AoEPulseDamage.CurrentValue;
                NetEffect.ElectricPulseFrequency = Evolve_AoEPulseFrequency;
                NetEffect.ElectricPulseDamageType = Class'SFXDamageType_BatarianNet_Shared';
                NetEffect.ElectricPulseRange = Evolve_AoEPulseRange;
            }
            NetEffect.OnApplied();
            oPawn.AddPowerAssistEvent(m_oPawn, DisplayName, PowerAssistFullControlValue);
            oPawn.PowerControlResistance += (1.0 - oPawn.PowerControlResistance) * 0.5;
            if (oPawn.PowerControlResistance > 0.899999976)
            {
                oPawn.PowerControlResistance = 1.0;
            }
            if (ShouldReplicate())
            {
                ReplicatePowerSubsequentImpact(oPawn, , fDuration, -1);
            }
        }
    }
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    Begin Object Class=BioDynamicAnimSet Name=MY_DYN_BAT_CB_Custom_CON_MP1
        m_nmOrigSetName = 'BAT_CB_Custom_CON_MP1'
        Sequences = (AnimSequence'BIOG_HMM_CB_CON_MP1.BAT_CB_Custom_CON_MP1_BC_BAT_Start', AnimSequence'BIOG_HMM_CB_CON_MP1.BAT_CB_Custom_CON_MP1_BC_BAT_End')
        m_pBioAnimSetData = BioAnimSetData'BIOG_HMM_CB_CON_MP1.BioAnimSetData_0'
    End Object
    DoTDamage = {
                 DynamicBonuses = (), 
                 RankBonuses[0] = 0.0, 
                 RankBonuses[1] = 0.0, 
                 RankBonuses[2] = 0.200000003, 
                 RankBonuses[3] = 0.0, 
                 RankBonuses[4] = 0.0, 
                 RankBonuses[5] = 0.0, 
                 BaseValue = 350.0, 
                 CurrentValue = 0.0, 
                 Formula = EPowerDataFormula.Normal
                }
    IncapacitateDuration = {
                            DynamicBonuses = (), 
                            RankBonuses[0] = 0.0, 
                            RankBonuses[1] = 0.0, 
                            RankBonuses[2] = 0.200000003, 
                            RankBonuses[3] = 0.0, 
                            RankBonuses[4] = 0.0, 
                            RankBonuses[5] = 0.0, 
                            BaseValue = 4.0, 
                            CurrentValue = 0.0, 
                            Formula = EPowerDataFormula.Normal
                           }
    Evolve_AoEPulseDamage = {
                             DynamicBonuses = (), 
                             RankBonuses[0] = 0.0, 
                             RankBonuses[1] = 0.0, 
                             RankBonuses[2] = 0.0, 
                             RankBonuses[3] = 0.0, 
                             RankBonuses[4] = 0.0, 
                             RankBonuses[5] = 0.0, 
                             BaseValue = 100.0, 
                             CurrentValue = 0.0, 
                             Formula = EPowerDataFormula.Normal
                            }
    Evolve_SlowTargetDuration = {
                                 DynamicBonuses = (), 
                                 RankBonuses[0] = 0.0, 
                                 RankBonuses[1] = 0.0, 
                                 RankBonuses[2] = 0.0, 
                                 RankBonuses[3] = 0.0, 
                                 RankBonuses[4] = 0.0, 
                                 RankBonuses[5] = 0.0, 
                                 BaseValue = 10.0, 
                                 CurrentValue = 0.0, 
                                 Formula = EPowerDataFormula.Normal
                                }
    IncapacitateResistThreshold = 0.800000012
    Evolve_DamageBonus = 0.300000012
    Evolve_IncapacitateBonus = 1.0
    Evolve_DamageBonus2 = 0.300000012
    Evolve_SlowTargetAmount = 0.300000012
    Evolve_RechargeSpeedBonus = 0.349999994
    Evolve_ShieldDamageBonus = 0.5
    Evolve_AoEPulseFrequency = 1.5
    Evolve_AoEPulseRange = 600.0
    PS_ImpactWall = ParticleSystem'BioVFX_DLC_MP1_Bat.Particles.Net_Projectile_Imp'
    BS_StartCastAnimation = {
                             AnimName = ('None', 
                                         'BC_BAT_Start', 
                                         'BC_BAT_Start', 
                                         'BC_BAT_Start', 
                                         'BC_BAT_Start', 
                                         'BC_BAT_Start', 
                                         'BC_BAT_Start', 
                                         'BC_BAT_Start', 
                                         'None', 
                                         'None', 
                                         'None', 
                                         'BC_BAT_Start'
                                        )
                            }
    BS_EndCastAnimation = {
                           AnimName = ('None', 
                                       'BC_BAT_End', 
                                       'BC_BAT_End', 
                                       'BC_BAT_End', 
                                       'BC_BAT_End', 
                                       'BC_BAT_End', 
                                       'BC_BAT_End', 
                                       'BC_BAT_End', 
                                       'None', 
                                       'None', 
                                       'None', 
                                       'BC_BAT_End'
                                      )
                          }
    DefaultDamageType = Class'SFXDamageType_BatarianNet_Shared'
    ProjectileClass = Class'SFXProjectile_PowerCustomAction_BatarianNet_Shared'
    ReleaseTime = 0.699999988
    CastAnimSet = MY_DYN_BAT_CB_Custom_CON_MP1
    CastCameraAnim = CameraAnim'BioVFX_C_CamAnim.Powers.BC_ThrowBiotic'
    CE_CasterCrustTemplate = RvrClientEffect'BioVFX_DLC_MP1_Bat.VCFX.NetMelee_VCFX'
    ImpactSound = WwiseEvent'Wwise_Power_DLC_StasisNet.Play_power_DLC_P_stasisnet_impact'
    CastSound = WwiseEvent'Wwise_Power_DLC_StasisNet.Play_power_DLC_P_stasisnet_cast'
    HenchmanImpactSound = WwiseEvent'Wwise_Power_DLC_StasisNet.Play_power_DLC_NP_stasisnet_impact'
    HenchmanCastSound = WwiseEvent'Wwise_Power_DLC_StasisNet.Play_power_DLC_NP_stasisnet_cast'
    Discipline = EBioCapMode.BIO_CAPMODE_TECH
    CooldownTime = {RankBonuses[1] = 0.25, BaseValue = 12.0, Formula = EPowerDataFormula.DivideByBonusSum}
    MaximumRange = {BaseValue = 6000.0}
    MaximumImpactTargets = {BaseValue = 1.0}
    EffectDuration = {RankBonuses[2] = 0.200000003, BaseValue = 4.0}
    ProjectileSpeed = {BaseValue = 2250.0}
    Ranks = ({
              Icon = 2, 
              Name = $0, 
              Description = $0, 
              Evolved1Name = $727757, 
              Evolved1Description = $727758, 
              Evolved2Name = $0, 
              Evolved2Description = $0
             }, 
             {
              Icon = 2, 
              Name = $0, 
              Description = $0, 
              Evolved1Name = $170381, 
              Evolved1Description = $501646, 
              Evolved2Name = $0, 
              Evolved2Description = $0
             }, 
             {
              Icon = 2, 
              Name = $0, 
              Description = $0, 
              Evolved1Name = $727771, 
              Evolved1Description = $727772, 
              Evolved2Name = $0, 
              Evolved2Description = $0
             }, 
             {
              Icon = 2, 
              Name = $0, 
              Description = $0, 
              Evolved1Name = $727773, 
              Evolved1Description = $727795, 
              Evolved2Name = $727776, 
              Evolved2Description = $727774
             }, 
             {
              Icon = 2, 
              Name = $0, 
              Description = $0, 
              Evolved1Name = $727777, 
              Evolved1Description = $727775, 
              Evolved2Name = $727778, 
              Evolved2Description = $727779
             }, 
             {
              Icon = 2, 
              Name = $0, 
              Description = $0, 
              Evolved1Name = $727780, 
              Evolved1Description = $727781, 
              Evolved2Name = $727782, 
              Evolved2Description = $727783
             }
            )
    PowerName = 'BatarianNet'
    PowerCustomActionID = 11
    DisplayName = $727757
    Description = $727758
    Icon = 2
    IconResource = GFxMovieInfo'GUI_SF_StasisNet.StasisNet'
    TalentDescription = $727758
    PowerType = EPowerType.PowerType_Projectile
    bHideWeapon = TRUE
}
