// MILAN CHANGE 01/06/2024
// By: Mgamerz
// Note: This file will likely be heavily revised during development
// Note: Please ensure main viewport is not obscured by this as developing
// MP content will often have this up constantly.
// Purpose: Build a useful MP development profiler

public function ProfileMPGame()
{
    // MILAN CHANGE - remove all 'PlayerPawn' references and the Profile Target
    // as we do not care about it.
    local SFXWave_Horde HordeCurrentWave;
    local SFXWave_Operation Operation;
    local SFXWaveCoordinator_HordeOperation WaveCoordinator;
    local int idx;
    local SFXPawn ChkPawn;
    local string EnemyName;
    local bool B;
    local SFXEngine Engine;
    local SFXScoreManager ScoreManager;
    local SFXPRI PRI;
    local SFXGRI GRI;
    local array<EnemyWaveInfo> EnemiesToSpawn;
    local int EnemyIndex;
    local SFXPlayerControllerMP C;
    local Color OldColor;
    local Canvas Canvas;

    Engine = SFXEngine(Class'Engine'.static.GetEngine());
    GRI = SFXGRI(Outer.WorldInfo.GRI);
    ScoreManager = GRI != None ? GRI.GetScoreManager() : None;
    ScoreManager = ScoreManager == None ? LastScoreManager : ScoreManager;
    LastScoreManager = ScoreManager;
    WaveCoordinator = SFXWaveCoordinator_HordeOperation(GRI.WaveCoordinator);
    if (WaveCoordinator != None)
    {
        HordeCurrentWave = SFXWave_Horde(WaveCoordinator.GetWaveOfType('SFXWave_Horde'));
        Operation = SFXWave_Operation(WaveCoordinator.GetWaveOfType('SFXWave_Operation'));
    }
    if (Engine == None || GRI == None)
    {
        return;
    }
    // MILAN CHANGE 09/06/2026 - Mgamerz - Add difficulty profiling so it's easier to see what we're on since there's some bugginess in wave selection
    DrawLine("Difficulty: ", GRI.DifficultyHandler != None ? string(GRI.DifficultyHandler.CurrentDifficulty) : "None");
    // END MILAN CHANGE
    if (WaveCoordinator != None && Operation != None)
    {
        DrawLine("WaveCoordinator information: ", string(WaveCoordinator));
        DrawLine("    Wave #:", string(WaveCoordinator.CurrentWaveNumber));
        DrawLine("    Wave # [Friendly]:", string(WaveCoordinator.GetFriendlyCurrentWaveNumber()));
        DrawLine("");
        DrawLine("Objective type Active: ", string(WaveCoordinator.OperationWaveType));
        DrawLine("    Current Objective: ", string(Operation));
        DrawLine("Horde type Active: ", string(WaveCoordinator.HordeWaveType));
    }
    else
    {
        DrawLine("WaveCoordinator information: ", string(None));
        DrawLine("    Wave #:", string(0));
        DrawLine("    Wave # [Friendly]:", string(0));
        DrawLine("");
        DrawLine("Objective type Active: ", string(None));
        DrawLine("    Current Objective: ", string(None));
        DrawLine("Horde type Active: ", string(None));
    }
    if (HordeCurrentWave != None)
    {
        DrawLine("    Current Wave: ", string(HordeCurrentWave));
        DrawLine("    Wave Points: ", HordeCurrentWave.EndlessWave ? "Endless" : (HordeCurrentWave.WavePointsRemaining $ " / ") $ HordeCurrentWave.WavePoints);
        DrawLine("    Rush Active: ", string(HordeCurrentWave.bEndRushTriggered));
    }
    else
    {
        DrawLine("    Current Wave: ", string(None));
        DrawLine("    Wave Points: ", string(0));
        DrawLine("    Rush Active: ", string(FALSE));
    }
    if (HordeCurrentWave != None) // MILAN CHANGE - Gate horde list behind null check to prevent tons of null access logs
    {
        DrawLine("");
        DrawLine("Num Enemies Spawned:");
        HordeCurrentWave.GetEnemyArray(EnemiesToSpawn);
        for (idx = 0; idx < EnemiesToSpawn.Length; idx++)
        {
            EnemyIndex = HordeCurrentWave.EnemyList.Find('EnemyType', EnemiesToSpawn[idx].EnemyType);
            if (EnemyIndex != -1)
            {
                DrawLine((((("    Enemy: " $ EnemiesToSpawn[idx].EnemyType) $ " Count: ") $ HordeCurrentWave.NumSpawnedEnemiesByType[EnemyIndex]) $ " Max: ") $ EnemiesToSpawn[idx].MaxPerWave);
            }
        }
        
        // BEGIN MILAN CHANGE
        // Add asset load status
        DrawLine("Asset load status:");
        Canvas = Outer.myHUD.Canvas;
        OldColor = Canvas.DrawColor;
        for (idx = 0; idx < HordeCurrentWave.AssetLoadData.Length; idx++)
        {
            if (HordeCurrentWave.AssetLoadData[idx].AssetLoadStatus == EAsyncLoadStatus.ASYNC_LOAD_STARTED)
            {
                Canvas.SetDrawColor(255, 255, 255, 128);
            }
            else if (HordeCurrentWave.AssetLoadData[idx].AssetLoadStatus == EAsyncLoadStatus.ASYNC_LOAD_INPROGRESS)
            {
                Canvas.SetDrawColor(255, 255, 0, 255);
            }
            else if (HordeCurrentWave.AssetLoadData[idx].AssetLoadStatus == EAsyncLoadStatus.ASYNC_LOAD_COMPLETE)
            {
                Canvas.SetDrawColor(0, 255, 0, 200);
            }
            else if (HordeCurrentWave.AssetLoadData[idx].AssetLoadStatus == EAsyncLoadStatus.ASYNC_LOAD_ERROR)
            {
                Canvas.SetDrawColor(255, 0, 0, 255);
            }
            Canvas.DrawText("    " $ HordeCurrentWave.AssetLoadData[idx].AssetToLoad $ ": " $ HordeCurrentWave.AssetLoadData[idx].AssetLoadStatus);
        }
        DrawLine("");
        // END MILAN CHANGE

        DrawLine("");
        DrawLine("Enemies");
        foreach Outer.WorldInfo.AllPawns(Class'SFXPawn', ChkPawn)
        {
            if (ChkPawn.IsHostile(Outer.Pawn) == FALSE)
            {
                continue;
            }
            EnemyName = Right(string(ChkPawn), Len(string(ChkPawn)) - 8);
            if (ChkPawn.IsDead() == TRUE)
            {
                DrawLine("    Dead: " $ EnemyName);
            }
            B = FALSE;
            for (idx = 0; idx < HordeCurrentWave.EnemiesSpawned.Length; idx++)
            {
                B = B || ChkPawn == HordeCurrentWave.EnemiesSpawned[idx].Enemy;
            }
            if (B)
            {
                DrawLine("    Enemy: " $ EnemyName);
            }
            else
            {
                DrawLine("    Orphan: " $ EnemyName);
            }
        }
    }
    DrawLine("");

    // BEGIN MILAN CHANGE
    // Add player controller states for networking debug
    // Remove the credits previewing as we don't care about that between clients
    foreach Class'BioWorldInfo'.static.GetWorldInfo().AllControllers(Class'SFXPlayerControllerMP', C)
    {
        DrawLine("Player data for controller ", string(C));
        DrawLine("    State: ", string(C.GetStateName()));
        DrawLine("    Pawn loaded: ", string(C.Pawn != None));
        DrawLine("    Pawn load status: ", string(SFXPRIMP(C.PlayerReplicationInfo).GetAsyncLoadingStatus()));
    }
}