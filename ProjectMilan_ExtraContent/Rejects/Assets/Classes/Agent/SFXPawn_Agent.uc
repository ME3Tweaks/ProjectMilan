Class SFXPawn_Agent extends SFXPawn
    placeable
    config(Game);

var editinline export StaticMeshComponent SwordMesh;
var float EvadeForceThreshold;
var float WarpFieldRadius;
var float WarpFieldDamage;

public simulated function PostBeginPlay()
{
    Super.PostBeginPlay();
    Mesh.AttachComponentToSocket(SwordMesh, LeftHandSocketName);
}
public simulated function EPowerResistance GetPowerResistance(Pawn Caster, Vector HitLocation, Vector HitNormal, out float Damage, out Vector Force, Class<DamageType> DamageType, out Actor TargetOverride)
{
    local float ForceMag;
    
    if (Role == ENetRole.ROLE_Authority)
    {
        ForceMag = VSize(Force);
        if (ForceMag >= EvadeForceThreshold)
        {
            StartCustomAction(92);
        }
        if (ClassIsChildOf(DamageType, Class'SFXDamageType_HeavyMelee'))
        {
            StartCustomAction(57);
        }
        if (ClassIsChildOf(DamageType, Class'SFXDamageType_Power_Fire'))
        {
            return 0;
        }
        if (ClassIsChildOf(DamageType, Class'SFXDamageType_Power_Freeze'))
        {
            return 0;
        }
        else
        {
            return 1;
        }
    }
    return Super.GetPowerResistance(Caster, HitLocation, HitNormal, Damage, Force, DamageType, TargetOverride);
}
public simulated function bool ModifyDamage(out float Damage, Vector Momentum, out DamageCalculationAlgorithm DamageCalc, const out TraceHitInfo HitInfo, Vector HitLocation, Class<SFXDamageType> DamageType, Controller instigatedBy, Actor DamageCauser)
{
    local SFXAI_Agent AI;
    local float CurrentShields;
    local float MaxShields;
    local float NewShieldPct;
    local float CurrentHealth;
    local float MaxHealth;
    local float NewHealthPct;
    local float ModifiedDamage;
    local SFXShield_Base Shields;
    
    if (Super(BioPawn).ModifyDamage(Damage, Momentum, DamageCalc, HitInfo, HitLocation, DamageType, instigatedBy, DamageCauser) == FALSE)
    {
        return FALSE;
    }
    if (Role == ENetRole.ROLE_Authority)
    {
        AI = SFXAI_Agent(Controller);

        if (AI.bIsInRechargeState){
            Damage *= 0.3;
        }
    }


    return TRUE;
}

