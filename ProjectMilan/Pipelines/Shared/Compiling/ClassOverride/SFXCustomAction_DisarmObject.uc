// Source: ME3, Asari_Adept_MP
// Decompiled 10/27/2026 3:17:22 PM
// MILAN CHANGE
// Force animation to start at beginning so timer can't be reused which causes
// the player to stand mid action

Class SFXCustomAction_DisarmObject extends SFXCustomAction_SingleAnim
    config(Game);

var float MinimumTimeToDisarm;
var SFXObjective_Disarm_Base DisarmObject;
var WwiseEvent DisarmStart;
var WwiseEvent DisarmStop;

public function StartCustomAction()
{
    local SFXGUI_MPHUD oHud;
    local SFXGUIInteraction oGUIController;
    
    Super.StartCustomAction();
    // MILAN CHANGE - Restart the stance instead of resuming a stale one
    if (m_oPawn.IsPlayingBodyStance(BS_Anim))
    {
        m_oPawn.BS_SetPosition(BS_Anim, fAnimStartTime);
        m_oPawn.BS_SetPlayRate(BS_Anim, fAnimPlayRate);
    }
    // END MILAN CHANGE
    m_oPawn.SetTimer(MinimumTimeToDisarm, FALSE, 'DisarmSuccess', Self);
    if (m_oPawn.Role == ENetRole.ROLE_Authority)
    {
        m_oPawn.SetTimer(0.5, TRUE, 'CheckMoving', Self);
        m_oPawn.SetTimer(0.5, TRUE, 'CheckFiring', Self);
    }
    if (SFXGRI(m_oPawn.WorldInfo.GRI).NumLivingPlayers() > 1)
    {
        SFXGRI(m_oPawn.WorldInfo.GRI).TriggerVocalizationEvent(121, m_oPawn);
    }
    oGUIController = Class'SFXGUIInteraction'.static.GetInstance();
    oHud = oGUIController == None ? None : oGUIController.CastGetMovie(Class'SFXGUI_MPHUD', None, oGUIController.MovieTag_MPHUD);
    if (oHud != None)
    {
        oHud.PlayerIsUsingObjectiveWithTime(MinimumTimeToDisarm);
        if (m_oPawn.IsLocallyControlled())
        {
            oHud.ShowCenterProgressBar(MinimumTimeToDisarm);
        }
    }
    m_oPawn.PlaySound(DisarmStart, TRUE);
    if (m_oPawn.IsLocallyControlled() == TRUE && m_oPawn.IsHumanControlled())
    {
        BioPlayerController(m_oPawn.Controller).HintSystem.HintEvent('ObjectiveStarted');
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
public function StopCustomAction()
{
    local SFXGUIInteraction oGUIController;
    local SFXGUI_MPHUD oHud;
    local BioWorldInfo BWI;
    
    Super.StopCustomAction();
    m_oPawn.ClearTimer('CheckMoving', Self);
    m_oPawn.ClearTimer('CheckFiring', Self);
    m_oPawn.ClearTimer('DisarmSuccess', Self);
    m_oPawn.PlaySound(DisarmStop, TRUE);
    DisarmObject = None;
    oGUIController = Class'SFXGUIInteraction'.static.GetInstance();
    oHud = oGUIController == None ? None : oGUIController.CastGetMovie(Class'SFXGUI_MPHUD', None, oGUIController.MovieTag_MPHUD);
    if (oHud != None)
    {
        oHud.PlayerIsFinishedWithObjective();
        if (m_oPawn.IsLocallyControlled())
        {
            oHud.HideCenterProgressBar();
        }
    }
    BWI = BioWorldInfo(m_oPawn.WorldInfo);
    if (BWI != None && BWI.GetAutoBotsEnabled() == TRUE)
    {
        if (BioCheatManagerNonNative(BWI.GetLocalPlayerController().CheatManager) != None)
        {
            BioCheatManagerNonNative(BWI.GetLocalPlayerController().CheatManager).MPBotsClearUsedLast();
        }
    }
}
public function DisarmSuccess()
{
    if (m_oPawn.Role == ENetRole.ROLE_Authority)
    {
        if (DisarmObject != None)
        {
            DisarmObject.DisarmBomb(m_oPawn);
        }
    }
    EndThisCustomAction();
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
                     Func = 'None', 
                     TimeIndex = 0.00999999978, 
                     TimeRemaining = 0.0, 
                     PSC_Instance = None, 
                     RBC_BlurInstance = None, 
                     PS_Template = None, 
                     CrustDuration = 10.0, 
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
                     RVR_CrustTemplate = RvrClientEffectMulti'BioVFX_T_TechPowers._OmniTool.VCFX.OmniTool_LeftFull_VCFX_M', 
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
                    }
                   )
        Lifetime = 11.0
    End Object
    MinimumTimeToDisarm = 10.0
    DisarmStart = WwiseEvent'Wwise_VFX_Tech.Play_vfx_omni_tool_MPDisable_start'
    DisarmStop = WwiseEvent'Wwise_VFX_Tech.Play_vfx_omni_tool_MPDisable_end'
    BS_Anim = {
               AnimName = ('CB_MP_Revive')
              }
    fAnimPlayRate = 0.5
    fAnimBlendInTime = 0.400000006
    fAnimBlendOutTime = 0.400000006
    ERootMotionMode = ERootMotionMode.RMM_Translate
    OverrideList = (Class'SFXCustomAction_Ragdoll', Class'SFXCustomAction_AnimatedRagdoll', Class'SFXCustomAction_Frozen', Class'SFXCustomAction_ClassMelee')
    TimelineTemplate = Timeline0
    bDisableMovement = FALSE
    bAllowChargeHolding = TRUE
    bReplicateCustomAction = TRUE
}