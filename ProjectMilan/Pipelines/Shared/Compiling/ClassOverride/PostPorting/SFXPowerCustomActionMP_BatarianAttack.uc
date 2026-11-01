// Source: LE3, Batarian_Soldier_MP
// Initial decompilation: 9/7/2024 4:00:30 PM
// MILAN CHANGE - UP3
// Preserve Ballistic Blades bleed DPS when duration bonuses extend the effect.
Class SFXPowerCustomActionMP_BatarianAttack extends SFXPowerCustomAction
    config(Game);

var config PowerData BleedDuration;
var config PowerData ConeAngle;
var config PowerData ExplosionDamage;
var config PowerData ExplosionForce;
var config PowerData ExplosionRadius;
var config AreaEffectParameters ExplosionParameters;
var config float ExplosionDelay;
var config float InstantDamagePercent;
var config float Evolve_DamageBonus;
var config float Evolve_ConeBonus;
var config float Evolve_RadiusBonus;
var config float Evolve_RechargeSpeedBonus;
var config float Evolve_DamageComboBonus;
var config float Evolve_DurationComboBonus;
var const ParticleSystem BatarianBladeImpact;
var const ParticleSystem BatarianBladeMuzzle;
var const ParticleSystem BatarianBladeImpactExplosion;
var const ParticleSystem WallImpact;
var const WwiseEvent WallImpactSound;
var config int MaxProjectilesStuck;

