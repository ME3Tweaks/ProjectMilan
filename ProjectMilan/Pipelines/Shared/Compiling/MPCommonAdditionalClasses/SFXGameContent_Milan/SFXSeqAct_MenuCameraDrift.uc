// MILAN CHANGE - Mgamerz - 2026-10-31
// Latent kismet action to handle the splash camera movement - linear start, cubic slow, then camera bob once done
class SFXSeqAct_MenuCameraDrift extends SeqAct_Latent;

// The camera that moves and the camera whose view it ends on
var() Name CameraTag;
var() Name EndTag;
// Seconds at a steady speed, then seconds slowing to rest
var() float CruiseSeconds;
var() float StopSeconds;
// Too slight and it moves the picture less than a pixel a frame, which reads as
// distant edges shimmering rather than as movement
var() float SwayBlendSeconds;
var() float SwayDistance;
var() int SwayPitch;
var() int SwayYaw;
var() float SwayLoopSeconds;

var transient CameraActor Camera;
var transient Vector StartLocation;
var transient Vector EndLocation;
var transient Rotator StartRotation;
var transient Rotator EndRotation;
var transient float StartFOV;
var transient float EndFOV;
var transient float Elapsed;
// Set once the camera has rendered once
var transient bool bWasViewed;

public event function Activated()
{
    local CameraActor Found;
    local CameraActor End;

    Camera = None;
    foreach GetWorldInfo().AllActors(Class'CameraActor', Found)
    {
        if (Found.Tag == CameraTag)
        {
            Camera = Found;
        }
        else if (Found.Tag == EndTag)
        {
            End = Found;
        }
    }
    if (Camera == None || End == None)
    {
        Camera = None;
        return;
    }

    StartLocation = Camera.Location;
    StartRotation = Camera.Rotation;
    StartFOV = Camera.FOVAngle;
    EndLocation = End.Location;
    EndRotation = End.Rotation;
    EndFOV = End.FOVAngle;
    Elapsed = 0.0;
    bWasViewed = FALSE;
    // Nothing should stop it moving
    Camera.SetCollision(FALSE, FALSE);
}

public event function bool Update(float DeltaTime)
{
    local float Alpha;
    local float SwayTime;
    local float Weight;
    local float Phase;
    local Vector NewLocation;
    local Vector Sway;
    local Rotator NewRotation;
    local Rotator SwayRotation;

    if (Camera == None)
    {
        return FALSE;
    }
    if (IsViewed())
    {
        bWasViewed = TRUE;
    }
    else if (bWasViewed)
    {
        return FALSE;
    }

    Elapsed += DeltaTime;
    Alpha = GetPathAlpha(Elapsed);
    NewLocation = VLerp(StartLocation, EndLocation, Alpha);
    NewRotation = RLerp(StartRotation, EndRotation, Alpha, TRUE);

    SwayTime = Elapsed - CruiseSeconds - StopSeconds;
    if (SwayTime > 0.0)
    {
        // Fades in from nothing with no jolt
        Weight = FMin(SwayTime / SwayBlendSeconds, 1.0);
        Weight = Weight * Weight * (3.0 - 2.0 * Weight);
        Phase = 2.0 * Pi * SwayTime / SwayLoopSeconds;
        Sway.X = Sin(Phase * 4.0 + 0.5) * SwayDistance;
        Sway.Y = Sin(Phase * 3.0 + 1.9) * SwayDistance;
        Sway.Z = Sin(Phase * 5.0 + 3.1) * SwayDistance * 0.6;
        NewLocation += Sway * Weight;

        SwayRotation.Pitch = Round(Sin(Phase * 5.0 + 0.9) * float(SwayPitch) * Weight);
        SwayRotation.Yaw = Round(Sin(Phase * 3.0 + 2.6) * float(SwayYaw) * Weight);
        NewRotation += SwayRotation;
    }

    Camera.SetLocation(NewLocation);
    Camera.SetRotation(NewRotation);
    Camera.FOVAngle = Lerp(StartFOV, EndFOV, Alpha);
    return TRUE;
}

// How far along the path (0-1) the camera is after Seconds
// A steady speed for CruiseSeconds
// Slowing to rest over StopSeconds
// Speed falling off as 1 - smoothstep so neither end of the slowdown jolts
public function float GetPathAlpha(float Seconds)
{
    local float Speed;
    local float X;

    Speed = 1.0 / (CruiseSeconds + StopSeconds * 0.5);
    if (Seconds <= CruiseSeconds)
    {
        return Seconds * Speed;
    }
    X = FMin((Seconds - CruiseSeconds) / StopSeconds, 1.0);
    return Speed * (CruiseSeconds + StopSeconds * (X - X * X * X + 0.5 * X * X * X * X));
}

// Whether the player is currently viewing this camera
public function bool IsViewed()
{
    local PlayerController PC;

    PC = GetWorldInfo().GetALocalPlayerController();
    if (PC == None || PC.PlayerCamera == None)
    {
        return FALSE;
    }
    return PC.PlayerCamera.ViewTarget.Target == Camera || PC.PlayerCamera.PendingViewTarget.Target == Camera;
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    CameraTag = 'MilanMenu_VistaCam'
    EndTag = 'MilanMenu_VistaCamEnd'
    CruiseSeconds = 38.0
    StopSeconds = 14.0
    SwayBlendSeconds = 6.0
    SwayDistance = 18.0
    SwayPitch = 150
    SwayYaw = 260
    SwayLoopSeconds = 40.0
    bCallHandler = FALSE
    InputLinks = ({LinkDesc = "Start"})
    VariableLinks = ()
}
