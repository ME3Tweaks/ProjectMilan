// Source: LE3, Vorcha_Soldier_MP
// MILAN CHANGE - Mgamerz - 2026-10-28
// Flamer start/stop sounds are played with bNotReplicated = TRUE, matching SFXCustomAction_VorchaRoar.
// Without it the host replicated its own _p (player, no distance falloff) event to all clients,
// so the host's flamer played at full volume everywhere on the map.
Class SFXPowerCustomActionMP_Flamer extends SFXPowerCustomAction
    config(Game);

var Class<SFXDamageType> DamageType_ImprovedAntiArmor;
var Class<SFXDamageType> DamageType_ImprovedAntiShield;
var Object.Guid GUID_OmniFlamer;
var Name FlamerSocket;
var config float Evolve_Damage1;
var config float Evolve_Damage2;
var config float Evolve_Range;
var config float Evolve_Duration;
var config float Evolve_ArmorMultiplier;
var config float Evolve_ShieldMultiplier;
var float UpdateFrequency;
var RvrClientEffectInterface CE_DeathEffectTemplate;
var RvrClientEffectInterface CE_FireDoTTemplate;
var RvrClientEffectInterface CE_OmniFlamer;
var config float DOTDuration;
var config float DotPercent;
var config float MinimumCooldown;
var float TimeFlamerStarted;
var instanced ParticleSystemComponent PSC_Flamer;
var instanced ParticleSystemComponent PSC_ElectricFlamer;
var float FlamerPSScale;
var WwiseEvent WWise_FlamerStart_Player;
var WwiseEvent WWise_FlamerStart_NonPlayer;
var WwiseEvent WWise_FlamerStop_Player;
var WwiseEvent WWise_FlamerStop_NonPlayer;
var bool bActive;

