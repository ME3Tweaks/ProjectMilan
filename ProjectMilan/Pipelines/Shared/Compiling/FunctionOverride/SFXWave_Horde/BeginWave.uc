// MILAN CHANGE - 07/04/2024
// By: Mgamerz
// Purpose: Log failed asset data loading in prep for allowing dynamic enemy spawn changes.
 
public function bool BeginWave()
{
    local int i;
    local int Index;
    
    if (!Super.BeginWave())
    {
        return FALSE;
    }
    bWaveIsOver = FALSE;
    EndOfRoundSpeedBonus = 0.0;
    WavePointsRemaining = WavePoints;
    CurrentSquadIndex = -1;
    NextSquadEnemyIndex = -1;
    if (BioWorldInfo != None && BioWorldInfo.Game != None && BioWorldInfo.Role == ENetRole.ROLE_Authority)
    {
        if (BioWorldInfo.GetAutoBotsEnabled() == TRUE)
        {
            if (!WaveCoordinator.IsTimerActive('StartAutoBots', Self))
            {
                WaveCoordinator.SetTimer(1.0, TRUE, 'StartAutoBots', Self);
            }
        }
        EnemySquad = SFXGame(BioWorldInfo.Game).SpawnEnemySquad();
        WaveCoordinator.SetTimer(SpawnDelay, FALSE, 'SpawnHorde', Self);
    }
    LocalPlayerController.SetScoreHudObjectiveText($0);
    for (i = 0; i < EnemyList.Length; i++)
    {
        Index = AssetLoadData.Find('AssetToLoad', EnemyList[i].EnemyArchetypeName);
        if (Index != -1)
        {
            EnemyList[i].EnemyArchetype = Pawn(FindObject(EnemyList[i].EnemyArchetypeName, Class'Pawn'));
            BioPawn(EnemyList[i].EnemyArchetype).Class.static.PrecacheVFX(SFXGRI(BioWorldInfo.GRI).ObjectPool, Class'RvrClientEffectManager'.static.GetClientEffectManager());
        } 
        // BEGIN MILAN CHANGE
        else {
            WarnInternal("Asset wasn't found for vfx precache: " $ EnemyList[i].EnemyArchetypeName);
        }
        // END MILAN CHANGE
    }
    TriggerWaveStartEvent(CurrentWave);
    return TRUE;
}