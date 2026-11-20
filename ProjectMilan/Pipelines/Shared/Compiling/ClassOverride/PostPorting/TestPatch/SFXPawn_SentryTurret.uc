// Source: ME3, Patch_SFXPawn_SentryTurret
// Decompiled 11/17/2026 7:38:07 AM against BIOP_MP_COMMON.pcc
Class SFXPawn_SentryTurret extends SFXPawn
    placeable
    config(Game);

struct ReplicatedTurretCreator 
{
    var clearcrosslevel BioPawn Creator;
    var int CreatorPowerCustomActionIndex;
};

var Object.Guid TurretVFXGuid;
var Object.Guid TurretBaseVFXGuid;
var repnotify repretry SFXPawn_SentryTurret.ReplicatedTurretCreator ReplicatedTurretCreatorInfo;
var RvrClientEffectInterface CE_TurretTemplate;
var RvrClientEffectInterface CE_PlayerTurretTemplate;
var transient MaterialInstanceConstant MIC_TurretHealth;
var WwiseEvent SpawnSound;
var WwiseEvent DiedSound;
var WwiseEvent LoopingSound;
var WwiseEvent StopLoopingSound;
var Actor Caster;
var bool bLoopSoundActive;
var bool bHasShock;
var bool bIsClientSideInitialized;

public simulated function PostBeginPlay()
{
    Super.PostBeginPlay();
    PlaySound(SpawnSound);
    PlaySound(LoopingSound);
}
public event simulated function ReplicatedEvent(Name VarName)
{
    switch (VarName)
    {
        case 'ReplicatedTurretCreatorInfo':
            TurretCreatorInfoUpdated();
            break;
        default:
            Super.ReplicatedEvent(VarName);
            break;
    }
}
public simulated function TakeDamage(float DamageAmount, Controller EventInstigator, Object.Vector HitLocation, Object.Vector Momentum, Class<DamageType> DamageType, optional Actor.TraceHitInfo HitInfo, optional Actor DamageCauser)
{
    local SFXModule_Damage DamageMod;
    
    Super(BioPawn).TakeDamage(DamageAmount, EventInstigator, HitLocation, Momentum, DamageType, HitInfo, DamageCauser);
    DamageMod = GetModule(Class'SFXModule_Damage');
    if (DamageMod != None)
    {
        MIC_TurretHealth.SetScalarParameterValue('f_Health', DamageMod.GetHealthRatio());
    }
}
public simulated function PlayDying(Class<DamageType> DamageType, Object.Vector HitLoc)
{
    OnTurretKilled(Self);
    Class'RvrClientEffectManager'.static.GetClientEffectManager().@Stop(None, TurretVFXGuid, TRUE);
    Class'RvrClientEffectManager'.static.GetClientEffectManager().@Stop(None, TurretBaseVFXGuid, TRUE);
    PlaySound(DiedSound);
    StopSound(StopLoopingSound);
    Super.PlayDying(DamageType, HitLoc);
}
public simulated function Actor GetPetOwner()
{
    return Caster;
}
public simulated function PlayDeathVocalization(BioPawn Killer);

public delegate function OnTurretKilled(SFXPawn_SentryTurret oTurret);

public simulated function SetupCasterAndReplication(Actor NewCaster, int CasterPowerCustomAction)
{
    local BioPawn BPOwner;
    
    Caster = NewCaster;
    if (Role == ENetRole.ROLE_Authority)
    {
        BPOwner = BioPawn(Caster);
        if (BPOwner != None)
        {
            ReplicatedTurretCreatorInfo.Creator = BPOwner;
            ReplicatedTurretCreatorInfo.CreatorPowerCustomActionIndex = CasterPowerCustomAction;
        }
    }
}
public final simulated function StartVFX()
{
    local RvrClientEffectInterface.RvrClientEffectTarget Target;
    local RvrClientEffectManager RvrEffectManager;
    
    RvrEffectManager = Class'RvrClientEffectManager'.static.GetClientEffectManager();
    if (RvrEffectManager != None)
    {
        Target.Instigator = Self;
        Target.HitNormal = Vector(Rotation);
        if (bHasShock)
        {
            Target.SpawnValue.Z = 1.0;
        }
        if (SFXPawn_Player(Caster) != None && SFXPawn_Player(Caster).IsLocallyControlled())
        {
            TurretVFXGuid = RvrEffectManager.StartOnTarget(CE_PlayerTurretTemplate, Target);
        }
        else
        {
            TurretVFXGuid = RvrEffectManager.StartOnTarget(CE_TurretTemplate, Target);
        }
        MIC_TurretHealth.SetScalarParameterValue('f_Health', 1.0);
    }
    else
    {
        SetTimer(0.100000001, FALSE, 'StartVFX', );
    }
}
public simulated function TurretCreatorInfoUpdated()
{
    local BioCustomAction CreatorCustomAction;
    local SFXPowerCustomAction_SentryTurret TurretCustomAction;
    
    if (ReplicatedTurretCreatorInfo.Creator != None && !bIsClientSideInitialized)
    {
        StartVFX();
        CreatorCustomAction = ReplicatedTurretCreatorInfo.Creator.PowerCustomActions[ReplicatedTurretCreatorInfo.CreatorPowerCustomActionIndex];
        if (CreatorCustomAction != None)
        {
            TurretCustomAction = SFXPowerCustomAction_SentryTurret(CreatorCustomAction);
            if (TurretCustomAction != None)
            {
                SetupCasterAndReplication(ReplicatedTurretCreatorInfo.Creator, ReplicatedTurretCreatorInfo.CreatorPowerCustomActionIndex);
                OnTurretKilled = TurretCustomAction.OnTurretKilled;
                TurretCustomAction.Turret = Self;
                TurretCustomAction.SetupCurrentTurret();
            }
        }
        bIsClientSideInitialized = TRUE;
    }
}

