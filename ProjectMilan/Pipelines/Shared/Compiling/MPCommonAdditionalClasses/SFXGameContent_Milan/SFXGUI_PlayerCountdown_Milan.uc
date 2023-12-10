// Manually made: 12/09/2023
// By: DropTheSquid
Class SFXGUI_PlayerCountdown_Milan extends SFXGUI_PlayerCountdown
    config(UI);

// Functions
public event function OnStart()
{
    // This replaces the superclass OnStart with one that is nearly identical, excpet we have redirected some delegates to new versions
    // that can't be directly overriden because they are private or final
    Super(SFXGUIMovie).OnStart();
    Animations[0] = GetVariableObject("_root.DeathRootInstance.DeathCoreInstance").CastTo(Class'SFXGUIValue_ManualAnimController');
    // redirected to OnDeathStartedEX because OnDeathStarted is final
    Animations[0].__OnAnimStarted__Delegate = OnDeathStartedEX;
    Animations[0].__OnAnimAborted__Delegate = OnDeathAborted;
    Animations[0].__OnAnimFinished__Delegate = OnDeathFinished;
    Animations[0].Initialize();
    Animations[0].StartFrame = 1;
    Animations[1] = GetVariableObject("_root.ThisPlayerReviveRootInstance.ThisPlayerReviveCoreInstance").CastTo(Class'SFXGUIValue_ManualAnimController');
    Animations[1].__OnAnimStarted__Delegate = ASPlayThisPlayerRevive;
    Animations[1].__OnAnimAborted__Delegate = OnThisPlayerReviveAborted;
    Animations[1].__OnAnimFinished__Delegate = OnThisPlayerReviveFinished;
    Animations[1].Initialize();
    Animations[2] = GetVariableObject("_root.OtherPlayerReviveRootInstance.OtherPlayerReviveCoreInstance").CastTo(Class'SFXGUIValue_ManualAnimController');
    Animations[2].__OnAnimStarted__Delegate = ASPlayOtherPlayerRevive;
    Animations[2].__OnAnimAborted__Delegate = OnOtherPlayerReviveAborted;
    Animations[2].__OnAnimFinished__Delegate = OnOtherPlayerReviveFinished;
    Animations[2].Initialize();
    UpdateEnabledState();
}
// this function is added in order to handle input switching
public event function HandleButtonRefresh(bool usingGamepad)
{
    Super(SFXGUIMovie).HandleButtonRefresh(usingGamepad);
    ActionScriptVoid("RefreshButtonHelp");
}
// this function is modified to use the new keybind that actually separates out keyboard/mouse and controller binds to support both at the same time better
public function OnDeathStartedEX()
{
    ASPlayDeath(("[" $ GetBoundKeyString("PC_ProlongLife", FALSE, 21)) $ "]");
}
// changed from base version to set the input mode initially
private final function ASPlayDeath(string PCText)
{
    HandleButtonRefresh(bUsingGamepad);
    ActionScriptVoid("PlayDeath");
}
// unchanged from base version. only included because the base version is private and I can't call it from here.
private final function ASPlayThisPlayerRevive()
{
    ActionScriptVoid("PlayThisPlayerRevive");
}
private final function ASPlayOtherPlayerRevive()
{
    ActionScriptVoid("PlayOtherPlayerRevive");
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
}