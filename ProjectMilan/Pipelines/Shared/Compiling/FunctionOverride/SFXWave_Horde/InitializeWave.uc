// MILAN CHANGE - 07/04/2024
// By: Mgamerz
// Purpose: Add logging to wave initialization for debugging wavelist changes
// Changes are all added log statements.

public function InitializeWave(SFXWaveManager OwnerManager)
{
    local int i;
    local Name EnemyTypeIter;
    local EnemySpawnInfo EnemySpawnInfoIter;
    local EnemyWaveInfo EnemyWaveInfoIter;
    local SFXWaveAssetLoadData NewAssetLoadData;
    local array<EnemyWaveInfo> EnemiesToSpawn;
    
    Super.InitializeWave(OwnerManager);
    LogInternal("Initializing wave");
    bWaveIsOver = FALSE;
    AliveEnemiesByType.Length = EnemyList.Length;
    NumSpawnedEnemiesByType.Length = EnemyList.Length;
    EnemiesSpawned.Length = 0;
    for (i = 0; i < EnemySquadList.Length; i++)
    {
        EnemySquadList[i].WaveCost = 0;
        foreach EnemySquadList[i].EnemyTypes(EnemyTypeIter, )
        {
            EnemySquadList[i].WaveCost += GetEnemySpawnInfoForEnemyType(EnemyTypeIter).WaveCost;
        }
    }
    if (BioWorldInfo != None && BioWorldInfo.Role == ENetRole.ROLE_Authority)
    {
        if (BioWorldInfo.GetAutoBotsEnabled() == TRUE)
        {
            StartAutoBots();
        }
    }
    GetEnemyArray(EnemiesToSpawn);
    foreach EnemiesToSpawn(EnemyWaveInfoIter, )
    {
        EnemySpawnInfoIter = GetEnemySpawnInfoForEnemyType(EnemyWaveInfoIter.EnemyType);
        NewAssetLoadData.AssetToLoad = EnemySpawnInfoIter.EnemyArchetypeName;
        AssetLoadData.AddItem(NewAssetLoadData);
    }
}