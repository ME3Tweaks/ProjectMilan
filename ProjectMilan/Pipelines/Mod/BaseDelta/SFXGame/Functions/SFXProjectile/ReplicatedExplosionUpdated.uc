public simulated function ReplicatedExplosionUpdated()
{
    if (bActive)
    {
        // MILAN CHANGE - Mgamerz - 2026-10-28
        // Force clients to detonate at the explosion point
        if (Role != ENetRole.ROLE_Authority)
        {
            SetLocation(ReplicatedExplosionInfo.HitLocation);
        }
        // END MILAN CHANGE
        Explode(ReplicatedExplosionInfo.HitLocation, ReplicatedExplosionInfo.HitNormal);
        LatestExplodeTime = 0.0;
    }
    else
    {
        LatestExplodeTime = WorldInfo.TimeSeconds;
    }
    if (IsShuttingDown() == FALSE)
    {
        ShutDown();
    }
}
