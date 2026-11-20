// Source: ME3, Patch_SFXCustomAction_BansheePhase
// Decompiled 11/17/2026 7:37:41 AM against Biod_Cat002_280Banshee.pcc
Class SFXCustomAction_BansheePhase extends SFXCustomAction_SingleAnim
    config(Game);

var transient Object.Vector ClientTeleportLocation;
var transient bool bTeleported;

public static function PrecacheVFX(SFXObjectPool ObjectPool, RvrClientEffectManager ClientEffects)
{
    Super(BioCustomAction).PrecacheVFX(ObjectPool, ClientEffects);
    Class'SFXProjectile_BansheePhase'.static.PrecacheVFX(ObjectPool, ClientEffects);
    ObjectPool.PrecacheProjectile(Class'SFXProjectile_BansheePhase');
}
public function Teleport()
{
    local SFXPawn_Banshee Banshee;
    local Object.Vector OldLocation;
    local Object.Vector ToTarget;
    local SFXObjectPool Pool;
    local SFXProjectile_BansheePhase Prj;
    local float TravelTime;
    
    Banshee = SFXPawn_Banshee(m_oPawn);
    if (Banshee != None)
    {
        OldLocation = m_oPawn.location;
        if (Banshee.Role == ENetRole.ROLE_Authority)
        {
            bTeleported = Banshee.TryTeleport();
        }
        else
        {
            Banshee.SetLocation(ClientTeleportLocation, );
            bTeleported = TRUE;
        }
        if (bTeleported)
        {
            ToTarget = Normal(m_oPawn.location - OldLocation);
            Banshee.SetHidden(TRUE);
            Banshee.HideEffects();
            TravelTime = FMax(0.100000001, VSize(m_oPawn.location - OldLocation) / Class'SFXProjectile_BansheePhase'.default.MaxSpeed);
            m_oPawn.SetTimer(TravelTime, FALSE, 'FinishTeleport', Self);
            Pool = SFXGRI(m_oPawn.WorldInfo.GRI).ObjectPool;
            if (Pool != None)
            {
                Prj = Pool.GetProjectile(Class'SFXProjectile_BansheePhase', m_oPawn, m_oPawn, OldLocation, Rotator(ToTarget));
                if (Prj != None)
                {
                    Prj.fFuseLength = TravelTime;
                    Prj.Init(ToTarget);
                }
            }
            if (ShouldReplicate())
            {
                ReplicateImpact(m_oPawn, -1, , m_oPawn.location);
            }
        }
        else
        {
            InterruptThisCustomAction();
            if (m_oAI != None)
            {
                m_oAI.bReachedMoveGoal = FALSE;
            }
        }
    }
}
public function BodyStanceAnimEndNotification(AnimNodeSequence SeqNode, float PlayedTime, float ExcessTime);

