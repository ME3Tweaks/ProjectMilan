// MILAN CHANGE - Mgamerz - 11/19/2026
// Gets the current game mode
public final function SFXGameModeBase GetCurrentGameMode()
{
    local SFXGameModeManager Manager;

    if (BioPlayerController(Outer) == None)
    {
        return None;
    }
    Manager = BioPlayerController(Outer).GameModeManager2;
    if (Manager == None)
    {
        return None;
    }
    return Manager.GameModes[int(Manager.CurrentMode)];
}