public function bool OnImpact(Actor.EPowerResistance Resistance, Actor oImpacted, int nPreviouslyImpacted, Object.Vector HitLocation, Object.Vector HitNormal)
{
    local SFXModule_GameEffectManager GEManager;
    local SFXGameEffect_FireDeath DeathEffect;
    local float DoTDamage;
    local SFXGameEffect_FireDamageOverTime DOTEffect;
    local RvrClientEffectInterface.RvrClientEffectTarget CETarget;
    local SFXGameEffect_PowerCombo_Fire FireComboEffect;
    
    if (oImpacted == None)
    {
        return FALSE;
    }
    GEManager = oImpacted.GetModule(Class'SFXModule_GameEffectManager');
    if (GEManager == None)
    {
        return FALSE;
    }
    if (Resistance != EPowerResistance.Resistance_Full)
    {
        if (GEManager.HasEffectOfTypeAndCategory(Class'SFXGameEffect_HealthRegenPenalty', Name) == FALSE)
        {
            ApplyPermanentGameEffect(oImpacted, Class'SFXGameEffect_HealthRegenPenalty', 1.0, Name, m_oPawn.Controller);
        }
        if (GEManager.HasEffectOfTypeAndCategory(Class'SFXGameEffect_FireDeath', Name) == FALSE)
        {
            DeathEffect = SFXGameEffect_FireDeath(GEManager.CreateEffect(Class'SFXGameEffect_FireDeath', Name, DOTDuration, 1, 0.0, m_oPawn.Controller));
            if (DeathEffect != None)
            {
                DeathEffect.CE_DeathEffectTemplate = CE_DeathEffectTemplate;
            }
        }
        DoTDamage = DotPercent * Damage.CurrentValue;
        if (GEManager.HasEffectOfTypeAndCategory(Class'SFXGameEffect_FireDamageOverTime', Name) == FALSE)
        {
            DOTEffect = SFXGameEffect_FireDamageOverTime(GEManager.CreateEffect(Class'SFXGameEffect_FireDamageOverTime', Name, DOTDuration, 1, DoTDamage, m_oPawn.Controller));
            if (DOTEffect != None)
            {
                GetImpactDamage(None, DOTEffect.DamageType);
                DOTEffect.bCanCauseCombo = FALSE;
                DOTEffect.OnApplied();
            }
        }
        else
        {
            DOTEffect = SFXGameEffect_FireDamageOverTime(GEManager.GetFirstEffectOfTypeAndCategory(Class'SFXGameEffect_FireDamageOverTime', Name));
            if (DOTEffect != None)
            {
                DOTEffect.AddFireDamage(DoTDamage, DOTDuration);
            }
        }
        FireComboEffect = SFXGameEffect_PowerCombo_Fire(GEManager.GetFirstEffectOfTypeAndCategory(Class'SFXGameEffect_PowerCombo_Fire', Name));
        if (FireComboEffect != None)
        {
            FireComboEffect.CurrentTime = 0.0;
        }
        else
        {
            AddComboEffect(oImpacted, Class'SFXGameEffect_PowerCombo_Fire', DOTDuration);
        }
        CETarget.Instigator = oImpacted;
        CETarget.SpawnValue.X = DOTDuration;
        Class'RvrClientEffectManager'.static.GetClientEffectManager().PlayOnTarget(CE_FireDoTTemplate, CETarget);
    }
    return TRUE;
}
public event function bool ShouldUsePower(Actor Target, out string sOptionalInfo)
{
    return TRUE;
}
public function StartCustomAction()
{
    local SFXPlayerController PC;
    local RvrClientEffectInterface.RvrClientEffectTarget CETarget;
    local WorldInfo WI;
    
    WI = Class'WorldInfo'.static.GetWorldInfo();
    if (WI != None)
    {
        TimeFlamerStarted = WI.TimeSeconds;
    }
    if (bActive)
    {
        m_oPawn.ClearTimer('FlameOff', Self);
        FlameOff();
    }
    else
    {
        PC = SFXPlayerController(m_oPawn.Controller);
        if (PC != None)
        {
            PC.m_bPermanentWalk = TRUE;
        }
        bActive = TRUE;
        if (m_oPawn != None)
        {
            CETarget.Instigator = m_oPawn;
            GUID_OmniFlamer = Class'RvrClientEffectManager'.static.GetClientEffectManager().StartOnTarget(CE_OmniFlamer, CETarget);
            m_oPawn.LeaveCover();
        }
    }
    Super.StartCustomAction();
}
public function bool CanOverrideMoveWith(int OldCustomAction, int NewCustomAction)
{
    local Class<SFXPowerCustomActionMP_Flamer> NewClass;
    
    NewClass = Class<SFXPowerCustomActionMP_Flamer>(GetCustomActionClass(NewCustomAction));
    if (NewClass != None)
    {
        return TRUE;
    }
    else
    {
        return Super(BioCustomAction).CanOverrideMoveWith(OldCustomAction, NewCustomAction);
    }
}
public function ClientDoPowerSubsequentImpact(Actor oActor, optional int CustomActionReactionType, optional float Duration, optional int ImpactCount, optional float Delay, optional bool DoCallback)
{
    local float InstantDamage;
    local Class<SFXDamageType> CurrentDamageType;
    
    InstantDamage = GetImpactDamage(None, CurrentDamageType);
    DoAreaExplosionForActor(oActor, oActor.location, ImpactCount, InstantDamage, CurrentDamageType, 0.0, DetonationParameters, 0, OnImpact);
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
            AddEvolvedRankBonus(Damage, Evolve_Damage1);
            break;
        case EEvolveChoice.EvolveChoice2:
            AddEvolvedRankBonus(ImpactRadius, Evolve_Range);
            break;
        case EEvolveChoice.EvolveChoice3:
            AddEvolvedRankBonus(Damage, Evolve_Damage2);
            break;
        case EEvolveChoice.EvolveChoice4:
            AddEvolvedRankBonus(EffectDuration, Evolve_Duration);
            break;
        case EEvolveChoice.EvolveChoice5:
            break;
        case EEvolveChoice.EvolveChoice6:
            break;
        default:
    }
    RecalculateAllPowerData();
}
public function float GetImpactDamage(Actor oImpacted, out Class<SFXDamageType> DamageType)
{
    if (IsEvolvedWithChoice(4))
    {
        DamageType = DamageType_ImprovedAntiArmor;
    }
    else if (IsEvolvedWithChoice(5))
    {
        DamageType = DamageType_ImprovedAntiShield;
    }
    else
    {
        DamageType = DefaultDamageType;
    }
    return Damage.CurrentValue * (1.0 - DotPercent) * UpdateFrequency;
}
public function OnPowerDetonated(Object.Vector HitLocation, Object.Vector HitNormal, optional SFXProjectile_PowerCustomAction oProjectile, optional Actor HitActor)
{
    local BioPlayerController PC;
    local SkeletalMeshComponent SMC_Caster;
    
    if (!bActive)
    {
        return;
    }
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
    Super.OnPowerDetonated(HitLocation, HitNormal, oProjectile, HitActor);
    SMC_Caster = m_oPawn.GetPrimarySkelMeshComponent();
    if (SMC_Caster != None)
    {
        if (IsEvolvedWithChoice(5) == TRUE && PSC_ElectricFlamer != None)
        {
            SMC_Caster.AttachComponentToSocket(PSC_ElectricFlamer, FlamerSocket);
            PSC_ElectricFlamer.SetScale(ImpactRadius.CurrentValue / FlamerPSScale);
            PSC_ElectricFlamer.ActivateSystem(TRUE);
        }
        if (PSC_Flamer != None)
        {
            SMC_Caster.AttachComponentToSocket(PSC_Flamer, FlamerSocket);
            PSC_Flamer.SetScale(ImpactRadius.CurrentValue / FlamerPSScale);
            PSC_Flamer.ActivateSystem(TRUE);
        }
    }
    if (m_oPawn.IsLocallyControlled() == TRUE)
    {
        // MILAN CHANGE - Mgamerz - 2026-10-28
        // Do not replicate: every machine already plays the right local/non-local event itself.
        // Replicating sent the host's flat-attenuation _p event to every client.
        m_oPawn.PlaySound(WWise_FlamerStart_Player, TRUE);
        // END MILAN CHANGE
    }
    else
    {
        // MILAN CHANGE - Mgamerz - 2026-10-28
        // Do not replicate: every machine already plays the right local/non-local event itself.
        // Replicating sent the host's flat-attenuation _p event to every client.
        m_oPawn.PlaySound(WWise_FlamerStart_NonPlayer, TRUE);
        // END MILAN CHANGE
    }
    FlameOn();
    m_oPawn.SetTimer(EffectDuration.CurrentValue, FALSE, 'FlameOff', Self);
}
public function PopulatePowerStatBarEvolves()
{
    PowerStatBars.Length = 4;
    PowerStatBars[0].Data = SFXPawn_Henchman(m_oPawn) == None ? CooldownTime : HenchmanCooldownTime;
    PowerStatBars[0].srDisplayTotalToken = StatBarToken_Time;
    PowerStatBars[0].srStatBarDisplayTitle = StatBarTitle_Cooldown;
    PowerStatBars[1].Data = Damage;
    PowerStatBars[1].srDisplayTotalToken = StatBarToken_RawValue;
    PowerStatBars[1].srStatBarDisplayTitle = StatBarTitle_DamagePerSecond;
    PowerStatBars[1].EvolvedBonuses[0] = Evolve_Damage1;
    PowerStatBars[1].EvolvedBonuses[2] = Evolve_Damage2;
    PowerStatBars[2].Data = EffectDuration;
    PowerStatBars[2].srDisplayTotalToken = StatBarToken_Time;
    PowerStatBars[2].srStatBarDisplayTitle = StatBarTitle_Duration;
    PowerStatBars[2].EvolvedBonuses[3] = Evolve_Duration;
    PowerStatBars[3].Data = ImpactRadius;
    PowerStatBars[3].Formula = EPowerStatBarFormula.EPowerStatBarFormula_Distance;
    PowerStatBars[3].srDisplayTotalToken = StatBarToken_Distance;
    PowerStatBars[3].srStatBarDisplayTitle = StatBarTitle_Range;
    PowerStatBars[3].EvolvedBonuses[1] = Evolve_Range;
}
public function RecalculateAllPowerData(optional bool bReset = FALSE)
{
    Super(SFXPowerCustomActionBase).RecalculateAllPowerData(bReset);
}
public function StartPowerCooldown();

