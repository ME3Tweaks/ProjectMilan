Class SFXGUI_MPHUD extends SFXGUIMovieMP
    config(UI);

// Types
struct MPUIObjectiveCircle 
{
    var string Text;
    var GFxValue MovieClip;
    var float PercentComplete;
    var bool Complete;
};
struct SFXMPHUD_TickerEntry 
{
    var string Text;
    var float TimeToLive;
    var int MovieIndex;
    var bool Fading;
    
    structdefaultproperties
    {
        MovieIndex = -1
    }
};
struct SFXMPHUD_TickerMovie 
{
    var int Id;
    var GFxValue TickerMovie;
    var int CurrentSlot;
};
const NUM_OBJECTIVE_CIRCLES = 4;
const NUM_TICKER_SLOTS = 4;

// Variables
var transient MPUIObjectiveCircle ObjectiveCircles[4];
var transient string CurrentTimerText;
var transient array<SFXMPHUD_TickerEntry> TickerItems;
var transient array<int> AvailableTickerMovies;
var transient SFXMPHUD_TickerMovie TickerMovies[4];
var transient GFxValue CountdownText;
var transient float CurrentCountdownTime;
var transient float CountdownWarningTime;
var transient SFXGUIValue_HUDPowerIcon DPadIconTop;
var transient SFXGUIValue_HUDPowerIcon DPadIconLeft;
var transient SFXGUIValue_HUDPowerIcon DPadIconBottom;
var transient SFXGUIValue_HUDPowerIcon DPadIconRight;
var transient float DPadElapsedDisplayTime;
var transient float TimeToNextTickerUpdate;
var transient GFxValue ObjectiveBar;
var transient GFxValue ObjectiveText;
var transient int CurrentObjectiveFrame;
var transient GFxValue ObjectiveCircleText;
var transient int CurrentObjectiveCircle;
var transient int PlayersCurrentlyUsingObjective;
var transient float CurrentObjectiveTime;
var transient float CurrentObjectiveTimeRemaining;
var transient stringref CurrentObjectiveText;
var transient SFXGUIValue_HUDPowerIcon CenterIconLeft;
var transient SFXGUIValue_HUDPowerIcon CenterIconCenter;
var transient SFXGUIValue_HUDPowerIcon CenterIconRight;
var transient GFxValue CenterProgressBar;
var transient float CenterBarRemainingTime;
var transient float CenterBarTime;
var privatewrite transient stringref CurrentSubareaText;
var config float DPadDisplayTime;
var config float TickerEntryDisplayTime;
var config float TickerUpdateTime;
var transient GFxValue SpectatorModeDescription;
var config stringref srSpectatorHUDDescriptionPC;
var config stringref srSpectatorHUDDescriptionConsole;
var transient bool Initialized;
var transient bool CountdownVisible;
var transient bool CountdownInWarning;
var transient bool DPadVisible;
var transient bool ObjectiveBarVisible;
var transient bool BoostAnimActive;
var transient bool ObjectiveCirclesVisible;
var transient bool CenterPowersVisible;
var transient bool CenterBarVisible;
var config bool DPadFadeOut;
var transient bool m_bSpectatorHUDVisible;
var transient bool PCPowersInitialized;

