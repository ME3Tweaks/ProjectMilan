Class SFXGameModeBase within BioPlayerController
    native
    abstract
    config(Input);

enum EGameModePriority2
{
    ModePriority_Base,
    ModePriority_CheatMenu,
    ModePriority_Conversation,
    ModePriority_Menus,
    ModePriority_Popup,
};

var transient native Object.MultiMap_Mirror CollectedBindMapping;
var config array<Input.KeyBind> Bindings;
var array<Input.KeyBind> LocalizedBindings;
var int NumReportSkynetMPCustomEventSent;
var(SFXGameModeBase) config float RadarMapDisplayTime;
var bool bBindingsCollected;
var(SFXGameModeBase) bool bIsActive;
var(SFXGameModeBase) const bool bShowHUD;
var(SFXGameModeBase) const bool bShowSelection;
var(SFXGameModeBase) const bool bShowExploreSelection;
var(SFXGameModeBase) const bool bShowDamageIndicators;
var(SFXGameModeBase) const bool bShowRadar;
var(SFXGameModeBase) const bool bShowHealth;
var(SFXGameModeBase) const bool bShowWeapon;
var(SFXGameModeBase) const bool bAllowRotationUpdate;
var(SFXGameModeBase) const bool bAllowMovement;
var(SFXGameModeBase) const bool bStopMovement;
var(SFXGameModeBase) const bool bAllowCamera;
var(SFXGameModeBase) const bool bAllowCameraMods;
var(SFXGameModeBase) const bool bAllowSave;
var(SFXGameModeBase) const bool bAllowPauseMenu;
var(SFXGameModeBase) const bool bAllowHints;
var(SFXGameModeBase) const bool bShowSubtitle;
var(SFXGameModeBase) const bool bClearPendingFire;
var(SFXGameModeBase) const bool bHasMouseAuthority;
var(SFXGameModeBase) bool bMouseVisible;
var(SFXGameModeBase) bool bMergeNotifications;
var(SFXGameModeBase) bool bQueueAndSuppressNotifications;
var(SFXGameModeBase) bool bShowReticles;
var(SFXGameModeBase) bool bPlayVocalizations;
var(SFXGameModeBase) bool bEnforce16x9Subtitles;
var(SFXGameModeBase) bool bAllowMessageUI;
var(SFXGameModeBase) bool bRestrictToPrimaryViewport;
var(SFXGameModeBase) const bool bNuiSpeechGlobal;
var(SFXGameModeBase) const bool bNuiSpeechExplore;
var(SFXGameModeBase) const bool bNuiSpeechCombat;
var(SFXGameModeBase) const bool bAllowPowerWeaponUI;
var(SFXGameModeBase) SFXGameModeBase.EGameModePriority2 Priority;

public function Activated()
{
    local SFXWeapon PlayerWeapon;
    
    bIsActive = TRUE;
    if (!bAllowMovement)
    {
        Outer.IgnoreMoveInput(TRUE);
    }
    if (!bAllowRotationUpdate)
    {
        Outer.IgnoreLookInput(TRUE);
    }
    if (bStopMovement && Outer.Pawn != None)
    {
        BioPawn(Outer.Pawn).StopMovement();
    }
    if (bClearPendingFire)
    {
        if (Outer.Pawn.InvManager != None)
        {
            PlayerWeapon = SFXWeapon(Outer.Pawn.Weapon);
            if (PlayerWeapon != None && Outer.Pawn.InvManager.IsPendingFire(PlayerWeapon, int(PlayerWeapon.DefaultFireMode)))
            {
                PlayerWeapon.StopFire(PlayerWeapon.DefaultFireMode);
            }
            Outer.Pawn.InvManager.ClearAllPendingFire(Outer.Pawn.Weapon);
        }
    }
}
public final function ClearTimer(optional Name inTimerFunc = 'Timer', optional Object inObj)
{
    Outer.ClearTimer(inTimerFunc, inObj != None ? inObj : Self);
}
public native function CollectBindings();

public function Deactivated()
{
    bIsActive = FALSE;
    if (!bAllowMovement)
    {
        Outer.IgnoreMoveInput(FALSE);
    }
    if (!bAllowRotationUpdate)
    {
        Outer.IgnoreLookInput(FALSE);
    }
}
public exec function FireWeapon()
{
    if (BioPlayerInput(Outer.PlayerInput).IsCombatEnabled() == FALSE)
    {
        return;
    }
    if (int(Outer.bFire) == 0)
    {
        Outer.SetAFKLastActionTime(FALSE);
    }
    Outer.bFire = 1;
}
public event function SFXCameraMode HACK_GetCameraMode();

