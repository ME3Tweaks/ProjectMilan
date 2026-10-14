// MILAN CHANGE
// 09/21/2026 - Mgamerz
// Add a new member to MPEnemyInfo native struct IsRandomOption
Class SFXOnlineGameSettings extends OnlineGameSettings
    native
    config(Game);

struct native MPChallengeInfo 
{
    var string Image;
    var int Id;
    var stringref Name;
    var stringref AllCapsName;
};
struct native MPEnemyInfo 
{
    var string Image;
    var string WaveClass;
    var int Id;
    var stringref Name;
    var stringref AllCapsName;
    // MILAN CHANGE
    // This struct appears unused in native and is config defined
    var bool IsRandomOption;
    // END MILAN CHANGE
};
struct native MPPrivacyInfo 
{
    var string Image;
    var int Id;
    var stringref Name;
    var stringref AllCapsName;
};
struct native MPMapInfo 
{
    var string PackageName;
    var string Image;
    var Vector GalaxyAtWarMapPosition;
    var Name MusicEventName;
    var int Id;
    var stringref PrettyName;
    var stringref Description;
    var stringref GalaxyAtWarMapSubtitle;
    var bool EveryoneHasThisMap;
};
enum EMatchPrivacySetting
{
    PRIVACY_PUBLIC,
    PRIVACY_PRIVATE,
    PRIVACY_FRIENDS,
};
enum EPersonalMatchSettingsType
{
    SETTINGS_FOR_SEARCH,
    SETTINGS_FOR_CREATE,
};

var UniqueNetId invitedUserId;
var config array<MPMapInfo> MasterMapList;
var config array<string> AvailableMaps;
var config array<MPPrivacyInfo> PrivacyTypes;
var config array<MPEnemyInfo> EnemyTypes;
var config array<MPChallengeInfo> ChallengeTypes;
var config string AnyMapImage;
var config string AnyEnemyImage;
var config string AnyChallengeImage;
var databinding string mME3MapName;
var config stringref srAnyMap;
var config stringref srAnyEnemy;
var config stringref srAnyChallenge;
var int EnemyType;
var bool mMapIsRequired;
var bool mCreateNewMatch;
var bool mFromGalaxyMap;
var SFXOnlineGameDifficulty Difficulty;
var EMatchPrivacySetting mPrivacySetting;

