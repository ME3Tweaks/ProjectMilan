// Source: ME3, Patch_SFXPawn_GethPrimeTurret
// Decompiled 11/17/2026 7:37:57 AM against BioD_Gth001_600Core.pcc
Class SFXPawn_GethPrimeTurret extends SFXPawn
    placeable
    config(Game);

var Object.Guid TurretVFXGuid;
var RvrClientEffectInterface CE_TurretTemplate;
var instanced ParticleSystemComponent PSC_Death;
var SFXNav_TurretPoint TurretPoint;
var float TurretDuration;

public simulated function PostBeginPlay()
{
    local SFXNav_TurretPoint TP;
    local SFXNav_TurretPoint Closest;
    local float ClosestDist;
    local float Dist;
    
    Super.PostBeginPlay();
    StartVFX();
    Mesh.AttachComponent(PSC_Death, 'Root');
    if (Role == ENetRole.ROLE_Authority)
    {
        foreach WorldInfo.RadiusNavigationPoints(Class'SFXNav_TurretPoint', TP, location, 300.0)
        {
            if (TP != None && TP.bClaimed == FALSE)
            {
                Dist = VSize(TP.location - location);
                if (Closest == None || Dist < ClosestDist)
                {
                    Closest = TP;
                    ClosestDist = Dist;
                }
            }
        }
        if (Closest != None)
        {
            TurretPoint = Closest;
            TurretPoint.bClaimed = TRUE;
        }
        SetTimer(TurretDuration, FALSE, 'TurretDurationEnded', );
    }
}
public function bool Died(Controller Killer, Class<DamageType> DamageType, Object.Vector HitLocation)
{
    if (TurretPoint != None)
    {
        TurretPoint.bClaimed = FALSE;
        TurretPoint = None;
    }
    return Super.Died(Killer, DamageType, HitLocation);
}
public simulated function PlayDying(Class<DamageType> DamageType, Object.Vector HitLoc)
{
    OnTurretKilled(Self);
    Class'RvrClientEffectManager'.static.GetClientEffectManager().@Stop(CE_TurretTemplate, TurretVFXGuid, TRUE);
    PSC_Death.SetActive(TRUE);
    Super.PlayDying(DamageType, HitLoc);
}
public simulated function bool CanPlayDeathEffect()
{
    return FALSE;
}
public delegate function OnTurretKilled(SFXPawn_GethPrimeTurret oDrone);

public final simulated function StartVFX()
{
    local RvrClientEffectInterface.RvrClientEffectTarget Target;
    local RvrClientEffectManager Manager;
    
    Manager = Class'RvrClientEffectManager'.static.GetClientEffectManager();
    if (Manager != None)
    {
        Target.Instigator = Self;
        Target.HitNormal = Vector(Rotation);
        TurretVFXGuid = Manager.StartOnTarget(CE_TurretTemplate, Target);
    }
    else
    {
        SetTimer(0.100000001, FALSE, 'StartVFX', );
    }
}
public final function TurretDurationEnded()
{
    Died(Controller, Class'SFXDamageType_Suicide', location);
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
        Template = ParticleSystem'BioVFX_Crt_GethTurret.Particles.GethTurret_Explode'
        bAutoActivate = FALSE
        ReplacementPrimitive = None
    End Object
    Begin Object Class=SFXLoadoutData Name=GethPrimeTurretLoadout0
        Weapons = (Class'SFXWeapon_AI_GethAssaultRifle')
    End Object
    Begin Template Class=SFXModule_AimAssistTarget Name=AimAssistMod
        m_srGameName = $584270
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
    CE_TurretTemplate = RvrClientEffect'BioVFX_Crt_GethTurret.VCFX.GethTurret_VCFX'
    PSC_Death = PSC0
    TurretDuration = 20.0
    MuzzleSocketName = 'Flash_1'
    DamageScoreBudget = 50.0
    KillBonusScore = 5.0
    PowerControlAssistBudget = 10.0
    FootstepForceFeedback = FootstepShakeFF0
    bSupportsVisibleWeapons = FALSE
    bIsPet = TRUE
    bCanDropAmmo = FALSE
    CustomActionClasses = (None, 
                           None, 
                           None, 
                           Class'SFXCustomAction_SyncPawnPartner_Base', 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           Class'SFXCustomAction_MountedGunReload', 
                           None, 
                           None, 
                           Class'SFXCustomAction_EnterMountedGun', 
                           Class'SFXCustomAction_ExitMountedGun'
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
    Loadout = GethPrimeTurretLoadout0
    PowerManager = PowerMgr
    bSpawnPHATInstance = FALSE
    bKillOnRagdoll = TRUE
    bCanRagdoll = FALSE
    bCanPortArms = FALSE
    RaceType = ERaceType.RaceType_Machine
    ControllerClass = Class'SFXAI_GethPrimeTurret'
    SightRadius = 4000.0
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
    bReplicateInstigator = TRUE
}