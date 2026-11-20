// Source: ME3, Patch_SFXPowerCustomAction_Carnage
// Decompiled 11/17/2026 7:38:33 AM against BioH_Marine_00.pcc
Class SFXPowerCustomAction_Carnage extends SFXPowerCustomAction
    config(Game);

var RvrClientEffectInterface CE_NormalImpact;
var RvrClientEffectInterface CE_CarnageDoTTemplate;
var RvrClientEffectInterface CE_DeathEffect;
var ParticleSystem MuzzleEffect;
var float MuzzleEffectLifetime;
var config float Evolve_DamageBonus;
var config float Evolve_ImpactRadiusBonus;
var config float Evolve_RechargeSpeedBonus;
var config float Evolve_DamageBonus2;
var config float Evolve_ArmorDamagePct;
var config float InstantDamagePercent;
var config float DoTDamagePercent;
var config float DOTDuration;

public function bool DoPowerDetonatedForActor(Actor oActor, Object.Vector HitLocation, Object.Vector HitNormal, int nImpactCount, bool bFirstTarget, optional SFXProjectile_PowerCustomAction oProjectile)
{
    local BioPawn ImpactedPawn;
    local SFXModule_GameEffectManager Manager;
    local SFXGameEffect_DeathEffect DeathEffect;
    
    ImpactedPawn = BioPawn(oActor);
    if (ImpactedPawn != None)
    {
        Manager = ImpactedPawn.GetModule(Class'SFXModule_GameEffectManager');
    }
    if (Manager != None && !Manager.HasEffectOfTypeAndCategory(Class'SFXGameEffect_DeathEffect', Name) && ImpactedPawn.CanGib())
    {
        DeathEffect = SFXGameEffect_DeathEffect(Manager.CreateEffect(Class'SFXGameEffect_DeathEffect', Name, 0.5, 1, 0.0, m_oPawn.Controller));
        if (DeathEffect != None)
        {
            DeathEffect.CE_DeathEffectTemplate = CE_DeathEffect;
            DeathEffect.bCorpseDestroyed = TRUE;
            GetImpactDamage(ImpactedPawn, DeathEffect.PlayExclusivelyForDamageType);
            DeathEffect.OnApplied();
        }
    }
    return Super.DoPowerDetonatedForActor(oActor, HitLocation, HitNormal, nImpactCount, bFirstTarget, oProjectile);
}
public function bool OnImpact(Actor.EPowerResistance Resistance, Actor oImpacted, int nPreviouslyImpacted, Object.Vector HitLocation, Object.Vector HitNormal)
{
    local SFXModule_GameEffectManager Manager;
    local SFXGameEffect_DamageOverTime Effect;
    local Class<SFXDamageType> DamageType;
    local float fDamagePerSecond;
    local SFXPawn oPawn;
    local Object.Vector Param;
    
    if (oImpacted == None)
    {
        return FALSE;
    }
    Manager = oImpacted.GetModule(Class'SFXModule_GameEffectManager');
    if (Resistance != EPowerResistance.Resistance_Full)
    {
        oPawn = SFXPawn(oImpacted);
        if (Manager != None && oPawn != None && !oPawn.IsDead())
        {
            fDamagePerSecond = GetTotalDamage(oImpacted, DamageType, TRUE) * DoTDamagePercent / DOTDuration;
            Effect = SFXGameEffect_DamageOverTime(Manager.CreateEffect(Class'SFXGameEffect_DamageOverTime', Name, DOTDuration, 1, fDamagePerSecond, m_oPawn.Controller));
            if (Effect != None)
            {
                Effect.DamageType = DamageType;
                Effect.OnApplied();
            }
            Param.X = EffectDuration.CurrentValue;
            Class'RvrClientEffectManager'.static.GetClientEffectManager().Play(CE_CarnageDoTTemplate, oImpacted, Param);
        }
        AddComboEffect(oImpacted, Class'SFXGameEffect_PowerCombo_Fire', DOTDuration);
        if (oPawn != None && IsEvolvedWithChoice(2) && Resistance == EPowerResistance.Resistance_None)
        {
            oPawn.AddPowerAssistEvent(m_oPawn, DisplayName, PowerAssistFullControlValue);
        }
    }
    return TRUE;
}
public static function PrecacheVFX(SFXObjectPool ObjectPool, RvrClientEffectManager ClientEffects)
{
    Super.PrecacheVFX(ObjectPool, ClientEffects);
    Class'SFXGameEffect_DeathEffect'.static.PrecacheVFX(ObjectPool, ClientEffects);
    ObjectPool.PrecacheImpactEmitter(default.MuzzleEffect);
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
        return ShouldUsePowerOnShields(oPawn, Class'SFXDamageType_Carnage', sOptionalInfo);
    }
    return TRUE;
}
public function EvolvePower(SFXPowerCustomActionBase.EEvolveChoice choice)
{
    Super(SFXPowerCustomActionBase).EvolvePower(choice);
    switch (choice)
    {
        case EEvolveChoice.EvolveChoice1:
            AddEvolvedRankBonus(ImpactRadius, Evolve_ImpactRadiusBonus);
            break;
        case EEvolveChoice.EvolveChoice2:
            AddEvolvedRankBonus(Damage, Evolve_DamageBonus);
            AddEvolvedRankBonus(Force, Evolve_DamageBonus);
            break;
        case EEvolveChoice.EvolveChoice3:
            break;
        case EEvolveChoice.EvolveChoice4:
            AddEvolvedRankBonus(CooldownTime, Evolve_RechargeSpeedBonus);
            AddEvolvedRankBonus(HenchmanCooldownTime, Evolve_RechargeSpeedBonus);
            break;
        case EEvolveChoice.EvolveChoice5:
            break;
        case EEvolveChoice.EvolveChoice6:
            AddEvolvedRankBonus(Damage, Evolve_DamageBonus2);
            AddEvolvedRankBonus(Force, Evolve_DamageBonus2);
            break;
        default:
    }
    RecalculateAllPowerInfo();
}
public function float GetImpactDamage(Actor oImpacted, out Class<SFXDamageType> DamageType)
{
    return GetTotalDamage(oImpacted, DamageType, FALSE) * InstantDamagePercent;
}
public function bool GetProjectileAttachPoint(out Object.Vector AttachPoint)
{
    local Object.Rotator Rotation;
    
    if (SFXWeapon(m_oPawn.Weapon) != None && SkeletalMeshComponent(m_oPawn.Weapon.Mesh) != None)
    {
        if (SkeletalMeshComponent(m_oPawn.Weapon.Mesh).GetSocketWorldLocationAndRotation(SFXWeapon(m_oPawn.Weapon).MuzzleSocketName, AttachPoint, Rotation) == FALSE)
        {
            AttachPoint = m_oPawn.location;
        }
    }
    return TRUE;
}
public function PlayDetonationEffects(Object.Vector ImpactLocation, Object.Vector ImpactNormal, optional SFXProjectile_PowerCustomAction oProjectile)
{
    Super.PlayDetonationEffects(ImpactLocation, ImpactNormal, oProjectile);
    Class'RvrClientEffectManager'.static.GetClientEffectManager().PlayAtLocation(CE_NormalImpact, ImpactLocation, ImpactNormal, GetDefaultClientEffectParams());
}
public function PopulatePowerStatBarEvolves()
{
    PowerStatBars.Length = 3;
    PowerStatBars[0].Data = SFXPawn_Henchman(m_oPawn) == None ? CooldownTime : HenchmanCooldownTime;
    PowerStatBars[0].srDisplayTotalToken = StatBarToken_Time;
    PowerStatBars[0].srStatBarDisplayTitle = StatBarTitle_Cooldown;
    PowerStatBars[0].EvolvedBonuses[3] = Evolve_RechargeSpeedBonus;
    PowerStatBars[1].Data = Damage;
    PowerStatBars[1].srDisplayTotalToken = StatBarToken_RawValue;
    PowerStatBars[1].srStatBarDisplayTitle = StatBarTitle_Damage;
    PowerStatBars[1].EvolvedBonuses[1] = Evolve_DamageBonus;
    PowerStatBars[1].EvolvedBonuses[5] = Evolve_DamageBonus2;
    PowerStatBars[2].Data = ImpactRadius;
    PowerStatBars[2].Formula = EPowerStatBarFormula.EPowerStatBarFormula_Distance;
    PowerStatBars[2].srDisplayTotalToken = StatBarToken_Distance;
    PowerStatBars[2].srStatBarDisplayTitle = StatBarTitle_ImpactRadius;
    PowerStatBars[2].EvolvedBonuses[0] = Evolve_ImpactRadiusBonus;
}
public function ReleasePower()
{
    local Object.Vector EffectLocation;
    local Object.Rotator EffectRotation;
    
    if (SFXWeapon(m_oPawn.Weapon) != None && SkeletalMeshComponent(m_oPawn.Weapon.Mesh) != None)
    {
        SkeletalMeshComponent(m_oPawn.Weapon.Mesh).GetSocketWorldLocationAndRotation(SFXWeapon(m_oPawn.Weapon).MuzzleSocketName, EffectLocation, EffectRotation);
        SFXGRI(m_oPawn.WorldInfo.GRI).DuringAsyncWorker.SpawnEffectAtLocation(m_oPawn, MuzzleEffect, EffectLocation, EffectRotation, MuzzleEffectLifetime);
    }
    Super.ReleasePower();
}
public function float GetTotalDamage(Actor oImpacted, out Class<SFXDamageType> DamageType, bool bIsDamageOverTime)
{
    local float fDamage;
    
    fDamage = Damage.CurrentValue;
    if (IsEvolvedWithChoice(2))
    {
        if (IsEvolvedWithChoice(4))
        {
            DamageType = bIsDamageOverTime ? Class'SFXDamageType_Carnage_Ragdoll_Improved_DoT' : Class'SFXDamageType_Carnage_Ragdoll_Improved';
        }
        else
        {
            DamageType = bIsDamageOverTime ? Class'SFXDamageType_Carnage_Ragdoll_DoT' : Class'SFXDamageType_Carnage_Ragdoll';
        }
    }
    else if (IsEvolvedWithChoice(4))
    {
        DamageType = bIsDamageOverTime ? Class'SFXDamageType_Carnage_Improved_DoT' : Class'SFXDamageType_Carnage_Improved';
    }
    else
    {
        DamageType = bIsDamageOverTime ? Class'SFXDamageType_Carnage_DoT' : Class'SFXDamageType_Carnage';
    }
    return fDamage;
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    Begin Object Class=BioDynamicAnimSet Name=MY_DYN_HMM_BC_ShotgunSpecial
        m_nmOrigSetName = 'HMM_BC_ShotgunSpecial'
        Sequences = (AnimSequence'BIOG_HMM_BC_A.HMM_BC_ShotgunSpecial_BC_Start', AnimSequence'BIOG_HMM_BC_A.HMM_BC_ShotgunSpecial_BC_End')
        m_pBioAnimSetData = BioAnimSetData'BIOG_HMM_BC_A.HMM_BC_ShotgunSpecial_BioAnimSetData'
    End Object
    CE_NormalImpact = RvrClientEffect'BioVFX_C_Carnage.VCFX.Carnage_Impact_VCFX'
    CE_CarnageDoTTemplate = RvrClientEffect'BioVFX_C_Carnage.VCFX.Carnage_TargetCrust_VCFX'
    CE_DeathEffect = RvrClientEffect'BioVFX_C_Blood.VCFX.Gib_01_VCFX'
    MuzzleEffect = ParticleSystem'BioVFX_C_Carnage.Particles.Carnage_Muzzle'
    MuzzleEffectLifetime = 1.0
    Evolve_DamageBonus = 0.300000012
    Evolve_ImpactRadiusBonus = 0.5
    Evolve_RechargeSpeedBonus = 0.349999994
    Evolve_DamageBonus2 = 0.5
    Evolve_ArmorDamagePct = 0.649999976
    InstantDamagePercent = 0.75
    DoTDamagePercent = 0.25
    DOTDuration = 2.0
    ComboDetonators = (Class'SFXGameEffect_PowerCombo_Electric', Class'SFXGameEffect_PowerCombo_Fire', Class'SFXGameEffect_PowerCombo_Cryo')
    EvolvedImpactSounds = ({Sound = WwiseEvent'Wwise_Power_Soldier_ConShot.Play_power_soldier_P_concussiveshot_evolimpact', bAnyEvolved = TRUE, bReplaceBaseSound = TRUE, EvolveChoice = EEvolveChoice.EvolveChoice1}
                          )
    EvolvedCastSounds = ({Sound = WwiseEvent'Wwise_Power_Soldier_ConShot.Play_power_soldier_P_concussiveshot_evolcast', bAnyEvolved = TRUE, bReplaceBaseSound = TRUE, EvolveChoice = EEvolveChoice.EvolveChoice1}
                        )
    HenchmanEvolvedImpactSounds = ({Sound = WwiseEvent'Wwise_Power_Soldier_ConShot.Play_power_soldier_NP_concussiveshot_evolimpact', bAnyEvolved = TRUE, bReplaceBaseSound = TRUE, EvolveChoice = EEvolveChoice.EvolveChoice1}
                                  )
    HenchmanEvolvedCastSounds = ({Sound = WwiseEvent'Wwise_Power_Soldier_ConShot.Play_power_soldier_NP_concussiveshot_evolcast', bAnyEvolved = TRUE, bReplaceBaseSound = TRUE, EvolveChoice = EEvolveChoice.EvolveChoice1}
                                )
    DefaultDamageType = Class'SFXDamageType_Carnage'
    ProjectileClass = Class'SFXProjectile_PowerCustomAction_Carnage'
    DetonationRumbleClass = Class'SFXRumble_Power_HeavyImpact'
    DetonationScreenShakeClass = Class'SFXShake_Power_HeavyImpact'
    CastAnimSet = MY_DYN_HMM_BC_ShotgunSpecial
    ImpactSound = WwiseEvent'Wwise_Power_Soldier_ConShot.Play_power_soldier_P_carnage_impact'
    CastSound = WwiseEvent'Wwise_Power_Soldier_ConShot.Play_power_soldier_P_carnage_cast'
    HenchmanImpactSound = WwiseEvent'Wwise_Power_Soldier_ConShot.Play_power_soldier_NP_carnage_impact'
    HenchmanCastSound = WwiseEvent'Wwise_Power_Soldier_ConShot.Play_power_soldier_NP_carnage_cast'
    ImpactDistanceLayer = WwiseEvent'Wwise_Generic_Explosions.Play_power_soldier_P_conshot_distant'
    HenchmanImpactDistanceLayer = WwiseEvent'Wwise_Generic_Explosions.Play_power_soldier_NP_conshot_distant'
    bPlayStartCastAnim = FALSE
    Discipline = EBioCapMode.BIO_CAPMODE_COMBAT
    CooldownTime = {RankBonuses[1] = 0.25, BaseValue = 10.0, Formula = EPowerDataFormula.DivideByBonusSum}
    HenchmanCooldownTime = {RankBonuses[1] = 0.25, BaseValue = 20.0, Formula = EPowerDataFormula.DivideByBonusSum}
    MaximumRange = {BaseValue = 6000.0}
    ImpactRadius = {BaseValue = 150.0}
    EffectDuration = {BaseValue = 1.0}
    Damage = {RankBonuses[2] = 0.200000003, BaseValue = 315.0}
    Force = {RankBonuses[2] = 0.200000003, BaseValue = 300.0}
    Ranks = ({
              Icon = 16, 
              Name = $0, 
              Description = $0, 
              Evolved1Name = $668831, 
              Evolved1Description = $690809, 
              Evolved2Name = $0, 
              Evolved2Description = $0
             }, 
             {
              Icon = 16, 
              Name = $0, 
              Description = $0, 
              Evolved1Name = $690810, 
              Evolved1Description = $690811, 
              Evolved2Name = $0, 
              Evolved2Description = $0
             }, 
             {
              Icon = 16, 
              Name = $0, 
              Description = $0, 
              Evolved1Name = $690812, 
              Evolved1Description = $690813, 
              Evolved2Name = $0, 
              Evolved2Description = $0
             }, 
             {
              Icon = 16, 
              Name = $0, 
              Description = $0, 
              Evolved1Name = $690814, 
              Evolved1Description = $690815, 
              Evolved2Name = $690816, 
              Evolved2Description = $690817
             }, 
             {
              Icon = 16, 
              Name = $0, 
              Description = $0, 
              Evolved1Name = $690818, 
              Evolved1Description = $690819, 
              Evolved2Name = $690820, 
              Evolved2Description = $690821
             }, 
             {
              Icon = 16, 
              Name = $0, 
              Description = $0, 
              Evolved1Name = $690822, 
              Evolved1Description = $690823, 
              Evolved2Name = $690824, 
              Evolved2Description = $690825
             }
            )
    PowerName = 'CARNAGE'
    PowerCustomActionID = 15
    DisplayName = $668831
    Description = $690808
    Icon = 16
    TalentDescription = $690808
    IsBonusPower = TRUE
    PowerType = EPowerType.PowerType_Projectile
    VocalizationEvent = ESFXVocalizationEventID.SFXVocalizationEvent_Power_Projectile
}