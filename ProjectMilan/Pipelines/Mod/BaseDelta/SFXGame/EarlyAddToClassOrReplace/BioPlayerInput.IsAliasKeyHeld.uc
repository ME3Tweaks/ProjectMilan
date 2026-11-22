// MILAN CHANGE - Mgamerz - 11/2026-11-21
// True while a key bound to Alias in the current mode is down
public final function bool IsAliasKeyHeld(string Alias)
{
    local SFXGameModeBase Mode;
    local int i;

    Mode = GetCurrentGameMode();
    if (Mode == None)
    {
        return FALSE;
    }
    for (i = 0; i < Mode.Bindings.Length; i++)
    {
        if (Mode.Bindings[i].Command ~= Alias && PressedKeys.Find(Mode.Bindings[i].Name) != -1)
        {
            return TRUE;
        }
    }
    return FALSE;
}
