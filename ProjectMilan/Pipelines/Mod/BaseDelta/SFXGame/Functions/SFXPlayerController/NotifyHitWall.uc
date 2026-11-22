// MILAN CHANGE - 11/19/2026 - Mgamerz
// Omni-key split - when running into wall you don't get in cover if cover and sprint are split up
public function bool NotifyHitWall(Object.Vector HitNormal, Actor Wall)
{
    local BioCustomAction Action;
    local BioPawn MyBP;
    local BioPlayerInput Input;

    MyBP = BioPawn(Pawn);
    if (MyBP != None && MyBP.GetCurrentCustomAction(Action) && Action.NotifyHitWall(HitNormal, Wall))
    {
        return TRUE;
    }
    if (MyBP.IsLocallyControlled())
    {
        Input = BioPlayerInput(PlayerInput);
        if (MyBP.bStorming)
        {
            if (Input.RawJoyRight > 0.707000017 || Input.RawJoyRight < -0.707000017 || Input.RawJoyUp < -0.707000017)
            {
                return FALSE;
            }
            // MILAN CHANGE - Storming into wall only gets into cover if cover key is actually used
            if (Input.IsCoverKeyHeld())
            {
                GetGameModeDefault().TryAcquireCover(FALSE);
            }
            // END MILAN CHANGE
        }
        if (MyBP.CurrentCustomAction == 56)
        {
            if (Input.RawJoyRight > 0.707000017 || Input.RawJoyRight < -0.707000017 || Input.RawJoyUp < -0.707000017)
            {
                return FALSE;
            }
            GetGameModeDefault().TryAcquireCover(TRUE);
        }
    }
    return Super(Controller).NotifyHitWall(HitNormal, Wall);
}
