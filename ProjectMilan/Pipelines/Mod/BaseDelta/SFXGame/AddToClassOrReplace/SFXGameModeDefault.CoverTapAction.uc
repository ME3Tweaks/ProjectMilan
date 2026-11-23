// MILAN CHANGE - Mgamerz - 11/20/2026
// OmniKey-Split - Cover single tap behavior
public final exec function MilanCoverTapAction()
{
    if (TryAcquireCover())
    {
        return;
    }
    TryCoverSlip();
    if (BioPlayerInput(Outer.PlayerInput).SprintSharesCover())
    {
        TryForwardRoll();
    }
    TryExitCover();
}
