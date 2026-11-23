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
        if (!BioPlayerInput(Outer.PlayerInput).SprintSharesCover() && BioPlayerInput(Outer.PlayerInput).IsAliasKeyHeld("PC_Sprint"))
        {
            SetTimer(0.2, FALSE, 'ResumeStormIfSprintHeld');
        }
        return TRUE;
    }
    return BioPlayerInput(Outer.PlayerInput).SprintSharesCover() && TryRoll();
}
