// Source: ME3, Patch_SFXGUIMovieMP
// Decompiled 10/12/2026 9:47:53 AM
// Changes:
// Add support for keeping references so garbage collector doesn't nuke some dynamic loaded dependencies
Class SFXGUIMovieMP extends SFXGUIMovie
    config(UI);

struct MatchSettingsDisplayInfo 
{
    var string MapName;
    var string EnemyName;
    var string ChallengeName;
    var string Wave;
    var int privacy;
    var int MapId;
    var int Enemy;
    var int Challenge;
    var int Time;
    var bool isPrivate;
    var bool bRandomMap;
    var bool bRandomEnemy;
    var bool bMissionSuccessful;
    
    structdefaultproperties
    {
        privacy = 0
    }
};

// MILAN CHANGE - Keep dynamically loaded movies alive while this screen
// can request their images. Resource-name strings and Scaleform's parsed movie data
// do not keep the GFxMovieInfo References textures alive across garbage collection.
var transient array<GFxMovieInfo> RetainedResources;
var transient array<string> FailedResources;

public final function RetainResource(string ResourceName)
{
    local int idx;
    local GFxMovieInfo Resource;

    if (ResourceName == "")
    {
        return;
    }
    for (idx = 0; idx < RetainedResources.Length; ++idx)
    {
        if (RetainedResources[idx] != None && PathName(RetainedResources[idx]) ~= ResourceName)
        {
            return;
        }
    }

    Resource = GFxMovieInfo(Class'SFXEngine'.static.LoadSeekFreeObjectBlocking(ResourceName, Class'GFxMovieInfo'));
    if (Resource != None)
    {
        RetainedResources.AddItem(Resource);
    }
    else if (FailedResources.Find(ResourceName) == -1)
    {
        FailedResources.AddItem(ResourceName);
        WarnInternal("Unable to retain resource: " $ ResourceName);
    }
}

public final function SFXOnlineGameSettings.MPMapInfo GetMapInfo(int MapId)
{
    return Class'SFXOnlineGameSettings'.static.GetMapByID(MapId);
}
public final function array<SFXOnlineGameSettings.MPChallengeInfo> GetChallengeTypes()
{
    return Class'SFXOnlineGameSettings'.default.ChallengeTypes;
}
public final function array<SFXOnlineGameSettings.MPChallengeInfo> GetChallengeTypesForSearching()
{
    local array<SFXOnlineGameSettings.MPChallengeInfo> ChallengeTypes;
    local SFXOnlineGameSettings.MPChallengeInfo AnyChallenge;
    
    ChallengeTypes = Class'SFXOnlineGameSettings'.default.ChallengeTypes;
    if (ChallengeTypes.Length > 1)
    {
        AnyChallenge.Id = 127;
        AnyChallenge.Name = Class'SFXOnlineGameSettings'.default.srAnyChallenge;
        AnyChallenge.Image = Class'SFXOnlineGameSettings'.default.AnyChallengeImage;
        ChallengeTypes.InsertItem(0, AnyChallenge);
    }
    return ChallengeTypes;
}
public final function array<SFXOnlineGameSettings.MPEnemyInfo> GetEnemyTypes()
{
    return Class'SFXOnlineGameSettings'.default.EnemyTypes;
}
public final function array<SFXOnlineGameSettings.MPEnemyInfo> GetEnemyTypesForSearching()
{
    local array<SFXOnlineGameSettings.MPEnemyInfo> EnemyTypes;
    local int UnknownEnemyIndex;
    local SFXOnlineGameSettings.MPEnemyInfo AnyEnemy;
    
    EnemyTypes = Class'SFXOnlineGameSettings'.default.EnemyTypes;
    if (EnemyTypes.Length > 1)
    {
        AnyEnemy.Id = 127;
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
public final function array<SFXOnlineGameSettings.MPMapInfo> GetMapList()
{
    GetLobbyFlow().RefreshMapList();
    return GetLobbyFlow().MapList;
}
public final function array<SFXOnlineGameSettings.MPMapInfo> GetMapListForSearching()
{
    local array<SFXOnlineGameSettings.MPMapInfo> MapList;
    local int UnknownMapIndex;
    local SFXOnlineGameSettings.MPMapInfo AnyMap;
    
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
public final function SFXGUIMovieMP.MatchSettingsDisplayInfo GetMatchSettings()
{
    local SFXGUIMovieMP.MatchSettingsDisplayInfo Settings;
    local SFXGRIMP_Lobby LobbyGRI;
    local SFXOnlineGameSettings.MPMapInfo MapInfo;
    local array<SFXOnlineGameSettings.MPEnemyInfo> EnemyTypes;
    local array<SFXOnlineGameSettings.MPChallengeInfo> ChallengeTypes;
    local int EnemyIndex;
    local int ChallengeIndex;
    
    LobbyGRI = GetLobbyGRI();
    if (LobbyGRI != None)
    {
        EnemyTypes = GetEnemyTypes();
        ChallengeTypes = GetChallengeTypes();
        MapInfo = GetMapInfo(LobbyGRI.MapSetting);
        Settings.isPrivate = LobbyGRI.IsPrivateMatch();
        Settings.privacy = LobbyGRI.GetPrivacy();
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
public final function array<SFXOnlineGameSettings.MPPrivacyInfo> GetPrivacyTypes()
{
    return Class'SFXOnlineGameSettings'.default.PrivacyTypes;
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
}