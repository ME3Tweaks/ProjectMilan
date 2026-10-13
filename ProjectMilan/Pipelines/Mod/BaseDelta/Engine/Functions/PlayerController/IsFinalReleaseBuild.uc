// MILAN CHANGE - Mgamerz - 2026-10-13
// ME3's Bink console patch returned false here so MP clients could create their cheat manager.
// Replace the LE3 native predicate with script to restore client profiles and debug messages.
public final function bool IsFinalReleaseBuild()
{
    return FALSE;
}
// END MILAN CHANGE