protected function bool GetMeleeReactions(float Angle, float SideAngle, out array<EAICustomAction> OutActions)
{
    OutActions.AddItem(57);
    return TRUE;
}
protected function bool GetStaggerReactions(float Angle, float SideAngle, out array<EAICustomAction> OutActions)
{
    OutActions.AddItem(57);
    return TRUE;
}
protected function bool GetStandardReactions(float Angle, float SideAngle, out array<EAICustomAction> OutActions)
{
    return FALSE;
}
public final simulated function ActivateWarpField()
{
    UpdateWarpField();
    SetTimer(1.0, TRUE, 'UpdateWarpField', );
}
public final simulated function DeactivateWarpField()
{
    ClearTimer('UpdateWarpField');
}
public function OnToggleKaiLengSword(SequenceAction Seq)
{
    if (Seq != None)
    {
        if (Seq.InputLinks[0].bHasImpulse)
        {
            SwordMesh.SetHidden(FALSE);
        }
        else if (Seq.InputLinks[1].bHasImpulse)
        {
            SwordMesh.SetHidden(TRUE);
        }
        else if (Seq.InputLinks[2].bHasImpulse)
        {
            SwordMesh.SetHidden(!SwordMesh.HiddenGame);
        }
    }
}
public final simulated function UpdateWarpField()
{
    local SFXPawn P;
    local Vector Momentum;
    
    foreach WorldInfo.AllPawns(Class'SFXPawn', P, location, WarpFieldRadius)
    {
        if (P != None && P != Self && IsHostile(P))
        {
            if (Role == ENetRole.ROLE_Authority)
            {
                Momentum = Normal(P.location - location) * 100.0;
                P.TakeDamage(WarpFieldDamage, Controller, P.location, Momentum, Class'SFXDamageType');
                if (FRand() <= 0.25)
                {
                    P.RequestReaction(0, Controller, Momentum);
                }
            }
        }
    }
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    Begin Template Class=CylinderComponent Name=CollisionCylinder
        ReplacementPrimitive = None
    End Template
    Begin Template Class=BioDynamicLightEnvironmentComponent Name=BioLightEnvComponent0
    End Template
    Begin Template Class=SkeletalMeshComponent Name=BioPawnSkeletalMeshComponent
        ReplacementPrimitive = None
        LightEnvironment = BioLightEnvComponent0
    End Template
    Begin Template Class=SkeletalMeshComponent Name=HeadMesh0
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
    Begin Template Class=SkeletalMeshComponent Name=GearMesh0
        ParentAnimComponent = BioPawnSkeletalMeshComponent
        ShadowParent = BioPawnSkeletalMeshComponent
        ReplacementPrimitive = None
        LightEnvironment = BioLightEnvComponent0
    End Template
    Begin Object Class=StaticMeshComponent Name=SwordMesh0
        StaticMesh = StaticMesh'BIOG_WPN_MLE_R.MLEa.WPN_MLEa_MDL_Static'
        ShadowParent = BioPawnSkeletalMeshComponent
        ReplacementPrimitive = None
        LightEnvironment = BioLightEnvComponent0
        CollideActors = FALSE
        BlockActors = FALSE
        BlockZeroExtent = FALSE
        BlockNonZeroExtent = FALSE
        BlockRigidBody = FALSE
    End Object
    Begin Template Class=ForceFeedbackWaveform Name=FootstepShakeFF0
    End Template
    Begin Template Class=SFXModule_GameEffectManager Name=GEMod0
    End Template
    Begin Template Class=SFXModule_Radar Name=RadarModule
    End Template
    Begin Template Class=SFXModule_AimAssistTarget Name=AimAssistMod
    End Template
    Begin Template Class=SFXModule_Damage Name=DmgMod0
    End Template
    Begin Template Class=SFXModule_Gestures Name=GestMod01
        Begin Template Class=BioGestureAnimSetMgr Name=oAnimSetMgr
        End Template
        m_pAnimSetMgr = oAnimSetMgr
    End Template
    Begin Template Class=SFXModule_Conversation Name=ConvoMod01
        m_bDisableFacefx = TRUE
    End Template
    Begin Template Class=SFXModule_LookAt Name=LookAtMod01
    End Template
    Begin Template Class=SFXModule_Audio Name=AudioModule
    End Template
    Begin Template Class=SFXModule_Timeline Name=TimelineMod0
    End Template
    Begin Object Class=SFXLoadoutData Name=KaiLengLoadout0
        Weapons = (Class'SFXWeapon_AI_KaiLeng')
        ShieldLoadouts = ({
                           Shields = Class'SFXShield_Energy', 
                           ShieldLevelRange = {X = 0.0, Y = 0.0}, 
                           MaxShields = {X = 5000.0, Y = 5000.0}
                          }
                         )
    End Object
    Begin Template Class=SFXPowerManager Name=PowerMgr
    End Template
    SwordMesh = SwordMesh0
    EvadeForceThreshold = 500.0
    WarpFieldRadius = 350.0
    WarpFieldDamage = 150.0
    PowerImpactNotifications = ({Label = 'CombatRoll', TimeBeforeImpact = 0.5}
                               )
    MuzzleSocketName = 'Socket_01'
    FootstepForceFeedback = FootstepShakeFF0
    bCanPartialLean = TRUE
    bSupportsVisibleWeapons = FALSE
    CustomActionClasses = (None, 
                           Class'SFXCustomAction_PhantomRagdoll', 
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
                           Class'SFXCustomAction_StandingGapJump', 
                           None, 
                           None, 
                           Class'SFXCustomAction_PhantomMantleOverCover', 
                           None, 
                           Class'SFXCustomAction_PhantomMantleUp', 
                           None, 
                           Class'SFXCustomAction_MoveAlongCover', 
                           Class'SFXCustomAction_CoverSlipLeft', 
                           Class'SFXCustomAction_CoverSlipLeftStanding', 
                           Class'SFXCustomAction_CoverSlipRight', 
                           Class'SFXCustomAction_CoverSlipRightStanding', 
                           None, 
                           None, 
                           None, 
                           None, 
                           Class'SFXCustomAction_AISwatTurnLeft', 
                           Class'SFXCustomAction_AISwatTurnRight', 
                           Class'SFXCustomAction_AILadderClimbUp', 
                           Class'SFXCustomAction_AILadderClimbDown', 
                           None, 
                           None, 
                           None, 
                           None, 
                           Class'SFXCustomAction_LeapHumanoid', 
                           None, 
                           Class'SFXCustomAction_PhantomEvadeLeft', 
                           Class'SFXCustomAction_PhantomEvadeRight', 
                           Class'SFXCustomAction_RollForward_KaiLeng', 
                           Class'SFXCustomAction_RollBackward_KaiLeng', 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           Class'SFXCustomAction_KnockbackImpact', 
                           Class'SFXCustomAction_KnockbackImpactForward', 
                           Class'SFXCustomAction_KnockbackImpactLeft', 
                           Class'SFXCustomAction_KnockbackImpactRight', 
                           None, 
                           None, 
                           None, 
                           None, 
                           Class'SFXCustomAction_ShieldBreach', 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           Class'SFXCustomAction_KaiLengMelee', 
                           Class'SFXCustomAction_KaiLengSwordSlice', 
                           Class'SFXCustomAction_AgentSyncGrapple', 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           Class'SFXCustomAction_AgentSuperVortex', 
                           Class'SFXCustomAction_KaiLengShield', 
                           Class'SFXCustomAction_PhantomAirRecover', 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           Class'SFXCustomAction_IdleSwordFlourish'
                          )
    PowerCustomActionClasses = (None, None, None, None, None, None, Class'SFXPowerCustomAction_KaiLengSlash')
    SupportedCustomReachSpecs = (Class'SFXBoostReachSpec', Class'SFXLeapReachSpecHumanoid', Class'SFXLadderReachSpec', Class'SFXJumpReachSpec')
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
                      BoneNames = ('LeftHip', 'LeftKnee'), 
                      BodyPart = 'LeftLeg'
                     }, 
                     {
                      BoneNames = ('RightHip', 'RightKnee'), 
                      BodyPart = 'RightLeg'
                     }, 
                     {
                      BoneNames = ('LeftCollar', 'LeftShoulder', 'LeftElbow', 'LeftWrist'), 
                      BodyPart = 'LeftArm'
                     }, 
                     {
                      BoneNames = ('RightCollar', 'RightShoulder', 'RightElbow', 'RightWrist'), 
                      BodyPart = 'RightArm'
                     }, 
                     {
                      BoneNames = ('Root', 'LowerBack', 'Chest'), 
                      BodyPart = 'Chest'
                     }, 
                     {
                      BoneNames = ('Neck', 'Head'), 
                      BodyPart = 'Head'
                     }
                    )
    HeadMesh = HeadMesh0
    m_oHairMesh = HairMesh0
    m_oHeadGearMesh = GearMesh0
    LightEnvironment = BioLightEnvComponent0
    Loadout = KaiLengLoadout0
    PowerManager = PowerMgr
    ThreatRadiusSquared = 90000.0
    PowerThreshold_Standard = 9999.0
    PowerThreshold_Stagger = 9999.0
    PowerThreshold_Knockback = 9999.0
    bAffectedByRagdollPowers = FALSE
    bCanPortArms = FALSE
    AffiliationType = EAffiliationType.AffiliationType_Cerberus
    ControllerClass = Class'SFXAI_Agent'
    Mesh = BioPawnSkeletalMeshComponent
    CylinderComponent = CollisionCylinder
    EyeHeight = 80.0
    bCanMantle = TRUE
    bCanClimbUp = TRUE
    bCanSwatTurn = TRUE
    bCanCoverSlip = TRUE
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