public event function SFXOnlineGameSettings Copy()
{
    local SFXOnlineGameSettings Copy;
    
    Copy = new Class'SFXOnlineGameSettings';
    Copy.mPrivacySetting = mPrivacySetting;
    Copy.mME3MapName = mME3MapName;
    Copy.mMapIsRequired = mMapIsRequired;
    Copy.EnemyType = EnemyType;
    Copy.Difficulty = Difficulty;
    Copy.mCreateNewMatch = mCreateNewMatch;
    Copy.mFromGalaxyMap = mFromGalaxyMap;
    Copy.NumPublicConnections = NumPublicConnections;
    Copy.NumPrivateConnections = NumPrivateConnections;
    Copy.NumOpenPublicConnections = NumOpenPublicConnections;
    Copy.NumOpenPrivateConnections = NumOpenPrivateConnections;
    Copy.invitedUserId = invitedUserId;
    Copy.OwningPlayerId = OwningPlayerId;
    return Copy;
}
public static event function MPMapInfo GetMapByServerMapID(string serverMapID)
{
    local int serverMapIdNum;
    
    serverMapIdNum = int(Mid(serverMapID, 3, ));
    return GetMapByID(serverMapIdNum);
}
public static event function int GetMasterMapID(string PackageName)
{
    local int idx;
    
    idx = default.MasterMapList.Find('PackageName', PackageName);
    if (idx != -1)
    {
        return default.MasterMapList[idx].Id;
    }
    else
    {
        return -1;
    }
}
public event function EMatchPrivacySetting GetPrivacy()
{
    return mPrivacySetting;
}
// MILAN CHANGE - 10/09/2026 - Mgamerz
// The lobby size is NumPublicConnections + NumPrivateConnections, all public or all private by
// privacy. SetPrivacy keeps the size instead of resetting it to 4, which was the ME3 default.
// These settings are kept between lobby/match, so SFXGameInfoMP.InitGame reads the size from here.
// MilanHost writes the counts when it reopens a migrated lobby.
public event function SetPrivacy(EMatchPrivacySetting privacy)
{
    local int LobbySize;

    LobbySize = GetLobbySize();
    mPrivacySetting = privacy;
    SetLobbySize(LobbySize);
}
public function SetLobbySize(int LobbySize)
{
    LobbySize = Max(LobbySize, 1);
    NumPublicConnections = mPrivacySetting == EMatchPrivacySetting.PRIVACY_PRIVATE ? 0 : LobbySize;
    NumPrivateConnections = LobbySize - NumPublicConnections;
}
// 4, the game's original size, for settings that never had one.
public function int GetLobbySize()
{
    if (NumPublicConnections + NumPrivateConnections <= 0)
    {
        return 4;
    }
    return NumPublicConnections + NumPrivateConnections;
}
// END MILAN CHANGE
public static function bool ValidateMapName(string MapName)
{
    return default.AvailableMaps.Find(MapName) != -1;
}
public static function EnsureMatchSettingsAreValid(EPersonalMatchSettingsType eType, out int PrivacySetting, out int MapSetting, out int EnemySetting, out int ChallengeSetting)
{
    local array<MPEnemyInfo> EnemyList;
    local array<MPChallengeInfo> ChallengeList;
    local bool bMapInList;
    local bool bEnemyInList;
    local bool bChallengeInList;
    local string mapPackageName;
    
    EnemyList = Class'SFXOnlineGameSettings'.default.EnemyTypes;
    ChallengeList = Class'SFXOnlineGameSettings'.default.ChallengeTypes;
    mapPackageName = GetMapByID(MapSetting).PackageName;
    bMapInList = default.AvailableMaps.Find(mapPackageName) != -1;
    bEnemyInList = EnemyList.Find('Id', EnemySetting) != -1;
    bChallengeInList = ChallengeList.Find('Id', ChallengeSetting) != -1;
    if (eType == EPersonalMatchSettingsType.SETTINGS_FOR_SEARCH)
    {
        PrivacySetting = 0;
        if (!bMapInList && MapSetting != -1)
        {
            MapSetting = -1;
        }
        if (!bEnemyInList && EnemySetting != 127)
        {
            EnemySetting = 127;
        }
        if (!bChallengeInList && ChallengeSetting != 127)
        {
            ChallengeSetting = 127;
        }
    }
    else if (eType == EPersonalMatchSettingsType.SETTINGS_FOR_CREATE)
    {
        if (!bMapInList)
        {
            MapSetting = default.MasterMapList[0].Id;
        }
        if (!bEnemyInList)
        {
            EnemySetting = EnemyList[0].Id;
        }
        if (!bChallengeInList)
        {
            ChallengeSetting = ChallengeList[0].Id;
        }
    }
}
public static function MPMapInfo GetMapByID(int MapId)
{
    local int idx;
    local MPMapInfo InvalidMapInfo;
    
    idx = default.MasterMapList.Find('Id', MapId);
    if (idx != -1)
    {
        return default.MasterMapList[idx];
    }
    else
    {
        return InvalidMapInfo;
    }
}
public static function MPMapInfo GetMapByPackageName(string PackageName)
{
    local int idx;
    local MPMapInfo InvalidMapInfo;
    
    idx = default.MasterMapList.Find('PackageName', PackageName);
    if (idx != -1)
    {
        return default.MasterMapList[idx];
    }
    else
    {
        return InvalidMapInfo;
    }
}
public function string ToString()
{
    local string resultStr;
    
    resultStr $= " -mPrivacy: " $ mPrivacySetting;
    resultStr $= " -mME3MapName: " $ mME3MapName;
    resultStr $= " -EnemyType: " $ EnemyType;
    resultStr $= " -Difficulty: " $ Difficulty;
    return resultStr;
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    MasterMapList = ({
                      PackageName = "", 
                      Image = "GUI_MPImages.MatchSettings.OptMapRandom", 
                      GalaxyAtWarMapPosition = {X = 0.0, Y = 0.0, Z = 0.0}, 
                      MusicEventName = 'None', 
                      Id = 0, 
                      PrettyName = $616735, 
                      Description = $616738, 
                      GalaxyAtWarMapSubtitle = $0, 
                      EveryoneHasThisMap = FALSE
                     }, 
                     {
                      PackageName = "BioP_MPCnfl", 
                      Image = "", 
                      GalaxyAtWarMapPosition = {X = 0.0, Y = 0.0, Z = 0.0}, 
                      MusicEventName = 'None', 
                      Id = 1, 
                      PrettyName = $618040, 
                      Description = $618049, 
                      GalaxyAtWarMapSubtitle = $0, 
                      EveryoneHasThisMap = FALSE
                     }, 
                     {
                      PackageName = "BioP_MPDish", 
                      Image = "GUI_MPImages.MatchSettings.OptMapDish", 
                      GalaxyAtWarMapPosition = {X = 424.0, Y = 216.0, Z = 0.0}, 
                      MusicEventName = 'Set_mus_map_mpdish', 
                      Id = 2, 
                      PrettyName = $618041, 
                      Description = $618050, 
                      GalaxyAtWarMapSubtitle = $706337, 
                      EveryoneHasThisMap = FALSE
                     }, 
                     {
                      PackageName = "BioP_MPSlum", 
                      Image = "GUI_MPImages.MatchSettings.OptMapSlum", 
                      GalaxyAtWarMapPosition = {X = 310.0, Y = 403.0, Z = 0.0}, 
                      MusicEventName = 'Set_mus_map_mpslum', 
                      Id = 3, 
                      PrettyName = $618042, 
                      Description = $618051, 
                      GalaxyAtWarMapSubtitle = $706335, 
                      EveryoneHasThisMap = FALSE
                     }, 
                     {
                      PackageName = "BioP_MPTowr", 
                      Image = "GUI_MPImages.MatchSettings.OptMapTowr", 
                      GalaxyAtWarMapPosition = {X = 195.0, Y = 358.0, Z = 0.0}, 
                      MusicEventName = 'Set_mus_map_mptowr', 
                      Id = 4, 
                      PrettyName = $618043, 
                      Description = $618052, 
                      GalaxyAtWarMapSubtitle = $706332, 
                      EveryoneHasThisMap = FALSE
                     }, 
                     {
                      PackageName = "BioP_MPRctr", 
                      Image = "GUI_MPImages.MatchSettings.OptMapRctr", 
                      GalaxyAtWarMapPosition = {X = 111.0, Y = 333.0, Z = 0.0}, 
                      MusicEventName = 'Set_mus_map_mprctr', 
                      Id = 5, 
                      PrettyName = $618044, 
                      Description = $618053, 
                      GalaxyAtWarMapSubtitle = $706336, 
                      EveryoneHasThisMap = FALSE
                     }, 
                     {
                      PackageName = "BioP_MPCer", 
                      Image = "GUI_MPImages.MatchSettings.OptMapCer", 
                      GalaxyAtWarMapPosition = {X = 280.0, Y = 97.0, Z = 0.0}, 
                      MusicEventName = 'Set_mus_map_mpcer', 
                      Id = 7, 
                      PrettyName = $618047, 
                      Description = $618056, 
                      GalaxyAtWarMapSubtitle = $706333, 
                      EveryoneHasThisMap = FALSE
                     }, 
                     {
                      PackageName = "BioP_MPNov", 
                      Image = "GUI_MPImages.MatchSettings.OptMapNoveria", 
                      GalaxyAtWarMapPosition = {X = 352.0, Y = 352.0, Z = 0.0}, 
                      MusicEventName = 'Set_mus_map_mpnov', 
                      Id = 8, 
                      PrettyName = $618048, 
                      Description = $618057, 
                      GalaxyAtWarMapSubtitle = $706334, 
                      EveryoneHasThisMap = FALSE
                     }
                    )
    AvailableMaps = ("", "BioP_MPDish", "BioP_MPSlum", "BioP_MPTowr", "BioP_MPRctr", "BioP_MPCer", "BioP_MPNov")
    PrivacyTypes = ({Image = "GUI_MPImages.MatchSettings.OptTeamPublic", Id = 0, Name = $686083, AllCapsName = $683885}, 
                    {Image = "GUI_MPImages.MatchSettings.OptTeamPrivate", Id = 1, Name = $686084, AllCapsName = $683886}
                   )
                   // MILAN CHANGE - Remove enemytypes, leave it only in config. You must set IsRandomOption!
    //EnemyTypes = ({Image = "GUI_MPImages.MatchSettings.OptEmyRandom", WaveClass = "", Id = 0, Name = $701523, AllCapsName = $701523}, 
                 // {Image = "GUI_MPImages.MatchSettings.OptEmyCerberus", WaveClass = "SFXGameMPContent.SFXWave_Horde_Cerberus", Id = 1, Name = $683914, AllCapsName = $683908}, 
                 // {Image = "GUI_MPImages.MatchSettings.OptEmyGeth", WaveClass = "SFXGameMPContent.SFXWave_Horde_Geth", Id = 2, Name = $683915, AllCapsName = $683909}, 
                 // {Image = "GUI_MPImages.MatchSettings.OptEmyReapers", WaveClass = "SFXGameMPContent.SFXWave_Horde_Reaper", Id = 3, Name = $683916, AllCapsName = $683910}
                 //)
                 // END MILAN CHANGE
    ChallengeTypes = ({Image = "GUI_MPImages.MatchSettings.OptChallgBrnz", Id = 0, Name = $683917, AllCapsName = $683911}, 
                      {Image = "GUI_MPImages.MatchSettings.OptChallgSilver", Id = 1, Name = $683918, AllCapsName = $683912}, 
                      {Image = "GUI_MPImages.MatchSettings.OptChallgGold", Id = 2, Name = $683919, AllCapsName = $683913}
                     )
    AnyMapImage = "GUI_MPImages.MatchSettings.OptMapRandom"
    AnyEnemyImage = "GUI_MPImages.MatchSettings.OptEmyRandom"
    AnyChallengeImage = "GUI_MPImages.MatchSettings.OptChallgRandom"
    srAnyMap = $716860
    srAnyEnemy = $716861
    srAnyChallenge = $722468
    NumPublicConnections = 4
    Properties = ({
                   Data = {Value1 = 1, Type = ESettingsDataType.SDT_Int32}, 
                   PropertyId = 0, 
                   AdvertisementType = EOnlineDataAdvertisementType.ODAT_OnlineService
                  }
                 )
    PropertyMappings = ({
                         ColumnHeaderText = "", 
                         ValueMappings = (), 
                         PredefinedValues = (), 
                         Name = 'MapIndex', 
                         Id = 0, 
                         MinVal = 0.0, 
                         MaxVal = 0.0, 
                         RangeIncrement = 0.0, 
                         MappingType = EPropertyValueMappingType.PVMT_RawValue
                        }
                       )
}