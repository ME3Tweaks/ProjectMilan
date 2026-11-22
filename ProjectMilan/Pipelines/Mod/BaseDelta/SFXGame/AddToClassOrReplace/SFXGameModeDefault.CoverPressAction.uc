// MILAN CHANGE - Mgamerz - 11/20/2026
// OmniKey-Split - Cover press while sprinting
public final exec function bool MilanCoverPressAction()
{
    if (TryAcquireCover(FALSE, TRUE))
    {
        return FALSE;
    }
    if (TryCoverAction())
    {
        MilanCoverResumeStorm();
        return TRUE;
    }
    return BioPlayerInput(Outer.PlayerInput).MilanSprintSharesCover() && TryRoll();
}
