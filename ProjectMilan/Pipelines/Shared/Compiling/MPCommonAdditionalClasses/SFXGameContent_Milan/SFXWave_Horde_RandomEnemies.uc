// NEW to Milan
// 09/21/2026 - Mgamerz
// Wavelist class that gets a randomized composition of enemies based on the score budget.
Class SFXWave_Horde_RandomEnemies extends SFXWave_Horde
    perobjectconfig
    config(Game);

public function GetLocalEnemyArray(out array<EnemyWaveInfo> EnemyArray)
{
    local array<Name> Chosen;
    local Name TypeName;
    local EnemyWaveInfo Info;
    local SFXWaveManager_Horde HordeManager;

    HordeManager = SFXWaveManager_Horde(WaveManager);
    Chosen = HordeManager.GenerateScaledRandomComposition(GetScoreBudget());
    EnemyArray.Length = 0;
    foreach Chosen(TypeName, )
    {
        Info.EnemyType = TypeName;
        Info.MinCount = 0;
        Info.MaxCount = 0;
        Info.MaxPerWave = 0;
        EnemyArray.AddItem(Info);
    }
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
}
