// Source: ME3, Patch_SFXPawn_GethPrimeShieldDrone
// Decompiled 11/17/2026 7:37:56 AM against BioD_Gth001_600Core.pcc
Class SFXPawn_GethPrimeShieldDrone extends SFXPawn
    placeable
    config(Game);

var Object.Vector DroneColor;
var Object.Vector DroneColor2;
var instanced ParticleSystemComponent PSC_Active;
var instanced ParticleSystemComponent PSC_Spawn;
var instanced ParticleSystemComponent PSC_Death;
var bool bCustomColor;
var bool bCustomColor2;

public simulated function PostBeginPlay()
{
    Super.PostBeginPlay();
    if (bCustomColor)
    {
        PSC_Spawn.SetVectorParameter('Color', DroneColor);
        PSC_Death.SetVectorParameter('Color', DroneColor);
    }
    if (bCustomColor2)
    {
        PSC_Spawn.SetVectorParameter('Color_2', DroneColor2);
        PSC_Death.SetVectorParameter('Color_2', DroneColor2);
    }
    Mesh.AttachComponent(PSC_Spawn, 'Root');
    Mesh.AttachComponent(PSC_Active, 'Root');
    Mesh.AttachComponent(PSC_Death, 'Root');
    PSC_Spawn.SetActive(TRUE);
    PSC_Active.SetActive(TRUE);
}
public simulated function PlayDying(Class<DamageType> DamageType, Object.Vector HitLoc)
{
    OnDroneKilled(Self);
    if (PSC_Active != None)
    {
        PSC_Active.SetActive(FALSE);
    }
    if (PSC_Spawn != None)
    {
        PSC_Spawn.SetActive(FALSE);
    }
    PSC_Death.SetActive(TRUE);
    Super.PlayDying(DamageType, HitLoc);
}
public simulated function bool CanPlayDeathEffect()
{
    return FALSE;
}
public delegate function OnDroneKilled(SFXPawn_GethPrimeShieldDrone oDrone);

public final function DroneDurationEnded()
{
    Died(Controller, Class'SFXDamageType_Suicide', location);
}
public final function SetDroneDuration(float fLifeSpan)
{
    SetTimer(fLifeSpan, FALSE, 'DroneDurationEnded', );
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    Begin Template Class=BioDynamicLightEnvironmentComponent Name=BioLightEnvComponent0
    End Template
    Begin Template Class=CylinderComponent Name=CollisionCylinder
        ReplacementPrimitive = None
        BlockNonZeroExtent = FALSE
        BlockRigidBody = FALSE
    End Template
    Begin Template Class=ForceFeedbackWaveform Name=FootstepShakeFF0
    End Template
    Begin Object Class=ParticleSystemComponent Name=PSC0
        Template = ParticleSystem'BioVFX_T_TechBall.Particles.Geth_Drone'
        ReplacementPrimitive = None
    End Object
    Begin Object Class=ParticleSystemComponent Name=PSC1
        Template = ParticleSystem'BioVFX_T_TechBall.Particles.Tech_Ball_Spawn'
        ReplacementPrimitive = None
    End Object
    Begin Object Class=ParticleSystemComponent Name=PSC2
        Template = ParticleSystem'BioVFX_T_TechBall.Particles.Tech_Ball_Spawn'
        ReplacementPrimitive = None
    End Object
    Begin Template Class=SFXModule_AimAssistTarget Name=AimAssistMod
        m_srGameName = $576878
    End Template
    Begin Template Class=SFXModule_Audio Name=AudioModule
    End Template
    Begin Template Class=SFXModule_Conversation Name=ConvoMod01
        m_bDisableFacefx = TRUE
    End Template
    Begin Template Class=SFXModule_Damage Name=DmgMod0
        HealthType = EHealthType.HealthType_Shields
    End Template
    Begin Template Class=SFXModule_GameEffectManager Name=GEMod0
    End Template
    Begin Template Class=SFXModule_Gestures Name=GestMod01
        Begin Template Class=BioGestureAnimSetMgr Name=oAnimSetMgr
        End Template
        m_pAnimSetMgr = oAnimSetMgr
    End Template
    Begin Template Class=SFXModule_LookAt Name=LookAtMod01
    End Template
    Begin Template Class=SFXModule_Radar Name=RadarModule
    End Template
    Begin Template Class=SFXModule_Timeline Name=TimelineMod0
    End Template
    Begin Template Class=SFXPowerManager Name=PowerMgr
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
    Begin Template Class=SkeletalMeshComponent Name=GearMesh0
        ParentAnimComponent = BioPawnSkeletalMeshComponent
        ShadowParent = BioPawnSkeletalMeshComponent
        ReplacementPrimitive = None
        LightEnvironment = BioLightEnvComponent0
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
    DroneColor = {X = 1.0, Y = 3.0, Z = 25.0}
    DroneColor2 = {X = 1.0, Y = 3.0, Z = 25.0}
    PSC_Active = PSC0
    PSC_Spawn = PSC1
    PSC_Death = PSC2
    bCustomColor = TRUE
    bCustomColor2 = TRUE
    MuzzleSocketName = 'Flash_1'
    DamageScoreBudget = 50.0
    KillBonusScore = 5.0
    PowerControlAssistBudget = 10.0
    FootstepForceFeedback = FootstepShakeFF0
    bSupportsVisibleWeapons = FALSE
    bIsPet = TRUE
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
                                None, 
                                None, 
                                Class'SFXPowerCustomAction_GethPrimeDroneRocket'
                               )
    AimNodes = ('None', 
                'Root', 
                'Root', 
                'Root', 
                'Root', 
                'Root', 
                'Root', 
                'Root'
               )
    RightHandSocketName = 'Flash_1'
    HeadMesh = HeadMesh0
    m_oHairMesh = HairMesh0
    m_oHeadGearMesh = GearMesh0
    LightEnvironment = BioLightEnvComponent0
    PowerManager = PowerMgr
    bSpawnPHATInstance = FALSE
    bKillOnRagdoll = TRUE
    bCanRagdoll = FALSE
    bCanPortArms = FALSE
    RaceType = ERaceType.RaceType_Machine
    ControllerClass = Class'SFXAI_GethPrimeShieldDrone'
    BaseEyeHeight = 50.0
    EyeHeight = 50.0
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
               TimelineMod0
              )
    NetPriority = 1.79999995
    CollisionComponent = CollisionCylinder
}