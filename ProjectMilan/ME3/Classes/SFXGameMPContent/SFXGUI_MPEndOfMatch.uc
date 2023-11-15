Class SFXGUI_MPEndOfMatch extends SFXGUIMovieMP
    config(UI);

// Variables
var SFXMatchResultsData OverallMatchResults;

// Functions
public event function OnStart()
{
    Super(SFXGUIMovie).OnStart();
    SetGameMode(TRUE, 9);
    SetMouseVisible(TRUE);
    PlayGuiSound(GetOverallMatchResults().CurrentMatchData.bResult ? 'MPMissionSucceed' : 'MPMissionFail');
}
public event function OnClose()
{
    StopGuiSound(GetOverallMatchResults().CurrentMatchData.bResult ? 'MPMissionSucceed' : 'MPMissionFail');
    SetMouseVisible(FALSE);
    SetGameMode(FALSE, 9);
    Super(SFXGUIMovie).OnClose();
}
public final function stringref GetHintText()
{
    local SFXGRIMP GRI;
    local SFXWave_Operation Wave;
    
    GRI = SFXGRIMP(Class'Engine'.static.GetCurrentWorldInfo().GRI);
    Wave = SFXWave_Operation(GRI.WaveCoordinator.GetWaveOfType('SFXWave_Operation'));
    if (Wave != None)
    {
        return Wave.srWaveFailedHint;
    }
    return $0;
}
public final function MatchSettingsDisplayInfo GetMatchResults()
{
    local MatchSettingsDisplayInfo ResultsDisplayInfo;
    local SFXMatchResultsData MatchResults;
    local MPMapInfo MapInfo;
    local array<MPEnemyInfo> EnemyTypes;
    local array<MPChallengeInfo> ChallengeTypes;
    local int EnemyIndex;
    local int ChallengeIndex;
    
    MatchResults = GetOverallMatchResults();
    EnemyTypes = GetEnemyTypes();
    ChallengeTypes = GetChallengeTypes();
    MapInfo = GetMapInfo(MatchResults.CurrentMatchData.MapId);
    EnemyIndex = EnemyTypes.Find('Id', MatchResults.CurrentMatchData.EnemyID);
    ChallengeIndex = ChallengeTypes.Find('Id', MatchResults.CurrentMatchData.DifficultyID);
    ResultsDisplayInfo.MapName = GetUIString(MapInfo.PrettyName);
    ResultsDisplayInfo.EnemyName = GetUIString(EnemyTypes[EnemyIndex].Name);
    ResultsDisplayInfo.ChallengeName = GetUIString(ChallengeTypes[ChallengeIndex].Name);
    ResultsDisplayInfo.bMissionSuccessful = MatchResults.CurrentMatchData.bResult;
    ResultsDisplayInfo.Wave = string(MatchResults.CurrentMatchData.Waves);
    ResultsDisplayInfo.Time = MatchResults.CurrentMatchData.TotalMatchTime;
    return ResultsDisplayInfo;
}
private final function SFXMatchResultsData GetOverallMatchResults()
{
    if (OverallMatchResults == None)
    {
        OverallMatchResults = SFXEngine(Class'Engine'.static.GetEngine()).MPSaveManager.GetMPMatchResultsData();
    }
    return OverallMatchResults;
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
}