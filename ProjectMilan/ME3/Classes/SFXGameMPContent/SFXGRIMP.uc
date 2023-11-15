Class SFXGRIMP extends SFXGRI
    config(Game);

// Types
enum EGameStatus
{
    GS_None,
    GS_PendingMatch,
    GS_MatchInProgress,
    GS_MatchOver_Win,
    GS_MatchOver_Lost,
    GS_ReturningToMainMenu,
};
const MAX_SQUAD_MEDALS = 10;

// Variables
var transient repnotify int SquadMedals[10];
var transient int SquadMedalsCache[10];
var int MapSetting;
var int EnemySetting;
var repnotify int DifficultySetting;
var config float fUpdateScoreInterval;
var config int MaxPlayersAllowedMP;
var transient int nNextPlayerIndex;
var transient SFXScoreManager ScoreManager;
var transient SFXMPEventTicker EventTicker;
var repnotify int SkynetGameID;
var repnotify int TeamScoreOffset;
var int MatchStartTime;
var bool PrivacySetting;
var bool bRandomMap;
var bool bRandomEnemy;
var bool bIsJoinInProgress;
var transient bool bIsMissionComplete;
var repnotify EGameStatus GameStatus;

// Functions
public simulated function PostBeginPlay()
{
    local SFXOnlineSubsystem OnlineSub;
    local BioRemoteLogger GLogger;
    local int i;
    
    GLogger = Class'BioRemoteLogger'.static.GetLogger();
    Super.PostBeginPlay();
    DifficultyHandler.CurrentDifficulty = byte(DifficultySetting);
    DifficultyHandler.bNeedsUpdate = TRUE;
    DifficultyHandler.Update();
    OnlineSub = Class'SFXOnlineSubsystem'.static.GetOnlineSubsystem();
    if (OnlineSub != None)
    {
        MatchStartTime = OnlineSub.GetComponentAPI().GetCurrentTime();
    }
    if (GLogger != None && Role == ENetRole.ROLE_Authority)
    {
        GLogger.SendNewCampaignMessage();
        GLogger.SendAreaEnteredEvent();
        SkynetGameID = GLogger.GetGameID();
    }
    for (i = 0; i < 10; i++)
    {
        SquadMedals[i] = -1;
        SquadMedalsCache[i] = -1;
    }
}
public event simulated function ReplicatedEvent(Name VarName)
{
    local BioRemoteLogger GLogger;
    
    if (VarName == 'GameStatus')
    {
        OnGameStatusChanged();
    }
    else if (VarName == 'SkynetGameID')
    {
        GLogger = Class'BioRemoteLogger'.static.GetLogger();
        if (GLogger != None)
        {
            GLogger.SetGameID(SkynetGameID);
            GLogger.SendNewCampaignMessage();
            GLogger.SendAreaEnteredEvent();
        }
    }
    else if (VarName == 'SquadMedals')
    {
        OnSquadMedalsChanged();
    }
    else if (VarName == 'DifficultySetting')
    {
        if (int(DifficultyHandler.CurrentDifficulty) != int(byte(DifficultySetting)))
        {
            DifficultyHandler.CurrentDifficulty = byte(DifficultySetting);
            DifficultyHandler.bNeedsUpdate = TRUE;
            DifficultyHandler.Update();
        }
    }
    else
    {
        Super(GameReplicationInfo).ReplicatedEvent(VarName);
    }
}
public function CopyProperties(SFXGRI OldGRI)
{
    local SFXGRIMP_Lobby LobbyGRI;
    local SFXGRIMP MPGRI;
    
    LobbyGRI = SFXGRIMP_Lobby(OldGRI);
    if (LobbyGRI != None)
    {
        PrivacySetting = LobbyGRI.PrivacySetting;
        MapSetting = LobbyGRI.MapSetting;
        bRandomMap = LobbyGRI.bRandomMap;
        EnemySetting = LobbyGRI.EnemySetting;
        bRandomEnemy = LobbyGRI.bRandomEnemy;
        DifficultySetting = LobbyGRI.DifficultySetting;
    }
    else
    {
        MPGRI = SFXGRIMP(OldGRI);
        if (MPGRI != None)
        {
            PrivacySetting = MPGRI.PrivacySetting;
            MapSetting = MPGRI.MapSetting;
            bRandomMap = MPGRI.bRandomMap;
            EnemySetting = MPGRI.EnemySetting;
            bRandomEnemy = MPGRI.bRandomEnemy;
            DifficultySetting = MPGRI.DifficultySetting;
        }
    }
}
public function AddSquadMedal(int Medal, optional int ReplaceMedal = -1)
{
    local int i;
    
    for (i = 0; i < 10; i++)
    {
        if (SquadMedals[i] == ReplaceMedal)
        {
            SquadMedals[i] = Medal;
            break;
        }
    }
    if (Role == ENetRole.ROLE_Authority)
    {
        OnSquadMedalsChanged();
    }
}
public simulated function int GetEnemyWaveTypeID()
{
    return EnemySetting;
}
public simulated function SFXMPEventTicker GetEventTicker()
{
    if (EventTicker == None)
    {
        EventTicker = new (Self) Class'SFXMPEventTicker';
    }
    return EventTicker;
}
public simulated function SFXScoreManager GetScoreManager()
{
    if (ScoreManager == None)
    {
        ScoreManager = new (Self) Class'SFXScoreManager';
        ScoreManager.Init();
    }
    return ScoreManager;
}
public simulated function float GetTeamScore()
{
    local int idx;
    local float fTeamScore;
    
    for (idx = 0; idx < WorldInfo.GRI.PRIArray.Length; idx++)
    {
        if (WorldInfo.GRI.PRIArray[idx].bBot == FALSE && !WorldInfo.GRI.PRIArray[idx].bIsInactive)
        {
            fTeamScore += SFXPRIMP(WorldInfo.GRI.PRIArray[idx]).GetTotalPoints();
        }
    }
    fTeamScore += float(SFXGRIMP(WorldInfo.GRI).TeamScoreOffset);
    return fTeamScore;
}
public function bool HasSquadMedal(int Medal)
{
    local int i;
    
    for (i = 0; i < 10; i++)
    {
        if (SquadMedals[i] == Medal)
        {
            return TRUE;
        }
    }
    return FALSE;
}
public simulated function bool IsGameOver()
{
    return GameStatus == EGameStatus.GS_MatchOver_Lost || GameStatus == EGameStatus.GS_MatchOver_Win;
}
public simulated function bool IsJoinInProgress()
{
    return Role == ENetRole.ROLE_Authority ? FALSE : bIsJoinInProgress;
}
public simulated function Pawn NextLivingPlayer()
{
    local int nIdx;
    local int nAdjustedIdx;
    local SFXPRIMP PRI;
    local SFXPawn_PlayerMP Pawn;
    
    if (NumLivingPlayers() > 0)
    {
        for (nIdx = 0; nIdx < PRIArray.Length; nIdx++)
        {
            nAdjustedIdx = (nNextPlayerIndex + nIdx) %  PRIArray.Length;
            PRI = SFXPRIMP(PRIArray[nAdjustedIdx]);
            Pawn = SFXPawn_PlayerMP(PRI.SFXPawn);
            if (((Pawn != None && !Pawn.IsDead()) && !Pawn.IsInState('Dying', )) && !Pawn.IsInState('Downed', ))
            {
                nNextPlayerIndex = nAdjustedIdx + 1;
                return Pawn;
            }
        }
    }
    return None;
}
public simulated function int NumLivingPlayers()
{
    local PlayerReplicationInfo PRI;
    local SFXPawn_PlayerMP Pawn;
    local int nRemaining;
    
    nRemaining = 0;
    foreach PRIArray(PRI, )
    {
        Pawn = SFXPawn_PlayerMP(SFXPRIMP(PRI).SFXPawn);
        if (((Pawn != None && !Pawn.IsDead()) && !Pawn.IsInState('Dying', )) && !Pawn.IsInState('Downed', ))
        {
            nRemaining++;
        }
    }
    return nRemaining;
}
public simulated function OnMissionComplete()
{
    local SFXPawn_Player PlayerPawn;
    
    PlayerPawn = SFXPawn_Player(WorldInfo.GetALocalPlayerController().Pawn);
    ScoreManager.IncrementMedalStanding(PlayerPawn, 16, int(DifficultyHandler.CurrentDifficulty) + 1);
    if (bRandomEnemy)
    {
        ScoreManager.IncrementMedalStanding(PlayerPawn, 20);
    }
    if (bRandomMap)
    {
        ScoreManager.IncrementMedalStanding(PlayerPawn, 19);
    }
    bIsMissionComplete = TRUE;
}
public simulated function bool RandomFactionChosen()
{
    return bRandomEnemy;
}
public simulated function bool RandomMapChosen()
{
    return bRandomMap;
}
public simulated function DeferredSetRichPresence()
{
    local BioPlayerController pController;
    
    pController = BioWorldInfo(WorldInfo).GetLocalPlayerController();
    if ((pController != None && pController.PlayerReplicationInfo != None) && pController.Pawn != None)
    {
        ClearTimer('DeferredSetRichPresence');
        pController.SetRichPresence();
    }
    else
    {
        SetTimer(0.100000001, FALSE, 'DeferredSetRichPresence', );
    }
}
public function ClearMatchConsumableGameEffects()
{
    local BioPlayerController PC;
    local PlayerReplicationInfo PRI;
    local SFXPRIMP PRIMP;
    
    if (Role != ENetRole.ROLE_Authority)
    {
        return;
    }
    foreach PRIArray(PRI, )
    {
        PC = BioPlayerController(PRI.Owner);
        PRIMP = SFXPRIMP(PRI);
        if (PC == None || PRIMP == None)
        {
            continue;
        }
        PRIMP.ClearActiveMatchConsumables();
    }
}
public simulated function DeferredGrantAccomplishments()
{
    local SFXPlayerControllerMP pController;
    
    if (BioWorldInfo(WorldInfo) != None && BioWorldInfo(WorldInfo).GetLocalPlayerController() != None)
    {
        ClearTimer('DeferredGrantAccomplishments');
        pController = SFXPlayerControllerMP(BioWorldInfo(WorldInfo).GetLocalPlayerController());
        pController.UpdateMPMapsCompleted(Name(WorldInfo.GetMapName()), FALSE);
        if (int(byte(DifficultySetting)) >= 2)
        {
            pController.UpdateMPMapsCompleted(Name(WorldInfo.GetMapName()), TRUE);
        }
    }
    else
    {
        SetTimer(0.100000001, FALSE, 'DeferredGrantAccomplishments', );
    }
}
public final simulated function DisplaySquadMedal(int nMedal)
{
    local string MedalName;
    local int ScoreBonus;
    local BioHintSystem HintSystem;
    local string Icon;
    
    ClearCustomTokens();
    SetCustomToken(0, string(ScoreManager.SquadMedalDefinitions[nMedal].Threshold));
    MedalName = string(ScoreManager.SquadMedalDefinitions[nMedal].MedalName);
    ClearCustomTokens();
    ScoreBonus = ScoreManager.SquadMedalDefinitions[nMedal].Score;
    Icon = ScoreManager.SquadMedalDefinitions[nMedal].Icon;
    GetEventTicker().AddTickerEntry((MedalName @ "+") $ ScoreBonus);
    HintSystem = BioHintSystem(BioWorldInfo(WorldInfo).GetLocalPlayerController().HintSystem);
    HintSystem.AddNotification_MPMedalGranted(MedalName, ScoreBonus, Icon);
}
public function array<int> GetActivePlayerIDs()
{
    local array<int> ActiveIDs;
    local PlayerReplicationInfo PRI;
    local SFXPRIMP CastPRI;
    
    foreach PRIArray(PRI, )
    {
        CastPRI = SFXPRIMP(PRI);
        if (CastPRI != None && CastPRI.IsPlayer())
        {
            ActiveIDs.AddItem(CastPRI.PlayerID);
        }
    }
    return ActiveIDs;
}
public simulated function int GetChallengeTypeIndex()
{
    return DifficultySetting;
}
public simulated function OnGameStatusChanged()
{
    switch (GameStatus)
    {
        case EGameStatus.GS_PendingMatch:
            if (Role == ENetRole.ROLE_SimulatedProxy)
            {
                bIsJoinInProgress = FALSE;
            }
            break;
        case EGameStatus.GS_MatchOver_Win:
            DeferredGrantAccomplishments();
        case EGameStatus.GS_MatchOver_Lost:
            DeferredSetRichPresence();
            break;
        case EGameStatus.GS_MatchInProgress:
            DeferredSetRichPresence();
            break;
        default:
    }
}
public simulated function OnSquadMedalsChanged()
{
    local int i;
    
    for (i = 0; i < 10; i++)
    {
        if (SquadMedals[i] != SquadMedalsCache[i])
        {
            DisplaySquadMedal(SquadMedals[i]);
            SquadMedalsCache[i] = SquadMedals[i];
        }
    }
}
public function SetGameStatus(EGameStatus NewGameStatus)
{
    GameStatus = NewGameStatus;
    OnGameStatusChanged();
    bForceNetUpdate = TRUE;
}

