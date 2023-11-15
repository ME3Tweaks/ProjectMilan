Class SFXGameInfoMP extends SFXGame
    config(Game);

// Variables
var array<Class<Object>> LoadedPlayerClasses;
var array<SFXPlayerControllerMP> AsyncRestartPlayerList;
var Class<Object> EndOfMatchScreenClass;
var Class<Object> ScoreboardScreenClass;
var Class<Object> ScoretagsScreenClass;
var Class<Object> PauseMenuScreenClass;
var Class<Object> OptionsMenuScreenClass;
var Class<Object> OptionsMenuScreenClassPC;
var Class<Object> MPReinforcementsRevealScreenClass;
var Class<Object> MPHUDScreenClass;
var GFxMovieInfo EndOfMatchScreen;
var GFxMovieInfo ScoreboardScreen;
var GFxMovieInfo ScoretagsScreen;
var GFxMovieInfo PauseMenuScreen;
var GFxMovieInfo MPReinforcementsRevealScreen;
var GFxMovieInfo MPHUDScreen;
var protectedwrite transient SFXHostMigrationMP HostMigration;
var config float WaitingForPlayersTimeout;
var config float JoinInProgressReplicationDelay;
var config float BackToLobbyFailSafeDelay;
var bool bTriggeredLoad;
var bool bWaitingForPlayers;

// Functions
public event function GetSeamlessTravelActorList(bool bToEntry, out array<Actor> ActorList)
{
    local int i;
    
    for (i = 0; i < WorldInfo.GRI.PRIArray.Length; i++)
    {
        if (WorldInfo.GRI.PRIArray[i] != None && !WorldInfo.GRI.PRIArray[i].bBot)
        {
            WorldInfo.GRI.PRIArray[i].bFromPreviousLevel = TRUE;
            ActorList[ActorList.Length] = WorldInfo.GRI.PRIArray[i];
        }
    }
    ActorList[ActorList.Length] = WorldInfo.GRI;
}
public function Logout(Controller Exiting)
{
    Super(GameInfo).Logout(Exiting);
    SFXGRIMP(WorldInfo.GRI).TeamScoreOffset += int(SFXPRIMP(Exiting.PlayerReplicationInfo).GetTotalPoints());
}
public event function PostBeginPlay()
{
    Super.PostBeginPlay();
    PlayerSquad = Spawn(Class'SFXPlayerSquadMP');
}
public function PreBeginPlay()
{
    local SFXGRI OldGRI;
    
    OldGRI = SFXGRI(WorldInfo.GRI);
    HostMigration = SFXHostMigrationMP(SFXEngine(Class'SFXEngine'.static.GetEngine()).InitHostMigration(Class'SFXHostMigrationMP'));
    Super.PreBeginPlay();
    if (OldGRI != None)
    {
        SFXGRI(WorldInfo.GRI).CopyProperties(OldGRI);
        OldGRI.Destroy();
    }
    if (HostMigration != None)
    {
        HostMigration.RestoreGRI(SFXGRI(WorldInfo.GRI));
    }
}
public function Tick(float TimeDelta)
{
    if (AsyncRestartPlayerList.Length > 0)
    {
        TickRestartPlayerAsync();
    }
}
public function bool FindInactivePRI(PlayerController PC)
{
    return FALSE;
}
public function NavigationPoint FindPlayerStart(Controller Player, optional byte InTeam, optional string IncomingName)
{
    local BioStartLocationMP ChkBioStartLocation;
    local BioStartLocationMP BestStartLocation;
    local float ChkStartLocationRating;
    local float BestStartLocationRating;
    local SFXPlayerControllerMP PC;
    local bool bUsedSpot;
    
    BestStartLocationRating = -1000000.0;
    if (Player == None || SFXPlayerControllerMP(Player).BioStartSpot == None)
    {
        foreach WorldInfo.AllActors(Class'BioStartLocationMP', ChkBioStartLocation, )
        {
            bUsedSpot = FALSE;
            foreach WorldInfo.AllControllers(Class'SFXPlayerControllerMP', PC)
            {
                if (ChkBioStartLocation == PC.BioStartSpot)
                {
                    bUsedSpot = TRUE;
                    break;
                }
            }
            if (!bUsedSpot)
            {
                ChkStartLocationRating = RateBioPlayerStart(ChkBioStartLocation, InTeam, Player);
                if (ChkStartLocationRating > BestStartLocationRating)
                {
                    BestStartLocationRating = ChkStartLocationRating;
                    BestStartLocation = ChkBioStartLocation;
                }
            }
        }
    }
    else
    {
        BestStartLocation = SFXPlayerControllerMP(Player).BioStartSpot;
    }
    if (BestStartLocation != None)
    {
        SFXPlayerControllerMP(Player).BioStartSpot = BestStartLocation;
        return Spawn(Class'DynamicAnchor', , , BestStartLocation.location, BestStartLocation.Rotation);
    }
    return Super(GameInfo).FindPlayerStart(Player, InTeam, IncomingName);
}
public function GenericPlayerInitialization(Controller C)
{
    Super(GameInfo).GenericPlayerInitialization(C);
    if (HostMigration != None)
    {
        HostMigration.RestorePRI(SFXPRI(C.PlayerReplicationInfo));
    }
}
public function float RatePlayerStart(PlayerStart P, byte Team, Controller Player)
{
    local float Rating;
    local float Distance;
    local SFXPlayerControllerMP PC;
    
    if (Player == None)
    {
        return -1.0;
    }
    if (P == None || P.bEnabled == FALSE)
    {
        return -1.0;
    }
    Rating = float(P.bPrimaryStart ? 10000000 : 5000000);
    Rating += 500.0 * FRand();
    foreach WorldInfo.AllControllers(Class'SFXPlayerControllerMP', PC)
    {
        if (PC != Player && PC.Pawn != None)
        {
            if (PC.Pawn != None)
            {
                Distance = VSize(PC.Pawn.location - P.location);
                Rating -= Distance;
            }
            if (PC.StartSpot == P)
            {
                Rating = -500.0;
            }
        }
    }
    return Rating;
}
public function RegisterServer();

