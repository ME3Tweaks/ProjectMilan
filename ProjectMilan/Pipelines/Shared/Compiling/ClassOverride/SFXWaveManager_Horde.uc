// MILAN CHANGE - Mgamerz
// Decompiled 09/18/2026
// HordeWaveSort loses its delegate flag because it breaks the .Sort() method (its never assigned). 
// It seems that per-object-config sorting isn't guaranteed which was causing waves to become unordered
// with our coalesced compiler so this latent bug surfaced, which was also present in OT but did not surface.
Class SFXWaveManager_Horde extends SFXWaveManager
    transient
    config(Game);

struct WavePointRange 
{
    var Vector2D PointRange;
    var EDifficultyOptions Difficulty;
};
struct WaveType 
{
    var string WaveClassName;
    var int SelectionWeight;
};

var config array<WaveType> WaveTypes;
var config array<WavePointRange> WavePointsRanges;
var array<SFXEnemySpawnPoint> EnemySpawnPoints;
var config Vector2D WaveProgressionRange;
var config int MaxWaves;

public simulated function GeneratePotentialWaveList(optional Class<SFXWave> SpecifiedWaveType)
{
    local array<Object> TempObjects;
    local SFXWave_Horde NewWave;
    local int WaveIndex;
    local int TempObjectsIndex;
    
    if (Role == ENetRole.ROLE_Authority && SpecifiedWaveType == None)
    {
        PotentialWavesType = SelectWaveType();
    }
    else
    {
        PotentialWavesType = SpecifiedWaveType;
    }
    GetObjectArrayFromConfigSection(PotentialWavesType, TempObjects, FALSE);
    TempObjects.Sort(HordeWaveSort);
    PotentialWaves.Length = 0;
    TempObjectsIndex = 0;
    for (WaveIndex = 0; WaveIndex < MaxWaves; WaveIndex++)
    {
        NewWave = SFXWave_Horde(new TempObjects[TempObjectsIndex].@Class (TempObjects[TempObjectsIndex]));
        NewWave.WavePoints = WavePointsForRound(WaveIndex + 1);
        NewWave.WaveIndex = WaveIndex + 1;
        PotentialWaves.AddItem(NewWave);
        TempObjectsIndex++;
        TempObjectsIndex = TempObjectsIndex % TempObjects.Length;
    }
}
public function int GetWaveIndex(optional int WaveIndex = -1, optional string WaveString = "")
{
    if (WaveIndex == -1)
    {
        return 0;
    }
    else
    {
        return WaveIndex % PotentialWaves.Length;
    }
}
public function Class<SFXWave_Horde> SelectWaveType()
{
    local float F;
    local float F2;
    local float WaveTotal;
    local int idx;
    local Class<SFXWave_Horde> WaveClass;
    
    WaveTotal = 0.0;
    for (idx = 0; idx < WaveTypes.Length; idx++)
    {
        WaveTotal += float(WaveTypes[idx].SelectionWeight);
    }
    F = FRand() * WaveTotal;
    F2 = 0.0;
    for (idx = 0; idx < WaveTypes.Length; idx++)
    {
        F2 += float(WaveTypes[idx].SelectionWeight);
        if (F < F2)
        {
            WaveClass = Class<SFXWave_Horde>(FindObject(WaveTypes[idx].WaveClassName, Class'Class'));
            if (WaveClass == None)
            {
                WaveClass = Class<SFXWave_Horde>(Class'SFXEngine'.static.GetSeekFreeObject(WaveTypes[idx].WaveClassName, Class'Class'));
            }
            if (WaveClass != None)
            {
                BioWorldInfo.ShowDebugMessage("SFXWaveManager_Horde: Starting Wave " $ WaveTypes[idx].WaveClassName);
                return WaveClass;
            }
        }
    }
    BioWorldInfo.ShowDebugMessage("SFXWaveManager_Horde: No Valid Wave Type, using default wave type 'cerberus'");
    return Class'SFXWave_Horde_Cerberus';
}
public simulated function int WavePointsForRound(int Round)
{
    local int Points;
    local int idx;
    
    idx = WavePointsRanges.Find('Difficulty', SFXGRI(BioWorldInfo.GRI).DifficultyHandler.CurrentDifficulty);
    if (idx == -1)
    {
        return 0;
    }
    Round = Clamp(Round, int(WaveProgressionRange.X), int(WaveProgressionRange.Y));
    Points = int(Lerp(WavePointsRanges[idx].PointRange.X, WavePointsRanges[idx].PointRange.Y, (float(Round) - WaveProgressionRange.X) / (WaveProgressionRange.Y - WaveProgressionRange.X)));
    return Points;
}
public function GenerateEnemySpawnPointList()
{
    local SFXEnemySpawnPoint SpawnPoint;
    
    if (BioWorldInfo == None)
    {
        return;
    }
    EnemySpawnPoints.Length = 0;
    foreach BioWorldInfo.AllNavigationPoints(Class'SFXEnemySpawnPoint', SpawnPoint)
    {
        EnemySpawnPoints.AddItem(SpawnPoint);
    }
}
public simulated function int HordeWaveSort(Object A, Object B)
{
    return SFXWave_Horde(A).WaveIndex > SFXWave_Horde(B).WaveIndex ? -1 : 0;
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    WaveTypes = ({WaveClassName = "SFXGameMPContent.SFXWave_Horde_Reaper", SelectionWeight = 100}, 
                 {WaveClassName = "SFXGameMPContent.SFXWave_Horde_Cerberus", SelectionWeight = 100}, 
                 {WaveClassName = "SFXGameMPContent.SFXWave_Horde_Geth", SelectionWeight = 65}
                )
    WavePointsRanges = ({
                         PointRange = {X = 240.0, Y = 550.0}, 
                         Difficulty = EDifficultyOptions.DO_Level1
                        }, 
                        {
                         PointRange = {X = 400.0, Y = 1000.0}, 
                         Difficulty = EDifficultyOptions.DO_Level2
                        }, 
                        {
                         PointRange = {X = 600.0, Y = 1800.0}, 
                         Difficulty = EDifficultyOptions.DO_Level3
                        }
                       )
    WaveProgressionRange = {X = 1.0, Y = 11.0}
    MaxWaves = 11
}