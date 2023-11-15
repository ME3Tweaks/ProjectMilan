Class SFXGUIMovieMP extends SFXGUIMovie
    config(UI);

// Types
struct MatchSettingsDisplayInfo 
{
    var string MapName;
    var string EnemyName;
    var string ChallengeName;
    var string Wave;
    var int MapId;
    var int Enemy;
    var int Challenge;
    var int Time;
    var bool isPrivate;
    var bool bRandomMap;
    var bool bRandomEnemy;
    var bool bMissionSuccessful;
};

// Functions
public final function MPMapInfo GetMapInfo(int MapId)
{
    return Class'SFXOnlineGameSettings'.static.GetMapByID(MapId);
}
public final function array<MPChallengeInfo> GetChallengeTypes()
{
    return Class'SFXOnlineGameSettings'.default.ChallengeTypes;
}
public final function array<MPChallengeInfo> GetChallengeTypesForSearching()
{
    local array<MPChallengeInfo> ChallengeTypes;
    local MPChallengeInfo AnyChallenge;
    
    ChallengeTypes = Class'SFXOnlineGameSettings'.default.ChallengeTypes;
    if (ChallengeTypes.Length > 1)
    {
        AnyChallenge.Id = 3;
        AnyChallenge.Name = Class'SFXOnlineGameSettings'.default.srAnyChallenge;
        AnyChallenge.Image = Class'SFXOnlineGameSettings'.default.AnyChallengeImage;
        ChallengeTypes.InsertItem(0, AnyChallenge);
    }
    return ChallengeTypes;
}
public final function array<MPEnemyInfo> GetEnemyTypes()
{
    return Class'SFXOnlineGameSettings'.default.EnemyTypes;
}
public final function array<MPEnemyInfo> GetEnemyTypesForSearching()
{
    local array<MPEnemyInfo> EnemyTypes;
    local int UnknownEnemyIndex;
    local MPEnemyInfo AnyEnemy;
    
    EnemyTypes = Class'SFXOnlineGameSettings'.default.EnemyTypes;
    if (EnemyTypes.Length > 1)
    {
        AnyEnemy.Id = 4;
        AnyEnemy.Name = Class'SFXOnlineGameSettings'.default.srAnyEnemy;
        AnyEnemy.Image = Class'SFXOnlineGameSettings'.default.AnyEnemyImage;
        EnemyTypes.InsertItem(0, AnyEnemy);
    }
    UnknownEnemyIndex = EnemyTypes.Find('Id', 0);
    if (UnknownEnemyIndex != -1)
    {
        EnemyTypes.Remove(UnknownEnemyIndex, 1);
    }
    return EnemyTypes;
}
public final function SFXLobbyFlow GetLobbyFlow()
{
    return SFXPlayerControllerMP(GetPC()).LobbyFlow;
}
public final function SFXGameInfoMP_Lobby GetLobbyGameInfo()
{
    return SFXGameInfoMP_Lobby(oWorldInfo.Game);
}
public final function SFXGRIMP_Lobby GetLobbyGRI()
{
    return SFXGRIMP_Lobby(oWorldInfo.GRI);
}
public final function array<MPMapInfo> GetMapList()
{
    GetLobbyFlow().RefreshMapList();
    return GetLobbyFlow().MapList;
}
public final function array<MPMapInfo> GetMapListForSearching()
{
    local array<MPMapInfo> MapList;
    local int UnknownMapIndex;
    local MPMapInfo AnyMap;
    
    GetLobbyFlow().RefreshMapList();
    MapList = GetLobbyFlow().MapList;
    if (MapList.Length > 1)
    {
        AnyMap.Id = -1;
        AnyMap.PrettyName = Class'SFXOnlineGameSettings'.default.srAnyMap;
        AnyMap.Image = Class'SFXOnlineGameSettings'.default.AnyMapImage;
        AnyMap.EveryoneHasThisMap = TRUE;
        MapList.InsertItem(0, AnyMap);
    }
    UnknownMapIndex = MapList.Find('Id', 0);
    if (UnknownMapIndex != -1)
    {
        MapList.Remove(UnknownMapIndex, 1);
    }
    return MapList;
}
public final function MatchSettingsDisplayInfo GetMatchSettings()
{
    local MatchSettingsDisplayInfo Settings;
    local SFXGRIMP_Lobby LobbyGRI;
    local MPMapInfo MapInfo;
    local array<MPEnemyInfo> EnemyTypes;
    local array<MPChallengeInfo> ChallengeTypes;
    local int EnemyIndex;
    local int ChallengeIndex;
    
    LobbyGRI = GetLobbyGRI();
    if (LobbyGRI != None)
    {
        EnemyTypes = GetEnemyTypes();
        ChallengeTypes = GetChallengeTypes();
        MapInfo = GetMapInfo(LobbyGRI.MapSetting);
        Settings.isPrivate = LobbyGRI.IsPrivateMatch();
        Settings.MapId = LobbyGRI.MapSetting;
        Settings.Enemy = LobbyGRI.EnemySetting;
        Settings.Challenge = LobbyGRI.DifficultySetting;
        EnemyIndex = EnemyTypes.Find('Id', LobbyGRI.EnemySetting);
        ChallengeIndex = ChallengeTypes.Find('Id', LobbyGRI.DifficultySetting);
        Settings.MapName = GetUIString(MapInfo.PrettyName);
        Settings.EnemyName = GetUIString(EnemyTypes[EnemyIndex].Name);
        Settings.ChallengeName = GetUIString(ChallengeTypes[ChallengeIndex].Name);
        Settings.bRandomMap = LobbyGRI.bRandomMap;
        Settings.bRandomEnemy = LobbyGRI.bRandomEnemy;
    }
    return Settings;
}
public final function SFXPRIMP GetPRIMP()
{
    return SFXPRIMP(GetPC().PlayerReplicationInfo);
}
public final function array<MPPrivacyInfo> GetPrivacyTypes()
{
    return Class'SFXOnlineGameSettings'.default.PrivacyTypes;
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
}