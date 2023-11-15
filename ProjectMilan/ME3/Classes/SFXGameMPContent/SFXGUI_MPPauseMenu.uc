Class SFXGUI_MPPauseMenu extends SFXGUIMovie
    config(UI);

// Types
struct PauseMenuScoreData 
{
    var string DisplayName;
    var int PRIIndex;
    var int Score;
};

// Variables
var config stringref srConfirm;
var config stringref srCancel;
var config stringref srExitToLobbyConfirmMessage;
var config stringref srWaveNumber;
var config stringref srMapText;
var config stringref srFactionText;
var config stringref srChallengeText;
var bool m_bShouldAnimate;

// Functions
public function Exit()
{
    Close();
}
public event function OnStart()
{
    Super.OnStart();
    SetGameMode(TRUE, 9);
    PlayGuiSound('MPPauseMenuStart');
}
public final function ShowGamercard(int ListIndex)
{
    local SFXPRIMP PRI;
    local WorldInfo CurrWorld;
    local int LocalUserNum;
    local array<PauseMenuScoreData> ScoreData;
    local int PRIIndex;
    
    CurrWorld = Class'Engine'.static.GetCurrentWorldInfo();
    ScoreData = GetScoreData();
    PRIIndex = ScoreData[ListIndex].PRIIndex;
    PRI = SFXPRIMP(CurrWorld.GRI.PRIArray[PRIIndex]);
    if (PRI != None)
    {
        LocalUserNum = LocalPlayer(GetPC().Player).ControllerId;
        Class'SFXOnlineSubsystem'.static.GetOnlineSubsystem().GetComponentPlatform().ShowGamerCardUI(byte(LocalUserNum), PRI.UniqueId);
    }
}
public event function OnClose()
{
    Super.OnClose();
    SetGameMode(FALSE, 9);
    PlayGuiSound('MPPauseMenuExit');
}
public final function ConfirmExitPopupCallback(bool bAPressed, int nContext)
{
    local SFXOnlineSubsystem oOnlineSubsystem;
    local ISFXOnlineComponentGame oOnlineGame;
    
    if (bAPressed)
    {
        PlayGuiSound('MPPauseMenuExitMatchConfirm');
        Close();
        oOnlineSubsystem = Class'SFXOnlineSubsystem'.static.GetOnlineSubsystem();
        if (oOnlineSubsystem != None)
        {
            oOnlineGame = oOnlineSubsystem.GetComponentGame();
            if (oOnlineGame != None)
            {
                oOnlineGame.LeaveGame();
            }
        }
        GetPC().ConsoleCommand("Disconnect");
    }
}
public function ExitMatch()
{
    local BioSFHandler_MessageBox messageBox;
    local BioMessageBoxOptionalParams Params;
    
    messageBox = GetSFXUIController().CreateMessageBox(GetPC());
    messageBox.SetInputDelegate(ConfirmExitPopupCallback);
    Params.srAText = srConfirm;
    Params.srBText = srCancel;
    PlayGuiSound('MPPauseMenuExitMatch');
    messageBox.DisplayMessageBox(srExitToLobbyConfirmMessage, Params);
}
public final function string GetChallengeText()
{
    local WorldInfo CurrWorld;
    local int ChallengeTypeIndex;
    local string TranslatedString;
    
    CurrWorld = Class'Engine'.static.GetCurrentWorldInfo();
    ChallengeTypeIndex = SFXGRIMP(CurrWorld.GRI).GetChallengeTypeIndex();
    ClearCustomTokens();
    SetCustomToken(0, string(Class'SFXOnlineGameSettings'.default.ChallengeTypes[ChallengeTypeIndex].Name));
    TranslatedString = GetUIString(srChallengeText, TRUE);
    ClearCustomTokens();
    return TranslatedString;
}
public final function string GetFactionText()
{
    local WorldInfo CurrWorld;
    local int EnemyWaveTypeID;
    local int Index;
    local string TranslatedString;
    
    CurrWorld = Class'Engine'.static.GetCurrentWorldInfo();
    EnemyWaveTypeID = SFXGRIMP(CurrWorld.GRI).GetEnemyWaveTypeID();
    Index = Class'SFXOnlineGameSettings'.default.EnemyTypes.Find('Id', EnemyWaveTypeID);
    ClearCustomTokens();
    SetCustomToken(0, string(Class'SFXOnlineGameSettings'.default.EnemyTypes[Index].Name));
    TranslatedString = GetUIString(srFactionText, TRUE);
    ClearCustomTokens();
    return TranslatedString;
}
public final function string GetMapText()
{
    local WorldInfo CurrWorld;
    local string CurrentMap;
    local int Index;
    local string TranslatedString;
    
    CurrWorld = Class'Engine'.static.GetCurrentWorldInfo();
    CurrentMap = CurrWorld.GetMapName();
    Index = Class'SFXOnlineGameSettings'.default.MasterMapList.Find('PackageName', CurrentMap);
    ClearCustomTokens();
    SetCustomToken(0, string(Class'SFXOnlineGameSettings'.default.MasterMapList[Index].PrettyName));
    TranslatedString = GetUIString(srMapText, TRUE);
    ClearCustomTokens();
    return TranslatedString;
}
public final function array<PauseMenuScoreData> GetScoreData()
{
    local SFXPRIMP PRI;
    local WorldInfo CurrWorld;
    local int idx;
    local PauseMenuScoreData CurrData;
    local array<PauseMenuScoreData> AllScoreData;
    
    CurrWorld = Class'Engine'.static.GetCurrentWorldInfo();
    for (idx = 0; idx < CurrWorld.GRI.PRIArray.Length; ++idx)
    {
        PRI = SFXPRIMP(CurrWorld.GRI.PRIArray[idx]);
        if (PRI != None && PRI.IsPlayer())
        {
            CurrData.PRIIndex = idx;
            CurrData.DisplayName = PRI.PlayerName;
            CurrData.Score = int(PRI.GetTotalPoints());
            AllScoreData.AddItem(CurrData);
        }
    }
    AllScoreData.Sort(SortScoreData);
    return AllScoreData;
}
public final function string GetWaveNumber()
{
    local int WaveNumber;
    local string TranslatedString;
    local WorldInfo CurrWorld;
    
    CurrWorld = Class'Engine'.static.GetCurrentWorldInfo();
    WaveNumber = SFXGRI(CurrWorld.GRI).WaveCoordinator.GetFriendlyCurrentWaveNumber();
    ClearCustomTokens();
    SetCustomToken(0, string(WaveNumber));
    TranslatedString = GetUIString(srWaveNumber, TRUE);
    ClearCustomTokens();
    return TranslatedString;
}
public static final function OnMPOptionsClosed()
{
    local PlayerController PC;
    
    PC = BioWorldInfo(Class'Engine'.static.GetCurrentWorldInfo()).GetLocalPlayerController();
    Class'SFXGUIInteraction'.static.GetInstance().HideMPOptions(PC);
    Class'SFXGUIInteraction'.static.GetInstance().ShowMPPauseMenu(PC, FALSE);
}
public function OpenIngamePropertyEditor()
{
    BioPlayerController(GetPC()).ConsoleCommand("StartIngamePropertyEditor 1");
}
public function OpenOptions()
{
    Close();
    GetSFXUIController().ShowMPOptions(GetPC(), Class'SFXGUI_MPPauseMenu'.static.OnMPOptionsClosed);
}
public function bool ShouldAnimate()
{
    return m_bShouldAnimate;
}
public final function int SortScoreData(PauseMenuScoreData A, PauseMenuScoreData B)
{
    return A.Score >= B.Score ? 0 : -1;
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    srConfirm = $153362
    srCancel = $153363
    srExitToLobbyConfirmMessage = $641884
    srWaveNumber = $705853
    srMapText = $705854
    srFactionText = $706060
    srChallengeText = $706061
    m_bShouldAnimate = TRUE
    m_bFocusOnStart = TRUE
}