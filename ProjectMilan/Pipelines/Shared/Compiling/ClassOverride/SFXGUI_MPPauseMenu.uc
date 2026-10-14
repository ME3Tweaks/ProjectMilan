// Source: ME3, Patch_SFXGUI_MPPauseMenu
// Decompiled 10/5/2026 5:01:22 PM
Class SFXGUI_MPPauseMenu extends SFXGUIMovie
    config(UI);

struct PauseMenuScoreData
{
    var string DisplayName;
    var int PRIIndex;
    var int Score;
    // MILAN CHANGE - Mgamerz - 2026-10-10
    // Extra columns and vote state for the scrolling in-match player list.
    var string Ping;
    var int KickVotes;
    var int ActivePlayers;
    var bool HasVoted;
    var bool CanVote;
    var bool IsLocal;
    // END MILAN CHANGE
};

// MILAN CHANGE - Mgamerz - 2026-10-10
// Scaleform receives already localized text. Keep every visible label in TLK.
struct PauseMenuTextData
{
    var string NameLabel;
    var string ScoreLabel;
    var string PingLabel;
    var string VoteLabel;
    var string RemoveVoteLabel;
    var string InviteLabel;
    var string InviteHint;
    var string ScrollLabel;
};
var config stringref srPlayerNameColumn;
var config stringref srPlayerScoreColumn;
var config stringref srPlayerPingColumn;
var config stringref srHostPing;
var config stringref srPingMilliseconds;
var config stringref srMatchVoteKick;
var config stringref srMatchRemoveVote;
var config stringref srMatchInvite;
var config stringref srMatchInviteHint;
var config stringref srMatchScroll;

public final function PauseMenuTextData GetPauseMenuText()
{
    local PauseMenuTextData Text;
    Text.NameLabel = GetUIString(srPlayerNameColumn);
    Text.ScoreLabel = GetUIString(srPlayerScoreColumn);
    Text.PingLabel = GetUIString(srPlayerPingColumn);
    Text.VoteLabel = GetUIString(srMatchVoteKick);
    Text.RemoveVoteLabel = GetUIString(srMatchRemoveVote);
    Text.InviteLabel = GetUIString(srMatchInvite);
    Text.InviteHint = GetUIString(srMatchInviteHint);
    Text.ScrollLabel = GetUIString(srMatchScroll);
    return Text;
}
// END MILAN CHANGE

var config stringref srConfirm;
var config stringref srCancel;
var config stringref srExitToLobbyConfirmMessage;
var config stringref srWaveNumber;
var config stringref srMapText;
var config stringref srFactionText;
var config stringref srChallengeText;
var bool m_bShouldAnimate;

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
    if (CurrWorld == None || CurrWorld.GRI == None || ListIndex < 0 || ListIndex >= ScoreData.Length)
    {
        return;
    }
    PRIIndex = ScoreData[ListIndex].PRIIndex;
    if (PRIIndex < 0 || PRIIndex >= CurrWorld.GRI.PRIArray.Length)
    {
        return;
    }
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
// MILAN CHANGE - Mgamerz - 2026-10-10
// MilanHost intercepts this call to share the current matchmaker invite code.
// It handles an unavailable matchmaker with a short HUD hint; local matches continue.
public function InviteFriends()
{
}
// END MILAN CHANGE

// MILAN CHANGE - Mgamerz - 2026-10-10
// Rows are indexed in the score-sorted array, not in GRI.PRIArray. The host
// validates the RPC and applies the same strict-majority rule as the lobby.
public final function ToggleKickVote(int ListIndex)
{
    local array<PauseMenuScoreData> ScoreData;
    local WorldInfo CurrWorld;
    local SFXPRIMP LocalPRI;
    local SFXPRIMP TargetPRI;
    local UniqueNetId ZeroId;

    CurrWorld = Class'Engine'.static.GetCurrentWorldInfo();
    if (CurrWorld == None || CurrWorld.GRI == None || GetPC() == None)
    {
        return;
    }
    ScoreData = GetScoreData();
    if (ListIndex < 0 || ListIndex >= ScoreData.Length || !ScoreData[ListIndex].CanVote)
    {
        return;
    }
    LocalPRI = SFXPRIMP(GetPC().PlayerReplicationInfo);
    TargetPRI = SFXPRIMP(CurrWorld.GRI.PRIArray[ScoreData[ListIndex].PRIIndex]);
    if (LocalPRI == None || TargetPRI == None || LocalPRI == TargetPRI)
    {
        return;
    }
    if (LocalPRI.KickVotePlayerId == TargetPRI.UniqueId)
    {
        LocalPRI.SetKickVote(ZeroId);
    }
    else
    {
        LocalPRI.SetKickVote(TargetPRI.UniqueId);
    }
}