public function bool OnImpact(EPowerResistance Resistance, Actor oImpacted, int nPreviouslyImpacted, Vector HitLocation, Vector HitNormal)
{
    local SFXModule_GameEffectManager Manager;
    local SFXGameEffect_BatarianBladeDamageOverTime Effect;
    local SFXDuringAsyncWorkTicker oTicker;
    local float fDamagePerSecond;
    local int ProjectilesFired;
    local Name BoneName;
    local BioPawn BP;
    local float DOTDuration;
    local bool ShouldExplode;
    
    if (oImpacted == None)
    {
        return FALSE;
    }
    Manager = oImpacted.GetModule(Class'SFXModule_GameEffectManager');
    if (Resistance != EPowerResistance.Resistance_Full)
    {
        if (Manager != None)
        {
            // MILAN CHANGE - UP3 - Preserve Ballistic Blades bleed DPS with duration bonuses
            fDamagePerSecond = Damage.CurrentValue * (1.0 - InstantDamagePercent) / BleedDuration.BaseValue;
            // END MILAN CHANGE
            if (IsEvolvedWithChoice(5))
            {
                ShouldExplode = TRUE;
                DOTDuration = ExplosionDelay;
            }
            else
            {
                ShouldExplode = FALSE;
                DOTDuration = BleedDuration.CurrentValue;
            }
            Effect = SFXGameEffect_BatarianBladeDamageOverTime(Manager.CreateEffect(Class'SFXGameEffect_BatarianBladeDamageOverTime', Name, DOTDuration, 1, fDamagePerSecond, m_oPawn.Controller));
            if (Effect != None)
            {
                Effect.DamageType = DefaultDamageType;
                Effect.ExplosionDelay = ExplosionDelay;
                Effect.Power = Self;
                Effect.Caster = SFXPawn(m_oPawn);
                Effect.ShouldExplode = ShouldExplode;
                Effect.OnApplied();
            }
        }
    }
    for (ProjectilesFired = 0; ProjectilesFired < MaxProjectilesStuck; ProjectilesFired++)
    {
        BP = BioPawn(oImpacted);
        if (BP != None)
        {
            BoneName = BP.GetRandomImpactBone();
            if (BoneName != 'None')
            {
                oTicker = SFXGRI(BP.WorldInfo.GRI).DuringAsyncWorker;
                if (oTicker != None)
                {
                    if (IsEvolvedWithChoice(5) && BatarianBladeImpactExplosion != None)
                    {
                        SpawnImpactEffect(m_oPawn.Controller, BatarianBladeImpactExplosion, BP, BP.Mesh.GetBoneLocation(BoneName), Normal(BP.location - m_oPawn.location), BP.Mesh, BoneName);
                        continue;
                    }
                    if (BatarianBladeImpact != None)
                    {
                        SpawnImpactEffect(m_oPawn.Controller, BatarianBladeImpact, BP, BP.Mesh.GetBoneLocation(BoneName), Normal(BP.location - m_oPawn.location), BP.Mesh, BoneName);
                    }
                }
            }
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
    if (Target != None && VSizeSq(Target.location - m_oPawn.location) > ImpactRadius.CurrentValue * ImpactRadius.CurrentValue)
    {
        return FALSE;
    }
    return TRUE;
}
public simulated function SpawnImpactEffect(Controller inInstigator, ParticleSystem Effect, Actor HitActor, Vector HitLocation, Vector HitNormal, PrimitiveComponent HitComponent, Name HitBoneName)
{
    local SFXGRI GRI;
    local ParticleSystemComponent ImpactPSC;
    local float CullDistance;
    local float Distance;
    local SFXPlayerController LocalPlayer;
    
    GRI = SFXGRI(m_oPawn.WorldInfo.GRI);
    LocalPlayer = SFXPlayerController(GRI.GetALocalPlayerController());
    ImpactPSC = GRI.ObjectPool.GetImpactParticleSystemComponent(Effect);
    if (ImpactPSC != None)
    {
        if (HitComponent != None && m_oPawn.WorldInfo.TimeSeconds - HitComponent.LastRenderTime > 1.0)
        {
            return;
        }
        CullDistance = Class'SFXDuringAsyncWorkTicker'.default.PSCCullDistance;
        if (CullDistance != 0.0)
        {
            if (inInstigator != None && inInstigator.IsLocalPlayerController())
            {
                CullDistance += Class'SFXDuringAsyncWorkTicker'.default.LocalPlayerCullDistanceBias;
            }
            Distance = VSize(HitLocation - LocalPlayer.PlayerCamera.CameraCache.POV.location);
            if (Distance * LocalPlayer.LODDistanceFactor > CullDistance)
            {
                return;
            }
        }
        ImpactPSC.SetScale(1.0);
        GRI.ObjectPool.ApplyLODLevel(ImpactPSC, HitLocation);
        GRI.ObjectPool.ApplyBloodColor(ImpactPSC, HitActor);
        GRI.ObjectPool.AttachParticleSystemComponent(ImpactPSC, HitActor, HitComponent, HitBoneName, HitLocation, HitNormal, FALSE);
        ImpactPSC.SetActive(TRUE);
    }
}
public function ApplyBonus(Name Parameter, SFXGameEffect Bonus, optional bool bRemove = FALSE)
{
    Super.ApplyBonus(Parameter, Bonus, bRemove);
    switch (Parameter)
    {
        case 'Damage':
            ApplyBonusToParameter(ExplosionDamage, Bonus, bRemove);
            break;
        case 'Force':
            ApplyBonusToParameter(ExplosionForce, Bonus, bRemove);
            break;
        case 'ImpactRadius':
            ApplyBonusToParameter(ExplosionRadius, Bonus, bRemove);
            break;
        case 'EffectDuration':
            ApplyBonusToParameter(BleedDuration, Bonus, bRemove);
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
            AddEvolvedRankBonus(Damage, Evolve_DamageBonus);
            break;
        case EEvolveChoice.EvolveChoice2:
            AddEvolvedRankBonus(ConeAngle, Evolve_ConeBonus);
            break;
        case EEvolveChoice.EvolveChoice3:
            AddEvolvedRankBonus(ImpactRadius, Evolve_RadiusBonus);
            break;
        case EEvolveChoice.EvolveChoice4:
            AddEvolvedRankBonus(CooldownTime, Evolve_RechargeSpeedBonus);
            break;
        case EEvolveChoice.EvolveChoice5:
            AddEvolvedRankBonus(Damage, Evolve_DamageComboBonus);
            AddEvolvedRankBonus(BleedDuration, Evolve_DurationComboBonus);
            break;
        case EEvolveChoice.EvolveChoice6:
            break;
        default:
    }
    RecalculateAllPowerData();
}
public function float GetImpactDamage(Actor oImpacted, out Class<SFXDamageType> DamageType)
{
    local float DistanceProportion;
    
    DamageType = DefaultDamageType;
    DistanceProportion = GetDistanceProportion(oImpacted);
    return Damage.CurrentValue * DistanceProportion * InstantDamagePercent;
}
public function float GetImpactForce(Actor oImpacted)
{
    local float DistanceProportion;
    local float RandomFactor;
    
    DistanceProportion = GetDistanceProportion(oImpacted);
    RandomFactor = 0.75 + 0.5 * FRand();
    return Force.CurrentValue * DistanceProportion * RandomFactor;
}
public function OnPowerDetonated(Vector HitLocation, Vector HitNormal, optional SFXProjectile_PowerCustomAction oProjectile, optional Actor HitActor)
{
    local BioPlayerController PC;
    local SFXDuringAsyncWorkTicker oTicker;
    local SFXPlayerCamera PlayerCamera;
    local Vector TraceHitLocation;
    local Vector TraceNormal;
    local Actor TraceHitActor;
    local bool TraceReturn;
    
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
    DetonationParameters.ConeAngle = ConeAngle.CurrentValue;
    Super.OnPowerDetonated(HitLocation, HitNormal, oProjectile, HitActor);
    oTicker = SFXGRI(m_oPawn.WorldInfo.GRI).DuringAsyncWorker;
    if (oTicker != None && m_ImpactedActors.Length == 0)
    {
        PlayerCamera = SFXPlayerCamera(PC.PlayerCamera);
        if (PlayerCamera != None)
        {
            TraceReturn = PlayerCamera.GetTrace(TraceHitActor, TraceHitLocation, TraceNormal);
            if (!TraceReturn)
            {
                return;
            }
        }
        PlayImpactSounds(TraceHitLocation, WallImpactSound, EvolvedImpactSounds);
        oTicker.SpawnImpactEffectAtLocation(m_oPawn.Controller, WallImpact, None, TraceHitLocation, -TraceNormal, None, 'None', 1.0);
    }
}
public function PopulatePowerStatBarEvolves()
{
    PowerStatBars.Length = 4;
    PowerStatBars[0].Data = SFXPawn_Henchman(m_oPawn) == None ? CooldownTime : HenchmanCooldownTime;
    PowerStatBars[0].srDisplayTotalToken = StatBarToken_Time;
    PowerStatBars[0].srStatBarDisplayTitle = StatBarTitle_Cooldown;
    PowerStatBars[0].EvolvedBonuses[3] = Evolve_RechargeSpeedBonus;
    PowerStatBars[1].Data = Damage;
    PowerStatBars[1].srDisplayTotalToken = StatBarToken_RawValue;
    PowerStatBars[1].srStatBarDisplayTitle = StatBarTitle_Damage;
    PowerStatBars[1].EvolvedBonuses[0] = Evolve_DamageBonus;
    PowerStatBars[1].EvolvedBonuses[4] = Evolve_DamageComboBonus;
    PowerStatBars[2].Data = BleedDuration;
    PowerStatBars[2].srDisplayTotalToken = StatBarToken_Time;
    PowerStatBars[2].srStatBarDisplayTitle = StatBarTitle_Duration;
    PowerStatBars[2].EvolvedBonuses[4] = Evolve_DurationComboBonus;
    PowerStatBars[3].Data = ImpactRadius;
    PowerStatBars[3].Formula = EPowerStatBarFormula.EPowerStatBarFormula_Distance;
    PowerStatBars[3].srDisplayTotalToken = StatBarToken_Distance;
    PowerStatBars[3].srStatBarDisplayTitle = StatBarTitle_ImpactRadius;
    PowerStatBars[3].EvolvedBonuses[2] = Evolve_RadiusBonus;
}
public function RecalculateAllPowerData(optional bool bReset = FALSE)
{
    Super(SFXPowerCustomActionBase).RecalculateAllPowerData(bReset);
    RecalculatePowerData(BleedDuration, bReset);
    RecalculatePowerData(ConeAngle, bReset);
    RecalculatePowerData(ExplosionDamage, bReset);
    RecalculatePowerData(ExplosionForce, bReset);
    RecalculatePowerData(ExplosionRadius, bReset);
}
public function ReleaseInstantPower()
{
    local Vector Origin;
    local SFXDuringAsyncWorkTicker oTicker;
    
    OnPowerDetonated(m_oPawn.location, vect(0.0, 0.0, 1.0));
    GetProjectileAttachPoint(Origin);
    oTicker = SFXGRI(m_oPawn.WorldInfo.GRI).DuringAsyncWorker;
    if (oTicker != None)
    {
        oTicker.SpawnEffectAtLocation(m_oPawn.Controller, BatarianBladeMuzzle, Origin, Rotator(DetonationParameters.ConeDirection));
    }
}
public function float GetDistanceProportion(Actor oImpacted)
{
    local float DistanceToTarget;
    
    DistanceToTarget = VSize(m_oPawn.location - oImpacted.location);
    return FClamp(1.0 - DistanceToTarget / ImpactRadius.CurrentValue, 0.0, 1.0);
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    Begin Object Class=BioDynamicAnimSet Name=MY_DYN_BAT_CB_Custom_CON_MP1
        m_nmOrigSetName = 'BAT_CB_Custom_CON_MP1'
        Sequences = (AnimSequence'BIOG_HMM_CB_CON_MP1.BAT_CB_Custom_CON_MP1_BC_BAT_Start', AnimSequence'BIOG_HMM_CB_CON_MP1.BAT_CB_Custom_CON_MP1_BC_BAT_End')
        m_pBioAnimSetData = BioAnimSetData'BIOG_HMM_CB_CON_MP1.BioAnimSetData_0'
    End Object
    BleedDuration = {
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
    ConeAngle = {
                 DynamicBonuses = (), 
                 RankBonuses[0] = 0.0, 
                 RankBonuses[1] = 0.0, 
                 RankBonuses[2] = 0.0, 
                 RankBonuses[3] = 0.0, 
                 RankBonuses[4] = 0.0, 
                 RankBonuses[5] = 0.0, 
                 BaseValue = 90.0, 
                 CurrentValue = 0.0, 
                 Formula = EPowerDataFormula.Normal
                }
    ExplosionDamage = {
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
    ExplosionForce = {
                      DynamicBonuses = (), 
                      RankBonuses[0] = 0.0, 
                      RankBonuses[1] = 0.0, 
                      RankBonuses[2] = 0.0, 
                      RankBonuses[3] = 0.0, 
                      RankBonuses[4] = 0.0, 
                      RankBonuses[5] = 0.0, 
                      BaseValue = 800.0, 
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
                       BaseValue = 50.0, 
                       CurrentValue = 0.0, 
                       Formula = EPowerDataFormula.Normal
                      }
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
    ExplosionDelay = 3.0
    InstantDamagePercent = 0.800000012
    Evolve_DamageBonus = 0.300000012
    Evolve_ConeBonus = 20.0
    Evolve_RadiusBonus = 0.5
    Evolve_RechargeSpeedBonus = 0.349999994
    Evolve_DamageComboBonus = 0.5
    Evolve_DurationComboBonus = 0.5
    BatarianBladeImpact = ParticleSystem'BioVFX_DLC_MP1_Bat_2.Particles.SpikeShot_Impact'
    BatarianBladeMuzzle = ParticleSystem'BioVFX_DLC_MP1_Bat_2.Particles.SpikeShot_Muzzle'
    BatarianBladeImpactExplosion = ParticleSystem'BioVFX_DLC_MP1_Bat_2.Particles.SpikeShot_Impact_Explo'
    WallImpact = ParticleSystem'BioVFX_DLC_MP1_Bat_2.Particles.SpikeShot_Wallhit'
    WallImpactSound = WwiseEvent'wwise_weapons_np_widow.Play_wep_np_widow_fire'
    MaxProjectilesStuck = 3
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
    DefaultDamageType = Class'SFXDamageType_BatarianBlade'
    DetonationRumbleClass = Class'SFXRumble_Power_HeavyImpact'
    DetonationScreenShakeClass = Class'SFXShake_Power_BatarianAttack'
    ReleaseTime = 0.730000019
    CastAnimSet = MY_DYN_BAT_CB_Custom_CON_MP1
    CastCameraAnim = CameraAnim'BioVFX_C_CamAnim.Powers.BC_ThrowBiotic'
    CE_CasterCrustTemplate = RvrClientEffect'BioVFX_DLC_MP1_Bat_2.VCFX.BatSpikeShot_Tool_VCFX'
    ImpactSound = WwiseEvent'Wwise_Weapons_NP_Graal.Play_wep_np_graal_fire'
    CastSound = WwiseEvent'Wwise_Power_DLC_BladeVolley.Play_power_DLC_P_bladevolley_cast'
    HenchmanImpactSound = WwiseEvent'Wwise_Power_DLC_BladeVolley.Play_power_DLC_P_bladevolley_impact'
    HenchmanCastSound = WwiseEvent'Wwise_Power_DLC_BladeVolley.Play_power_DLC_NP_bladevolley_cast'
    Discipline = EBioCapMode.BIO_CAPMODE_COMBAT
    CooldownTime = {RankBonuses[1] = 0.25, BaseValue = 8.0, Formula = EPowerDataFormula.DivideByBonusSum}
    MaximumRange = {BaseValue = 6000.0}
    ImpactRadius = {BaseValue = 1200.0}
    MaximumImpactTargets = {BaseValue = 3.0}
    Damage = {RankBonuses[2] = 0.200000003, BaseValue = 800.0}
    Force = {BaseValue = 800.0}
    Ranks = ({
              Icon = 2, 
              Name = $0, 
              Description = $0, 
              Evolved1Name = $727737, 
              Evolved1Description = $727739, 
              Evolved2Name = $0, 
              Evolved2Description = $0
             }, 
             {
              Icon = 2, 
              Name = $0, 
              Description = $0, 
              Evolved1Name = $727740, 
              Evolved1Description = $727741, 
              Evolved2Name = $0, 
              Evolved2Description = $0
             }, 
             {
              Icon = 2, 
              Name = $0, 
              Description = $0, 
              Evolved1Name = $727742, 
              Evolved1Description = $727743, 
              Evolved2Name = $0, 
              Evolved2Description = $0
             }, 
             {
              Icon = 2, 
              Name = $0, 
              Description = $0, 
              Evolved1Name = $727744, 
              Evolved1Description = $727745, 
              Evolved2Name = $727748, 
              Evolved2Description = $727749
             }, 
             {
              Icon = 2, 
              Name = $0, 
              Description = $0, 
              Evolved1Name = $727746, 
              Evolved1Description = $727747, 
              Evolved2Name = $727750, 
              Evolved2Description = $727751
             }, 
             {
              Icon = 2, 
              Name = $0, 
              Description = $0, 
              Evolved1Name = $727752, 
              Evolved1Description = $727753, 
              Evolved2Name = $727754, 
              Evolved2Description = $727755
             }
            )
    PowerName = 'BatarianAttack'
    PowerCustomActionID = 36
    DisplayName = $727737
    Description = $727739
    Icon = 2
    IconResource = GFxMovieInfo'GUI_SF_BladeVolley.BladeVolley'
    TalentDescription = $727739
    bHideWeapon = TRUE
}
