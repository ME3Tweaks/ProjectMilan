// MILAN CHANGE - 10/06/2026
// By Mgamerz
// Strip out Console_Melee, rename PC_Melee to Shared_Melee so this works with our reversion to Shared_Melee
Class SFXCustomAction_SyncPawnPartner_Base extends BioCustomAction
    config(Game);

const APS_SAMPLES = 4;

var float APSBuffer[4];
var BioPawn Instigator;
var SFXTimelineData APSTimeline;
var int InstigatorCustomAction;
var const float APSThreshold;
var int APSIdx;
var bool bSendReachedDestinationEvent;

public event function ReachedPrecisePosition()
{
    if (bSendReachedDestinationEvent)
    {
        if (Instigator != None && Instigator.CurrentCustomAction == InstigatorCustomAction)
        {
            if (!Instigator.CustomActionMessageEvent('PartnerReachedDestination', m_oPawn))
            {
                LogInternal(m_oPawn.WorldInfo.GameTimeSeconds @ m_oPawn @ @Class @ GetFuncName() @ "MessageEvent PartnerReachedDestination not processed by Instigator!!" @ Instigator, );
            }
        }
    }
}
public function StartCustomAction()
{
    local int idx;
    
    Super.StartCustomAction();
    if (Instigator == None)
    {
        Instigator = BioPawn(m_oPawn.SyncPawn);
        InstigatorCustomAction = 0;
    }
    APSIdx = 0;
    for (idx = 0; idx < 4; idx++)
    {
        APSBuffer[idx] = 0.0;
    }
    m_oPawn.StopMovement(FALSE);
}
public function ButtonPressed()
{
    local int NumActions;
    local int idx;
    local float StartTime;
    local bool bDone;
    
    if (m_oPawn.WorldInfo.bPlayersOnly)
    {
        return;
    }
    APSBuffer[APSIdx] = m_oPawn.WorldInfo.GameTimeSeconds;
    APSIdx++;
    if (APSIdx >= 4)
    {
        APSIdx = 0;
    }
    for (idx = 0; idx < 4; idx++)
    {
        if (APSBuffer[idx] == 0.0)
        {
            return;
        }
    }
    NumActions = 1;
    idx = APSIdx - 1;
    StartTime = m_oPawn.WorldInfo.GameTimeSeconds;
    while (bDone == FALSE && idx != APSIdx)
    {
        if (idx < 0)
        {
            idx = 4 - 1;
        }
        if (StartTime - APSBuffer[idx] <= 1.0)
        {
            NumActions++;
            idx--;
            continue;
        }
        bDone = TRUE;
    }
    if (float(NumActions) >= APSThreshold)
    {
        Instigator.CustomActionMessageEvent('MashSuccess', m_oPawn);
        ReplicateMashSuccess(Instigator);
        CloseInputWindow();
    }
}
public function bool CanBeInterrupted()
{
    return FALSE;
}
public function bool CanInteractWithPawn(BioPawn OtherPawn)
{
    return TRUE;
}
public final function CloseInputWindow()
{
    if (m_oPC != None)
    {
        BioPlayerInput(m_oPC.PlayerInput).UnregisterInputOverride("PC_Melee", TRUE);
        BioPlayerInput(m_oPC.PlayerInput).UnregisterInputOverride("Console_Melee", TRUE);
    }
}
public function InteractionStarted()
{
    InstigatorCustomAction = Instigator.CurrentCustomAction;
}
public function bool MessageEvent(Name EventName, Object Sender)
{
    if (EventName == 'InteractionStarted')
    {
        InteractionStarted();
        return TRUE;
    }
    else if (EventName == 'RequestReachedDestinationEvent')
    {
        bSendReachedDestinationEvent = TRUE;
        MoveSpeed = 600.0;
        return TRUE;
    }
    else if (EventName == 'OpenAPSWindow')
    {
        ApplyTimeline(APSTimeline);
        return TRUE;
    }
    else if (EventName == 'CloseAPSWindow')
    {
        CloseInputWindow();
        return TRUE;
    }
    return Super.MessageEvent(EventName, Sender);
}
public function ReplicateMashSuccess(BioPawn Pawn)
{
    m_oPawn.ServerMashSuccess(Pawn);
}
public function StopCustomAction()
{
    local EAICustomAction PartnerCustomAction;
    
    if (Instigator != None && Instigator.CurrentCustomAction == InstigatorCustomAction)
    {
        if (!Instigator.CustomActionMessageEvent('PartnerLeavingCustomAction', m_oPawn))
        {
            PartnerCustomAction = byte(Instigator.CurrentCustomAction);
            LogInternal(m_oPawn.WorldInfo.GameTimeSeconds @ m_oPawn @ @Class @ GetFuncName() @ "MessageEvent PartnerLeavingCustomAction not processed by Instigator!!" @ Instigator @ PartnerCustomAction, );
        }
    }
    Instigator = None;
    InstigatorCustomAction = 0;
    if (m_oPawn.SyncPawnOwner == Self)
    {
        m_oPawn.SyncPawn = None;
    }
    MoveSpeed = 0.0;
    RemoveTimeline();
    bLockRotationAfterPreciseRotation = FALSE;
    Super.StopCustomAction();
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    // MILAN CHANGE - 10/06/2026 - Mgamerz
    // Strip out Console_Melee, rename PC_Melee to Shared_Melee so this works
    Begin Object Class=SFXTimelineData Name=Timeline0
        Timeline = ({
                     TimeDilation = {
                                     Points = (), 
                                     InterpMethod = EInterpMethodType.IMT_UseFixedTangentEvalAndNewAutoTangents
                                    }, 
                     Reactions = (), 
                     AOEFunc = None, 
                     InputAlias = "Shared_Melee", 
                     InputHandle = class'SFXCustomAction_SyncPawnPartner_Base'.ButtonPressed, 
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
                     RVR_CrustTemplate = None, 
                     TimeIndex = 0.0, 
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
                     bOnPress = TRUE, 
                     bExclusive = TRUE, 
                     bBufferedInput = FALSE, 
                     bLoopCamAnim = FALSE, 
                     bCEAllowCooldown = TRUE, 
                     bCEStopAllMatching = FALSE, 
                     Type = ETimelineType.TLT_InputOn, 
                     TargetType = ETimelineTarget.TRG_Source, 
                     VocID = ESFXVocalizationEventID.SFXVocalizationEvent_None, 
                     Constraint = EBioPartGroup.BIOPARTGROUP_NONE, 
                     AOEType = ETimelineAOEType.AOE_Radius
                    }
                   )
    End Object
    APSTimeline = Timeline0
    APSThreshold = 3.0
    bBreakFromCover = TRUE
    bDisableMovement = TRUE
    bDisableLook = TRUE
    bDisableCustomActionQueuing = TRUE
    Priority = ECustomActionPriority.CA_Priority_SuperHigh
}