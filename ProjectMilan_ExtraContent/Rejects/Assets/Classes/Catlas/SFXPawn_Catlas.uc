Class SFXPawn_Catlas extends SFXPawn
    placeable
    config(Game);

var RvrClientEffectInterface CE_Damaged[4];
var Guid DamagedGUID;
var transient AnimNodeBlendList CachedReactionNode;
var transient RvrClientEffectInterface CE_Current;
var editinline export SkeletalMeshComponent PSC_BrokenCockpit;
var transient SkelControlSingleBone SmokeLauncherCtrl;
var RvrClientEffectInterface CE_BloodEffect;
var ParticleSystem PS_Footstep;
var editinline transient export PrimitiveComponent LastHitComponent;
var transient int DamageLevel;
var float CockpitOffset;

public simulated function PlayHit(float Damage, Controller instigatedBy, Vector HitLocation, Class<DamageType> DamageType, Vector Momentum, TraceHitInfo HitInfo, Pawn DamageCauser)
{
    Super.PlayHit(Damage, instigatedBy, HitLocation, DamageType, Momentum, HitInfo, DamageCauser);
    UpdateDamageLevel();
    if (CachedReactionNode != None && HitInfo.HitComponent != None && CurrentCustomAction == 0 && ClassIsChildOf(HitInfo.HitComponent.Class, Class'StaticMeshComponent') && HasAnyShieldResistance() == FALSE)
    {
        CachedReactionNode.SetActiveChild(Rand(4) + 1, 0.100000001);
    }
}
public simulated function SetInitialState()
{
    local SFXPawn NewDriver;
    local SFXDifficultyHandler DH;
    local SFXModule_Damage DmgMod;
    local int idx;
    local SFXModule_Armour ArmMod;
    
    Super(Actor).SetInitialState();
    if (WorldInfo.GRI == None)
    {
        SetTimer(0.100000001, FALSE, 'SetInitialState', );
        return;
    }
    DH = SFXGRI(WorldInfo.GRI).DifficultyHandler;
    if (DH != None)
    {
        ArmMod = GetModule(Class'SFXModule_Armour');
        if (ArmMod != None)
        {
            for (idx = 0; idx < 12; idx++)
            {
                if (ArmMod.ActiveArmour[idx] != None)
                {
                    if (ArmMod.ActiveArmour[idx].ArmourName != 'CanopyGlass')
                    {
                        ArmMod.ActiveArmour[idx].CurrentHealth = DH.GetFloat('ArmourPieceHealth', 'Catlas');
                        ArmMod.ActiveArmour[idx].MaxHealth = DH.GetFloat('ArmourPieceHealth', 'Catlas');
                        continue;
                    }
                    ArmMod.ActiveArmour[idx].CurrentHealth = DH.GetFloat('GlassCockpitHealth', 'Catlas');
                    ArmMod.ActiveArmour[idx].MaxHealth = DH.GetFloat('GlassCockpitHealth', 'Catlas');
                }
            }
        }
    }
    SmokeLauncherCtrl = SkelControlSingleBone(Mesh.FindSkelControl('SmokeLauncher'));
    if (SmokeLauncherCtrl != None)
    {
        SmokeLauncherCtrl.SetSkelControlStrength(1.0, 0.0);
        SmokeLauncherCtrl.SetSkelControlActive(FALSE);
    }
}
public simulated function bool ImpactWithPower(EPowerResistance Resistance, Pawn Caster, Vector HitLocation, Vector HitNormal, float Damage, Vector Force, Class<DamageType> DamageType)
{
    local bool bReturnVal;
    
    bReturnVal = Super.ImpactWithPower(Resistance, Caster, HitLocation, HitNormal, Damage, Force, DamageType);
    UpdateDamageLevel();
    return bReturnVal;
}
public simulated function CacheAnimNodes()
{
    local AnimNodeBlendList BlendNode;
    
    Super(BioPawn).CacheAnimNodes();
    if (Mesh != None && Mesh.Animations != None)
    {
        foreach Mesh.AllAnimNodes(Class'AnimNodeBlendList', BlendNode)
        {
            if (BlendNode.NodeName == 'None')
            {
                continue;
            }
            if (BlendNode.NodeName == 'LightReactions')
            {
                CachedReactionNode = BlendNode;
                break;
            }
        }
    }
}
public simulated function ClearAnimNodes()
{
    Super(BioPawn).ClearAnimNodes();
    CachedReactionNode = None;
}
public simulated function bool ModifyDamage(out float Damage, Vector Momentum, out DamageCalculationAlgorithm DamageCalc, const out TraceHitInfo HitInfo, Vector HitLocation, Class<SFXDamageType> DamageType, Controller instigatedBy, Actor DamageCauser)
{
    local SFXAI_Core AI;
    local SFXWeapon ChkWeapon;
    
    if (Super(BioPawn).ModifyDamage(Damage, Momentum, DamageCalc, HitInfo, HitLocation, DamageType, instigatedBy, DamageCauser) == FALSE)
    {
        return FALSE;
    }
    AI = SFXAI_Core(Controller);
    if (AI != None)
    {
        ChkWeapon = SFXWeapon(DamageCauser);
        if (ChkWeapon != None && ChkWeapon.GetPenetrationDepth() > 0.0)
        {
            if (LastHitComponent != None && LastHitComponent != Mesh && HitInfo.HitComponent == Mesh && WorldInfo.GameTimeSeconds - AI.LastDamagedTime <= 0.100000001)
            {
                return FALSE;
            }
        }
    }
    LastHitComponent = HitInfo.HitComponent;
    return TRUE;
}
public simulated function PlayDying(Class<DamageType> DamageType, Vector HitLoc)
{
    Super.PlayDying(DamageType, HitLoc);
    if (CE_Current != None)
    {
        Class'RvrClientEffectManager'.static.GetClientEffectManager().Stop(CE_Current, DamagedGUID, FALSE, Self);
        CE_Current = None;
    }
}
public simulated function bool CanPlayDeathEffect()
{
    return FALSE;
}
public simulated function ParticleSystem GetSpecificFootStepEffect(SFXPhysicalMaterialFootSteps FootStepMat, int FootDown)
{
    return PS_Footstep;
}
public simulated function NotifyHealed()
{
    Super.NotifyHealed();
    UpdateDamageLevel(TRUE);
}
public function CloseLauncherPort()
{
    if (SmokeLauncherCtrl != None)
    {
        SmokeLauncherCtrl.SetSkelControlActive(FALSE);
    }
}
public function Vector GetSmokeLauncherFireLoc()
{
    local Vector Loc;
    local Rotator Rot;
    
    if (Mesh != None)
    {
        if (Mesh.GetSocketWorldLocationAndRotation('Socket_grenLauncher', Loc, Rot))
        {
            return Loc;
        }
    }
    return vect(0.0, 0.0, 0.0);
}
public function HideMeshes()
{
    local int idx;
    local SFXModule_Armour ArmMod;
    
    Mesh.SetHidden(TRUE);
    ArmMod = GetModule(Class'SFXModule_Armour');
    if (ArmMod != None)
    {
        for (idx = 0; idx < 12; idx++)
        {
            if (ArmMod.ActiveArmour[idx].AttachInstance != None)
            {
                ArmMod.ActiveArmour[idx].AttachInstance.SetHidden(TRUE);
            }
        }
    }
    Class'RvrClientEffectManager'.static.GetClientEffectManager().HideOn(Self, TRUE);
}