public final function string GetPingText(PlayerReplicationInfo PRI)
{
    if (PRI.Ping == 255)
    {
        return "--";
    }
    if (PRI.Ping == 0)
    {
        return "--";
    }
    return string(int(PRI.Ping) * 4) $ GetUIString(srPingMilliseconds);
}
// END MILAN CHANGE
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
public final function ConfirmExitPopupCallback(bool bAPressed, int nContext)
{
    local SFXOnlineSubsystem oOnlineSubsystem;
    local ISFXOnlineComponentGame oOnlineGame;
    local SFXAccomplishmentManager AccManager;

    if (bAPressed)
    {
        AccManager = Class'SFXEngine'.static.GetSFXEngine().AccomplishmentManager;
        if (AccManager != None)
        {
            AccManager.Save();
        }
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
    local SFXPRIMP LocalPRI;
    local WorldInfo CurrWorld;
    local int idx;
    local int ActivePlayers;
    local PauseMenuScoreData CurrData;
    local array<PauseMenuScoreData> AllScoreData;
    local UniqueNetId ZeroId;

    CurrWorld = Class'Engine'.static.GetCurrentWorldInfo();
    if (CurrWorld == None || CurrWorld.GRI == None)
    {
        return AllScoreData;
    }
    if (GetPC() != None)
    {
        LocalPRI = SFXPRIMP(GetPC().PlayerReplicationInfo);
    }
    for (idx = 0; idx < CurrWorld.GRI.PRIArray.Length; ++idx)
    {
        PRI = SFXPRIMP(CurrWorld.GRI.PRIArray[idx]);
        if (PRI != None && !PRI.bOnlySpectator && !PRI.bIsInactive)
        {
            ++ActivePlayers;
        }
    }
    for (idx = 0; idx < CurrWorld.GRI.PRIArray.Length; ++idx)
    {
        PRI = SFXPRIMP(CurrWorld.GRI.PRIArray[idx]);
        if (PRI != None && PRI.IsPlayer())
        {
            CurrData.PRIIndex = idx;
            CurrData.DisplayName = PRI.PlayerName;
            CurrData.Score = int(PRI.GetTotalPoints());
            CurrData.Ping = GetPingText(PRI);
            CurrData.KickVotes = int(PRI.NumKickVotesReceived);
            CurrData.ActivePlayers = ActivePlayers;
            // MILAN CHANGE - Mgamerz - 2026-10-11
            // A zero target means no vote. Offline PRIs can also have zero IDs;
            // never show the vote marker for an empty target or for ourselves.
            CurrData.HasVoted = LocalPRI != None && LocalPRI != PRI && LocalPRI.KickVotePlayerId != ZeroId && LocalPRI.KickVotePlayerId == PRI.UniqueId;
            // END MILAN CHANGE
            CurrData.CanVote = ActivePlayers > 2 && LocalPRI != None && LocalPRI != PRI && !PRI.bOnlySpectator && !PRI.bIsInactive;
            CurrData.IsLocal = LocalPRI != None && LocalPRI == PRI;
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

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    srPlayerNameColumn = $49875760
    srPlayerScoreColumn = $49875761
    srPlayerPingColumn = $49875762
    srHostPing = $49875763
    srPingMilliseconds = $49875764
    srMatchVoteKick = $49875765
    srMatchRemoveVote = $49875766
    // MILAN CHANGE - Mgamerz - 2026-10-11
    // Reuse the lobby's localized Invite Friends caption.
    srMatchInvite = $592439
    // END MILAN CHANGE
    srMatchScroll = $49875768
    srMatchInviteHint = $49875769
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
