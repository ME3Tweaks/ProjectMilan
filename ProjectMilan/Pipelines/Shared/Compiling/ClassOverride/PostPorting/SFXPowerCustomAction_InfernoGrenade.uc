// Source: LMP, Batarian_Soldier_MP
// Initial decompilation: 10/31/2026
// MILAN CHANGE - Mgamerz
// Mark child projectile speed as config so it can actually read the value
Class SFXPowerCustomAction_InfernoGrenade extends SFXPowerCustomAction_GrenadeBase
    config(Game);

struct BurningActor
{
    var Actor AffectedActor;
    var int TimesAffected;
};

var config SFXPowerCustomActionBase.PowerData MaxGrenadeBonus;
var config SFXPowerCustomActionBase.PowerData ConcussiveImpact;
var config SFXPowerCustomActionBase.PowerData NumChildProjectiles;
var config SFXPowerCustomActionBase.PowerData ChildProjImpactRadius;
var array<SFXPowerCustomAction_InfernoGrenade.BurningActor> BurningActors;
var array<Actor> ActorsWithHealthRegenDebuff;
var array<Actor> ActorsWithStyleBonus;
var const WwiseEvent ReleasePowerSound;
var const WwiseEvent ProjectileSplitSound;
var RvrClientEffectInterface CE_FireDoTTemplate;
var config float Evolve_DamageBonus;
var config float Evolve_RadiusBonus;
var config float Evolve_RadiusBonus2;
var config float Evolve_NumFragmentsIncrease;
var config float Evolve_ArmorDamageBonus;
var config float Evolve_GrenadeCountBonus;
var config float Evolve_DamageBonus2;
var config int Rank2GrenadeUpgrade;
// MILAN CHANGE - Mark config
// Not defined on the class so it has to come from config.
var config float ChildProjMaxSpeed;
// END MILAN CHANGE
var config int MaxDotsPerPawn;

