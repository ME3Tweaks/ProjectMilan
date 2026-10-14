public simulated function AddPRI(PlayerReplicationInfo PRI)
{
    local int PRICount;
    local PlayerReplicationInfo SFXPRI;
    local PlayerController PC;
    local array<PlayerController> PRIOwners;
    
    Super(GameReplicationInfo).AddPRI(PRI);
    if (Role == ENetRole.ROLE_Authority && PRI.IsPlayerOwned())
    {
        foreach PRIArray(SFXPRI, )
        {
            if (SFXPRI.IsPlayerOwned())
            {
                PC = PlayerController(SFXPRI.Owner);
                if (PRIOwners.Find(PC) == -1)
                {
                    PRIOwners.AddItem(PC);
                    PRICount++;
                }
            }
        }
        if (PRICount > int(MaxUniquePlayers))
        {
            // MILAN CHANGE - 10/09/2026 - Mgamerz
            // Lobbies can hold up to 16 players (SFXGameInfoMP_Lobby.MAX_LOBBY_SIZE), not 4.
            // This feeds the challenge data's NumPlayers.
            MaxUniquePlayers = byte(Min(16, PRICount));
            // END MILAN CHANGE
        }
    }
}
