// Source: ME3, MPLobby
// Decompiled 10/5/2026 5:01:18 PM
// MILAN CHANGE - 10/09/2026 - Mgamerz
// Class override instead of function overrides: the loose class is compiled before function
// overrides apply, and its original CheckGoToLobby no longer matches SFXPRIMP.GatherMatchResults.
// Lobby size changes: InitGame, FindPlayerStart + FindOverflowStartLocation, MatchOver.CheckGoToLobby.
// SpawnDefaultPawnFor moved here from FunctionOverride\SFXGameInfoMP (07/02/2024).
Class SFXGameInfoMP extends SFXGame
    config(Game);

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
// NEW to Milan - 10/09/2026 - Mgamerz
// Lobby size, applied on every MP map (the lobby, the match, and the return to the lobby):
//  - MaxPlayersAllowed is the ceiling GameInfo.InitGame clamps MaxPlayers to. It comes from config
//    SFXGameMPContent.SFXGameInfoMP_Lobby MaxLobbySize, see GetMaxLobbySize()) instead of this
//    class's package default of 4.
//  - MaxPlayers is the host's chosen size. It lives in the host's online game settings
//    (SFXOnlineGameSettings.GetLobbySize), which survives travel; a GameInfo does not. AtCapacity
//    refuses joins against it, so a size of 1 admits nobody.
// An explicit ?MaxPlayers= URL option always overrides this 
public event function InitGame(string Options, out string ErrorMessage)
{
    local SFXOnlineGameSettings Settings;

    MaxPlayersAllowed = Class'SFXGameInfoMP_Lobby'.static.GetMaxLobbySize();
    Super.InitGame(Options, ErrorMessage);
    if (!HasOption(Options, "MaxPlayers") && GameInterface != None)
    {
        Settings = SFXOnlineGameSettings(GameInterface.GetGameSettings('Game'));
        if (Settings != None)
        {
            MaxPlayers = Clamp(Settings.GetLobbySize(), 1, MaxPlayersAllowed);
        }
    }
}

