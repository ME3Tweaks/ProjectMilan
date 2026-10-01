public function RecomputeHealthSegment()
{
    local int HealthSegment;
    // MILAN CHANGE: Only compute health segment if we are a human player. This fixes some issues with bots updating the player HUD.
    // 09/30/2026 - Mgamerz - Also add IsLocallyControlled() so clients don't mess with us
    if (Pawn(ModuleOwner).IsHumanControlled() && Pawn(ModuleOwner).IsLocallyControlled())
    {
        HealthSegment = FCeil(GetHealthRatio() * float(5));
        SoftMaxHealth = float(HealthSegment) * (GetMaxHealth() / float(5));
    }
}