replication
{
    if (bNetDirty && Role == ENetRole.ROLE_Authority)
        ReplicatedTurretCreatorInfo;
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    Begin Template Class=BioDynamicLightEnvironmentComponent Name=BioLightEnvComponent0
    End Template
    Begin Template Class=CylinderComponent Name=CollisionCylinder
        CollisionRadius = 15.0
        ReplacementPrimitive = None
        BlockNonZeroExtent = FALSE
        BlockRigidBody = FALSE
    End Template
    Begin Template Class=ForceFeedbackWaveform Name=FootstepShakeFF0
    End Template
    Begin Object Class=SFXLoadoutData Name=MyLoadout0
        Weapons = (Class'SFXWeapon_AssaultRifle_SentryTurret')
    End Object
    Begin Template Class=SFXModule_AimAssistTarget Name=AimAssistMod
        m_srGameName = $577087
    End Template
    Begin Template Class=SFXModule_Audio Name=AudioModule
    End Template
    Begin Template Class=SFXModule_Conversation Name=ConvoMod01
    End Template
    Begin Template Class=SFXModule_Damage Name=DmgMod0
        HealthType = EHealthType.HealthType_Shields
        MaxHealth = {X = 300.0, Y = 300.0}
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
    CE_TurretTemplate = RvrClientEffect'BioVFX_T_TechBall.VCFX.SentryTurret_01_VCFX'
    CE_PlayerTurretTemplate = RvrClientEffect'BioVFX_T_TechBall.VCFX.SentryTurret_01_Player_VCFX'
    MIC_TurretHealth = MaterialInstanceConstant'BioVFX_T_TechBall.Materials.Hud_SentryTurret_Flare_INST'
    SpawnSound = WwiseEvent'Wwise_Power_Tech_SenTurret.Play_power_tech_S_turret_spawn'
    LoopingSound = WwiseEvent'Wwise_Power_Tech_SenTurret.Play_power_tech_S_turret_loop'
    StopLoopingSound = WwiseEvent'Wwise_Power_Tech_SenTurret.Stop_power_tech_S_turret_loop'
    MuzzleSocketName = 'Flash_1'
    FootstepForceFeedback = FootstepShakeFF0
    bSupportsVisibleWeapons = FALSE
    bCanBeMeleed = FALSE
    bIsPet = TRUE
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
                                Class'SFXPowerCustomAction_SentryTurretCryoAmmo', 
                                Class'SFXPowerCustomAction_SentryTurretArmorPiercingAmmo', 
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
                                Class'SFXPowerCustomAction_SentryTurretRocket', 
                                Class'SFXPowerCustomAction_SentryTurretShock'
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
    HeadMesh = HeadMesh0
    m_oHairMesh = HairMesh0
    m_oHeadGearMesh = GearMesh0
    LightEnvironment = BioLightEnvComponent0
    Loadout = MyLoadout0
    PowerThreshold_Stagger = 25.0
    PowerThreshold_Knockback = 50.0
    PowerManager = PowerMgr
    bSpawnPHATInstance = FALSE
    bKillOnRagdoll = TRUE
    bCanRagdoll = FALSE
    bDisablePlayerPortArmsEvenIfFriendly = TRUE
    ControllerClass = Class'SFXAI_SentryTurret'
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