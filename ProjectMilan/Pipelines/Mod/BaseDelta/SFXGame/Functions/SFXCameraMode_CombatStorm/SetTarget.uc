// MILAN CHANGE - Mgamerz - 2026-10-26
// Fix swapping controller/mouse breaking mouse turning
public function SetTarget()
{
    local BioPlayerController PC;
    local BioPlayerInput PInput;
    local int DeltaYaw;
    local Vector MoveStickAdjusted;

    PC = BioPlayerController(GetViewTargetAsController());
    if (PC != None && PC.Pawn != None && PC.Pawn.IsLocallyControlled())
    {
        // MILAN CHANGE - Mgamerz - 2026-10-26
        // Clone input so it doesn't modify the original
        if (Input != None && Input.Outer != Self)
        {
            Input = new (Self) Input.Class (Input);
        }
        // END MILAN CHANGE
        PInput = BioPlayerInput(PC.PlayerInput);
        if (!PC.WorldInfo.IsConsoleBuild() && !PInput.bUsingGamepad)
        {
            bRecenterCameraNew = FALSE;
            // MILAN CHANGE - Mgamerz - 2026-10-26
            // Restore camera sensitivity when returning to kbm
            Input.CameraSensitivity = default.Input.CameraSensitivity;
            // END MILAN CHANGE
        }
        else
        {
            bRecenterCameraNew = TRUE;
            // MILAN CHANGE - Stumpy - 2026-11-06
            // Restore camera control when sprinting with a controller 
            // Input.CameraSensitivity.X = 0.0;
            // Input.CameraSensitivity.Y = 0.0;
            // MILAN END
        }
        MoveStickAdjusted = PInput.MoveStick;
        MoveStickAdjusted.X = Abs(MoveStickAdjusted.X);
        CameraTargetDir = CameraTargetDir + Rotator(MoveStickAdjusted) * StickFactor;
        RecenterStrength = default.RecenterStrength;
    }
    else
    {
        CameraTargetDir = PC.Rotation;
    }
    DeltaYaw = (CameraTargetDir.Yaw - PC.Rotation.Yaw) % 65536;
    if (DeltaYaw > 32768)
    {
        DeltaYaw -= 65536;
    }
    if (DeltaYaw < -32767)
    {
        DeltaYaw += 65536;
    }
    CameraTargetDir.Yaw = PC.Rotation.Yaw + Clamp(DeltaYaw, -8192, 8192);
}