public function ClientDoCustomActionImpact(Actor oActor, int ImpactCount, optional bool bFirstTarget, optional Object.Vector HitLocation, optional Object.Vector HitNormal, optional int CustomActionReactionType)
{
    local SFXPawn_Banshee Banshee;
    
    switch (ImpactCount)
    {
        case -1:
            Banshee = SFXPawn_Banshee(m_oPawn);
            if (bTeleported == FALSE && Banshee != None && Banshee.CurrentCustomAction == 172)
            {
                ClientTeleportLocation = HitLocation;
                Teleport();
            }
            break;
        default:
            Super(BioCustomAction).ClientDoCustomActionImpact(oActor, ImpactCount, bFirstTarget, HitLocation, HitNormal, CustomActionReactionType);
            break;
    }
}
public function StopCustomAction()
{
    Super.StopCustomAction();
    if (bTeleported)
    {
        m_oPawn.ClearTimer('FinishTeleport', Self);
        m_oPawn.SetHidden(FALSE);
        SFXPawn_Banshee(m_oPawn).ShowEffects();
    }
    bTeleported = FALSE;
}
public function FinishTeleport()
{
    EndThisCustomAction();
}
public function ServerTeleport()
{
    if (m_oPawn != None && m_oPawn.Role == ENetRole.ROLE_Authority)
    {
        Teleport();
    }
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    Begin Object Class=SFXTimelineData Name=Timeline0
        Timeline = ({
                     TimeDilation = {
                                     Points = (), 
                                     InterpMethod = EInterpMethodType.IMT_UseFixedTangentEvalAndNewAutoTangents
                                    }, 
                     Reactions = (), 
                     AOEFunc = None, 
                     InputAlias = "", 
                     InputHandle = None, 
                     RumbleClass = None, 
                     ScreenShakeClass = None, 
                     DamageType = None, 
                     AOEFilterClass = Class'Actor', 
                     GameEffectClass = None, 
                     ScreenShake = {
                                    RotAmplitude = {X = 100.0, Y = 100.0, Z = 200.0}, 
                                    RotFrequency = {X = 10.0, Y = 10.0, Z = 25.0}, 
                                    RotSinOffset = {X = 0.0, Y = 0.0, Z = 0.0}, 
                                    LocAmplitude = {X = 0.0, Y = 3.0, Z = 5.0}, 
                                    LocFrequency = {X = 1.0, Y = 10.0, Z = 20.0}, 
                                    LocSinOffset = {X = 0.0, Y = 0.0, Z = 0.0}, 
                                    ShakeName = 'None', 
                                    TimeToGo = 0.0, 
                                    TimeDuration = 1.0, 
                                    RotParam = {X = EShakeParam.ESP_OffsetRandom, Y = EShakeParam.ESP_OffsetRandom, Z = EShakeParam.ESP_OffsetRandom}, 
                                    LocParam = {X = EShakeParam.ESP_OffsetRandom, Y = EShakeParam.ESP_OffsetRandom, Z = EShakeParam.ESP_OffsetRandom}, 
                                    FOVAmplitude = 2.0, 
                                    FOVFrequency = 5.0, 
                                    FOVSinOffset = 0.0, 
                                    TargetingDampening = 0.0, 
                                    bOverrideTargetingDampening = FALSE, 
                                    FOVParam = EShakeParam.ESP_OffsetRandom
                                   }, 
                     ClientEffectID = {A = 0, B = 0, C = 0, D = 0}, 
                     PS_Rotation = {Pitch = 0, Yaw = 0, Roll = 0}, 
                     SocketName = 'None', 
                     Func = 'ServerTeleport', 
                     TimeIndex = 0.649999976, 
                     TimeRemaining = 0.0, 
                     PSC_Instance = None, 
                     RBC_BlurInstance = None, 
                     PS_Template = None, 
                     CrustDuration = 1.0, 
                     Sound = None, 
                     PlayerSound = None, 
                     Rumble = None, 
                     ScreenShakeObject = None, 
                     TimeDilationLength = 1.0, 
                     RagdollForce = 100.0, 
                     Damage = 1.0, 
                     AOERadius = 500.0, 
                     AOEConeAngle = 0.0, 
                     AOEImpactTimeline = None, 
                     SyncPartnerImpactTimeline = None, 
                     TimelineTemplate = None, 
                     nMatchedInputIndex = 0, 
                     BlurMaterial = None, 
                     BlurScale = 1.0, 
                     BlurFalloffExponent = 1.5, 
                     BlurOpacity = 1.0, 
                     CamAnim = None, 
                     CamStartTime = 0.0, 
                     CamBlendInTime = 0.200000003, 
                     CamBlendOutTime = 0.200000003, 
                     CamPlayRate = 1.0, 
                     CamDuration = 0.0, 
                     RVR_CrustTemplate = None, 
                     CEStartIndex = 0, 
                     GameEffectDuration = 0.0, 
                     GameEffectValue = 0.0, 
                     bActivated = FALSE, 
                     bActiveInput = FALSE, 
                     bReceivedInput = FALSE, 
                     bUseWeaponMesh = FALSE, 
                     bApplyBloodColorParam = FALSE, 
                     bDilateSound = TRUE, 
                     bAOEAffectsTarget = FALSE, 
                     bOnPress = FALSE, 
                     bExclusive = TRUE, 
                     bBufferedInput = FALSE, 
                     bLoopCamAnim = FALSE, 
                     bCEAllowCooldown = TRUE, 
                     bCEStopAllMatching = FALSE, 
                     Type = ETimelineType.TLT_Function, 
                     TargetType = ETimelineTarget.TRG_Source, 
                     VocID = ESFXVocalizationEventID.SFXVocalizationEvent_None, 
                     Constraint = EBioPartGroup.BIOPARTGROUP_NONE, 
                     AOEType = ETimelineAOEType.AOE_Radius
                    }
                   )
        Lifetime = 3.0
    End Object
    BS_Anim = {
               AnimName = ('CB_GlitchOut')
              }
    TimelineTemplate = Timeline0
    bDisableShooting = FALSE
    bLockRotationAfterPreciseRotation = TRUE
    bReplicateCustomAction = TRUE
    bForceLocalSimulation = TRUE
    Priority = ECustomActionPriority.CA_Priority_High
}