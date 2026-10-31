// Source: LE3, N7_Engineer_MP
// Initial decompilation: 9/7/2024 4:01:42 PM
// MILAN CHANGE - UP3
// Allow the burning Homing Grenade evolution to prime fire combos
Class SFXPowerCustomActionMP_HomingGrenade extends SFXPowerCustomAction_GrenadeBase
    config(Game);

var config PowerData MaxGrenadeBonus;
var config AreaEffectParameters SecondTargetParams;
var Guid GrenadeSpawnGuid;
var Vector SecondLocation;
var config float Evolve_DamageBonus;
var config float Evolve_ImpactRadiusBonus;
var config int Evolve_GrenadeCountBonus;
var config float Evolve_DoTDamage;
var config float Evolve_DoTDuration;
var config float Evolve_ArmorDebuffPercent;
var config float Evolve_ArmorDebuffDuration;
var config float Evolve_ArmorDamageBonus;
var config float Evolve_SplitDamage;
var config float SecondProjectileDelay;
var config float SecondProjectileMaxRange;
var Actor SecondTarget;
var config float CastConeHalfAngleDeg;
var config int Rank2GrenadeUpgrade;
var RvrClientEffectInterface CE_GrenadeImpact;
var RvrClientEffectInterface CE_GrenadeSpawn;
var RvrClientEffectInterface CE_FireDoTTemplate;
var bool bSecondProjectile;

