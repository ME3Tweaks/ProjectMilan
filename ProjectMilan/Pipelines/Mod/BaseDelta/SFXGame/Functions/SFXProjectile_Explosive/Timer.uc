public function Timer()
{
    // MILAN CHANGE - Mgamerz - 2026-10-28
    // Remove bClientPredictionActive == FALSE check so it matches ME3's
    // This is why projectiles off host would not despawn on impact
    if (IsShuttingDown() == FALSE)
    // END MILAN CHANGE
    {
        Explode(location, vect(0.0, 0.0, 1.0));
        ShutDown();
    }
}
