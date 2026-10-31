// Source: LE3, N7_Vanguard_MP
// Initial decompilation: 9/7/2024 4:00:42 PM
// MILAN CHANGE - UP3
// Apply Biotic Slash's combo evolution in the subsequent-impact detonation path.
Class SFXPowerCustomActionMP_SonicSlash extends SFXPowerCustomActionMP_Slash
    config(Game);

var config float Evolve_Damage1;
var config float Evolve_ImpactRadius;
var config float Evolve_ComboBonus;
var config float Evolve_Cooldown;
var config float Evolve_Damage2;
var config float Evolve_NumShockwavesBonus;

// MILAN CHANGE - UP3 - Apply Biotic Slash combo evolution before subsequent-impact detonation
public function DoSubsequentImpact(Actor HitActor, Vector ImpactLocation, int nImpactCount)
{
    local SFXPawn HitPawn;
    local Vector HitNormal;
    local EPowerResistance Resistance;
    local Actor oTargetOverride;
    local float fDamage;
    local Vector vInitialForce;
    local SFXModule_GameEffectManager Manager;
    local Class<SFXDamageType> dmgType;
    local bool bRagdolled;
    local SFXGameEffect_PowerCombo_Biotic BioticEffect;
    local SFXGameEffect oEffect;
    
    HitNormal = Normal(ImpactLocation - HitActor.location);
    fDamage = GetImpactDamage(HitActor, dmgType);
    if (MaximumRagdollTargets.CurrentValue > float(0) && float(NumTargetsHit) >= MaximumRagdollTargets.CurrentValue)
    {
        dmgType = GetNonRagdollDamageType();
    }
    HitPawn = SFXPawn(HitActor);
    if (HitPawn == None)
    {
        return;
    }
    if (bDoingEarlyImpact)
    {
        PlayDetonationEffects(HitActor.location, HitNormal);
    }
    vInitialForce = Normal(Normal(HitPawn.location - m_oPawn.location) + vect(0.0, 0.0, 1.0)) * Force.CurrentValue;
    Resistance = HitActor.GetPowerResistance(m_oPawn, ImpactLocation, HitNormal, fDamage, vInitialForce, dmgType, oTargetOverride);
    if (oTargetOverride != None)
    {
        HitActor = oTargetOverride;
    }
    HitActor.ImpactWithPower(Resistance, m_oPawn, ImpactLocation, HitNormal, fDamage, vInitialForce, dmgType);
    Manager = HitActor.GetModule(Class'SFXModule_GameEffectManager');
    if (Resistance == EPowerResistance.Resistance_None && GravityEffectDuration > 0.0)
    {
        bRagdolled = TRUE;
        Manager.CreateAndApplyEffect(Class'SFXGameEffect_AntiGravity', Name, GravityEffectDuration, 1, GravityValue, m_oPawn.Controller);
        HitPawn.RegisterRBCallback(OnRagdollPhysicsImpact, TRUE);
    }
    if (Resistance != EPowerResistance.Resistance_Full)
    {
        HitPawn.AddPowerAssistEvent(m_oPawn, DisplayName, bRagdolled ? PowerAssistFullControlValue : PowerAssistPartialControlValue);
    }
    if (nImpactCount == 0)
    {
        if (ImpactActorSound != None)
        {
            HitActor.PlaySound(ImpactActorSound, TRUE);
        }
        if (ImpactActorScreenShakeClass != None)
        {
            PlayPowerScreenShake(ImpactActorScreenShakeClass, ImpactLocation);
        }
    }
    if (Resistance != EPowerResistance.Resistance_Full && Manager != None && IsEvolvedWithChoice(2))
    {
        foreach Manager.GameEffects(oEffect, )
        {
            if (oEffect.Class == Class'SFXGameEffect_PowerCombo_Biotic')
            {
                BioticEffect = SFXGameEffect_PowerCombo_Biotic(oEffect);
                if (BioticEffect != None)
                {
                    BioticEffect.ComboDamage.X *= 1.0 + Evolve_ComboBonus;
                    BioticEffect.ComboDamage.Y *= 1.0 + Evolve_ComboBonus;
                    BioticEffect.ComboForce.X *= 1.0 + Evolve_ComboBonus;
                    BioticEffect.ComboForce.Y *= 1.0 + Evolve_ComboBonus;
                }
            }
        }
    }
    CheckForPowerCombo(HitActor, Resistance, ImpactLocation, HitNormal);
    ImpactedActors.AddItem(HitActor);
    NumTargetsHit++;
    if (HitPawn != None && ShouldReplicate())
    {
        ReplicatePowerSubsequentImpact(HitPawn, HitPawn.CurrentCustomAction);
    }
}
// END MILAN CHANGE
public function bool OnImpact(EPowerResistance Resistance, Actor oImpacted, int nPreviouslyImpacted, Vector HitLocation, Vector HitNormal)
{
    local SFXPawn ImpactedPawn;
    local SFXModule_GameEffectManager Manager;
    local SFXGameEffect_PowerCombo_Biotic BioticEffect;
    local SFXGameEffect oEffect;
    
    ImpactedPawn = SFXPawn(oImpacted);
    if (ImpactedPawn != None && Resistance != EPowerResistance.Resistance_Full)
    {
        Manager = ImpactedPawn.GetModule(Class'SFXModule_GameEffectManager');
        if (Manager != None && IsEvolvedWithChoice(2))
        {
            foreach Manager.GameEffects(oEffect, )
            {
                if (oEffect.Class == Class'SFXGameEffect_PowerCombo_Biotic')
                {
                    BioticEffect = SFXGameEffect_PowerCombo_Biotic(oEffect);
                    if (BioticEffect != None)
                    {
                        BioticEffect.ComboDamage.X *= 1.0 + Evolve_ComboBonus;
                        BioticEffect.ComboDamage.Y *= 1.0 + Evolve_ComboBonus;
                        BioticEffect.ComboForce.X *= 1.0 + Evolve_ComboBonus;
                        BioticEffect.ComboForce.Y *= 1.0 + Evolve_ComboBonus;
                    }
                }
            }
        }
    }
    return Super(SFXPowerCustomAction).OnImpact(Resistance, oImpacted, nPreviouslyImpacted, HitLocation, HitNormal);
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
            AddEvolvedRankBonus(ImpactRadius, Evolve_ImpactRadius);
            AddEvolvedRankBonus(EarlyImpactRadius, Evolve_ImpactRadius);
            break;
        case EEvolveChoice.EvolveChoice3:
            break;
        case EEvolveChoice.EvolveChoice4:
            AddEvolvedRankBonus(CooldownTime, Evolve_Cooldown);
            break;
        case EEvolveChoice.EvolveChoice5:
            AddEvolvedRankBonus(Damage, Evolve_Damage2);
            break;
        case EEvolveChoice.EvolveChoice6:
            AddEvolvedRankBonus(NumShockwaveImpacts, Evolve_NumShockwavesBonus);
            AddEvolvedRankBonus(Range, Evolve_NumShockwavesBonus);
            break;
        default:
    }
    RecalculateAllPowerInfo();
}
public function PopulatePowerStatBarEvolves()
{
    PowerStatBars.Length = 4;
    PowerStatBars[0].Data = CooldownTime;
    PowerStatBars[0].srDisplayTotalToken = StatBarToken_Time;
    PowerStatBars[0].srStatBarDisplayTitle = StatBarTitle_Cooldown;
    PowerStatBars[0].EvolvedBonuses[3] = Evolve_Cooldown;
    PowerStatBars[1].Data = Damage;
    PowerStatBars[1].srDisplayTotalToken = StatBarToken_RawValue;
    PowerStatBars[1].srStatBarDisplayTitle = StatBarTitle_Damage;
    PowerStatBars[1].EvolvedBonuses[0] = Evolve_Damage1;
    PowerStatBars[1].EvolvedBonuses[4] = Evolve_Damage2;
    PowerStatBars[2].Data = Range;
    PowerStatBars[2].Formula = EPowerStatBarFormula.EPowerStatBarFormula_Distance;
    PowerStatBars[2].srDisplayTotalToken = StatBarToken_Distance;
    PowerStatBars[2].srStatBarDisplayTitle = StatBarTitle_Range;
    PowerStatBars[2].EvolvedBonuses[5] = Evolve_NumShockwavesBonus;
    PowerStatBars[3].Data = ImpactRadius;
    PowerStatBars[3].Formula = EPowerStatBarFormula.EPowerStatBarFormula_Distance;
    PowerStatBars[3].srDisplayTotalToken = StatBarToken_Distance;
    PowerStatBars[3].srStatBarDisplayTitle = StatBarTitle_ImpactRadius;
    PowerStatBars[3].EvolvedBonuses[1] = Evolve_ImpactRadius;
}
public function float GetRadiusBonus()
{
    if (IsEvolvedWithChoice(1))
    {
        return Evolve_ImpactRadius;
    }
    return 0.0;
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    Begin Object Class=StaticMeshComponent Name=SwordMesh0
        StaticMesh = StaticMesh'BIOG_WPN_MLE_R.MLEa.WPN_MLEa_MDL_Static'
        ReplacementPrimitive = None
        BlockActors = FALSE
    End Object
    Begin Object Class=BioDynamicAnimSet Name=MY_DYN_HMM_CB_Vanguard_CON_MP3
        m_nmOrigSetName = 'HMM_CB_Vanguard_CON_MP3'
        Sequences = (AnimSequence'BIOG_HMM_CB_CON_MP3.HMM_CB_Vanguard_CON_MP3_CB_Van_SwordSlash')
        m_pBioAnimSetData = BioAnimSetData'BIOG_HMM_CB_CON_MP3.HMM_CB_Vanguard_CON_MP3_BioAnimSetData'
    End Object
    Evolve_Damage1 = 0.300000012
    Evolve_ImpactRadius = 0.300000012
    Evolve_ComboBonus = 0.5
    Evolve_Cooldown = 0.400000006
    Evolve_Damage2 = 0.5
    Evolve_NumShockwavesBonus = 0.5
    Range = {BaseValue = 1500.0}
    NumShockwaveImpacts = {BaseValue = 6.0}
    TimeBetweenImpacts = {BaseValue = 0.100000001}
    EarlyImpactRadius = {BaseValue = 200.0}
    MaximumEarlyImpactTargets = {BaseValue = 3.0}
    ImpactRumbleClass = Class'SFXRumble_Power_HeavyImpact'
    ImpactScreenShakeClass = Class'SFXShake_Power_HeavyImpact'
    EarlyImpactDamageType = Class'SFXDamageType_SonicSlash_NoRagdoll'
    EarlyImpactParameters = {ConeAngle = 180.0, ImpactPlaceables = TRUE, DistancedSorted = TRUE}
    SwordSocket = 'Socket_01'
    CE_Slash = RvrClientEffectMulti'BioVFX_MP3_Sonic_Boom.VCFX.Sonic_Body_Glow_VCFX'
    ImpactActorSound = WwiseEvent'wwise_power_biotic_throw.Play_power_biotic_P_throw_impact'
    EarlySlashSound = WwiseEvent'Wwise_Crt_Cerb_Phtm_SFX.Play_crt_cerb_phantom_sword_swipe'
    CE_ShockwaveImpact = RvrClientEffect'BioVFX_MP3_Sonic_Boom.VCFX.Sonic_xFinal_Imp_VCFX'
    PS_Slice = ParticleSystem'BioVFX_MP3_Sonic_Boom.Particles.Sonic_v1_Slash'
    SliceDistance = 150.0
    SwordMesh = SwordMesh0
    GravityValue = 0.800000012
    GravityEffectDuration = 1.5
    StopMovementDuration = 1.20000005
    EarlyImpactDamagePercent = 0.300000012
    LeaveCoverDistance = 100.0
    ForceEndLeaveCoverTime = 0.200000003
    EarlyImpactTime1 = 0.26666671
    EarlyImpactTime2 = 0.699999988
    ComboDetonators = (Class'SFXGameEffect_PowerCombo_Electric', Class'SFXGameEffect_PowerCombo_Fire', Class'SFXGameEffect_PowerCombo_Biotic')
    BS_StartCastAnimation = {
                             AnimName = ('CB_Van_SwordSlash', 
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
    DefaultDamageType = Class'SFXDamageType_SonicSlash'
    NonRagdollDamageType = Class'SFXDamageType_SonicSlash_NoRagdoll'
    ProjectileClass = Class'SFXProjectile_PowerCustomAction_SonicSlash'
    DetonationParameters = {BlockedByObjects = FALSE}
    ProjectileAttachPoint = 'Root'
    ReleaseTime = 1.5
    CastAnimSet = MY_DYN_HMM_CB_Vanguard_CON_MP3
    CE_ImpactTemplate = RvrClientEffect'BioVFX_MP3_Sonic_Boom.VCFX.Sonic_x1_Imp_VCFX'
    ImpactSound = WwiseEvent'Wwise_Power_Biotic_Shockwave.Play_power_biotic_P_shockwave_ripple'
    ReleaseSound = WwiseEvent'Wwise_Crt_Cerb_Phtm_SFX.Play_crt_cerb_phantom_sword_swipe'
    CastSound = WwiseEvent'Wwise_Power_DLC_SSlash.Play_power_DLC_P_sslash_cast'
    HenchmanImpactSound = WwiseEvent'Wwise_Power_Biotic_Shockwave.Play_power_biotic_NP_shockwave_ripple'
    HenchmanCastSound = WwiseEvent'Wwise_Power_DLC_SSlash.Play_power_DLC_NP_sslash_cast'
    Discipline = EBioCapMode.BIO_CAPMODE_BIOTICS
    CooldownTime = {RankBonuses[1] = 0.25, BaseValue = 5.0, Formula = EPowerDataFormula.DivideByBonusSum}
    MaximumRange = {BaseValue = 6000.0}
    ImpactRadius = {BaseValue = 200.0}
    MaximumImpactTargets = {BaseValue = 3.0}
    MaximumRagdollTargets = {BaseValue = 2.0}
    EffectDuration = {BaseValue = 6.0}
    Damage = {RankBonuses[2] = 0.200000003, BaseValue = 500.0}
    Force = {BaseValue = 300.0}
    Ranks = ({
              Icon = 2, 
              Name = $0, 
              Description = $0, 
              Evolved1Name = $746484, 
              Evolved1Description = $746485, 
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
              Evolved1Name = $754538, 
              Evolved1Description = $754539, 
              Evolved2Name = $0, 
              Evolved2Description = $0
             }, 
             {
              Icon = 2, 
              Name = $0, 
              Description = $0, 
              Evolved1Name = $750682, 
              Evolved1Description = $750683, 
              Evolved2Name = $750684, 
              Evolved2Description = $750685
             }, 
             {
              Icon = 2, 
              Name = $0, 
              Description = $0, 
              Evolved1Name = $750686, 
              Evolved1Description = $750687, 
              Evolved2Name = $750688, 
              Evolved2Description = $750689
             }, 
             {
              Icon = 2, 
              Name = $0, 
              Description = $0, 
              Evolved1Name = $750690, 
              Evolved1Description = $750691, 
              Evolved2Name = $750692, 
              Evolved2Description = $750693
             }
            )
    PowerName = 'SonicSlash'
    PowerCustomActionID = 6
    DisplayName = $746484
    Description = $746485
    Icon = 2
    IconResource = GFxMovieInfo'GUI_SF_SonicSlash.SonicSlash'
    TalentDescription = $746485
    PlayerCameraMode = Class'SFXCameraMode_Slash'
    DamageReductionLength = 1.5
    DamageReductionAmount = 0.5
    fCameraTransitionIn = 1.25
    fCameraTransitionOut = 0.349999994
    bAllowDamageReduction = TRUE
}
