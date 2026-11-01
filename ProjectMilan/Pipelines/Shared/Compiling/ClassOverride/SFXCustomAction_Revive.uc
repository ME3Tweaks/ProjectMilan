// Source: LE3, BioP_Char
// Decompiled 10/27/2026 3:22:16 PM
// MILAN CHANGE
// Force animation to start at beginning so timer can't be reused which causes
// the player to stand mid action
Class SFXCustomAction_Revive extends SFXCustomAction_SingleAnim
    config(Game);

var SFXPawn_PlayerParty DownedPlayer;
var bool bSuccessRevive;

public function Resurrect()
{
    local BioRemoteLogger GLogger;
    local SFXAccomplishmentManager AccManager;
    
    if (m_oPawn != None)
    {
        m_oPawn.BreakStealth();
    }
    if (m_oPawn != None && DownedPlayer != None && !m_oPawn.IsDead() && DownedPlayer.IsInState('Downed', ) && m_oPawn.Role == ENetRole.ROLE_Authority)
    {
        if (SFXGRI(m_oPawn.WorldInfo.GRI).bMultiplayer)
        {
            GLogger = Class'BioRemoteLogger'.static.GetLogger();
            if (GLogger != None)
            {
                GLogger.SendMPEvent(6, DownedPlayer.location.X, DownedPlayer.location.Y, DownedPlayer.location.Z, string(DownedPlayer.Name), string(m_oPawn.Name), 0, 0);
            }
            SFXGRI(m_oPawn.WorldInfo.GRI).GetScoreManager().IncrementMedalStanding(SFXPawn_Player(m_oPawn), 13);
        }
        if (DownedPlayer.Controller != None)
        {
            BioPlayerController(m_oPawn.Controller).Revive(DownedPlayer);
        }
    }
    if (m_oPawn.IsLocallyControlled())
    {
        AccManager = SFXEngine(Class'Engine'.static.GetEngine()).AccomplishmentManager;
        if (AccManager != None)
        {
            AccManager.UpdateMiscChallenges(9, BioPlayerController(m_oPawn.Controller));
        }
    }
    bSuccessRevive = TRUE;
    DownedPlayer.Reviver = SFXPawn(m_oPawn);
    DownedPlayer.SetTimer(0.200000003, FALSE, 'PlayerRevivedMessage', );
    EndThisCustomAction();
}
public function StartCustomAction()
{
    Super.StartCustomAction();
    // MILAN CHANGE - Restart the stance instead of resuming a stale one
    if (m_oPawn.IsPlayingBodyStance(BS_Anim))
    {
        m_oPawn.BS_SetPosition(BS_Anim, fAnimStartTime);
        m_oPawn.BS_SetPlayRate(BS_Anim, fAnimPlayRate);
    }
    // END MILAN CHANGE
    bSuccessRevive = FALSE;
    DownedPlayer = SFXPawn_PlayerParty(m_oPawn.SyncPawn);
    if (DownedPlayer == None)
    {
        InterruptThisCustomAction();
        return;
    }
    if (m_oPawn.Role == ENetRole.ROLE_Authority)
    {
        SFXPawn_PlayerParty(m_oPawn.SyncPawn).bBeingRevived = TRUE;
        m_oPawn.SetTimer(0.5, TRUE, 'CheckMoving', Self);
        m_oPawn.SetTimer(0.5, TRUE, 'CheckFiring', Self);
    }
    DownedPlayer.EnableUsage(FALSE);
    DownedPlayer.PauseTimer(TRUE, 'PermaDeath');
    m_oPawn.SetTimer(SFXPawn_PlayerParty(m_oPawn).fTimeToRevive, FALSE, 'Resurrect', Self);
    if (m_oPC != None && m_oPC.IsLocalPlayerController())
    {
        m_oPC.HintSystem.HintEvent('StartRevive');
    }
    SFXPawn_PlayerParty(m_oPawn).UpdateReviveHud(TRUE, TRUE);
    DownedPlayer.UpdateReviveHud(TRUE, FALSE);
    if (SFXGRI(m_oPawn.WorldInfo.GRI).bMultiplayer)
    {
        SFXGRI(m_oPawn.WorldInfo.GRI).TriggerVocalizationEvent(116, m_oPawn);
    }
}
public function TickCustomAction(float DeltaTime)
{
    Super(BioCustomAction).TickCustomAction(DeltaTime);
    if (DownedPlayer.bIsDead)
    {
        EndThisCustomAction();
    }
}
public function BodyStanceAnimEndNotification(AnimNodeSequence SeqNode, float PlayedTime, float ExcessTime);

