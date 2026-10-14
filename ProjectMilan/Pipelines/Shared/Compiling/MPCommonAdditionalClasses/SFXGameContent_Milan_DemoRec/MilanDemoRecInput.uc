// MILAN CHANGE - Mgamerz - 2026-10-08
// Load demo camera controls from BioInput without saving gameplay input preferences.
Class MilanDemoRecInput extends PlayerInput within PlayerController
    config(Input);

var config float DemoMouseSensitivity;
var config bool bDemoInvertLook;
var config bool bDemoInvertTurn;
var config bool bDemoMouseSmoothing;

// The inherited mouse preferences are globalconfig. Use this class's own config values
// for the spectator instance so BioInput can control them independently.
public event function PlayerInput(float DeltaTime)
{
    MouseSensitivity = DemoMouseSensitivity;
    bInvertMouse = bDemoInvertLook;
    bInvertTurn = bDemoInvertTurn;
    bEnableMouseSmoothing = bDemoMouseSmoothing;
    Super.PlayerInput(DeltaTime);
}

defaultproperties
{
    DemoMouseSensitivity = 40.0
}