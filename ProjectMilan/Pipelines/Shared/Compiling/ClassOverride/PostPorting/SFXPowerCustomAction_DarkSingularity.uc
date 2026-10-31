// Source: LE3, Collector_Adept_MP
// Initial decompilation: 9/7/2024 5:13:18 PM
// MILAN CHANGE - UP3
// Correct Dark Sphere damage-over-time duration and DPS
Class SFXPowerCustomAction_DarkSingularity extends SFXPowerCustomAction
    config(Game);

var config PowerData DoTDamage;
var config PowerData DoTRadius;
var config PowerData DOTDuration;
var BodyStance BS_DetonateAnimation;
var array<BioPawn> TrackedPawns;
var array<Actor> ImpactedActors;
var Guid HandChargeGUID;
var Guid OmniToolGuid;
var config float Evolve_DamageBonus1;
var config float Evolve_DamageBonus2;
var config float Evolve_DoTDamage;
var config float Evolve_DOTDamage1;
var config float Evolve_DOTDuration1;
var config float Evolve_DOTDamage2;
var config float Evolve_DOTDuration2;
var config float Evolve_RadiusBonus;
var config float Evolve_RadiusBonus2;
var config float Evolve_NegativeRadiusBonus;
var config float Evolve_CooldownBonus;
var config float ArmingDelay;
var config float TimeBetweenImpacts;
var config int MaxComboTargets;
var AnimSet DetonateAnimSet;
var float DetonateReleaseTime;
var SFXProjectile_PowerCustomAction_DarkSingularity ActiveMine;
var int NumTargetsHit;
var WwiseEvent PlayerChargeStartSound;
var WwiseEvent NonPlayerChargeStartSound;
var bool bOmniToolActive;

