Class SFXGUI_MPScoretags_Milan extends SFXGUI_MPScoretags
    config(UI);

// Functions
// MILAN CHANGE DropTheSquid 1/8/2024
// I am overriding and entirely replacing the vanilla OnStart method. I need to change the ViewScaleMode before other things are called. inserting code before or after doesn't work. 
public event function OnStart()
{
    local float x0;
    local float y0;
    local float X1;
    local float Y1;
    
	// this is sort of a change. I am explicitly skipping over the immediate superclass method, but this is the one the superclass called, so not really a change in functionality
    Super(SFXGUIMovie).OnStart();
	// this is the only actual change. The base method sets it to 0 (noScale) which causes the UI to not scale up at all, so it is comically tiny at 4k+
	// this sets it to ShowAll instead, which works.
    SetViewScaleMode(1);
	// the rest of the function is identical to the superclass version this replaces
    GetVisibleFrameRect(x0, y0, X1, Y1);
    ScreenLocationX = (X1 - x0) * (0.5 + LocationX) + x0;
    ScreenLocationY = (Y1 - y0) * (0.5 + LocationY) + y0;
    ActiveScoreTagAnim = GetVariableObject("_root.ScoreTagInstance").CastTo(Class'SFXGUIValue_ManualAnimController');
    ActiveScoreTagAnim.Initialize();
    ActiveScoreTagAnim.__OnAnimFinished__Delegate = FinishScoreTagClip;
    ActiveScoreTagAnim.__OnAnimAborted__Delegate = FinishScoreTagClip;
    ActiveScoreTagAnim.SetPosition(ScreenLocationX, ScreenLocationY);
    UpdateEnabledState();
}
// END MILAN

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
}