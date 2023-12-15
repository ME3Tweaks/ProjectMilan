Class SFXGUI_Leaderboard_Milan extends SFXGUI_Leaderboard
    config(UI);

// Functions
public event function HandleButtonRefresh(bool usingGamepad)
{
    Super(SFXGUIMovie).HandleButtonRefresh(usingGamepad);
    ActionScriptVoid("screen.RefreshButtonHelp");
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
}