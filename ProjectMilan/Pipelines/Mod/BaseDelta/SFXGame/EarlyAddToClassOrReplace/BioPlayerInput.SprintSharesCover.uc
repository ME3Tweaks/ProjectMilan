// MILAN CHANGE - Mgamerz - 11/20/2026
// True when a single key is bound to both sprint AND cover (not split)
public final function bool SprintSharesCover()
{
    local SFXGameModeBase Mode;
    local int i;
    local int j;

    Mode = GetCurrentGameMode();
    if (Mode == None)
    {
        return TRUE;
    }
    for (i = 0; i < Mode.Bindings.Length; i++)
    {
        // None/Unbound keys must be filtered out
        // or it messes up over-cover slide
        if (Mode.Bindings[i].Command ~= "PC_Sprint" && Mode.Bindings[i].Name != 'None' && Mode.Bindings[i].Name != 'Unbound')
        {
            for (j = 0; j < Mode.Bindings.Length; j++)
            {
                if (Mode.Bindings[j].Command ~= "PC_Cover" && Mode.Bindings[j].Name == Mode.Bindings[i].Name)
                {
                    return TRUE;
                }
            }
        }
    }
    return FALSE;
}
