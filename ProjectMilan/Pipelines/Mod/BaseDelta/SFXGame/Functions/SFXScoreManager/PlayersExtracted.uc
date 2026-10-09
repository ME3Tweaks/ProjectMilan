public final function PlayersExtracted(array<SFXPawn_Player> ExtractedPlayers)
{
    local SFXPawn_Player Player;
    local float ExtractionCredits;
    
    ExtractionCredits = SFXGRI(BioWorldInfo.GRI).DifficultyHandler.GetFloat('ExtractionCredits', 'MPGlobal');
    ExtractionCredits *= GetFinalCreditsMultiplier();
    foreach ExtractedPlayers(Player, )
    {
        if (Player.PlayerReplicationInfo != None)
        {
            ExtractedPlayerIDs.AddItem(Player.PlayerReplicationInfo.PlayerID);
            if (ExtractionCredits > 0.0)
            {
                SFXPRI(Player.PlayerReplicationInfo).AddCredits(ExtractionCredits);
                ShowExtractionCreditsEarnedMessage(SFXPlayerController(Player.Controller), ExtractionCredits);
            }
        }
    }
    if (ExtractedPlayers.Length > 0)
    {
        if (ExtractedPlayers.Length == BioWorldInfo.Game.NumPlayers)
        {
            IncrementMedalStanding(ExtractedPlayers[0], 17, 4);
        }
        else
        {
            IncrementMedalStanding(ExtractedPlayers[0], 17, ExtractedPlayers.Length);
        }
    }
}
