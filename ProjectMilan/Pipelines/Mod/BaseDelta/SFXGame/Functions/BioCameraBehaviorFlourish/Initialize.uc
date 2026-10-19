public function Initialize()
{
    local BioPlayerController PC;

    PC = BioPlayerController(GetViewTargetAsController());
    m_pov = PC.PlayerCamera.CameraCache.POV;
    // MILAN CHANGE - Mgamerz - 2026-10-19
    // Downed MP players must not inherit the previous weapon's zoomed FOV.
    if (PC.Pawn != None && PC.Pawn.IsA('SFXPawn_PlayerMP') && PC.Pawn.IsInState('Downed'))
    {
        m_pov.FOV = FOV;
    }
    // END MILAN CHANGE
    CurrentTime = 0.0;
    bInterpToStart = TRUE;
}
