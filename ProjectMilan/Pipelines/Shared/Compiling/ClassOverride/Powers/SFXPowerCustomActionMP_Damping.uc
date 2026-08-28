// 08/27/2026 - Mgamerz
// Added HeadshotDamageModifier to properly account for headshot damage bonus
// Fixed Rank 5A not accounting for headshot damage (requires changes to SFXGame)
// Added Rank 5A Shieldgate reduction effect (requires changes to SFXGame)
// Fixed Rank 5B applying effects backwards (both have same value, so it was not obvious)
Class SFXPowerCustomActionMP_Damping extends SFXPowerCustomAction
    config(Game);

var config PowerData AdditionalDamageTaken;
var config PowerData MovementSpeedModifier;
var config PowerData HeadshotDamageModifier; // MILAN CHANGE 08/27/2026 - Mgamerz: Added to properly account for headshot damage bonus
var config PowerData TargetShieldgateModifier; // MILAN CHANGE 08/27/2026 - Mgamerz: Added to buff Rank 5A because headshots suck with shieldgating
var config array<Name> InstantKillEnemies;
var Guid PlayerScanVFXGuid;
var Guid TargetScanVFXGuid;
var Guid PlayerOmniToolVFXGuid;
var Guid PlayerOmniToolInfoVFXGuid;
var Guid PlayerOmniToolScanBeamVFXGuid;
var Rotator InitialRot;
var Vector HealthColor;
var Vector ArmorColor;
var Vector ShieldColor;
var Vector BioticColor;
var Name DampingUniqueCategory;
var Name GlowActorUniqueCategory;
var config Vector2D EnemySizeRange;
var config Vector2D HoloMeshScaleRange;
var config Vector2D HighlightSizeRange;
var config float Evolve_WeaponDamageBonus;
var config float Evolve_PowerDamageBonus;
var float Evolve_HeadShotBonus;
var config float Evolve_MovementSpeedBonus;
var config float Evolve_DamageTakenBonus;
var config float Evolve_DurationBonus;
var config float Evolve_AreaScanRadius;
var config float Evolve_AreaScanDuration;
var config float Evolve_ShieldGateReduction;
var RvrClientEffectInterface CE_PlayerScanTemplate;
var RvrClientEffectInterface CE_TargetScanTemplate;
var RvrClientEffectInterface CE_PlayerOmniToolTemplate;
var RvrClientEffectInterface CE_PlayerOmniToolInfoTemplate;
var RvrClientEffectInterface CE_PlayerOmniToolScanBeamTemplate;
var BioPawn CurrentlyAffectedPawn;
var SkeletalMeshActorSpawnable CurrentPawnMeshCopy;
var SFXEmitter HologramEmitter;
var SFXEmitter HologramDistanceEmitter;
var SFXEmitter TargetEmitter;
var ParticleSystem PS_HealthShieldTemplate;
var ParticleSystem PS_HoloHealthShieldTemplate;
var ParticleSystem PS_HoloDistanceTemplate;
var config float AttachMeshDelay;
var config float ShowDistanceMeterDelay;
var config float UpdatePawnFrequency;
var config float HoloHighlightSize;
var config float HoloHealthBarSize;
var config float ShutOffOmniToolDelay;
var WwiseEvent ScanImpactSound;
var bool bOmniToolActive;

