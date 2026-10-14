// MILAN CHANGE - Mgamerz - 2026-10-08
// Replicate a demo spectator controller, initialize a local playback camera,
// and close LMP's loading screen after the native player handoff.
// Export: SFXGAmeContent_Milan_DemoRec.MilanDemoRecSpectator, forced into BIOP_MP_COMMON.
// Source layout follows LECCLI's decompiled output; comments are added for the Milan handoff.
Class MilanDemoRecSpectator extends PlayerController
    config(Game);

var transient bool bDemoLoadScreenRequested;
var transient float DemoUpAxis;

public event simulated function PostBeginPlay()
{
    Super.PostBeginPlay();
    GotoState('DemoSpectating', , , );
}
// Playback has no gameplay GameInfo. This spectator does not create a gameplay PRI.
function InitPlayerReplicationInfo()
{
}
// This controller belongs to the demo connection and never logged into the gameplay GameInfo.
// Keep the base controller cleanup, but prevent it from logging out an unregistered MP player.
public event function Destroyed()
{
    bIsPlayer = FALSE;
    Super.Destroyed();
}
// A footage spectator does not spawn a gameplay HUD.
function SpawnDefaultHUD()
{
}
// Skip the base gameplay cheat-manager setup for this controller.
function AddCheats()
{
}
// MilanDemoRecInput loads the spectator bindings and preferences from BioInput.
public event function InitInputSystem()
{
    if (PlayerInput == None)
    {
        PlayerInput = new (Self) InputClass;
    }
    if (Interactions.Find(PlayerInput) == -1)
    {
        Interactions.AddItem(PlayerInput);
    }
}
// Native SetPlayer calls this for both the recording connection and the local playback player.
public event simulated function ReceivedPlayer()
{
    // During recording Player is a DemoRecConnection; only playback has a LocalPlayer.
    if (LocalPlayer(Player) == None)
    {
        LogInternal("MilanDemoRecSpectator: recording spectator attached.", );
        return;
    }
    bIgnoreMoveInput = 0;
    bIgnoreLookInput = 0;
    SetViewTarget(Self);
    if (PlayerCamera != None)
    {
        PlayerCamera.CameraStyle = 'FirstPerson';
    }
    GotoState('DemoSpectating', , , );
    LogInternal("MilanDemoRecSpectator: local playback spectator attached.", );
    // Allow native HandleClientPlayer to finish opening the connection before closing UI.
    SetTimer(0.100000001, FALSE, 'FinishDemoPlaybackLoading', );
}
// Use the SFX loading/UI completion calls without requiring an MP gameplay pawn.
function FinishDemoPlaybackLoading()
{
    local SFXEngine Engine;
    local SFXGUIInteraction GUIManager;
    
    if (LocalPlayer(Player) == None || bDemoLoadScreenRequested)
    {
        return;
    }
    Engine = SFXEngine(Class'Engine'.static.GetEngine());
    if (Engine == None)
    {
        LogInternal("MilanDemoRecSpectator: SFXEngine unavailable; loading screen was not closed.", );
        return;
    }
    GUIManager = Class'SFXGUIInteraction'.static.GetInstance();
    if (GUIManager != None)
    {
        GUIManager.RemoveNamedMessageBox('LoadingScreenTimeout', Self);
        if (GUIManager.GetSaveLoadWidget() != None)
        {
            GUIManager.GetSaveLoadWidget().HideLoadingMessage(TRUE);
        }
        GUIManager.HideBlackScreen(Self, FALSE);
    }
    Engine.CloseLoadScreen(TRUE);
    bDemoLoadScreenRequested = TRUE;
    LogInternal("MilanDemoRecSpectator: requested loading-screen closure after rendering.", );
}
public event function PlayerTick(float DeltaTime)
{
    if (LocalPlayer(Player) != None && PlayerInput != None)
    {
        // A demo camera does not send possession acknowledgements or movement RPCs.
        // Preserve the vertical axis before the engine scales movement input by frame time.
        DemoUpAxis = PlayerInput.aUp;
        PlayerInput.PlayerInput(DeltaTime);
        PlayerMove(DeltaTime);
        AdjustFOV(DeltaTime);
    }
}
function bool IsSpectating()
{
    return TRUE;
}
// Console example: DemoCameraSpeed 1200. The default is 600 world units per second.
exec function DemoCameraSpeed(float NewSpeed)
{
    SpectatorCameraSpeed = FClamp(NewSpeed, 1.0, 100000.0);
    LogInternal("MilanDemoRecSpectator: camera speed " $ SpectatorCameraSpeed, );
}

// Move the camera locally. Recording has no LocalPlayer and never runs PlayerTick movement.
auto state DemoSpectating 
{
    public event simulated function BeginState(Name PreviousStateName)
    {
        bCollideWorld = FALSE;
        SetPhysics(0);
    }
    // Fly through the level: WASD, Q/E for world-Z movement, and Shift for 4x speed.
    function PlayerMove(float DeltaTime)
    {
        local Vector X;
        local Vector Y;
        local Vector Z;
        local Vector Direction;
        local float Speed;
        local float DirectionSize;
        
        UpdateRotation(DeltaTime);
        GetAxes(Rotation, X, Y, Z);
        // Raw stick values preserve partial deflection; cap diagonal movement at the camera speed.
        Direction = X * PlayerInput.RawJoyUp + Y * PlayerInput.RawJoyRight + vect(0.0, 0.0, 1.0) * DemoUpAxis;
        DirectionSize = VSize(Direction);
        if (DirectionSize > 1.0)
        {
            Direction /= DirectionSize;
        }
        Speed = SpectatorCameraSpeed;
        if (int(bRun) != 0)
        {
            Speed *= 4.0;
        }
        if (DirectionSize > 0.0)
        {
            SetLocation(location + Direction * Speed * DeltaTime, );
        }
    }
    exec function StartFire(optional byte FireModeNum)
    {
    }
    exec function StartAltFire(optional byte FireModeNum)
    {
    }
    
    stop;
};

// Generated class defaults can also be inspected on Default__MilanDemoRecSpectator.
// Replication flags admit the spectator to the demo stream; movement stays local during playback.
defaultproperties
{
    RemoteRole = ENetRole.ROLE_AutonomousProxy
    bForceDemoRelevant = TRUE
    bDemoOwner = TRUE
    bReplicateMovement = FALSE
    bNetInitialRotation = TRUE
    bCollideActors = FALSE
    bBlockActors = FALSE
    bCollideWorld = FALSE
    InputClass = Class'MilanDemoRecInput'
    CameraClass = Class'Camera'
    CheatClass = None
    ForceFeedbackManagerClassName = ""
    SpectatorCameraSpeed = 600.0
}