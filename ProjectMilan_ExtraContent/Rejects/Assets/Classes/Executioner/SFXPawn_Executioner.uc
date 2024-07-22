Class SFXPawn_Executioner extends SFXPawn
    placeable
    config(Game);

enum EExecutionerMood {
    Defensive, // Backpedaling to cover
    Offensive, // On the attack
    Reckless   // Preparing to execute! 
}

var SFXLoadoutData Loadout_Assault;
var SFXLoadoutData Loadout_Sniper;
var SFXLoadoutData Loadout_Shotgun;
var SFXLoadoutData Loadout_Pistol;
var float LastReactionTime;
var float ReactionInterval;

public simulated function Destroyed()
{
    local SFXAI_Executioner MyAI;
    
    MyAI = SFXAI_Executioner(Controller);
    if (MyAI != None)
    {
        ClearPersistentStuff();
    }
    Super(BioPawn).Destroyed();
}
public function bool Died(Controller Killer, Class<DamageType> DamageType, Vector HitLocation)
{
    local SFXAI_Executioner MyAI;
    local bool DiedReturn;
    
    DiedReturn = Super.Died(Killer, DamageType, HitLocation);
    MyAI = SFXAI_Executioner(Controller);
    if (MyAI != None)
    {
        ClearPersistentStuff();
    }
    return DiedReturn;
}
public simulated function ClearPersistentStuff()
{
    local SFXPowerCustomAction_CloneDenial DenialGrenade;
    local SFXPowerCustomAction_CloneDenial_Biotic BioticDenialGrenade;
    local SFXPowerCustomAction_ExecutionerDrone ExecutionerDrone;
    
    if (PowerManager != None)
    {
        DenialGrenade = SFXPowerCustomAction_CloneDenial(PowerManager.GetPowerByClass(Class'SFXPowerCustomAction_CloneDenial'));
        if (DenialGrenade != None)
        {
            DenialGrenade.ClearDenialZones();
        }
        BioticDenialGrenade = SFXPowerCustomAction_CloneDenial_Biotic(PowerManager.GetPowerByClass(Class'SFXPowerCustomAction_CloneDenial_Biotic'));
        if (BioticDenialGrenade != None)
        {
            BioticDenialGrenade.ClearDenialZones();
        }
        if (SFXAI_Executioner(Controller) != None && SFXAI_Executioner(Controller).ExecutionerClass == CloneClassType.CloneClass_Engineer)
        {
            ExecutionerDrone = SFXPowerCustomAction_ExecutionerDrone(PowerManager.GetPowerByClass(Class'SFXPowerCustomAction_ExecutionerDrone'));
            if (ExecutionerDrone != None && ExecutionerDrone.Drone != None)
            {
                ExecutionerDrone.DespawnDrone(ExecutionerDrone.Drone);
            }
        }
    }
}
protected function bool GetKnockbackReactions(float Angle, float SideAngle, out array<EAICustomAction> OutActions)
{
    if (WorldInfo.GameTimeSeconds - LastLargeReactionTime > LargeReactionInterval)
    {
        LastLargeReactionTime = WorldInfo.GameTimeSeconds;
        return Super(BioPawn).GetKnockbackReactions(Angle, SideAngle, OutActions);
    }
    return GetStandardReactions(Angle, SideAngle, OutActions);
}
protected function bool GetMeleeReactions(float Angle, float SideAngle, out array<EAICustomAction> OutActions)
{
    if (WorldInfo.GameTimeSeconds - LastReactionTime > ReactionInterval)
    {
        LastReactionTime = WorldInfo.GameTimeSeconds;
        return Super(BioPawn).GetMeleeReactions(Angle, SideAngle, OutActions);
    }
    return GetStandardReactions(Angle, SideAngle, OutActions);
}
protected function bool GetStaggerReactions(float Angle, float SideAngle, out array<EAICustomAction> OutActions)
{
    if (WorldInfo.GameTimeSeconds - LastLargeReactionTime > LargeReactionInterval)
    {
        LastLargeReactionTime = WorldInfo.GameTimeSeconds;
        return Super(BioPawn).GetStaggerReactions(Angle, SideAngle, OutActions);
    }
    return GetStandardReactions(Angle, SideAngle, OutActions);
}
protected function bool GetStandardReactions(float Angle, float SideAngle, out array<EAICustomAction> OutActions)
{
    if (WorldInfo.GameTimeSeconds - LastReactionTime > ReactionInterval)
    {
        LastReactionTime = WorldInfo.GameTimeSeconds;
        return Super(BioPawn).GetStandardReactions(Angle, SideAngle, OutActions);
    }
    return FALSE;
}

