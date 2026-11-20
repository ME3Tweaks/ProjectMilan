// Source: ME3, Patch_SFXPawn_Swarmer
// Decompiled 11/17/2026 7:38:07 AM against BioD_Cat002_250Courtyard.pcc
Class SFXPawn_Swarmer extends SFXPawn
    placeable
    config(Game);

var config float TimeToLive;
var config float ExplodeDamage;
var config float DoTDamage;
var config float DOTDuration;
var const RvrClientEffectInterface CE_SlimeEffect;
var ParticleSystem PS_Death;
var MaterialInstance BloodDecal;
var float DecalWidth;
var float DecalHeight;
var transient repnotify Actor SlimeTarget;
var WwiseEvent SwarmerExplodeSound;
var transient bool bPlayedSpawn;

public simulated function PostBeginPlay()
{
    local SFXGame Game;
    
    Super.PostBeginPlay();
    if (Role == ENetRole.ROLE_Authority)
    {
        Game = SFXGame(WorldInfo.Game);
        if (Game != None)
        {
            Game.CurrentSwarmerCount++;
        }
        SetTimer(TimeToLive + FRand() * TimeToLive * 0.25, FALSE, 'Suicide', );
        SetTimer(FRand() * 3.0, FALSE, 'PlaySpawn', );
    }
    if (Class'WorldInfo'.static.IsConsoleBuild())
    {
        Mesh.ForcedLodModel = 3;
    }
}
public static function PrecacheVFX(SFXObjectPool ObjectPool, RvrClientEffectManager ClientEffects)
{
    Super(BioPawn).PrecacheVFX(ObjectPool, ClientEffects);
    ObjectPool.PrecacheImpactEmitter(default.PS_Death);
}
public simulated function ReplicatedEvent(Name VarName)
{
    Super.ReplicatedEvent(VarName);
    if (VarName == 'SlimeTarget')
    {
        ApplySlime(SlimeTarget);
    }
}
public function Touch(Actor Other, PrimitiveComponent OtherComp, Object.Vector HitLocation, Object.Vector HitNormal)
{
    local SFXModule_GameEffectManager GEMan;
    local SFXGameEffect_AcidDamageOverTime Effect;
    
    Super(Actor).Touch(Other, OtherComp, HitLocation, HitNormal);
    if (Pawn(Other) != None && IsHostile(Pawn(Other)))
    {
        Other.TakeDamage(ExplodeDamage, Controller, location, Normal(Velocity) * 50.0, Class'SFXDamageType_Swarmer');
        GEMan = Other.GetModule(Class'SFXModule_GameEffectManager');
        if (GEMan != None)
        {
            Effect = SFXGameEffect_AcidDamageOverTime(GEMan.GetFirstEffectOfType(Class'SFXGameEffect_AcidDamageOverTime'));
            if (Effect != None)
            {
                Effect.RefreshDoT(DoTDamage / DOTDuration);
            }
            else
            {
                GEMan.CreateAndApplyEffect(Class'SFXGameEffect_AcidDamageOverTime', 'SwarmerDoT', DOTDuration, 1, DoTDamage / DOTDuration, Controller);
            }
        }
        ApplySlime(Other);
        Suicide();
    }
}
public simulated function bool ImpactWithPower(Actor.EPowerResistance Resistance, Pawn Caster, Object.Vector HitLocation, Object.Vector HitNormal, float Damage, Object.Vector Force, Class<DamageType> DamageType)
{
    TakeDamage(10000.0, Caster.Controller, HitLocation, Force, DamageType, , Caster);
    return Super.ImpactWithPower(Resistance, Caster, HitLocation, HitNormal, Damage, Force, DamageType);
}
public simulated function PlayDying(Class<DamageType> DamageType, Object.Vector HitLocation)
{
    local SFXGRI GRI;
    local SFXEmitter Emitter;
    local Object.Vector HitLoc;
    local Object.Vector HitNormal;
    
    Super.PlayDying(DamageType, HitLocation);
    if (Role == ENetRole.ROLE_Authority)
    {
        SFXGame(WorldInfo.Game).CurrentSwarmerCount--;
    }
    SetHidden(TRUE);
    GRI = SFXGRI(WorldInfo.GRI);
    if (GRI != None && GRI.ObjectPool != None)
    {
        Emitter = GRI.ObjectPool.GetImpactEmitter(PS_Death, location, Rotation);
        if (Emitter != None)
        {
            Emitter.SetLifetime(2.0);
            Emitter.ParticleSystemComponent.SetActive(TRUE);
        }
        if (Trace(HitLoc, HitNormal, location - vect(0.0, 0.0, 1.0) * 80.0, location, FALSE, , , ) != None)
        {
            WorldInfo.MyDecalManager.SpawnDecal(BloodDecal, HitLoc, Rotator(-HitNormal), DecalWidth, DecalHeight, 20.0, FALSE);
        }
    }
}
public function TakeFallingDamage();

