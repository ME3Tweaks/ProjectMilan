defaultproperties
{
    Begin Template Class=MotionBlurEffect Name=s_DefaultBlur
        MaxVelocity = 0.5
        MotionBlurAmount = 0.400000006
    End Template
    // MILAN CHANGE - 2026/11/08 - Stumpy - Up the camera sensitivity to the same as the normal camera -30 to the Y axix
    Begin Template Class=SFXCameraInput Name=s_Input
        CameraSensitivity = {X = 90.0, Y = 60.0}
    End Template
    // MILAN END
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