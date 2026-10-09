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
            MaxUniquePlayers = byte(Min(4, PRICount));
        }
    }
}
