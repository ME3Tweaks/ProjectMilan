// Source: ME3, Patch_SFXGUI_MPMatchResults
// Decompiled 1/7/2024 1:54:08 PM
Class SFXGUI_MPMatchResults extends SFXGUIMovieMP
    config(UI);

// Types
struct PlayerMatchResultData 
{
    var string PlayerName;
    var string ClassData;
    var string ClassIconRef;
    var array<RewardMedalData> Medals;
    var int PlayerDataIdx;
    var int TotalMatchXP;
    var int MatchXPPercentage;
    var bool bExtracted;
    var bool bIsLocal;
};
struct RewardMedalData 
{
    var string MedalIconRef;
    var string MedalDescription;
};

// Variables
var delegate<ResultDataSort> __ResultDataSort__Delegate;
var config stringref srFormattedXP;
var config stringref srFormattedXPPlus;
var config stringref srClassDataFormat;
var config stringref srNextLevel;
var config stringref srPlus;
var config stringref srLevelUp;
var config stringref srGAWString;
var config stringref srRandomBonusString;
var config stringref srBonusXPString;
var config stringref srBonusXPReadinessString;
var config float fIntroEventPauseTime;
var SFXMatchResultsData OverallMatchResults;

// Functions
// MILAN CHANGE 1/8/2024 DropTehSquid
// adding this so we can react to input mode changes
public event function HandleButtonRefresh(bool usingGamepad)
{
    Super(SFXGUIMovie).HandleButtonRefresh(usingGamepad);
    SetMouseVisible(!usingGamepad);
    ActionScriptVoid("screen.RefreshButtonHelp");
}
// END MILAN
public function array<PlayerMatchResultData> GetPlayerData()
{
    local array<PlayerMatchResultData> PlayerResultData;
    local PlayerMatchResultData NewData;
    local RewardMedalData NewMedalData;
    local SFXMatchResultsData MatchResults;
    local int idx;
    local int Idx2;
    local float TotalSquadScore;
    local float ScoreToXPMultiplier;
    local SFXSaveManagerMP MPSaveManager;
    
    MPSaveManager = SFXEngine(Class'Engine'.static.GetEngine()).MPSaveManager;
    MatchResults = GetOverallMatchResults();
    ScoreToXPMultiplier = SFXGameConfigMP(SFXGRI(Class'Engine'.static.GetCurrentWorldInfo().GRI).gameconfig).ScoreToXPMultiplier;
    TotalSquadScore = 0.0;
    for (idx = 0; idx < MatchResults.PlayerData.Length; ++idx)
    {
        NewData.PlayerDataIdx = idx;
        NewData.PlayerName = MatchResults.PlayerData[idx].PlayerName;
        NewData.TotalMatchXP = FCeil(ScoreToXPMultiplier * MatchResults.PlayerData[idx].fScore);
        TotalSquadScore += float(NewData.TotalMatchXP);
        SetCustomToken(0, string(MatchResults.PlayerData[idx].ClassLevel));
        SetCustomToken(1, GetUIString(MPSaveManager.GetKitBaseClassPrettyName(MatchResults.PlayerData[idx].KitName)));
        NewData.ClassData = GetUIString(srClassDataFormat, TRUE);
        ClearCustomTokens();
        NewData.ClassIconRef = "";
        NewData.Medals.Length = 0;
        for (Idx2 = 0; Idx2 < MatchResults.PlayerData[idx].PlayerMedalIDs.Length; ++Idx2)
        {
            NewMedalData.MedalDescription = "";
            NewMedalData.MedalIconRef = "";
            if (GetPlayerMedalDefinition(MatchResults.PlayerData[idx].PlayerMedalIDs[Idx2], NewMedalData))
            {
                NewData.Medals.AddItem(NewMedalData);
            }
        }
        NewData.bExtracted = MatchResults.ExtractedPlayerIDs.Find(MatchResults.PlayerData[idx].PlayerID) >= 0;
        NewData.bIsLocal = MatchResults.PlayerData[idx].PlayerID == GetPRIMP().PlayerID;
        PlayerResultData.AddItem(NewData);
    }
    if (TotalSquadScore > float(0))
    {
        for (idx = 0; idx < PlayerResultData.Length; ++idx)
        {
            PlayerResultData[idx].MatchXPPercentage = int((float(PlayerResultData[idx].TotalMatchXP) / TotalSquadScore) * float(100));
        }
    }
    PlayerResultData.Sort(ResultDataSort);
    return PlayerResultData;
}
public event function OnStart()
{
    Super(SFXGUIMovie).OnStart();
    SetGameMode(TRUE, 24); // MILAN Patched: GameMode Enum Index
	// MILAN CHANGE DropTheSquid 1/8/2024
	// making sure we can actually show/hide the mouse when in lobby game mode. 
	BioPlayerController(GetPC()).GameModeManager2.GameModes[24].bHasMouseAuthority = FALSE;
	// making sure the mouse visibility is correct (removed a call a few lines up)
    SetMouseVisible(!bUsingGamepad);
	// END MILAN
    SetRequiresUIWorld(TRUE);
    PlayGuiSound('MPMatchResultsStart');
    AS_InitializeScreen();
    GetLobbyFlow().LastMapPlayed = OverallMatchResults.CurrentMatchData.MapId;
    GetLobbyFlow().LastEnemyPlayed = OverallMatchResults.CurrentMatchData.EnemyID;
}
public final function ShowGamercard(int nPlayerIndex)
{
    local SFXMatchResultsData MatchResults;
    local int nLocalUserNum;
    
    MatchResults = GetOverallMatchResults();
    nLocalUserNum = LocalPlayer(GetPC().Player).ControllerId;
    Class'SFXOnlineSubsystem'.static.GetOnlineSubsystem().GetComponentPlatform().ShowGamerCardUI(byte(nLocalUserNum), MatchResults.PlayerData[nPlayerIndex].UniqueId);
}
public event function OnClose()
{
    Super(SFXGUIMovie).OnClose();
    SetGameMode(FALSE, 24); // MILAN Patched: GameMode Enum Index
    SetMouseVisible(FALSE);
    OverallMatchResults.ResetData();
    StopGuiSound('MPMatchResultsXPProgress');
}
public function AS_InitializeScreen()
{
    ActionScriptVoid("screen.InitializeScreen");
}
public function int GetLevelFromXP(int nXP)
{
    local int nLevel;
    
    if (Class'BioLevelUpSystem'.static.GetLevelFromXP(nXP, nLevel))
    {
        return nLevel;
    }
    return -1;
}
public final function bool LeveledUp()
{
    local SFXMatchResultsData MatchResults;
    local int nOriginalLevel;
    local int nFinalLevel;
    
    MatchResults = GetOverallMatchResults();
    Class'BioLevelUpSystem'.static.GetLevelFromXP(int(MatchResults.PlayerRewards.fOriginalExperience), nOriginalLevel);
    Class'BioLevelUpSystem'.static.GetLevelFromXP(int(MatchResults.PlayerRewards.fNewExperience), nFinalLevel);
    return nFinalLevel > nOriginalLevel;
}
public final function OnContinue()
{
    Close();
    PlayGuiSound('MPMatchResultsFinished');
    GetLobbyFlow().FinishMatchResults();
}
public delegate function int ResultDataSort(PlayerMatchResultData A, PlayerMatchResultData B)
{
    return A.TotalMatchXP >= B.TotalMatchXP ? 0 : -1;
}
public final function StartXPProgressSound()
{
    PlayGuiSound('MPMatchResultsXPProgress');
}
public final function StopXPProgressSound()
{
    StopGuiSound('MPMatchResultsXPProgress');
}
public function string GetClassDataString(int nLevel, Name className)
{
    local SFXSaveManagerMP MPSaveManager;
    local string ReturnString;
    local string ClassPrettyName;
    
    MPSaveManager = SFXEngine(Class'Engine'.static.GetEngine()).MPSaveManager;
    ClassPrettyName = GetUIString(MPSaveManager.GetClassPrettyName(className));
    SetCustomToken(0, string(nLevel));
    SetCustomToken(1, ClassPrettyName);
    ReturnString = GetUIString(srClassDataFormat, TRUE);
    ClearCustomTokens();
    return ReturnString;
}
public function string GetCurrentPlayerClassDataString(int nLevel)
{
    local SFXSaveManagerMP MPSaveManager;
    local SFXMPCharacterRecord CurrentCharacter;
    
    MPSaveManager = SFXEngine(Class'Engine'.static.GetEngine()).MPSaveManager;
    CurrentCharacter = MPSaveManager.GetCurrentSelectedCharacterRecord();
    return GetClassDataString(nLevel, CurrentCharacter.className);
}
public function int GetFinalExperience()
{
    local SFXMatchResultsData MatchResults;
    
    MatchResults = GetOverallMatchResults();
    return int(MatchResults.PlayerRewards.fNewExperience);
}
public function string GetFormattedXPString(int nXP)
{
    local string ResultString;
    
    SetCustomToken(0, string(nXP));
    ResultString = GetUIString(srFormattedXP, TRUE);
    ClearCustomTokens();
    return ResultString;
}
public function string GetFormattedXPStringPlus(int nXP)
{
    local string ResultString;
    
    SetCustomToken(0, string(nXP));
    ResultString = GetUIString(srFormattedXPPlus, TRUE);
    ClearCustomTokens();
    return ResultString;
}
public final function EGAWZone GetGAWMapID()
{
    local SFXMatchResultsData MatchResults;
    
    MatchResults = GetOverallMatchResults();
    return MatchResults.CurrentMatchData.ZoneID;
}
public final function int GetGAWMapRating()
{
    local SFXMatchResultsData MatchResults;
    local SFXGAWAssetsHandler GAWAssetsHandler;
    
    MatchResults = GetOverallMatchResults();
    GAWAssetsHandler = Class'SFXGAWAssetsHandler'.static.GetGAWHandler();
    return 50 + MatchResults.CurrentMatchData.ZoneRatingIncrease; // MILAN Patched: Remove Galaxy At War calls
}
public final function int GetGAWMapRatingIncrease()
{
    local SFXMatchResultsData MatchResults;
    
    MatchResults = GetOverallMatchResults();
    if (true) // MILAN Patched: Remove Galaxy At War calls
    {
        return 0;
    }
    return MatchResults.CurrentMatchData.ZoneRatingIncrease;
}
public final function string GetGAWMapString()
{
    local SFXMatchResultsData MatchResults;
    local SFXGAWAssetsHandler GAWAssetsHandler;
    local string MapDisplayName;
    local string ReturnString;
    local int RatingUpdate;
    local int nZoneIdx;
    
    MatchResults = GetOverallMatchResults();
    GAWAssetsHandler = Class'SFXGAWAssetsHandler'.static.GetGAWHandler();
    nZoneIdx = GAWAssetsHandler.GAWTheatreData.Find('ZoneID', MatchResults.CurrentMatchData.ZoneID);
    if (nZoneIdx < 0)
    {
        return "";
    }
    MapDisplayName = GetUIString(GAWAssetsHandler.GAWTheatreData[nZoneIdx].srZoneName);
    RatingUpdate = MatchResults.CurrentMatchData.ZoneRatingIncrease;
    SetCustomToken(0, MapDisplayName);
    SetCustomToken(1, string(RatingUpdate));
    ReturnString = GetUIString(srGAWString, TRUE);
    ClearCustomTokens();
    return ReturnString;
}
public final function float GetIntroEventPauseTime()
{
    return fIntroEventPauseTime;
}
public final function string GetLeveledUpString()
{
    return GetUIString(srLevelUp);
}
public final function string GetLocalPlayerClassData(int nLevel)
{
    local SFXMatchResultsData MatchResults;
    local string ReturnString;
    local SFXSaveManagerMP MPSaveManager;
    local int idx;
    
    MPSaveManager = SFXEngine(Class'Engine'.static.GetEngine()).MPSaveManager;
    MatchResults = GetOverallMatchResults();
    for (idx = 0; idx < MatchResults.PlayerData.Length; ++idx)
    {
        if (MatchResults.PlayerData[idx].PlayerID == GetPRIMP().PlayerID)
        {
            SetCustomToken(0, string(nLevel));
            SetCustomToken(1, GetUIString(MPSaveManager.GetKitBaseClassPrettyName(MatchResults.PlayerData[idx].KitName)));
            ReturnString = GetUIString(srClassDataFormat, TRUE);
            ClearCustomTokens();
            break;
        }
    }
    return ReturnString;
}
public function string GetMatchChallenge()
{
    local SFXMatchResultsData MatchResults;
    local array<MPChallengeInfo> ChallengeTypes;
    local int ChallengeIndex;
    
    MatchResults = GetOverallMatchResults();
    ChallengeTypes = GetChallengeTypes();
    ChallengeIndex = ChallengeTypes.Find('Id', MatchResults.CurrentMatchData.DifficultyID);
    if (ChallengeIndex != -1)
    {
        return GetUIString(ChallengeTypes[ChallengeIndex].Name);
    }
    else
    {
        return "";
    }
}
public function string GetMatchEnemy()
{
    local SFXMatchResultsData MatchResults;
    local array<MPEnemyInfo> EnemyTypes;
    local int EnemyIndex;
    
    MatchResults = GetOverallMatchResults();
    EnemyTypes = GetEnemyTypes();
    EnemyIndex = EnemyTypes.Find('Id', MatchResults.CurrentMatchData.EnemyID);
    if (EnemyIndex != -1)
    {
        return GetUIString(EnemyTypes[EnemyIndex].Name);
    }
    else
    {
        return "";
    }
}
public function string GetMatchMap()
{
    local SFXMatchResultsData MatchResults;
    
    MatchResults = GetOverallMatchResults();
    return GetUIString(GetLobbyGRI().GetMapInfo(MatchResults.CurrentMatchData.MapId).PrettyName);
}
public function int GetMatchTime()
{
    return GetOverallMatchResults().CurrentMatchData.TotalMatchTime;
}
public function string GetMatchWave()
{
    return string(GetOverallMatchResults().CurrentMatchData.Waves);
}
public final function string GetMaxReadinessString()
{
    local string ReadinessString;
    local string XPString;
    
    SetCustomToken(1, string(100));
    ReadinessString = GetUIString(srBonusXPReadinessString, TRUE);
    ClearCustomTokens();
    SetCustomToken(0, string(int(Class'SFXPRIMP'.default.MaxReadinessXPBonus * 100.0)));
    XPString = GetUIString(srBonusXPString, TRUE);
    ClearCustomTokens();
    return (ReadinessString $ "\n") $ XPString;
}
private final function bool GetMedalDefinition(int MedalID, out RewardMedalData MedalData, out array<MedalDefinition> MedalDefinitions)
{
    local int MedalXP;
    local float ScoreToXPMultiplier;
    
    ScoreToXPMultiplier = SFXGameConfigMP(SFXGRI(Class'Engine'.static.GetCurrentWorldInfo().GRI).gameconfig).ScoreToXPMultiplier;
    if (MedalID >= 0 && MedalID < MedalDefinitions.Length)
    {
        if (MedalDefinitions[MedalID].Type != MPMedalType.MPMedalType_Invalid)
        {
            MedalXP = int(float(MedalDefinitions[MedalID].Score) * ScoreToXPMultiplier);
            ClearCustomTokens();
            SetCustomToken(0, string(MedalDefinitions[MedalID].Threshold));
            MedalData.MedalDescription = (GetUIString(MedalDefinitions[MedalID].MedalName, TRUE) $ " +") $ MedalXP;
            ClearCustomTokens();
            MedalData.MedalIconRef = MedalDefinitions[MedalID].Icon;
            return TRUE;
        }
    }
    return FALSE;
}
public function bool GetMissionResult()
{
    return GetOverallMatchResults().CurrentMatchData.bResult;
}
public function string GetNextLevelString(int nLevel)
{
    local string ReturnString;
    
    SetCustomToken(0, string(nLevel));
    ReturnString = GetUIString(srNextLevel, TRUE);
    ClearCustomTokens();
    return ReturnString;
}
public function int GetOriginalExperience()
{
    local SFXMatchResultsData MatchResults;
    
    MatchResults = GetOverallMatchResults();
    return int(MatchResults.PlayerRewards.fOriginalExperience);
}
private final function SFXMatchResultsData GetOverallMatchResults()
{
    if (OverallMatchResults == None)
    {
        OverallMatchResults = SFXEngine(Class'Engine'.static.GetEngine()).MPSaveManager.GetMPMatchResultsData();
    }
    return OverallMatchResults;
}
public final function string GetOverallRatingsString()
{
    local SFXMatchResultsData MatchResults;
    local string ReturnString;
    
    if (Class'SFXGAWAssetsHandler'.static.GetGAWHandler().GetOverallReadiness() < 100)
    {
        MatchResults = GetOverallMatchResults();
        SetCustomToken(0, string(MatchResults.CurrentMatchData.OverallRatingIncrease));
        ReturnString = GetUIString(srRandomBonusString, TRUE);
        ClearCustomTokens();
    }
    else
    {
        ReturnString = GetMaxReadinessString();
    }
    return ReturnString;
}
private final function bool GetPlayerMedalDefinition(int MedalID, out RewardMedalData MedalData)
{
    return GetMedalDefinition(MedalID, MedalData, Class'SFXScoreManager'.default.PlayerMedalDefinitions);
}
public function string GetPlusFormattedValue(int nValue)
{
    local string ReturnString;
    
    SetCustomToken(0, string(nValue));
    ReturnString = GetUIString(srPlus, TRUE);
    ClearCustomTokens();
    return ReturnString;
}
public function int GetSquadBonusXP()
{
    local SFXMatchResultsData MatchResults;
    
    MatchResults = GetOverallMatchResults();
    return MatchResults.BonusSquadXP;
}
private final function bool GetSquadMedalDefinition(int MedalID, out RewardMedalData MedalData)
{
    return GetMedalDefinition(MedalID, MedalData, Class'SFXScoreManager'.default.SquadMedalDefinitions);
}
public function array<RewardMedalData> GetSquadMedals()
{
    local array<RewardMedalData> SquadMedals;
    local SFXMatchResultsData MatchResults;
    local RewardMedalData NewMedalData;
    local int idx;
    
    MatchResults = GetOverallMatchResults();
    for (idx = 0; idx < MatchResults.SquadMedalIDs.Length; ++idx)
    {
        NewMedalData.MedalDescription = "";
        NewMedalData.MedalIconRef = "";
        if (GetSquadMedalDefinition(MatchResults.SquadMedalIDs[idx], NewMedalData))
        {
            SquadMedals.AddItem(NewMedalData);
        }
    }
    return SquadMedals;
}
public function int GetSquadTotalCredits()
{
    local SFXMatchResultsData MatchResults;
    
    MatchResults = GetOverallMatchResults();
    return MatchResults.TotalSquadCredits;
}
public function int GetSquadTotalXP()
{
    local SFXMatchResultsData MatchResults;
    
    MatchResults = GetOverallMatchResults();
    return MatchResults.TotalSquadXP;
}
public function int GetXPRequredForLevel(int nLevel)
{
    local int nXPNeeded;
    
    if (Class'BioLevelUpSystem'.static.GetXPNeededForLevel(nLevel, nXPNeeded))
    {
        return nXPNeeded;
    }
    return -1;
}
public final function bool HasOverallRatingsIncrease()
{
    local SFXMatchResultsData MatchResults;
    
    MatchResults = GetOverallMatchResults();
    if (MatchResults.TotalSquadXP > 0 && Class'SFXGAWAssetsHandler'.static.GetGAWHandler().GetOverallReadiness() == 100)
    {
        return TRUE;
    }
    return MatchResults.CurrentMatchData.OverallRatingIncrease > 0;
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    srFormattedXP = $677972
    srFormattedXPPlus = $677973
    srClassDataFormat = $677974
    srNextLevel = $677975
    srPlus = $677976
    srLevelUp = $716157
    srGAWString = $716156
    srRandomBonusString = $716158
    srBonusXPString = $712076
    srBonusXPReadinessString = $727445
    fIntroEventPauseTime = 2.0
    m_bFocusOnStart = TRUE
}