replication
{
    if (bNetDirty && Role == ENetRole.ROLE_Authority)
        SquadMedals, MapSetting, EnemySetting, DifficultySetting, SkynetGameID, TeamScoreOffset, MatchStartTime, PrivacySetting, bRandomMap, bRandomEnemy, GameStatus;
    
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    Begin Template Class=RvrClientEffectManager Name=CEManager
    End Template
    Begin Template Class=RvrClientEffectPool Name=CEPool
    End Template
    Begin Object Class=SFXGameConfigMP Name=GameConfigBase1
    End Object
    fUpdateScoreInterval = 1.0
    MaxPlayersAllowedMP = 4
    bIsJoinInProgress = TRUE
    DifficultyHandlerClass = Class'SFXDifficultyHandlerMP'
    VocManagerClass = Class'SFXVocalizationManagerMP'
    gameconfig = GameConfigBase1
    m_pClientEffectManager = CEManager
    m_pClientEffectPool = CEPool
    bCanSpawnHenchmen = FALSE
    bPlayerCanChangeSquad = FALSE
    bPauseForCommand = FALSE
    bAllowTimeDilation = FALSE
    bAlwaysInCombat = TRUE
    bMultiplayer = TRUE
    bIsMultiplayerCharacter = TRUE
    bCanShowMap = FALSE
    bCanShowCodex = FALSE
    bCanShowJournal = FALSE
    bCanSave = FALSE
    NetPriority = 3.0
}