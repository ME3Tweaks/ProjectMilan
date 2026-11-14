// MILAN CHANGE - 11/14/2026 - Mgamerz
// Add null guards
public function bool OnImpact(EPowerResistance Resistance, Actor oImpacted, int nPreviouslyImpacted, Vector HitLocation, Vector HitNormal)
{
    local BioPawn ImpactedPawn;
    local int PowerComboTypeUniqueID;
    // Add variable for detonation rank
    local float DetonationRank;

    if (Owner != None && Owner.Role == ENetRole.ROLE_Authority)
    {
        ImpactedPawn = BioPawn(oImpacted);
        // MILAN CHANGE - 11/14/2026 - Mgamerz
        // Add null guards
        if (ImpactedPawn != None && SourcePower != None)
        {
            DetonationRank = 0.0;
            if (CurrentDetonationPower != None)
            {
                DetonationRank = CurrentDetonationPower.Rank;
            }
            PowerComboTypeUniqueID = SourcePower.GetPowerComboTypeUniqueIDFromClass(PathName(@Class));
            SourcePower.ReplicatePowerComboImpact(ImpactedPawn, ImpactedPawn.CurrentCustomAction, DetonationRank, PowerComboTypeUniqueID, nPreviouslyImpacted);
        }
        // END MILAN CHANGE
    }
    return TRUE;
}
