// MILAN CHANGE - Mgamerz - 2026-10-31
// C01: A nonpositive pellet delay processes the shot immediately, without a timer.
public final simulated function FirePellets(Vector StartLocation, Rotator AimRotation, byte FireMode)
{
    local int PelletIdx;
    local int NumPellets;

    LatentFire_AimRotation = AimRotation;
    LatentFire_CurrentPellet = 0;
    LatentFire_StartLocation = StartLocation;
    if (LatentFireTime <= 0.0)
    {
        ClearTimer('PollLatentFire', Self);
        // Bound the loop independently of the completion callback's pellet state.
        NumPellets = PelletSpread.Length;
        for (PelletIdx = 0; PelletIdx < NumPellets; PelletIdx++)
        {
            // Retain the existing impact, replication, FX and completion handling.
            PollLatentFire();
        }
        return;
    }
    SetTimer(FMax(0.00100000005, LatentFireTime / float(PelletSpread.Length)), TRUE, 'PollLatentFire', );
}
// END MILAN CHANGE
