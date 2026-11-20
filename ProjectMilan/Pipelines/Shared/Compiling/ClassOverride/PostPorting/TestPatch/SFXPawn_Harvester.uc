// Source: ME3, Patch_SFXPawn_Harvester
// Decompiled 11/17/2026 7:37:59 AM against BioD_Cat002_570Harvesters.pcc
Class SFXPawn_Harvester extends SFXPawn
    placeable
    config(Game);

var Name FrontLeftLegName;
var Name FrontRightLegName;
var Name BackLeftLegName;
var Name BackRightLegName;
var Name LeftWeaponSocketName;
var Name RightWeaponSocketName;
var transient SFXSkelCtrl_AnimatedFootPlacement FrontLeftLeg;
var transient SFXSkelCtrl_AnimatedFootPlacement FrontRightLeg;
var transient SFXSkelCtrl_AnimatedFootPlacement BackLeftLeg;
var transient SFXSkelCtrl_AnimatedFootPlacement BackRightLeg;
var transient BioAnimNodeBlend_TurnInPlace TurnInPlace;
var(SFXPawn_Harvester) bool bFlying;
var(SFXPawn_Harvester) bool bAiming;
var bool bFireAltGun;

public simulated function PlayHit(float Damage, Controller instigatedBy, Object.Vector HitLocation, Class<DamageType> DamageType, Object.Vector Momentum, Actor.TraceHitInfo HitInfo, Pawn DamageCauser)
{
    local SFXPawn_PlayerParty PlayerPartyPawn;
    
    Super.PlayHit(Damage, instigatedBy, HitLocation, DamageType, Momentum, HitInfo, DamageCauser);
    PlayerPartyPawn = SFXPawn_PlayerParty(instigatedBy.Pawn);
    if (PlayerPartyPawn != None)
    {
        PlayerPartyPawn.bDamagedHarvester = TRUE;
    }
}
public event simulated function PostInitAnimTree(SkeletalMeshComponent SkelComp)
{
    Super(BioPawn).PostInitAnimTree(SkelComp);
    if (SkelComp == Mesh)
    {
        FrontLeftLeg = SFXSkelCtrl_AnimatedFootPlacement(Mesh.FindSkelControl(FrontLeftLegName));
        FrontRightLeg = SFXSkelCtrl_AnimatedFootPlacement(Mesh.FindSkelControl(FrontRightLegName));
        BackLeftLeg = SFXSkelCtrl_AnimatedFootPlacement(Mesh.FindSkelControl(BackLeftLegName));
        BackRightLeg = SFXSkelCtrl_AnimatedFootPlacement(Mesh.FindSkelControl(BackRightLegName));
    }
}
public function bool Died(Controller Killer, Class<DamageType> DamageType, Object.Vector HitLocation)
{
    local BioPlayerController PC;
    local SFXPawn_PlayerParty KillerPawn;
    
    KillerPawn = SFXPawn_PlayerParty(Killer.Pawn);
    if (KillerPawn != None && KillerPawn.bDamagedHarvester == TRUE)
    {
        PC = BioPlayerController(WorldInfo.GetALocalPlayerController());
        if (PC != None)
        {
            PC.UnlockAccomplishment('HARVESTER');
        }
    }
    return Super.Died(Killer, DamageType, HitLocation);
}
public simulated function WeaponFired(Weapon InWeapon, bool bViaReplication, optional Object.Vector HitLocation)
{
    Super(BioPawn).WeaponFired(InWeapon, bViaReplication, HitLocation);
    bFireAltGun = !bFireAltGun;
    MuzzleSocketName = bFireAltGun ? LeftWeaponSocketName : RightWeaponSocketName;
}
public simulated function CacheCrucialAnimNodes()
{
    Super(BioPawn).CacheCrucialAnimNodes();
    if (Mesh != None && Mesh.Animations != None)
    {
        foreach Mesh.AllAnimNodes(Class'BioAnimNodeBlend_TurnInPlace', TurnInPlace)
        {
            break;
        }
    }
}
public simulated function bool CanPlayDeathEffect()
{
    return FALSE;
}
protected function bool GetKnockbackReactions(float Angle, float SideAngle, out array<SFXCustomActionTypes.EAICustomAction> OutActions)
{
    if (!bFlying)
    {
        return Super(BioPawn).GetKnockbackReactions(Angle, SideAngle, OutActions);
    }
    return FALSE;
}
protected function bool GetMeleeReactions(float Angle, float SideAngle, out array<SFXCustomActionTypes.EAICustomAction> OutActions)
{
    if (!bFlying)
    {
        return Super(BioPawn).GetMeleeReactions(Angle, SideAngle, OutActions);
    }
    return FALSE;
}
protected function bool GetStaggerReactions(float Angle, float SideAngle, out array<SFXCustomActionTypes.EAICustomAction> OutActions)
{
    if (!bFlying)
    {
        return Super(BioPawn).GetStaggerReactions(Angle, SideAngle, OutActions);
    }
    return FALSE;
}
protected function bool GetStandardReactions(float Angle, float SideAngle, out array<SFXCustomActionTypes.EAICustomAction> OutActions)
{
    if (!bFlying)
    {
        return Super(BioPawn).GetStandardReactions(Angle, SideAngle, OutActions);
    }
    return FALSE;
}
public simulated function PlayDeathReaction()
{
    if (bFlying || CurrentCustomAction == 152 || CurrentCustomAction == 153)
    {
        StartCustomAction(156);
    }
    else
    {
        StartCustomAction(DeathCustomAction);
    }
}
public simulated function BackLeftStepDown()
{
    BackLeftLeg.SetSkelControlActive(TRUE);
}
public simulated function BackLeftStepUp()
{
    BackLeftLeg.SetSkelControlActive(FALSE);
}
public simulated function BackRightStepDown()
{
    BackRightLeg.SetSkelControlActive(TRUE);
}
public simulated function BackRightStepUp()
{
    BackRightLeg.SetSkelControlActive(FALSE);
}
public simulated function FrontLeftStepDown()
{
    FrontLeftLeg.SetSkelControlActive(TRUE);
}
public simulated function FrontLeftStepUp()
{
    FrontLeftLeg.SetSkelControlActive(FALSE);
}
public simulated function FrontRightStepDown()
{
    FrontRightLeg.SetSkelControlActive(TRUE);
}
public simulated function FrontRightStepUp()
{
    FrontRightLeg.SetSkelControlActive(FALSE);
}
public simulated function SetAiming(bool bNewAiming)
{
    bAiming = bNewAiming;
}

