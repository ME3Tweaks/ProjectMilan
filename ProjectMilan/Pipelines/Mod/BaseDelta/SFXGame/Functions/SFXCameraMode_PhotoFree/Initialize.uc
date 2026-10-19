// MILAN CHANGE - Mgamerz - 2026-10-16
// MP camera state belongs to this mode's local owning controller, never its viewed pawn
public function Initialize()
{
    local PlayerController C;
    local Vector Loc;
    local Rotator Rot;
    local SFXGameModePhoto Photo;

    Super(SFXCameraMode).Initialize();
    Photo = SFXGameModePhoto(Outer);
    if (Photo != None && Photo.bMPSpectatorPhoto)
    {
        m_pov = Photo.MPPhotoPOV;
        return;
    }
    C = PlayerController(GetViewTargetAsController());
    if (C != None)
    {
        C.GetPlayerViewPoint(Loc, Rot);
        C.SetLocation(Loc);
        C.SetRotation(Rot);
        m_pov.Location = Loc;
        m_pov.Rotation = Rot;
    }
}
// END MILAN CHANGE
