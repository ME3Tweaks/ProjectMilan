defaultproperties
{
    Begin Template Class=MotionBlurEffect Name=s_DefaultBlur
        MaxVelocity = 0.5
        MotionBlurAmount = 0.400000006
    End Template
    Begin Template Class=SFXCameraInput Name=s_Input
        CameraSensitivity = {X = 30.0, Y = 20.0}
    End Template
    StickFactor = 0.0199999996
    FullTurnRecenter = 1.0
    Blur = s_DefaultBlur
    Offset = {X = 135.0, Y = -17.0, Z = 45.0}
    HookOffset = {X = -10.0, Y = 40.0, Z = 90.0}
    Input = s_Input
    FOV = 90.0
    // MILAN CHANGE - 2026/11/08 - Stumpy - make the centering a touch less aggressive
    RecenterStrength = 8.0
    // MILAN END
    bRecenterCameraNew = TRUE
}