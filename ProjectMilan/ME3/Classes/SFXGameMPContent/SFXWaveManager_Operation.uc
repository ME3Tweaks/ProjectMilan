Class SFXWaveManager_Operation extends SFXWaveManager
    transient;

// Variables
var transient array<SFXOperation_ObjectiveData> ObjectiveData;
var transient array<SFXOperation_ObjectiveSpawnPoint> ObjectiveSpawnPoints;
var transient array<SFXWave_Operation> PreviousWaves;
var transient float JoinInProgressTimeStamp;
var transient float WaveTimerOverride;
var transient repnotify int MatchTimer;
var transient bool bSuccessfullyGeneratedWaveList;

// Functions
public event simulated function ReplicatedEvent(Name VarName)
{
    if (VarName == 'MatchTimer')
    {
        SyncClientMatchTimer(float(MatchTimer), SFXGRI(WorldInfo.GRI).WaveCoordinator.GetWaveOfType('SFXWave_Operation'));
    }
    else
    {
        Super(Actor).ReplicatedEvent(VarName);
    }
}
public simulated function GeneratePotentialWaveList(optional Class<SFXWave> SpecifiedWaveType = Class'SFXWave_Operation')
{
    local array<Object> ObjectArray;
    local Object ObjectIter;
    local SFXOperation_ObjectiveData ObjectiveDataIter;
    local SFXWave_Operation WaveOpIter;
    local SFXOperation_ObjectiveSpawnPoint SpawnPointIter;
    local array<int> NumSpawnPointsForEachObjective;
    local int i;
    local array<string> ObjectiveTypes;
    local int ObjectiveTypeIndex;
    local array<int> NumSpawnPointsForEachObjectiveType;
    local bool IsEngagementValid;
    local SFXOperation_ObjectiveRequirement ObjReqIter;
    
    GetObjectArrayFromConfigSection(Class'SFXOperation_ObjectiveData', ObjectArray, FALSE);
    foreach ObjectArray(ObjectIter, )
    {
        ObjectiveData.AddItem(SFXOperation_ObjectiveData(ObjectIter));
    }
    PotentialWavesType = SpecifiedWaveType;
    GetObjectArrayFromConfigSection(PotentialWavesType, ObjectArray, TRUE);
    foreach ObjectArray(ObjectIter, )
    {
        PotentialWaves.AddItem(SFXWave_Operation(ObjectIter));
    }
    foreach BioWorldInfo.AllActors(Class'SFXOperation_ObjectiveSpawnPoint', SpawnPointIter, )
    {
        ObjectiveSpawnPoints.AddItem(SpawnPointIter);
    }
    NumSpawnPointsForEachObjective.Length = ObjectiveData.Length;
    foreach ObjectiveData(ObjectiveDataIter, i)
    {
        NumSpawnPointsForEachObjective[i] = 0;
        foreach ObjectiveSpawnPoints(SpawnPointIter, )
        {
            if (SpawnPointIter.IsObjectiveValidForSpawn(ObjectiveDataIter))
            {
                NumSpawnPointsForEachObjective[i]++;
            }
        }
    }
    for (i = 0; i < NumSpawnPointsForEachObjective.Length; i++)
    {
        if (NumSpawnPointsForEachObjective[i] == 0)
        {
            NumSpawnPointsForEachObjective.Remove(i, 1);
            ObjectiveData.Remove(i, 1);
            i--;
        }
    }
    ObjectiveTypes.Length = 0;
    foreach ObjectiveData(ObjectiveDataIter, i)
    {
        ObjectiveTypeIndex = ObjectiveTypes.Find(ObjectiveDataIter.ObjectiveType);
        if (ObjectiveTypeIndex == -1)
        {
            ObjectiveTypeIndex = ObjectiveTypes.AddItem(ObjectiveDataIter.ObjectiveType);
            NumSpawnPointsForEachObjectiveType.Add(1);
        }
        NumSpawnPointsForEachObjectiveType[ObjectiveTypeIndex] += NumSpawnPointsForEachObjective[i];
    }
    for (i = 0; i < PotentialWaves.Length; i++)
    {
        IsEngagementValid = TRUE;
        WaveOpIter = SFXWave_Operation(PotentialWaves[i]);
        foreach WaveOpIter.ObjectivesRequired(ObjReqIter, )
        {
            ObjectiveTypeIndex = ObjectiveTypes.Find(ObjReqIter.ObjectiveType);
            if (ObjectiveTypeIndex == -1 || NumSpawnPointsForEachObjectiveType[ObjectiveTypeIndex] < ObjReqIter.MinimumObjectivesRequired)
            {
                IsEngagementValid = FALSE;
                break;
            }
        }
        if (!IsEngagementValid)
        {
            PotentialWaves.Remove(i, 1);
            i--;
        }
    }
    PotentialWaves.Sort(SortObjectByName);
    bSuccessfullyGeneratedWaveList = TRUE;
}
public function int GetWaveIndex(optional int WaveIndex = -1, optional string WaveString = "")
{
    local array<float> WCofEngagement;
    local array<int> WaveIndexes;
    local SFXWave WaveIter;
    local SFXWave_Operation WaveOpIter;
    local float RunningSum;
    local float DiceRoll;
    local int ToRetWaveIndex;
    local int idx;
    local Class<SFXWave> WaveTypeOverride;
    
    if (PotentialWaves.Length == 0)
    {
        return -1;
    }
    if (WaveString != "")
    {
        WaveTypeOverride = GetWaveType(WaveString);
    }
    if (WaveTypeOverride != None)
    {
        foreach PotentialWaves(WaveIter, )
        {
            WaveOpIter = SFXWave_Operation(WaveIter);
            if (WaveOpIter != None && WaveOpIter.Class == WaveTypeOverride)
            {
                break;
            }
            ToRetWaveIndex++;
        }
    }
    else
    {
        ToRetWaveIndex = -1;
        for (idx = 0; idx < PotentialWaves.Length; idx++)
        {
            WaveOpIter = SFXWave_Operation(PotentialWaves[idx]);
            if (WaveOpIter != None && WaveOpIter.WeightedChanceOfSelection > float(0))
            {
                RunningSum += WaveOpIter.WeightedChanceOfSelection;
                WCofEngagement.AddItem(RunningSum);
                WaveIndexes.AddItem(idx);
            }
        }
        DiceRoll = FRand() * RunningSum;
        for (idx = 0; idx < WaveIndexes.Length; idx++)
        {
            if (DiceRoll <= WCofEngagement[idx])
            {
                ToRetWaveIndex = WaveIndexes[idx];
                break;
            }
        }
    }
    return ToRetWaveIndex;
}
public simulated function SyncClientMatchTimer(float OverrideTime, optional SFXWave CurrentWave)
{
    JoinInProgressTimeStamp = WorldInfo.GameTimeSeconds;
    WaveTimerOverride = OverrideTime;
    if (SFXWave_Operation(CurrentWave) != None)
    {
        SFXWave_Operation(CurrentWave).BeginWaveTimeLimit();
    }
}
public function ForceMatchTimerSync(optional int NewTime)
{
    if (IsTimerActive('MatchTimerSync'))
    {
        ClearTimer('MatchTimerSync');
    }
    MatchTimer = NewTime != 0 ? NewTime : int(SFXPlayerController(GetALocalPlayerController()).GetRemainingCountdownTime());
    SetTimer(60.0, FALSE, 'MatchTimerSync', );
}
public function Class<SFXWave_Operation> GetWaveType(string WaveType)
{
    return Class<SFXWave_Operation>(FindObject(WaveType, Class'Class'));
}
public function MatchTimerSync()
{
    if (float(MatchTimer) > 60.0)
    {
        MatchTimer -= int(60.0);
        SetTimer(60.0, FALSE, 'MatchTimerSync', );
    }
}
public final simulated function int SortObjectByName(Object A, Object B)
{
    return string(A.Name) >= string(B.Name) ? 0 : -1;
}

replication
{
    if ((!bNetInitial && bNetDirty) && Role == ENetRole.ROLE_Authority)
        MatchTimer;
    
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
}