public function bool OnImpact(EPowerResistance Resistance, Actor oImpacted, int nPreviouslyImpacted, Vector HitLocation, Vector HitNormal)
{
    local SFXModule_GameEffectManager Manager;
    local SFXGameEffect_FireDamageOverTime Effect;
    local BioPawn oPawn;
    local float TotalDamage;
    local RvrClientEffectTarget TargetInfo;
    
    oPawn = BioPawn(oImpacted);
    if (oPawn == None)
    {
        return FALSE;
    }
    if (Resistance != EPowerResistance.Resistance_Full)
    {
        Manager = oImpacted.GetModule(Class'SFXModule_GameEffectManager');
        if (IsEvolvedWithChoice(3))
        {
            if (Manager != None)
            {
                if (IsEvolvedWithChoice(5))
                {
                    TotalDamage = Evolve_DoTDamage * Damage.CurrentValue * Evolve_SplitDamage;
                }
                else
                {
                    TotalDamage = Evolve_DoTDamage * Damage.CurrentValue;
                }
                // MILAN CHANGE - UP3 - Prime fire combos for the burning evolution duration
                AddComboEffect(oPawn, Class'SFXGameEffect_PowerCombo_Fire', Evolve_DoTDuration);
                // END MILAN CHANGE
                Effect = SFXGameEffect_FireDamageOverTime(Manager.CreateEffect(Class'SFXGameEffect_FireDamageOverTime', Name, Evolve_DoTDuration, 1, TotalDamage / Evolve_DoTDuration, m_oPawn.Controller));
                if (Effect != None)
                {
                    Effect.DamageType = GetDamageType();
                    Effect.OnApplied();
                    TargetInfo.Instigator = oImpacted;
                    TargetInfo.SpawnValue.X = Evolve_DoTDuration;
                    Class'RvrClientEffectManager'.static.GetClientEffectManager().PlayOnTarget(CE_FireDoTTemplate, TargetInfo);
                }
            }
        }
        if (IsEvolvedWithChoice(4))
        {
            if (!Manager.HasEffectOfTypeAndCategory(Class'SFXGameEffect_ArmorWeakness', Name))
            {
                Manager.CreateAndApplyEffect(Class'SFXGameEffect_ArmorWeakness', Name, Evolve_ArmorDebuffDuration, 1, -Evolve_ArmorDebuffPercent, m_oPawn.Controller);
            }
        }
    }
    return TRUE;
}
public function EvolvePower(EEvolveChoice choice)
{
    Super(SFXPowerCustomActionBase).EvolvePower(choice);
    switch (choice)
    {
        case EEvolveChoice.EvolveChoice1:
            AddEvolvedRankBonus(Damage, Evolve_DamageBonus);
            break;
        case EEvolveChoice.EvolveChoice2:
            AddEvolvedRankBonus(ImpactRadius, Evolve_ImpactRadiusBonus);
            break;
        case EEvolveChoice.EvolveChoice3:
            AddEvolvedRankBonus(MaxGrenadeBonus, float(Evolve_GrenadeCountBonus));
            break;
        case EEvolveChoice.EvolveChoice4:
            break;
        case EEvolveChoice.EvolveChoice5:
            break;
        case EEvolveChoice.EvolveChoice6:
            bSecondProjectile = TRUE;
            break;
        default:
    }
    RecalculateAllPowerInfo();
    ApplyGrenadeBonus();
}
public function Class<SFXDamageType> GetDamageType()
{
    if (!IsEvolvedWithChoice(4))
    {
        return Class'SFXDamageType_HomingGrenade';
    }
    return Class'SFXDamageType_HomingGrenade_Improved';
}
public function Vector GetDefaultClientEffectParams()
{
    local Vector Param;
    
    if (IsEvolvedWithChoice(1))
    {
        Param.Y = 1.0;
    }
    return Param;
}
public function float GetImpactDamage(Actor oImpacted, out Class<SFXDamageType> DamageType)
{
    DamageType = GetDamageType();
    if (IsEvolvedWithChoice(5))
    {
        return Damage.CurrentValue * Evolve_SplitDamage;
    }
    return Damage.CurrentValue;
}
public function PlayDetonationEffects(Vector ImpactLocation, Vector ImpactNormal, optional SFXProjectile_PowerCustomAction oProjectile)
{
    Super(SFXPowerCustomAction).PlayDetonationEffects(ImpactLocation, ImpactNormal, oProjectile);
    if (CE_GrenadeImpact != None)
    {
        Class'RvrClientEffectManager'.static.GetClientEffectManager().PlayAtLocation(CE_GrenadeImpact, ImpactLocation, vect(1.0, 0.0, 0.0), GetDefaultClientEffectParams());
    }
}
public function PopulatePowerStatBarEvolves()
{
    PowerStatBars.Length = 2;
    PowerStatBars[0].Data = Damage;
    PowerStatBars[0].srDisplayTotalToken = StatBarToken_RawValue;
    PowerStatBars[0].srStatBarDisplayTitle = StatBarTitle_Damage;
    PowerStatBars[0].EvolvedBonuses[0] = Evolve_DamageBonus;
    PowerStatBars[1].Data = ImpactRadius;
    PowerStatBars[1].Formula = EPowerStatBarFormula.EPowerStatBarFormula_Distance;
    PowerStatBars[1].srDisplayTotalToken = StatBarToken_Distance;
    PowerStatBars[1].srStatBarDisplayTitle = StatBarTitle_ImpactRadius;
    PowerStatBars[1].EvolvedBonuses[1] = Evolve_ImpactRadiusBonus;
}
public function RecalculateAllPowerData(optional bool bReset = FALSE)
{
    Super(SFXPowerCustomActionBase).RecalculateAllPowerData(bReset);
    RecalculatePowerData(MaxGrenadeBonus, bReset);
}
public function ReleasePower()
{
    Super.ReleasePower();
    Class'RvrClientEffectManager'.static.GetClientEffectManager().Stop(None, GrenadeSpawnGuid, TRUE, m_oPawn);
    if (bSecondProjectile)
    {
        FindSecondTarget();
        m_oPawn.SetTimer(SecondProjectileDelay, FALSE, 'ReleaseSecondProjectile', Self);
    }
}
public function SFXProjectile_PowerCustomAction ReleaseProjectilePower()
{
    local SFXProjectile_PowerCustomAction oProjectile;
    
    oProjectile = Super(SFXPowerCustomAction).ReleaseProjectilePower();
    if (oProjectile != None)
    {
        oProjectile.SetBase(m_oPawn, , m_oPawn.Mesh, 'Grenade');
    }
    return oProjectile;
}
public function ResetPower()
{
    bSecondProjectile = FALSE;
    Super.ResetPower();
}
public function StartPower()
{
    Super(SFXPowerCustomAction).StartPower();
    GrenadeSpawnGuid = Class'RvrClientEffectManager'.static.GetClientEffectManager().Start(CE_GrenadeSpawn, m_oPawn);
}
public function ApplyGrenadeBonus()
{
    local SFXModule_GameEffectManager Manager;
    
    Manager = m_oPawn.GetModule(Class'SFXModule_GameEffectManager');
    if (Manager != None)
    {
        Manager.RemoveEffectsByCategory(Name);
    }
    if (MaxGrenadeBonus.CurrentValue > float(0))
    {
        ApplyPermanentGameEffect(m_oPawn, Class'SFXGameEffect_MaxGrenadeBonus', MaxGrenadeBonus.CurrentValue, Name, m_oPawn.Controller);
    }
}
public function FindSecondTarget()
{
    local array<Actor> NearbyActors;
    local Actor oActor;
    local SFXPawn_Player Player;
    
    if (m_oTargetToAimAt != None)
    {
        GetNearbyActors(NearbyActors, m_oTargetToAimAt.location, SecondProjectileMaxRange, SecondProjectileMaxRange, SecondTargetParams);
        Player = SFXPawn_Player(m_oPawn);
        foreach NearbyActors(oActor, )
        {
            if (oActor != m_oTargetToAimAt)
            {
                if (Player != None && Vector(m_oPawn.Rotation) Dot Normal(oActor.location - m_oPawn.location) < Cos(CastConeHalfAngleDeg * 0.0174532924))
                {
                    continue;
                }
                SecondTarget = oActor;
                break;
            }
        }
        if (SecondTarget != None)
        {
            SecondLocation = SecondTarget.location;
            return;
        }
        else
        {
            SecondTarget = m_oTargetToAimAt;
            SecondLocation = m_oTargetToAimAt.location;
        }
    }
    else
    {
        SecondTarget = m_oTargetToAimAt;
        SecondLocation = m_vLocationToAimAt;
    }
}
public function ReleaseSecondProjectile()
{
    local BioPawn oPawnTarget;
    
    m_oTargetToAimAt = SecondTarget;
    m_vLocationToAimAt = SecondLocation;
    oPawnTarget = BioPawn(SecondTarget);
    if (oPawnTarget != None)
    {
        oPawnTarget.OnCastAt(m_oPawn, Self);
    }
    ReleaseProjectilePower();
    SecondTarget = None;
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    Begin Object Class=BioDynamicAnimSet Name=MY_DYN_HMM_CB_Engineer_CON_MP3
        m_nmOrigSetName = 'HMM_CB_Engineer_CON_MP3'
        Sequences = (AnimSequence'BIOG_HMM_CB_CON_MP3.HMM_CB_Engineer_CON_MP3_BC_Start', AnimSequence'BIOG_HMM_CB_CON_MP3.HMM_CB_Engineer_CON_MP3_BC_End')
        m_pBioAnimSetData = BioAnimSetData'BIOG_HMM_CB_CON_MP3.HMM_CB_Engineer_CON_MP3_BioAnimSetData'
    End Object
    MaxGrenadeBonus = {
                       DynamicBonuses = (), 
                       RankBonuses[0] = 0.0, 
                       RankBonuses[1] = 1.0, 
                       RankBonuses[2] = 0.0, 
                       RankBonuses[3] = 0.0, 
                       RankBonuses[4] = 0.0, 
                       RankBonuses[5] = 0.0, 
                       BaseValue = 0.0, 
                       CurrentValue = 0.0, 
                       Formula = EPowerDataFormula.BonusIsHardValue
                      }
    SecondTargetParams = {
                          ConeDirection = {X = 0.0, Y = 0.0, Z = 0.0}, 
                          HitDirectionOffset = {Pitch = 0, Yaw = 0, Roll = 0}, 
                          ConeAngle = 0.0, 
                          ImpactFriends = FALSE, 
                          ImpactDeadPawns = FALSE, 
                          ImpactPlaceables = TRUE, 
                          BlockedByObjects = FALSE, 
                          DistancedSorted = TRUE
                         }
    Evolve_DamageBonus = 0.300000012
    Evolve_ImpactRadiusBonus = 0.5
    Evolve_GrenadeCountBonus = 1
    Evolve_DoTDamage = 0.5
    Evolve_DoTDuration = 6.0
    Evolve_ArmorDebuffPercent = 0.5
    Evolve_ArmorDebuffDuration = 8.0
    Evolve_ArmorDamageBonus = 0.600000024
    Evolve_SplitDamage = 0.600000024
    SecondProjectileDelay = 0.25
    SecondProjectileMaxRange = 800.0
    CastConeHalfAngleDeg = 60.0
    CE_GrenadeImpact = RvrClientEffect'BioVFX_MP3_Engineer.VCFX.HomingGrenade_Imp_VCFX'
    CE_GrenadeSpawn = RvrClientEffect'BioVFX_MP3_Engineer.VCFX.Grenade_Inital'
    CE_FireDoTTemplate = RvrClientEffect'BioVFX_C_Fire.VCFX.Fire_Dot_VCFX'
    ComboDetonators = (Class'SFXGameEffect_PowerCombo_Electric', Class'SFXGameEffect_PowerCombo_Fire', Class'SFXGameEffect_PowerCombo_Cryo')
    BS_EndCastAnimation = {
                           AnimName = ('None', 
                                       'BC_End', 
                                       'BC_End', 
                                       'BC_End_Cover_Neutral', 
                                       'BC_End', 
                                       'BC_End_Cover_Neutral_Mid', 
                                       'BC_End', 
                                       'BC_End', 
                                       'None', 
                                       'None', 
                                       'None', 
                                       'BC_End'
                                      )
                          }
    ProjectileClass = Class'SFXProjectile_PowerCustomAction_HomingGrenade'
    DetonationRumbleClass = Class'SFXRumble_Power_FragGrenade'
    DetonationScreenShakeClass = Class'SFXShake_Power_FragGrenade'
    DetonationParameters = {BlockedByObjects = FALSE}
    CustomCasterCrustParameters = {X = 1.79999995, Y = 0.0, Z = 0.0}
    ProjectileAttachPoint = 'Grenade'
    ReleaseEffectBoneName = 'Grenade'
    ReleaseTime = 0.800000012
    CastAnimSet = MY_DYN_HMM_CB_Engineer_CON_MP3
    fEndAnimBlendInTime = 0.5
    fEndAnimBlendOutTime = 0.649999976
    CE_CasterCrustTemplate = RvrClientEffectMulti'BioVFX_T_TechPowers._OmniTool.VCFX.OmniTool_RightFull_VCFX_M'
    ImpactSound = WwiseEvent'Wwise_Power_DLC_HGren.Play_power_DLC_P_HGrenade_impact'
    ReleaseSound = WwiseEvent'Wwise_Power_Tech_Incinerate.Play_power_tech_P_incinerate_cast'
    CastSound = WwiseEvent'Wwise_Power_DLC_HGren.Play_power_DLC_P_HGrenade_cast'
    HenchmanImpactSound = WwiseEvent'Wwise_Power_DLC_HGren.Play_power_DLC_NP_HGrenade_impact'
    HenchmanReleaseSound = WwiseEvent'Wwise_Power_Tech_Incinerate.Play_power_tech_NP_incinerate_cast'
    HenchmanCastSound = WwiseEvent'Wwise_Power_DLC_HGren.Play_power_DLC_NP_HGrenade_cast'
    bPlayStartCastAnim = TRUE
    bCustomCasterCrustParameters = TRUE
    Discipline = EBioCapMode.BIO_CAPMODE_TECH
    MaximumRange = {BaseValue = 6000.0}
    ImpactRadius = {BaseValue = 200.0}
    Damage = {RankBonuses[2] = 0.200000003, BaseValue = 700.0}
    Force = {RankBonuses[2] = 0.200000003, BaseValue = 1000.0}
    ProjectileSpeed = {BaseValue = 500.0}
    Ranks = ({
              Icon = 2, 
              Name = $0, 
              Description = $0, 
              Evolved1Name = $754613, 
              Evolved1Description = $754614, 
              Evolved2Name = $0, 
              Evolved2Description = $0
             }, 
             {
              Icon = 2, 
              Name = $0, 
              Description = $0, 
              Evolved1Name = $754625, 
              Evolved1Description = $754615, 
              Evolved2Name = $0, 
              Evolved2Description = $0
             }, 
             {
              Icon = 2, 
              Name = $0, 
              Description = $0, 
              Evolved1Name = $754623, 
              Evolved1Description = $754616, 
              Evolved2Name = $0, 
              Evolved2Description = $0
             }, 
             {
              Icon = 2, 
              Name = $0, 
              Description = $0, 
              Evolved1Name = $754623, 
              Evolved1Description = $754617, 
              Evolved2Name = $754624, 
              Evolved2Description = $754618
             }, 
             {
              Icon = 2, 
              Name = $0, 
              Description = $0, 
              Evolved1Name = $754625, 
              Evolved1Description = $754619, 
              Evolved2Name = $754626, 
              Evolved2Description = $754620
             }, 
             {
              Icon = 2, 
              Name = $0, 
              Description = $0, 
              Evolved1Name = $754627, 
              Evolved1Description = $754621, 
              Evolved2Name = $754628, 
              Evolved2Description = $754622
             }
            )
    PowerName = 'HomingGrenade'
    PowerCustomActionID = 12
    DisplayName = $754613
    Description = $754614
    Icon = 2
    IconResource = GFxMovieInfo'GUI_SF_HomingGade.HomingGade'
    TalentDescription = $754614
    MinTimeBetweenActions = 0.25
    VocalizationEvent = ESFXVocalizationEventID.SFXVocalizationEvent_Power_Flashbang
}
