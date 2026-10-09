public function CheckGoToLobby()
{
    local SFXPlayerControllerMP PC;
    local int ExtractedPlayers[4];
    local int idx;
    
    for (idx = 0; idx < 4; idx++)
    {
        if (SFXGRIMP(WorldInfo.GRI).GetScoreManager().ExtractedPlayerIDs.Length > idx)
        {
            ExtractedPlayers[idx] = SFXGRIMP(WorldInfo.GRI).GetScoreManager().ExtractedPlayerIDs[idx];
            continue;
        }
        ExtractedPlayers[idx] = -1;
    }
    foreach WorldInfo.AllControllers(Class'SFXPlayerControllerMP', PC)
    {
        if (SFXPRIMP(PC.PlayerReplicationInfo) != None)
        {
            if (PC.Pawn != None)
            {
                SFXPRIMP(PC.PlayerReplicationInfo).ReadyToTransitionToLobby = FALSE;
                SFXPRIMP(PC.PlayerReplicationInfo).GatherMatchResults(SFXGRIMP(GameReplicationInfo).GameStatus == EGameStatus.GS_MatchOver_Win, ExtractedPlayers);
            }
            else
            {
                SFXPRIMP(PC.PlayerReplicationInfo).ReadyToTransitionToLobby = TRUE;
            }
        }
    }
    SetTimer(BackToLobbyFailSafeDelay, FALSE, 'ForceEverybodyReadyToTransitionToLobby', );
    if (GameInterface != None)
    {
        WriteOnlineStats();
        WriteOnlinePlayerScores();
        EndOnlineGame();
        if (bUsingArbitration)
        {
            PendingArbitrationPCs.Length = 0;
            ArbitrationPCs.Length = 0;
            NotifyArbitratedMatchEnd();
        }
    }
    ClearTimer('CheckPlayersReadyAtMatchEnd');
    CheckPlayersReadyAtMatchEnd();
}