public function bool CanUsePower(Actor oTarget)
{
    if (m_oPawn.Role == ENetRole.ROLE_SimulatedProxy)
    {
        return TRUE;
    }
    if (!bEnabled || Rank < 1.0)
    {
        return FALSE;
    }
    if (ActiveMine == None && m_oPawn.PowerManager.GetSharedCooldown() > float(0))
    {
        return FALSE;
    }
    return TRUE;
}
public function StartCustomAction()
{
    if (ActiveMine != None)
    {
        LeanOutToCast = FALSE;
        CastAnimSet = DetonateAnimSet;
        BS_EndCastAnimation = BS_DetonateAnimation;
        ReleaseTime = DetonateReleaseTime;
    }
    else
    {
        LeanOutToCast = default.LeanOutToCast;
        CastAnimSet = default.CastAnimSet;
        BS_EndCastAnimation = default.BS_EndCastAnimation;
        ReleaseTime = default.ReleaseTime;
        if (m_oPawn.IsLocallyControlled())
        {
            m_oPawn.PlaySound(PlayerChargeStartSound, TRUE);
        }
        else
        {
            m_oPawn.PlaySound(NonPlayerChargeStartSound, TRUE);
        }
    }
    Super.StartCustomAction();
}
public function ApplyBonus(Name Parameter, SFXGameEffect Bonus, optional bool bRemove = FALSE)
{
    Super.ApplyBonus(Parameter, Bonus, bRemove);
    switch (Parameter)
    {
        case 'Damage':
            ApplyBonusToParameter(DoTDamage, Bonus, bRemove);
            break;
        default:
    }
}
public function DoImpact(Vector location, Rotator ProjectileRotation)
{
    local SFXGameEffect_CollectorDamageOverTime DamageEffect;
    local SFXGameEffect_PowerCombo_Biotic ComboEffect;
    local SFXModule_GameEffectManager Manager;
    local EPowerResistance Resistance;
    local SFXPawn oPawn;
    local Vector Momentum;
    local float fDamage;
    local Actor HitActor;
    local Actor TargetOverride;
    local array<Actor> NearbyActors;
    
    ImpactedActors.Length = 0;
    NumTargetsHit = 0;
    GetNearbyActors(NearbyActors, location, ImpactRadius.CurrentValue, ImpactRadius.CurrentValue, DetonationParameters);
    foreach NearbyActors(HitActor, )
    {
        oPawn = SFXPawn(HitActor);
        if (oPawn == None)
        {
            continue;
        }
        if (float(NumTargetsHit) >= MaximumImpactTargets.CurrentValue)
        {
            return;
        }
        if (ImpactedActors.Find(HitActor) != -1)
        {
            continue;
        }
        Resistance = HitActor.GetPowerResistance(m_oPawn, location, -Vector(ProjectileRotation), fDamage, Momentum, DefaultDamageType, TargetOverride);
        if (TargetOverride != None)
        {
            oPawn = SFXPawn(TargetOverride);
            if (oPawn == None)
            {
                continue;
            }
        }
        if (Resistance != EPowerResistance.Resistance_Full)
        {
            Manager = oPawn.GetModule(Class'SFXModule_GameEffectManager');
            if (Manager == None)
            {
                continue;
            }
            DamageEffect = SFXGameEffect_CollectorDamageOverTime(Manager.GetFirstEffectOfTypeAndCategory(Class'SFXGameEffect_CollectorDamageOverTime', Name));
            if (DamageEffect != None)
            {
                DamageEffect.CurrentTime = 0.0;
            }
            else
            {
                // MILAN CHANGE - UP3 - Use the evolved DoT lifetime without diluting Dark Sphere DPS
                DamageEffect = SFXGameEffect_CollectorDamageOverTime(Manager.CreateEffect(Class'SFXGameEffect_CollectorDamageOverTime', Name, DOTDuration.CurrentValue, 1, DoTDamage.CurrentValue / DOTDuration.BaseValue, m_oPawn.Controller, m_oPawn));
                // END MILAN CHANGE
                if (DamageEffect != None)
                {
                    DamageEffect.DamageType = DefaultDamageType;
                    DamageEffect.OnApplied();
                }
            }
            if (TrackedPawns.Length < MaxComboTargets && TrackedPawns.Find(oPawn) == -1)
            {
                TrackedPawns.AddItem(oPawn);
                ComboEffect = SFXGameEffect_PowerCombo_Biotic(Manager.GetFirstEffectOfTypeAndCategory(Class'SFXGameEffect_PowerCombo_Biotic', Name));
                if (ComboEffect != None)
                {
                    ComboEffect.CurrentTime = 0.0;
                }
                else
                {
                    AddComboEffect(oPawn, Class'SFXGameEffect_PowerCombo_Biotic', DOTDuration.CurrentValue);
                }
            }
            NumTargetsHit++;
        }
    }
}
public function DoJoinInProgress()
{
    Super(SFXPowerCustomActionBase).DoJoinInProgress();
    if (ShouldReplicate())
    {
        if (ActiveMine != None)
        {
            if (ActiveMine.bStuck)
            {
                ActiveMine.ReplicateStick(ActiveMine.StuckTo, ActiveMine.location, -Vector(ActiveMine.Rotation), -1);
            }
        }
        m_oPawn.SetTimer(3.0, FALSE, 'DelayedDoJoinInProgress', Self);
    }
}
public function EvolvePower(EEvolveChoice choice)
{
    Super(SFXPowerCustomActionBase).EvolvePower(choice);
    switch (choice)
    {
        case EEvolveChoice.EvolveChoice1:
            AddEvolvedRankBonus(Damage, Evolve_DamageBonus1);
            AddEvolvedRankBonus(DoTDamage, Evolve_DoTDamage);
            break;
        case EEvolveChoice.EvolveChoice2:
            AddEvolvedRankBonus(ImpactRadius, Evolve_RadiusBonus);
            break;
        case EEvolveChoice.EvolveChoice3:
            AddEvolvedRankBonus(DoTDamage, Evolve_DOTDamage1);
            AddEvolvedRankBonus(DOTDuration, Evolve_DOTDuration1);
            break;
        case EEvolveChoice.EvolveChoice4:
            AddEvolvedRankBonus(CooldownTime, Evolve_CooldownBonus);
            break;
        case EEvolveChoice.EvolveChoice5:
            AddEvolvedRankBonus(Damage, Evolve_DamageBonus2);
            AddEvolvedRankBonus(ImpactRadius, -Evolve_NegativeRadiusBonus);
            break;
        case EEvolveChoice.EvolveChoice6:
            AddEvolvedRankBonus(ImpactRadius, Evolve_RadiusBonus2);
            AddEvolvedRankBonus(DoTDamage, Evolve_DOTDamage2);
            AddEvolvedRankBonus(DOTDuration, Evolve_DOTDuration2);
            break;
        default:
    }
    RecalculateAllPowerInfo();
}
public function bool GetProjectileAttachPoint(out Vector AttachPoint)
{
    local Rotator Rotation;
    
    if (SFXWeapon(m_oPawn.Weapon) != None && SkeletalMeshComponent(m_oPawn.Weapon.Mesh) != None)
    {
        if (SkeletalMeshComponent(m_oPawn.Weapon.Mesh).GetSocketWorldLocationAndRotation(SFXWeapon(m_oPawn.Weapon).MuzzleSocketName, AttachPoint, Rotation) == FALSE)
        {
            AttachPoint = m_oPawn.location;
        }
    }
    return TRUE;
}
public function OnOwnerDestroyed()
{
    Super(SFXPowerCustomActionBase).OnOwnerDestroyed();
    if (m_oPawn != None && m_oPawn.Role == ENetRole.ROLE_Authority && ActiveMine != None)
    {
        ActiveMine.DetonateMine();
        ActiveMine = None;
    }
}
public function PopulatePowerStatBarEvolves()
{
    PowerStatBars.Length = 5;
    PowerStatBars[0].Data = SFXPawn_Henchman(m_oPawn) == None ? CooldownTime : HenchmanCooldownTime;
    PowerStatBars[0].srDisplayTotalToken = StatBarToken_Time;
    PowerStatBars[0].srStatBarDisplayTitle = $814593;
    PowerStatBars[0].EvolvedBonuses[3] = Evolve_CooldownBonus;
    PowerStatBars[1].Data = Damage;
    PowerStatBars[1].srDisplayTotalToken = StatBarToken_RawValue;
    PowerStatBars[1].srStatBarDisplayTitle = StatBarTitle_Damage;
    PowerStatBars[1].srStatBarDisplayTitle = $814537;
    PowerStatBars[1].EvolvedBonuses[0] = Evolve_DamageBonus1;
    PowerStatBars[1].EvolvedBonuses[4] = Evolve_DamageBonus2;
    PowerStatBars[2].Data = ImpactRadius;
    PowerStatBars[2].Formula = EPowerStatBarFormula.EPowerStatBarFormula_Distance;
    PowerStatBars[2].srDisplayTotalToken = StatBarToken_Distance;
    PowerStatBars[2].srStatBarDisplayTitle = $814536;
    PowerStatBars[2].EvolvedBonuses[1] = Evolve_RadiusBonus;
    PowerStatBars[2].EvolvedBonuses[5] = Evolve_RadiusBonus2;
    PowerStatBars[3].Data = DoTDamage;
    PowerStatBars[3].srDisplayTotalToken = StatBarToken_RawValue;
    PowerStatBars[3].srStatBarDisplayTitle = StatBarTitle_DamagePerSecond;
    PowerStatBars[3].srStatBarDisplayTitle = $808659;
    PowerStatBars[3].EvolvedBonuses[0] = Evolve_DoTDamage;
    PowerStatBars[3].EvolvedBonuses[2] = Evolve_DOTDamage1;
    PowerStatBars[3].EvolvedBonuses[5] = Evolve_DOTDamage2;
    PowerStatBars[4].Data = DOTDuration;
    PowerStatBars[4].srDisplayTotalToken = StatBarToken_Time;
    PowerStatBars[4].srStatBarDisplayTitle = StatBarTitle_DamagePerSecond;
    PowerStatBars[4].srStatBarDisplayTitle = $814441;
    PowerStatBars[4].EvolvedBonuses[2] = Evolve_DOTDuration1;
    PowerStatBars[4].EvolvedBonuses[5] = Evolve_DOTDuration2;
}
public function RecalculateAllPowerData(optional bool bReset = FALSE)
{
    Super(SFXPowerCustomActionBase).RecalculateAllPowerData(bReset);
    RecalculatePowerData(DoTDamage, bReset);
    RecalculatePowerData(DoTRadius, bReset);
    RecalculatePowerData(DOTDuration, bReset);
}
public function ReleasePower()
{
    local SFXModule_GameEffectManager Manager;
    
    TrackedPawns.Length = 0;
    Manager = m_oPawn.GetModule(Class'SFXModule_GameEffectManager');
    if (Manager == None)
    {
        return;
    }
    bPowerStarted = FALSE;
    bPowerReleased = TRUE;
    if (ActiveMine != None)
    {
        if (ActiveMine.DetonateMine())
        {
            ActiveMine = None;
        }
        StartPowerCooldown();
        return;
    }
    if (m_oPawn == None || m_oPawn.Role == ENetRole.ROLE_SimulatedProxy || m_oPawn.Role == ENetRole.ROLE_AutonomousProxy && ProjectileClass.default.bClientPredictProjectile == FALSE)
    {
    }
    else
    {
        ActiveMine = SFXProjectile_PowerCustomAction_DarkSingularity(ReleaseProjectilePower());
    }
    PlayReleaseEffects();
    if (m_oPawn != None && m_oPawn.PowerManager != None)
    {
        m_oPawn.PowerManager.PowerReleased(Self);
    }
    if (m_oPawn.IsLocallyControlled() && m_oPawn.IsHumanControlled())
    {
        PlayCasterSounds(ReleaseSound, EvolvedReleaseSounds);
    }
    else
    {
        PlayCasterSounds(HenchmanReleaseSound, HenchmanEvolvedReleaseSounds);
    }
}
public function StartPower()
{
    local RvrClientEffectTarget TargetInfo;
    
    TimeSinceStart = 0.0;
    bPowerReleased = FALSE;
    bPowerStarted = TRUE;
    if (m_oPawn.PowerManager.DisableCasterCrusts <= 0)
    {
        if (CE_CasterCrustTemplate != None && ActiveMine == None)
        {
            TargetInfo.Instigator = m_oPawn;
            HandChargeGUID = Class'RvrClientEffectManager'.static.GetClientEffectManager().StartOnTarget(CE_CasterCrustTemplate, TargetInfo, m_oPawn);
        }
    }
    if (m_oPawn.IsBlindFiring() == FALSE)
    {
        if (m_oPawn.IsLocallyControlled() && m_oPawn.IsHumanControlled())
        {
            PlayCasterSounds(CastSound, EvolvedCastSounds);
        }
        else
        {
            PlayCasterSounds(HenchmanCastSound, HenchmanEvolvedCastSounds);
        }
    }
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
    m_oPawn.PowerManager.SetSharedCooldown(GetPowerCooldown());
}
public function StopCustomAction()
{
    Super.StopCustomAction();
    Class'RvrClientEffectManager'.static.GetClientEffectManager().Stop(CE_CasterCrustTemplate, HandChargeGUID, FALSE);
}
public function DelayedDoJoinInProgress()
{
    local int idx;
    
    for (idx = 0; idx < TrackedPawns.Length; idx++)
    {
        if (TrackedPawns[idx] != None)
        {
            ReplicatePowerSubsequentImpact(TrackedPawns[idx], , , -1);
        }
    }
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    Begin Object Class=BioDynamicAnimSet Name=MY_DYN_PRT_BC_Blast
        m_nmOrigSetName = 'PRT_BC_Blast'
        Sequences = (AnimSequence'BIOG_DLC_MP5_CBT_A.PRT_BC_Blast_PRT_BC_Orb_Throw')
        m_pBioAnimSetData = BioAnimSetData'BIOG_DLC_MP5_CBT_A.PRT_BC_Blast_BioAnimSetData'
    End Object
    DoTDamage = {
                 DynamicBonuses = (), 
                 RankBonuses[0] = 0.0, 
                 RankBonuses[1] = 0.0, 
                 RankBonuses[2] = 0.150000006, 
                 RankBonuses[3] = 0.0, 
                 RankBonuses[4] = 0.0, 
                 RankBonuses[5] = 0.0, 
                 BaseValue = 250.0, 
                 CurrentValue = 0.0, 
                 Formula = EPowerDataFormula.Normal
                }
    DoTRadius = {
                 DynamicBonuses = (), 
                 RankBonuses[0] = 0.0, 
                 RankBonuses[1] = 0.0, 
                 RankBonuses[2] = 0.0, 
                 RankBonuses[3] = 0.0, 
                 RankBonuses[4] = 0.0, 
                 RankBonuses[5] = 0.0, 
                 BaseValue = 225.0, 
                 CurrentValue = 0.0, 
                 Formula = EPowerDataFormula.Normal
                }
    DOTDuration = {
                   DynamicBonuses = (), 
                   RankBonuses[0] = 0.0, 
                   RankBonuses[1] = 0.0, 
                   RankBonuses[2] = 0.0, 
                   RankBonuses[3] = 0.0, 
                   RankBonuses[4] = 0.0, 
                   RankBonuses[5] = 0.0, 
                   BaseValue = 5.0, 
                   CurrentValue = 0.0, 
                   Formula = EPowerDataFormula.Normal
                  }
    BS_DetonateAnimation = {
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
    Evolve_DamageBonus1 = 0.300000012
    Evolve_DamageBonus2 = 1.0
    Evolve_DoTDamage = 0.200000003
    Evolve_DOTDamage1 = 0.400000006
    Evolve_DOTDuration1 = 0.400000006
    Evolve_DOTDamage2 = 0.400000006
    Evolve_DOTDuration2 = 0.400000006
    Evolve_RadiusBonus = 0.400000006
    Evolve_RadiusBonus2 = 0.400000006
    Evolve_NegativeRadiusBonus = 0.5
    Evolve_CooldownBonus = 0.349999994
    TimeBetweenImpacts = 0.200000003
    MaxComboTargets = 3
    DetonateAnimSet = AnimSet'BIOG_HMM_BC_A.HMM_BC_RifleTechToolActivate'
    PlayerChargeStartSound = WwiseEvent'Wwise_Power_MP5_Collector.Play_pwr_DLC_darksphere_cast_P'
    NonPlayerChargeStartSound = WwiseEvent'Wwise_Power_MP5_Collector.Play_pwr_DLC_darksphere_cast_NP'
    BS_EndCastAnimation = {
                           AnimName = ('PRT_BC_Orb_Throw', 
                                       'None', 
                                       'None', 
                                       'None', 
                                       'None', 
                                       'None', 
                                       'None', 
                                       'None', 
                                       'None', 
                                       'None', 
                                       'None', 
                                       'None'
                                      )
                          }
    DefaultDamageType = Class'SFXDamageType_DarkSingularity'
    ProjectileClass = Class'SFXProjectile_PowerCustomAction_DarkSingularity'
    DetonationRumbleClass = Class'SFXRumble_Power_HeavyImpact'
    DetonationScreenShakeClass = Class'SFXShake_Power_HeavyImpact'
    DetonationParameters = {BlockedByObjects = FALSE}
    ReleaseTime = 0.882700026
    CastAnimSet = MY_DYN_PRT_BC_Blast
    CastCameraAnim = CameraAnim'BioVFX_C_CamAnim.Powers.BC_ThrowBiotic'
    CE_CasterCrustTemplate = RvrClientEffect'BioVFX_MP5_Prothean.VCFX.DarkSphere_HandCharge'
    CE_ReleaseEffectTemplate = RvrClientEffect'BioVFX_Hch_Prothean.VCFX.DarkChannel_Charge_VCFX'
    bPlayStartCastAnim = FALSE
    Discipline = EBioCapMode.BIO_CAPMODE_BIOTICS
    CooldownTime = {RankBonuses[1] = 0.150000006, BaseValue = 24.0, Formula = EPowerDataFormula.DivideByBonusSum}
    MaximumRange = {BaseValue = 6000.0}
    ImpactRadius = {BaseValue = 500.0}
    MaximumImpactTargets = {BaseValue = 3.0}
    EffectDuration = {BaseValue = 5.0}
    Damage = {RankBonuses[2] = 0.200000003, BaseValue = 1000.0}
    Force = {BaseValue = 1500.0}
    ProjectileSpeed = {BaseValue = 550.0}
    Ranks = ({
              Icon = 2, 
              Name = $0, 
              Description = $0, 
              Evolved1Name = $808407, 
              Evolved1Description = $806023, 
              Evolved2Name = $0, 
              Evolved2Description = $0
             }, 
             {
              Icon = 2, 
              Name = $0, 
              Description = $0, 
              Evolved1Name = $572669, 
              Evolved1Description = $572674, 
              Evolved2Name = $0, 
              Evolved2Description = $0
             }, 
             {
              Icon = 2, 
              Name = $0, 
              Description = $0, 
              Evolved1Name = $572670, 
              Evolved1Description = $814538, 
              Evolved2Name = $0, 
              Evolved2Description = $0
             }, 
             {
              Icon = 2, 
              Name = $0, 
              Description = $0, 
              Evolved1Name = $572670, 
              Evolved1Description = $808656, 
              Evolved2Name = $808657, 
              Evolved2Description = $808658
             }, 
             {
              Icon = 2, 
              Name = $0, 
              Description = $0, 
              Evolved1Name = $808659, 
              Evolved1Description = $808671, 
              Evolved2Name = $572669, 
              Evolved2Description = $808672
             }, 
             {
              Icon = 2, 
              Name = $0, 
              Description = $0, 
              Evolved1Name = $808673, 
              Evolved1Description = $808674, 
              Evolved2Name = $808675, 
              Evolved2Description = $808697
             }
            )
    PowerName = 'DarkSingularity'
    PowerCustomActionID = 29
    DisplayName = $808407
    Description = $806023
    Icon = 2
    IconResource = GFxMovieInfo'GUI_SF_DarkSphere.DarkSphere'
    TalentDescription = $806023
    UsesSharedCooldown = FALSE
    PowerType = EPowerType.PowerType_Projectile
    bBreakFromCover = TRUE
    bHideWeapon = TRUE
}
