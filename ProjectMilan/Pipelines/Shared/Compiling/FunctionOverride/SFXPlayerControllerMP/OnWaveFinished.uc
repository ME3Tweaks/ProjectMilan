public simulated function OnWaveFinished()
{
    local SFXAccomplishmentManager AccomplishmentManager;
    local SFXGRIMP GRI;

    // MILAN CHANGE DropTheSquid 1/11/2024
    // I don't know why this is being called here, but it is pretty useless. it gets shown again immediately by MPHud update
    // it just causes it to do the entry animation again at the end of each wave. removing it fixes that.
    // HideInGameConsumableUI();
    // END MILAN
    if (IsLocalPlayerController())
    {
        SFXEngine(Class'Engine'.static.GetEngine()).MPSaveManager.SaveRecords(TRUE);
        GRI = SFXGRIMP(WorldInfo.GRI);
        if (GRI != None && GRI.GameStatus == EGameStatus.GS_MatchInProgress)
        {
            AccomplishmentManager = SFXEngine(Class'Engine'.static.GetEngine()).AccomplishmentManager;
            AccomplishmentManager.UpdateWaveChallenges(Self);
        }
    }
}