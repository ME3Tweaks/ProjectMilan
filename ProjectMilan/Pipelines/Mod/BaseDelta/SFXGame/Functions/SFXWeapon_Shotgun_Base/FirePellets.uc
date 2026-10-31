// MILAN CHANGE - Mgamerz
// <= 0 latent fire time no longer uses a forced minimum and is effectively hitscan
public final simulated function FirePellets(Vector StartLocation, Rotator AimRotation, byte FireMode)
{
    local int PelletIdx;
    local int NumPellets;

    LatentFire_AimRotation = AimRotation;
    LatentFire_CurrentPellet = 0;
    LatentFire_StartLocation = StartLocation;
    // MILAN CHANGE - Fire immediately when there is no latent time
    if (LatentFireTime <= 0.0)
    {
        // Fire immediately with no latent fire callback
        ClearTimer('PollLatentFire', Self);
        NumPellets = PelletSpread.Length;
        for (PelletIdx = 0; PelletIdx < NumPellets; PelletIdx++)
        {
            PollLatentFire();
        }
        return;
    }
    // END MILAN CHANGE
    SetTimer(FMax(0.00100000005, LatentFireTime / float(PelletSpread.Length)), TRUE, 'PollLatentFire', );
}