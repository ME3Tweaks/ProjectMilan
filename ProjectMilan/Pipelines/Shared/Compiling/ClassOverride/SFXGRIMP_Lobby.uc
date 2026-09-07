// Source: ME3, Patch_SFXGRIMP_Lobby
// Decompiled 9/4/2026 7:37:42 AM
Class SFXGRIMP_Lobby extends SFXGRI
    config(Game);

struct LobbyMatchTimerInfo 
{
    var float fMatchStartTimerValue;
    var float fAllPlayersReadyTimerDuration;
    var bool bMatchStartTimerRunning;
};

var repnotify string LobbyStatusString;
var array<Name> aTimerSounds;
var repnotify LobbyMatchTimerInfo MatchTimerInfo;
var repnotify Name LobbyState;
var Name nmCurrentTimerSound;
var int NumPlayerSlots;
var int NumReadyPlayers;
var SFXPRIMP LeaderPRI;
var repnotify int PrivacySetting;
var repnotify int MapSetting;
var repnotify int EnemySetting;
var repnotify int DifficultySetting;
var config stringref srLoading;
var config stringref srWaitingForPlayers;
var config stringref srStartingMatch;
var config stringref srExiting;
var config stringref srMatchStartCountdown;
var config stringref srMapChangedDueToDLCMismatch;
var config stringref srOK;
var bool bRandomMap;
var bool bRandomEnemy;

public final simulated function MPMapInfo GetMapInfo(int MapId)
{
    return Class'SFXOnlineGameSettings'.static.GetMapByID(MapId);
}
public final simulated function int GetPrivacy()
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
    else if (VarName == 'PrivacySetting' || VarName == 'MapSetting' || VarName == 'EnemySetting' || VarName == 'DifficultySetting')
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
    else if (VarName == 'LobbyStatusString' || VarName == 'NumReadyPlayers' || VarName == 'MatchTimerInfo')
    {
        if (VarName == 'MatchTimerInfo')
        {
            UpdateLobbyTimerSound();
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
public final simulated function bool IsPrivateMatch()
{
    return PrivacySetting != 0;
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
public final function SetMatchStartTimer(bool bTimerRunning, float fTimerValue, float fAllPlayersReadyTimerDuration)
{
    MatchTimerInfo.bMatchStartTimerRunning = bTimerRunning;
    MatchTimerInfo.fMatchStartTimerValue = fTimerValue;
    MatchTimerInfo.fAllPlayersReadyTimerDuration = fAllPlayersReadyTimerDuration;
    UpdateLobbyTimerSound();
    if (!MatchTimerInfo.bMatchStartTimerRunning && (BioWorldInfo(WorldInfo) == None || BioWorldInfo(WorldInfo).GetAutoBotsEnabled() == FALSE))
    {
        Class'SFXEngine'.static.ValidateNetObjectIndex();
    }
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
public simulated function UpdateLobbyTimerSound()
{
    local bool LocalPlayerIsNotReady;
    local Name NewTimerSound;
    local Name TimerSoundIter;
    
    LocalPlayerIsNotReady = SFXPRIMP(GetALocalPlayerController().PlayerReplicationInfo).ReadyInLobby;
    if (MatchTimerInfo.bMatchStartTimerRunning)
    {
        if (MatchTimerInfo.fMatchStartTimerValue <= MatchTimerInfo.fAllPlayersReadyTimerDuration)
        {
            NewTimerSound = 'MPLobbyOverlayTimer';
        }
        else if (!LocalPlayerIsNotReady)
        {
            NewTimerSound = 'MPLobbyLastManTimer';
        }
    }
    if (nmCurrentTimerSound != NewTimerSound)
    {
        nmCurrentTimerSound = NewTimerSound;
        foreach aTimerSounds(TimerSoundIter, )
        {
            if (nmCurrentTimerSound == TimerSoundIter)
            {
                Class'SFXGUIInteraction'.static.GetInstance().PlayGuiSound(TimerSoundIter);
            }
            else
            {
                Class'SFXGUIInteraction'.static.GetInstance().StopGuiSound(TimerSoundIter);
            }
        }
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
public final function BuildCombinedMapArray()
{
    local int MAX_MAPS;
    local int MapId;
    local int PRIIndex;
    local SFXPRIMP PRI;
    
    // MILAN CHANGE - 09/06/2026 - Mgamerz
    // Make this 255 instead of 30
    MAX_MAPS = 255;
    // END MILAN
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
public function bool CanForceLastManReady()
{
    local int NumReady;
    local int NumPlayers;
    local int idx;
    local SFXPRIMP PRIIter;
    
    NumReady = GetNumReadyPlayers();
    NumPlayers = GetNumPlayers();
    if (NumPlayers != NumPlayerSlots || NumPlayers - NumReady != 1)
    {
        return FALSE;
    }
    for (idx = 0; idx < PRIArray.Length; ++idx)
    {
        PRIIter = SFXPRIMP(PRIArray[idx]);
        if (PRIIter != None && !PRIIter.ReadyInLobby)
        {
            if (PRIIter.GetStoreIsOpen())
            {
                return FALSE;
                continue;
            }
            return TRUE;
        }
    }
    return FALSE;
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
    if (MatchTimerInfo.bMatchStartTimerRunning)
    {
        SetCustomToken(0, string(FCeil(MatchTimerInfo.fMatchStartTimerValue)));
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

simulated state Exiting 
{
    public simulated function BeginState(Name PreviousStateName)
    {
        Class'SFXGUIInteraction'.static.GetInstance().HackReloadMainMenu();
    }
    
    stop;
};
simulated state StartingMatch 
{
    public simulated function BeginState(Name PreviousStateName)
    {
        GetPC().LobbyFlow.RefreshLobbyScreen();
        Class'SFXGUIInteraction'.static.GetInstance().StopGuiSound('Play_mus_mp');
    }
    
    stop;
};
simulated state WaitingForPlayers 
{
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
    
    stop;
};
simulated state MultiplayerMenu 
{
    public simulated function bool CanInteract()
    {
        return TRUE;
    }
    
    stop;
};
simulated auto state Startup 
{
    
    stop;
};

replication
{
    if (bNetDirty && Role == ENetRole.ROLE_Authority)
        LobbyStatusString, MatchTimerInfo, LobbyState, NumPlayerSlots, NumReadyPlayers, LeaderPRI, PrivacySetting, MapSetting, EnemySetting, DifficultySetting, bRandomMap, bRandomEnemy;
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
    aTimerSounds = ('MPLobbyLastManTimer', 'MPLobbyOverlayTimer')
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