public simulated function bool CanPlayDeathEffect()
{
    return FALSE;
}
public simulated function ApplySlime(Actor ChkTarget)
{
    local Object.Vector Params;
    
    if (ChkTarget != None)
    {
        if (Role == ENetRole.ROLE_Authority)
        {
            SlimeTarget = ChkTarget;
        }
        PlaySound(SwarmerExplodeSound, TRUE);
        Params.X = DOTDuration;
        Class'RvrClientEffectManager'.static.GetClientEffectManager().Play(CE_SlimeEffect, ChkTarget, Params);
    }
}
public function PlaySpawn()
{
    if (Physics != EPhysics.PHYS_Walking && Physics != EPhysics.PHYS_PathApproximation)
    {
        SetTimer(0.25, FALSE, 'PlaySpawn', );
        return;
    }
    StartCustomAction(144);
}
public static function SFXPawn_Swarmer SpawnSwarmer(Object.Vector SpawnLoc, Object.Rotator SpawnRot, int NewTeamNum, BioBaseSquad NewSquad)
{
    local SFXPawn_Swarmer NewSwarmer;
    local AIController SwarmerAI;
    local WorldInfo WI;
    local SFXDifficultyHandler DH;
    
    WI = Class'WorldInfo'.static.GetWorldInfo();
    DH = SFXGRI(WI.GRI).DifficultyHandler;
    if (float(SFXGame(WI.Game).CurrentSwarmerCount) < DH.MaxSwarmers)
    {
        NewSwarmer = WI.Spawn(Class'SFXPawn_Swarmer', None, 'None', SpawnLoc, SpawnRot, Class'SFXPawn_Ravager'.default.SwarmerArchetype, TRUE);
        SwarmerAI = WI.Spawn(NewSwarmer.ControllerClass, , , , , None, TRUE);
        SwarmerAI.Possess(NewSwarmer, FALSE);
        if (SFXGRI(WI.GRI) != None && SFXGRI(WI.GRI).WaveCoordinator != None)
        {
            SFXGRI(WI.GRI).WaveCoordinator.PawnSpawned(NewSwarmer);
        }
        if (NewSquad != None)
        {
            NewSquad.AddMember(NewSwarmer);
        }
        AIController(NewSwarmer.Controller).SetTeam(NewTeamNum);
        SFXAI_Core(NewSwarmer.Controller).BeginDefaultCommand();
        return NewSwarmer;
    }
    return None;
}

