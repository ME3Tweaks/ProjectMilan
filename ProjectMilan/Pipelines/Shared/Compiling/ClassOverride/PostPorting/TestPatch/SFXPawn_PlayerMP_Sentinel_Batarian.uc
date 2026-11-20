// Source: ME3, Patch_SFXPwnPlayerMPSentBatarian
// Decompiled 11/17/2026 7:38:01 AM against Batarian_Sentinel_MP.pcc
Class SFXPawn_PlayerMP_Sentinel_Batarian extends SFXPawn_PlayerMP_Sentinel
    placeable
    config(Game);

public simulated function PostBeginPlay()
{
    Super(SFXPawn_PlayerMP).PostBeginPlay();
    StormSpeed = 800.0;
}
public simulated function TakeDamage(float DamageAmount, Controller EventInstigator, Object.Vector HitLocation, Object.Vector Momentum, Class<DamageType> DamageType, optional Actor.TraceHitInfo HitInfo, optional Actor DamageCauser)
{
    local SFXPowerCustomActionMP_BatarianArmor ArmorPower;
    
    Super(BioPawn).TakeDamage(DamageAmount, EventInstigator, HitLocation, Momentum, DamageType, HitInfo, DamageCauser);
    if (ClassIsChildOf(DamageType, Class'SFXDamageType_Melee') || EventInstigator.IsA('SFXAI_Husk'))
    {
        ArmorPower = SFXPowerCustomActionMP_BatarianArmor(PowerManager.GetPowerByClass(Class'SFXPowerCustomActionMP_BatarianArmor'));
        if (ArmorPower != None)
        {
            ArmorPower.OnOwnerMeleed(DamageAmount, EventInstigator, HitLocation, Momentum, DamageType, HitInfo, DamageCauser);
        }
    }
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    Begin Template Class=BioDynamicLightEnvironmentComponent Name=BioLightEnvComponent0
    End Template
    Begin Template Class=CylinderComponent Name=CollisionCylinder
        ReplacementPrimitive = None
    End Template
    Begin Template Class=ForceFeedbackWaveform Name=CoverEnterSound0
    End Template
    Begin Template Class=ForceFeedbackWaveform Name=FootstepShakeFF0
    End Template
    Begin Template Class=SFXCustomizationInstance_PlayerMP Name=AppInstanceMP0
    End Template
    Begin Template Class=SFXModule_AimAssistTarget Name=AimAssistMod
    End Template
    Begin Object Class=SFXModule_Armour Name=BattleDamage0
    End Object
    Begin Template Class=SFXModule_Audio Name=AudioModule
    End Template
    Begin Template Class=SFXModule_Conversation Name=ConvoMod01
    End Template
    Begin Template Class=SFXModule_DamagePlayer Name=DmgMod1
        MaxHealth = {X = 750.0, Y = 750.0}
    End Template
    Begin Template Class=SFXModule_GameEffectManager Name=GEMod0
    End Template
    Begin Template Class=SFXModule_Gestures Name=GestMod01
        Begin Template Class=BioGestureAnimSetMgr Name=oAnimSetMgr
        End Template
        m_pAnimSetMgr = oAnimSetMgr
    End Template
    Begin Template Class=SFXModule_Locomotion Name=Locomotion0
    End Template
    Begin Template Class=SFXModule_LookAt Name=LookAtMod01
    End Template
    Begin Template Class=SFXModule_MarkerPlayer Name=SFXModule_MarkerObjective0
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
    CustomizationMP = AppInstanceMP0
    CoverForceFeedback = CoverEnterSound0
    bCanRoll = FALSE
    bCanBeStopped = FALSE
    FootstepForceFeedback = FootstepShakeFF0
    CustomActionClasses = (None, 
                           Class'SFXCustomAction_Ragdoll', 
                           None, 
                           Class'SFXCustomAction_SyncPawnPartner_Base', 
                           Class'SFXCustomAction_Utilize', 
                           None, 
                           None, 
                           Class'SFXCustomAction_BovineFortitude', 
                           Class'SFXCustomAction_Frozen', 
                           None, 
                           Class'SFXCustomAction_MountedGunReload', 
                           Class'SFXCustomAction_HolsterWeapon', 
                           Class'SFXCustomAction_DrawWeapon', 
                           Class'SFXCustomAction_EnterMountedGun', 
                           Class'SFXCustomAction_ExitMountedGun', 
                           None, 
                           None, 
                           Class'SFXCustomAction_HackDoor', 
                           Class'SFXCustomAction_OmniWave', 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           Class'SFXCustomAction_Cover90TurnRight', 
                           Class'SFXCustomAction_Cover90TurnRightStanding', 
                           Class'SFXCustomAction_Cover90TurnLeft', 
                           Class'SFXCustomAction_Cover90TurnLeftStanding', 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           Class'SFXCustomAction_BackTakeDown', 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           Class'SFXCustomAction_HeavyStdCoverMeleeRight', 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           Class'SFXCustomAction_StandardImpact', 
                           Class'SFXCustomAction_StandardImpactForward', 
                           Class'SFXCustomAction_StandardImpactLeft', 
                           Class'SFXCustomAction_StandardImpactRight', 
                           None, 
                           None, 
                           None, 
                           None, 
                           Class'SFXCustomAction_PlayerShieldStandardImpact', 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           Class'SFXCustomAction_ExplosionBack', 
                           Class'SFXCustomAction_ExplosionForward', 
                           Class'SFXCustomAction_ExplosionLeft', 
                           Class'SFXCustomAction_ExplosionRight', 
                           Class'SFXCustomAction_ShieldFace'
                          )
    CombatWalkSpeed = 330.0
    CoverGroundSpeed = 350.0
    CoverCrouchGroundSpeed = 350.0
    StormSpeed = 800.0
    StormSpeedScale = 1.0
    StormSpeedScaleTime = 3.0
    StormStartSpeed = 0.5
    HeadMesh = HeadMesh0
    m_oHairMesh = HairMesh0
    m_oHeadGearMesh = GearMesh0
    LightEnvironment = BioLightEnvComponent0
    PowerManager = PowerMgr
    AccelRate = 1000.0
    Mesh = BioPawnSkeletalMeshComponent
    CylinderComponent = CollisionCylinder
    bCanSwatTurn = FALSE
    Components = (CollisionCylinder, None, BioLightEnvComponent0, BioPawnSkeletalMeshComponent, HeadMesh0, HairMesh0, GearMesh0)
    Modules = (GEMod0, 
               RadarModule, 
               AimAssistMod, 
               GestMod01, 
               ConvoMod01, 
               LookAtMod01, 
               AudioModule, 
               TimelineMod0, 
               Locomotion0, 
               DmgMod1, 
               SFXModule_MarkerObjective0, 
               BattleDamage0
              )
    CollisionComponent = CollisionCylinder
}