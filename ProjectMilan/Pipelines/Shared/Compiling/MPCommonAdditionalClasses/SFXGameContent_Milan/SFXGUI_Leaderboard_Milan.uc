Class SFXGUI_Leaderboard_Milan extends SFXGUI_Leaderboard
    config(UI);

// Functions
// added so we can react to changing input modes
public event function HandleButtonRefresh(bool usingGamepad)
{
    Super(SFXGUIMovie).HandleButtonRefresh(usingGamepad);
	SetMouseVisible(!bUsingGamepad);
    ActionScriptVoid("screen.RefreshButtonHelp");
}
// added to set the mouse visibility on start according to the UI mode
public event function OnStart()
{
    Super.OnStart();
    // make sure we actually can control the mouse visibility
	BioPlayerController(GetPC()).GameModeManager2.GameModes[int(EGameModes.GameMode_Lobby)].bHasMouseAuthority = false;
	// make sure the mouse is initially shown/hidden based on the input mode
	SetMouseVisible(!bUsingGamepad);
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
}