public function RestartPlayer(Controller NewPlayer)
{
    local SFXPlayerControllerMP PC;
    local Pawn oPawn;
    
    PC = SFXPlayerControllerMP(NewPlayer);
    if (PC != None && IsRestarting(PC) == FALSE)
    {
        if (PC.Pawn != None && PC.PawnNeedsCleanup())
        {
            oPawn = PC.Pawn;
            oPawn.SetHidden(TRUE);
            PC.UnPossess();
            oPawn.Destroy();
        }
        RestartPlayerAsync(PC);
    }
}
public function Pawn SpawnDefaultPawnFor(Controller NewPlayer, NavigationPoint StartSpot, optional bool bNoCollisionFail = FALSE)
{
    local Rotator StartRotation;
    local SFXPawn_PlayerMP ResultPawn;
    local Actor PlayerArchetype;
    local SFXPlayerControllerMP PC;
    local SFXPRIMP oPRI;
    
    PC = SFXPlayerControllerMP(NewPlayer);
    if (PC == None)
    {
        return None;
    }
    oPRI = SFXPRIMP(PC.PlayerReplicationInfo);
    if (oPRI == None)
    {
        return None;
    }
    PlayerArchetype = SFXPawn_PlayerMP(Class'SFXEngine'.static.GetSeekFreeObject(oPRI.GetPawnArchetype(), Class'SFXPawn_PlayerMP'));
    StartRotation.Yaw = StartSpot.Rotation.Yaw;
    ResultPawn = Spawn(Class<SFXPawn_PlayerMP>(PlayerArchetype.Class), , , StartSpot.location, StartRotation, PlayerArchetype, bNoCollisionFail);
    if (ResultPawn == None)
    {
        return None;
    }
    ResultPawn.Kit = oPRI.GetCharacterKit();
    return ResultPawn;
}
public function StartMatch()
{
    WorldInfo.ForceGarbageCollection();
    Super.StartMatch();
    bWaitingToStartMatch = FALSE;
    GotoState('MatchInProgress', , , );
}
public function ClearCrossLevelReferences()
{
    Super.ClearCrossLevelReferences();
    JoinInProgressDelegates.Remove(0, JoinInProgressDelegates.Length);
}
public function OnPlayerSquadDeath();

