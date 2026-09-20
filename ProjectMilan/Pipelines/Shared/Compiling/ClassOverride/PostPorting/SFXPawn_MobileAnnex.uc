// MILAN CHANGE 09/17/2026 - Mgamerz
// Bugfix for when pawn falls out of world, it doesn't make a horrible grinding noise due to constant
// audio playing.

Class SFXPawn_MobileAnnex extends SFXPawn
    placeable
    config(Game);

var config array<float> FullSpeed;
var array<BioPawn> KnownEnemies;
var Guid PawnTemplateGuid;
var config float LowPowerThreshold;
var RvrClientEffectInterface CE_PawnTemplate;
var float CurrentSpeed;
var SFXObjective_MobileAnnex Objective;
var WwiseEvent ActivatedSound;
var WwiseEvent ObjectiveCompletedSound;
var WwiseEvent DeathSound;
var config float DestroyDelay;
var config float SpawnVODelay;
var bool bDestroyed;
// MILAN CHANGE - add a flag to know when object is completing
var bool bObjectiveFinishing;
// END MILAN CHANGE

public event simulated function Destroyed()
{
    if (bDestroyed)
    {
        return;
    }
    bDestroyed = TRUE;
    CleanUpEffects();
    Super(BioPawn).Destroyed();
}
public simulated function FellOutOfWorld(Class<DamageType> dmgType)
{
    if (Role == ENetRole.ROLE_Authority)
    {
        // MILAN CHANGE - only notify objective if it is not already finishing
        if (Objective != None && bObjectiveFinishing == FALSE)
        // END MILAN CHANGE
        {
            Objective.AnnexPawnFellOutOfWorld();
        }
    }
    DoneObjective();
}
public simulated function bool InCombat()
{
    return TRUE;
}
public simulated function PostBeginPlay()
{
    Super.PostBeginPlay();
    SetDesiredSpeed(0.0);
    DeferredPostBeginPlay();
}
public simulated function DeferredPostBeginPlay()
{
    local RvrClientEffectTarget Target;
    local SFXModule_MarkerObjective ObjectiveModule;
    
    if (PlayerReplicationInfo == None || WorldInfo == None || WorldInfo.GRI == None)
    {
        SetTimer(0.100000001, FALSE, 'DeferredPostBeginPlay', );
        return;
    }
    Target.Instigator = Self;
    PawnTemplateGuid = Class'RvrClientEffectManager'.static.GetClientEffectManager().StartOnTarget(CE_PawnTemplate, Target);
    PlaySound(ActivatedSound, TRUE);
    ObjectiveModule = GetModule(Class'SFXModule_MarkerObjective');
    if (ObjectiveModule != None)
    {
        ObjectiveModule.Activate();
    }
    SetTimer(SpawnVODelay, FALSE, 'PlaySpawnVO', );
    if (Role == ENetRole.ROLE_Authority)
    {
        SetTimer(1.0, TRUE, 'CheckForEnemies', );
    }
}
public function CheckForEnemies()
{
    local BioPawn oPawn;
    local int idx;
    local SFXAI_Core AI;
    
    for (idx = KnownEnemies.Length - 1; idx >= 0; idx--)
    {
        if (KnownEnemies[idx] == None || KnownEnemies[idx].IsDead())
        {
            KnownEnemies.Remove(idx, 1);
        }
    }
    foreach WorldInfo.AllPawns(Class'BioPawn', oPawn, location, 4000.0)
    {
        if (int(oPawn.GetTeamNum()) != 1 || oPawn.IsDead() || KnownEnemies.Find(oPawn) != -1)
        {
            continue;
        }
        AI = SFXAI_Core(oPawn.Controller);
        if (AI != None)
        {
            AI.IgnoredTargets.AddItem(Self);
            KnownEnemies.AddItem(oPawn);
        }
    }
}
public simulated function CleanUpEffects()
{
    local SFXModule_MarkerObjective ObjectiveModule;
    
    ClearTimer('CheckForEnemies');
    PlaySound(DeathSound, TRUE);
    if (PawnTemplateGuid.A != 0 || PawnTemplateGuid.B != 0 || PawnTemplateGuid.C != 0 || PawnTemplateGuid.D != 0)
    {
        Class'RvrClientEffectManager'.static.GetClientEffectManager().@Stop(None, PawnTemplateGuid, TRUE);
    }
    ObjectiveModule = GetModule(Class'SFXModule_MarkerObjective');
    if (ObjectiveModule != None)
    {
        ObjectiveModule.Deactivate();
    }
}
public simulated function DoneObjective()
{
    // MILAN CHANGE - set flag to indicate the objective is finishing
    if (bObjectiveFinishing) {
        return; // Reentry guard
    }
    bObjectiveFinishing = TRUE;
    //END MILAN CHANGE
    SFXGRI(WorldInfo.GRI).TriggerVocalizationEvent(138, Self, None);
    PlaySound(ObjectiveCompletedSound, TRUE);
    CleanUpEffects();
    SetTimer(DestroyDelay, FALSE, 'Destroyed', );
}
public simulated function PlaySpawnVO()
{
    SFXGRI(WorldInfo.GRI).TriggerVocalizationEvent(130, Self, None, 0.0, 1.0);
}
public simulated function SetAnnexSpeed(float fPercent)
{
    local SFXDifficultyHandler DH;
    local float fFullSpeed;
    
    DH = SFXGRI(WorldInfo.GRI).DifficultyHandler;
    if (DH == None)
    {
        return;
    }
    if (FullSpeed.Length == 0)
    {
        return;
    }
    if (int(DH.CurrentDifficulty) >= FullSpeed.Length)
    {
        fFullSpeed = FullSpeed[FullSpeed.Length - 1];
    }
    else
    {
        fFullSpeed = FullSpeed[int(DH.CurrentDifficulty)];
    }
    fPercent = FClamp(fPercent, 0.0, 1.0);
    if (fPercent <= float(0))
    {
        if (CurrentSpeed != float(0))
        {
            SFXGRI(WorldInfo.GRI).TriggerVocalizationEvent(132, Self, None, 0.5);
        }
        Velocity.X = 0.0;
        Velocity.Y = 0.0;
        Velocity.Z = 0.0;
        CurrentSpeed = 0.0;
        SetDesiredSpeed(0.0);
    }
    else
    {
        if (CurrentSpeed != fPercent * fFullSpeed)
        {
            if (fPercent == 1.0)
            {
                SFXGRI(WorldInfo.GRI).TriggerVocalizationEvent(133, Self, None, 0.5);
            }
            else if (CurrentSpeed == float(0))
            {
                SFXGRI(WorldInfo.GRI).TriggerVocalizationEvent(77, Self, None, 0.5);
            }
            else if (fPercent <= LowPowerThreshold)
            {
                SFXGRI(WorldInfo.GRI).TriggerVocalizationEvent(134, Self, None, 0.5);
            }
        }
        CurrentSpeed = fPercent * fFullSpeed;
        SetDesiredSpeed(CurrentSpeed);
    }
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    Begin Template Class=SFXModule_AimAssistTarget Name=AimAssistMod
    End Template
    Begin Template Class=SFXModule_Audio Name=AudioModule
    End Template
    Begin Template Class=BioDynamicLightEnvironmentComponent Name=BioLightEnvComponent0
    End Template
    Begin Template Class=SkeletalMeshComponent Name=BioPawnSkeletalMeshComponent
        SkeletalMesh = SkeletalMesh'BIOG_CBT_DRN_NKD_R.NKDa.CBT_DRN_NKDa_MDL'
        PhysicsAsset = PhysicsAsset'BIOG_CBT_DRN_NKD_R.NKDa.CBT_DRN_NKDa_MDL_Physics'
        ReplacementPrimitive = None
        LightEnvironment = BioLightEnvComponent0
        CastShadow = FALSE
        bCastDynamicShadow = FALSE
        Translation = {X = 0.0, Y = 0.0, Z = 40.0}
    End Template
    Begin Template Class=CylinderComponent Name=CollisionCylinder
        ReplacementPrimitive = None
    End Template
    Begin Template Class=SFXModule_Conversation Name=ConvoMod01
    End Template
    Begin Template Class=SFXModule_Damage Name=DmgMod0
    End Template
    Begin Template Class=ForceFeedbackWaveform Name=FootstepShakeFF0
    End Template
    Begin Template Class=SkeletalMeshComponent Name=GearMesh0
        ParentAnimComponent = BioPawnSkeletalMeshComponent
        ShadowParent = BioPawnSkeletalMeshComponent
        ReplacementPrimitive = None
        LightEnvironment = BioLightEnvComponent0
    End Template
    Begin Template Class=SFXModule_GameEffectManager Name=GEMod0
    End Template
    Begin Template Class=SFXModule_Gestures Name=GestMod01
        Begin Template Class=BioGestureAnimSetMgr Name=oAnimSetMgr
        End Template
        m_pAnimSetMgr = oAnimSetMgr
    End Template
    Begin Template Class=SkeletalMeshComponent Name=HairMesh0
        ParentAnimComponent = BioPawnSkeletalMeshComponent
        ShadowParent = BioPawnSkeletalMeshComponent
        ReplacementPrimitive = None
        LightEnvironment = BioLightEnvComponent0
    End Template
    Begin Template Class=SkeletalMeshComponent Name=HeadMesh0
        ParentAnimComponent = BioPawnSkeletalMeshComponent
        ShadowParent = BioPawnSkeletalMeshComponent
        ReplacementPrimitive = None
        LightEnvironment = BioLightEnvComponent0
    End Template
    Begin Template Class=SFXModule_LookAt Name=LookAtMod01
    End Template
    Begin Object Class=SFXModule_MarkerObjective Name=ObjectiveModule0
        MarkerOffset = {X = 0.0, Y = 0.0, Z = 40.0}
        MarkerLabel = $744426
    End Object
    Begin Template Class=SFXPowerManager Name=PowerMgr
    End Template
    Begin Template Class=SFXModule_Radar Name=RadarModule
    End Template
    Begin Template Class=SFXModule_Timeline Name=TimelineMod0
    End Template
    FullSpeed = (0.600000024, 0.625, 0.649999976, 0.675000012)
    LowPowerThreshold = 0.5
    CE_PawnTemplate = RvrClientEffect'BioVFX_DLC_Shared.VCFX.TechBall_Escort_VCFX'
    ActivatedSound = WwiseEvent'Wwise_GUI_DLC_MP3.Play_gui_mp3_drone_activate'
    ObjectiveCompletedSound = WwiseEvent'Wwise_GUI_DLC_MP3.Play_gui_mp3_escort_success'
    DeathSound = WwiseEvent'Wwise_Power_Tech_Drone.Play_power_tech_S_combatdrone_death'
    DestroyDelay = 1.5
    SpawnVODelay = 0.25
    FootstepForceFeedback = FootstepShakeFF0
    bCanDropAmmo = FALSE
    PowerCustomActionClasses = (None, 
                                None, 
                                None, 
                                None, 
                                None, 
                                None, 
                                None, 
                                None, 
                                None, 
                                None, 
                                None, 
                                None, 
                                None, 
                                None, 
                                None, 
                                None, 
                                None, 
                                None, 
                                None, 
                                None, 
                                None, 
                                None, 
                                None, 
                                None, 
                                None, 
                                None, 
                                None, 
                                None, 
                                None, 
                                None, 
                                None, 
                                None, 
                                None, 
                                None, 
                                None, 
                                None, 
                                None, 
                                None, 
                                None, 
                                None, 
                                None, 
                                None, 
                                None, 
                                None, 
                                None, 
                                None, 
                                None, 
                                None, 
                                Class'SFXPowerCustomActionMP_EscortDroneZap', 
                                Class'SFXPowerCustomActionMP_EscortDroneHeal'
                               )
    CombatVocVariants = (SFXVocalizationBank'AIBarks_DLC_CON_MP3.ss_mp_recondrone')
    HeadMesh = HeadMesh0
    m_oHairMesh = HairMesh0
    m_oHeadGearMesh = GearMesh0
    LightEnvironment = BioLightEnvComponent0
    PowerManager = PowerMgr
    bSpawnPHATInstance = FALSE
    bCanRagdoll = FALSE
    bDisablePlayerPortArmsEvenIfFriendly = TRUE
    ControllerClass = Class'SFXAI_MobileAnnex'
    Mesh = BioPawnSkeletalMeshComponent
    CylinderComponent = CollisionCylinder
    Components = (CollisionCylinder, None, BioLightEnvComponent0, BioPawnSkeletalMeshComponent, HeadMesh0, HairMesh0, GearMesh0)
    Modules = (GEMod0, 
               RadarModule, 
               AimAssistMod, 
               DmgMod0, 
               GestMod01, 
               ConvoMod01, 
               LookAtMod01, 
               AudioModule, 
               TimelineMod0, 
               ObjectiveModule0
              )
    NetPriority = 1.79999995
    CollisionComponent = CollisionCylinder
    bCanBeDamaged = FALSE
    bCollideActors = FALSE
    bCollideWorld = FALSE
    bBlockActors = FALSE
}