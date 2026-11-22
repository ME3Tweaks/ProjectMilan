// MILAN CHANGE - Mgamerz - 11/21/2026
// OmniKey-Split - Check if sprint is still held so cover slide continues sprint
public final function MilanCoverResumeStorm()
{
    if (!BioPlayerInput(Outer.PlayerInput).MilanSprintSharesCover() && BioPlayerInput(Outer.PlayerInput).MilanIsAliasKeyHeld("PC_Sprint"))
    {
        SetTimer(0.2, FALSE, 'MilanResumeStormIfHeld');
    }
}
