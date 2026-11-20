// Source: ME3, Patch_SFXPawn_Brute
// Decompiled 11/17/2026 7:37:55 AM against BioD_Cat002_120TurretEnemies.pcc
Class SFXPawn_Brute extends SFXPawn
    placeable
    config(Game);

var WwiseEvent WarningSound;
var bool bGuardWalk;

public function bool Died(Controller Killer, Class<DamageType> DamageType, Object.Vector HitLocation)
{
    local BioPlayerController PC;
    
    PC = BioPlayerController(Killer);
    if (CurrentCustomAction == 151 && PC != None && Killer.Pawn == SFXAI_Core(Controller).FireTarget)
    {
        PC.UnlockAccomplishment('BRUTECHARGE');
    }
    return Super.Died(Killer, DamageType, HitLocation);
}
public simulated function bool CanPlayDeathEffect()
{
    return FALSE;
}
public simulated function PlayWarningSound()
{
    if (Role == ENetRole.ROLE_Authority)
    {
        PlaySound(WarningSound);
    }
}

replication
{
    if (bNetDirty && !bNetOwner && !bTearOff && Role == ENetRole.ROLE_Authority)
        bGuardWalk;
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    Begin Template Class=BioDynamicLightEnvironmentComponent Name=BioLightEnvComponent0
    End Template
    Begin Template Class=CylinderComponent Name=CollisionCylinder
        CollisionHeight = 125.0
        CollisionRadius = 115.0
        ReplacementPrimitive = None
    End Template
    Begin Template Class=ForceFeedbackWaveform Name=FootstepShakeFF0
        Samples = ({Duration = 0.25, LeftAmplitude = 0, RightAmplitude = 65, LeftFunction = EWaveformFunction.WF_Constant, RightFunction = EWaveformFunction.WF_Sin0to90}, 
                   {Duration = 0.25, LeftAmplitude = 65, RightAmplitude = 65, LeftFunction = EWaveformFunction.WF_LinearDecreasing, RightFunction = EWaveformFunction.WF_LinearDecreasing}
                  )
    End Template
    Begin Template Class=SFXModule_AimAssistTarget Name=AimAssistMod
    End Template
    Begin Object Class=SFXModule_Armour Name=BattleDamage0
    End Object
    Begin Template Class=SFXModule_Audio Name=AudioModule
    End Template
    Begin Template Class=SFXModule_Conversation Name=ConvoMod01
        m_bDisableFacefx = TRUE
    End Template
    Begin Template Class=SFXModule_Damage Name=DmgMod0
        DamageParts = ({PartName = 'RightClaw', DamageScale = 0.00109999999}, 
                       {PartName = 'LeftArm', DamageScale = 0.75}, 
                       {PartName = 'RightArm', DamageScale = 0.75}
                      )
        HealthType = EHealthType.HealthType_Armour
    End Template
    Begin Template Class=SFXModule_GameEffectManager Name=GEMod0
    End Template
    Begin Template Class=SFXModule_Gestures Name=GestMod01
        Begin Template Class=BioGestureAnimSetMgr Name=oAnimSetMgr_1
        End Template
        m_pAnimSetMgr = oAnimSetMgr_1
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
    WarningSound = WwiseEvent'Wwise_Crt_Reap_Brute_SFX.Play_crt_reap_brute_voc_warning'
    FootstepShake = {
                     RotAmplitude = {X = 25.0, Y = 0.0, Z = 0.0}, 
                     RotFrequency = {X = 2000.0, Y = 2000.0, Z = 2000.0}, 
                     LocAmplitude = {X = 0.0, Y = 0.0, Z = 0.5}, 
                     LocFrequency = {X = 2000.0, Y = 2000.0, Z = 2000.0}, 
                     TimeDuration = 0.400000006
                    }
    HeadshotMultiplier = 0.400000006
    CodexPlotState = 20831
    DamageScoreBudget = 700.0
    KillBonusScore = 70.0
    PowerControlAssistBudget = 175.0
    FootstepForceFeedback = FootstepShakeFF0
    bAllowHeadGib = FALSE
    bPlayFootstepScreenShake = TRUE
    bPlayFootstepRumble = TRUE
    bCanBeMeleed = FALSE
    bIgnoresPets = TRUE
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
                           None, 
                           None, 
                           None, 
                           Class'SFXCustomAction_BruteMantle', 
                           None, 
                           Class'SFXCustomAction_BruteClimbUp', 
                           Class'SFXCustomAction_BruteClimbDown', 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           Class'SFXCustomAction_BruteDropDown', 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           Class'SFXCustomAction_BruteStagger', 
                           Class'SFXCustomAction_BruteStandard', 
                           Class'SFXCustomAction_BruteStandardForward', 
                           Class'SFXCustomAction_BruteStandardLeft', 
                           Class'SFXCustomAction_BruteStandardRight', 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           Class'SFXCustomAction_BruteDeath', 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           Class'SFXCustomAction_BruteMelee', 
                           Class'SFXCustomAction_BruteSmash', 
                           Class'SFXCustomAction_BruteSyncMelee', 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           Class'SFXCustomAction_BruteRoar', 
                           None, 
                           Class'SFXCustomAction_BruteCharge', 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           Class'SFXCustomAction_IdleBrute'
                          )
    SupportedCustomReachSpecs = (Class'SFXLargeMantleReachSpec', Class'SFXLargeClimbReachSpec', Class'SFXLargeBoostReachSpec')
    AimNodes = ('None', 
                'None', 
                'LeftShoulder', 
                'RightShoulder', 
                'Chest1', 
                'Pelvis', 
                'LeftKnee', 
                'RightKnee'
               )
    ReactionBones = ({
                      BoneNames = ('ClawBottomLeft', 'ClawTop01', 'ClawBottomRight', 'ClawTopRear', 'RightHand'), 
                      BodyPart = 'RightClaw'
                     }, 
                     {
                      BoneNames = ('LeftFoot', 'leftCalf', 'leftMidLeg', 'LeftUpperLeg', 'LeftLegHip'), 
                      BodyPart = 'LeftLeg'
                     }, 
                     {
                      BoneNames = ('RightFoot', 'rightCalf', 'rightMidLeg', 'RightUpperLeg', 'RightLegHip'), 
                      BodyPart = 'RightLeg'
                     }, 
                     {
                      BoneNames = ('LeftHand', 'LeftElbow', 'LeftShoulder', 'LeftArmCollar'), 
                      BodyPart = 'LeftArm'
                     }, 
                     {
                      BoneNames = ('RightElbow', 'RightShoulder', 'RightArmCollar'), 
                      BodyPart = 'RightArm'
                     }, 
                     {
                      BoneNames = ('Root', 'LowerBack', 'Pelvis', 'Chest', 'Chest1', 'GutsUpper'), 
                      BodyPart = 'Chest'
                     }, 
                     {
                      BoneNames = ('Neck', 'Neck1', 'Neck2', 'Neck3', 'Head'), 
                      BodyPart = 'Head'
                     }
                    )
    DeathCustomAction = 120
    HeadMesh = HeadMesh0
    m_oHairMesh = HairMesh0
    m_oHeadGearMesh = GearMesh0
    LightEnvironment = BioLightEnvComponent0
    NotifyNewEnemySound = WwiseEvent'Wwise_Crt_Reap_Brute_SFX.Play_crt_reap_brute_voc_entrance'
    CE_LifetimeCrust = RvrClientEffect'BioVFX_Crt_Brute.VCFX.Drool_VCFX'
    BloodColor = {B = 1, G = 2, R = 5, A = 255}
    PowerManager = PowerMgr
    bSpawnPHATInstance = FALSE
    bCanRagdoll = FALSE
    bAffectedByRagdollPowers = FALSE
    bUseLargeReactions = TRUE
    m_bHideWithCameraCollision = FALSE
    bCanPortArms = FALSE
    bAdjustMeshTranslationOnSlopes = TRUE
    CharacterType = ECharacterType.CharacterType_Reaper_Brute
    AffiliationType = EAffiliationType.AffiliationType_Reaper
    ControllerClass = Class'SFXAI_Brute'
    BaseEyeHeight = 110.0
    EyeHeight = 110.0
    Mesh = BioPawnSkeletalMeshComponent
    CylinderComponent = CollisionCylinder
    bCanCrouch = FALSE
    bCanMantle = TRUE
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
               TimelineMod0, 
               BattleDamage0
              )
    CollisionComponent = CollisionCylinder
}