public event function HidePauseMenu()
{
    local SFXGUIInteraction oGUI;
    
    oGUI = Class'SFXGUIInteraction'.static.GetInstance();
    if (Outer.GameModeManager2.IsActive(9) && oGUI.GetBrowserHandler(Outer) != None)
    {
        oGUI.HideBrowserWheel(None, Outer);
    }
}
public event function Initialize()
{
    CollectBindings();
}
public final function SetTimer(float InRate, optional bool inbLoop, optional Name inTimerFunc = 'Timer', optional Object inObj)
{
    Outer.SetTimer(InRate, inbLoop, inTimerFunc, inObj != None ? inObj : Self);
}
public event function ShowPauseMenu()
{
    ShowMenu();
}
public exec function ShowMenu()
{
    if (bAllowPauseMenu)
    {
        Outer.bWantsToStorm = 0;
        if (Outer.WorldInfo.GRI.IsMultiplayerGame())
        {
            Class'SFXGUIInteraction'.static.GetInstance().ShowMPPauseMenu(Outer, TRUE);
        }
        else
        {
            Class'SFXGUIInteraction'.static.GetInstance().ShowBrowserWheel(Outer);
        }
    }
}
public function ActivateSpecifier(Name ModeSpecifier);

public function DeactivateSpecifier(Name ModeSpecifier);

public exec function EnterCommandMenu()
{
    if (!bAllowPowerWeaponUI)
    {
        return;
    }
    if (BioPlayerInput(Outer.PlayerInput).IsCombatEnabled() == FALSE)
    {
        return;
    }
    // Milan Change DropTheSquid 11/2/2026
    // added a check that disables the tactics HUD in MP mode, same as the power and weapon wheels
    if (Outer.WorldInfo.GRI.IsMultiplayerGame())
    {
        return;
    }
    // END MILAN CHANGE
    if (BioPawn(Outer.Pawn).IsInAnimatedTransition())
    {
        SetTimer(0.200000003, FALSE, GetFuncName());
        return;
    }
    Outer.GameModeManager2.EnableMode(5);
}
public exec function EnterPowerWheel()
{
    if (BioPlayerInput(Outer.PlayerInput).IsCombatEnabled() == FALSE)
    {
        return;
    }
    if (!bAllowPowerWeaponUI)
    {
        return;
    }
    if (Outer.WorldInfo.GRI.IsMultiplayerGame())
    {
        SFXPlayerController(Outer).PulsePowerDisplay();
        return;
    }
    if (BioPawn(Outer.Pawn).IsInAnimatedTransition())
    {
        SetTimer(0.200000003, FALSE, GetFuncName());
        return;
    }
    Outer.GameModeManager2.EnableMode(3);
}
public exec function EnterWeaponWheel()
{
    if (BioPlayerInput(Outer.PlayerInput).IsCombatEnabled() == FALSE)
    {
        return;
    }
    if (!bAllowPowerWeaponUI)
    {
        return;
    }
    if (Outer.WorldInfo.GRI.IsMultiplayerGame())
    {
        return;
    }
    if (BioPawn(Outer.Pawn).IsInAnimatedTransition())
    {
        SetTimer(0.200000003, FALSE, GetFuncName());
        return;
    }
    Outer.GameModeManager2.EnableMode(4);
}
public function SFXCameraMode GetCameraMode(SFXCameraMode OldCameraMode, out int PreserveTarget, out float TransitionTime, out SFXCameraMode_Interpolate Transition)
{
    TransitionTime = 0.0;
    PreserveTarget = 0;
    return OldCameraMode;
}
public exec function GuiKey(BioDefine.BioGuiEvents Event)
{
    Class'SFXGUIInteraction'.static.GetInstance().HandleInputEvent(Outer.GetPlayerControllerId(), Event);
}
public exec function HoldObjectiveDisplay()
{
    local SFXGUIInteraction oGUI;
    local SFXGUI_Markers oObjectiveMarkers;
    
    oGUI = Class'SFXGUIInteraction'.static.GetInstance();
    if (oGUI != None)
    {
        oObjectiveMarkers = oGUI.CastGetMovie(Class'SFXGUI_Markers', Outer, oGUI.MovieTag_Markers);
        if (oObjectiveMarkers != None)
        {
            oObjectiveMarkers.BeginOnDemandPulse();
            oObjectiveMarkers.DisplayObjectiveText();
            SetTimer(0.5, TRUE, 'BeginOnDemandPulse', oObjectiveMarkers);
            SetTimer(0.5, TRUE, 'DisplayObjectiveText', oObjectiveMarkers);
        }
    }
}
public native function bool IsSystemFilmgrainEnabled();

