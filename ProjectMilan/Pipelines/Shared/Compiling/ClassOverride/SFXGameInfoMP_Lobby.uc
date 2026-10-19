// Source: ME3, Patch_SFXGameInfoMP_Lobby
// Decompiled 9/20/2026 9:50:12 PM
// MILAN CHANGE - 09/21/2026 - Mgamerz
// ChooseRandomEnemy() only ever excluded the literal "Unknown" (Id=0) entry from its candidate
// pool. Filter on the new MPEnemyInfo.IsRandomOption flag instead, so "Random Waves" and
// "Random Enemies" (and any future meta-option) can never be picked as the resolved faction
// when a player selects "Unknown" - matches the same IsRandomOption filter used in
// SFXWaveCoordinator_HordeOperation.PickRandomFactionWaveType().
Class SFXGameInfoMP_Lobby extends SFXGameInfoMP
    config(Game);

enum EMatchTimerState
{
    MatchTimer_NoTimer,
    MatchTimer_AllPlayersReady,
    MatchTimer_WaitingOnLastMan,
};

var Class<Object> MPLobbyScreenClass;
var Class<Object> MPLobbyStatusBarsScreenClass;
var Class<Object> CharacterSelectScreenClass;
var Class<Object> CharacterCreateScreenClass;
var Class<Object> CharacterAppearanceScreenClass;
var Class<Object> CharacterKitScreenClass;
var Class<Object> MatchResultsScreenClass;
var Class<Object> LeaderboardScreenClass;
var Class<Object> MPMatchConsumablesScreenClass;
var Class<Object> MPStoreScreenClass;
var Class<Object> MPPromotionScreenClass;
var Class<Object> GalaxyAtWarScreenClass;
var Class<Object> WarAssetsScreenClass;
var GFxMovieInfo MPNewLobbyScreen;
var GFxMovieInfo MPLobbyStatusBarsScreen;
var GFxMovieInfo CharacterSelectScreen;
var GFxMovieInfo CharacterCreateScreen;
var GFxMovieInfo CharacterAppearanceScreen;
var GFxMovieInfo CharacterKitScreen;
var GFxMovieInfo MatchResultsScreen;
var GFxMovieInfo LeaderboardScreen;
var GFxMovieInfo MPMatchConsumablesScreen;
var GFxMovieInfo MPStoreScreen;
var GFxMovieInfo MPPromotionScreen;
var GFxMovieInfo GalaxyAtWarScreen;
var GFxMovieInfo WarAssetsScreen;
var GFxMovieInfo WeaponSelectScreen;
var config stringref srOK;
var config stringref srCancel;
var config stringref srSearchingForGames;
var config stringref srCreatingGame;
var config stringref srMatchMakingError;
var config stringref srOnlinePrivilegeError;
var config stringref srStrictNatError;
var config float NatWarningShowDelay;
var config float NatWarningShowDuration;
var SFXOnlineGameSettings MatchMakingGameSettings;
// MILAN CHANGE - Mgamerz - 2026-10-15
// Quick Match failures need their own reasons, and the 'searching' box has to be closed when a search fails.
var config stringref srQuickMatchOff;
var config stringref srQuickMatchServerUnavailable;
var config stringref srQuickMatchAccessKeyRejected;
var BioSFHandler_MessageBox SearchMsgBox;
// END MILAN CHANGE
var config float MatchStartTimerDuration;
var config float MatchStartLastManTimerDuration;
// MILAN CHANGE - 10/09/2026 - Mgamerz
// The largest lobby size a host can pick (GetMaxLobbySize). Hard coded, cannot be changed without lots of work.
const MAX_LOBBY_SIZE = 16;
// Marked config so its just a simple config edit to adjust. 16 is the cap, 8 is the default max, 4 is the default value if not changed.
var config int MaxLobbySize;
// END MILAN CHANGE
var float MatchStartTimer;
var EMatchTimerState MatchTimerState;