public function bool PreventPermanentDeath(BioPawn KilledPawn)
{
    if (KilledPawn.IsPlayerPawn())
    {
        return TRUE;
    }
    return Super.PreventPermanentDeath(KilledPawn);
}
public function QuitToMainMenu()
{
    SFXGRIMP(GameReplicationInfo).SetGameStatus(5);
}
public function RegisterJoinInProgressDelegate(delegate<OnJoinInProgress> NewDelegate)
{
    if (JoinInProgressDelegates.Find(NewDelegate) == -1)
    {
        JoinInProgressDelegates.AddItem(NewDelegate);
    }
}
public function BioBaseSquad SpawnEnemySquad()
{
    return Spawn(Class'SFXSquadCombatMP', WorldInfo, , , , , TRUE, FALSE);
}
public function UnRegisterJoinInProgressDelegate(delegate<OnJoinInProgress> DelegateToRemove)
{
    JoinInProgressDelegates.RemoveItem(DelegateToRemove);
}
public final function bool AreAllPlayersDeath()
{
    local SFXPlayerControllerMP C;
    
    foreach WorldInfo.AllControllers(Class'SFXPlayerControllerMP', C)
    {
        if ((((!C.IsDead() && C.Pawn != None) && !C.Pawn.IsInState('Dying', )) && !SFXPawn_PlayerMP(C.Pawn).bIsDead || C.PlayerReplicationInfo == None) || C.Pawn == None)
        {
            return FALSE;
        }
    }
    return TRUE;
}
public final function CallJoinInProgressDelegates()
{
    local delegate<OnJoinInProgress> DelegateIter;
    
    foreach JoinInProgressDelegates(DelegateIter, )
    {
        DelegateIter();
    }
}
public function EndMatch()
{
    GotoState('MatchOver', , , );
}
public final function bool IsRestarting(SFXPlayerControllerMP PC)
{
    if (AsyncRestartPlayerList.Find(PC) != -1)
    {
        return TRUE;
    }
    else
    {
        return FALSE;
    }
}
public function QuitToLobby(string ExtraURLOption)
{
    ConsoleCommand(("servertravel " $ Class'GameEngine'.static.GetDefaultLobbyMap()) $ ExtraURLOption);
}
public function float RateBioPlayerStart(BioStartLocationMP P, byte Team, Controller Player)
{
    local float Rating;
    local float Distance;
    local SFXPlayerControllerMP PC;
    
    if (Player == None)
    {
        return -1.0;
    }
    if (P == None)
    {
        return -1.0;
    }
    Rating = float(P.bPrimaryStart ? 10000000 : 5000000);
    Rating += 500.0 * FRand();
    foreach WorldInfo.AllControllers(Class'SFXPlayerControllerMP', PC)
    {
        if (PC != Player && PC.Pawn != None)
        {
            if (PC.Pawn != None)
            {
                Distance = VSize(PC.Pawn.location - P.location);
                Rating -= Distance;
            }
            if (PC.BioStartSpot == P)
            {
                Rating = -500.0;
            }
        }
    }
    return Rating;
}
public function RestartMatch()
{
    ConsoleCommand("servertravel ?Restart");
}
public function RestartPlayerAsync(SFXPlayerControllerMP PC)
{
    local SFXPRIMP oPRI;
    
    oPRI = SFXPRIMP(PC.PlayerReplicationInfo);
    if (oPRI == None)
    {
        return;
    }
    oPRI.GetAsyncLoadingStatus();
    AsyncRestartPlayerList.AddItem(PC);
}
public function TickRestartPlayerAsync()
{
    local SFXPlayerControllerMP PC;
    local int idx;
    local SFXPRIMP oPRI;
    local EAsyncLoadStatus Status;
    local SFXPawn_PlayerMP PlayerPawn;
    
    for (idx = AsyncRestartPlayerList.Length - 1; idx >= 0; idx--)
    {
        PC = AsyncRestartPlayerList[idx];
        if (PC != None)
        {
            Status = EAsyncLoadStatus.ASYNC_LOAD_COMPLETE;
            oPRI = SFXPRIMP(PC.PlayerReplicationInfo);
            if (oPRI != None)
            {
                Status = oPRI.GetAsyncLoadingStatus();
            }
            if (Status == EAsyncLoadStatus.ASYNC_LOAD_COMPLETE)
            {
                AsyncRestartPlayerList.Remove(idx, 1);
                Super.RestartPlayer(PC);
                PlayerPawn = SFXPawn_PlayerMP(PC.Pawn);
                if (PlayerPawn != None && PlayerPawn.bIsProcessingFellOutOfWorld)
                {
                    PlayerPawn.FinalizeProcessFellOutOfWorld();
                    PC.ClientForceLocation(PlayerPawn.location.X, PlayerPawn.location.Y, PlayerPawn.location.Z);
                }
            }
        }
    }
}