public simulated function SetMoodColor(EExecutionerMood mood){
    local MaterialInstance Mat;
    local MeshComponent Comp;
    local LinearColor Value;
    local int i;
    
    Value.A = 1;
    if (mood == EExecutionerMood.Defensive) {
        Value.R = 0.0f;
        Value.G = 0.035f;
        Value.B = 0.08f;
    } 
    else if (mood == EExecutionerMood.Offensive)
    {
        Value.R = 0.278f;
        Value.G = 0.278f;
        Value.B = 0.008f;
    }
    else if (mood == EExecutionerMood.Reckless)
    {
        Value.R = 0.89f;
        Value.G = 0.008f;
        Value.B = 0.0f;        
    }

    foreach AllOwnedComponents(Class'MeshComponent', Comp)
    {
        for (i = 0; i < Comp.GetNumElements(); i++)
        {
            Mat = MaterialInstance(Comp.GetMaterial(i));
            if (Mat != None)
            {
                Mat.SetVectorParameterValue('None', Value);
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
    Begin Object Class=SFXLoadoutData Name=CloneAssaultLoadout0
        Weapons = (Class'SFXWeapon_AI_Valkyrie')
    End Object
    Begin Object Class=SFXLoadoutData Name=CloneSniperLoadout0
        Weapons = (Class'SFXWeapon_AI_BlackWidow')
    End Object
    Begin Object Class=SFXLoadoutData Name=CloneShotgunLoadout0
        Weapons = (Class'SFXWeapon_AI_Wraith')
    End Object
    Begin Object Class=SFXLoadoutData Name=ClonePistolLoadout0
        Weapons = (Class'SFXWeapon_AI_Hurricane')
    End Object
    Begin Template Class=ForceFeedbackWaveform Name=FootstepShakeFF0
    End Template
    Begin Object Class=SFXLoadoutData Name=ExecutionerLoadout0
        Weapons = (Class'SFXWeapon_AI_Wraith')
        ShieldLoadouts = ({
                           Shields = Class'SFXShield_Energy', 
                           ShieldLevelRange = {X = 0.0, Y = 0.0}, 
                           MaxShields = {X = 3000.0, Y = 3000.0}
                          }
                         )
    End Object
    Begin Template Class=SFXPowerManager Name=PowerMgr
    End Template
    Begin Template Class=SFXModule_GameEffectManager Name=GEMod0
    End Template
    Begin Template Class=SFXModule_Radar Name=RadarModule
    End Template
    Begin Template Class=SFXModule_AimAssistTarget Name=AimAssistMod
        m_srGameName = $13250208
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
    Begin Object Class=SFXModule_Damage Name=DmgMod1
        HealthType = EHealthType.HealthType_Armour
        MaxHealth = {X = 100.0, Y = 100.0}
    End Object
    Loadout_Assault = CloneAssaultLoadout0
    Loadout_Sniper = CloneSniperLoadout0
    Loadout_Shotgun = CloneShotgunLoadout0
    Loadout_Pistol = ClonePistolLoadout0
    MeleedVoc = WwiseEvent'VocalizationBanks.SS_ss_c_trooper_Instigator_ReceivedDamage_SpecificType_None_m_Play'
    ReactionInterval = 3.0
    PowerImpactNotifications = ({Label = 'CombatRoll', TimeBeforeImpact = 0.5}
                               )
    FootstepForceFeedback = FootstepShakeFF0
    CombatVocVariants = (SFXVocalizationBank'VocalizationBanks.ss_c_trooper')
    PowerControlResistance = 1.0
    bCanPartialLean = TRUE
    bCanUseTurrets = TRUE
    bCanDriveAtlas = TRUE
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
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           Class'SFXCustomAction_RollLeft_Clone', 
                           Class'SFXCustomAction_RollRight_Clone', 
                           Class'SFXCustomAction_RollForward_Clone', 
                           Class'SFXCustomAction_RollBackward_Clone', 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
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
                           Class'SFXCustomAction_StaggerImpact', 
                           Class'SFXCustomAction_StaggerImpactForward', 
                           Class'SFXCustomAction_StaggerImpactLeft', 
                           Class'SFXCustomAction_StaggerImpactRight', 
                           Class'SFXCustomAction_Meleed', 
                           Class'SFXCustomAction_MeleedForward', 
                           Class'SFXCustomAction_MeleedLeft', 
                           Class'SFXCustomAction_MeleedRight', 
                           Class'SFXCustomAction_ShieldBreach', 
                           Class'SFXCustomAction_FlinchLight', 
                           Class'SFXCustomAction_FlinchHeavy', 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
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
                           Class'SFXCustomAction_ClonePunch_Soldier', 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           Class'SFXCustomAction_ClonePunch_Sentinel', 
                           Class'SFXCustomAction_ClonePunch_Vanguard', 
                           Class'SFXCustomAction_ClonePunch_Infiltrator', 
                           Class'SFXCustomAction_ClonePunch_Engineer', 
                           Class'SFXCustomAction_ClonePunch_Adept', 
                           Class'SFXCustomAction_ClonePunch_Soldier', 
                           None, 
                           None, 
                           Class'SFXCustomAction_ExecutionerCharge', 
                           None
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
                                None, 
                                None, 
                                None, 
                                None, 
                                None, 
                                Class'SFXPowerCustomAction_ExecutionerDrone', 
                                None, 
                                None, 
                                None, 
                                Class'SFXPowerCustomAction_CloneDenial', 
                                None, 
                                None, 
                                None, 
                                None, 
                                None, 
                                None, 
                                None, 
                                None, 
                                None, 
                                None, 
                                None, 
                                None, 
                                None, 
                                None, 
                                None, 
                                Class'SFXPowerCustomAction_CloneProjectile_Warp', 
                                Class'SFXPowerCustomAction_CloneProjectile_Carnage', 
                                Class'SFXPowerCustomAction_CloneProjectile_Incinerate', 
                                None, 
                                None, 
                                None, 
                                None, 
                                Class'SFXPowerCustomAction_CloneDenial_Biotic'
                               )
    SupportedCustomReachSpecs = (Class'SFXLadderReachSpec', Class'SFXJumpReachSpec', Class'SFXJumpDownReachSpec')
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
                      BoneNames = ('LeftShoulder', 'LeftElbow'), 
                      BodyPart = 'LeftArm'
                     }, 
                     {
                      BoneNames = ('RightShoulder', 'RightElbow'), 
                      BodyPart = 'RightArm'
                     }, 
                     {
                      BoneNames = ('Root', 'LowerBack', 'Chest'), 
                      BodyPart = 'Chest'
                     }, 
                     {
                      BoneNames = ('Neck'), 
                      BodyPart = 'Head'
                     }
                    )
    HeadMesh = HeadMesh0
    m_oHairMesh = HairMesh0
    m_oHeadGearMesh = GearMesh0
    LightEnvironment = BioLightEnvComponent0
    DyingSound = WwiseEvent'Wwise_Crt_Cerb_Generic_SFX.Play_crt_cerb_gen_deathsweet_trooper'
    Loadout = ExecutionerLoadout0
    PowerManager = PowerMgr
    LargeReactionInterval = 6.0
    bCanPortArms = FALSE
    CharacterType = ECharacterType.CharacterType_Cerberus_Trooper
    AffiliationType = EAffiliationType.AffiliationType_GenericMerc
    ControllerClass = Class'SFXAI_Executioner'
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
               GestMod01, 
               ConvoMod01, 
               LookAtMod01, 
               AudioModule, 
               TimelineMod0, 
               DmgMod1
              )
    CollisionComponent = CollisionCylinder
}