public function StopCustomAction()
{
    Super.StopCustomAction();
    m_oPawn.ClearTimer('FlameOff', Self);
    InterruptFlamer();
}
public function FlameOff()
{
    if (m_oPawn != None)
    {
        m_oPawn.InterruptCustomAction();
    }
    else
    {
        InterruptFlamer();
    }
}
public function FlameOn()
{
    local float InstantDamage;
    local Class<SFXDamageType> CurrentDamageType;
    local SkeletalMeshComponent SMC_Caster;
    local Object.Vector SocketLocation;
    local Object.Rotator SocketRotation;
    local float FlamerRange;
    
    if (m_oPawn != None)
    {
        SMC_Caster = m_oPawn.GetPrimarySkelMeshComponent();
    }
    if (SMC_Caster != None)
    {
        SMC_Caster.GetSocketWorldLocationAndRotation(FlamerSocket, SocketLocation, SocketRotation);
    }
    InstantDamage = GetImpactDamage(None, CurrentDamageType);
    DetonationParameters.ConeDirection = Vector(SocketRotation);
    SocketLocation += vect(-100.0, 0.0, 0.0) >> SocketRotation;
    FlamerRange = ImpactRadius.CurrentValue + 100.0;
    AreaExplosion(SocketLocation, FlamerRange, InstantDamage, CurrentDamageType, 0.0, DetonationParameters, 0, OnImpact);
    m_oPawn.SetTimer(UpdateFrequency, FALSE, 'FlameOn', Self);
}
public function InterruptFlamer()
{
    local SFXPlayerController PC;
    local WorldInfo WI;
    local float FlamerTimeActive;
    local float Cooldown;
    
    m_oPawn.ClearTimer('FlameOn', Self);
    bActive = FALSE;
    PC = SFXPlayerController(m_oPawn.Controller);
    if (PC != None)
    {
        PC.m_bPermanentWalk = FALSE;
    }
    WI = Class'WorldInfo'.static.GetWorldInfo();
    if (WI != None)
    {
        FlamerTimeActive = Abs(WI.TimeSeconds - TimeFlamerStarted - ReleaseTime);
        FlamerTimeActive = FMax(FlamerTimeActive, 0.0);
    }
    if (IsEvolvedWithChoice(5) == TRUE && PSC_ElectricFlamer != None)
    {
        PSC_ElectricFlamer.DeactivateSystem();
    }
    if (PSC_Flamer != None)
    {
        PSC_Flamer.DeactivateSystem();
    }
    Class'RvrClientEffectManager'.static.GetClientEffectManager().@Stop(CE_OmniFlamer, GUID_OmniFlamer, TRUE);
    if (m_oPawn.IsLocallyControlled() == TRUE)
    {
        // MILAN CHANGE - Mgamerz - 2026-10-28
        // Do not replicate: every machine already plays the right local/non-local event itself.
        // Replicating sent the host's flat-attenuation _p event to every client.
        m_oPawn.PlaySound(WWise_FlamerStop_Player, TRUE);
        // END MILAN CHANGE
    }
    else
    {
        // MILAN CHANGE - Mgamerz - 2026-10-28
        // Do not replicate: every machine already plays the right local/non-local event itself.
        // Replicating sent the host's flat-attenuation _p event to every client.
        m_oPawn.PlaySound(WWise_FlamerStop_NonPlayer, TRUE);
        // END MILAN CHANGE
    }
    if (EffectDuration.CurrentValue > float(0))
    {
        Cooldown = FMax(MinimumCooldown, Lerp(0.0, GetPowerCooldown(), FlamerTimeActive / EffectDuration.CurrentValue));
        m_oPawn.PowerManager.SetSharedCooldown(Cooldown);
        m_oPawn.PowerManager.PowerReleased(Self);
    }
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    Begin Object Class=BioDynamicAnimSet Name=MY_DYN_HMM_BC_Flamer_MP2
        m_nmOrigSetName = 'HMM_BC_Flamer_MP2'
        Sequences = (AnimSequence'BIOG_HMM_CB_CON_MP2.HMM_BC_Flamer_MP2_HMM_BC_Flamer')
        m_pBioAnimSetData = BioAnimSetData'BIOG_HMM_CB_CON_MP2.HMM_BC_Flamer_MP2_BioAnimSetData'
    End Object
    Begin Object Class=ParticleSystemComponent Name=PSCFlamer0
        Template = ParticleSystem'BioVFX_DLC_MP2_Vorcha.Particles.OmniFlamer_Flamethrower'
        bAutoActivate = FALSE
        ReplacementPrimitive = None
    End Object
    Begin Object Class=ParticleSystemComponent Name=PSCFlamer1
        Template = ParticleSystem'BioVFX_DLC_MP2_Vorcha.Particles.OmniFlamer_Flamethrower_Electric'
        bAutoActivate = FALSE
        ReplacementPrimitive = None
    End Object
    DamageType_ImprovedAntiArmor = Class'SFXDamageType_Flamer_AntiArmor'
    DamageType_ImprovedAntiShield = Class'SFXDamageType_Flamer_AntiShield'
    FlamerSocket = 'FlamerSocket'
    Evolve_Damage1 = 0.300000012
    Evolve_Damage2 = 0.400000006
    Evolve_Range = 0.5
    Evolve_Duration = 0.600000024
    Evolve_ArmorMultiplier = 0.5
    Evolve_ShieldMultiplier = 0.5
    UpdateFrequency = 0.5
    CE_DeathEffectTemplate = RvrClientEffect'BioVFX_C_Fire.VCFX.Fire_Death_VCFX'
    CE_FireDoTTemplate = RvrClientEffect'BioVFX_C_Fire.VCFX.Fire_Dot_VCFX'
    CE_OmniFlamer = RvrClientEffect'BioVFX_DLC_MP2_Vorcha.VCFX.OmniFlamer_VCFX'
    DOTDuration = 5.0
    DotPercent = 0.25
    MinimumCooldown = 1.0
    PSC_Flamer = PSCFlamer0
    PSC_ElectricFlamer = PSCFlamer1
    FlamerPSScale = 500.0
    WWise_FlamerStart_Player = WwiseEvent'Wwise_Power_DLC_MP2_Vor.Play_pwr_vorcha_flamethrower_start_p'
    WWise_FlamerStart_NonPlayer = WwiseEvent'Wwise_Power_DLC_MP2_Vor.Play_pwr_vorcha_flamethrower_start_np'
    WWise_FlamerStop_Player = WwiseEvent'Wwise_Power_DLC_MP2_Vor.Stop_pwr_vorcha_flamethrower_stop_p'
    WWise_FlamerStop_NonPlayer = WwiseEvent'Wwise_Power_DLC_MP2_Vor.Stop_pwr_vorcha_flamethrower_stop_np'
    BS_StartCastAnimation = {
                             AnimName = ('None', 
                                         'HMM_BC_Flamer', 
                                         'HMM_BC_Flamer', 
                                         'HMM_BC_Flamer', 
                                         'HMM_BC_Flamer', 
                                         'HMM_BC_Flamer', 
                                         'HMM_BC_Flamer', 
                                         'HMM_BC_Flamer', 
                                         'None', 
                                         'None', 
                                         'None', 
                                         'HMM_BC_Flamer'
                                        )
                            }
    DefaultDamageType = Class'SFXDamageType_Flamer'
    DetonationParameters = {ConeAngle = 45.0}
    ReleaseTime = 0.200000003
    CastAnimSet = MY_DYN_HMM_BC_Flamer_MP2
    fEndAnimBlendOutTime = 0.300000012
    bCustomImpactLogic = TRUE
    Discipline = EBioCapMode.BIO_CAPMODE_TECH
    CooldownTime = {RankBonuses[1] = 0.25, BaseValue = 8.0, Formula = EPowerDataFormula.DivideByBonusSum}
    MaximumRange = {BaseValue = 6000.0}
    ImpactRadius = {BaseValue = 500.0}
    EffectDuration = {BaseValue = 5.0}
    Damage = {RankBonuses[2] = 0.200000003, BaseValue = 200.0}
    Ranks = ({
              Icon = 2, 
              Name = $0, 
              Description = $0, 
              Evolved1Name = $734212, 
              Evolved1Description = $734232, 
              Evolved2Name = $0, 
              Evolved2Description = $0
             }, 
             {
              Icon = 2, 
              Name = $0, 
              Description = $0, 
              Evolved1Name = $251101, 
              Evolved1Description = $619264, 
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
              Evolved1Name = $731541, 
              Evolved1Description = $734239, 
              Evolved2Name = $155499, 
              Evolved2Description = $734240
             }, 
             {
              Icon = 2, 
              Name = $0, 
              Description = $0, 
              Evolved1Name = $558834, 
              Evolved1Description = $734241, 
              Evolved2Name = $558184, 
              Evolved2Description = $734242
             }
            )
    PowerName = 'Flamer'
    PowerCustomActionID = 6
    DisplayName = $734212
    Description = $734232
    Icon = 2
    IconResource = GFxMovieInfo'GUI_SF_FlameBurst.FlameBurst'
    TalentDescription = $734232
    OverrideList = (Class'SFXCustomAction_Ragdoll', 
                    Class'SFXCustomAction_AnimatedRagdoll', 
                    Class'SFXCustomAction_Frozen', 
                    Class'SFXCustomAction_SwatTurn', 
                    Class'SFXCustomAction_CoverSlipBase', 
                    Class'BioCustomAction_CoverMantle', 
                    Class'BioCustomAction_CoverClimb', 
                    Class'SFXCustomAction_PlayerEvadeBase', 
                    Class'SFXCustomAction_PlayerMeleeBase', 
                    Class'SFXCustomAction_PlayerHeavyMeleeBase', 
                    Class'SFXPowerCustomActionMP_Flamer'
                   )
    bHideWeapon = TRUE
}
