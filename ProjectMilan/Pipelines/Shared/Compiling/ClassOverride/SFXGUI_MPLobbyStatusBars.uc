Class SFXGUI_MPLobbyStatusBars extends SFXGUIMovieMP
    config(UI);

// Variables
var config stringref srWaitingForMatchToStart;
var config stringref srWaitingForSingleOther;
var config stringref srWaitingForOthers;
var config stringref srWaitingForYou;
var config stringref srWaitingForYouAndSingleOther;
var config stringref srWaitingForYouAndOthers;
var config stringref srPressButtonToReady;
var config stringref srPCReadyButton;
var bool m_bShouldShowStatusBar;
var bool m_bShouldShowMatchInfo;
var bool m_bCanSetReady;

// Functions
// MILAN CHANGE DropTheSquid 12/16/2023
// adding this so we can handle the input changing
public event function HandleButtonRefresh(bool usingGamepad)
{
    Super(SFXGUIMovie).HandleButtonRefresh(usingGamepad);
    Refresh();
}
// END MILAN
public event function OnStart()
{
    Super(SFXGUIMovie).OnStart();
}
public event function Update(float fDeltaT)
{
    local bool bShouldShowStatusBar;
    local bool bShouldShowMatchInfo;
    local bool bCanSetReady;
    local bool bDirty;
    
    Super(SFXGUIMovie).Update(fDeltaT);
    bDirty = FALSE;
    bShouldShowStatusBar = ShouldShowStatusBar();
    if (bShouldShowStatusBar != m_bShouldShowStatusBar)
    {
        bDirty = TRUE;
        m_bShouldShowStatusBar = bShouldShowStatusBar;
    }
    bShouldShowMatchInfo = ShouldShowMatchInfo();
    if (bShouldShowMatchInfo != m_bShouldShowMatchInfo)
    {
        bDirty = TRUE;
        m_bShouldShowMatchInfo = bShouldShowMatchInfo;
    }
    bCanSetReady = GetLobbyFlow().CanSetReady();
    if (bCanSetReady != m_bCanSetReady)
    {
        bDirty = TRUE;
        m_bCanSetReady = bCanSetReady;
    }
    if (bDirty)
    {
        Refresh();
    }
}
public event function OnClose()
{
    Super(SFXGUIMovie).OnClose();
}
public final function Refresh()
{
    AS_Refresh();
}
public final function bool ShouldShowMatchInfo()
{
    local SFXGUIInteraction GUI;
    local SFXGUIMovie LobbyScreen;
    local bool bInLobbyScreen;
    
    GUI = Class'SFXGUIInteraction'.static.GetInstance();
    LobbyScreen = GUI.GetMovie(GetPC(), GUI.MovieTag_MPNewLobby);
    bInLobbyScreen = LobbyScreen != None && !LobbyScreen.m_bPendingClose;
    return bInLobbyScreen;
}
public final function bool ShouldShowStatusBar()
{
    local SFXGUIInteraction GUI;
    local SFXGUIMovie MatchResultsScreen;
    local SFXGUIMovie OptionsScreen;
    local bool bIsConnected;
    
    GUI = Class'SFXGUIInteraction'.static.GetInstance();
    MatchResultsScreen = GUI.GetMovie(GetPC(), GUI.MovieTag_MPMatchResults);
    OptionsScreen = GUI.GetMovie(GetPC(), GUI.MovieTag_Options);
    bIsConnected = IsMPGame();
    return (bIsConnected && MatchResultsScreen == None) && OptionsScreen == None;
}
public final function AS_Refresh()
{
    ActionScriptVoid("screen.Refresh");
}
public final function int GetNumReadyPlayers()
{
    return GetLobbyGRI().GetNumReadyPlayers();
}
public final function string GetPlayerStatus()
{
    local string StatusString;
    local int NumPlayers;
    local int NumReadyPlayers;
    local int NumWaitingOn;
    local SFXGRIMP_Lobby GRI;
    
    GRI = GetLobbyGRI();
    if (GRI == None)
    {
        return StatusString;
    }
    if (GRI.MatchTimerInfo.bMatchStartTimerRunning)
    {
        StatusString = GRI.GetLobbyStatusString();
    }
    else
    {
        NumPlayers = GRI.GetNumPlayers();
        NumReadyPlayers = GRI.GetNumReadyPlayers();
        if (NumReadyPlayers == NumPlayers)
        {
            StatusString = UIStrRef(srWaitingForMatchToStart);
        }
        else if (GetPRIMP().ReadyInLobby)
        {
            NumWaitingOn = NumPlayers - NumReadyPlayers;
            if (NumWaitingOn == 1)
            {
                StatusString = GetUIString(srWaitingForSingleOther);
            }
            else
            {
                SetCustomToken(0, string(NumWaitingOn));
                StatusString = GetTokenisedString(srWaitingForOthers);
            }
        }
        else
        {
            if (NumReadyPlayers == NumPlayers - 1)
            {
                StatusString = GetUIString(srWaitingForYou);
            }
            else
            {
                NumWaitingOn = (NumPlayers - NumReadyPlayers) - 1;
                if (NumWaitingOn == 1)
                {
                    StatusString = GetUIString(srWaitingForYouAndSingleOther);
                }
                else
                {
                    SetCustomToken(0, string(NumWaitingOn));
                    StatusString = GetTokenisedString(srWaitingForYouAndOthers);
                }
            }
            if (GetLobbyFlow().CanSetReady())
            {
                SetCustomToken(0, GetReadyButtonString());
                StatusString @= GetTokenisedString(srPressButtonToReady);
            }
        }
    }
    return StatusString;
}
public final function string GetReadyButtonString()
{
	// MILAN Change DropTheSquid 12/16/2023
	// have this go off of current input mode rather than platform
    if (bUsingGamepad)
	// End Milan
    {
        return "[XBoxB_Btn_RT]";
    }
    else
    {
        return ("[" $ GetUIString(srPCReadyButton)) $ "]";
    }
}
public final function bool IsReady()
{
    return GetPRIMP().ReadyInLobby;
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    srWaitingForMatchToStart = $681598
    srWaitingForSingleOther = $682012
    srWaitingForOthers = $681601
    srWaitingForYou = $681599
    srWaitingForYouAndSingleOther = $682013
    srWaitingForYouAndOthers = $681600
    srPressButtonToReady = $686987
    srPCReadyButton = $174820
}
