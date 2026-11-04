// MILAN CHANGE - Stumpy - 2026-10-23
// Get zoom FOV offset
public function Initialize()
{
    local BioPlayerController PC;
    // MILAN CHANGE 2026-10-23 - Stumpy
    local SFXEngine Engine;
    local int nFOV;
    // MILAN END
    
    PC = BioPlayerController(GetViewTargetAsController());
    if (PC != None && PC.Pawn != None && PC.Pawn.IsLocallyControlled())
    {
        CameraTargetDir = PC.Rotation;
    }
    else
    {
        CameraTargetDir = PC.Rotation;
    }
    // MILAN CHANGE 2026-10-23 - Stumpy
    Engine = SFXEngine(Class'SFXEngine'.static.GetEngine());
    Engine.GetProfileSettings().GetMilanFOV(nFOV);
    FOV = float(nFOV * Class'MilanGUI_Option_FOV'.default.Multiplier) + 70.0 + 10.0;
    // MILAN END
}