public exec function LeaveWorld()
{
    local SFXGRI GRI;
    local Sequence GameSeq;
    local array<SequenceObject> AllLeaveEvents;
    local SequenceObject Event;
    
    GRI = SFXGRI(Outer.WorldInfo.GRI);
    if (GRI != None && GRI.InCombat() == FALSE)
    {
        GameSeq = Outer.WorldInfo.GetGameSequence();
        if (GameSeq != None)
        {
            GameSeq.FindSeqObjectsByClass(Class'SFXSeqEvt_LeaveWorld', TRUE, AllLeaveEvents);
            foreach AllLeaveEvents(Event, )
            {
                SequenceEvent(Event).CheckActivate(Outer.Pawn, Outer.Pawn);
            }
        }
    }
}
public function PauseTimeDilationEffects()
{
    local SFXModule_GameEffectManager Manager;
    local SFXGame Game;
    
    if (Outer.Pawn != None)
    {
        Manager = Outer.Pawn.GetModule(Class'SFXModule_GameEffectManager');
        if (Manager != None)
        {
            Manager.PauseEffectsByType(Class'SFXGameEffect_TimeDilation');
        }
    }
    if (Outer.WorldInfo != None)
    {
        Game = SFXGame(Outer.WorldInfo.Game);
        if (Game != None)
        {
            Game.OnTimeDilationChange(1.0);
        }
    }
}
public exec function PulseObjectiveDisplay()
{
    local SFXGUIInteraction oGUI;
    local SFXGUI_Markers oObjectiveMarkers;
    
    oGUI = Class'SFXGUIInteraction'.static.GetInstance();
    if (oGUI != None)
    {
        oObjectiveMarkers = oGUI.CastGetMovie(Class'SFXGUI_Markers', Outer, oGUI.MovieTag_Markers);
        if (oObjectiveMarkers != None)
        {
            Outer.GenerateTutorialEvent(18);
            oObjectiveMarkers.BeginOnDemandPulse();
            oObjectiveMarkers.DisplayObjectiveText();
        }
    }
}
public exec function PulseRadarDisplay(float fPulseTime)
{
    local SFXGUIInteraction oGUI;
    local SFXSFHandler_PowerWheel oPowerWheel;
    
    oGUI = Class'SFXGUIInteraction'.static.GetInstance();
    if (oGUI != None)
    {
        oPowerWheel = oGUI.CastGetMovie(Class'SFXSFHandler_PowerWheel', Outer, oGUI.MovieTag_PowerWheel);
        if (oPowerWheel != None)
        {
            oPowerWheel.PulseRadar(fPulseTime);
        }
    }
}
public function RemoveTimeDilationEffects()
{
    local SFXModule_GameEffectManager Manager;
    local SFXGame Game;
    
    if (Outer.Pawn != None)
    {
        Manager = Outer.Pawn.GetModule(Class'SFXModule_GameEffectManager');
        if (Manager != None)
        {
            Manager.RemoveEffectsByType(Class'SFXGameEffect_TimeDilation');
        }
    }
    if (Outer.WorldInfo != None)
    {
        Game = SFXGame(Outer.WorldInfo.Game);
        if (Game != None)
        {
            Game.OnTimeDilationChange(1.0);
        }
    }
}
public final exec function ReportCustomEvent()
{
    local BioRemoteLogger GLogger;
    local SFXGUIInteraction SFXUIController;
    local Object.Color Clr;
    local string sMessage;
    
    GLogger = Class'BioRemoteLogger'.static.GetLogger();
    if (GLogger != None)
    {
        NumReportSkynetMPCustomEventSent++;
        sMessage = "Skynet Custom_Event # " $ NumReportSkynetMPCustomEventSent $ " has been sent.";
        Clr.R = 255;
        Clr.G = 255;
        Clr.B = 255;
        Clr.A = 255;
        SFXUIController = Outer.GetSFXUIController();
        if (SFXUIController != None)
        {
            SFXUIController.AddLogEntry(sMessage, 10.0, Clr);
        }
        LogInternal(sMessage, );
        GLogger.SendMPEvent(41, 0.0, 0.0, 0.0, "", "", NumReportSkynetMPCustomEventSent, 0);
    }
}
public native function SetSystemFilmgrainEnabled(bool bValue);