public function OpenLauncherPort()
{
    if (SmokeLauncherCtrl != None)
    {
        SmokeLauncherCtrl.SetSkelControlActive(TRUE);
    }
}

public function ShowMeshes()
{
    local int idx;
    local SFXModule_Armour ArmMod;
    
    Mesh.SetHidden(FALSE);
    ArmMod = GetModule(Class'SFXModule_Armour');
    if (ArmMod != None)
    {
        for (idx = 0; idx < 12; idx++)
        {
            if (ArmMod.ActiveArmour[idx].AttachInstance != None)
            {
                ArmMod.ActiveArmour[idx].AttachInstance.SetHidden(FALSE);
            }
        }
    }
    Class'RvrClientEffectManager'.static.GetClientEffectManager().HideOn(Self, FALSE);
}
public simulated function UpdateDamageLevel(optional bool bForced)
{
    local float HealthPct;
    local int NewDamageLevel;
    
    if (!IsDead() && (HasAnyShieldResistance() == FALSE || bForced))
    {
        HealthPct = GetHealthPct();
        if (HealthPct <= 1.0)
        {
            NewDamageLevel = int((float(1) - HealthPct) * 4.0);
            if (NewDamageLevel != DamageLevel)
            {
                if (CE_Current != None)
                {
                    Class'RvrClientEffectManager'.static.GetClientEffectManager().Stop(CE_Current, DamagedGUID, FALSE, Self);
                }
                CE_Current = CE_Damaged[NewDamageLevel];
                DamagedGUID = Class'RvrClientEffectManager'.static.GetClientEffectManager().Start(CE_Current, Self);
                DamageLevel = NewDamageLevel;
            }
        }
    }
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    Begin Template Class=CylinderComponent Name=CollisionCylinder
        CollisionHeight = 190.0
        CollisionRadius = 135.0
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
    Begin Object Class=SkeletalMeshComponent Name=BrokenCockpit0
        SkeletalMesh = SkeletalMesh'BioVFX_Crt_Atlas.Meshes.CRB_ATA_CanopyGlass_Broken'
        bIgnoreControllersWhenNotRendered = TRUE
        ReplacementPrimitive = None
        LightEnvironment = BioLightEnvComponent0
    End Object
    Begin Template Class=ForceFeedbackWaveform Name=FootstepShakeFF0
        Samples = ({Duration = 0.400000006, LeftAmplitude = 80, RightAmplitude = 80, LeftFunction = EWaveformFunction.WF_LinearDecreasing, RightFunction = EWaveformFunction.WF_LinearDecreasing}
                  )
    End Template
    Begin Template Class=SFXModule_GameEffectManager Name=GEMod0
    End Template
    Begin Template Class=SFXModule_Radar Name=RadarModule
    End Template
    Begin Template Class=SFXModule_AimAssistTarget Name=AimAssistMod
        AimAssistRegions = ({Width = 120.0, Height = 80.0, SoftMargin = 80.0, NodeType = EAimNodes.AimNode_Groin}, 
                            {Width = 80.0, Height = 50.0, SoftMargin = 80.0, NodeType = EAimNodes.AimNode_Groin}, 
                            {Width = 80.0, Height = 80.0, SoftMargin = 80.0, NodeType = EAimNodes.AimNode_Cover}
                           )
    End Template
    Begin Template Class=SFXModule_Damage Name=DmgMod0
        HealthType = EHealthType.HealthType_Armour
    End Template
    Begin Template Class=SFXModule_Gestures Name=GestMod01
        Begin Object Class=BioGestureAnimSetMgr Name=oAnimSetMgr_0
        End Object
        m_pAnimSetMgr = oAnimSetMgr_0
    End Template
    Begin Template Class=SFXModule_Conversation Name=ConvoMod01
        m_bDisableFacefx = TRUE
    End Template
    Begin Template Class=SFXModule_LookAt Name=LookAtMod01
    End Template
    Begin Template Class=SFXModule_Audio Name=AudioModule
        bPlayFootstepSounds = FALSE
    End Template
    Begin Template Class=SFXModule_Timeline Name=TimelineMod0
    End Template
    Begin Object Class=SFXModule_Armour Name=BattleDamage0
    End Object
    Begin Object Class=SFXLoadoutData Name=AtlasLoadout0
        Weapons = (Class'SFXWeapon_Heavy_Atlas')
        ShieldLoadouts = ({
                           Shields = Class'SFXShield_Energy', 
                           ShieldLevelRange = {X = 0.0, Y = 0.0}, 
                           MaxShields = {X = 1500.0, Y = 1500.0}
                          }
                         )
    End Object
    Begin Template Class=SFXPowerManager Name=PowerMgr
    End Template
    CE_Damaged[0] = RvrClientEffect'BioVFX_Crt_Atlas.VCFX.Atlas_Damage_lvl_1'
    CE_Damaged[1] = RvrClientEffect'BioVFX_Crt_Atlas.VCFX.Atlas_Damage_lvl_2'
    CE_Damaged[2] = RvrClientEffect'BioVFX_Crt_Atlas.VCFX.Atlas_Damage_lvl_3'
    CE_Damaged[3] = RvrClientEffect'BioVFX_Crt_Atlas.VCFX.Atlas_Damage_lvl_4'
    PSC_BrokenCockpit = BrokenCockpit0
    CE_BloodEffect = RvrClientEffect'BioVFX_C_Wpn_Scorpion.VCFX.Scorpion_Imp_VCFX'
    PS_Footstep = ParticleSystem'BioVFX_Env_Dust.Particles.Dust_Puff_wDebris_01'
    DamageLevel = -1
    CockpitOffset = -5.0
    FootstepShake = {
                     RotAmplitude = {X = 60.0, Y = 60.0, Z = 60.0}, 
                     RotFrequency = {X = 120.0, Y = 160.0, Z = 200.0}, 
                     TimeDuration = 0.400000006
                    }
    MuzzleSocketName = 'Socket_cannon'
    FootstepForceFeedback = FootstepShakeFF0
    PowerControlResistance = 0.5
    CodexPlotState = 21717
    DamageScoreBudget = 1000.0
    KillBonusScore = 100.0
    PowerControlAssistBudget = 250.0
    bPlayFootstepScreenShake = TRUE
    bPlayFootstepRumble = TRUE
    bSupportsVisibleWeapons = FALSE
    bCanBeRepaired = TRUE
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
                           Class'SFXCustomAction_AtlasOrbitalDrop', 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           Class'SFXCustomAction_CatlasMantle', 
                           None, 
                           Class'SFXCustomAction_CatlasClimbUp', 
                           Class'SFXCustomAction_CatlasClimbDown', 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           Class'SFXCustomAction_AtlasStagger', 
                           Class'SFXCustomAction_AtlasStandard', 
                           Class'SFXCustomAction_AtlasStandardForward', 
                           Class'SFXCustomAction_AtlasStandardLeft', 
                           Class'SFXCustomAction_AtlasStandardRight', 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           Class'SFXCustomAction_AtlasDeathExplosion', 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           Class'SFXCustomAction_AtlasMelee', 
                           Class'SFXCustomAction_AtlasHeavyMelee', 
                           Class'SFXCustomAction_AtlasSyncMelee', 
                           Class'SFXCustomAction_AtlasHeavyMelee', 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           Class'SFXCustomAction_AtlasPlayerSmokeShot', 
                           Class'SFXCustomAction_CatlasBlock'
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
                                None, 
                                None, 
                                Class'SFXPowerCustomAction_MIRVBomb'
                               )
    SupportedCustomReachSpecs = (Class'SFXLargeMantleReachSpec', Class'SFXLargeClimbReachSpec')
    CombatVocVariants = (SFXVocalizationBank'VocalizationBanks.ss_c_atlas')
    AimNodes = ('FAKE_Cover', 
                'Spine01', 
                'leftArmClav', 
                'rightArmClav', 
                'Spine01', 
                'Pelvis', 
                'LeftUpperLeg', 
                'RightUpperLeg'
               )
    ReactionBones = ({
                      BoneNames = ('LeftFoot', 'leftCalf', 'left_RearCalf', 'leftMidLeg', 'LeftUpperLeg', 'LeftHip'), 
                      BodyPart = 'LeftLeg'
                     }, 
                     {
                      BoneNames = ('RightFoot', 'rightCalf', 'right_RearCalf', 'rightMidLeg', 'RightUpperLeg', 'RightHip'), 
                      BodyPart = 'RightLeg'
                     }, 
                     {
                      BoneNames = ('LeftClaw02', 
                                   'LeftClaw01', 
                                   'RightClaw02', 
                                   'RightClaw01', 
                                   'LeftHand', 
                                   'LeftArm', 
                                   'LeftShoulder', 
                                   'leftArmClav'
                                  ), 
                      BodyPart = 'LeftArm'
                     }, 
                     {
                      BoneNames = ('RightArm', 'RightShoulder', 'rightArmClav'), 
                      BodyPart = 'RightArm'
                     }, 
                     {
                      BoneNames = ('Root', 'Pelvis', 'Spine', 'God', 'Spine01'), 
                      BodyPart = 'Chest'
                     }
                    )
    RightHandSocketName = 'Socket_cannon'
    HeadMesh = HeadMesh0
    m_oHairMesh = HairMesh0
    m_oHeadGearMesh = GearMesh0
    LightEnvironment = BioLightEnvComponent0
    Loadout = AtlasLoadout0
    CE_LifetimeCrust = RvrClientEffect'BioVFX_Crt_Atlas.VCFX.Atlas_Jet_LifetimeCrust'
    PowerManager = PowerMgr
    DeathCustomAction = 120
    AimOffsetInterpSpeed = 6.0
    AimOriginOffset = 100.0
    FollowDistanceModifier = 400.0
    bSpawnPHATInstance = FALSE
    bCanRagdoll = FALSE
    bUseLargeReactions = TRUE
    m_bHideWithCameraCollision = FALSE
    bCanPortArms = FALSE
    bAdjustMeshTranslationOnSlopes = TRUE
    RaceType = ERaceType.RaceType_Machine
    CharacterType = ECharacterType.CharacterType_Cerberus_Atlas
    AffiliationType = EAffiliationType.AffiliationType_Cerberus
    ControllerClass = Class'SFXAI_Catlas'
    Mesh = BioPawnSkeletalMeshComponent
    CylinderComponent = CollisionCylinder
    SightRadius = 4000.0
    BaseEyeHeight = 130.0
    EyeHeight = 130.0
    ViewPitchMin = -4096.0
    ViewPitchMax = 4096.0
    bCanCrouch = FALSE
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
               TimelineMod0, 
               BattleDamage0
              )
    CollisionComponent = CollisionCylinder
    bIgnoreRigidBodyPawns = TRUE
}