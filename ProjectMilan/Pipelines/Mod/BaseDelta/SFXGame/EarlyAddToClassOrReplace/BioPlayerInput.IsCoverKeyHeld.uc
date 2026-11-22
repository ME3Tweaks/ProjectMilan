// MILAN CHANGE - Mgamerz - 11/20/2026
// True while a key bound to PC_Cover (keyboard) or Shared_Action (controller) is down.
public final function bool IsCoverKeyHeld()
{
    if (GetCurrentGameMode() == None)
    {
        return TRUE;
    }
    return MilanIsAliasKeyHeld("PC_Cover") || MilanIsAliasKeyHeld("Shared_Action");
}