public exec function bool ShowAreaMap()
{
    local SFXGUIInteraction oManager;
    local SFXSFHandler_AreaMap oHandler;
    local bool bGotMap;
    local BioPawn BP;
    
    BP = BioPawn(Outer.Pawn);
    oManager = Class'SFXGUIInteraction'.static.GetInstance();
    if (oManager != None)
    {
        if (Outer.GameModeManager2.IsActive(7) && oManager.GetConversationHandler(Outer) != None)
        {
            return FALSE;
        }
        oManager.ShowAreaMap(Outer);
        oHandler = oManager.GetAreaMapHandler(BioWorldInfo(Class'Engine'.static.GetCurrentWorldInfo()).GetLocalPlayerController());
        if (oHandler != None)
        {
            bGotMap = oHandler.Initialize(FALSE);
        }
    }
    if (!bGotMap)
    {
        if (BP.CoverAction != ECoverAction.CA_PeekLeft && BP.CoverAction != ECoverAction.CA_PeekRight)
        {
            PulseObjectiveDisplay();
        }
    }
    else
    {
        ClearTimer('TurnObjectiveRadarDisplayOn', Self);
    }
    return bGotMap;
}
public final exec function SquadCommand_Attack()
{
    local bool bCanUseHenchmen;
    local bool bSuccess;
    
    bCanUseHenchmen = SFXGRI(Outer.WorldInfo.GRI).bCanSpawnHenchmen;
    bSuccess = FALSE;
    if (bCanUseHenchmen)
    {
        if (BioPlayerInput(Outer.PlayerInput).IsCombatEnabled())
        {
            bSuccess = Outer.QuickCommandAttackTarget();
        }
        Class'SFXGUIInteraction'.static.GetInstance().ForceSquadCommandFeedback(1, 0, bSuccess, Outer);
    }
}
public final exec function SquadCommand_Follow()
{
    local bool bCanUseHenchmen;
    local bool bSuccess;
    
    bCanUseHenchmen = SFXGRI(Outer.WorldInfo.GRI).bCanSpawnHenchmen;
    bSuccess = FALSE;
    if (bCanUseHenchmen)
    {
        if (BioPlayerInput(Outer.PlayerInput).IsCombatEnabled())
        {
            bSuccess = Outer.QuickCommandFollowPlayer();
        }
        Class'SFXGUIInteraction'.static.GetInstance().ForceSquadCommandFeedback(3, 0, bSuccess, Outer);
    }
}
public final exec function SquadCommand_Move1()
{
    local bool bCanUseHenchmen;
    local bool bSuccess;
    
    bCanUseHenchmen = SFXGRI(Outer.WorldInfo.GRI).bCanSpawnHenchmen;
    bSuccess = FALSE;
    if (bCanUseHenchmen)
    {
        if (BioPlayerInput(Outer.PlayerInput).IsCombatEnabled())
        {
            bSuccess = Outer.QuickCommandMoveTo(1);
        }
        Class'SFXGUIInteraction'.static.GetInstance().ForceSquadCommandFeedback(2, 1, bSuccess, Outer);
    }
}
public final exec function SquadCommand_Move2()
{
    local bool bCanUseHenchmen;
    local bool bSuccess;
    
    bCanUseHenchmen = SFXGRI(Outer.WorldInfo.GRI).bCanSpawnHenchmen;
    bSuccess = FALSE;
    if (bCanUseHenchmen)
    {
        if (BioPlayerInput(Outer.PlayerInput).IsCombatEnabled())
        {
            bSuccess = Outer.QuickCommandMoveTo(2);
        }
        Class'SFXGUIInteraction'.static.GetInstance().ForceSquadCommandFeedback(2, 2, bSuccess, Outer);
    }
}
public exec function StartIngamePropertyEditor()
{
    local SFXGUIInteraction oGUI;
    
    oGUI = Class'SFXGUIInteraction'.static.GetInstance();
    if (Class'Engine'.static.IsShip() || Class'SFXEngine'.static.IsDemoMode())
    {
        return;
    }
    if (Outer.GameModeManager2.IsActive(9) && oGUI.GetBrowserHandler(Outer) != None || Outer.GameModeManager2.IsActive(7) && oGUI.GetConversationHandler(Outer) != None)
    {
        if (Outer.GameModeManager2.IsActive(9))
        {
            oGUI.HideBrowserWheel(None, Outer);
        }
        Outer.GameModeManager2.EnableMode(15);
    }
}
public exec function StopFiringWeapon()
{
    Outer.bFire = 0;
}
public exec function StopObjectiveDisplay()
{
    local SFXGUIInteraction oGUI;
    local SFXGUI_Markers oObjectiveMarkers;
    
    oGUI = Class'SFXGUIInteraction'.static.GetInstance();
    if (oGUI != None)
    {
        oObjectiveMarkers = oGUI.CastGetMovie(Class'SFXGUI_Markers', Outer, oGUI.MovieTag_Markers);
        if (oObjectiveMarkers != None)
        {
            if (Outer.IsTimerActive('BeginOnDemandPulse', oObjectiveMarkers))
            {
                ClearTimer('BeginOnDemandPulse', oObjectiveMarkers);
                oObjectiveMarkers.FadeOutMarkers();
            }
            if (Outer.IsTimerActive('DisplayObjectiveText', oObjectiveMarkers))
            {
                ClearTimer('DisplayObjectiveText', oObjectiveMarkers);
                oObjectiveMarkers.HideObjectiveText();
            }
        }
    }
}
public exec function ToggleObjectiveRadarDisplay(bool bTurnOn)
{
    local SFXGUIInteraction oGUI;
    local SFXSFHandler_PowerWheel oPowerWheel;
    
    oGUI = Class'SFXGUIInteraction'.static.GetInstance();
    if (oGUI != None)
    {
        oPowerWheel = oGUI.CastGetMovie(Class'SFXSFHandler_PowerWheel', Outer, oGUI.MovieTag_PowerWheel);
        if (oPowerWheel != None)
        {
            oPowerWheel.m_bObjectiveRadarOn = bTurnOn;
        }
    }
}
public exec function TurnObjectiveRadarDisplayOff()
{
    ToggleObjectiveRadarDisplay(FALSE);
}
public exec function TurnObjectiveRadarDisplayOn()
{
    ToggleObjectiveRadarDisplay(TRUE);
}
public final function TurnOffStormForPause()
{
    Outer.bWantsToStorm = 0;
}
public function UnpauseTimeDilationEffects()
{
    local SFXModule_GameEffectManager Manager;
    
    if (Outer.Pawn != None)
    {
        Manager = Outer.Pawn.GetModule(Class'SFXModule_GameEffectManager');
        if (Manager != None)
        {
            Manager.UnpauseEffectsByType(Class'SFXGameEffect_TimeDilation');
        }
    }
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    Bindings = ({
                 Command = "Axis aTurn Speed=1.0 DeadZone=0.2", 
                 Name = 'Console_LookX', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }, 
                {
                 Command = "Axis aLookup Speed=1.0 DeadZone=0.2", 
                 Name = 'Console_LookY', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }, 
                {
                 Command = "Axis aLookup Speed=-1.0, DeadZone=0.2", 
                 Name = 'Console_LookY_Invert', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }, 
                {
                 Command = "Axis aStrafe Speed=1.0 DeadZone=0.2", 
                 Name = 'Console_Strafe', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }, 
                {
                 Command = "Axis aBaseY Speed=1.0 DeadZone=0.2", 
                 Name = 'Console_Movement', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }, 
                {
                 Command = "Axis aBaseY Speed=-1.0 DeadZone=0.2", 
                 Name = 'Console_Movement_Invert', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }, 
                {
                 Command = "SwapWeaponIfEmpty | FireWeapon | OnRelease StopFiringWeapon", 
                 Name = 'Console_Shoot', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }, 
                {
                 Command = "SwapWeaponIfEmpty | TightAim | OnRelease StopTightAim", 
                 Name = 'Console_Aim', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }, 
                {
                 Command = "OnTap 0.3 TryUsePower 0 | OnHold 0.3 EnterWeaponWheel", 
                 Name = 'Console_WeaponWheelAndQuickPower1', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }, 
                {
                 Command = "OnTap 0.3 TryUsePower 1 | OnHold 0.3 EnterPowerWheel", 
                 Name = 'Console_PowerWheelAndQuickPower2', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }, 
                {
                 Command = "Exclusive TryStandingJump | Exclusive Used | OnRelease StormOff | OnHold 0.2 StormOn | Exclusive PressAction | OnTap 0.3 TapAction | OnHold 0.3 HoldAction", 
                 Name = 'Console_Action', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }, 
                {
                 Command = "OnTap 0.3 TryMelee | LeaveWorld | OnHold 0.3 TryHeavyMelee", 
                 Name = 'Console_Melee', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }, 
                {
                 Command = "OnTap 0.3 SwapWeaponIfEmpty | OnTap 0.3 TryReload | OnHold 0.3 TrySwapWeapon", 
                 Name = 'Console_Weapon', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }, 
                {
                 Command = "OnRelease ExitPowerWheel", 
                 Name = 'Console_ExitPowerWheel', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }, 
                {
                 Command = "OnRelease ExitWeaponWheel", 
                 Name = 'Console_ExitWeaponWheel', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }, 
                {
                 Command = "TryUsePower 3 | SquadCommand_Attack", 
                 Name = 'Console_SquadAttackAndPower4', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }, 
                {
                 Command = "TryUsePower 4 | SquadCommand_Move2", 
                 Name = 'Console_SquadMove2AndPower5', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }, 
                {
                 Command = "TryUsePower 5 | SquadCommand_Follow", 
                 Name = 'Console_SquadFollowAndPower6', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }, 
                {
                 Command = "TryUsePower 6 | SquadCommand_Move1", 
                 Name = 'Console_SquadMove1AndPower7', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }, 
                {
                 Command = "ShowMenu", 
                 Name = 'Console_Menu', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }, 
                {
                 Command = "SelectResponse", 
                 Name = 'Console_ConvSelect', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }, 
                {
                 Command = "SkipConversation", 
                 Name = 'Console_ConvSkip', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }, 
                {
                 Command = "InterruptRenegade", 
                 Name = 'Console_ConvIntRenegade', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }, 
                {
                 Command = "InterruptParagon", 
                 Name = 'Console_ConvIntParagon', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }, 
                {
                 Command = "SkipCinematic", 
                 Name = 'Console_CineSkip', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }, 
                {
                 Command = "SkipMovie", 
                 Name = 'Console_MovieSkip', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }, 
                {
                 Command = "ToggleReticleMode", 
                 Name = 'Console_GalaxyToggle', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }, 
                {
                 Command = "StartFuel|Repeat BuyFuel 0.2|OnRelease StopFuel", 
                 Name = 'Console_BuyFuel', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }, 
                {
                 Command = "StartScanning | OnRelease StopScanning", 
                 Name = 'Console_GalaxyScan', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }, 
                {
                 Command = "ScanSystem", 
                 Name = 'Console_GalaxySystemScan', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }, 
                {
                 Command = "LaunchProbe", 
                 Name = 'Console_GalaxyProbe', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }, 
                {
                 Command = "TabRight", 
                 Name = 'Console_GalaxyTabRight', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }, 
                {
                 Command = "TabLeft", 
                 Name = 'Console_GalaxyTabLeft', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }, 
                {
                 Command = "ExitAtlas", 
                 Name = 'Console_ExitAtlas', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }, 
                {
                 Command = "ExitVehicle", 
                 Name = 'Console_ExitMountedGun', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }, 
                {
                 Command = "SlideshowAdvance true", 
                 Name = 'Console_AdvanceSlideshowForward', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }, 
                {
                 Command = "SlideshowAdvance false", 
                 Name = 'Console_AdvanceSlideshowBackward', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }, 
                {
                 Command = "SlideshowExit", 
                 Name = 'Console_ExitSlideshow', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }, 
                {
                 Command = "QuickSave", 
                 Name = 'Console_QuickSave', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }, 
                {
                 Command = "HideAreaMap", 
                 Name = 'Console_MapAndPhotoMode', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }, 
                {
                 Command = "MPToggleReady", 
                 Name = 'Console_MPToggleReady', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }, 
                {
                 Command = "viewprevplayer true", 
                 Name = 'Console_ViewPrevPlayer', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }, 
                {
                 Command = "viewnextplayer true", 
                 Name = 'Console_ViewNextPlayer', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }, 
                {
                 Command = "OnRelease TryUsePower 2", 
                 Name = 'Console_UsePower3', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }, 
                {
                 Command = "Exclusive TryCoverTurn | Exclusive ActivatePOI | OnRelease DeactivatePOI | ShowAreaMap ", 
                 Name = 'Console_NavAssistanceOrCoverTurn', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }, 
                {
                 Command = "ToggleOptions", 
                 Name = 'Console_TogglePhotoOptions', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }, 
                {
                 Command = "Axis aUp Speed=1.0 DeadZone=0.2", 
                 Name = 'Console_MoveUp', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }, 
                {
                 Command = "Axis aUp Speed=-1.0 DeadZone=0.2", 
                 Name = 'Console_MoveDown', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }, 
                {
                 Command = "TakePhoto", 
                 Name = 'Console_Screenshot', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }, 
                {
                 Command = "Axis aStrafe Speed=1.0 DeadZone=0.1", 
                 Name = 'Console_PhotoStrafe', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }, 
                {
                 Command = "Axis aBaseY Speed=1.0 DeadZone=0.1", 
                 Name = 'Console_PhotoMovement', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }, 
                {
                 Command = "Count bXAxis | Axis aMouseX", 
                 Name = 'PC_LookX', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }, 
                {
                 Command = "Count bYAxis | Axis aMouseY", 
                 Name = 'PC_LookY', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }, 
                {
                 Command = "Axis aStrafe Speed=-1.0", 
                 Name = 'PC_StrafeLeft', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }, 
                {
                 Command = "Axis aStrafe Speed=+1.0", 
                 Name = 'PC_StrafeRight', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }, 
                {
                 Command = "Axis aBaseY Speed=1.0", 
                 Name = 'PC_MoveForward', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }, 
                {
                 Command = "Axis aBaseY Speed=-1.0", 
                 Name = 'PC_MoveBackward', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }, 
                {
                 Command = "SwapWeaponIfEmpty | FireWeapon | OnRelease StopFiringWeapon", 
                 Name = 'PC_Shoot', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }, 
                {
                 Command = "SwapWeaponIfEmpty | TightAim | OnRelease StopTightAim", 
                 Name = 'PC_Aim', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }, 
                {
                 Command = "Exclusive TryStandingJump | Exclusive Used | OnRelease StormOff | OnHold 0.2 StormOn | Exclusive PressAction | OnTap 0.3 TapAction | OnHold 0.3 HoldAction", 
                 Name = 'PC_Action', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }, 
                {
                 Command = "OnTap 0.3 TryMelee | LeaveWorld | OnHold 0.3 TryHeavyMelee", 
                 Name = 'PC_Melee', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }, 
                {
                 Command = "TrySwapWeapon", 
                 Name = 'PC_SwapWeapon', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }, 
                {
                 Command = "SwapWeaponIfEmpty | TryReload", 
                 Name = 'PC_Reload', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }, 
                {
                 Command = "EnterCommandMenu", 
                 Name = 'PC_EnterCommandMenu', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }, 
                {
                 Command = "OnRelease ExitCommandMenu", 
                 Name = 'PC_ExitCommandMenu', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }, 
                {
                 Command = "EnableCamera | OnRelease DisableCamera", 
                 Name = 'PC_CommandToggleCam', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }, 
                {
                 Command = "SquadCommand_Attack", 
                 Name = 'PC_SquadAttack', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }, 
                {
                 Command = "SquadCommand_Follow", 
                 Name = 'PC_SquadFollow', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }, 
                {
                 Command = "SquadCommand_Move1", 
                 Name = 'PC_SquadMove1', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }, 
                {
                 Command = "SquadCommand_Move2", 
                 Name = 'PC_SquadMove2', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }, 
                {
                 Command = "ShowMenu", 
                 Name = 'PC_Menu', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }, 
                {
                 Command = "SelectResponse", 
                 Name = 'PC_ConvSelect', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }, 
                {
                 Command = "SkipConversation", 
                 Name = 'PC_ConvSkip', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }, 
                {
                 Command = "HighlightDefaultResponse", 
                 Name = 'PC_ConvHilight', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }, 
                {
                 Command = "InterruptRenegade", 
                 Name = 'PC_ConvIntRenegade', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }, 
                {
                 Command = "InterruptParagon", 
                 Name = 'PC_ConvIntParagon', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }, 
                {
                 Command = "SkipCinematic", 
                 Name = 'PC_CineSkip', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }, 
                {
                 Command = "SkipMovie", 
                 Name = 'PC_MovieSkip', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }, 
                {
                 Command = "Axis aMouseX BIOGUI_EVENT_AXIS_MOUSE_X", 
                 Name = 'PC_GalaxyMouseStrafe', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }, 
                {
                 Command = "Axis aMouseY BIOGUI_EVENT_AXIS_MOUSE_Y", 
                 Name = 'PC_GalaxyMouseMovement', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }, 
                {
                 Command = "Repeat PlanetLeftRight 0.5", 
                 Name = 'PC_GalaxyKeyRotateLeft', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }, 
                {
                 Command = "Repeat PlanetLeftRight -0.5", 
                 Name = 'PC_GalaxyKeyRotateRight', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }, 
                {
                 Command = "StartScanning | OnRelease StopScanning", 
                 Name = 'PC_GalaxyScan', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }, 
                {
                 Command = "ScanSystem", 
                 Name = 'PC_GalaxySystemScan', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }, 
                {
                 Command = "LaunchProbe", 
                 Name = 'PC_GalaxyProbe', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }, 
                {
                 Command = "ExitAtlas", 
                 Name = 'PC_ExitAtlas', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }, 
                {
                 Command = "ExitVehicle", 
                 Name = 'PC_ExitMountedGun', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }, 
                {
                 Command = "SlideshowAdvance true", 
                 Name = 'PC_AdvanceSlideshowForward', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }, 
                {
                 Command = "SlideshowAdvance false", 
                 Name = 'PC_AdvanceSlideshowBackward', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }, 
                {
                 Command = "SlideshowExit", 
                 Name = 'PC_ExitSlideshow', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }, 
                {
                 Command = "QuickSave", 
                 Name = 'PC_QuickSave', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }, 
                {
                 Command = "QuickLoad", 
                 Name = 'PC_QuickLoad', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }, 
                {
                 Command = "MPToggleReady", 
                 Name = 'PC_MPToggleReady', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }, 
                {
                 Command = "NextWeapon", 
                 Name = 'PC_NextWeapon', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }, 
                {
                 Command = "PrevWeapon", 
                 Name = 'PC_PrevWeapon', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }, 
                {
                 Command = "UseAbility 0", 
                 Name = 'PC_HotKey1', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }, 
                {
                 Command = "UseAbility 1", 
                 Name = 'PC_HotKey2', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }, 
                {
                 Command = "UseAbility 2", 
                 Name = 'PC_HotKey3', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }, 
                {
                 Command = "UseAbility 3", 
                 Name = 'PC_HotKey4', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }, 
                {
                 Command = "UseAbility 4", 
                 Name = 'PC_HotKey5', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }, 
                {
                 Command = "UseAbility 5", 
                 Name = 'PC_HotKey6', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }, 
                {
                 Command = "UseAbility 6", 
                 Name = 'PC_HotKey7', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }, 
                {
                 Command = "UseAbility 7", 
                 Name = 'PC_HotKey8', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }, 
                {
                 Command = "Exclusive ActivatePOI | OnRelease DeactivatePOI | OnTap 0.2 ShowAreaMap | OnHold 0.2 HoldObjectiveDisplay | OnRelease StopObjectiveDisplay ", 
                 Name = 'PC_ShowMap', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }, 
                {
                 Command = "HideAreaMap", 
                 Name = 'PC_HideMap', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }, 
                {
                 Command = "TryCoverTurn", 
                 Name = 'PC_CoverTurn', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }, 
                {
                 Command = "EnableWalking | OnRelease DisableWalking", 
                 Name = 'Walking', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }, 
                {
                 Command = "VoicePushToTalkStart | OnRelease VoicePushToTalkEnd", 
                 Name = 'PC_PushToTalk', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }, 
                {
                 Command = "viewprevplayer true", 
                 Name = 'PC_ViewPrevPlayer', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }, 
                {
                 Command = "viewnextplayer true", 
                 Name = 'PC_ViewNextPlayer', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }, 
                {
                 Command = "EnableCamera | OnRelease DisableCamera", 
                 Name = 'PC_TogglePhotoCamera', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }, 
                {
                 Command = "ToggleOptions", 
                 Name = 'PC_TogglePhotoOptions', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }, 
                {
                 Command = "Axis aUp Speed=1.0 DeadZone=0.2", 
                 Name = 'PC_MoveUp', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }, 
                {
                 Command = "Axis aUp Speed=-1.0 DeadZone=0.2", 
                 Name = 'PC_MoveDown', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }, 
                {
                 Command = "TakePhoto", 
                 Name = 'PC_Screenshot', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }, 
                {
                 Command = "Repeat GuiKey BIOGUI_EVENT_CONTROL_UP | OnRelease GuiKey BIOGUI_EVENT_CONTROL_UP_RELEASE", 
                 Name = 'PC_GUIControlUp', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }, 
                {
                 Command = "Repeat GuiKey BIOGUI_EVENT_CONTROL_DOWN | OnRelease GuiKey BIOGUI_EVENT_CONTROL_DOWN_RELEASE", 
                 Name = 'PC_GUIControlDown', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }, 
                {
                 Command = "Repeat GuiKey BIOGUI_EVENT_CONTROL_LEFT | OnRelease GuiKey BIOGUI_EVENT_CONTROL_LEFT_RELEASE", 
                 Name = 'PC_GUIControlLeft', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }, 
                {
                 Command = "Repeat GuiKey BIOGUI_EVENT_CONTROL_RIGHT | OnRelease GuiKey BIOGUI_EVENT_CONTROL_RIGHT_RELEASE", 
                 Name = 'PC_GUIControlRight', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }
               )
    RadarMapDisplayTime = 1.0
    bShowExploreSelection = TRUE
    bShowHealth = TRUE
    bShowWeapon = TRUE
}