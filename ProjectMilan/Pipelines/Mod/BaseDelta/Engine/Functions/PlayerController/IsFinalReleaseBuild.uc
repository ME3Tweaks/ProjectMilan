// MILAN CHANGE - Mgamerz - 2026-10-13
// In MP for some reason this returns true. Patch it to false. Our bink proxy for some reason is not reliably setting it
public final function bool IsFinalReleaseBuild()
{
    return FALSE;
}
// END MILAN CHANGE