// MILAN CHANGE - Mgamerz - 2026-10-10
// In-match vote kicks use the same host-authoritative rule as lobby votes:
// active occupants only, strict majority, and no kicks with two players.
public final function UpdateMatchKickVotes()
{
    local array<PlayerReplicationInfo> ActivePRIs;
    local PlayerReplicationInfo PRI;
    local SFXPRIMP Kicker;
    local SFXPRIMP Kickee;
    local UniqueNetId ZeroId;
    local ISFXOnlineComponentGame OnlineGame;
    local int KickeeIndex;
    local int KickerIndex;
    local int KickVotes;

    if (Role != ENetRole.ROLE_Authority || GameReplicationInfo == None)
    {
        return;
    }
    foreach GameReplicationInfo.PRIArray(PRI)
    {
        if (SFXPRIMP(PRI) != None && !PRI.bOnlySpectator && !PRI.bIsInactive)
        {
            ActivePRIs.AddItem(PRI);
        }
    }
    OnlineGame = Class'SFXOnlineSubsystem'.static.GetOnlineSubsystem().GetComponentGame();
    for (KickeeIndex = 0; KickeeIndex < ActivePRIs.Length; ++KickeeIndex)
    {
        Kickee = SFXPRIMP(ActivePRIs[KickeeIndex]);
        KickVotes = 0;
        for (KickerIndex = 0; KickerIndex < ActivePRIs.Length; ++KickerIndex)
        {
            Kicker = SFXPRIMP(ActivePRIs[KickerIndex]);
            if (Kicker != Kickee && Kicker.KickVotePlayerId != ZeroId && Kicker.KickVotePlayerId == Kickee.UniqueId)
            {
                ++KickVotes;
            }
        }
        Kickee.NumKickVotesReceived = byte(Min(KickVotes, 255));
        if (ActivePRIs.Length > 2 && KickVotes * 2 > ActivePRIs.Length && OnlineGame != None && OnlineGame.KickPlayer(Kickee.UniqueId))
        {
            LogInternal("LMP in-match vote kick:" @ Kickee.PlayerName @ "votes" @ KickVotes @ "of" @ ActivePRIs.Length);
            for (KickerIndex = 0; KickerIndex < ActivePRIs.Length; ++KickerIndex)
            {
                Kicker = SFXPRIMP(ActivePRIs[KickerIndex]);
                if (Kicker.KickVotePlayerId == Kickee.UniqueId)
                {
                    Kicker.KickVotePlayerId = ZeroId;
                }
            }
            return;
        }
    }
}
// END MILAN CHANGE
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
    local Vector OverflowLocation; // MILAN CHANGE - 10/09/2026 - Mgamerz
    local Rotator OverflowRotation; // MILAN CHANGE - 10/09/2026 - Mgamerz

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
        // MILAN CHANGE - 10/09/2026 - Mgamerz
        // Cast-check so it doesn't throw an error in log which can be misleading
        if (SFXPlayerControllerMP(Player) != None)
        {
            SFXPlayerControllerMP(Player).BioStartSpot = BestStartLocation;
        }
        else {
            LogInternal("FindPlayerStart: Player is not a SFXPlayerControllerMP, cannot set BioStartSpot", );
        }
        // END MILAN CHANGE
        return Spawn(Class'DynamicAnchor', , , BestStartLocation.location, BestStartLocation.Rotation);
    }
    // MILAN CHANGE - 10/09/2026 - Mgamerz
    // To avoid having to add more player starts, if all slots are full, find a nearby spot to spawn
    if (FindOverflowStartLocation(Player, InTeam, OverflowLocation, OverflowRotation))
    {
        return Spawn(Class'DynamicAnchor', , , OverflowLocation, OverflowRotation);
    }
    LogInternal("FindPlayerStart: no free start spot and no free space near one for" @ Player, );
    // END MILAN CHANGE
    return Super(GameInfo).FindPlayerStart(Player, InTeam, IncomingName);
}
// NEW to Milan - 10/09/2026 - Mgamerz
// Finds free space for a player near the map's BioStartLocationMP spots, for a lobby that holds more
// players than the map has spots (FindPlayerStart). Spots are tried best rated first
// (RateBioPlayerStart prefers spots near the other players), each in three rings of 8 candidates.
// A candidate must:
//  - be in sight of its spot, so it is not through a wall or in another room;
//  - have room for a pawn (FindSpot nudges it out of geometry, or fails);
//  - have a floor within reach below it;
//  - keep clear of every pawn and start spot.
public function bool FindOverflowStartLocation(Controller Player, byte InTeam, out Vector OutLocation, out Rotator OutRotation)
{
    local BioStartLocationMP Spot;
    local BioStartLocationMP OtherSpot;
    local array<BioStartLocationMP> Spots;
    local array<float> Ratings;
    local Controller C;
    local int SpotIdx;
    local int BestIdx;
    local int Ring;
    local int Step;
    local bool bBlocked;
    local Vector Extent;
    local Vector Candidate;
    local Vector Adjusted;
    local Vector HitLocation;
    local Vector HitNormal;
    local Rotator Direction;

    // The start spots' own collision cylinder: radius 50, half height 90.
    Extent = vect(50.0, 50.0, 90.0);
    foreach WorldInfo.AllActors(Class'BioStartLocationMP', Spot)
    {
        Spots.AddItem(Spot);
        Ratings.AddItem(RateBioPlayerStart(Spot, InTeam, Player));
    }
    while (Spots.Length > 0)
    {
        BestIdx = 0;
        for (SpotIdx = 1; SpotIdx < Spots.Length; ++SpotIdx)
        {
            if (Ratings[SpotIdx] > Ratings[BestIdx])
            {
                BestIdx = SpotIdx;
            }
        }
        Spot = Spots[BestIdx];
        Spots.Remove(BestIdx, 1);
        Ratings.Remove(BestIdx, 1);
        for (Ring = 1; Ring <= 3; ++Ring)
        {
            for (Step = 0; Step < 8; ++Step)
            {
                // 8 directions 45 degrees apart; the middle ring is turned half a step to fill the gaps.
                Direction.Yaw = Spot.Rotation.Yaw + Step * 8192 + (Ring == 2 ? 4096 : 0);
                Candidate = Spot.location + Vector(Direction) * (110.0 * float(Ring));
                if (!FastTrace(Candidate, Spot.location))
                {
                    continue;
                }
                Adjusted = Candidate;
                if (!FindSpot(Extent, Adjusted) || VSize(Adjusted - Candidate) > 60.0)
                {
                    continue;
                }
                if (Trace(HitLocation, HitNormal, Adjusted - vect(0.0, 0.0, 200.0), Adjusted, FALSE) == None)
                {
                    continue;
                }
                bBlocked = FALSE;
                foreach WorldInfo.AllControllers(Class'Controller', C)
                {
                    if (C.Pawn != None && VSize(C.Pawn.location - Adjusted) < Extent.X * 2.0)
                    {
                        bBlocked = TRUE;
                        break;
                    }
                }
                if (!bBlocked)
                {
                    foreach WorldInfo.AllActors(Class'BioStartLocationMP', OtherSpot)
                    {
                        if (VSize(OtherSpot.location - Adjusted) < Extent.X * 2.0)
                        {
                            bBlocked = TRUE;
                            break;
                        }
                    }
                }
                if (bBlocked)
                {
                    continue;
                }
                LogInternal("FindOverflowStartLocation: all start spots are claimed; placing" @ Player @ "near" @ Spot, );
                OutLocation = Adjusted;
                OutRotation = Spot.Rotation;
                return TRUE;
            }
        }
    }
    return FALSE;
}
// END MILAN CHANGE

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
// MILAN CHANGE
// Date: 07/02/2024
// Purpose: If playerarchetype fails to spawn, load the default one to prevent infinite loading. 
// - Mgamerz
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
    // MILAN CHANGE 07/02/2024
    // Spawn default pawn if we could not spawn the archetype in case save references non-compiled kit
    if (PlayerArchetype == None)
    {
        // Spawn failed!
        LogInternal("Spawn failed for " $ oPRI.GetPawnArchetype() $ " - using default archetype", );
        PlayerArchetype = SFXPawn_PlayerMP(Class'SFXEngine'.static.GetSeekFreeObject(Class'SFXPRIMP'.default.DEFAULT_PLAYER_ARCHETYPE_PATH, Class'SFXPawn_PlayerMP'));
    }
    // END MILAN CHANGE
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
        if (!C.IsDead() && C.Pawn != None && !C.Pawn.IsInState('Dying', ) && !SFXPawn_PlayerMP(C.Pawn).bIsDead || C.PlayerReplicationInfo == None || C.Pawn == None)
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
    ConsoleCommand("servertravel " $ Class'GameEngine'.static.GetDefaultLobbyMap() $ ExtraURLOption);
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

