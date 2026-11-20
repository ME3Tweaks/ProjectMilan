// Source: ME3, Patch_SFXPawn_GethPrime
// Decompiled 11/17/2026 7:37:56 AM against BioD_Gth001_600Core.pcc
Class SFXPawn_GethPrime extends SFXPawn
    placeable
    config(Game);

var WwiseEvent CastDroneVoc;
var WwiseEvent CastTurretVoc;
var instanced LensFlareComponent LF_GethLensFlare01;
var instanced LensFlareComponent LF_GethLensFlare02;
var instanced LensFlareComponent LF_GethLensFlare03;

public simulated function PostBeginPlay()
{
    Super.PostBeginPlay();
    Mesh.AttachComponentToSocket(LF_GethLensFlare01, 'Socket_Lens01');
    Mesh.AttachComponentToSocket(LF_GethLensFlare02, 'Socket_Lens02');
    Mesh.AttachComponentToSocket(LF_GethLensFlare03, 'Socket_Lens03');
}
public simulated function PlayDying(Class<DamageType> DamageType, Object.Vector HitLoc)
{
    Super.PlayDying(DamageType, HitLoc);
    LF_GethLensFlare01.SetIsActive(FALSE);
    LF_GethLensFlare02.SetIsActive(FALSE);
    LF_GethLensFlare03.SetIsActive(FALSE);
}
public simulated function bool CanPlayDeathEffect()
{
    return FALSE;
}
public function PlayCastDroneVoc()
{
    PlaySound(CastDroneVoc);
}
public function PlayCastTurretVoc()
{
    PlaySound(CastTurretVoc);
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    Begin Template Class=BioDynamicLightEnvironmentComponent Name=BioLightEnvComponent0
    End Template
    Begin Template Class=CylinderComponent Name=CollisionCylinder
        CollisionHeight = 140.0
        CollisionRadius = 100.0
        ReplacementPrimitive = None
    End Template
    Begin Template Class=ForceFeedbackWaveform Name=FootstepShakeFF0
    End Template
    Begin Object Class=LensFlareComponent Name=LensFlare0
        Template = LensFlare'BioVFX_Crt_Geth.Flares.Geth_Flare_STP'
        ReplacementPrimitive = None
    End Object
    Begin Object Class=LensFlareComponent Name=LensFlare1
        Template = LensFlare'BioVFX_Crt_Geth.Flares.Geth_Flare_STP'
        ReplacementPrimitive = None
    End Object
    Begin Object Class=LensFlareComponent Name=LensFlare2
        Template = LensFlare'BioVFX_Crt_Geth.Flares.Geth_Flare_STP'
        ReplacementPrimitive = None
    End Object
    Begin Object Class=SFXLoadoutData Name=GethPrimeLoadout0
        Weapons = (Class'SFXWeapon_AI_GethPrimeRifle')
        ShieldLoadouts = ({
                           Shields = Class'SFXShield_Energy', 
                           ShieldLevelRange = {X = 0.0, Y = 0.0}, 
                           MaxShields = {X = 3000.0, Y = 3000.0}
                          }
                         )
    End Object
    Begin Template Class=SFXModule_AimAssistTarget Name=AimAssistMod
    End Template
    Begin Template Class=SFXModule_Audio Name=AudioModule
    End Template
    Begin Template Class=SFXModule_Conversation Name=ConvoMod01
        m_bDisableFacefx = TRUE
    End Template
    Begin Template Class=SFXModule_Damage Name=DmgMod0
        HealthType = EHealthType.HealthType_Armour
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
        GlobalAnimRateScale = 0.666599989
        ReplacementPrimitive = None
        LightEnvironment = BioLightEnvComponent0
        Scale = 1.5
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
    CastDroneVoc = WwiseEvent'Wwise_Crt_Geth_Prime_SFX.Play_crt_geth_prime_voc_drone'
    CastTurretVoc = WwiseEvent'Wwise_Crt_Geth_Prime_SFX.Play_crt_geth_prime_voc_turret'
    LF_GethLensFlare01 = LensFlare0
    LF_GethLensFlare02 = LensFlare1
    LF_GethLensFlare03 = LensFlare2
    HeadshotMultiplier = 0.400000006
    AmbientVoc = WwiseEvent'Wwise_Crt_Geth_Prime_SFX.Play_crt_geth_prime_voc_ambient'
    PainVoc = WwiseEvent'Wwise_Crt_Geth_Prime_SFX.Play_crt_geth_prime_voc_pain'
    ShieldsDownVoc = WwiseEvent'Wwise_Crt_Geth_Prime_SFX.Play_crt_geth_prime_voc_shieldsdown'
    PowerControlResistance = 0.5
    DamageScoreBudget = 1000.0
    KillBonusScore = 100.0
    PowerControlAssistBudget = 250.0
    FootstepForceFeedback = FootstepShakeFF0
    bCanBeMeleed = FALSE
    CustomActionClasses = (None, 
                           Class'SFXCustomAction_Ragdoll', 
                           None, 
                           Class'SFXCustomAction_SyncPawnPartner_Base', 
                           None, 
                           None, 
                           None, 
                           None, 
                           Class'SFXCustomAction_Frozen', 
                           Class'SFXCustomAction_Reload', 
                           Class'SFXCustomAction_MountedGunReload', 
                           None, 
                           None, 
                           Class'SFXCustomAction_EnterMountedGun', 
                           Class'SFXCustomAction_ExitMountedGun', 
                           Class'SFXCustomAction_GethPrimeOrbitalDrop', 
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
                           Class'SFXCustomAction_GethPrimeStagger', 
                           Class'SFXCustomAction_GethPrimeStandard', 
                           Class'SFXCustomAction_GethPrimeStandardForward', 
                           Class'SFXCustomAction_GethPrimeStandardLeft', 
                           Class'SFXCustomAction_GethPrimeStandardRight', 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           Class'SFXCustomAction_GethPrimeDeathEMP', 
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
                           Class'SFXCustomAction_GethPrimeMelee', 
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
                           Class'SFXCustomAction_IdleStandGuard', 
                           Class'SFXCustomAction_IdleInspectWeapon', 
                           Class'SFXCustomAction_IdleInspectOmniTool', 
                           Class'SFXCustomAction_IdleOmniToolScan', 
                           Class'SFXCustomAction_IdleUseConsole', 
                           Class'SFXCustomAction_IdleTalking', 
                           Class'SFXCustomAction_IdleTalking2', 
                           Class'SFXCustomAction_IdleTalking3', 
                           Class'SFXCustomAction_IdleListening', 
                           Class'SFXCustomAction_IdleListening2', 
                           Class'SFXCustomAction_IdleListening3'
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
                                Class'SFXPowerCustomAction_GethPrimeShieldDrone', 
                                Class'SFXPowerCustomAction_GethPrimeTurret'
                               )
    AimNodes = ('None', 
                'Head', 
                'LeftShoulder', 
                'RightShoulder', 
                'Chest2', 
                'Pelvis', 
                'LeftKnee', 
                'RightKnee'
               )
    ReactionBones = ({
                      BoneNames = ('LeftHip', 'LeftKnee', 'LeftAnkle'), 
                      BodyPart = 'LeftLeg'
                     }, 
                     {
                      BoneNames = ('RightHip', 'RightKnee', 'RightAnkle'), 
                      BodyPart = 'RightLeg'
                     }, 
                     {
                      BoneNames = ('LeftShoulder', 'LeftElbow', 'LeftWrist'), 
                      BodyPart = 'LeftArm'
                     }, 
                     {
                      BoneNames = ('RightShoulder', 'RightElbow', 'RightWrist'), 
                      BodyPart = 'RightArm'
                     }, 
                     {
                      BoneNames = ('Root', 'LowerBack'), 
                      BodyPart = 'Chest'
                     }, 
                     {
                      BoneNames = ('Head', 'Neck'), 
                      BodyPart = 'Head'
                     }
                    )
    DeathCustomAction = 120
    HeadMesh = HeadMesh0
    m_oHairMesh = HairMesh0
    m_oHeadGearMesh = GearMesh0
    LightEnvironment = BioLightEnvComponent0
    NotifyNewEnemySound = WwiseEvent'Wwise_Crt_Geth_Prime_SFX.Play_crt_geth_prime_voc_entrance'
    Loadout = GethPrimeLoadout0
    BloodColor = {B = 24, G = 30, R = 35, A = 255}
    PowerManager = PowerMgr
    bSpawnPHATInstance = FALSE
    bCanRagdoll = FALSE
    bUseLargeReactions = TRUE
    bCanPortArms = FALSE
    bAdjustMeshTranslationOnSlopes = TRUE
    RaceType = ERaceType.RaceType_Machine
    CharacterType = ECharacterType.CharacterType_Geth_Prime
    AffiliationType = EAffiliationType.AffiliationType_Geth
    ControllerClass = Class'SFXAI_GethPrime'
    SightRadius = 5000.0
    BaseEyeHeight = 110.0
    EyeHeight = 110.0
    Mesh = BioPawnSkeletalMeshComponent
    CylinderComponent = CollisionCylinder
    bCanCrouch = FALSE
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
    CollisionComponent = CollisionCylinder
}