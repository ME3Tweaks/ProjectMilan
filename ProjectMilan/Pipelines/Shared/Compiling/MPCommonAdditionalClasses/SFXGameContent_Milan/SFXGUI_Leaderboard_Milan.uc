Class SFXGUI_Leaderboard_Milan extends SFXGUI_Leaderboard
    config(UI);

// Functions
// added so we can react to changing input modes
public event function HandleButtonRefresh(bool usingGamepad)
{
    Super(SFXGUIMovie).HandleButtonRefresh(usingGamepad);
	SetMouseVisible(!usingGamepad);
    ActionScriptVoid("screen.RefreshButtonHelp");
}
// added to set the mouse visibility on start according to the UI mode
public event function OnStart()
{
    Super.OnStart();
    // MILAN Change DropTheSquid 10/31/2026
	// make sure the mouse is initially shown/hidden based on the input mode, updated to prevent the mouse briefly flickering
	SetMouseVisible(!IsUsingGamepad());
    // END MILAN
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
}