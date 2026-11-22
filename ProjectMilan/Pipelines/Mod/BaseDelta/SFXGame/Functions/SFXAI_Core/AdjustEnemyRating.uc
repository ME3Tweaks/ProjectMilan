// MILAN CHANGE - 11/21/2026 - Mgamerz
// Add support for game effect that increases target priority
// This method was originally empty so all its implementation is new
public function AdjustEnemyRating(Pawn EnemyPawn, out float fRating)
{
    local SFXPawn_Player TargetPlayer;
    local SFXModule_GameEffectManager Manager;
    local SFXGameEffect PriorityEffect;

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
    }
}