Class SFXGRIMP_Lobby extends SFXGRI
    config(Game);

// Variables
var repnotify string LobbyStatusString;
var repnotify Name LobbyState;
var int NumPlayerSlots;
var int NumReadyPlayers;
var SFXPRIMP LeaderPRI;
var repnotify int MapSetting;
var repnotify int EnemySetting;
var repnotify int DifficultySetting;
var repnotify float MatchStartTimer;
var config stringref srLoading;
var config stringref srWaitingForPlayers;
var config stringref srStartingMatch;
var config stringref srExiting;
var config stringref srMatchStartCountdown;
var config stringref srMapChangedDueToDLCMismatch;
var config stringref srOK;
var repnotify bool PrivacySetting;
var bool bRandomMap;
var bool bRandomEnemy;
var repnotify bool bMatchStartTimerRunning;

// Functions
public final simulated function MPMapInfo GetMapInfo(int MapId)
{
    return Class'SFXOnlineGameSettings'.static.GetMapByID(MapId);
}
public final simulated function bool IsPrivateMatch()
{
    return PrivacySetting;
}
public simulated function PostBeginPlay()
{
    Super.PostBeginPlay();
    SaveDataForHostMigration();
}
public event simulated function ReplicatedEvent(Name VarName)
{
    Super(GameReplicationInfo).ReplicatedEvent(VarName);
    if (VarName == 'LobbyState')
    {
        GotoState(LobbyState, , , );
    }
    else if (((VarName == 'PrivacySetting' || VarName == 'MapSetting') || VarName == 'EnemySetting') || VarName == 'DifficultySetting')
    {
        if (GetPC().LobbyFlow != None)
        {
            GetPC().LobbyFlow.RefreshLobbyScreen();
            GetPC().LobbyFlow.OnMatchSettingsChanged();
            if (VarName == 'MapSetting')
            {
                GetPC().LobbyFlow.ChangeMapMusic(MapSetting);
            }
        }
        SaveDataForHostMigration();
    }
    else if (((VarName == 'LobbyStatusString' || VarName == 'NumReadyPlayers') || VarName == 'bMatchStartTimerRunning') || VarName == 'MatchStartTimer')
    {
        if (VarName == 'bMatchStartTimerRunning')
        {
            if (bMatchStartTimerRunning)
            {
                Class'SFXGUIInteraction'.static.GetInstance().PlayGuiSound('MPLobbyOverlayTimer');
            }
            else
            {
                Class'SFXGUIInteraction'.static.GetInstance().StopGuiSound('MPLobbyOverlayTimer');
            }
            Class'SFXEngine'.static.ValidateNetObjectIndex();
        }
        if (GetPC().LobbyFlow != None)
        {
            GetPC().LobbyFlow.RefreshLobbyStatusBars();
        }
    }
}
public simulated function Tick(float DeltaTime)
{
    if (Role == ENetRole.ROLE_Authority)
    {
        LobbyState = GetStateName();
    }
}
public simulated function SFXPlayerControllerMP GetPC()
{
    return SFXPlayerControllerMP(BioWorldInfo(WorldInfo).GetLocalPlayerController());
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
public final simulated function int GetNumPlayers()
{
    return PRIArray.Length;
}
public final function OnlineGameInterface GetOnlineGameInterface()
{
    local OnlineSubsystem OnlineSub;
    
    OnlineSub = Class'GameEngine'.static.GetOnlineSubsystem();
    if (OnlineSub != None)
    {
        return OnlineSub.GameInterface;
    }
    return None;
}
public simulated function bool IsMultiplayerGame()
{
    return TRUE;
}
public simulated function ReturnToMainMenu()
{
    GotoState('Exiting', , , );
}
public final function BuildCombinedMapArray()
{
    local int MAX_MAPS;
    local int MapId;
    local int PRIIndex;
    local SFXPRIMP PRI;
    
    MAX_MAPS = 30;
    PRI = SFXPRIMP(GetPC().PlayerReplicationInfo);
    for (MapId = 0; MapId < MAX_MAPS; ++MapId)
    {
        PRI.CombinedMapArray[MapId] = 0;
    }
    for (PRIIndex = 0; PRIIndex < PRIArray.Length; ++PRIIndex)
    {
        for (MapId = 0; MapId < MAX_MAPS; ++MapId)
        {
            if (int(SFXPRIMP(PRIArray[PRIIndex]).LocalMapArray[MapId]) != 0)
            {
                PRI.CombinedMapArray[MapId] = byte(int(PRI.CombinedMapArray[MapId]) + (1 << PRIIndex));
            }
        }
    }
    for (PRIIndex = 0; PRIIndex < PRIArray.Length; ++PRIIndex)
    {
        for (MapId = 0; MapId < MAX_MAPS; ++MapId)
        {
            SFXPRIMP(PRIArray[PRIIndex]).CombinedMapArray[MapId] = PRI.CombinedMapArray[MapId];
        }
    }
}
public simulated function bool CanInteract()
{
    return FALSE;
}
public final simulated function array<MPChallengeInfo> GetChallengeTypes()
{
    return Class'SFXOnlineGameSettings'.default.ChallengeTypes;
}
public final simulated function array<MPEnemyInfo> GetEnemyTypes()
{
    return Class'SFXOnlineGameSettings'.default.EnemyTypes;
}
public simulated function string GetLobbyStatusString()
{
    if (bMatchStartTimerRunning)
    {
        SetCustomToken(0, string(FCeil(MatchStartTimer)));
        return GetTokenisedString(srMatchStartCountdown);
    }
    else
    {
        return string(srWaitingForPlayers);
    }
}
public final simulated function int GetNumReadyPlayers()
{
    local int idx;
    
    NumReadyPlayers = 0;
    for (idx = 0; idx < PRIArray.Length; ++idx)
    {
        if (SFXPRIMP(PRIArray[idx]).ReadyInLobby)
        {
            NumReadyPlayers++;
        }
    }
    return NumReadyPlayers;
}
public simulated function SaveDataForHostMigration()
{
    local SFXHostMigration HostMigration;
    
    HostMigration = Class'SFXHostMigration'.static.GetHostMigration();
    if (HostMigration != None)
    {
        HostMigration.SaveGRI(Self);
    }
}
public final function SetMatchStartTimer(bool bTimerRunning, float fTimerValue)
{
    if (!bMatchStartTimerRunning && bTimerRunning)
    {
        Class'SFXGUIInteraction'.static.GetInstance().PlayGuiSound('MPLobbyOverlayTimer');
    }
    else if (bMatchStartTimerRunning && !bTimerRunning)
    {
        Class'SFXGUIInteraction'.static.GetInstance().StopGuiSound('MPLobbyOverlayTimer');
    }
    if (bMatchStartTimerRunning == FALSE && (BioWorldInfo(WorldInfo) == None || BioWorldInfo(WorldInfo).GetAutoBotsEnabled() == FALSE))
    {
        Class'SFXEngine'.static.ValidateNetObjectIndex();
    }
    bMatchStartTimerRunning = bTimerRunning;
    MatchStartTimer = fTimerValue;
    if (GetPC().LobbyFlow != None)
    {
        GetPC().LobbyFlow.RefreshLobbyStatusBars();
    }
}
public final function ShowMapChangedDueToDLCMismatchPopup()
{
    local BioSFHandler_MessageBox messageBox;
    local BioMessageBoxOptionalParams Params;
    
    messageBox = GetPC().GetSFXUIController().CreateMessageBox(GetPC());
    Params.srAText = srOK;
    messageBox.DisplayMessageBox(srMapChangedDueToDLCMismatch, Params);
}
public final function UnreadyAllPlayers()
{
    local int idx;
    
    for (idx = 0; idx < PRIArray.Length; ++idx)
    {
        SFXPRIMP(PRIArray[idx]).SetReadyInLobby(FALSE);
    }
}
public final function UpdateMapArrays()
{
    local bool bSelectedMapIsStillAvailable;
    
    UpdatePlayerListOrder();
    BuildCombinedMapArray();
    bSelectedMapIsStillAvailable = GetPC().LobbyFlow.DoesEveryoneHaveMap(MapSetting);
    if (!bSelectedMapIsStillAvailable)
    {
        SFXGameInfoMP_Lobby(WorldInfo.Game).ChangeMatchSettings(PrivacySetting, 0, TRUE, EnemySetting, bRandomEnemy, DifficultySetting);
        ShowMapChangedDueToDLCMismatchPopup();
    }
}
public final function UpdatePlayerListOrder()
{
    local int idx;
    
    for (idx = 0; idx < PRIArray.Length; ++idx)
    {
        if (PRIArray[idx].IsLocalPlayerPRI())
        {
            LeaderPRI = SFXPRIMP(PRIArray[idx]);
        }
        SFXPRIMP(PRIArray[idx]).LobbyListOrder = idx;
    }
}

// States
simulated state Exiting 
{
    // State Functions
    public simulated function BeginState(Name PreviousStateName)
    {
        Class'SFXGUIInteraction'.static.GetInstance().HackReloadMainMenu();
    }
    
    // State code
    stop;
};
simulated state StartingMatch 
{
    // State Functions
    public simulated function BeginState(Name PreviousStateName)
    {
        GetPC().LobbyFlow.RefreshLobbyScreen();
        Class'SFXGUIInteraction'.static.GetInstance().StopGuiSound('Play_mus_mp');
    }
    
    // State code
    stop;
};
simulated state WaitingForPlayers 
{
    // State Functions
    public simulated function RemovePRI(PlayerReplicationInfo PRI)
    {
        Super(GameReplicationInfo).RemovePRI(PRI);
        if (GetPC().LobbyFlow != None)
        {
            GetPC().LobbyFlow.OnPlayerLeave(PRI);
        }
        if (IsServer())
        {
            UpdatePlayerListOrder();
            UpdateMapArrays();
            SFXGameInfoMP_Lobby(WorldInfo.Game).UpdateKickVotes();
            SFXGameInfoMP_Lobby(WorldInfo.Game).CheckAllPlayersReady();
        }
    }
    public simulated function AddPRI(PlayerReplicationInfo PRI)
    {
        Super(GameReplicationInfo).AddPRI(PRI);
        if (GetPC().LobbyFlow != None)
        {
            GetPC().LobbyFlow.OnPlayerEnter(PRI);
            SFXGameInfoMP_Lobby(WorldInfo.Game).ClearTimer('ShowStrictNatWarning');
        }
        if (IsServer())
        {
            UpdatePlayerListOrder();
            SFXGameInfoMP_Lobby(WorldInfo.Game).UpdateKickVotes();
            SFXGameInfoMP_Lobby(WorldInfo.Game).CheckAllPlayersReady();
        }
    }
    public simulated function bool CanInteract()
    {
        return TRUE;
    }
    public simulated function BeginState(Name PreviousStateName)
    {
        if (IsServer())
        {
            UpdatePlayerListOrder();
        }
    }
    
    // State code
    stop;
};
simulated state MultiplayerMenu 
{
    // State Functions
    public simulated function bool CanInteract()
    {
        return TRUE;
    }
    
    // State code
    stop;
};
simulated auto state Startup 
{
    // State Functions
    
    // State code
    stop;
};

replication
{
    if (bNetDirty && Role == ENetRole.ROLE_Authority)
        LobbyStatusString, LobbyState, NumPlayerSlots, NumReadyPlayers, LeaderPRI, MapSetting, EnemySetting, DifficultySetting, MatchStartTimer, PrivacySetting, bRandomMap, bRandomEnemy, bMatchStartTimerRunning;
    
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
    srLoading = $608467
    srWaitingForPlayers = $608468
    srStartingMatch = $608469
    srExiting = $608470
    srMatchStartCountdown = $633549
    srMapChangedDueToDLCMismatch = $702536
    srOK = $152938
    bRandomMap = TRUE
    bRandomEnemy = TRUE
    gameconfig = GameConfigBase1
    m_pClientEffectManager = CEManager
    m_pClientEffectPool = CEPool
    bCanSpawnHenchmen = FALSE
    bPlayerCanChangeSquad = FALSE
    bAllowTimeDilation = FALSE
    bIsMultiplayerCharacter = TRUE
}