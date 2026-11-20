// Source: ME3, Patch_PowCustAction_ConcussiveShot
// Decompiled 11/17/2026 11:20:16 AM against BioD_ProEar_200.pcc
Class SFXPowerCustomAction_ConcussiveShot extends SFXPowerCustomAction
    config(Game);

var config float Evolve_DoTDamage;
var config float Evolve_DoTDuration;
var config float Evolve_DamageBonus;
var config float Evolve_RadiusBonus;
var config float Evolve_CooldownBonus;
var config float Evolve_FreezeComboBonus;
var config float Evolve_ForceBonus;
var clearcrosslevel SFXPowerCustomAction_AmmoPower AmmoPower;
var RvrClientEffectInterface CE_NormalImpact;
var ParticleSystem MuzzleEffect;
var float MuzzleEffectLifetime;
var float MinTargetDistanceSq;

public function bool OnImpact(Actor.EPowerResistance Resistance, Actor oImpacted, int nPreviouslyImpacted, Object.Vector HitLocation, Object.Vector HitNormal)
{
    local SFXPawn oPawn;
    local float fDamage;
    local Class<SFXDamageType> DamageType;
    local bool bRagdolled;
    
    if (oImpacted == None)
    {
        return FALSE;
    }
    oPawn = SFXPawn(oImpacted);
    if (oPawn != None && Resistance != EPowerResistance.Resistance_Full)
    {
        bRagdolled = Resistance == EPowerResistance.Resistance_None && (MaximumRagdollTargets.CurrentValue == float(0) || float(nPreviouslyImpacted) < MaximumRagdollTargets.CurrentValue);
        oPawn.AddPowerAssistEvent(m_oPawn, DisplayName, bRagdolled ? PowerAssistFullControlValue : PowerAssistPartialControlValue);
        if (bRagdolled)
        {
            oPawn.RegisterRBCallback(OnRagdollPhysicsImpact, TRUE);
        }
        if (IsEvolvedWithChoice(5) && oPawn.RaceType != ERaceType.RaceType_Machine)
        {
            fDamage = GetImpactDamage(oImpacted, DamageType) * Evolve_DoTDamage;
            ApplyTemporaryGameEffect(oImpacted, Class'SFXGameEffect_DamageOverTime', Evolve_DoTDuration, fDamage / Evolve_DoTDuration, Name, m_oPawn.Controller);
        }
    }
    if (IsEvolvedWithChoice(4) && AmmoPower != None)
    {
        AmmoPower.ConcussiveShotCustomImpact(Resistance, oImpacted, nPreviouslyImpacted, HitLocation, HitNormal);
    }
    return TRUE;
}
public static function PrecacheVFX(SFXObjectPool ObjectPool, RvrClientEffectManager ClientEffects)
{
    Super.PrecacheVFX(ObjectPool, ClientEffects);
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
        return ShouldUsePowerOnShields(oPawn, Class'SFXDamageType_ConcussiveShot', sOptionalInfo);
    }
    return TRUE;
}
public function EvolvePower(SFXPowerCustomActionBase.EEvolveChoice choice)
{
    Super(SFXPowerCustomActionBase).EvolvePower(choice);
    switch (choice)
    {
        case EEvolveChoice.EvolveChoice1:
            AddEvolvedRankBonus(Damage, Evolve_DamageBonus);
            AddEvolvedRankBonus(Force, Evolve_DamageBonus);
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
            AddEvolvedRankBonus(Force, Evolve_ForceBonus);
            break;
        default:
    }
    RecalculateAllPowerInfo();
}
public final function Class<SFXDamageType> GetDamageType()
{
    if (IsEvolvedWithChoice(4) && AmmoPower != None && AmmoPower.ConcussiveShotDamageType != None)
    {
        return AmmoPower.ConcussiveShotDamageType;
    }
    else
    {
        return Class'SFXDamageType_ConcussiveShot';
    }
}
public function float GetImpactDamage(Actor oImpacted, out Class<SFXDamageType> DamageType)
{
    local SFXModule_GameEffectManager Manager;
    local float fDamage;
    
    DamageType = GetDamageType();
    fDamage = Damage.CurrentValue;
    if (IsEvolvedWithChoice(2))
    {
        Manager = oImpacted.GetModule(Class'SFXModule_GameEffectManager');
        if (Manager != None)
        {
            if (Manager.HasEffectOfType(Class'SFXGameEffect_DelayedCryoFreeze') || Manager.HasEffectOfType(Class'SFXGameEffect_CryoFreeze'))
            {
                fDamage *= 1.0 + Evolve_FreezeComboBonus;
            }
        }
    }
    return fDamage;
}
public function float GetImpactForce(Actor oImpacted)
{
    local SFXModule_GameEffectManager Manager;
    local float fForce;
    
    fForce = Force.CurrentValue;
    if (IsEvolvedWithChoice(2))
    {
        Manager = oImpacted.GetModule(Class'SFXModule_GameEffectManager');
        if (Manager != None)
        {
            if (Manager.HasEffectOfType(Class'SFXGameEffect_DelayedCryoFreeze') || Manager.HasEffectOfType(Class'SFXGameEffect_CryoFreeze'))
            {
                fForce *= 1.0 + Evolve_FreezeComboBonus;
            }
        }
    }
    return fForce;
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
    if (m_oTargetToAimAt != None && VSizeSq(m_oTargetToAimAt.location - AttachPoint) < MinTargetDistanceSq)
    {
        m_oPawn.GetAimNodeLocation(4, AttachPoint);
    }
    return TRUE;
}
public function OnPowerDetonated(Object.Vector HitLocation, Object.Vector HitNormal, optional SFXProjectile_PowerCustomAction oProjectile, optional Actor HitActor)
{
    Super.OnPowerDetonated(HitLocation, HitNormal, oProjectile, HitActor);
}
public function OnRagdollPhysicsImpact(Pawn oPawn, Actor oImpactActor, Object.Vector vImpactDir)
{
    local BioPawn oBioPawn;
    
    oBioPawn = BioPawn(oPawn);
    if (oBioPawn != None)
    {
        oBioPawn.m_bRagdollEnteredPendingBodyFallSound = TRUE;
    }
    RagdollPhysicsImpact(oPawn, oImpactActor, vImpactDir);
}
public function PlayDetonationEffects(Object.Vector ImpactLocation, Object.Vector ImpactNormal, optional SFXProjectile_PowerCustomAction oProjectile)
{
    Super.PlayDetonationEffects(ImpactLocation, ImpactNormal, oProjectile);
    if (IsEvolvedWithChoice(4) && AmmoPower != None && AmmoPower.CE_ConcussiveShotImpact != None)
    {
        Class'RvrClientEffectManager'.static.GetClientEffectManager().PlayAtLocation(AmmoPower.CE_ConcussiveShotImpact, ImpactLocation, ImpactNormal, GetDefaultClientEffectParams());
        if (AmmoPower.ConcussiveShotImpactSound != None)
        {
            m_oPawn.PlaySound(AmmoPower.ConcussiveShotImpactSound, TRUE, , , ImpactLocation);
        }
    }
    else
    {
        Class'RvrClientEffectManager'.static.GetClientEffectManager().PlayAtLocation(CE_NormalImpact, ImpactLocation, ImpactNormal, GetDefaultClientEffectParams());
    }
}
public function PopulatePowerStatBarEvolves()
{
    PowerStatBars.Length = 3;
    PowerStatBars[0].Data = SFXPawn_Henchman(m_oPawn) == None ? CooldownTime : HenchmanCooldownTime;
    PowerStatBars[0].srDisplayTotalToken = StatBarToken_Time;
    PowerStatBars[0].srStatBarDisplayTitle = StatBarTitle_Cooldown;
    PowerStatBars[0].EvolvedBonuses[3] = Evolve_CooldownBonus;
    PowerStatBars[1].Data = Damage;
    PowerStatBars[1].srDisplayTotalToken = StatBarToken_RawValue;
    PowerStatBars[1].srStatBarDisplayTitle = StatBarTitle_Damage;
    PowerStatBars[1].EvolvedBonuses[0] = Evolve_DamageBonus;
    PowerStatBars[2].Data = Force;
    PowerStatBars[2].srDisplayTotalToken = StatBarToken_Force;
    PowerStatBars[2].srStatBarDisplayTitle = StatBarTitle_Force;
    PowerStatBars[2].EvolvedBonuses[0] = Evolve_DamageBonus;
    PowerStatBars[2].EvolvedBonuses[5] = Evolve_ForceBonus;
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
public function StartPower()
{
    local SFXWeapon Weapon;
    
    Super.StartPower();
    if (IsEvolvedWithChoice(4))
    {
        Weapon = SFXWeapon(m_oPawn.Weapon);
        if (Weapon != None)
        {
            AmmoPower = SFXPowerCustomAction_AmmoPower(Class'SFXPowerCustomAction_AmmoPowerBase'.static.GetSourceAmmoPower(Weapon.AmmoPowerName, Weapon.AmmoPowerSourceTag));
        }
    }
}

// MILAN CHANGE - Mgamerz - 2026-11-17
// Preserve the helper called by LE3's Concussive Shot projectile.
public function RvrClientEffectInterface GetAmmoPowerProjectile()
{
    if (AmmoPower != None)
    {
        return AmmoPower.CE_ConcussiveShotProjectile;
    }
    return None;
}
// END MILAN CHANGE

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    Begin Object Class=BioDynamicAnimSet Name=MY_DYN_HMM_BC_ShotgunSpecial
        m_nmOrigSetName = 'HMM_BC_ShotgunSpecial'
        Sequences = (AnimSequence'BIOG_HMM_BC_A.HMM_BC_ShotgunSpecial_BC_Start', AnimSequence'BIOG_HMM_BC_A.HMM_BC_ShotgunSpecial_BC_End')
        m_pBioAnimSetData = BioAnimSetData'BIOG_HMM_BC_A.HMM_BC_ShotgunSpecial_BioAnimSetData'
    End Object
    Evolve_DoTDamage = 1.0
    Evolve_DoTDuration = 10.0
    Evolve_DamageBonus = 0.300000012
    Evolve_RadiusBonus = 150.0
    Evolve_CooldownBonus = 0.349999994
    Evolve_FreezeComboBonus = 1.0
    Evolve_ForceBonus = 0.5
    CE_NormalImpact = RvrClientEffect'BioVFX_C_FlashBang.VCFX.FlashBang_Generic_Imp_VCFX'
    MuzzleEffect = ParticleSystem'BioVFX_C_Weapons.Muzzles.Particles.Pistol_Muzzle_Magunm'
    MuzzleEffectLifetime = 1.0
    MinTargetDistanceSq = 5625.0
    ComboDetonators = (Class'SFXGameEffect_PowerCombo_Electric', Class'SFXGameEffect_PowerCombo_Fire', Class'SFXGameEffect_PowerCombo_Cryo')
    EvolvedImpactSounds = ({Sound = WwiseEvent'Wwise_Power_Soldier_ConShot.Play_power_soldier_P_concussiveshot_evolimpact', bAnyEvolved = TRUE, bReplaceBaseSound = TRUE, EvolveChoice = EEvolveChoice.EvolveChoice1}
                          )
    EvolvedCastSounds = ({Sound = WwiseEvent'Wwise_Power_Soldier_ConShot.Play_power_soldier_P_concussiveshot_evolcast', bAnyEvolved = TRUE, bReplaceBaseSound = TRUE, EvolveChoice = EEvolveChoice.EvolveChoice1}
                        )
    HenchmanEvolvedImpactSounds = ({Sound = WwiseEvent'Wwise_Power_Soldier_ConShot.Play_power_soldier_NP_concussiveshot_evolimpact', bAnyEvolved = TRUE, bReplaceBaseSound = TRUE, EvolveChoice = EEvolveChoice.EvolveChoice1}
                                  )
    HenchmanEvolvedCastSounds = ({Sound = WwiseEvent'Wwise_Power_Soldier_ConShot.Play_power_soldier_NP_concussiveshot_evolcast', bAnyEvolved = TRUE, bReplaceBaseSound = TRUE, EvolveChoice = EEvolveChoice.EvolveChoice1}
                                )
    NonRagdollDamageType = Class'SFXDamageType_ConcussiveShot_NoRagdoll'
    ProjectileClass = Class'SFXProjectile_PowerCustomAction_ConcussiveShot'
    DetonationRumbleClass = Class'SFXRumble_Power_HeavyImpact'
    DetonationScreenShakeClass = Class'SFXShake_Power_HeavyImpact'
    CastAnimSet = MY_DYN_HMM_BC_ShotgunSpecial
    ImpactSound = WwiseEvent'Wwise_Power_Soldier_ConShot.Play_power_soldier_P_concussiveshot_impact'
    CastSound = WwiseEvent'Wwise_Power_Soldier_ConShot.Play_power_soldier_P_concussiveshot_cast'
    HenchmanImpactSound = WwiseEvent'Wwise_Power_Soldier_ConShot.Play_power_soldier_NP_concussiveshot_impact'
    HenchmanCastSound = WwiseEvent'Wwise_Power_Soldier_ConShot.Play_power_soldier_NP_concussiveshot_cast'
    ImpactDistanceLayer = WwiseEvent'Wwise_Generic_Explosions.Play_power_soldier_P_conshot_distant'
    HenchmanImpactDistanceLayer = WwiseEvent'Wwise_Generic_Explosions.Play_power_soldier_NP_conshot_distant'
    bPlayStartCastAnim = FALSE
    Discipline = EBioCapMode.BIO_CAPMODE_COMBAT
    CooldownTime = {RankBonuses[1] = 0.25, BaseValue = 5.0, Formula = EPowerDataFormula.DivideByBonusSum}
    HenchmanCooldownTime = {RankBonuses[1] = 0.25, BaseValue = 10.0, Formula = EPowerDataFormula.DivideByBonusSum}
    MaximumRange = {BaseValue = 6000.0}
    ImpactRadius = {Formula = EPowerDataFormula.BonusIsHardValue}
    MaximumRagdollTargets = {BaseValue = 1.0}
    EffectDuration = {BaseValue = 1.0}
    Damage = {RankBonuses[2] = 0.200000003, BaseValue = 100.0}
    Force = {RankBonuses[2] = 0.200000003, BaseValue = 300.0}
    ProjectileSpeed = {BaseValue = 3000.0}
    Ranks = ({
              Icon = 44, 
              Name = $0, 
              Description = $0, 
              Evolved1Name = $190258, 
              Evolved1Description = $502601, 
              Evolved2Name = $0, 
              Evolved2Description = $0
             }, 
             {
              Icon = 44, 
              Name = $0, 
              Description = $0, 
              Evolved1Name = $244427, 
              Evolved1Description = $505365, 
              Evolved2Name = $0, 
              Evolved2Description = $0
             }, 
             {
              Icon = 44, 
              Name = $0, 
              Description = $0, 
              Evolved1Name = $244428, 
              Evolved1Description = $190375, 
              Evolved2Name = $0, 
              Evolved2Description = $0
             }, 
             {
              Icon = 44, 
              Name = $0, 
              Description = $0, 
              Evolved1Name = $190921, 
              Evolved1Description = $190922, 
              Evolved2Name = $190917, 
              Evolved2Description = $190918
             }, 
             {
              Icon = 44, 
              Name = $0, 
              Description = $0, 
              Evolved1Name = $505438, 
              Evolved1Description = $505439, 
              Evolved2Name = $505448, 
              Evolved2Description = $505449
             }, 
             {
              Icon = 44, 
              Name = $0, 
              Description = $0, 
              Evolved1Name = $505468, 
              Evolved1Description = $505469, 
              Evolved2Name = $505470, 
              Evolved2Description = $505471
             }
            )
    PowerName = 'ConcussiveShot'
    PowerCustomActionID = 14
    DisplayName = $190258
    Description = $190259
    Icon = 44
    TalentDescription = $190259
    PowerType = EPowerType.PowerType_Projectile
    VocalizationEvent = ESFXVocalizationEventID.SFXVocalizationEvent_Power_Projectile
}