state MatchOver 
{
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
        // MILAN CHANGE - 10/09/2026 - Mgamerz
        // Room for every player of a lobby of up to 16 (SFXGameInfoMP_Lobby.MAX_LOBBY_SIZE); with 4,
        // players 5 and up never reached the end-of-match results. Must match SFXPRIMP.GatherMatchResults.
        local int ExtractedPlayers[16];
        // END MILAN CHANGE
        local int idx;
        // MILAN CHANGE - Mgamerz - 2026-10-12
        // Measure both timestamps on the host; each PC has a different uptime. This is used by MilanHost to
        // compute the match duration for the results screen, and is sent to all players in SFXPRIMP.GatherMatchResults - 
        // since SFXOnlineComponentAPI was stripped from the binary
        local SFXGRIMP GRI;
        local SFXOnlineSubsystem MatchOnlineSub;
        local int MatchEndTime;
        local int MatchDuration;
        // END MILAN CHANGE

        // MILAN CHANGE - Mgamerz - 2026-10-12
        // Compute once before sending results so every player receives the same duration.
        // Leave duration at zero if the start or end timestamp is unavailable.
        GRI = SFXGRIMP(GameReplicationInfo);
        MatchOnlineSub = Class'SFXOnlineSubsystem'.static.GetOnlineSubsystem();
        if (GRI != None && GRI.MatchStartTime != 0 && MatchOnlineSub != None)
        {
            MatchEndTime = MatchOnlineSub.GetComponentAPI().GetCurrentTime();
            if (MatchEndTime != 0)
            {
                MatchDuration = Max(0, MatchEndTime - GRI.MatchStartTime);
            }
        }
        // END MILAN CHANGE

        for (idx = 0; idx < 16; idx++)
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
                    // MILAN CHANGE - Mgamerz - 2026-10-12
                    // Send the host's duration in the results RPC, without a replication race.
                    SFXPRIMP(PC.PlayerReplicationInfo).GatherMatchResults(SFXGRIMP(GameReplicationInfo).GameStatus == EGameStatus.GS_MatchOver_Win, ExtractedPlayers, MatchDuration);
                    // END MILAN CHANGE
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
    
    
    stop;
};
state MatchInProgress 
{
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
            if (PC.Pawn == None && PC.PlayerReplicationInfo != None && PC.PlayerReplicationInfo.bReadyToPlay && IsRestarting(PC) == FALSE)
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
        local SFXGRIMP GRI;

        Super(Object).BeginState(PrevStateName);
        
        // MILAN CHANGE - 10/09/2026 - Mgamerz
        // Check cast to GRIMP as game shows evidence this is SFXGRIMP_Lobby which is not subclass of SFXGRIMP.
        GRI = SFXGRIMP(WorldInfo.GRI);
        if (GRI != None) {
            SFXGRIMP(GameReplicationInfo).SetGameStatus(2);
        }
        // END MILAN CHANGE
    }
    
    stop;
};
auto state PendingMatch 
{
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
        local SFXGRIMP GRI;

        Super(Object).BeginState(PrevStateName);

        // MILAN CHANGE - 10/09/2026 - Mgamerz
        // Check cast to GRIMP as game shows evidence this is SFXGRIMP_Lobby which is not subclass of SFXGRIMP.
        GRI = SFXGRIMP(WorldInfo.GRI);
        if (GRI != None) {
            SFXGRIMP(GameReplicationInfo).SetGameStatus(1);
        }
        // END MILAN CHANGE
        bWaitingToStartMatch = TRUE;
        bWaitingForPlayers = TRUE;
    }
    public function RestartPlayer(Controller NewPlayer);
    
    
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
