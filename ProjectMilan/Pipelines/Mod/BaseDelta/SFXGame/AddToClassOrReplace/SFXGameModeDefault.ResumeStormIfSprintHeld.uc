// MILAN CHANGE - Mgamerz - 11/21/2026
// OmniKey-Split - Callback for storm when sliding over cover to turn it back on
public final function ResumeStormIfSprintHeld()
{
    if (BioPlayerInput(Outer.PlayerInput).IsAliasKeyHeld("PC_Sprint"))
    {
        StormOn();
    }
}
