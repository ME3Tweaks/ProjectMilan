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
var config float MatchStartTimerDuration;
var config float MatchStartLastManTimerDuration;
var float MatchStartTimer;
var EMatchTimerState MatchTimerState;

public function CancelSearchInput(bool bAPressed, int nContext)
{
    CancelSearch();
}
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
            ShowNetworkErrorPrompt(srMatchMakingError);
        }
    }
    else if (int(Result) == 3)
    {
        QuickMatch(MatchMakingGameSettings);
    }
    else
    {
        ShowNetworkErrorPrompt(srMatchMakingError);
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
    SFXGRIMP_Lobby(GameReplicationInfo).NumPlayerSlots = MaxPlayersAllowed;
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
    local SFXGUIInteraction oGuiMgr;
    local BioSFHandler_MessageBox oMsgBox;
    local BioMessageBoxOptionalParams stParams;
    local bool bMatchRequestSent;
    local SFXOnlineComponentBlazeGame BG;

    if (OnlineSub != None)
    {
        GameInterface = OnlineSub.GameInterface;
        // MILAN CHANGE - The development server has no online component to
        // answer CanPlayOnline(), so proceed directly to the interface path.
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
                    if (BG != None && BG.GameSettings == None)
                    {
                        BG.GameSettings = MatchMakingGameSettings;
                    }
                    bMatchRequestSent = CreateOnlineGame(MatchMakingGameSettings);
                }
                else
                {
                    bMatchRequestSent = QuickMatch(MatchMakingGameSettings);
                }
            }
            if (bMatchRequestSent)
            {
                oGuiMgr = GetPC().GetSFXUIController();
                oMsgBox = oGuiMgr.CreateMessageBox(GetPC());
                stParams.bModal = TRUE;
                oMsgBox.SetInputDelegate(CancelSearchInput);
                stParams.srBText = srCancel;
                oMsgBox.DisplayMessageBox(MatchMakingGameSettings.mCreateNewMatch ? srCreatingGame : srSearchingForGames, stParams);
            }
            else
            {
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
    GRI.GotoState('StartingMatch', , , );
    mapPackageName = GetOnlineGameSettings().GetMapByID(GRI.MapSetting).PackageName;
    ConsoleCommand("servertravel " $ mapPackageName);
}
public function UnCommitSettings()
{
    local SFXGRIMP_Lobby GRI;

    GRI = SFXGRIMP_Lobby(GameReplicationInfo);
    GetOnlineGameSettings().mMapIsRequired = FALSE;
    ChangeMatchSettings(GRI.PrivacySetting, GRI.MapSetting, GRI.bRandomMap, GRI.EnemySetting, GRI.bRandomEnemy, GRI.DifficultySetting, TRUE, TRUE);
}
public final function UpdateKickVotes()
{
    local int KickerIdx;
    local int KickeeIdx;
    local SFXPRIMP Kicker;
    local SFXPRIMP Kickee;
    local array<PlayerReplicationInfo> PRIArray;
    local UniqueNetId ZeroId;

    PRIArray = GameReplicationInfo.PRIArray;
    for (KickeeIdx = 0; KickeeIdx < PRIArray.Length; ++KickeeIdx)
    {
        Kickee = SFXPRIMP(PRIArray[KickeeIdx]);
        Kickee.NumKickVotesReceived = 0;
        for (KickerIdx = 0; KickerIdx < PRIArray.Length; ++KickerIdx)
        {
            Kicker = SFXPRIMP(PRIArray[KickerIdx]);
            if (Kicker.KickVotePlayerId != ZeroId && Kicker.KickVotePlayerId == Kickee.UniqueId)
            {
                Kickee.NumKickVotesReceived++;
            }
        }
        if (int(Kickee.NumKickVotesReceived) > 1 && int(Kickee.NumKickVotesReceived) == PRIArray.Length - 1)
        {
            for (KickerIdx = 0; KickerIdx < PRIArray.Length; ++KickerIdx)
            {
                Kicker = SFXPRIMP(PRIArray[KickerIdx]);
                if (Kicker.KickVotePlayerId != ZeroId && Kicker.KickVotePlayerId == Kickee.UniqueId)
                {
                    Kicker.KickVotePlayerId = ZeroId;
                }
            }
            GetPC().KickPlayer(Kickee.UniqueId);
        }
    }
}
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
// Enemies" (and any future meta-option) can never be selected as the resolved faction when
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
public final function SFXOnlineGameSettings GetOnlineGameSettings()
{
    return SFXOnlineGameSettings(OnlineSub.GameInterface.GetGameSettings('Game'));
}

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
    srOnlinePrivilegeError = $652174
    srStrictNatError = $724659
    NatWarningShowDelay = 30.0
    NatWarningShowDuration = 6.0
    MatchStartTimerDuration = 5.0
    MatchStartLastManTimerDuration = 20.0
    GameReplicationInfoClass = Class'SFXGRIMP_Lobby'
}