public function bool OnImpact(EPowerResistance Resistance, Actor oImpacted, int nPreviouslyImpacted, Vector HitLocation, Vector HitNormal)
{
    local SFXPawn oTargetPawn;
    local SFXModule_GameEffectManager Manager;
    local RvrClientEffectTarget TargetInfo;
    local float fPawnSize;
    local float fVFXScale;
    local Vector vScale;
    local int idx;
    
    oTargetPawn = SFXPawn(oImpacted);
    if (oTargetPawn == None)
    {
        return FALSE;
    }
    for (idx = 0; idx < InstantKillEnemies.Length; idx++)
    {
        if (oTargetPawn.IsA(InstantKillEnemies[idx]))
        {
            oTargetPawn.TakeDamage(100000.0, m_oPawn.Controller, oTargetPawn.location, vect(0.0, 0.0, 0.0), DefaultDamageType);
            return FALSE;
        }
    }
    Manager = oTargetPawn.GetModule(Class'SFXModule_GameEffectManager');
    if (Manager == None)
    {
        return FALSE;
    }
    if (Manager.HasEffectOfCategory(DampingUniqueCategory))
    {
        return FALSE;
    }
    oTargetPawn.AddPowerAssistEvent(m_oPawn, DisplayName, PowerAssistPartialControlValue);
    CurrentlyAffectedPawn = oTargetPawn;
    m_oPawn.ClearTimer('StopOmniTool', Self);
    if (m_oPawn.IsLocallyControlled())
    {
        TargetInfo.Instigator = oImpacted;
        PlayerScanVFXGuid = Class'RvrClientEffectManager'.static.GetClientEffectManager().StartOnTarget(CE_PlayerScanTemplate, TargetInfo, m_oPawn);
        m_oPawn.SetTimer(AttachMeshDelay, FALSE, 'AttachMeshToPlayer', Self);
    }
    fPawnSize = (CurrentlyAffectedPawn.default.BaseEyeHeight - EnemySizeRange.Y) / (EnemySizeRange.X - EnemySizeRange.Y);
    fVFXScale = Lerp(HighlightSizeRange.Y, HighlightSizeRange.X, FClamp(fPawnSize, 0.0, 1.0));
    TargetEmitter = m_oPawn.Spawn(Class'SFXEmitter', m_oPawn, 'QuarianScanTarget', oImpacted.location, oImpacted.Rotation, , TRUE, FALSE);
    if (TargetEmitter != None)
    {
        TargetEmitter.SetTemplate(PS_HealthShieldTemplate);
        TargetEmitter.SetBase(CurrentlyAffectedPawn, , CurrentlyAffectedPawn.Mesh, 'Root');
        TargetEmitter.ParticleSystemComponent.SetDepthPriorityGroup(2);
        TargetEmitter.ParticleSystemComponent.SetActive(TRUE);
        vScale.X = fVFXScale;
        vScale.Y = fVFXScale;
        vScale.Z = fVFXScale;
        TargetEmitter.SetVectorParameter('V_Scale', vScale);
        UpdateHealthShieldParameters();
    }
    TargetInfo.Instigator = oImpacted;
    TargetInfo.SpawnValue.Y = fVFXScale;
    TargetScanVFXGuid = Class'RvrClientEffectManager'.static.GetClientEffectManager().StartOnTarget(CE_TargetScanTemplate, TargetInfo, oImpacted);
    oImpacted.PlaySound(ScanImpactSound, TRUE);
    ApplyTemporaryGameEffect(oImpacted, Class'SFXGameEffect_DamageTakenBonus', EffectDuration.CurrentValue, AdditionalDamageTaken.CurrentValue, DampingUniqueCategory, m_oPawn.Controller);
    if (IsEvolvedWithChoice(0))
    {
        ApplyTemporaryGameEffect(oImpacted, Class'SFXGameEffect_WeaponDamageTakenBonus', EffectDuration.CurrentValue, Evolve_WeaponDamageBonus, DampingUniqueCategory, m_oPawn.Controller);
    }
    if (IsEvolvedWithChoice(1))
    {
        ApplyTemporaryGameEffect(oImpacted, Class'SFXGameEffect_PowerDamageTakenBonus', EffectDuration.CurrentValue, Evolve_PowerDamageBonus, DampingUniqueCategory, m_oPawn.Controller);
    }
    if (IsEvolvedWithChoice(2))
    {
        // MILAN CHANGE 08/27/2026 - Mgamerz
        // Repoint to new game effect that hooks into the new SFXDamageModule headshot calculation code
        ApplyTemporaryGameEffect(oImpacted, Class'SFXGameEffect_HeadshotDamageDebuff', EffectDuration.CurrentValue, Evolve_HeadShotBonus, DampingUniqueCategory, m_oPawn.Controller);
        // Also add new shield gate bypass to help make this evolution more worth choosing
        ApplyTemporaryGameEffect(oImpacted, Class'SFXGameEffect_ShieldGateReduction', EffectDuration.CurrentValue, 1.0, DampingUniqueCategory, m_oPawn.Controller);
        // END MILAN CHANGE
    }
    ApplyTemporaryGameEffect(oImpacted, Class'SFXGameEffect_MovementSpeedBonus', EffectDuration.CurrentValue, -MovementSpeedModifier.CurrentValue, DampingUniqueCategory, m_oPawn.Controller);
    CreateGlowActor(oTargetPawn, EffectDuration.CurrentValue);
    if (IsEvolvedWithChoice(5))
    {
        CreateNearbyPawnGlowActors(oTargetPawn);
    }
    m_oPawn.SetTimer(UpdatePawnFrequency, TRUE, 'UpdateTarget', Self);
    m_oPawn.SetTimer(EffectDuration.CurrentValue, FALSE, 'ScanComplete', Self);
    return TRUE;
}
public function EvolvePower(EEvolveChoice choice)
{
    Super(SFXPowerCustomActionBase).EvolvePower(choice);
    switch (choice)
    {
        case EEvolveChoice.EvolveChoice1:
            break;
        case EEvolveChoice.EvolveChoice2:
            break;
        case EEvolveChoice.EvolveChoice3:
            // MILAN CHANGE 08/27/2026 - Mgamerz
            // Fix headshot (requires changes to sfxgame) evolution
            // Add shield gate modifier to power as well.
            AddEvolvedRankBonus(HeadshotDamageModifier, Evolve_HeadShotBonus);
            AddEvolvedRankBonus(HeadshotDamageModifier, Evolve_ShieldGateReduction);
            // END MILAN CHANGE
            break;
        case EEvolveChoice.EvolveChoice4:
            AddEvolvedRankBonus(MovementSpeedModifier, Evolve_MovementSpeedBonus);
            break;
        case EEvolveChoice.EvolveChoice5:
            AddEvolvedRankBonus(AdditionalDamageTaken, Evolve_DamageTakenBonus);
            break;
        case EEvolveChoice.EvolveChoice6:
            AddEvolvedRankBonus(EffectDuration, Evolve_DurationBonus);
            break;
        default:
    }
    RecalculateAllPowerInfo();
}
public function PopulatePowerStatBarEvolves()
{
    PowerStatBars.Length = 4;
    PowerStatBars[0].Data = SFXPawn_Henchman(m_oPawn) == None ? CooldownTime : HenchmanCooldownTime;
    PowerStatBars[0].srDisplayTotalToken = StatBarToken_Time;
    PowerStatBars[0].srStatBarDisplayTitle = StatBarTitle_Cooldown;
    // MILAN CHANGE - Removed headshot damage stats that originally appeared here as they were pointless.
    PowerStatBars[1].Data = EffectDuration;
    PowerStatBars[1].srDisplayTotalToken = StatBarToken_Time;
    PowerStatBars[1].srStatBarDisplayTitle = StatBarTitle_Duration;
    PowerStatBars[1].EvolvedBonuses[5] = Evolve_DurationBonus;
    PowerStatBars[2].Data = AdditionalDamageTaken;
    PowerStatBars[2].srDisplayTotalToken = StatBarToken_Percent;
    PowerStatBars[2].srStatBarDisplayTitle = $732754;
    PowerStatBars[2].Formula = EPowerStatBarFormula.EPowerStatBarFormula_Percent;
    PowerStatBars[2].EvolvedBonuses[4] = Evolve_DamageTakenBonus;
    PowerStatBars[3].Data = MovementSpeedModifier;
    PowerStatBars[3].srDisplayTotalToken = StatBarToken_Percent;
    PowerStatBars[3].srStatBarDisplayTitle = $732755;
    PowerStatBars[3].Formula = EPowerStatBarFormula.EPowerStatBarFormula_Percent;
    PowerStatBars[3].EvolvedBonuses[3] = Evolve_MovementSpeedBonus;
}
public function RecalculateAllPowerData(optional bool bReset = FALSE)
{
    Super(SFXPowerCustomActionBase).RecalculateAllPowerData(bReset);
    RecalculatePowerData(AdditionalDamageTaken, bReset);
    RecalculatePowerData(MovementSpeedModifier, bReset);
    RecalculatePowerData(HeadshotDamageModifier, bReset); // MILAN CHANGE - Recalculate changes
    RecalculatePowerData(TargetShieldgateModifier, bReset); // MILAN CHANGE - Recalculate changes
}
public function ReleaseInstantPower()
{
    if (m_oTargetToAimAt != None)
    {
        OnPowerDetonated(m_oTargetToAimAt.location, vect(0.0, 0.0, 1.0), None, m_oTargetToAimAt);
    }
    else
    {
        OnPowerDetonated(m_oPawn.location, vect(0.0, 0.0, 1.0), None, None);
        if (IsEvolvedWithChoice(5))
        {
            CreateNearbyPawnGlowActors(m_oPawn);
        }
    }
}
public function StartPower()
{
    local BioPlayerController PC;
    
    StopCurrentTargetScan(FALSE);
    PC = BioPlayerController(m_oPawn.Controller);
    if (PC != None && m_oPawn.IsLocallyControlled())
    {
        if (PC.m_oPlayerSelection.m_oCurrentSelectionTarget != None)
        {
            m_oTargetToAimAt = PC.m_oPlayerSelection.m_oCurrentSelectionTarget;
        }
        else
        {
            m_oTargetToAimAt = None;
        }
    }
    Super.StartPower();
    SetOmniToolEnabled(TRUE);
    m_oPawn.SetTimer(ShutOffOmniToolDelay, FALSE, 'StopOmniTool', Self);
}
public function StopOmniTool()
{
    SetOmniToolEnabled(FALSE);
}
public function AttachMeshToPlayer()
{
    local SkeletalMeshActorSpawnable oMeshSpawnable;
    local SkeletalMeshComponent TargetSkelMesh;
    local bool bMeshFound;
    local float fPawnSize;
    local float fMeshDrawScale;
    local Vector vScale;
    local RvrClientEffectTarget TargetInfo;
    
    if (CurrentlyAffectedPawn == None)
    {
        return;
    }
    TargetSkelMesh = CurrentlyAffectedPawn.GetPrimarySkelMeshComponent();
    foreach m_oPawn.DynamicActors(Class'SkeletalMeshActorSpawnable', oMeshSpawnable, )
    {
        if (oMeshSpawnable.SkeletalMeshComponent.SkeletalMesh == TargetSkelMesh.SkeletalMesh)
        {
            oMeshSpawnable.SetBase(m_oPawn, , m_oPawn.Mesh, 'Scan01');
            oMeshSpawnable.bIgnoreBaseRotation = TRUE;
            oMeshSpawnable.SetRotation(CurrentlyAffectedPawn.Rotation + InitialRot);
            fPawnSize = (CurrentlyAffectedPawn.default.BaseEyeHeight - EnemySizeRange.Y) / (EnemySizeRange.X - EnemySizeRange.Y);
            fMeshDrawScale = Lerp(HoloMeshScaleRange.Y, HoloMeshScaleRange.X, FClamp(fPawnSize, 0.0, 1.0));
            oMeshSpawnable.SetDrawScale(fMeshDrawScale);
            CurrentPawnMeshCopy = oMeshSpawnable;
            TargetInfo.Instigator = m_oPawn;
            PlayerOmniToolScanBeamVFXGuid = Class'RvrClientEffectManager'.static.GetClientEffectManager().StartOnTarget(CE_PlayerOmniToolScanBeamTemplate, TargetInfo, m_oPawn);
            TargetInfo.SpawnValue.Y = HoloHighlightSize;
            PlayerOmniToolInfoVFXGuid = Class'RvrClientEffectManager'.static.GetClientEffectManager().StartOnTarget(CE_PlayerOmniToolInfoTemplate, TargetInfo, m_oPawn);
            HologramEmitter = m_oPawn.Spawn(Class'SFXEmitter', m_oPawn, 'QuarianScanHologram', m_oPawn.location, m_oPawn.Rotation, , TRUE, FALSE);
            if (HologramEmitter != None)
            {
                HologramEmitter.SetTemplate(PS_HoloHealthShieldTemplate);
                HologramEmitter.SetBase(m_oPawn, , m_oPawn.Mesh, 'Scan01');
                HologramEmitter.ParticleSystemComponent.SetActive(TRUE);
                vScale.X = HoloHealthBarSize;
                vScale.Y = HoloHealthBarSize;
                vScale.Z = HoloHealthBarSize;
                HologramEmitter.SetVectorParameter('V_Scale', vScale);
                UpdateHealthShieldParameters();
            }
            m_oPawn.SetTimer(ShowDistanceMeterDelay, FALSE, 'ShowDistanceMeter', Self);
            bMeshFound = TRUE;
            break;
        }
    }
    if (!bMeshFound)
    {
        m_oPawn.SetTimer(AttachMeshDelay, FALSE, 'AttachMeshToPlayer', Self);
    }
}
public function CreateGlowActor(BioPawn Target, float fDuration)
{
    local SFXModule_GameEffectManager Manager;
    local SFXGameEffect_ScanGlowActor GlowEffect;
    
    Manager = Target.GetModule(Class'SFXModule_GameEffectManager');
    if (Manager != None)
    {
        GlowEffect = SFXGameEffect_ScanGlowActor(Manager.GetFirstEffectOfType(Class'SFXGameEffect_ScanGlowActor'));
        if (GlowEffect != None)
        {
            if (GlowEffect.Duration - GlowEffect.CurrentTime < fDuration)
            {
                GlowEffect.CurrentTime = 0.0;
                GlowEffect.Duration = fDuration;
            }
        }
        else
        {
            Manager.CreateAndApplyEffect(Class'SFXGameEffect_ScanGlowActor', GlowActorUniqueCategory, fDuration, 1, MaximumRange.CurrentValue, m_oPawn.Controller, m_oPawn);
        }
    }
}
public function CreateNearbyPawnGlowActors(BioPawn SourcePawn)
{
    local BioPawn NearbyPawn;
    
    if (SourcePawn == None)
    {
        return;
    }
    foreach m_oPawn.WorldInfo.AllPawns(Class'BioPawn', NearbyPawn, SourcePawn.location, Evolve_AreaScanRadius)
    {
        if (!NearbyPawn.IsDead() && NearbyPawn.GetTeam().TeamIndex == 1)
        {
            CreateGlowActor(NearbyPawn, Evolve_AreaScanDuration);
        }
    }
}
public function ScanComplete()
{
    StopCurrentTargetScan(TRUE);
}
public function SetOmniToolEnabled(bool bEnable)
{
    local RvrClientEffectTarget TargetInfo;
    
    if (bEnable && !bOmniToolActive)
    {
        TargetInfo.Instigator = m_oPawn;
        PlayerOmniToolVFXGuid = Class'RvrClientEffectManager'.static.GetClientEffectManager().StartOnTarget(CE_PlayerOmniToolTemplate, TargetInfo, m_oPawn);
        bOmniToolActive = TRUE;
    }
    else if (!bEnable && bOmniToolActive)
    {
        if (PlayerOmniToolVFXGuid.A != 0 || PlayerOmniToolVFXGuid.B != 0 || PlayerOmniToolVFXGuid.C != 0 || PlayerOmniToolVFXGuid.D != 0)
        {
            Class'RvrClientEffectManager'.static.GetClientEffectManager().@Stop(CE_PlayerOmniToolTemplate, PlayerOmniToolVFXGuid, TRUE);
        }
        bOmniToolActive = FALSE;
    }
}
public function ShowDistanceMeter()
{
    if (CurrentlyAffectedPawn != None)
    {
        HologramDistanceEmitter = m_oPawn.Spawn(Class'SFXEmitter', m_oPawn, 'QuarianScanDistHologram', m_oPawn.location, m_oPawn.Rotation, , TRUE, FALSE);
        if (HologramDistanceEmitter != None)
        {
            HologramDistanceEmitter.SetTemplate(PS_HoloDistanceTemplate);
            HologramDistanceEmitter.SetBase(m_oPawn, , m_oPawn.Mesh, 'Scan01');
            HologramDistanceEmitter.ParticleSystemComponent.SetActive(TRUE);
        }
    }
}
public function StopCurrentTargetScan(bool bStopOmniTool)
{
    local SFXModule_GameEffectManager Manager;
    
    if (bStopOmniTool)
    {
        SetOmniToolEnabled(FALSE);
    }
    if (PlayerScanVFXGuid.A != 0 || PlayerScanVFXGuid.B != 0 || PlayerScanVFXGuid.C != 0 || PlayerScanVFXGuid.D != 0)
    {
        Class'RvrClientEffectManager'.static.GetClientEffectManager().@Stop(CE_PlayerScanTemplate, PlayerScanVFXGuid, TRUE);
    }
    if (TargetScanVFXGuid.A != 0 || TargetScanVFXGuid.B != 0 || TargetScanVFXGuid.C != 0 || TargetScanVFXGuid.D != 0)
    {
        Class'RvrClientEffectManager'.static.GetClientEffectManager().@Stop(CE_TargetScanTemplate, TargetScanVFXGuid, TRUE);
    }
    if (PlayerOmniToolInfoVFXGuid.A != 0 || PlayerOmniToolInfoVFXGuid.B != 0 || PlayerOmniToolInfoVFXGuid.C != 0 || PlayerOmniToolInfoVFXGuid.D != 0)
    {
        Class'RvrClientEffectManager'.static.GetClientEffectManager().@Stop(CE_PlayerOmniToolInfoTemplate, PlayerOmniToolInfoVFXGuid, TRUE);
    }
    if (PlayerOmniToolScanBeamVFXGuid.A != 0 || PlayerOmniToolScanBeamVFXGuid.B != 0 || PlayerOmniToolScanBeamVFXGuid.C != 0 || PlayerOmniToolScanBeamVFXGuid.D != 0)
    {
        Class'RvrClientEffectManager'.static.GetClientEffectManager().@Stop(CE_PlayerOmniToolScanBeamTemplate, PlayerOmniToolScanBeamVFXGuid, TRUE);
    }
    if (CurrentPawnMeshCopy != None)
    {
        CurrentPawnMeshCopy.Destroy();
        CurrentPawnMeshCopy = None;
    }
    if (TargetEmitter != None)
    {
        TargetEmitter.SetLifetime(0.100000001);
        TargetEmitter.ParticleSystemComponent.SetActive(FALSE);
        TargetEmitter.Destroy();
        TargetEmitter = None;
    }
    if (HologramEmitter != None)
    {
        HologramEmitter.SetLifetime(0.100000001);
        HologramEmitter.ParticleSystemComponent.SetActive(FALSE);
        HologramEmitter.Destroy();
        HologramEmitter = None;
    }
    if (HologramDistanceEmitter != None)
    {
        HologramDistanceEmitter.SetLifetime(0.100000001);
        HologramDistanceEmitter.ParticleSystemComponent.SetActive(FALSE);
        HologramDistanceEmitter.Destroy();
        HologramDistanceEmitter = None;
    }
    if (CurrentlyAffectedPawn != None)
    {
        Manager = CurrentlyAffectedPawn.GetModule(Class'SFXModule_GameEffectManager');
        if (Manager != None)
        {
            Manager.RemoveEffectsByCategory(DampingUniqueCategory);
            Manager.RemoveEffectsByCategory(GlowActorUniqueCategory);
        }
        CurrentlyAffectedPawn = None;
    }
    m_oPawn.ClearTimer('UpdateTarget', Self);
    m_oPawn.ClearTimer('ScanComplete', Self);
}
public function UpdateHealthShieldParameters()
{
    local float fHealthParam;
    local float fShieldParam;
    local bool bHasShields;
    local Vector vBar1Color;
    local Vector vBar2Color;
    
    if (CurrentlyAffectedPawn == None)
    {
        return;
    }
    if (CurrentlyAffectedPawn.HasResistance(3))
    {
        vBar1Color = ArmorColor;
    }
    else
    {
        vBar1Color = HealthColor;
    }
    fHealthParam = CurrentlyAffectedPawn.GetCurrentHealth() / CurrentlyAffectedPawn.GetMaxHealth();
    if (CurrentlyAffectedPawn.HasResistance(2))
    {
        vBar2Color = BioticColor;
        bHasShields = TRUE;
    }
    else if (CurrentlyAffectedPawn.HasResistance(1))
    {
        vBar2Color = ShieldColor;
        bHasShields = TRUE;
    }
    if (bHasShields)
    {
        fShieldParam = CurrentlyAffectedPawn.GetCurrentShields() / CurrentlyAffectedPawn.GetMaxShields();
    }
    else
    {
        fShieldParam = 0.0;
    }
    if (HologramEmitter != None)
    {
        HologramEmitter.SetVectorParameter('Bar_1_V', vBar1Color);
        HologramEmitter.SetFloatParameter('Bar_1_F', fHealthParam);
        HologramEmitter.SetVectorParameter('Bar_2_V', vBar2Color);
        HologramEmitter.SetFloatParameter('Bar_2_F', fShieldParam);
    }
    if (TargetEmitter != None)
    {
        TargetEmitter.SetVectorParameter('Bar_1_V', vBar1Color);
        TargetEmitter.SetFloatParameter('Bar_1_F', fHealthParam);
        TargetEmitter.SetVectorParameter('Bar_2_V', vBar2Color);
        TargetEmitter.SetFloatParameter('Bar_2_F', fShieldParam);
    }
}
public function UpdateTarget()
{
    local int nDistToTarget;
    
    if (CurrentlyAffectedPawn == None || CurrentlyAffectedPawn.IsDead())
    {
        m_oPawn.ClearTimer('UpdateTarget', Self);
        StopCurrentTargetScan(TRUE);
        return;
    }
    UpdateHealthShieldParameters();
    if (CurrentPawnMeshCopy != None)
    {
        CurrentPawnMeshCopy.SetRotation(CurrentlyAffectedPawn.Rotation);
    }
    if (HologramDistanceEmitter != None)
    {
        nDistToTarget = Round(VSize(CurrentlyAffectedPawn.location - m_oPawn.location) / 100.0);
        HologramDistanceEmitter.SetFloatParameter('D1', float(nDistToTarget / 100));
        nDistToTarget = nDistToTarget % 100;
        HologramDistanceEmitter.SetFloatParameter('D2', float(nDistToTarget / 10));
        nDistToTarget = nDistToTarget % 10;
        HologramDistanceEmitter.SetFloatParameter('D3', float(nDistToTarget));
    }
}

