// Source: ME3, Patch_SFXPawn_Banshee
// Decompiled 11/17/2026 7:37:54 AM against Biod_Cat002_280Banshee.pcc
Class SFXPawn_Banshee extends SFXPawn
    placeable
    config(Game);

var transient array<NavigationPoint> RecentTeleportNavs;
var Object.Guid ShieldGUID;
var Object.Guid ChargedGUID;
var Name BlastSocketName;
var instanced StaticMeshComponent InvisShieldMesh;
var RvrClientEffectInterface CE_Shield;
var RvrClientEffectInterface CE_Charged;
var transient AnimNodeBlendList CachedReactionNode;
var WwiseEvent ChargedAmbientVoc;
var transient repnotify bool bShieldActive;
var transient repnotify bool bCharged;
var transient bool bTeleportFailed;

public simulated function PlayHit(float Damage, Controller instigatedBy, Object.Vector HitLocation, Class<DamageType> DamageType, Object.Vector Momentum, Actor.TraceHitInfo HitInfo, Pawn DamageCauser)
{
    Super.PlayHit(Damage, instigatedBy, HitLocation, DamageType, Momentum, HitInfo, DamageCauser);
    if (CachedReactionNode != None && CurrentCustomAction == 0 && HasAnyShieldResistance() == FALSE)
    {
        CachedReactionNode.SetActiveChild(Rand(3) + 1, 0.100000001);
    }
}
public static function PrecacheVFX(SFXObjectPool ObjectPool, RvrClientEffectManager ClientEffects)
{
    Super(BioPawn).PrecacheVFX(ObjectPool, ClientEffects);
    Class'SFXProjectile_BansheeBlast'.static.PrecacheVFX(ObjectPool, ClientEffects);
    ObjectPool.PrecacheProjectile(Class'SFXProjectile_BansheeBlast');
}
public simulated function ReplicatedEvent(Name VarName)
{
    Super.ReplicatedEvent(VarName);
    if (VarName == 'bShieldActive')
    {
        if (bShieldActive)
        {
            StartShield();
        }
        else
        {
            StopShield();
        }
    }
    else if (VarName == 'bCharged')
    {
        if (bCharged)
        {
            StartCharge();
        }
        else
        {
            StopCharge();
        }
    }
}
public simulated function Actor.EPowerResistance GetPowerResistance(Pawn Caster, Object.Vector HitLocation, Object.Vector HitNormal, out float Damage, out Object.Vector Force, Class<DamageType> DamageType, out Actor TargetOverride)
{
    if (bShieldActive)
    {
        return 0;
    }
    return Super.GetPowerResistance(Caster, HitLocation, HitNormal, Damage, Force, DamageType, TargetOverride);
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
public simulated function PlayDying(Class<DamageType> DamageType, Object.Vector HitLoc)
{
    Super.PlayDying(DamageType, HitLoc);
    StopCharge();
    StopShield();
}
public simulated function bool CanPlayDeathEffect()
{
    return FALSE;
}
protected function bool GetKnockbackReactions(float Angle, float SideAngle, out array<SFXCustomActionTypes.EAICustomAction> OutActions)
{
    if (bCharged)
    {
        return FALSE;
    }
    return Super(BioPawn).GetKnockbackReactions(Angle, SideAngle, OutActions);
}
protected function bool GetStaggerReactions(float Angle, float SideAngle, out array<SFXCustomActionTypes.EAICustomAction> OutActions)
{
    if (bCharged)
    {
        return FALSE;
    }
    return Super(BioPawn).GetStaggerReactions(Angle, SideAngle, OutActions);
}
protected function bool GetStandardReactions(float Angle, float SideAngle, out array<SFXCustomActionTypes.EAICustomAction> OutActions)
{
    if (bCharged)
    {
        return FALSE;
    }
    return Super(BioPawn).GetStandardReactions(Angle, SideAngle, OutActions);
}
public simulated function PlayAmbientSound()
{
    local SFXAI_Core AI;
    
    if (bCharged)
    {
        if (AmbientVoc != None && IsDead() == FALSE)
        {
            AI = SFXAI_Core(Controller);
            if (AI == None || AI.HasAnyEnemies())
            {
                PlaySound(ChargedAmbientVoc, TRUE);
            }
            SetTimer(2.0 + FRand(), FALSE, 'PlayAmbientSound', );
        }
        return;
    }
    Super.PlayAmbientSound();
}
public function PlayMeleedVoc()
{
    if (MeleedVoc != None && !bCharged)
    {
        PlaySound(MeleedVoc, TRUE);
    }
}
public simulated function StartCharge()
{
    if (Role == ENetRole.ROLE_Authority)
    {
        bCharged = TRUE;
    }
    ChargedGUID = Class'RvrClientEffectManager'.static.GetClientEffectManager().Start(CE_Charged, Self);
}
public simulated function StopCharge()
{
    if (Role == ENetRole.ROLE_Authority)
    {
        bCharged = FALSE;
    }
    Class'RvrClientEffectManager'.static.GetClientEffectManager().@Stop(CE_Charged, ChargedGUID, TRUE);
}
public simulated function AttachShieldMesh()
{
    if (Mesh != None)
    {
        AttachComponent(InvisShieldMesh);
        ShieldGUID = Class'RvrClientEffectManager'.static.GetClientEffectManager().Start(CE_Shield, Self);
    }
}
public simulated function DetachShieldMesh()
{
    if (Mesh != None)
    {
        DetachComponent(InvisShieldMesh);
        Class'RvrClientEffectManager'.static.GetClientEffectManager().@Stop(CE_Shield, ShieldGUID, TRUE);
    }
}
private final function NavigationPoint FindTeleportNav(Object.Vector SearchLoc)
{
    local NavigationPoint N;
    local NavigationPoint BestNav;
    local float Distance;
    local float BestDistance;
    local bool bOverlappingPawn;
    local SFXPawn ChkPawn;
    
    foreach WorldInfo.RadiusNavigationPoints(Class'NavigationPoint', N, SearchLoc, 800.0)
    {
        if (N != None && N != Anchor && N.IsUsableAnchorFor(Self) && RecentTeleportNavs.Find(N) == -1)
        {
            Distance = VSize(N.location - SearchLoc);
            if (BestNav == None || Distance < BestDistance)
            {
                bOverlappingPawn = FALSE;
                foreach CollidingActors(Class'SFXPawn', ChkPawn, CylinderComponent.CollisionRadius, N.location, TRUE, , )
                {
                    if (ChkPawn != None && ChkPawn != Self)
                    {
                        bOverlappingPawn = TRUE;
                    }
                }
                if (!bOverlappingPawn)
                {
                    BestDistance = Distance;
                    BestNav = N;
                }
            }
        }
    }
    return BestNav;
}
public final function FireBlast(SFXCustomAction_BansheeBlast BlastCustomAction)
{
    local Object.Vector SpawnLoc;
    local Object.Rotator SpawnRot;
    local SFXProjectile_BansheeBlast Proj;
    local SFXObjectPool Pool;
    local SFXAI_Core AI;
    
    if (Mesh != None && Mesh.GetSocketWorldLocationAndRotation(BlastSocketName, SpawnLoc, SpawnRot))
    {
        Pool = SFXGRI(WorldInfo.GRI).ObjectPool;
        if (Pool != None)
        {
            AI = SFXAI_Banshee(Controller);
            if (AI != None && AI.FireTarget != None)
            {
                Proj = Pool.GetProjectile(Class'SFXProjectile_BansheeBlast', Self, Self, SpawnLoc, SpawnRot);
                Proj.BlastCustomAction = BlastCustomAction;
                Proj.Fire(AI.FireTarget);
            }
        }
    }
}
public simulated function HideEffects()
{
    Class'RvrClientEffectManager'.static.GetClientEffectManager().HideOn(Self, TRUE);
}
public simulated function ShowEffects()
{
    Class'RvrClientEffectManager'.static.GetClientEffectManager().HideOn(Self, FALSE);
}
public final simulated function StartShield()
{
    local SFXAI_Banshee AI;
    
    if (Role == ENetRole.ROLE_Authority)
    {
        bShieldActive = TRUE;
        AI = SFXAI_Banshee(Controller);
        if (AI != None)
        {
            SetTimer(AI.ShieldDuration, FALSE, 'StopShield', );
        }
    }
    AttachShieldMesh();
}
public final simulated function StopShield()
{
    if (Role == ENetRole.ROLE_Authority)
    {
        bShieldActive = FALSE;
    }
    DetachShieldMesh();
}
public final function bool TryTeleport()
{
    local SFXAI_Banshee AI;
    local Object.Vector ToTarget;
    local Object.Vector DestLoc;
    local Object.Vector OldLoc;
    local Object.Vector X;
    local Object.Vector Y;
    local Object.Vector Z;
    local bool bIgnorePathSearch;
    local SFXPawn PawnTarget;
    local Object.Vector Start;
    local Object.Vector End;
    local Object.Vector Extent;
    local Object.Vector HitLoc;
    local Object.Vector HitNormal;
    local Object.Vector TeleportLoc;
    local NavigationPoint TeleportNav;
    
    AI = SFXAI_Banshee(Controller);
    if (AI != None)
    {
        PawnTarget = SFXPawn(AI.FireTarget);
        ToTarget = AI.FireTarget.location - location;
        ToTarget.Z = 0.0;
        ToTarget = Normal(ToTarget);
        GetAxes(Rotator(ToTarget), X, Y, Z);
        if (AI.InRange(AI.FireTarget.location, AI.EnemyDistance_Short))
        {
            if (PawnTarget != None && PawnTarget.IsInCover())
            {
                DestLoc = AI.FireTarget.location + ToTarget * 150.0;
            }
            else
            {
                DestLoc = AI.FireTarget.location - ToTarget * 150.0;
            }
            bIgnorePathSearch = TRUE;
        }
        else if (AI.CachedPath.Length > 0)
        {
            DestLoc = location;
            do {
                if (AI.CachedPath[0] != None)
                {
                    DestLoc = AI.CachedPath[0].location;
                }
                AI.CachedPath.Remove(0, 1);
            } until (AI.CachedPath.Length <= 0 || VSize(DestLoc - location) > AI.EnemyDistance_Short);
        }
        else
        {
            DestLoc = location + X * AI.EnemyDistance_Short;
        }
        Start = DestLoc;
        Start.Z += PawnTarget.CylinderComponent.CollisionHeight;
        End = DestLoc;
        End.Z -= PawnTarget.CylinderComponent.CollisionHeight * 4.0;
        Extent = GetCollisionExtent();
        Extent.Z = 1.0;
        if (Trace(HitLoc, HitNormal, End, Start, FALSE, Extent, , ) != None)
        {
            DestLoc = HitLoc;
            DestLoc.Z += CylinderComponent.CollisionHeight;
            if (FindNearestOpenLocation(DestLoc, TeleportLoc))
            {
                if (!bIgnorePathSearch)
                {
                    TeleportNav = FindTeleportNav(DestLoc);
                    if (TeleportNav == None)
                    {
                        return FALSE;
                    }
                    RecentTeleportNavs.AddItem(TeleportNav);
                    SetAnchor(TeleportNav);
                    TeleportLoc = TeleportNav.location;
                    TeleportLoc.Z += CylinderComponent.CollisionHeight - TeleportNav.CylinderComponent.CollisionHeight;
                }
                OldLoc = location;
                SetLocation(TeleportLoc, );
                if (VSize2D(OldLoc - location) < 120.0)
                {
                    bTeleportFailed = TRUE;
                }
                LockDesiredRotation(FALSE);
                SetDesiredRotation(Rotator(AI.FireTarget.location - TeleportLoc));
                SetRotation(Rotator(AI.FireTarget.location - TeleportLoc));
                AI.MoveTarget = None;
                return TRUE;
            }
        }
    }
    return FALSE;
}

replication
{
    if (bNetDirty && Role == ENetRole.ROLE_Authority)
        bShieldActive, bCharged;
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    Begin Template Class=BioDynamicLightEnvironmentComponent Name=BioLightEnvComponent0
    End Template
    Begin Template Class=CylinderComponent Name=CollisionCylinder
        CollisionHeight = 125.0
        CollisionRadius = 50.0
        ReplacementPrimitive = None
    End Template
    Begin Template Class=ForceFeedbackWaveform Name=FootstepShakeFF0
    End Template
    Begin Object Class=SFXLoadoutData Name=BansheeLoadout0
        ShieldLoadouts = ({
                           Shields = Class'SFXShield_Biotic', 
                           ShieldLevelRange = {X = 0.0, Y = 0.0}, 
                           MaxShields = {X = 2000.0, Y = 2000.0}
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
    Begin Object Class=StaticMeshComponent Name=ShieldMesh0
        StaticMesh = StaticMesh'biog_box_nkd_r.CRB.CRV.InvisShieldMesh'
        ReplacementPrimitive = None
        HiddenGame = TRUE
    End Object
    BlastSocketName = 'Socket_Blast'
    InvisShieldMesh = ShieldMesh0
    CE_Shield = RvrClientEffectMulti'BioVFX_Crt_Rpr_Banshee.VCFX.Rpr_Banshee_StasisField_M_VCFX'
    CE_Charged = RvrClientEffect'BioVFX_Crt_Rpr_Banshee.VCFX.Rpr_Banshee_Charged_VCFX'
    ChargedAmbientVoc = WwiseEvent'Wwise_Crt_Reap_Banshee_SFX.Play_crt_reap_banshee_voc_ambient_chargedup'
    PowerImpactNotifications = ({Label = 'BioticShield', TimeBeforeImpact = 0.200000003}
                               )
    HeadshotMultiplier = 0.400000006
    AmbientVoc = WwiseEvent'Wwise_Crt_Reap_Banshee_SFX.Play_crt_reap_banshee_voc_ambient'
    PainVoc = WwiseEvent'Wwise_Crt_Reap_Banshee_SFX.Play_crt_reap_banshee_voc_pain'
    ShieldsDownVoc = WwiseEvent'Wwise_Crt_Reap_Banshee_SFX.Play_crt_reap_banshee_voc_charge_knockback'
    MeleedVoc = WwiseEvent'Wwise_Crt_Reap_Banshee_SFX.Play_crt_reap_banshee_voc_pain'
    CodexPlotState = 20829
    DamageScoreBudget = 1000.0
    KillBonusScore = 100.0
    PowerControlAssistBudget = 250.0
    FootstepForceFeedback = FootstepShakeFF0
    bAllowHeadGib = FALSE
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
                           Class'SFXCustomAction_BansheeMantle', 
                           None, 
                           Class'SFXCustomAction_BansheeClimbUp', 
                           Class'SFXCustomAction_BansheeClimbDown', 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           Class'SFXCustomAction_BansheeDropDown', 
                           Class'SFXCustomAction_BansheeBoostUp', 
                           None, 
                           None, 
                           None, 
                           Class'SFXCustomAction_BansheeLeap', 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           Class'SFXCustomAction_BansheeStagger', 
                           Class'SFXCustomAction_BansheeStandard', 
                           Class'SFXCustomAction_BansheeStandardForward', 
                           Class'SFXCustomAction_BansheeStandardLeft', 
                           Class'SFXCustomAction_BansheeStandardRight', 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           Class'SFXCustomAction_BansheeDeath', 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           Class'SFXCustomAction_BansheeMelee', 
                           None, 
                           Class'SFXCustomAction_BansheeSyncMelee', 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           Class'SFXCustomAction_BansheeRoar', 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           Class'SFXCustomAction_BansheeBlast', 
                           Class'SFXCustomAction_BansheeAOEBlast', 
                           Class'SFXCustomAction_BansheeShield', 
                           Class'SFXCustomAction_BansheePhase', 
                           Class'SFXCustomAction_BansheeBreach', 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           None, 
                           Class'SFXCustomAction_IdleBanshee'
                          )
    SupportedCustomReachSpecs = (Class'SFXLargeMantleReachSpec', Class'SFXLargeClimbReachSpec', Class'SFXLeapReachSpecLarge', Class'SFXLargeBoostReachSpec')
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
                      BoneNames = ('LeftAnkle', 'LeftKnee', 'LeftHip'), 
                      BodyPart = 'LeftLeg'
                     }, 
                     {
                      BoneNames = ('RightAnkle', 'RightKnee', 'RightHip'), 
                      BodyPart = 'RightLeg'
                     }, 
                     {
                      BoneNames = ('LeftWrist', 'LeftElbow', 'LeftShoulder'), 
                      BodyPart = 'LeftArm'
                     }, 
                     {
                      BoneNames = ('RightWrist', 'RightElbow', 'RightShoulder'), 
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
    DeathCustomAction = 120
    HeadMesh = HeadMesh0
    m_oHairMesh = HairMesh0
    m_oHeadGearMesh = GearMesh0
    LightEnvironment = BioLightEnvComponent0
    DyingSound = WwiseEvent'Wwise_Crt_Reap_Banshee_SFX.Play_crt_reap_banshee_voc_death'
    NotifyNewEnemySound = WwiseEvent'Wwise_Crt_Reap_Banshee_SFX.Play_crt_reap_banshee_voc_entrance'
    Loadout = BansheeLoadout0
    BloodColor = {B = 2, G = 2, R = 5, A = 255}
    PowerManager = PowerMgr
    bSpawnPHATInstance = FALSE
    bCanRagdoll = FALSE
    bUseLargeReactions = TRUE
    m_bHideWithCameraCollision = FALSE
    bCanPortArms = FALSE
    CharacterType = ECharacterType.CharacterType_Reaper_Banshee
    AffiliationType = EAffiliationType.AffiliationType_Reaper
    ControllerClass = Class'SFXAI_Banshee'
    SightRadius = 4500.0
    BaseEyeHeight = 100.0
    EyeHeight = 100.0
    Mesh = BioPawnSkeletalMeshComponent
    CylinderComponent = CollisionCylinder
    bCanCrouch = FALSE
    bCanStrafe = FALSE
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
               TimelineMod0
              )
    CollisionComponent = CollisionCylinder
}