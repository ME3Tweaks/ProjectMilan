Class SFXPawn_AdjutantMP extends SFXPawn
    placeable
    config(Game);

var Guid EyeGlowGuid;
var transient AnimNodeBlendList CachedReactionNode;
var const RvrClientEffectInterface CE_EyeGlow;
var bool bEyeGlowOn;

public simulated function Destroyed()
{
    TurnOffEyes();
    Super(BioPawn).Destroyed();
}
public simulated function PlayHit(float Damage, Controller instigatedBy, Vector HitLocation, Class<DamageType> DamageType, Vector Momentum, TraceHitInfo HitInfo, Pawn DamageCauser)
{
    Super.PlayHit(Damage, instigatedBy, HitLocation, DamageType, Momentum, HitInfo, DamageCauser);
    if (CachedReactionNode != None && CurrentCustomAction == 0 && HasAnyShieldResistance() == FALSE)
    {
        CachedReactionNode.SetActiveChild(Rand(3) + 1, 0.100000001);
    }
}
public simulated function PostBeginPlay()
{
    Super.PostBeginPlay();
    SetTimer(0.200000003, FALSE, 'TurnOnEyes', );
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
public simulated function bool HasDeathReaction()
{
    return DeathCustomAction != 0 && (!IsPerformingCustomAction() || CurrentCustomAction == 111 || CurrentCustomAction == 112 || CurrentCustomAction == 113 || CurrentCustomAction == 114 || CurrentCustomAction == 110);
}
public simulated function PlayDeathEffect(Class<SFXDamageType> SFXDamageType, optional Controller Killer)
{
    bCanRagdoll = TRUE;
    TurnOffEyes(TRUE);
    Super(BioPawn).PlayDeathEffect(SFXDamageType, Killer);
}
public function ApplyPoisonEffects(BioPawn HitPawn, Actor PoisonSource)
{
    local bool bInitNewEffect;
    local SFXModule_GameEffectManager Manager;
    local SFXGameEffect_AdjutantBlast Effect;
    
    if (HitPawn != None && IsHostile(HitPawn) && SFXPawn_Henchman(HitPawn) == None)
    {
        Manager = HitPawn.GetModule(Class'SFXModule_GameEffectManager');
        if (Manager != None)
        {
            Effect = SFXGameEffect_AdjutantBlast(Manager.GetFirstEffectOfType(Class'SFXGameEffect_AdjutantBlast'));
            if (Effect == None)
            {
                Effect = SFXGameEffect_AdjutantBlast(Manager.CreateEffect(Class'SFXGameEffect_AdjutantBlast', Name, 0.00999999978, 2, SFXAI_AdjutantMP(Controller).PoisonDPS, Controller, Self));
                Effect.PoisonRadius = SFXAI_AdjutantMP(Controller).PoisonRadius;
                bInitNewEffect = TRUE;
            }
            Effect.PoisonSources.AddItem(PoisonSource);
            if (bInitNewEffect)
            {
                Effect.OnApplied();
            }
        }
    }
}
public function ExplodeBlast(SFXProjectile_AdjutantMPBlast BlastProj, Vector HitNormal)
{
    local SFXAdjutantMPPoisonVolume Poison;
    
    Poison = Spawn(Class'SFXAdjutantMPPoisonVolume', Self, , BlastProj.GetEffectLocation(HitNormal), Rotator(vect(0.0, 1.0, 0.0)));
    Poison.Init();
}
public final function FireBlast()
{
    local Vector SpawnLoc;
    local Rotator SpawnRot;
    local SFXProjectile_AdjutantMPBlast Proj;
    local SFXObjectPool Pool;
    local SFXAI_AdjutantMP AI;
    
    AI = SFXAI_AdjutantMP(Controller);
    if (AI != None && AI.FireTarget != None)
    {
        if (Mesh != None && Mesh.GetSocketWorldLocationAndRotation(MuzzleSocketName, SpawnLoc, SpawnRot))
        {
            Pool = SFXGRI(WorldInfo.GRI).ObjectPool;
            if (Pool != None)
            {
                Proj = Pool.GetProjectile(Class'SFXProjectile_AdjutantMPBlast', Self, Self, SpawnLoc, SpawnRot);
                Proj.OwnerPawn = Self;
                Proj.Damage = AI.BlastDamage;
                Proj.Fire(AI.FireTarget);
            }
        }
    }
}
public function OnPopAdjutantSac(SFXSeqAct_PopAdjutantSac SeqAct)
{
    local SFXModule_Armour ArmorMan;
    local SFXArmourPiece ArmorPiece;
    local int ArmorIdx;
    
    if (SeqAct.InputLinks[0].bHasImpulse)
    {
        ArmorMan = GetModule(Class'SFXModule_Armour');
        if (ArmorMan != None)
        {
            ArmorIdx = SeqAct.SacIdx;
            if (ArmorIdx >= 0 && ArmorIdx < 12)
            {
                ArmorPiece = ArmorMan.ActiveArmour[ArmorIdx];
            }
            if (ArmorPiece != None)
            {
                ArmorPiece.CurrentHealth = 1.0;
                ArmorMan.ApplyDamageToPiece(ArmorIdx, 1.0, Controller);
            }
            else
            {
                LogInternal("Could not find armor piece" @ SeqAct.SacIdx, );
            }
        }
        else
        {
            LogInternal("Armor module missing. Ignoring.", );
        }
    }
}
public simulated function TurnOffEyes(optional bool Cooldown)
{
    if (bEyeGlowOn)
    {
        Class'RvrClientEffectManager'.static.GetClientEffectManager().Stop(CE_EyeGlow, EyeGlowGuid, Cooldown);
    }
}
public simulated function TurnOnEyes()
{
    local RvrClientEffectTarget CETarget;
    
    if (!bEyeGlowOn)
    {
        CETarget.HitActor = Self;
        CETarget.Instigator = Self;
        EyeGlowGuid = Class'RvrClientEffectManager'.static.GetClientEffectManager().StartOnTarget(CE_EyeGlow, CETarget, Self);
        bEyeGlowOn = TRUE;
    }
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    Begin Template Class=CylinderComponent Name=CollisionCylinder
        CollisionHeight = 100.0
        CollisionRadius = 70.0
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
    Begin Template Class=ForceFeedbackWaveform Name=FootstepShakeFF0
    End Template
    Begin Template Class=SFXModule_GameEffectManager Name=GEMod0
    End Template
    Begin Template Class=SFXModule_Radar Name=RadarModule
    End Template
    Begin Template Class=SFXModule_AimAssistTarget Name=AimAssistMod
    End Template
    Begin Template Class=SFXModule_Damage Name=DmgMod0
        HealthType = EHealthType.HealthType_Armour
    End Template
    Begin Template Class=SFXModule_Gestures Name=GestMod01
        Begin Template Class=BioGestureAnimSetMgr Name=oAnimSetMgr_14
        End Template
        m_pAnimSetMgr = oAnimSetMgr_14
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
    Begin Object Class=SFXLoadoutData Name=AdjutantLoadout0
        ShieldLoadouts = ({
                           Shields = Class'SFXShield_Biotic', 
                           ShieldLevelRange = {X = 0.0, Y = 0.0}, 
                           MaxShields = {X = 2000.0, Y = 2000.0}
                          }
                         )
    End Object
    Begin Template Class=SFXPowerManager Name=PowerMgr
    End Template
    CE_EyeGlow = RvrClientEffect'BioVFX_Exp2_Adj.VCFX.LifetimeCrust_VCFX'
    PowerImpactNotifications = ({Label = 'Evade', TimeBeforeImpact = 0.5}
                               )
    PainVoc = WwiseEvent'Wwise_Crt_DLC_Omega_Adjutant.Play_crt_omega_adjutant_voc_pain'
    MeleedVoc = WwiseEvent'Wwise_Crt_DLC_Omega_Adjutant.Play_crt_omega_adjutant_voc_pain'
    MuzzleSocketName = 'Socket_GunTip'
    FootstepForceFeedback = FootstepShakeFF0
    HeadshotMultiplier = 0.400000006
    bAllowHeadGib = FALSE
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
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           Class'SFXCustomAction_AdjutantEvadeLeft', 
                           Class'SFXCustomAction_AdjutantEvadeRight', 
                           Class'SFXCustomAction_AdjutantEvadeForward', 
                           Class'SFXCustomAction_AdjutantEvadeBack', 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           Class'SFXCustomAction_CannibalStagger', 
                           Class'SFXCustomAction_CannibalStandard', 
                           Class'SFXCustomAction_CannibalStandardForward', 
                           Class'SFXCustomAction_CannibalStandardLeft', 
                           Class'SFXCustomAction_CannibalStandardRight', 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           Class'SFXCustomAction_AdjutantDeath', 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           Class'SFXCustomAction_AdjutantMelee', 
                           Class'SFXCustomAction_AdjutantMelee2', 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           Class'SFXCustomAction_AdjutantMPBlast', 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           Class'SFXCustomAction_AdjutantMPChargeShort', 
                           Class'SFXCustomAction_AdjutantMPChargeMedium', 
                           Class'SFXCustomAction_AdjutantMPCharge'
                          )
    SupportedSyncActions = ('AtlasSync', 'PhantomSync', 'KaiLengSync', 'BruteSync', 'BansheeSync')
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
                      BoneNames = ('Neck', 'Head'), 
                      BodyPart = 'Head'
                     }
                    )
    RightHandSocketName = 'Socket_GunTip'
    HeadMesh = HeadMesh0
    m_oHairMesh = HairMesh0
    m_oHeadGearMesh = GearMesh0
    LightEnvironment = BioLightEnvComponent0
    DyingSound = WwiseEvent'Wwise_Crt_DLC_Omega_Adjutant.Play_crt_omega_adjutant_voc_death'
    NotifyNewEnemySound = WwiseEvent'Wwise_Crt_DLC_Omega_Adjutant.Play_crt_omega_adjutant_voc_enter'
    Loadout = AdjutantLoadout0
    PowerManager = PowerMgr
    DeathCustomAction = 120
    BloodColor = {B = 2, G = 2, R = 5, A = 255}
    bCanRagdoll = FALSE
    bAffectedByRagdollPowers = FALSE
    bUseLargeReactions = TRUE
    bCanPortArms = FALSE
    AffiliationType = EAffiliationType.AffiliationType_Cerberus
    ControllerClass = Class'SFXAI_Adjutant'
    Mesh = BioPawnSkeletalMeshComponent
    CylinderComponent = CollisionCylinder
    BaseEyeHeight = 45.0
    EyeHeight = 45.0
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