public function CancelSearchInput(bool bAPressed, int nContext)
{
    // MILAN CHANGE - Mgamerz - 2026-10-15
    // The box dismisses itself when its button is pressed; don't hide it a second time.
    SearchMsgBox = None;
    // END MILAN CHANGE
    CancelSearch();
}
// MILAN CHANGE - Mgamerz - 2026-10-15
public function ShowSearchMsgBox()
{
    local SFXGUIInteraction oGuiMgr;
    local BioMessageBoxOptionalParams stParams;

    oGuiMgr = GetPC().GetSFXUIController();
    SearchMsgBox = oGuiMgr.CreateMessageBox(GetPC());
    stParams.bModal = TRUE;
    SearchMsgBox.SetInputDelegate(CancelSearchInput);
    stParams.srBText = srCancel;
    SearchMsgBox.DisplayMessageBox(MatchMakingGameSettings.mCreateNewMatch ? srCreatingGame : srSearchingForGames, stParams);
}
public function HideSearchMsgBox()
{
    if (SearchMsgBox != None)
    {
        SearchMsgBox.HideMessageBox(TRUE);
        SearchMsgBox = None;
    }
}
// END MILAN CHANGE
public function bool CreateOnlineGame(SFXOnlineGameSettings GameSettings)
{
    local bool bMatchRequestSent;

    if (GameSettings == None)
    {
        OnMPFatalError("Should have valid GameSettings when calling CreateOnlineGame.");
        return FALSE;
    }
    // MILAN CHANGE -- Skip creating a real online session in development builds.
    if (TRUE)
    {
        OnCreateGameComplete('Game', TRUE);
        return TRUE;
    }
    if (OnlineSub != None)
    {
        GameInterface = OnlineSub.GameInterface;
        if (GameInterface != None)
        {
            GameInterface.AddDestroyOnlineGameCompleteDelegate(OnMultiplayerGameDestroyed);
            GameInterface.AddCreateOnlineGameCompleteDelegate(OnCreateGameComplete);
            bMatchRequestSent = GameInterface.CreateOnlineGame(0, 'Game', GameSettings);
            if (!bMatchRequestSent)
            {
                GameInterface.ClearCreateOnlineGameCompleteDelegate(OnCreateGameComplete);
            }
        }
    }
    return bMatchRequestSent;
}
public function OnQuickMatchComplete(byte Result)
{
    local string joinGameHostIp;

    // MILAN CHANGE - Mgamerz - 2026-09-25
    // A successful server reservation must travel to its host, not start a new listen lobby.
    if (OnlineSub != None)
    {
        GameInterface = OnlineSub.GameInterface;
        if (GameInterface != None)
        {
            GameInterface.ClearQuickMatchCompleteDelegate(OnQuickMatchComplete);
        }
    }
    if (int(Result) == 2)
    {
        if (GameInterface != None && GameInterface.GetResolvedConnectString('Game', joinGameHostIp) && joinGameHostIp != "")
        {
            WorldInfo.ConsoleCommand("open " $ joinGameHostIp);
        }
        else
        {
            HideSearchMsgBox();
            ShowNetworkErrorPrompt(srMatchMakingError);
        }
    }
    else if (int(Result) == 3)
    {
        QuickMatch(MatchMakingGameSettings);
    }
    else
    {
        // The search is over, so close its 'searching' box before showing why it failed.
        // Results come from MilanHost's CMatchmaking: 5 = matchmaking off, 6 = matchmaker unavailable,
        // 7 = matchmaker refused the access key, anything else is a plain failure.
        HideSearchMsgBox();
        switch (int(Result))
        {
            case 5:
                ShowNetworkErrorPrompt(srQuickMatchOff);
                break;
            case 6:
                ShowNetworkErrorPrompt(srQuickMatchServerUnavailable);
                break;
            case 7:
                ShowNetworkErrorPrompt(srQuickMatchAccessKeyRejected);
                break;
            default:
                ShowNetworkErrorPrompt(srMatchMakingError);
                break;
        }
    }
    // END MILAN CHANGE
}
public event simulated function PostBeginPlay()
{
    Super.PostBeginPlay();
    DeferredPostBeginPlay();
}
public function bool QuickMatch(optional SFXOnlineGameSettings GameSettings)
{
    local bool bMatchRequestSent;

    if (OnlineSub != None)
    {
        GameInterface = OnlineSub.GameInterface;
        if (GameInterface != None)
        {
            GameInterface.AddDestroyOnlineGameCompleteDelegate(OnMultiplayerGameDestroyed);
            GameInterface.AddQuickMatchCompleteDelegate(OnQuickMatchComplete);
            bMatchRequestSent = GameInterface.QuickMatch(GameSettings);
            if (!bMatchRequestSent)
            {
                GameInterface.ClearQuickMatchCompleteDelegate(OnQuickMatchComplete);
            }
        }
    }
    return bMatchRequestSent;
}
public function Tick(float DeltaTime)
{
    local bool TimerSecondsChanged;

    Super.Tick(DeltaTime);
    if (IsMatchTimerRunning())
    {
        TimerSecondsChanged = FCeil(MatchStartTimer) != FCeil(MatchStartTimer - DeltaTime);
        MatchStartTimer -= DeltaTime;
        if (MatchStartTimer <= float(0))
        {
            SetMatchTimerState(0);
            TravelToNextMap();
        }
        else if (TimerSecondsChanged)
        {
            SFXGRIMP_Lobby(GameReplicationInfo).SetMatchStartTimer(IsMatchTimerRunning(), MatchStartTimer, MatchStartTimerDuration);
        }
    }
}
public final function SFXPlayerControllerMP GetPC()
{
    return SFXPlayerControllerMP(BioWorldInfo(WorldInfo).GetLocalPlayerController());
}
public function RestartPlayer(Controller NewPlayer)
{
    if (SFXGRIMP_Lobby(GameReplicationInfo) != None)
    {
        Super.RestartPlayer(NewPlayer);
    }
}
public function ClearCrossLevelReferences()
{
    GameInterface.ClearCreateOnlineGameCompleteDelegate(OnCreateGameComplete);
    GameInterface.ClearQuickMatchCompleteDelegate(OnQuickMatchComplete);
    GameInterface.ClearDestroyOnlineGameCompleteDelegate(OnMultiplayerGameDestroyed);
    GameInterface.ClearJoinOnlineGameCompleteDelegate(OnQuickMatchJoined);
    Super.ClearCrossLevelReferences();
}
public simulated function DeferredPostBeginPlay()
{
    if (GameReplicationInfo == None)
    {
        SetTimer(0.100000001, FALSE, 'DeferredPostBeginPlay', );
        return;
    }
    // MILAN CHANGE - 10/09/2026 - Mgamerz
    // The lobby shows a slot per player the lobby admits (MaxPlayers, the host's chosen size; see
    // SFXGameInfoMP.InitGame), not the ceiling (MaxPlayersAllowed).
    SFXGRIMP_Lobby(GameReplicationInfo).SetNumPlayerSlots(MaxPlayers);
    // END MILAN CHANGE
    ClearTimer('DeferredPostBeginPlay');
}
public function OnMultiplayerGameDestroyed(Name SessionName, bool bWasSuccessful)
{
    OnMPNetworkError("OnMultiplayerGameDestroyed: " $ (bWasSuccessful ? "TRUE" : "FALSE"));
}
public final function bool IsMatchTimerRunning()
{
    return MatchTimerState != EMatchTimerState.MatchTimer_NoTimer;
}
public function OnCreateGameComplete(Name SessionName, bool bWasSuccessful)
{
    Class'SFXTelemetryHooksMP'.static.SendMPHostNew(bWasSuccessful);
    if (bWasSuccessful)
    {
        ShowPrompt(srCreatingGame, FALSE);
        OnMPGameStarted(bWasSuccessful);
    }
    else
    {
        ShowNetworkErrorPrompt(srMatchMakingError);
    }
}
public function OnMPFatalError(string additionalInfo)
{
    CancelSearch();
    ShowNetworkErrorPrompt(srMatchMakingError);
    assert(FALSE);
}
public function OnMPGameStarted(bool bWasSuccessful)
{
    local string connectString;

    // MILAN CHANGE - Move connection string construction out of the online
    // component. The map is always the lobby in the current development flow.
    connectString = "mplobby?listen";
    connectString $= "?origin=MultiplayerMenu";
    connectString $= "?privacy=" $ MatchMakingGameSettings.GetPrivacy();
    connectString $= "?map=" $ MatchMakingGameSettings.mME3MapName;
    connectString $= "?enemy=" $ MatchMakingGameSettings.EnemyType;
    connectString $= "?difficulty=" $ int(MatchMakingGameSettings.Difficulty);
    connectString = "open " $ connectString;

    // Keep the original online-subsystem path disabled while the development
    // lobby flow is in use; retain it here as documentation of the old path.
    if (FALSE)
    {
        LogInternal("OnMPGameStarted: " $ bWasSuccessful, );
        if (OnlineSub != None)
        {
            GameInterface = OnlineSub.GameInterface;
            if (GameInterface != None)
            {
                if (bWasSuccessful)
                {
                    GameInterface.ClearCreateOnlineGameCompleteDelegate(OnCreateGameComplete);
                    GameInterface.ClearQuickMatchCompleteDelegate(OnQuickMatchComplete);
                    GameInterface.ClearDestroyOnlineGameCompleteDelegate(OnMultiplayerGameDestroyed);
                    if (GameInterface.GetResolvedConnectString('Game', connectString))
                    {
                        connectString $= "?origin=MultiplayerMenu";
                        connectString $= "?privacy=" $ MatchMakingGameSettings.GetPrivacy();
                        connectString $= "?map=" $ MatchMakingGameSettings.mME3MapName;
                        connectString $= "?enemy=" $ MatchMakingGameSettings.EnemyType;
                        connectString $= "?difficulty=" $ int(MatchMakingGameSettings.Difficulty);
                        connectString = "open " $ connectString;
                    }
                    else
                    {
                        OnMPFatalError("GetResolvedConnectString failed.");
                    }
                }
                else
                {
                    OnMPNetworkError("Starting MP match failed.");
                    CancelSearch();
                }
            }
            else
            {
                OnMPFatalError(Self @ GetFuncName());
            }
        }
        else
        {
            OnMPFatalError(Self @ GetFuncName());
        }
    }
    LogInternal("WorldInfoCC: " $ connectString, );
    WorldInfo.ConsoleCommand(connectString);
}
public function OnMPNetworkError(string additionalInfo)
{
    CancelSearch();
}
public function OnQuickMatchJoined(Name SessionName, bool bWasSuccessful)
{
     // MILAN Patched: Remove calls to SFXTelemetry
    if (OnlineSub != None)
    {
        GameInterface = OnlineSub.GameInterface;
        if (GameInterface != None)
        {
            GameInterface.ClearJoinOnlineGameCompleteDelegate(OnQuickMatchJoined);
        }
    }
    if (!bWasSuccessful)
    {
        QuickMatch(MatchMakingGameSettings);
    }
}
public function SetMatchTimerState(EMatchTimerState NewMatchTimerState)
{
    local BioWorldInfo BioWorldInfo;

    if (!IsMatchTimerRunning() || int(MatchTimerState) != int(NewMatchTimerState))
    {
        MatchTimerState = NewMatchTimerState;
        switch (MatchTimerState)
        {
            case EMatchTimerState.MatchTimer_WaitingOnLastMan:
                if (MatchStartLastManTimerDuration > float(0))
                {
                    MatchStartTimer = MatchStartLastManTimerDuration;
                }
                else
                {
                    MatchStartTimer = MatchStartTimerDuration;
                }
                break;
            case EMatchTimerState.MatchTimer_NoTimer:
                MatchStartTimer = 0.0;
                break;
            case EMatchTimerState.MatchTimer_AllPlayersReady:
            default:
                MatchStartTimer = MatchStartTimerDuration;
                break;
        }
        BioWorldInfo = BioWorldInfo(WorldInfo);
        if (BioWorldInfo != None && BioWorldInfo.Role == ENetRole.ROLE_Authority && IsMatchTimerRunning())
        {
            if (BioWorldInfo.GetAutoBotsEnabled() == TRUE)
            {
                MatchStartTimer = float(BioWorldInfo.GetAutoBotsLobbyWaitTime());
            }
        }
        SFXGRIMP_Lobby(GameReplicationInfo).SetMatchStartTimer(IsMatchTimerRunning(), MatchStartTimer, MatchStartTimerDuration);
    }
}
public function ShowNetworkErrorPrompt(stringref Caption)
{
    ShowPrompt(Caption, TRUE);
}
public function ShowPrompt(stringref Caption, bool withOkButton)
{
    local SFXGUIInteraction oGuiMgr;
    local BioMessageBoxOptionalParams stParams;

    oGuiMgr = GetPC().GetSFXUIController();
    stParams.bModal = TRUE;
    if (withOkButton)
    {
        stParams.srAText = srOK;
    }
    oGuiMgr.QueueNamedMessageBox('LobbyNetworkPrompt', 5, Caption, stParams, None);
}
public function ShowStrictNatWarning()
{
    local SFXGUIInteraction oGuiMgr;

    oGuiMgr = GetPC() == None ? None : GetPC().GetSFXUIController();
    if (oGuiMgr != None)
    {
        oGuiMgr.ShowHint(srStrictNatError, srStrictNatError, NatWarningShowDuration); // MILAN Patched: Change method signature for controller/KBM strings
    }
}
public function StartMPMatch(optional SFXOnlineGameSettings GameSettings)
{
    local bool bMatchRequestSent;
    local bool bQuickMatch;
    local SFXOnlineComponentBlazeGame BG;

    if (OnlineSub != None)
    {
        GameInterface = OnlineSub.GameInterface;
        // MILAN CHANGE - We don't care about CanPlayOnline, so we remove it
        if (GameInterface != None)
        {
            if (GameSettings == None)
            {
                // MILAN CHANGE - Mgamerz - 2026-09-25
                // Default Quick Match searches every public map, enemy, and difficulty.
                MatchMakingGameSettings = new Class'SFXOnlineGameSettings';
                MatchMakingGameSettings.mME3MapName = "";
                MatchMakingGameSettings.EnemyType = 127;
                MatchMakingGameSettings.Difficulty = 127;
                MatchMakingGameSettings.mCreateNewMatch = FALSE;
                // 2026-10-15: MilanHost can fail a search before QuickMatch returns, so the box must already be up to be closed.
                bQuickMatch = TRUE;
                ShowSearchMsgBox();
                bMatchRequestSent = QuickMatch(MatchMakingGameSettings);
                // END MILAN CHANGE
            }
            else
            {
                MatchMakingGameSettings = GameSettings.Copy();
                if (MatchMakingGameSettings.mCreateNewMatch)
                {
                    // MILAN CHANGE - Force-populate BlazeGame GameSettings;
                    // there is no setter outside native code.
                    BG = SFXOnlineComponentBlazeGame(OnlineSub.GameInterface);
                    // 10/07/2026 - Mgamerz - Remove BG.GameSettings = None because it meant old settings were continuing to be used
                    if (BG != None)
                    {
                        BG.GameSettings = MatchMakingGameSettings;
                    }
                    bMatchRequestSent = CreateOnlineGame(MatchMakingGameSettings);
                }
                else
                {
                    // MILAN CHANGE - Mgamerz - 2026-10-15
                    bQuickMatch = TRUE;
                    ShowSearchMsgBox();
                    // END MILAN CHANGE
                    bMatchRequestSent = QuickMatch(MatchMakingGameSettings);
                }
            }
            if (bMatchRequestSent)
            {
                // MILAN CHANGE - Mgamerz - 2026-10-15
                // Quick Match already showed its box before the request; it may have been closed since.
                if (!bQuickMatch)
                {
                    ShowSearchMsgBox();
                }
                // END MILAN CHANGE
            }
            else
            {
                HideSearchMsgBox(); // MILAN CHANGE - Mgamerz - 2026-10-15
                GameInterface.ClearDestroyOnlineGameCompleteDelegate(OnMultiplayerGameDestroyed);
                OnMPFatalError(Self @ GetFuncName());
            }
        }
        else
        {
            OnMPFatalError(Self @ GetFuncName());
        }
    }
    else
    {
        OnMPFatalError(Self @ GetFuncName());
    }
}
public function TravelToNextMap()
{
    local string mapPackageName;
    local SFXGRIMP_Lobby GRI;

    GRI = SFXGRIMP_Lobby(GameReplicationInfo);
    // MILAN CHANGE - Mgamerz - 2026-10-16
    // GetMapByID is static, so it needs no settings instance. An empty name would make servertravel
    // keep the current map and reload the lobby, so refuse and send the players back to readying.
    mapPackageName = Class'SFXOnlineGameSettings'.static.GetMapByID(GRI.MapSetting).PackageName;
    if (mapPackageName == "")
    {
        LogInternal("TravelToNextMap: no map package for MapSetting" @ GRI.MapSetting $ "; not traveling", );
        GRI.UnreadyAllPlayers();
        return;
    }
    GRI.GotoState('StartingMatch', , , );
    // END MILAN CHANGE
    ConsoleCommand("servertravel " $ mapPackageName);
}
public function UnCommitSettings()
{
    local SFXGRIMP_Lobby GRI;

    GRI = SFXGRIMP_Lobby(GameReplicationInfo);
    GetOnlineGameSettings().mMapIsRequired = FALSE;
    ChangeMatchSettings(GRI.PrivacySetting, GRI.MapSetting, GRI.bRandomMap, GRI.EnemySetting, GRI.bRandomEnemy, GRI.DifficultySetting, TRUE, TRUE);
}
// MILAN CHANGE - Mgamerz - 2026-10-10
// Require strictly more than half of the current lobby, including the target in the
// denominator. Integer multiplication avoids rounding; two-player lobbies cannot kick.
// Call the game component on the authority so a host kick is handled by the host too.
public final function UpdateKickVotes()
{
    local int KickerIdx;
    local int KickeeIdx;
    local int KickVotes;
    local SFXPRIMP Kicker;
    local SFXPRIMP Kickee;
    local PlayerReplicationInfo PRI;
    local array<PlayerReplicationInfo> PRIArray;
    local UniqueNetId ZeroId;
    local ISFXOnlineComponentGame OnlineGame;

    if (Role != ENetRole.ROLE_Authority || GameReplicationInfo == None)
    {
        return;
    }
    foreach GameReplicationInfo.PRIArray(PRI)
    {
        if (SFXPRIMP(PRI) != None && !PRI.bOnlySpectator && !PRI.bIsInactive)
        {
            PRIArray.AddItem(PRI);
        }
    }
    OnlineGame = Class'SFXOnlineSubsystem'.static.GetOnlineSubsystem().GetComponentGame();
    for (KickeeIdx = 0; KickeeIdx < PRIArray.Length; ++KickeeIdx)
    {
        Kickee = SFXPRIMP(PRIArray[KickeeIdx]);
        KickVotes = 0;
        for (KickerIdx = 0; KickerIdx < PRIArray.Length; ++KickerIdx)
        {
            Kicker = SFXPRIMP(PRIArray[KickerIdx]);
            if (Kicker != Kickee && Kicker.KickVotePlayerId != ZeroId && Kicker.KickVotePlayerId == Kickee.UniqueId)
            {
                KickVotes++;
            }
        }
        Kickee.NumKickVotesReceived = byte(Min(KickVotes, 255));
        if (PRIArray.Length > 2 && KickVotes * 2 > PRIArray.Length && OnlineGame != None)
        {
            // Keep the votes if removal could not be queued; do not report a false success.
            if (OnlineGame.KickPlayer(Kickee.UniqueId))
            {
                LogInternal("LMP vote kick:" @ Kickee.PlayerName @ "votes" @ KickVotes @ "of" @ PRIArray.Length);
                for (KickerIdx = 0; KickerIdx < PRIArray.Length; ++KickerIdx)
                {
                    Kicker = SFXPRIMP(PRIArray[KickerIdx]);
                    if (Kicker.KickVotePlayerId == Kickee.UniqueId)
                    {
                        Kicker.KickVotePlayerId = ZeroId;
                    }
                }
                return;
            }
        }
    }
}
// END MILAN CHANGE
public function CancelSearch()
{
    if (OnlineSub != None)
    {
        GameInterface = OnlineSub.GameInterface;
        if (GameInterface != None)
        {
            GameInterface.ClearCreateOnlineGameCompleteDelegate(OnCreateGameComplete);
            GameInterface.ClearQuickMatchCompleteDelegate(OnQuickMatchComplete);
            GameInterface.ClearDestroyOnlineGameCompleteDelegate(OnMultiplayerGameDestroyed);
            GameInterface.ClearJoinOnlineGameCompleteDelegate(OnQuickMatchJoined);
            GameInterface.CancelFindOnlineGames();
            HideSearchMsgBox(); // MILAN CHANGE - Mgamerz - 2026-10-15
            GetPC().LobbyFlow.OnSearchGameCancelled();
        }
        else
        {
            OnMPFatalError(Self @ GetFuncName());
        }
    }
    else
    {
        OnMPFatalError(Self @ GetFuncName());
    }
}
public function bool ChangeMatchSettings(int privacy, int MapId, bool bRandomMap, int EnemyType, bool bRandomEnemy, int NewDifficulty, optional bool bAllowMatchmaking = TRUE, optional bool updateOnline = TRUE)
{
    local SFXOnlineGameSettings CurrentSettings;
    local SFXOnlineGameSettings NewSettings;
    local string mapPackageName;
    local SFXGRIMP_Lobby GRI;
    local bool bSettingsChanged;

    CurrentSettings = GetOnlineGameSettings();
    if (CurrentSettings != None)
    {
        mapPackageName = CurrentSettings.GetMapByID(MapId).PackageName;
        NewSettings = GetOnlineGameSettings().Copy();
        NewSettings.SetPrivacy(byte(privacy));
        NewSettings.mME3MapName = mapPackageName;
        NewSettings.EnemyType = EnemyType;
        NewSettings.Difficulty = byte(NewDifficulty);
        if (updateOnline && OnlineSub != None)
        {
            GameInterface = OnlineSub.GameInterface;
            if (GameInterface != None)
            {
                Class'SFXOnlineSubsystem'.static.GetOnlineSubsystem().GetComponentGame().AllowMatchmaking(bAllowMatchmaking, FALSE);
                GameInterface.UpdateOnlineGame('Game', NewSettings, TRUE);
            }
        }
    }
    GRI = SFXGRIMP_Lobby(GameReplicationInfo);
    bSettingsChanged = GRI.PrivacySetting != privacy || GRI.MapSetting != MapId || GRI.bRandomMap != bRandomMap || GRI.EnemySetting != EnemyType || GRI.bRandomEnemy != bRandomEnemy || GRI.DifficultySetting != NewDifficulty;
    GRI.PrivacySetting = privacy;
    GRI.MapSetting = MapId;
    GRI.bRandomMap = bRandomMap;
    GRI.EnemySetting = EnemyType;
    GRI.bRandomEnemy = bRandomEnemy;
    GRI.DifficultySetting = NewDifficulty;
     // MILAN Patched: Remove calls to Engine.Telemetry.GameSession.SetMPMatchSettings()
    GetPC().LobbyFlow.OnMatchSettingsChanged();
    // MILAN CHANGE - 10/09/2026 - Mgamerz
    // A 1-player lobby is a private match. Leaving Private (1), for Public or Friends, opens it to
    // the default size.
    if (privacy != 1 && MaxPlayers <= 1)
    {
        SetLobbySize(GetDefaultLobbySize());
    }
    // END MILAN CHANGE
    return bSettingsChanged;
}
public function CheckAllPlayersReady()
{
    local int NumReady;
    local BioWorldInfo BioWorldInfo;
    local SFXGRIMP_Lobby CastedGRI;

    CastedGRI = SFXGRIMP_Lobby(GameReplicationInfo);
    NumReady = CastedGRI.GetNumReadyPlayers();
    BioWorldInfo = BioWorldInfo(WorldInfo);
    if (BioWorldInfo != None && BioWorldInfo.Role == ENetRole.ROLE_Authority)
    {
        if (BioWorldInfo.GetAutoBotsEnabled() == TRUE)
        {
            NumReady = CastedGRI.PRIArray.Length;
        }
    }
    if (NumReady > 0 && NumReady == CastedGRI.GetNumPlayers())
    {
        SetMatchTimerState(1);
        CommitSettings();
    }
    else if (CastedGRI.CanForceLastManReady())
    {
        SetMatchTimerState(2);
        CommitSettings();
    }
    else if (IsMatchTimerRunning())
    {
        SetMatchTimerState(0);
        UnCommitSettings();
    }
}
public function CheckNatRestriction()
{
    local SFXOnlineSubsystem OnlineSubsystem;
    local ISFXOnlineComponentGame OnlineGame;

    OnlineSubsystem = Class'SFXOnlineSubsystem'.static.GetOnlineSubsystem();
    if (OnlineSubsystem != None)
    {
        OnlineGame = OnlineSubsystem.GetComponentGame();
        if (OnlineGame != None && OnlineGame.IsInvalidHost())
        {
            SetTimer(NatWarningShowDelay, FALSE, 'ShowStrictNatWarning', );
        }
    }
}
// MILAN CHANGE
// Filter on IsRandomOption instead of a hardcoded Id==0 check, so "Random Waves"/"Random
// Enemies" (and any future not-an-actual-defined-option) can never be selected as the resolved faction when
// a player picks "Unknown".
public function MPEnemyInfo ChooseRandomEnemy()
{
    local array<MPEnemyInfo> EnemiesToChooseFrom;
    local int RemoveIdx;
    local int idx;
    local MPEnemyInfo RandomEnemy;
    local MPEnemyInfo Info;
    local int LastEnemyPlayedIdx;
    local float SelectionSum;
    local float Weight;
    local float RandVal;

    EnemiesToChooseFrom = Class'SFXOnlineGameSettings'.default.EnemyTypes;
    for (RemoveIdx = EnemiesToChooseFrom.Length - 1; RemoveIdx >= 0; RemoveIdx--)
    {
        if (EnemiesToChooseFrom[RemoveIdx].IsRandomOption)
        {
            EnemiesToChooseFrom.Remove(RemoveIdx, 1);
        }
    }
    // END MILAN CHANGE
    if (EnemiesToChooseFrom.Length > 1)
    {
        LastEnemyPlayedIdx = EnemiesToChooseFrom.Find('Id', GetPC().LobbyFlow.LastEnemyPlayed);
        if (LastEnemyPlayedIdx != -1)
        {
            EnemiesToChooseFrom.Remove(LastEnemyPlayedIdx, 1);
        }
    }
    if (EnemiesToChooseFrom.Length > 0)
    {
        foreach EnemiesToChooseFrom(Info, )
        {
            idx = Class'SFXWaveManager_Horde'.default.WaveTypes.Find('WaveClassName', Info.WaveClass);
            if (idx != -1)
            {
                SelectionSum += float(Class'SFXWaveManager_Horde'.default.WaveTypes[idx].SelectionWeight);
            }
        }
        RandVal = FRand() * SelectionSum;
        foreach EnemiesToChooseFrom(Info, )
        {
            idx = Class'SFXWaveManager_Horde'.default.WaveTypes.Find('WaveClassName', Info.WaveClass);
            if (idx != -1)
            {
                Weight = float(Class'SFXWaveManager_Horde'.default.WaveTypes[idx].SelectionWeight);
                if (RandVal < Weight)
                {
                    RandomEnemy = Info;
                    break;
                }
                RandVal -= Weight;
            }
        }
    }
    return RandomEnemy;
}
public function MPMapInfo ChooseRandomMap()
{
    local array<MPMapInfo> MapsToChooseFrom;
    local MPMapInfo RandomMap;
    local int UnknownMapIdx;
    local int RandomIdx;
    local int LastMapPlayedIdx;
    local int MapIter;

    MapsToChooseFrom = GetPC().LobbyFlow.GetAvailableMapList();
    UnknownMapIdx = MapsToChooseFrom.Find('PackageName', "");
    if (UnknownMapIdx != -1)
    {
        MapsToChooseFrom.Remove(UnknownMapIdx, 1);
    }
    if (MapsToChooseFrom.Length > 1)
    {
        LastMapPlayedIdx = MapsToChooseFrom.Find('Id', GetPC().LobbyFlow.LastMapPlayed);
        if (LastMapPlayedIdx != -1)
        {
            MapsToChooseFrom.Remove(LastMapPlayedIdx, 1);
        }
    }
    for (MapIter = MapsToChooseFrom.Length - 1; MapIter >= 0; MapIter--)
    {
        if (!MapsToChooseFrom[MapIter].EveryoneHasThisMap)
        {
            MapsToChooseFrom.Remove(MapIter, 1);
        }
    }
    if (MapsToChooseFrom.Length > 0)
    {
        RandomIdx = Rand(MapsToChooseFrom.Length);
        RandomMap = MapsToChooseFrom[RandomIdx];
    }
    return RandomMap;
}
public function CommitSettings()
{
    local int MapSetting;
    local int EnemySetting;
    local SFXGRIMP_Lobby GRI;

    GRI = SFXGRIMP_Lobby(GameReplicationInfo);
    MapSetting = GRI.MapSetting;
    if (GRI.bRandomMap == TRUE)
    {
        MapSetting = ChooseRandomMap().Id;
    }
    EnemySetting = GRI.EnemySetting;
    if (GRI.bRandomEnemy == TRUE)
    {
        EnemySetting = ChooseRandomEnemy().Id;
    }
    GetOnlineGameSettings().mMapIsRequired = TRUE;
    ChangeMatchSettings(GRI.PrivacySetting, MapSetting, GRI.bRandomMap, EnemySetting, GRI.bRandomEnemy, GRI.DifficultySetting, FALSE, TRUE);
    GetOnlineGameSettings().SetIntProperty(0, MapSetting);
}
// MILAN CHANGE - 10/09/2026 - Mgamerz
// Lobby size: how many players, the host included, the lobby admits. The host's online game
// settings carry it across travel; SFXGameInfoMP.InitGame applies it to MaxPlayers on every map.
// The largest size a host can pick: config MaxLobbySize, capped at MAX_LOBBY_SIZE.
public static function int GetMaxLobbySize()
{
    // This class's own section, whichever subclass (SFXGameInfoMP_Lobby_DLC) is asking.
    return Clamp(Class'SFXGameInfoMP_Lobby'.default.MaxLobbySize, 1, MAX_LOBBY_SIZE);
}
// The size a new lobby starts with: [Engine.GameInfo] MaxPlayers.
public static function int GetDefaultLobbySize()
{
    return Clamp(Class'GameInfo'.default.MaxPlayers, 1, Class'SFXGameInfoMP_Lobby'.static.GetMaxLobbySize());
}
public function int GetLobbySize()
{
    return MaxPlayers;
}
// Host only. Clamped to 1..MaxPlayersAllowed and never below the players already here, so a smaller
// size removes nobody. A size of 1 is a private match with no invites. Returns the size in effect.
public function int SetLobbySize(int NewSize)
{
    local SFXOnlineGameSettings Settings;
    local SFXGRIMP_Lobby GRI;

    GRI = SFXGRIMP_Lobby(GameReplicationInfo);
    Settings = GetOnlineGameSettings();
    if (GRI == None || Settings == None)
    {
        return MaxPlayers;
    }
    NewSize = Clamp(NewSize, Max(1, GetNumPlayers()), MaxPlayersAllowed);
    Settings.SetLobbySize(NewSize);
    MaxPlayers = NewSize;
    GRI.SetNumPlayerSlots(NewSize);
    // 1 is PRIVACY_PRIVATE; Public (0) and Friends (2) both take invites.
    if (NewSize == 1 && GRI.PrivacySetting != 1)
    {
        ChangeMatchSettings(1, GRI.MapSetting, GRI.bRandomMap, GRI.EnemySetting, GRI.bRandomEnemy, GRI.DifficultySetting);
    }
    // A full lobby can now start on the last-man timer, or no longer can.
    CheckAllPlayersReady();
    return MaxPlayers;
}
// END MILAN CHANGE
public final function SFXOnlineGameSettings GetOnlineGameSettings()
{
    return EnsureOnlineGameSettings(); // MILAN CHANGE - Mgamerz - 2026-10-16
}
// MILAN CHANGE - Mgamerz - 2026-10-16
// Only a game that created its match got online game settings (StartMPMatch); a game that joined had
// none. When host migration made such a game the host, MilanHost had nowhere to put the lobby's settings
// and every lookup through them read None, so TravelToNextMap traveled to an empty map: the lobby again.
// SFXLobbyFlow.StartMPFlow calls this on every MP level so a member has settings before it is adopted.
public static final function SFXOnlineGameSettings EnsureOnlineGameSettings()
{
    local SFXOnlineSubsystem OnlineSubsystem;
    local SFXOnlineComponentBlazeGame BG;

    OnlineSubsystem = Class'SFXOnlineSubsystem'.static.GetOnlineSubsystem();
    if (OnlineSubsystem != None)
    {
        BG = SFXOnlineComponentBlazeGame(OnlineSubsystem.GameInterface);
    }
    if (BG == None)
    {
        return None;
    }
    if (BG.GameSettings == None)
    {
        BG.GameSettings = new Class'SFXOnlineGameSettings';
        BG.GameSettings.SetLobbySize(GetDefaultLobbySize());
    }
    return BG.GameSettings;
}
// END MILAN CHANGE

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    MPLobbyScreenClass = Class'SFXGUI_MPLobby'
    MPLobbyStatusBarsScreenClass = Class'SFXGUI_MPLobbyStatusBars'
    CharacterAppearanceScreenClass = Class'SFXGUI_MPAppearance'
    CharacterKitScreenClass = Class'SFXGUI_MPSelectKit'
    MatchResultsScreenClass = Class'SFXGUI_MPMatchResults'
    LeaderboardScreenClass = Class'SFXGUI_Leaderboard'
    MPMatchConsumablesScreenClass = Class'SFXGUI_MPMatchConsumables'
    MPStoreScreenClass = Class'SFXGUI_MPStore'
    MPPromotionScreenClass = Class'SFXGUI_MPPromotion'
    GalaxyAtWarScreenClass = Class'SFXGUI_GalaxyAtWar'
    WarAssetsScreenClass = Class'SFXGUI_WarAssets'
    MPNewLobbyScreen = GFxMovieInfo'GUI_SF_MPNewLobby.MPNewLobby'
    MPLobbyStatusBarsScreen = GFxMovieInfo'GUI_SF_MPLobbyStatusBars.MPLobbyStatusBars'
    CharacterAppearanceScreen = GFxMovieInfo'GUI_SF_MPAppearance.MPAppearance'
    CharacterKitScreen = GFxMovieInfo'GUI_SF_MPSelectKit.MPSelectKit'
    MatchResultsScreen = GFxMovieInfo'GUI_SF_MPMatchResults.MPMatchResults'
    LeaderboardScreen = GFxMovieInfo'GUI_SF_Leaderboard.Leaderboard'
    MPMatchConsumablesScreen = GFxMovieInfo'GUI_SF_MPMatchConsumables.MPMatchConsumables'
    MPStoreScreen = GFxMovieInfo'GUI_SF_MPStore.MPStore'
    MPPromotionScreen = GFxMovieInfo'GUI_SF_MPPromotion.MPPromotion'
    GalaxyAtWarScreen = GFxMovieInfo'GUI_SF_GalaxyAtWar.galaxyAtWar'
    WarAssetsScreen = GFxMovieInfo'GUI_SF_WarAssets.WarAssets'
    WeaponSelectScreen = GFxMovieInfo'GUI_SF_WeaponSelect.WeaponSelect'
    srOK = $152938
    srCancel = $168246
    srSearchingForGames = $506693
    srCreatingGame = $626902
    srMatchMakingError = $591379
    srQuickMatchOff = $49875719
    srQuickMatchServerUnavailable = $49875720
    srQuickMatchAccessKeyRejected = $49875718
    srOnlinePrivilegeError = $652174
    srStrictNatError = $724659
    NatWarningShowDelay = 30.0
    NatWarningShowDuration = 6.0
    MatchStartTimerDuration = 5.0
    MatchStartLastManTimerDuration = 20.0
    MaxLobbySize = 8
    GameReplicationInfoClass = Class'SFXGRIMP_Lobby'
}