// Functions
public final function LogFromAS(string Message)
{
    LogInternal("LogFromAS:" @ Message, );
}
public event function HandleButtonRefresh(bool usingGamepad)
{
    Super(SFXGUIMovie).HandleButtonRefresh(usingGamepad);
    ActionScriptVoid("RefreshButtonHelp");
}
public final function Initialize()
{
    HandleButtonRefresh(bUsingGamepad);
    InitializeDPadPowerIcons();
    InitializeCenterPowerIcons();
    SFXPawn_Player(GetPC().Pawn).PowerManager.RegisterPowerReleasedCallback(OnPawnPowerUsed);
    SetPowersVisible(TRUE, TRUE);
    ShowDPadPowerIcons();
    Initialized = TRUE;
}
public event function OnControllerProfileSettingChange()
{
    InitializeCenterPowerIcons();
}
public event function OnStart()
{
    Super(SFXGUIMovie).OnStart();
    DPadIconTop = SFXGUIValue_HUDPowerIcon(GetVariableObject("DPadMap.DPadPowerIcons.PowerTop", Class'SFXGUIValue_HUDPowerIcon'));
    DPadIconTop.sPath = "DPadMap.DPadPowerIcons.PowerTop";
    DPadIconTop.FlashWhenTextChanges = TRUE;
    DPadIconLeft = SFXGUIValue_HUDPowerIcon(GetVariableObject("DPadMap.DPadPowerIcons.PowerLeft", Class'SFXGUIValue_HUDPowerIcon'));
    DPadIconLeft.sPath = "DPadMap.DPadPowerIcons.PowerLeft";
    DPadIconLeft.FlashWhenTextChanges = TRUE;
    DPadIconBottom = SFXGUIValue_HUDPowerIcon(GetVariableObject("DPadMap.DPadPowerIcons.PowerBtm", Class'SFXGUIValue_HUDPowerIcon'));
    DPadIconBottom.sPath = "DPadMap.DPadPowerIcons.PowerBtm";
    DPadIconBottom.FlashWhenTextChanges = TRUE;
    DPadIconRight = SFXGUIValue_HUDPowerIcon(GetVariableObject("DPadMap.DPadPowerIcons.PowerRight", Class'SFXGUIValue_HUDPowerIcon'));
    DPadIconRight.sPath = "DPadMap.DPadPowerIcons.PowerRight";
    DPadIconRight.FlashWhenTextChanges = TRUE;
    CenterIconLeft = SFXGUIValue_HUDPowerIcon(GetVariableObject("PowerMapAnimation.PowerMap.Power1", Class'SFXGUIValue_HUDPowerIcon'));
    CenterIconLeft.sPath = "PowerMapAnimation.PowerMap.Power1";
    CenterIconCenter = SFXGUIValue_HUDPowerIcon(GetVariableObject("PowerMapAnimation.PowerMap.Power2", Class'SFXGUIValue_HUDPowerIcon'));
    CenterIconCenter.sPath = "PowerMapAnimation.PowerMap.Power2";
    CenterIconRight = SFXGUIValue_HUDPowerIcon(GetVariableObject("PowerMapAnimation.PowerMap.Power3", Class'SFXGUIValue_HUDPowerIcon'));
    CenterIconRight.sPath = "PowerMapAnimation.PowerMap.Power3";
    CountdownText = GetVariableObject("timerText.timerTextPulse.timerTextMC.timerText");
    ObjectiveBar = GetVariableObject("ObjectiveBar.objectiveBar");
    ObjectiveBar.GetObject("bar.BoostAnim").SetVisible(FALSE);
    ObjectiveText = GetVariableObject("ObjectiveBar.objectiveBar.objectiveText");
    ObjectiveCircleText = GetVariableObject("ObjectiveCircles.objectiveCircles.objectiveText");
    ObjectiveCircles[0].MovieClip = GetVariableObject("ObjectiveCircles.objectiveCircles.TargetCircle1");
    ObjectiveCircles[1].MovieClip = GetVariableObject("ObjectiveCircles.objectiveCircles.TargetCircle2");
    ObjectiveCircles[2].MovieClip = GetVariableObject("ObjectiveCircles.objectiveCircles.TargetCircle3");
    ObjectiveCircles[3].MovieClip = GetVariableObject("ObjectiveCircles.objectiveCircles.TargetCircle4");
    CenterProgressBar = GetVariableObject("ProgressBar.progressBar");
    SpectatorModeDescription = GetVariableObject("SpectatorMode.SpectatorModeAnim.txtField_info");
    InitTickerMovie(0);
    InitTickerMovie(1);
    InitTickerMovie(2);
    InitTickerMovie(3);
    SetObjectiveText($0);
}
public event function Update(float fDeltaT)
{
    local BioPlayerController PC;
    local bool bSpectator;
    local bool bDying;
    local bool bInPauseMenu;
    local bool bShowHUD;
    local bool bUpdateHUD;
    
    PC = BioPlayerController(GetPC());
    bSpectator = PC.GameModeManager2.IsActive(19);
    bDying = PC.GameModeManager2.IsActive(20);
    bInPauseMenu = PC.GameModeManager2.IsActive(9);
    bShowHUD = !bInPauseMenu && ((PC.GameModeManager2.ShouldShowHUD() || bSpectator == TRUE) || bDying == TRUE);
    bUpdateHUD = bShowHUD || bInPauseMenu;
    if (bShowHUD)
    {
        if (!GetVisible())
        {
            SetVisible(TRUE);
        }
        if (!bSpectator)
        {
            if (m_bSpectatorHUDVisible)
            {
                AS_HideSpectatorHUD();
                ClearTickerEntries();
                m_bSpectatorHUDVisible = FALSE;
            }
            if (!bDying)
            {
                SetPowersVisible(TRUE, TRUE);
                if (!DPadVisible)
                {
                    ShowDPadPowerIcons(FALSE);
                }
            }
            else
            {
                SetPowersVisible(FALSE, TRUE);
            }
        }
        else
        {
            if (!m_bSpectatorHUDVisible)
            {
                ShowSpectatorHUD();
                ClearTickerEntries();
                m_bSpectatorHUDVisible = TRUE;
            }
            HideDPadPowerIcons(TRUE);
            SetPowersVisible(FALSE, TRUE);
        }
    }
    else if (GetVisible())
    {
        SetVisible(FALSE);
    }
    if (bUpdateHUD)
    {
        if (!bSpectator)
        {
            UpdateDPad(fDeltaT);
            UpdateCenterPowerIcons(fDeltaT);
            UpdateTickers(fDeltaT);
        }
        UpdateCountdownTimer(fDeltaT);
        UpdateCenterProgressBar(fDeltaT);
        UpdateObjectiveCircles(fDeltaT);
    }
    initPCPowers();
}
private final function initPCPowers()
{
    local SFXGUIInteraction oGM;
    local SFXSFHandler_PCPowerWheel oPowerWheel;
    local BioPlayerController BPC;
    local int i;
    local SFXPowerCustomActionBase oPower;
    
    if (!PCPowersInitialized)
    {
        BPC = BioPlayerController(GetPC());
        oGM = Class'SFXGUIInteraction'.static.GetInstance();
        oPowerWheel = SFXSFHandler_PCPowerWheel(oGM.GetMovie(BPC, oGM.MovieTag_PowerWheel));
        if ((oGM == None || oPowerWheel == None) || BPC == None)
        {
            return;
        }
        for (i = 0; i < oPowerWheel.m_aPowerIcons.Length; i++)
        {
            oPower = oPowerWheel.m_aPowerIcons[i].pPower;
            if (oPower != None)
            {
                SFXPawn_Player(GetPC().Pawn).AutoMap();
                PCPowersInitialized = TRUE;
                return;
            }
        }
    }
}
public event function OnClose()
{
    local SFXPawn_Player oPlayer;
    
    oPlayer = SFXPawn_Player(GetPC().Pawn);
    DPadIconTop.Cleanup();
    DPadIconTop = None;
    DPadIconLeft.Cleanup();
    DPadIconLeft = None;
    DPadIconBottom.Cleanup();
    DPadIconBottom = None;
    DPadIconRight.Cleanup();
    DPadIconRight = None;
    CenterIconLeft.Cleanup();
    CenterIconLeft = None;
    CenterIconCenter.Cleanup();
    CenterIconCenter = None;
    CenterIconRight.Cleanup();
    CenterIconRight = None;
    if (oPlayer != None)
    {
        oPlayer.PowerManager.UnregisterPowerReleasedCallback(OnPawnPowerUsed);
    }
    Super(SFXGUIMovie).OnClose();
}
public final function AddTickerEntry(const string sText)
{
    local int N;
    local SFXMPHUD_TickerEntry NewEntry;
    
    NewEntry.Text = sText;
    NewEntry.TimeToLive = TickerEntryDisplayTime;
    TickerItems.AddItem(NewEntry);
    while (TickerItems.Length > 4)
    {
        ResetTickerMovie(TickerItems[0].MovieIndex);
        TickerItems.Remove(0, 1);
    }
    for (N = 0; N < TickerItems.Length; ++N)
    {
        if (TickerItems[N].MovieIndex < 0)
        {
            if (AvailableTickerMovies.Length > 0)
            {
                TickerItems[N].MovieIndex = AvailableTickerMovies[0];
                AS_SetTickerText(TickerMovies[TickerItems[N].MovieIndex].TickerMovie, TickerItems[N].Text);
                AvailableTickerMovies.Remove(0, 1);
                continue;
            }
        }
    }
}
public final function CancelCountdownTimer()
{
    if (CountdownVisible)
    {
        AS_SetTimerVisible(FALSE);
        CountdownVisible = FALSE;
    }
}
public final function OnPawnPowerUsed(SFXPowerCustomAction oPower)
{
    if (oPower == None || oPower.m_oPawn == None)
    {
        return;
    }
    if (CenterIconLeft.pPower == oPower)
    {
        CenterIconLeft.PowerUsed(oPower);
    }
    else
    {
        CenterIconLeft.CheckCooldownState();
    }
    if (CenterIconCenter.pPower == oPower)
    {
        CenterIconCenter.PowerUsed(oPower);
    }
    else
    {
        CenterIconCenter.CheckCooldownState();
    }
    if (CenterIconRight.pPower == oPower)
    {
        CenterIconRight.PowerUsed(oPower);
    }
    else
    {
        CenterIconRight.CheckCooldownState();
    }
}
public final function SetObjectiveCircleProgress(int nNumComplete)
{
    local int nCircle;
    
    SetObjectiveCirclesVisible(TRUE);
    for (nCircle = 0; nCircle < nNumComplete && nCircle < 4; ++nCircle)
    {
        if (ObjectiveCircles[nCircle].Complete)
        {
            continue;
        }
        ObjectiveCircles[nCircle].MovieClip.GotoAndStopI(101);
        ObjectiveCircles[nCircle].Complete = TRUE;
    }
    for (nCircle = nCircle; nCircle < 4; ++nCircle)
    {
        if (ObjectiveCircles[nCircle].Complete)
        {
            ObjectiveCircles[nCircle].MovieClip.GotoAndStopI(1);
            ObjectiveCircles[nCircle].Complete = FALSE;
        }
    }
    CurrentObjectiveCircle = Min(nNumComplete + 1, 4) - 1;
}
public final function SetObjectiveCircleText(const string s1, const string s2, const string s3, const string s4)
{
    ObjectiveCircles[0].MovieClip.SetMemberObjectText("text", s1);
    ObjectiveCircles[1].MovieClip.SetMemberObjectText("text", s2);
    ObjectiveCircles[2].MovieClip.SetMemberObjectText("text", s3);
    ObjectiveCircles[3].MovieClip.SetMemberObjectText("text", s4);
}
public final function SetObjectiveText(stringref srObjectiveText)
{
    if (CurrentObjectiveText != srObjectiveText)
    {
        if (srObjectiveText == 0)
        {
            SetObjectiveBarVisible(FALSE);
            SetObjectiveCirclesVisible(FALSE);
        }
        CurrentObjectiveText = srObjectiveText;
        ObjectiveText.SetText(UIStrRef(CurrentObjectiveText));
        ObjectiveCircleText.SetText(UIStrRef(CurrentObjectiveText));
    }
}
public final function UpdateCountdownTimer(float fDeltaT)
{
    local string sText;
    local int Minutes;
    local int Seconds;
    
    if (!CountdownVisible)
    {
        return;
    }
    CurrentCountdownTime = FMax(0.0, CurrentCountdownTime - fDeltaT);
    Minutes = int(CurrentCountdownTime / float(60));
    Seconds = int(CurrentCountdownTime %  float(60));
    sText = ((Minutes $ ":") $ (Seconds < 10 ? "0" : "")) $ Seconds;
    SetTimerText(sText);
    if (CurrentCountdownTime <= CountdownWarningTime)
    {
        if (!CountdownInWarning)
        {
            AS_SetTimerPulse(TRUE);
            CountdownInWarning = TRUE;
        }
    }
    else if (CountdownInWarning)
    {
        AS_SetTimerPulse(FALSE);
        CountdownInWarning = FALSE;
    }
}
public final function AcquireNewTickerEntries()
{
    local int nEvent;
    local SFXMPEventTicker oSrc;
    
    oSrc = SFXGRI(oWorldInfo.GRI).GetEventTicker();
    if (oSrc == None)
    {
        return;
    }
    for (nEvent = 0; nEvent < oSrc.Events.Length; ++nEvent)
    {
        AddTickerEntry(oSrc.Events[nEvent]);
    }
    oSrc.ClearTicker();
}
public final function AS_DisplaySubareaText(string sSubareaText)
{
    ActionScriptVoid("DisplaySubareaText");
}
public final function AS_FadeTickerBar(GFxValue barMC)
{
    ActionScriptVoid("FadeTickerBar");
}
public final function AS_HideSpectatorHUD()
{
    ActionScriptVoid("HideSpectatorHUD");
}
public final function AS_ResetTickerBar(GFxValue barMC)
{
    ActionScriptVoid("ResetTickerBar");
}
public final function AS_SetDPadVisible(bool bVisible, bool bSkipTransition)
{
    ActionScriptVoid("SetDPadVisible");
}
public final function AS_SetObjectiveVisible(bool bVisible, bool bCircleObjectives)
{
    ActionScriptVoid("SetObjectiveVisible");
}
public final function AS_SetPowerMapVisible(bool bVisible, bool bSkipTransition)
{
    ActionScriptVoid("SetPowerMapVisible");
}
public final function AS_SetProgressBarVisible(bool bVisible, bool bSkipTransition)
{
    ActionScriptVoid("SetProgressBarVisible");
}
public final function AS_SetTickerText(GFxValue barMC, const string sText)
{
    ActionScriptVoid("SetTickerText");
}
public final function AS_SetTimerPulse(bool bPulse)
{
    ActionScriptVoid("SetTimerPulse");
}
public final function AS_SetTimerVisible(bool bVisible)
{
    ActionScriptVoid("SetTimerVisible");
}
public final function AS_ShowSpectatorHUD()
{
    ActionScriptVoid("ShowSpectatorHUD");
}
public final function ClearTickerEntries()
{
    local int nTicker;
    
    TickerItems.Length = 0;
    for (nTicker = 0; nTicker < 4; ++nTicker)
    {
        ResetTickerMovie(nTicker);
    }
}
public final function DisplaySubareaText(stringref NewSubareaText)
{
    if (CurrentSubareaText != NewSubareaText)
    {
        CurrentSubareaText = NewSubareaText;
        AS_DisplaySubareaText(GetUIString(CurrentSubareaText));
    }
}
public final function HideCenterProgressBar()
{
    if (CenterBarVisible)
    {
        AS_SetProgressBarVisible(FALSE, FALSE);
        CenterBarVisible = FALSE;
    }
}
public final function HideDPadPowerIcons(optional bool bSkipTransition = FALSE)
{
    if (DPadVisible)
    {
        AS_SetDPadVisible(FALSE, bSkipTransition);
        DPadIconTop.MadeVisible(FALSE);
        DPadIconLeft.MadeVisible(FALSE);
        DPadIconRight.MadeVisible(FALSE);
        DPadIconBottom.MadeVisible(FALSE);
        DPadVisible = FALSE;
    }
}
public final function InitializeCenterPowerIcons()
{
    local SFXPawn_Player oPlayer;
    local SFXPowerCustomActionBase oPower;
    local SFXPowerManager PowerManager;
    local SFXCharacterClass PlayerClass;
    local BioPlayerInput oPlayerInput;
    local bool bIconVisible;
    
    if (GetPC() == None)
    {
        return;
    }
    oPlayer = SFXPawn_Player(GetPC().Pawn);
    if (oPlayer == None)
    {
        return;
    }
    oPlayerInput = BioPlayerInput(GetPC().PlayerInput);
    if (oPlayerInput == None)
    {
        return;
    }
    PowerManager = oPlayer.PowerManager;
    PlayerClass = oPlayer.PlayerClass;
    if (PowerManager == None || PlayerClass == None)
    {
        return;
    }
    oPower = PowerManager.GetPowerByClass(PlayerClass.SquadScreenPowerOrder[1]);
    CenterIconLeft.SetPower(oPower);
    CenterIconLeft.UpdateDisplay();
    if (IsTriggerSouthpaw())
    {
        oPlayerInput.m_nmMappedPower2 = oPower == None ? 'None' : oPower.Class.Name;
    }
    else
    {
        oPlayerInput.m_nmMappedPower = oPower == None ? 'None' : oPower.Class.Name;
    }
    bIconVisible = (oPower != None && oPower.IsEnabled()) && oPower.Rank > float(0);
    CenterIconLeft.SetVisible(bIconVisible);
    GetVariableObject("PowerMapAnimation.PowerMap.ControllerIconLeft").SetVisible(bIconVisible);
    oPower = PowerManager.GetPowerByClass(PlayerClass.SquadScreenPowerOrder[0]);
    CenterIconCenter.SetPower(oPower);
    CenterIconCenter.UpdateDisplay();
    oPlayerInput.m_nmMappedPower3 = oPower == None ? 'None' : oPower.Class.Name;
    bIconVisible = (oPower != None && oPower.IsEnabled()) && oPower.Rank > float(0);
    CenterIconCenter.SetVisible(bIconVisible);
    GetVariableObject("PowerMapAnimation.PowerMap.ControllerIconCenter").SetVisible(bIconVisible);
    oPower = PowerManager.GetPowerByClass(PlayerClass.SquadScreenPowerOrder[2]);
    CenterIconRight.SetPower(oPower);
    CenterIconRight.UpdateDisplay();
    if (IsTriggerSouthpaw())
    {
        oPlayerInput.m_nmMappedPower = oPower == None ? 'None' : oPower.Class.Name;
    }
    else
    {
        oPlayerInput.m_nmMappedPower2 = oPower == None ? 'None' : oPower.Class.Name;
    }
    bIconVisible = (oPower != None && oPower.IsEnabled()) && oPower.Rank > float(0);
    CenterIconRight.SetVisible(bIconVisible);
    GetVariableObject("PowerMapAnimation.PowerMap.ControllerIconRight").SetVisible(bIconVisible);
}
public final function InitializeDPadPowerIcons()
{
    local SFXPawn_Player oPlayer;
    local SFXPowerCustomActionMP_Consumable Consumable;
    
    oPlayer = SFXPawn_Player(GetPC().Pawn);
    if (oPlayer == None)
    {
        return;
    }
    Consumable = SFXPowerCustomActionMP_Consumable(oPlayer.PowerManager.GetPowerByClass(Class'SFXPowerCustomActionMP_Consumable_Rocket'));
    if (Consumable != None)
    {
        DPadIconTop.SetPower(Consumable);
        DPadIconTop.FlashWhenTextChanges = TRUE;
        DPadIconTop.UpdateDisplay();
    }
    Consumable = SFXPowerCustomActionMP_Consumable(oPlayer.PowerManager.GetPowerByClass(Class'SFXPowerCustomActionMP_Consumable_Shield'));
    if (Consumable != None)
    {
        DPadIconRight.SetPower(Consumable);
        DPadIconRight.FlashWhenTextChanges = TRUE;
        DPadIconRight.UpdateDisplay();
    }
    Consumable = SFXPowerCustomActionMP_Consumable(oPlayer.PowerManager.GetPowerByClass(Class'SFXPowerCustomActionMP_Consumable_Ammo'));
    if (Consumable != None)
    {
        DPadIconLeft.SetPower(Consumable);
        DPadIconLeft.FlashWhenTextChanges = TRUE;
        DPadIconLeft.UpdateDisplay();
    }
    Consumable = SFXPowerCustomActionMP_Consumable(oPlayer.PowerManager.GetPowerByClass(Class'SFXPowerCustomActionMP_Consumable_Revive'));
    if (Consumable != None)
    {
        DPadIconBottom.SetPower(Consumable);
        DPadIconBottom.FlashWhenTextChanges = TRUE;
        DPadIconBottom.UpdateDisplay();
    }
}
public final function InitTickerMovie(int N)
{
    TickerMovies[N].TickerMovie = GetVariableObject("TickerBar" $ N + 1);
    TickerMovies[N].Id = N + 1;
    TickerMovies[N].TickerMovie.SetNumber("ID", float(N + 1));
    AvailableTickerMovies.AddItem(N);
}
public final function OnTickerFadeComplete(int nTickerID)
{
    local int nIndex;
    
    for (nIndex = 0; nIndex < TickerItems.Length; ++nIndex)
    {
        if (TickerMovies[TickerItems[nIndex].MovieIndex].Id == nTickerID)
        {
            ResetTickerMovie(TickerItems[nIndex].MovieIndex);
            TickerItems.Remove(nIndex, 1);
            break;
        }
    }
}
public final function PlayerIsFinishedWithObjective()
{
    PlayersCurrentlyUsingObjective = Max(0, PlayersCurrentlyUsingObjective - 1);
    if (PlayersCurrentlyUsingObjective == 0)
    {
        SetCurrentObjectiveCircleCompletion(0.0);
    }
}
public final function PlayerIsUsingObjectiveWithTime(float fTime)
{
    if (PlayersCurrentlyUsingObjective == 0)
    {
        CurrentObjectiveTime = fTime;
        CurrentObjectiveTimeRemaining = fTime;
    }
    ++PlayersCurrentlyUsingObjective;
}
public final function ResetTickerMovie(int nIndex)
{
    TickerMovies[nIndex].CurrentSlot = 0;
    AS_ResetTickerBar(TickerMovies[nIndex].TickerMovie);
    if (AvailableTickerMovies.Find(nIndex) == -1)
    {
        AvailableTickerMovies.AddItem(nIndex);
    }
}
public final function SetBoostAnimOn(bool bTurnOn)
{
    if (BoostAnimActive != bTurnOn)
    {
        ObjectiveBar.GetObject("bar.BoostAnim").SetVisible(bTurnOn);
        BoostAnimActive = bTurnOn;
    }
}
public final function SetCurrentObjectiveCircleCompletion(float fPercentComplete)
{
    if (CurrentObjectiveCircle < 0 || CurrentObjectiveCircle >= 4)
    {
        return;
    }
    fPercentComplete = FClamp(fPercentComplete, 0.0, 1.0);
    if (ObjectiveCircles[CurrentObjectiveCircle].PercentComplete != fPercentComplete)
    {
        ObjectiveCircles[CurrentObjectiveCircle].MovieClip.GotoAndStopI(int(fPercentComplete * float(100)) + 1);
        ObjectiveCircles[CurrentObjectiveCircle].PercentComplete = fPercentComplete;
    }
}
public final function SetObjectiveBarProgress(float fPct, optional bool bBoostAnim = FALSE)
{
    local int nFrame;
    
    fPct = FClamp(fPct, 0.0, 1.0);
    nFrame = int(fPct * float(100)) + 1;
    if (CurrentObjectiveText != 0)
    {
        SetObjectiveBarVisible(TRUE);
    }
    ObjectiveBar.GotoAndStopI(nFrame);
    CurrentObjectiveFrame = nFrame;
    SetBoostAnimOn(bBoostAnim);
}
public final function SetObjectiveBarVisible(bool bVisible)
{
    if (bVisible != ObjectiveBarVisible)
    {
        ObjectiveBarVisible = bVisible;
        SetObjectiveCirclesVisible(FALSE);
        AS_SetObjectiveVisible(bVisible, FALSE);
    }
}
public final function SetObjectiveCirclesVisible(bool bVisible)
{
    if (bVisible != ObjectiveCirclesVisible)
    {
        ObjectiveCirclesVisible = bVisible;
        SetObjectiveBarVisible(FALSE);
        AS_SetObjectiveVisible(bVisible, TRUE);
        if (!bVisible)
        {
            PlayersCurrentlyUsingObjective = 0;
        }
    }
}
public final function SetPowersVisible(bool bVisible, optional bool bSkipTransition = FALSE)
{
    if (CenterPowersVisible != bVisible)
    {
        AS_SetPowerMapVisible(bVisible, bSkipTransition);
        CenterPowersVisible = bVisible;
    }
}
public final function SetTimerText(const out string sText)
{
    if (CurrentTimerText == sText)
    {
        return;
    }
    CountdownText.SetText(sText);
}
public final function ShowCenterProgressBar(float fCenterBarTime)
{
    CenterBarTime = fCenterBarTime;
    CenterBarRemainingTime = fCenterBarTime;
    if (!CenterBarVisible)
    {
        AS_SetProgressBarVisible(TRUE, FALSE);
        CenterBarVisible = TRUE;
    }
}
public final function ShowDPadPowerIcons(optional bool bSkipTransition = FALSE)
{
    DPadElapsedDisplayTime = 0.0;
    if (!Initialized)
    {
        return;
    }
    if (!DPadVisible)
    {
        AS_SetDPadVisible(TRUE, bSkipTransition);
        DPadIconTop.MadeVisible(TRUE);
        DPadIconLeft.MadeVisible(TRUE);
        DPadIconRight.MadeVisible(TRUE);
        DPadIconBottom.MadeVisible(TRUE);
        DPadVisible = TRUE;
    }
}
public final function ShowSpectatorHUD()
{
    SpectatorModeDescription.SetText(string(oWorldInfo.IsConsoleBuild() ? srSpectatorHUDDescriptionConsole : srSpectatorHUDDescriptionPC));
    AS_ShowSpectatorHUD();
}
public final function StartCountdownTimer(float fTime, float fWarningTime)
{
    CurrentCountdownTime = fTime;
    CountdownWarningTime = fWarningTime;
    if (!CountdownVisible)
    {
        AS_SetTimerVisible(TRUE);
        CountdownVisible = TRUE;
    }
}
public final function UpdateCenterPowerIcons(float fDeltaT)
{
    if (!Initialized)
    {
        return;
    }
    CenterIconLeft.UpdateInfoText();
    CenterIconLeft.TickCooldown();
    CenterIconCenter.UpdateInfoText();
    CenterIconCenter.TickCooldown();
    CenterIconRight.UpdateInfoText();
    CenterIconRight.TickCooldown();
}
public final function UpdateCenterProgressBar(float fDeltaT)
{
    local float fPct;
    local int nFrame;
    
    if (!CenterBarVisible)
    {
        return;
    }
    CenterBarRemainingTime -= fDeltaT;
    fPct = 1.0 - CenterBarRemainingTime / CenterBarTime;
    nFrame = Clamp(int(fPct * float(100)), 1, 101);
    CenterProgressBar.GotoAndStopI(nFrame);
}
public final function UpdateDPad(float fDeltaT)
{
    if (DPadFadeOut && DPadVisible)
    {
        DPadElapsedDisplayTime += fDeltaT;
        if (DPadElapsedDisplayTime >= DPadDisplayTime)
        {
            HideDPadPowerIcons();
        }
    }
}
public final function UpdateDPadPowerIcons()
{
    if (!Initialized)
    {
        return;
    }
    if (!DPadVisible)
    {
        ShowDPadPowerIcons();
    }
    DPadElapsedDisplayTime = 0.0;
    DPadIconTop.UpdateInfoText();
    DPadIconLeft.UpdateInfoText();
    DPadIconBottom.UpdateInfoText();
    DPadIconRight.UpdateInfoText();
}
public final function UpdateObjectiveCircles(float fDeltaT)
{
    local float fPctDone;
    
    if (!ObjectiveCirclesVisible)
    {
        return;
    }
    if ((CurrentObjectiveTime <= 0.0 || CurrentObjectiveTimeRemaining <= 0.0) || PlayersCurrentlyUsingObjective <= 0)
    {
        return;
    }
    CurrentObjectiveTimeRemaining -= fDeltaT;
    fPctDone = 1.0 - CurrentObjectiveTimeRemaining / CurrentObjectiveTime;
    SetCurrentObjectiveCircleCompletion(fPctDone);
}
public final function UpdateTickers(float fDeltaT)
{
    local int nTicker;
    local int nMovie;
    local int nCurrentDisplaySlot;
    
    TimeToNextTickerUpdate -= fDeltaT;
    if (TimeToNextTickerUpdate <= float(0))
    {
        AcquireNewTickerEntries();
        TimeToNextTickerUpdate = TickerUpdateTime;
    }
    nCurrentDisplaySlot = TickerItems.Length;
    for (nTicker = 0; nTicker < TickerItems.Length && nTicker < 4; ++nTicker)
    {
        TickerItems[nTicker].TimeToLive -= fDeltaT;
        nMovie = TickerItems[nTicker].MovieIndex;
        if (nMovie >= 0 && nMovie < 4)
        {
            if (TickerItems[nTicker].TimeToLive <= float(0))
            {
                if (TickerItems[nTicker].Fading == FALSE)
                {
                    AS_FadeTickerBar(TickerMovies[nMovie].TickerMovie);
                    TickerItems[nTicker].Fading = TRUE;
                }
            }
            if (TickerMovies[nMovie].CurrentSlot != nCurrentDisplaySlot)
            {
                TickerMovies[nMovie].TickerMovie.GotoAndPlay("slot" $ nCurrentDisplaySlot);
                TickerMovies[nMovie].CurrentSlot = nCurrentDisplaySlot;
            }
            --nCurrentDisplaySlot;
        }
    }
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    DPadDisplayTime = 10.0
    TickerEntryDisplayTime = 8.0
    TickerUpdateTime = 0.5
    srSpectatorHUDDescriptionPC = $618884
    srSpectatorHUDDescriptionConsole = $618885
}