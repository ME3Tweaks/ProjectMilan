// MILAN CHANGE - Mgamerz - 2026-10-22
// Preserve the original seed-cost-biased Unified implementation.
// NEW to Milan
// 09/21/2026 - Mgamerz
// Wavelist class that gets a randomized composition of enemies based on the score budget.
Class SFXWave_Horde_RandomEnemiesBiased extends SFXWave_Horde
    config(Game);

public function GetLocalEnemyArray(out array<EnemyWaveInfo> EnemyArray)
{
    local SFXWaveManager_Horde HordeManager;

    LogInternal("GetLocalEnemyArray()");
    HordeManager = SFXWaveManager_Horde(WaveManager);
    if (HordeManager == None)
    {
        LogInternal("Random Enemies has no HordeManager; generated composition is empty.");
        EnemyArray.Length = 0;
        return;
    }
    EnemyArray = HordeManager.GenerateScaledRandomComposition(GetScoreBudget(), MaxEnemies);
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
}

// END MILAN CHANGE
