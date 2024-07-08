Class SFXPawn_Forerunner extends SFXPawn
    placeable
    config(Game);


public simulated function EPowerResistance GetPowerResistance(Pawn Caster, Vector HitLocation, Vector HitNormal, out float Damage, out Vector Force, Class<DamageType> DamageType, out Actor TargetOverride)
{
    if (bIsInRagdollRecovery)
    {
        return 1;
    }
    return Super.GetPowerResistance(Caster, HitLocation, HitNormal, Damage, Force, DamageType, TargetOverride);
}

public simulated function ForerunnerCloak()
{
    // Must be in Pawn class or it will not replicate.
    // AI will call this method, which will run on clients.
    local SFXModule_GameEffectManager GEManager;
    local SFXSelectionModule SelectionModule;
    
    LogInternal(Self $ " - " $ GetFuncName());
    GEManager = GetModule(Class'SFXModule_GameEffectManager');
    if (GEManager != None)
    {
        GEManager.RemoveEffectsByTypeAndCategory(Class'SFXGameEffect_Cloak', Name);
        GEManager.CreateAndApplyEffect(Class'SFXGameEffect_Cloak', Name, 0.0, 2, 0.0);
    }
    SelectionModule = GetModule(Class'SFXSelectionModule');
    if (SelectionModule != None)
    {
        SelectionModule.SetCombatTargetable(FALSE);
    }
}