// States
state MatchOver 
{
    // State Functions
    public function CheckPlayersReadyAtMatchEnd()
    {
        local SFXPlayerControllerMP PC;
        local bool bAllPlayersReady;
        
        bAllPlayersReady = TRUE;
        foreach WorldInfo.AllControllers(Class'SFXPlayerControllerMP', PC)
        {
            if (!SFXPRIMP(PC.PlayerReplicationInfo).ReadyToTransitionToLobby)
            {
                bAllPlayersReady = FALSE;
                break;
            }
        }
        if (bAllPlayersReady)
        {
            ClearTimer('ForceEverybodyReadyToTransitionToLobby');
            QuitToLobby("?origin=EndOfMatch");
        }
        else if (!IsTimerActive('CheckPlayersReadyAtMatchEnd'))
        {
            SetTimer(0.5, TRUE, 'CheckPlayersReadyAtMatchEnd', );
        }
    }
    public function CheckGoToLobby()
    {
        local SFXPlayerControllerMP PC;
        local int ExtractedPlayers[4];
        local int idx;
        
        for (idx = 0; idx < 4; idx++)
        {
            if (SFXGRIMP(WorldInfo.GRI).GetScoreManager().ExtractedPlayerIDs.Length > idx)
            {
                ExtractedPlayers[idx] = SFXGRIMP(WorldInfo.GRI).GetScoreManager().ExtractedPlayerIDs[idx];
                continue;
            }
            ExtractedPlayers[idx] = -1;
        }
        foreach WorldInfo.AllControllers(Class'SFXPlayerControllerMP', PC)
        {
            if (SFXPRIMP(PC.PlayerReplicationInfo) != None)
            {
                if (PC.Pawn != None)
                {
                    SFXPRIMP(PC.PlayerReplicationInfo).ReadyToTransitionToLobby = FALSE;
                    SFXPRIMP(PC.PlayerReplicationInfo).GatherMatchResults(SFXGRIMP(GameReplicationInfo).GameStatus == EGameStatus.GS_MatchOver_Win, ExtractedPlayers);
                }
                else
                {
                    SFXPRIMP(PC.PlayerReplicationInfo).ReadyToTransitionToLobby = TRUE;
                }
            }
        }
        SetTimer(BackToLobbyFailSafeDelay, FALSE, 'ForceEverybodyReadyToTransitionToLobby', );
        if (GameInterface != None)
        {
            WriteOnlineStats();
            WriteOnlinePlayerScores();
            EndOnlineGame();
            if (bUsingArbitration)
            {
                PendingArbitrationPCs.Length = 0;
                ArbitrationPCs.Length = 0;
                NotifyArbitratedMatchEnd();
            }
        }
        ClearTimer('CheckPlayersReadyAtMatchEnd');
        CheckPlayersReadyAtMatchEnd();
    }
    public function ForceEverybodyReadyToTransitionToLobby()
    {
        local SFXPlayerControllerMP PC;
        local SFXPRIMP oPRI;
        
        foreach WorldInfo.AllControllers(Class'SFXPlayerControllerMP', PC)
        {
            oPRI = SFXPRIMP(PC.PlayerReplicationInfo);
            if (oPRI != None)
            {
                if (oPRI.ReadyToTransitionToLobby == FALSE)
                {
                }
                oPRI.ReadyToTransitionToLobby = TRUE;
            }
        }
    }
    public event function BeginState(Name PrevStateName)
    {
        local SFXGRIMP GRI;
        local int idx;
        local SFXPRI PRI;
        
        GRI = SFXGRIMP(WorldInfo.GRI);
        if (AreAllPlayersDeath() || GRI != None && !GRI.bIsMissionComplete)
        {
            SFXGRIMP(GameReplicationInfo).SetGameStatus(4);
        }
        else
        {
            SFXGRIMP(GameReplicationInfo).SetGameStatus(3);
        }
        if (GRI != None)
        {
            GRI.bForceNetUpdate = TRUE;
            for (idx = 0; idx < GRI.PRIArray.Length; ++idx)
            {
                PRI = SFXPRIMP(GRI.PRIArray[idx]);
                if (PRI.bBot == FALSE)
                {
                    PRI.ReplicateScoreInfo();
                    PRI.bForceNetUpdate = TRUE;
                }
            }
        }
        Class'SFXOnlineSubsystem'.static.GetOnlineSubsystem().GetComponentGame().AllowMatchmaking(FALSE, TRUE);
        SetTimer(2.0, FALSE, 'CheckGoToLobby', );
    }
    public function RestartPlayer(Controller NewPlayer);
    
    
    // State code
    stop;
};
state MatchInProgress 
{
    // State Functions
    public event function PostLogin(PlayerController NewPlayer)
    {
        local SFXPlayerControllerMP PC;
        
        Global.PostLogin(NewPlayer);
        PC = SFXPlayerControllerMP(NewPlayer);
        if (PC != None)
        {
            PC.bIsJoinInProgress = TRUE;
        }
        SetTimer(JoinInProgressReplicationDelay, FALSE, 'CallJoinInProgressDelegates', );
    }
    public function Tick(float TimeDelta)
    {
        local SFXPlayerControllerMP PC;
        
        Global.Tick(TimeDelta);
        CheckEndMatch();
        foreach WorldInfo.AllControllers(Class'SFXPlayerControllerMP', PC)
        {
            if (((PC.Pawn == None && PC.PlayerReplicationInfo != None) && PC.PlayerReplicationInfo.bReadyToPlay) && IsRestarting(PC) == FALSE)
            {
                RestartPlayer(PC);
            }
        }
    }
    public function bool CheckEndMatch()
    {
        if (AreAllPlayersDeath() == TRUE)
        {
            EndMatch();
            return TRUE;
        }
        return FALSE;
    }
    public event function EndState(Name NextStateName)
    {
        Super(Object).EndState(NextStateName);
    }
    public event function BeginState(Name PrevStateName)
    {
        Super(Object).BeginState(PrevStateName);
        SFXGRIMP(GameReplicationInfo).SetGameStatus(2);
    }
    
    // State code
    stop;
};
auto state PendingMatch 
{
    // State Functions
    public function CheckStartMatch()
    {
        local SFXPlayerControllerMP PC;
        local int PlayerCount;
        local int NumPlayersReady;
        local SFXPRIMP PRI;
        
        PlayerCount = 0;
        NumPlayersReady = 0;
        foreach WorldInfo.AllControllers(Class'SFXPlayerControllerMP', PC)
        {
            PlayerCount++;
            PRI = SFXPRIMP(PC.PlayerReplicationInfo);
            if (PRI != None && PRI.bReadyToPlay)
            {
                NumPlayersReady++;
            }
        }
        if (bWaitingForPlayers)
        {
            if (HostMigration == None || HostMigration.IsReadyToStartMatch(NumPlayersReady))
            {
                bWaitingForPlayers = FALSE;
                ClearTimer('TimeoutWhileWaitingForPlayers');
            }
        }
        if (!bWaitingForPlayers)
        {
            if (NumPlayersReady == PlayerCount)
            {
                ClearTimer('CheckStartMatch');
                StartMatch();
            }
        }
    }
    public function TimeoutWhileWaitingForPlayers()
    {
        bWaitingForPlayers = FALSE;
    }
    public event function BeginState(Name PrevStateName)
    {
        Super(Object).BeginState(PrevStateName);
        SFXGRIMP(GameReplicationInfo).SetGameStatus(1);
        bWaitingToStartMatch = TRUE;
        bWaitingForPlayers = TRUE;
    }
    public function RestartPlayer(Controller NewPlayer);
    
    
    // State code
Begin:
    SetTimer(1.0, TRUE, 'CheckStartMatch', );
    SetTimer(WaitingForPlayersTimeout, FALSE, 'TimeoutWhileWaitingForPlayers', );
    stop;
};

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    EndOfMatchScreenClass = Class'SFXGUI_MPEndOfMatch'
    ScoretagsScreenClass = Class'SFXGUI_MPScoretags'
    PauseMenuScreenClass = Class'SFXGUI_MPPauseMenu'
    OptionsMenuScreenClass = Class'SFXGUI_MPOptions'
    OptionsMenuScreenClassPC = Class'SFXGUI_PCMPOptions'
    MPReinforcementsRevealScreenClass = Class'SFXGUI_MPReinforcementsReveal'
    MPHUDScreenClass = Class'SFXGUI_MPHUD'
    EndOfMatchScreen = GFxMovieInfo'GUI_SF_MPEndOfMatch.MPEndOfMatch'
    ScoretagsScreen = GFxMovieInfo'GUI_SF_MPScoretags.MPScoretags'
    PauseMenuScreen = GFxMovieInfo'GUI_SF_MPPauseMenu.MPPauseMenu'
    MPReinforcementsRevealScreen = GFxMovieInfo'GUI_SF_MPReinforcementsReveal.MPReinforcementsReveal'
    MPHUDScreen = GFxMovieInfo'GUI_SF_MP_HUD.MP_HUD'
    WaitingForPlayersTimeout = 20.0
    JoinInProgressReplicationDelay = 1.5
    BackToLobbyFailSafeDelay = 5.0
    HUDType = Class'SFXHUDMP'
    PlayerControllerClass = Class'SFXPlayerControllerMP'
    PlayerReplicationInfoClass = Class'SFXPRIMP'
    GameReplicationInfoClass = Class'SFXGRIMP'
    OnlineStatsWriteClass = Class'SFXOnlineStatsWrite'
    OnlineGameSettingsClass = Class'SFXOnlineGameSettings'
    MaxPlayersAllowed = 4
    bPauseable = FALSE
    bTeamGame = TRUE
    bUseSeamlessTravel = TRUE
}