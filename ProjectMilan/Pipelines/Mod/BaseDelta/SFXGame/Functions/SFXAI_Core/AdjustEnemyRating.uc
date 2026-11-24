// MILAN CHANGE - 11/21/2026 - Mgamerz
// Add support for game effect that increases target priority
// This method was originally empty so all its implementation is new
public function AdjustEnemyRating(Pawn EnemyPawn, out float fRating)
{
    local SFXPawn_Player TargetPlayer;
    local SFXModule_GameEffectManager Manager;
    local SFXGameEffect PriorityEffect;
    local int EnemyIdx;

    if (Role != ENetRole.ROLE_Authority || WorldInfo.GRI == None || MyBP == None || int(MyBP.GetTeamNum()) != 1 || fRating <= 0.0)
    {
        return;
    }

    TargetPlayer = SFXPawn_Player(EnemyPawn);
    // Don't target invisible players
    if (TargetPlayer == None || TargetPlayer.IsInvisible())
    {
        return;
    }

    Manager = TargetPlayer.GetModule(Class'SFXModule_GameEffectManager');
    if (Manager == None)
    {
        return;
    }

    // Check priority effect is applied
    PriorityEffect = Manager.GetFirstEffectOfCategory('MilanObjectivePriority');
    if (PriorityEffect != None && PriorityEffect.EffectValue > 1.0)
    {
        fRating *= PriorityEffect.EffectValue;

        // MILAN CHANGE - 11/22/2026 - Mgamerz
        // Priority effect suppresses line of sight check
        EnemyIdx = GetEnemyIndex(EnemyPawn);
        if (EnemyIdx != -1 && EnemyPawn != PreferredTarget && !IsEnemyVisibleByIndex(EnemyIdx) && TimeSinceEnemyLocationUpdate(EnemyIdx) <= 1.0 && VSize(GetEnemyLocationByIndex(EnemyIdx) - Pawn.Location) > EnemyDistance_Short)
        {
            if (TimeSinceEnemyVisible(EnemyIdx) < 5.0)
            {
                fRating *= 2.0;
            }
            else
            {
                fRating *= 10.0;
            }
        }
        // END MILAN CHANGE
    }
}