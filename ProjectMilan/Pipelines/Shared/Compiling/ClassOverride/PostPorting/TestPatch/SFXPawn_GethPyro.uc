// Source: ME3, Patch_SFXPawn_GethPyro
// Decompiled 11/17/2026 7:37:58 AM against BioD_Gth002_210Tower.pcc
Class SFXPawn_GethPyro extends SFXPawn
    placeable
    config(Game);

struct PyroFlameLeaks 
{
    var Name SocketName;
    var instanced ParticleSystemComponent PSC_Leak;
    var float HealthPctThreshold;
    var bool bActive;
};

var array<SFXPawn_GethPyro.PyroFlameLeaks> FlameLeaks;
var WwiseEvent TankPunctureSound;
var RvrClientEffectInterface CE_TankExplosion;
var WwiseEvent ExplosionSound;
var instanced LensFlareComponent LF_GethLensFlare;

public simulated function PostBeginPlay()
{
    Super.PostBeginPlay();
    Mesh.AttachComponentToSocket(LF_GethLensFlare, 'Socket_Lens01');
}
public simulated function SetInitialState()
{
    local SFXDifficultyHandler DH;
    local SFXArmourPiece piece;
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
            piece = ArmMod.GetArmourPieceByName('Tank');
            if (piece != None)
            {
                piece.CurrentHealth = DH.GetFloat('TankHealth', 'GethPyro');
                piece.MaxHealth = DH.GetFloat('TankHealth', 'GethPyro');
            }
        }
    }
}
public simulated function Actor.EPowerResistance GetPowerResistance(Pawn Caster, Object.Vector HitLocation, Object.Vector HitNormal, out float Damage, out Object.Vector Force, Class<DamageType> DamageType, out Actor TargetOverride)
{
    if (ClassIsChildOf(DamageType, Class'SFXDamageType_Power_Fire'))
    {
        return 1;
    }
    return Super.GetPowerResistance(Caster, HitLocation, HitNormal, Damage, Force, DamageType, TargetOverride);
}
public simulated function PlayDying(Class<DamageType> DamageType, Object.Vector HitLoc)
{
    Super.PlayDying(DamageType, HitLoc);
    LF_GethLensFlare.SetIsActive(FALSE);
    if (ClassIsChildOf(DamageType, Class'SFXDamageType_GethPyroTankExplosion') || ClassIsChildOf(DamageType, Class'SFXDamageType_Incinerate') || ClassIsChildOf(DamageType, Class'SFXDamageType_Power_Electrocute'))
    {
        Class'RvrClientEffectManager'.static.GetClientEffectManager().Play(CE_TankExplosion, Self);
        PlaySound(ExplosionSound, TRUE);
    }
}
public simulated function NotifyArmourAppearanceUpdated(int ArmourIdx)
{
    local SFXModule_Armour ArmMod;
    local int idx;
    local float ArmourPct;
    local bool bPlayPunctureSound;
    
    Super(BioPawn).NotifyArmourAppearanceUpdated(ArmourIdx);
    ArmMod = GetModule(Class'SFXModule_Armour');
    if (ArmMod != None)
    {
        ArmourPct = ArmMod.GetArmourHealthPct(ArmourIdx);
        for (idx = 0; idx < FlameLeaks.Length; idx++)
        {
            if (FlameLeaks[idx].bActive == FALSE && ArmourPct < FlameLeaks[idx].HealthPctThreshold)
            {
                ActivateFlameLeak(idx);
                bPlayPunctureSound = TRUE;
            }
        }
        if (bPlayPunctureSound)
        {
            PlaySound(TankPunctureSound, TRUE);
        }
    }
}
private final simulated function ActivateFlameLeak(int LeakIdx)
{
    if (LeakIdx >= 0 && LeakIdx < FlameLeaks.Length)
    {
        Mesh.AttachComponentToSocket(FlameLeaks[LeakIdx].PSC_Leak, FlameLeaks[LeakIdx].SocketName);
        FlameLeaks[LeakIdx].PSC_Leak.SetActive(TRUE);
        FlameLeaks[LeakIdx].bActive = TRUE;
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
    Begin Template Class=ForceFeedbackWaveform Name=FootstepShakeFF0
    End Template
    Begin Object Class=LensFlareComponent Name=LensFlare0
        Template = LensFlare'BioVFX_Crt_Geth.Flares.Geth_Flare_FLM'
        ReplacementPrimitive = None
    End Object
    Begin Object Class=ParticleSystemComponent Name=Leak0
        Template = ParticleSystem'BioVFX_Crt_FlameThrower.Particles.Flame_Tank_Leak_Geth'
        bAutoActivate = FALSE
        ReplacementPrimitive = None
    End Object
    Begin Object Class=ParticleSystemComponent Name=Leak1
        Template = ParticleSystem'BioVFX_Crt_FlameThrower.Particles.Flame_Tank_Leak_Geth'
        bAutoActivate = FALSE
        ReplacementPrimitive = None
    End Object
    Begin Object Class=ParticleSystemComponent Name=Leak2
        Template = ParticleSystem'BioVFX_Crt_FlameThrower.Particles.Flame_Tank_Leak_Geth'
        bAutoActivate = FALSE
        ReplacementPrimitive = None
        Scale = 1.5
    End Object
    Begin Object Class=SFXLoadoutData Name=GethPyroLoadout0
        Weapons = (Class'SFXWeapon_AI_GethFlameThrower')
        ShieldLoadouts = ({
                           Shields = Class'SFXShield_Energy', 
                           ShieldLevelRange = {X = 0.0, Y = 0.0}, 
                           MaxShields = {X = 400.0, Y = 400.0}
                          }
                         )
    End Object
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
    FlameLeaks = ({SocketName = 'Socket_Leak0', PSC_Leak = Leak0, HealthPctThreshold = 0.660000026, bActive = FALSE}, 
                  {SocketName = 'Socket_Leak1', PSC_Leak = Leak1, HealthPctThreshold = 0.330000013, bActive = FALSE}, 
                  {SocketName = 'Socket_Leak3', PSC_Leak = Leak2, HealthPctThreshold = 0.100000001, bActive = FALSE}
                 )
    TankPunctureSound = WwiseEvent'Wwise_Generic_Bullet_Impacts.Play_bullet_impact_metal_sniper'
    CE_TankExplosion = RvrClientEffect'BioVFX_Crt_FlameThrower.VCFX.Gth_Flm_Gib_VCFX'
    ExplosionSound = WwiseEvent'Wwise_Weapon_Flamethrower.Play_weapon_flamethrower_tank_exp'
    LF_GethLensFlare = LensFlare0
    PowerImpactNotifications = ({Label = 'CombatRoll', TimeBeforeImpact = 0.5}
                               )
    AmbientVoc = WwiseEvent'Wwise_Crt_Geth_Pyro_SFX.Play_crt_geth_pyro_voc_amb'
    PainVoc = WwiseEvent'Wwise_Crt_Geth_Pyro_SFX.Play_crt_geth_pyro_voc_pain'
    DamageScoreBudget = 400.0
    KillBonusScore = 40.0
    PowerControlAssistBudget = 100.0
    FootstepForceFeedback = FootstepShakeFF0
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
                           Class'SFXCustomAction_GethTrooperOrbitalDrop', 
                           None, 
                           None, 
                           None, 
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
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           Class'SFXCustomAction_AILadderClimbUp', 
                           Class'SFXCustomAction_AILadderClimbDown', 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           Class'SFXCustomAction_GethEvadeLeft', 
                           Class'SFXCustomAction_GethEvadeRight', 
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
                           None, 
                           None, 
                           None, 
                           Class'SFXCustomAction_DeathReaction_HeavyLeftArm', 
                           Class'SFXCustomAction_DeathReaction_HeavyRightArm', 
                           None, 
                           None, 
                           None, 
                           Class'SFXCustomAction_DeathReaction_Knockback', 
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
    SupportedCustomReachSpecs = (Class'SFXLadderReachSpec', Class'SFXJumpReachSpec', Class'SFXJumpDownReachSpec')
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
    HeadMesh = HeadMesh0
    m_oHairMesh = HairMesh0
    m_oHeadGearMesh = GearMesh0
    LightEnvironment = BioLightEnvComponent0
    DyingSound = WwiseEvent'Wwise_Crt_Geth_Pyro_SFX.Play_crt_geth_pyro_voc_death'
    NotifyNewEnemySound = WwiseEvent'Wwise_Crt_Geth_Pyro_SFX.Play_crt_geth_pyro_voc_entrance'
    Loadout = GethPyroLoadout0
    BloodColor = {B = 24, G = 30, R = 35, A = 255}
    PowerManager = PowerMgr
    bAffectedByRagdollPowers = FALSE
    bCanPortArms = FALSE
    RaceType = ERaceType.RaceType_Machine
    CharacterType = ECharacterType.CharacterType_Geth_Pyro
    AffiliationType = EAffiliationType.AffiliationType_Geth
    ControllerClass = Class'SFXAI_GethPyro'
    EyeHeight = 80.0
    Mesh = BioPawnSkeletalMeshComponent
    CylinderComponent = CollisionCylinder
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