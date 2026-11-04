// MILAN CHANGE - Stumpy - 2026-10-23
// Get zoom FOV offset
public function Tick(float TimeDelta)
{
    local BioPlayerController PC;
    local Actor Ignored;
    local Object.Vector HitLocation;
    local Object.Vector HitNormal;
    local SFXWeapon Weapon;
    local SFXEngine Engine;
    local int nFOV;
    
    PC = BioPlayerController(GetViewTargetAsController());
    m_pov.Rotation = PC.Rotation;
    m_pov.location = GetCameraLocation();
    m_pov.FOV = FOV;
    BioWorldInfo(PC.WorldInfo).SetRenderStateOfPlayerToDefault(0);
    Weapon = SFXWeapon(PC.Pawn.Weapon);
    if (Weapon != None && PC.GameModeManager2.IsActive(8) == FALSE)
    {
        // MILAN CHANGE 2026-10-23 - Stumpy
        Engine = SFXEngine(Class'SFXEngine'.static.GetEngine());
        Engine.GetProfileSettings().GetMilanZoomFov(nFOV);
        m_pov.FOV = Weapon.GetZoomFOV() + float(nFOV * Class'MilanGUI_Option_ZoomFOV'.default.Multiplier);
        // MILAN END
        if (ZoomData != None)
        {
            if (Weapon.AimModes[Weapon.CurrentAimMode].bScoped)
            {
                SFXPlayerCamera(PC.PlayerCamera).GetTrace(Ignored, HitLocation, HitNormal);
                ZoomData.Focus(VSize(m_pov.location - HitLocation), BioWorldInfo(PC.WorldInfo));
                ZoomData.Tick(TimeDelta, m_pov.FOV, 1.0);
            }
        }
    }
}