public function bool OnImpact(Actor.EPowerResistance Resistance, Actor oImpacted, int nPreviouslyImpacted, Object.Vector HitLocation, Object.Vector HitNormal)
{
    local SFXModule_GameEffectManager Manager;
    local SFXGameEffect_FireDamageOverTime Effect;
    local Class<SFXDamageType> DamageType;
    local float fDamagePerSecond;
    local RvrClientEffectInterface.RvrClientEffectTarget TargetInfo;
    local bool AllowDotApplication;

    if (oImpacted == None)
    {
        return FALSE;
    }
    Manager = oImpacted.GetModule(Class'SFXModule_GameEffectManager');
    if (Manager == None)
    {
        return FALSE;
    }
    AllowDotApplication = AllowFlameDot(oImpacted);
    if (AllowDotApplication)
    {
        AddPermanentHealthRegenPenalty(oImpacted, Resistance);
        ApplyTemporaryGameEffect(oImpacted, Class'SFXGameEffect_FireDeath', 2.0, 0.0, Name, m_oPawn.Controller);
    }
    if (Resistance == EPowerResistance.Resistance_Full)
    {
        return TRUE;
    }
    if (AllowDotApplication)
    {
        UpdateBurningPawns(oImpacted);
        fDamagePerSecond = Damage.CurrentValue;
        GetImpactDamage(oImpacted, DamageType);
        AddComboEffect(oImpacted, Class'SFXGameEffect_PowerCombo_Fire', EffectDuration.CurrentValue);
        Effect = SFXGameEffect_FireDamageOverTime(Manager.CreateEffect(Class'SFXGameEffect_FireDamageOverTime', Name, EffectDuration.CurrentValue, 1, fDamagePerSecond, m_oPawn.Controller));
        if (Effect != None)
        {
            Effect.DamageType = DamageType;
            Effect.bCanCauseCombo = FALSE;
            Effect.OnApplied();
        }
        TargetInfo.Instigator = oImpacted;
        TargetInfo.SpawnValue.X = EffectDuration.CurrentValue;
        Class'RvrClientEffectManager'.static.GetClientEffectManager().PlayOnTarget(CE_FireDoTTemplate, TargetInfo);
    }
    return TRUE;
}
public static function PrecacheVFX(SFXObjectPool ObjectPool, RvrClientEffectManager ClientEffects)
{
    Super(SFXPowerCustomAction).PrecacheVFX(ObjectPool, ClientEffects);
    ObjectPool.PrecacheProjectile(Class'SFXProjectile_PowerCustomAction_InfernoChild');
}
public function ApplyBonus(Name Parameter, SFXGameEffect Bonus, optional bool bRemove = FALSE)
{
    Super(SFXPowerCustomAction).ApplyBonus(Parameter, Bonus, bRemove);
    switch (Parameter)
    {
        case 'FireDamage':
            ApplyBonusToParameter(Damage, Bonus, bRemove);
            break;
        case 'Force':
            ApplyBonusToParameter(ConcussiveImpact, Bonus, bRemove);
            break;
            break;
        case 'ImpactRadius':
            ApplyBonusToParameter(ChildProjImpactRadius, Bonus, bRemove);
            break;
        default:
    }
}
public function ClientDoPowerSubsequentImpact(Actor oActor, optional int CustomActionReactionType, optional float Duration, optional int ImpactCount, optional float Delay, optional bool DoCallback)
{
    if (BioPawn(oActor) != None)
    {
        BioPawn(oActor).ClientPlayAnimatedReaction(CustomActionReactionType);
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
            AddEvolvedRankBonus(MaxGrenadeBonus, Evolve_GrenadeCountBonus);
            break;
        case EEvolveChoice.EvolveChoice4:
            AddEvolvedRankBonus(Damage, Evolve_DamageBonus2);
            break;
        case EEvolveChoice.EvolveChoice5:
            break;
        case EEvolveChoice.EvolveChoice6:
            AddEvolvedRankBonus(ImpactRadius, Evolve_RadiusBonus2);
            AddEvolvedRankBonus(NumChildProjectiles, Evolve_NumFragmentsIncrease);
            break;
        default:
    }
    RecalculateAllPowerInfo();
    ApplyGrenadeBonus();
}
public function float GetImpactDamage(Actor oImpacted, out Class<SFXDamageType> DamageType)
{
    if (IsEvolvedWithChoice(4))
    {
        DamageType = Class'SFXDamageType_ImprovedInfernoGrenade';
    }
    else
    {
        DamageType = Class'SFXDamageType_InfernoGrenade';
    }
    return 0.0;
}
public function float GetImpactForce(Actor oImpacted)
{
    local float fForce;

    if (IsEvolvedWithChoice(5))
    {
        fForce = ConcussiveImpact.CurrentValue;
    }
    return fForce;
}
public function OnPowerDetonated(Object.Vector HitLocation, Object.Vector HitNormal, optional SFXProjectile_PowerCustomAction oProjectile, optional Actor HitActor)
{
    if (SFXProjectile_PowerCustomAction_InfernoChild(oProjectile) == None)
    {
        BurningActors.Length = 0;
        ActorsWithStyleBonus.Length = 0;
        SpawnChildProjectiles(HitLocation, HitNormal, oProjectile);
        Super(SFXPowerCustomAction).OnPowerDetonated(HitLocation, HitNormal, oProjectile, HitActor);
    }
}
public function PopulatePowerStatBarEvolves()
{
    PowerStatBars.Length = 3;
    PowerStatBars[0].Data = Damage;
    PowerStatBars[0].srDisplayTotalToken = StatBarToken_RawValue;
    PowerStatBars[0].srStatBarDisplayTitle = StatBarTitle_DamagePerSecond;
    PowerStatBars[0].EvolvedBonuses[0] = Evolve_DamageBonus;
    PowerStatBars[0].EvolvedBonuses[3] = Evolve_DamageBonus2;
    PowerStatBars[1].Data = EffectDuration;
    PowerStatBars[1].srDisplayTotalToken = StatBarToken_Time;
    PowerStatBars[1].srStatBarDisplayTitle = StatBarTitle_Duration;
    PowerStatBars[2].Data = ImpactRadius;
    PowerStatBars[2].Formula = EPowerStatBarFormula.EPowerStatBarFormula_Distance;
    PowerStatBars[2].srDisplayTotalToken = StatBarToken_Distance;
    PowerStatBars[2].srStatBarDisplayTitle = StatBarTitle_ImpactRadius;
    PowerStatBars[2].EvolvedBonuses[1] = Evolve_RadiusBonus;
    PowerStatBars[2].EvolvedBonuses[5] = Evolve_RadiusBonus2;
}
public function RecalculateAllPowerData(optional bool bReset = FALSE)
{
    Super(SFXPowerCustomActionBase).RecalculateAllPowerData(bReset);
    RecalculatePowerData(ChildProjImpactRadius, bReset);
    RecalculatePowerData(NumChildProjectiles, bReset);
    RecalculatePowerData(ConcussiveImpact, bReset);
    RecalculatePowerData(MaxGrenadeBonus, bReset);
}
public function ReleasePower()
{
    Super.ReleasePower();
    m_oPawn.PlaySound(ReleasePowerSound, TRUE);
}
public function bool AddPermanentHealthRegenPenalty(Actor oImpacted, Actor.EPowerResistance Resistance)
{
    local int Index;

    if (Resistance == EPowerResistance.Resistance_None)
    {
        Index = ActorsWithHealthRegenDebuff.Find(oImpacted);
        if (Index < 0)
        {
            ActorsWithHealthRegenDebuff.AddItem(oImpacted);
            ApplyPermanentGameEffect(oImpacted, Class'SFXGameEffect_HealthRegenPenalty', 1.0, Name, m_oPawn.Controller);
            return TRUE;
        }
    }
    return FALSE;
}
public function bool AllowFlameDot(Actor oImpacted)
{
    local int Index;

    Index = BurningActors.Find('AffectedActor', oImpacted);
    if (Index < 0)
    {
        return TRUE;
    }
    if (Index >= 0 && BurningActors[Index].TimesAffected < MaxDotsPerPawn)
    {
        return TRUE;
    }
    return FALSE;
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
public function bool OnPoolTick(Actor.EPowerResistance Resistance, Actor oImpacted, int nPreviouslyImpacted, Object.Vector HitLocation, Object.Vector HitNormal)
{
    local RvrClientEffectInterface.RvrClientEffectTarget TargetInfo;
    local bool bHealthRegenPenaltyApplied;

    if (oImpacted == None)
    {
        return FALSE;
    }
    if (Resistance == EPowerResistance.Resistance_None)
    {
        ApplyTemporaryGameEffect(oImpacted, Class'SFXGameEffect_FireDeath', 1.0, 0.0, Name, m_oPawn.Controller);
    }
    bHealthRegenPenaltyApplied = AddPermanentHealthRegenPenalty(oImpacted, Resistance);
    if (bHealthRegenPenaltyApplied)
    {
        TargetInfo.Instigator = oImpacted;
        TargetInfo.SpawnValue.X = 1.0;
        Class'RvrClientEffectManager'.static.GetClientEffectManager().PlayOnTarget(CE_FireDoTTemplate, TargetInfo);
    }
    return TRUE;
}
public function SpawnChildProjectiles(Object.Vector HitLocation, Object.Vector HitNormal, optional SFXProjectile_PowerCustomAction oProjectile)
{
    local int Index;
    local SFXProjectile_PowerCustomAction_InfernoChild Projectile;
    local Object.Vector Direction;
    local Object.Rotator SpawnRotation;
    local float YawRotation;

    if (m_oPawn == None)
    {
        return;
    }
    if (m_oPawn.Role == ENetRole.ROLE_Authority)
    {
        if (ProjectileSplitSound != None)
        {
            SFXGRI(m_oPawn.WorldInfo.GRI).PlayTransientSound(ProjectileSplitSound, HitLocation);
        }
        Direction.X = 1.0;
        Direction.Y = 0.0;
        YawRotation = FRand() * float(65536);
        for (Index = 0; float(Index) < NumChildProjectiles.CurrentValue; Index++)
        {
            Direction.Z = 0.5 + FRand();
            SpawnRotation = Rotator(Direction);
            SpawnRotation.Yaw = int(YawRotation);
            Projectile = SFXGRI(m_oPawn.WorldInfo.GRI).ObjectPool.GetProjectile(Class'SFXProjectile_PowerCustomAction_InfernoChild', m_oPawn, m_oPawn.Instigator, HitLocation + HitNormal * 50.0, SpawnRotation);
            if (Projectile != None)
            {
                Projectile.SetRotation(SpawnRotation);
                if (oProjectile != None)
                {
                    Projectile.InitializePowerProjectile(m_oPawn, 0.0, 0.0, oProjectile.Power);
                }
                else
                {
                    Projectile.InitializePowerProjectile(m_oPawn, 0.0, 0.0, Self);
                }
                Projectile.ReplicatedPowerProjInitInfo.Power = oProjectile.ReplicatedPowerProjInitInfo.Power;
                Projectile.ReplicatedPowerProjInitInfo.Caster = oProjectile.Caster;
            }
            YawRotation += float(65536) / NumChildProjectiles.CurrentValue;
        }
    }
}
public function UpdateBurningPawns(Actor oImpacted)
{
    local int Index;
    local SFXPowerCustomAction_InfernoGrenade.BurningActor CurrentBurningPawn;

    Index = BurningActors.Find('AffectedActor', oImpacted);
    if (Index < 0)
    {
        CurrentBurningPawn.AffectedActor = oImpacted;
        CurrentBurningPawn.TimesAffected = 1;
        BurningActors.AddItem(CurrentBurningPawn);
    }
    else
    {
        BurningActors[Index].TimesAffected++;
    }
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    Begin Object Class=BioDynamicAnimSet Name=MY_DYN_HMM_CB_Grenade
        m_nmOrigSetName = 'HMM_CB_Grenade'
        Sequences = (AnimSequence'BIOG_HMM_CB_A.HMM_CB_Grenade_CB_Grenade2')
        m_pBioAnimSetData = BioAnimSetData'BIOG_HMM_CB_A.HMM_CB_Grenade_BioAnimSetData'
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
    ConcussiveImpact = {
                        DynamicBonuses = (),
                        RankBonuses[0] = 0.0,
                        RankBonuses[1] = 0.0,
                        RankBonuses[2] = 0.0,
                        RankBonuses[3] = 0.0,
                        RankBonuses[4] = 0.0,
                        RankBonuses[5] = 0.0,
                        BaseValue = 200.0,
                        CurrentValue = 0.0,
                        Formula = EPowerDataFormula.Normal
                       }
    NumChildProjectiles = {
                           DynamicBonuses = (),
                           RankBonuses[0] = 0.0,
                           RankBonuses[1] = 0.0,
                           RankBonuses[2] = 0.0,
                           RankBonuses[3] = 0.0,
                           RankBonuses[4] = 0.0,
                           RankBonuses[5] = 0.0,
                           BaseValue = 3.0,
                           CurrentValue = 0.0,
                           Formula = EPowerDataFormula.BonusIsHardValue
                          }
    ChildProjImpactRadius = {
                             DynamicBonuses = (),
                             RankBonuses[0] = 0.0,
                             RankBonuses[1] = 0.0,
                             RankBonuses[2] = 0.0,
                             RankBonuses[3] = 0.0,
                             RankBonuses[4] = 0.0,
                             RankBonuses[5] = 0.0,
                             BaseValue = 250.0,
                             CurrentValue = 0.0,
                             Formula = EPowerDataFormula.Normal
                            }
    ReleasePowerSound = WwiseEvent'Wwise_Power_Soldier_InferGren.Play_power_soldier_S_INFgrenade_projectile'
    ProjectileSplitSound = WwiseEvent'Wwise_Power_Soldier_InferGren.Play_power_soldier_S_INFgrenade_split'
    CE_FireDoTTemplate = RvrClientEffect'BioVFX_C_Fire.VCFX.Fire_Dot_VCFX'
    Evolve_DamageBonus = 0.300000012
    Evolve_RadiusBonus = 0.300000012
    Evolve_RadiusBonus2 = 0.400000006
    Evolve_NumFragmentsIncrease = 1.0
    Evolve_ArmorDamageBonus = 0.5
    Evolve_GrenadeCountBonus = 2.0
    Evolve_DamageBonus2 = 0.400000006
    Rank2GrenadeUpgrade = 1
    MaxDotsPerPawn = 1
    ProjectileClass = Class'SFXProjectile_PowerCustomAction_InfernoGrenade'
    DetonationParameters = {BlockedByObjects = FALSE}
    CastAnimSet = MY_DYN_HMM_CB_Grenade
    CE_ImpactTemplate = RvrClientEffect'BioVFX_C_NapalmGrenade.VCFX.Grenade_Imp_explosion_VCFX'
    CastSound = WwiseEvent'Wwise_Power_Soldier_InferGren.Play_power_soldier_P_INFgrenade_cast'
    HenchmanCastSound = WwiseEvent'Wwise_Power_Soldier_InferGren.Play_power_soldier_NP_INFgrenade_cast'
    Discipline = EBioCapMode.BIO_CAPMODE_COMBAT
    MaximumRange = {BaseValue = 6000.0}
    ImpactRadius = {BaseValue = 500.0}
    EffectDuration = {BaseValue = 8.0}
    Damage = {RankBonuses[2] = 0.200000003, BaseValue = 100.0}
    ProjectileSpeed = {BaseValue = 2000.0}
    Ranks = ({
              Icon = 49,
              Name = $0,
              Description = $0,
              Evolved1Name = $349055,
              Evolved1Description = $349060,
              Evolved2Name = $0,
              Evolved2Description = $0
             },
             {
              Icon = 49,
              Name = $0,
              Description = $0,
              Evolved1Name = $349057,
              Evolved1Description = $349062,
              Evolved2Name = $0,
              Evolved2Description = $0
             },
             {
              Icon = 49,
              Name = $0,
              Description = $0,
              Evolved1Name = $349058,
              Evolved1Description = $349063,
              Evolved2Name = $0,
              Evolved2Description = $0
             },
             {
              Icon = 49,
              Name = $0,
              Description = $0,
              Evolved1Name = $570337,
              Evolved1Description = $570343,
              Evolved2Name = $570338,
              Evolved2Description = $570344
             },
             {
              Icon = 49,
              Name = $0,
              Description = $0,
              Evolved1Name = $570339,
              Evolved1Description = $570345,
              Evolved2Name = $570340,
              Evolved2Description = $570347
             },
             {
              Icon = 49,
              Name = $0,
              Description = $0,
              Evolved1Name = $570341,
              Evolved1Description = $570346,
              Evolved2Name = $570342,
              Evolved2Description = $570348
             }
            )
    PowerName = 'InfernoGrenade'
    PowerCustomActionID = 23
    DisplayName = $349055
    Description = $703559
    Icon = 49
    TalentDescription = $703559
    IsBonusPower = TRUE
}
