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
        // MILAN CHANGE - 10/09/2026 - Mgamerz
        // The squad extraction medal's tiers are 1, 2 and 4. With more than 4 players, the raw count
        // would give gold before everyone is out and skip tiers for 3, 5, 6 or 7, so map the share
        // extracted onto the tiers instead: half or more is silver, fewer is bronze.
        else if (BioWorldInfo.Game.NumPlayers > 4)
        {
            IncrementMedalStanding(ExtractedPlayers[0], 17, ExtractedPlayers.Length * 2 >= BioWorldInfo.Game.NumPlayers ? 2 : 1);
        }
        // END MILAN CHANGE
        else
        {
            IncrementMedalStanding(ExtractedPlayers[0], 17, ExtractedPlayers.Length);
        }
    }
}
