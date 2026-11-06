defaultproperties
{
    Begin Object Class=SFXCameraInput Name=s_Input
    End Object
    ViewTarget = {
                  POV = {
                         location = {X = 0.0, Y = 0.0, Z = 0.0}, 
                         Rotation = {Pitch = 0, Yaw = 0, Roll = 0}, 
                         FOV = 90.0
                        }, 
                  Target = None, 
                  Controller = None, 
                  PRI = None, 
                  AspectRatio = 0.0
                 }
    m_pov = {
             location = {X = 0.0, Y = 0.0, Z = 0.0}, 
             Rotation = {Pitch = 0, Yaw = 0, Roll = 0}, 
             FOV = 90.0
            }
    HookOffset = {X = 0.0, Y = 0.0, Z = 98.0}
    HookName = 'Camera'
    Input = s_Input
    FOV = 70.0
    AspectRatio = 1.77777779
    TimeToRecenter = 0.200000003
    RotationSpeedLimit = 200000.0
    // MILAN CHANGE - Stumpy - 2026/11/06
    // Lower recenter strength, still quick, but can actually move the camera
    RecenterStrength = 0.5
    // MILAN END
    bCollisionEnabled = TRUE
    bAllowSpectate = TRUE
}