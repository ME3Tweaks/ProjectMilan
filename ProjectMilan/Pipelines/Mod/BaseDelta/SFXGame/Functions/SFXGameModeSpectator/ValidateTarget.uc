// MILAN CHANGE - Mgamerz - 2026-10-16
// The photo UI owns its subject (including downed pawns) while photomode (14) is active
public function ValidateTarget()
{
    local SFXPawn_Player TargetPawn;

    if (Outer.GameModeManager2.IsActive(14))
    {
        return;
    }
    TargetPawn = SFXPawn_Player(Outer.PlayerCamera.PendingViewTarget.Target);
    if (TargetPawn == None)
    {
        TargetPawn = SFXPawn_Player(Outer.PlayerCamera.ViewTarget.Target);
    }
    if (TargetPawn == None || TargetPawn.IsDead() || TargetPawn.IsInState('Dying') || TargetPawn.IsInState('Downed'))
    {
        Outer.ViewNextPlayer();
    }
}
// END MILAN CHANGE