replication
{
    if (bNetDirty && Role == ENetRole.ROLE_Authority)
        bFlying, bAiming;
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    Begin Template Class=BioDynamicLightEnvironmentComponent Name=BioLightEnvComponent0
    End Template
    Begin Template Class=CylinderComponent Name=CollisionCylinder
        CollisionHeight = 250.0
        CollisionRadius = 250.0
        ReplacementPrimitive = None
    End Template
    Begin Template Class=ForceFeedbackWaveform Name=FootstepShakeFF0
    End Template
    Begin Object Class=SFXLoadoutData Name=HarvesterLoadout0
        Weapons = (Class'SFXWeapon_AI_Harvester')
    End Object
    Begin Template Class=SFXModule_AimAssistTarget Name=AimAssistMod
    End Template
    Begin Template Class=SFXModule_Audio Name=AudioModule
        bPlayFootstepSounds = FALSE
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
        Begin Template Class=BioGestureAnimSetMgr Name=oAnimSetMgr_3
        End Template
        m_pAnimSetMgr = oAnimSetMgr_3
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
    FrontLeftLegName = 'FrontLeftLeg'
    FrontRightLegName = 'FrontRightLeg'
    BackLeftLegName = 'BackLeftLeg'
    BackRightLegName = 'BackRightLeg'
    LeftWeaponSocketName = 'Socket_LGun'
    RightWeaponSocketName = 'Socket_RGun'
    MuzzleSocketName = 'Socket_LGun'
    PowerControlResistance = 1.0
    CodexPlotState = 21663
    FootstepForceFeedback = FootstepShakeFF0
    bAllowHeadGib = FALSE
    bLimitConsoleLOD = FALSE
    bSupportsVisibleWeapons = FALSE
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
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           Class'SFXCustomAction_HarvesterStandard', 
                           Class'SFXCustomAction_HarvesterStandardForward', 
                           Class'SFXCustomAction_HarvesterStandardLeft', 
                           Class'SFXCustomAction_HarvesterStandardRight', 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           Class'SFXCustomAction_HarvesterDeath', 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           Class'SFXCustomAction_HarvesterTakeOff', 
                           Class'SFXCustomAction_HarvesterLand', 
                           Class'SFXCustomAction_HarvesterEnterAim', 
                           Class'SFXCustomAction_HarvesterLeaveAim', 
                           Class'SFXCustomAction_HarvesterDeathInstant'
                          )
    AimNodes = ('None', 
                'Head', 
                'LeftShoulder', 
                'RightShoulder', 
                'Pelvis', 
                'None', 
                'None', 
                'None'
               )
    ReactionBones = ({
                      BoneNames = ('LeftAnkle', 'Back_LClaw', 'LeftHip'), 
                      BodyPart = 'LeftLeg'
                     }, 
                     {
                      BoneNames = ('RightAnkle', 'Back_RClaw', 'RightHip'), 
                      BodyPart = 'RightLeg'
                     }, 
                     {
                      BoneNames = ('LeftWrist', 'Front_LClaw', 'LeftElbow', 'LeftShoulder'), 
                      BodyPart = 'LeftArm'
                     }, 
                     {
                      BoneNames = ('RightWrist', 'Front_RClaw', 'RightElbow', 'RightShoulder'), 
                      BodyPart = 'RightArm'
                     }, 
                     {
                      BoneNames = ('Pelvis', 'Root'), 
                      BodyPart = 'Chest'
                     }, 
                     {
                      BoneNames = ('Big_LWing_Clav', 
                                   'Big_LWing_Shoulder', 
                                   'Big_LWing_Elbow', 
                                   'Big_LWing_Tip', 
                                   'Big_LWing_Index', 
                                   'Big_LWing_Index01', 
                                   'Big_LWing_Index02', 
                                   'Big_LWing_Middle', 
                                   'Big_LWing_Middle01', 
                                   'Big_LWing_Middle02', 
                                   'Big_LWing_Ring', 
                                   'Big_LWing_Ring01', 
                                   'Big_LWing_Ring02', 
                                   'Big_LWing_Pinky', 
                                   'Big_LWing_Pinky01', 
                                   'Big_LWing_Pinky02'
                                  ), 
                      BodyPart = 'BigLeftWing'
                     }, 
                     {
                      BoneNames = ('Big_RWing_Clav', 
                                   'Big_RWing_Shoulder', 
                                   'Big_RWing_Elbow', 
                                   'Big_RWing_Tip', 
                                   'Big_RWing_Index', 
                                   'Big_RWing_Index01', 
                                   'Big_RWing_Index02', 
                                   'Big_RWing_Middle', 
                                   'Big_RWing_Middle01', 
                                   'Big_RWing_Middle02', 
                                   'Big_RWing_Ring', 
                                   'Big_RWing_Ring01', 
                                   'Big_RWing_Ring02', 
                                   'Big_RWing_Pinky', 
                                   'Big_RWing_Pinky01', 
                                   'Big_RWing_Pinky02'
                                  ), 
                      BodyPart = 'BigRightWing'
                     }, 
                     {
                      BoneNames = ('Small_LWing_Clav', 'Small_LWing_Shoulder', 'Small_LWing_Elbow', 'Small_LWing_Tip'), 
                      BodyPart = 'SmallLeftWing'
                     }, 
                     {
                      BoneNames = ('Small_RWing_Clav', 'Small_RWing_Shoulder', 'Small_RWing_Elbow', 'Small_RWing_Tip'), 
                      BodyPart = 'SmallRightWing'
                     }
                    )
    RightHandSocketName = 'AimingOrigin'
    DeathCustomAction = 120
    HeadMesh = HeadMesh0
    m_oHairMesh = HairMesh0
    m_oHeadGearMesh = GearMesh0
    LightEnvironment = BioLightEnvComponent0
    Loadout = HarvesterLoadout0
    PowerManager = PowerMgr
    bIgnoreSelectionMaxRange = TRUE
    bCanRagdoll = FALSE
    bUseLargeReactions = TRUE
    m_bHideWithCameraCollision = FALSE
    bCanPortArms = FALSE
    AffiliationType = EAffiliationType.AffiliationType_Reaper
    ControllerClass = Class'SFXAI_Harvester'
    CrouchHeight = 150.0
    CrouchRadius = 225.0
    SightRadius = 10000.0
    BaseEyeHeight = 225.0
    EyeHeight = 225.0
    Mesh = BioPawnSkeletalMeshComponent
    CylinderComponent = CollisionCylinder
    bCanStrafe = FALSE
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
    RotationRate = {Pitch = 16384, Yaw = 16384, Roll = 16384}
    CollisionComponent = CollisionCylinder
}