defaultproperties
{
    Begin Object Class=BioDynamicAnimSet Name=MY_DYN_HMM_CB_PistolAiScan_CON_MP2
        m_nmOrigSetName = 'HMM_CB_PistolAiScan_CON_MP2'
        Sequences = (AnimSequence'BIOG_HMM_CB_CON_MP2.HMM_CB_PistolAiScan_CON_MP2_BC_AiScan_Start', AnimSequence'BIOG_HMM_CB_CON_MP2.HMM_CB_PistolAiScan_CON_MP2_BC_AiScan_StdCov_Start', AnimSequence'BIOG_HMM_CB_CON_MP2.HMM_CB_PistolAiScan_CON_MP2_BC_AiScan_MidCov_Start', AnimSequence'BIOG_HMM_CB_CON_MP2.HMM_CB_PistolAiScan_CON_MP2_BC_AiScan_End', AnimSequence'BIOG_HMM_CB_CON_MP2.HMM_CB_PistolAiScan_CON_MP2_BC_AiScan_StdCov_End', AnimSequence'BIOG_HMM_CB_CON_MP2.HMM_CB_PistolAiScan_CON_MP2_BC_AiScan_MidCov_End')
        m_pBioAnimSetData = BioAnimSetData'BIOG_HMM_CB_CON_MP2.HMM_CB_PistolAiScan_CON_MP2_BioAnimSetData'
    End Object
    AdditionalDamageTaken = {
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
    MovementSpeedModifier = {
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
    // MILAN CHANGE 08/27/2026 - Mgamerz
    // Added HeadshotDamageModifier to properly account for headshot damage bonus
    HeadshotDamageModifier = {
                              DynamicBonuses = (), 
                              RankBonuses[0] = 0.0, 
                              RankBonuses[1] = 0.0, 
                              RankBonuses[2] = 0.0, 
                              RankBonuses[3] = 0.0, 
                              RankBonuses[4] = 0.0, 
                              RankBonuses[5] = 0.0, 
                              BaseValue = 25.0, 
                              CurrentValue = 0.0, 
                              Formula = EPowerDataFormula.BonusIsHardValue
                             }
    // END MILAN CHANGE
    InstantKillEnemies = ('SFXPawn_GethPrimeTurret', 'SFXPawn_GethPrimeShieldDrone')
    HealthColor = {X = 1.0, Y = 0.100000001, Z = 0.100000001}
    ArmorColor = {X = 1.0, Y = 0.5, Z = 0.100000001}
    ShieldColor = {X = 0.100000001, Y = 0.5, Z = 1.0}
    BioticColor = {X = 0.349999994, Y = 0.200000003, Z = 0.800000012}
    DampingUniqueCategory = 'DampingPowerEffect'
    GlowActorUniqueCategory = 'GlowActorPowerEffect'
    EnemySizeRange = {X = 130.0, Y = 40.0}
    HoloMeshScaleRange = {X = 0.0350000001, Y = 0.109999999}
    HighlightSizeRange = {X = 1.79999995, Y = 0.449999988}
    Evolve_WeaponDamageBonus = 0.075000003
    Evolve_PowerDamageBonus = 0.075000003
    Evolve_HeadShotBonus = 0.25
    Evolve_MovementSpeedBonus = 0.150000006
    Evolve_DamageTakenBonus = 0.100000001
    Evolve_DurationBonus = 1.0
    Evolve_AreaScanRadius = 2000.0
    Evolve_AreaScanDuration = 3.0
    Evolve_ShieldGateReduction = 0.25
    CE_PlayerScanTemplate = RvrClientEffect'BioVFX_DLC_MaleQuarian.VCFX.Scan_Info_Crust'
    CE_TargetScanTemplate = RvrClientEffect'BioVFX_DLC_MaleQuarian.VCFX.Scan_Info_Target_VCFX'
    CE_PlayerOmniToolTemplate = RvrClientEffectMulti'BioVFX_T_TechPowers._OmniTool.VCFX.OmniTool_RightFull_VCFX_M'
    CE_PlayerOmniToolInfoTemplate = RvrClientEffect'BioVFX_DLC_MaleQuarian.VCFX.Scan_Info_Wrist'
    CE_PlayerOmniToolScanBeamTemplate = RvrClientEffect'BioVFX_DLC_MaleQuarian.VCFX.OmniTool_ScanBeams_VCFX'
    PS_HealthShieldTemplate = ParticleSystem'BioVFX_DLC_MaleQuarian.Particles.Scan_Hud_Shields_Ind'
    PS_HoloHealthShieldTemplate = ParticleSystem'BioVFX_DLC_MaleQuarian.Particles.Scan_Hud_Shields_Ind_Player'
    PS_HoloDistanceTemplate = ParticleSystem'BioVFX_DLC_MaleQuarian.Particles.Scan_Emitter_Distance'
    AttachMeshDelay = 0.100000001
    ShowDistanceMeterDelay = 0.5
    UpdatePawnFrequency = 0.300000012
    HoloHighlightSize = 0.699999988
    HoloHealthBarSize = 0.100000001
    ShutOffOmniToolDelay = 2.0
    ScanImpactSound = WwiseEvent'Wwise_Power_DLC_TactScan.Play_power_DLC_NP_TactScan_target'
    BS_StartCastAnimation = {
                             AnimName = ('None', 
                                         'BC_AiScan_Start', 
                                         'BC_AiScan_Start', 
                                         'BC_AiScan_StdCov_Start', 
                                         'BC_AiScan_StdCov_Start', 
                                         'BC_AiScan_MidCov_Start', 
                                         'BC_AiScan_MidCov_Start', 
                                         'BC_AiScan_MidCov_Start', 
                                         'None', 
                                         'None', 
                                         'None', 
                                         'BC_AiScan_MidCov_Start'
                                        )
                            }
    BS_EndCastAnimation = {
                           AnimName = ('None', 
                                       'BC_AiScan_End', 
                                       'BC_AiScan_End', 
                                       'BC_AiScan_StdCov_End', 
                                       'BC_AiScan_StdCov_End', 
                                       'BC_AiScan_MidCov_End', 
                                       'BC_AiScan_MidCov_End', 
                                       'BC_AiScan_MidCov_End', 
                                       'None', 
                                       'None', 
                                       'None', 
                                       'BC_AiScan_MidCov_End'
                                      )
                          }
    DefaultDamageType = Class'SFXDamageType_Damping'
    DetonationParameters = {ImpactPlaceables = FALSE, BlockedByObjects = FALSE}
    ReleaseTime = 0.600000024
    CastAnimSet = MY_DYN_HMM_CB_PistolAiScan_CON_MP2
    fStartAnimBlendInTime = 0.200000003
    fEndAnimBlendOutTime = 0.200000003
    CastSound = WwiseEvent'Wwise_Power_DLC_TactScan.Play_power_DLC_P_TactScan_cast'
    HenchmanCastSound = WwiseEvent'Wwise_Power_DLC_TactScan.Play_power_DLC_NP_TactScan_cast'
    LeanOutToCast = FALSE
    Discipline = EBioCapMode.BIO_CAPMODE_TECH
    CooldownTime = {RankBonuses[1] = 0.5, BaseValue = 4.0, Formula = EPowerDataFormula.DivideByBonusSum}
    MaximumRange = {BaseValue = 4000.0}
    EffectDuration = {RankBonuses[2] = 0.300000012, BaseValue = 20.0}
    Ranks = ({
              Icon = 2, 
              Name = $0, 
              Description = $0, 
              Evolved1Name = $731601, 
              Evolved1Description = $731603, 
              Evolved2Name = $0, 
              Evolved2Description = $0
             }, 
             {
              Icon = 2, 
              Name = $0, 
              Description = $0, 
              Evolved1Name = $314881, 
              Evolved1Description = $690826, 
              Evolved2Name = $0, 
              Evolved2Description = $0
             }, 
             {
              Icon = 2, 
              Name = $0, 
              Description = $0, 
              Evolved1Name = $733106, 
              Evolved1Description = $733105, 
              Evolved2Name = $0, 
              Evolved2Description = $0
             }, 
             {
              Icon = 2, 
              Name = $0, 
              Description = $0, 
              Evolved1Name = $733107, 
              Evolved1Description = $733108, 
              Evolved2Name = $733109, 
              Evolved2Description = $733110
             }, 
             {
              Icon = 2, 
              Name = $0, 
              Description = $0, 
              Evolved1Name = $733111, 
              Evolved1Description = $733112, 
              Evolved2Name = $733113, 
              Evolved2Description = $733114
             }, 
             {
              Icon = 2, 
              Name = $0, 
              Description = $0, 
              Evolved1Name = $733115, 
              Evolved1Description = $733116, 
              Evolved2Name = $733117, 
              Evolved2Description = $733119
             }
            )
    PowerName = 'Damping'
    PowerCustomActionID = 15
    DisplayName = $731601
    Description = $731603
    Icon = 2
    IconResource = GFxMovieInfo'GUI_SF_TacticalScan.TacticalScan'
    TalentDescription = $731603
}