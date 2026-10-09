public function RecomputeHealthSegment()
{
    local int HealthSegment;
    // MILAN CHANGE: Only compute health segment if we are a human player. This fixes some issues with bots updating the player HUD.
    if (Pawn(ModuleOwner).IsHumanControlled())
    {
        HealthSegment = FCeil(GetHealthRatio() * float(5));
        SoftMaxHealth = float(HealthSegment) * (GetMaxHealth() / float(5));
    }
}