public simulated function ForerunnerDecloak()
{
    // Must be in Pawn class or it will not replicate.
    // AI will call this method, which will run on clients.
    local SFXModule_GameEffectManager GEManager;
    local SFXSelectionModule SelectionModule;
    
    LogInternal(Self $ " - " $ GetFuncName());
    GEManager = GetModule(Class'SFXModule_GameEffectManager');
    if (GEManager != None)
    {
        GEManager.RemoveEffectsByTypeAndCategory(Class'SFXGameEffect_Cloak', Name);
    }
    SelectionModule = GetModule(Class'SFXSelectionModule');
    if (SelectionModule != None)
    {
        SelectionModule.SetCombatTargetable(TRUE);
    }
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    Begin Template Class=SFXModule_Gestures Name=GestMod01
        Begin Template Class=BioGestureAnimSetMgr Name=oAnimSetMgr
        End Template
        m_pAnimSetMgr = oAnimSetMgr
    End Template
    Begin Template Class=ForceFeedbackWaveform Name=FootstepShakeFF0
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
    Begin Template Class=BioDynamicLightEnvironmentComponent Name=BioLightEnvComponent0
    End Template
    Begin Template Class=SkeletalMeshComponent Name=BioPawnSkeletalMeshComponent
        ReplacementPrimitive = None
        LightEnvironment = BioLightEnvComponent0
    End Template
    Begin Template Class=CylinderComponent Name=CollisionCylinder
        ReplacementPrimitive = None
    End Template
    Begin Template Class=SFXModule_GameEffectManager Name=GEMod0
    End Template
    Begin Template Class=SFXModule_Radar Name=RadarModule
    End Template
    Begin Template Class=SFXModule_AimAssistTarget Name=AimAssistMod
    End Template
    Begin Template Class=SFXModule_Damage Name=DmgMod0
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
    Begin Object Class=SFXLoadoutData Name=CerbNemesisLoadout0
        Weapons = (Class'SFXWeapon_AI_Crusader')
        ShieldLoadouts = ({
                           Shields = Class'SFXShield_Energy', 
                           ShieldLevelRange = {X = 0.0, Y = 0.0}, 
                           MaxShields = {X = 3000.0, Y = 3000.0}
                          }
                         )
    End Object
    Begin Template Class=SFXPowerManager Name=PowerMgr
    End Template
    PowerImpactNotifications = ({Label = 'CombatRoll', TimeBeforeImpact = 0.5}
                               )
    CE_HeadGibCap = RvrClientEffect'BioVFX_C_Blood.VCFX.HeadGib_Cap_Fem_VCFX'
    FootstepForceFeedback = FootstepShakeFF0
    PowerControlResistance = 0.5
    bCanPartialLean = TRUE
    CustomActionClasses = (None, 
                           Class'SFXCustomAction_Ragdoll', 
                           Class'SFXCustomAction_AnimRagdollSingularity', 
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
                           None, 
                           None, 
                           None, 
                           None, 
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
                           Class'SFXCustomAction_JumpDown', 
                           Class'SFXCustomAction_AIMantleOverCover', 
                           None, 
                           Class'SFXCustomAction_AIMantleUp', 
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
                           Class'SFXCustomAction_BoostDown', 
                           Class'SFXCustomAction_BoostUp', 
                           None, 
                           None, 
                           None, 
                           None, 
                           Class'SFXCustomAction_RollLeft', 
                           Class'SFXCustomAction_RollRight', 
                           Class'SFXCustomAction_RollForward', 
                           Class'SFXCustomAction_RollBackward', 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
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
                           Class'SFXCustomAction_StandardImpactII', 
                           Class'SFXCustomAction_StandardImpactForward', 
                           Class'SFXCustomAction_StandardImpactLeft', 
                           Class'SFXCustomAction_StandardImpactRight', 
                           Class'SFXCustomAction_StandardImpactKnee', 
                           Class'SFXCustomAction_StaggerImpact', 
                           Class'SFXCustomAction_StaggerImpactII', 
                           Class'SFXCustomAction_StaggerImpactForward', 
                           Class'SFXCustomAction_StaggerImpactLeft', 
                           Class'SFXCustomAction_StaggerImpactRight', 
                           Class'SFXCustomAction_KnockbackImpact', 
                           Class'SFXCustomAction_KnockbackImpactForward', 
                           Class'SFXCustomAction_KnockbackImpactLeft', 
                           Class'SFXCustomAction_KnockbackImpactRight', 
                           Class'SFXCustomAction_Meleed', 
                           Class'SFXCustomAction_MeleedForward', 
                           Class'SFXCustomAction_MeleedLeft', 
                           Class'SFXCustomAction_MeleedRight', 
                           Class'SFXCustomAction_ShieldBreach', 
                           Class'SFXCustomAction_FlinchLight', 
                           Class'SFXCustomAction_FlinchHeavy', 
                           None, 
                           None, 
                           Class'SFXCustomAction_GreatPain', 
                           Class'SFXCustomAction_GreatPainII', 
                           Class'SFXCustomAction_Freezing', 
                           Class'SFXCustomAction_FreezingII', 
                           Class'SFXCustomAction_FreezingIII', 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           Class'SFXCustomAction_DeathReaction_GibHeadshot', 
                           Class'SFXCustomAction_DeathReaction_LeftArm', 
                           Class'SFXCustomAction_DeathReaction_RightArm', 
                           Class'SFXCustomAction_DeathReaction_HeavyLeftArm', 
                           Class'SFXCustomAction_DeathReaction_HeavyRightArm', 
                           Class'SFXCustomAction_DeathReaction_LeftLeg', 
                           Class'SFXCustomAction_DeathReaction_RightLeg', 
                           Class'SFXCustomAction_DeathReaction_Stomach', 
                           Class'SFXCustomAction_DeathReaction_GibKnockback', 
                           Class'SFXCustomAction_DeathReaction_Corkscrew', 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           Class'SFXCustomAction_IdleSniperSweep'
                          )
    SupportedCustomReachSpecs = (Class'SFXBoostReachSpec', Class'SFXLadderReachSpec', Class'SFXJumpReachSpec', Class'SFXJumpDownReachSpec')
    SupportedSyncActions = ('AtlasSync', 'PhantomSync', 'KaiLengSync', 'HuskSync', 'BruteSync', 'BansheeSync')
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
    Loadout = CerbNemesisLoadout0
    PowerManager = PowerMgr
    bCanPortArms = FALSE
    CharacterType = ECharacterType.CharacterType_Cerberus_Nemesis
    AffiliationType = EAffiliationType.AffiliationType_GenericMerc
    ControllerClass = Class'SFXAI_Forerunner'
    Mesh = BioPawnSkeletalMeshComponent
    CylinderComponent = CollisionCylinder
    SightRadius = 5000.0
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