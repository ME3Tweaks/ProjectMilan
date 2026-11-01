// MILAN CHANGE - Mgamerz - 2026-10-28
// Catch effects started/replaced while spectating, as the photo camera already does.
public function Tick(float TimeDelta)
{
    local BioWorldInfo WI;
    local BioPlayerController PC;

    WI = BioWorldInfo(Class'Engine'.static.GetCurrentWorldInfo());
    PC = BioPlayerController(WI.GetLocalPlayerController());
    m_pov.Rotation = SFXPlayerCamera(PC.PlayerCamera).GetRotation();
    m_pov.location = GetCameraLocation();
    m_pov.FOV = FOV;
    WI.SetRenderStateOfPlayerToDefault(0);
    if (PC.GameModeManager2.GetPhotoMode() != None) {
        PC.GameModeManager2.GetPhotoMode().UpdateMPObserverScreenEffects();
    }
}
// END MILAN CHANGE
