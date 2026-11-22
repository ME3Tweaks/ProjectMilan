// MILAN CHANGE - Mgamerz - 11/19/2026
// OmniKey-Split - Roll behavior unless sprint/cover are on the same key (handled elsewhere in that case)
public final exec function bool MilanSprintPressAction()
{
    if (BioPlayerInput(Outer.PlayerInput).MilanSprintSharesCover())
    {
        return FALSE;
    }
    return TryRoll();
}
