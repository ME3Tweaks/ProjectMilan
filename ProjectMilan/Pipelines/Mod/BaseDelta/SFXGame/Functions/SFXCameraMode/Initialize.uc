// MILAN CHANGE - Stumpy - 2026-10-23
// Get zoom FOV offset
public function Initialize()
{
    local SFXEngine Engine;
    local int nFOV;
    
    // Only original line in the file
    bRecenterCancelled = FALSE;
    
    Engine = SFXEngine(Class'SFXEngine'.static.GetEngine());
    Engine.GetProfileSettings().GetMilanFOV(nFOV);
    FOV = float(nFOV * Class'MilanGUI_Option_FOV'.default.Multiplier) + 70.0;
}