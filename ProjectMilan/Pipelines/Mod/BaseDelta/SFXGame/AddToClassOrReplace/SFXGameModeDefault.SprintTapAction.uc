// MILAN CHANGE - Mgamerz - 11/19/2026
// OmniKey-Split - Forward rold when sprinting (only if cover is on a different key)
public final exec function MilanSprintTapAction()
{
    if (BioPawn(Outer.Pawn) == None || BioPawn(Outer.Pawn).bStorming || BioPlayerInput(Outer.PlayerInput).SprintSharesCover())
    {
        return;
    }
    TryForwardRoll();
}
