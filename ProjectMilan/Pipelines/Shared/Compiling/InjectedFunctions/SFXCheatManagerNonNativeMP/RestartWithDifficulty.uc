// NEW TO MILAN 09/06/2026
// Mgamerz
// This method is used to restart the faction with the given difficulty. It makes it easier to debug things.
public exec function RestartWithDifficulty(string Difficulty)
{
    local int NewDifficulty;
    local SFXGRIMP GRIMP;
    
    switch (Locs(Difficulty))
    {
        case "bronze":
            NewDifficulty = 0;
            break;
        case "silver":
            NewDifficulty = 1;
            break;
        case "gold":
            NewDifficulty = 2;
            break;
        case "platinum":
            NewDifficulty = 3;
            break;
        case "diamond":
            NewDifficulty = 4;
            break;
        default:
            LogInternal(GetFuncName() @ "could not find valid difficulty for specified name '" $ Difficulty $ "'");
            return;
    }
    GRIMP = SFXGRIMP(Outer.WorldInfo.GRI);
    LogInternal("Switching active difficulty to " $ Difficulty);
    GRIMP.DifficultySetting = NewDifficulty;
    GRIMP.DifficultyHandler.CurrentDifficulty = byte(NewDifficulty);
    GRIMP.DifficultyHandler.bNeedsUpdate = TRUE;
    GRIMP.DifficultyHandler.Update();
    RestartFromCheckpoint();
}