public function CheckFiring()
{
    if (m_oPawn.IsFiring())
    {
        m_oPawn.ClearTimer('CheckFiring', Self);
        InterruptThisCustomAction();
    }
}
public function ClientDoCustomAction(optional bool bForced)
{
    if (m_oPawn != None)
    {
        m_oPawn.SyncPawn = BioPawn(m_oPawn.ReplicatedCustomActionInfo.Target);
        Super(BioCustomAction).ClientDoCustomAction(bForced);
    }
}
protected function bool InternalCanDoCustomAction(BioPawn SyncPawn, bool bForced)
{
    if (SFXPawn_PlayerParty(SyncPawn) == None)
    {
        return FALSE;
    }
    if (m_oPawn != None && (m_oPawn.IsInState('InRagdoll', ) || m_oPawn.IsInState('RagdollRecovery', )))
    {
        return FALSE;
    }
    if (!m_oPawn.IsInState('Downed', ) && SyncPawn.IsInState('Downed', ) && !SFXPawn_PlayerParty(SyncPawn).bBeingRevived)
    {
        return TRUE;
    }
    return Super(BioCustomAction).InternalCanDoCustomAction(SyncPawn, bForced);
}
public function Replicate()
{
    Super(BioCustomAction).Replicate();
    if (m_oPawn != None)
    {
        m_oPawn.ReplicatedCustomActionInfo.Target = m_oPawn.SyncPawn;
    }
}
public function StopCustomAction()
{
    Super.StopCustomAction();
    m_oPawn.ClearTimer('CheckMoving', Self);
    m_oPawn.ClearTimer('CheckFiring', Self);
    m_oPawn.ClearTimer('Resurrect', Self);
    SFXPawn_PlayerParty(m_oPawn).UpdateReviveHud(FALSE, TRUE);
    DownedPlayer.UpdateReviveHud(FALSE, FALSE);
    if (m_oPawn != None && DownedPlayer != None)
    {
        DownedPlayer.bBeingRevived = FALSE;
    }
    if (!bSuccessRevive && m_oPawn != None && DownedPlayer != None && !DownedPlayer.bIsDead)
    {
        DownedPlayer.PauseTimer(FALSE, 'PermaDeath');
        DownedPlayer.EnableUsage(TRUE);
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
                     PSC_Instance = None, 
                     RBC_BlurInstance = None, 
                     PS_Template = None, 
                     SocketName = 'None', 
                     Sound = None, 
                     PlayerSound = None, 
                     Rumble = None, 
                     ScreenShakeObject = None, 
                     AOEImpactTimeline = None, 
                     SyncPartnerImpactTimeline = None, 
                     TimelineTemplate = None, 
                     Func = 'None', 
                     BlurMaterial = None, 
                     CamAnim = None, 
                     RVR_CrustTemplate = RvrClientEffectMulti'BioVFX_T_TechPowers._OmniTool.VCFX.OmniTool_RightFull_VCFX_M', 
                     TimeIndex = 0.00999999978, 
                     TimeRemaining = 0.0, 
                     CrustDuration = 5.0, 
                     TimeDilationLength = 1.0, 
                     RagdollForce = 100.0, 
                     Damage = 1.0, 
                     AOERadius = 500.0, 
                     AOEConeAngle = 0.0, 
                     nMatchedInputIndex = 0, 
                     BlurScale = 1.0, 
                     BlurFalloffExponent = 1.5, 
                     BlurOpacity = 1.0, 
                     CamStartTime = 0.0, 
                     CamBlendInTime = 0.200000003, 
                     CamBlendOutTime = 0.200000003, 
                     CamPlayRate = 1.0, 
                     CamDuration = 0.0, 
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
                     Type = ETimelineType.TLT_ClientEffect, 
                     TargetType = ETimelineTarget.TRG_Source, 
                     VocID = ESFXVocalizationEventID.SFXVocalizationEvent_None, 
                     Constraint = EBioPartGroup.BIOPARTGROUP_NONE, 
                     AOEType = ETimelineAOEType.AOE_Radius
                    }, 
                    {
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
                     PSC_Instance = None, 
                     RBC_BlurInstance = None, 
                     PS_Template = None, 
                     SocketName = 'None', 
                     Sound = WwiseEvent'Wwise_GUI_MultiPlayer_Specific.Play_MPPlayerRevived', 
                     PlayerSound = WwiseEvent'Wwise_GUI_MultiPlayer_Specific.Play_MPPlayerRevived', 
                     Rumble = None, 
                     ScreenShakeObject = None, 
                     AOEImpactTimeline = None, 
                     SyncPartnerImpactTimeline = None, 
                     TimelineTemplate = None, 
                     Func = 'None', 
                     BlurMaterial = None, 
                     CamAnim = None, 
                     RVR_CrustTemplate = None, 
                     TimeIndex = 0.00999999978, 
                     TimeRemaining = 0.0, 
                     CrustDuration = 1.0, 
                     TimeDilationLength = 1.0, 
                     RagdollForce = 100.0, 
                     Damage = 1.0, 
                     AOERadius = 500.0, 
                     AOEConeAngle = 0.0, 
                     nMatchedInputIndex = 0, 
                     BlurScale = 1.0, 
                     BlurFalloffExponent = 1.5, 
                     BlurOpacity = 1.0, 
                     CamStartTime = 0.0, 
                     CamBlendInTime = 0.200000003, 
                     CamBlendOutTime = 0.200000003, 
                     CamPlayRate = 1.0, 
                     CamDuration = 0.0, 
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
                     Type = ETimelineType.TLT_Sound, 
                     TargetType = ETimelineTarget.TRG_Source, 
                     VocID = ESFXVocalizationEventID.SFXVocalizationEvent_None, 
                     Constraint = EBioPartGroup.BIOPARTGROUP_NONE, 
                     AOEType = ETimelineAOEType.AOE_Radius
                    }, 
                    {
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
                     PSC_Instance = None, 
                     RBC_BlurInstance = None, 
                     PS_Template = None, 
                     SocketName = 'None', 
                     Sound = WwiseEvent'Wwise_Generic_GUI.Play_MediGel_Use', 
                     PlayerSound = WwiseEvent'Wwise_Generic_GUI.Play_MediGel_Use', 
                     Rumble = None, 
                     ScreenShakeObject = None, 
                     AOEImpactTimeline = None, 
                     SyncPartnerImpactTimeline = None, 
                     TimelineTemplate = None, 
                     Func = 'None', 
                     BlurMaterial = None, 
                     CamAnim = None, 
                     RVR_CrustTemplate = None, 
                     TimeIndex = 0.5, 
                     TimeRemaining = 0.0, 
                     CrustDuration = 1.0, 
                     TimeDilationLength = 1.0, 
                     RagdollForce = 100.0, 
                     Damage = 1.0, 
                     AOERadius = 500.0, 
                     AOEConeAngle = 0.0, 
                     nMatchedInputIndex = 0, 
                     BlurScale = 1.0, 
                     BlurFalloffExponent = 1.5, 
                     BlurOpacity = 1.0, 
                     CamStartTime = 0.0, 
                     CamBlendInTime = 0.200000003, 
                     CamBlendOutTime = 0.200000003, 
                     CamPlayRate = 1.0, 
                     CamDuration = 0.0, 
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
                     Type = ETimelineType.TLT_Sound, 
                     TargetType = ETimelineTarget.TRG_Source, 
                     VocID = ESFXVocalizationEventID.SFXVocalizationEvent_None, 
                     Constraint = EBioPartGroup.BIOPARTGROUP_NONE, 
                     AOEType = ETimelineAOEType.AOE_Radius
                    }
                   )
    End Object
    BS_Anim = {
               AnimName = ('CB_MP_Revive')
              }
    fAnimBlendInTime = 0.400000006
    fAnimBlendOutTime = 0.400000006
    ERootMotionMode = ERootMotionMode.RMM_Translate
    OverrideList = (Class'SFXCustomAction_Ragdoll', Class'SFXCustomAction_AnimatedRagdoll', Class'SFXCustomAction_Frozen', Class'SFXCustomAction_ClassMelee')
    TimelineTemplate = Timeline0
    bDisableMovement = FALSE
    bAllowChargeHolding = TRUE
    bReplicateCustomAction = TRUE
}