replication
{
    if (bNetDirty && Role == ENetRole.ROLE_Authority)
        SlimeTarget, bPlayedSpawn;
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    Begin Template Class=BioDynamicLightEnvironmentComponent Name=BioLightEnvComponent0
    End Template
    Begin Template Class=CylinderComponent Name=CollisionCylinder
        CollisionHeight = 20.0
        ReplacementPrimitive = None
    End Template
    Begin Template Class=ForceFeedbackWaveform Name=FootstepShakeFF0
    End Template
    Begin Template Class=SFXModule_AimAssistTarget Name=AimAssistMod
        AimAssistRegions = ({Width = 100.0, Height = 100.0, SoftMargin = 20.0, NodeType = EAimNodes.AimNode_Chest}, 
                            {Width = 80.0, Height = 50.0, SoftMargin = 80.0, NodeType = EAimNodes.AimNode_Groin}, 
                            {Width = 80.0, Height = 80.0, SoftMargin = 80.0, NodeType = EAimNodes.AimNode_Cover}
                           )
    End Template
    Begin Template Class=SFXModule_Audio Name=AudioModule
        bPlayFootstepSounds = FALSE
    End Template
    Begin Template Class=SFXModule_Conversation Name=ConvoMod01
        m_bDisableFacefx = TRUE
    End Template
    Begin Template Class=SFXModule_Damage Name=DmgMod0
    End Template
    Begin Template Class=SFXModule_GameEffectManager Name=GEMod0
    End Template
    Begin Template Class=SFXModule_Gestures Name=GestMod01
        Begin Template Class=BioGestureAnimSetMgr Name=oAnimSetMgr_5
        End Template
        m_pAnimSetMgr = oAnimSetMgr_5
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
        ReplacementPrimitive = None
        LightEnvironment = BioLightEnvComponent0
        CastShadow = FALSE
        bCastDynamicShadow = FALSE
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
    TimeToLive = 60.0
    ExplodeDamage = 25.0
    DoTDamage = 100.0
    DOTDuration = 5.0
    CE_SlimeEffect = RvrClientEffect'biovfx_crt_rpr_swarmer.VCFX.Swarmer_Target_Crust_VCFX'
    PS_Death = ParticleSystem'biovfx_crt_rpr_swarmer.Particles.Swarmer_Explosion'
    BloodDecal = MaterialInstanceTimeVarying'BioVFX_C_Impacts.Blood.Decals.Blood_Black_Decal_TimeInst'
    DecalWidth = 150.0
    DecalHeight = 150.0
    SwarmerExplodeSound = WwiseEvent'Wwise_Crt_Reap_Swarmer_SFX.Play_crt_reap_swarm_vfx_squish'
    DamageScoreBudget = 20.0
    FootstepForceFeedback = FootstepShakeFF0
    bSupportsVisibleWeapons = FALSE
    bIsPet = TRUE
    bCanDropAmmo = FALSE
    CustomActionClasses = (None, 
                           Class'SFXCustomAction_Ragdoll', 
                           None, 
                           Class'SFXCustomAction_SyncPawnPartner_Base', 
                           None, 
                           None, 
                           None, 
                           None, 
                           Class'SFXCustomAction_Frozen', 
                           None, 
                           Class'SFXCustomAction_MountedGunReload', 
                           None, 
                           None, 
                           Class'SFXCustomAction_EnterMountedGun', 
                           Class'SFXCustomAction_ExitMountedGun', 
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
                           Class'SFXCustomAction_SwarmerGapJump', 
                           None, 
                           None, 
                           None, 
                           None, 
                           Class'SFXCustomAction_SwarmerClimbUp', 
                           Class'SFXCustomAction_SwarmerClimbDown', 
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
                           Class'SFXCustomAction_SwarmerJump', 
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
                           Class'SFXCustomAction_SwarmerSpawn'
                          )
    SupportedCustomReachSpecs = (Class'SFXJumpReachSpec')
    AimNodes = ('None', 
                'Head', 
                'None', 
                'None', 
                'Pelvis', 
                'None', 
                'None', 
                'None'
               )
    ReactionBones = ({
                      BoneNames = ('LeftF_Hip', 'LeftF_Knee', 'LeftF_Ankle'), 
                      BodyPart = 'LeftFrontLeg'
                     }, 
                     {
                      BoneNames = ('RightF_Hip', 'RightF_Knee', 'RightF_Ankle'), 
                      BodyPart = 'RightFrontLeg'
                     }, 
                     {
                      BoneNames = ('LeftB_Hip', 'LeftB_Knee', 'LeftB_Ankle'), 
                      BodyPart = 'LeftBackLeg'
                     }, 
                     {
                      BoneNames = ('RightB_Hip', 'RightB_Knee', 'RightB_Ankle'), 
                      BodyPart = 'RightBackLeg'
                     }, 
                     {
                      BoneNames = ('RootMini', 'Pelvis'), 
                      BodyPart = 'Chest'
                     }
                    )
    RightHandSocketName = 'None'
    HeadMesh = HeadMesh0
    m_oHairMesh = HairMesh0
    m_oHeadGearMesh = GearMesh0
    LightEnvironment = BioLightEnvComponent0
    PowerManager = PowerMgr
    bSpawnPHATInstance = FALSE
    bKillOnRagdoll = TRUE
    bCanRagdoll = FALSE
    bCanPortArms = FALSE
    AffiliationType = EAffiliationType.AffiliationType_Reaper
    ControllerClass = Class'SFXAI_Swarmer'
    CrouchHeight = 20.0
    BaseEyeHeight = 40.0
    EyeHeight = 40.0
    Mesh = BioPawnSkeletalMeshComponent
    CylinderComponent = CollisionCylinder
    bCanClimbUp = TRUE
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
    bBlockActors = FALSE
    CollisionType = ECollisionType.COLLIDE_TouchAllButWeapons
}