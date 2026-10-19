// MILAN CHANGE - Mgamerz - 2026-10-16
// Update photo mode per tick in MP mode
public function Tick(float DeltaTime)
{
    local PlayerController PC;
    local SFXGameModePhoto Photo;

    Photo = SFXGameModePhoto(Outer);
    if (Photo != None && Photo.bMPSpectatorPhoto)
    {
        Photo.UpdateMPPhoto(DeltaTime);
        return;
    }
    PC = PlayerController(GetViewTargetAsController());
    if (PC != None)
    {
        m_pov.Location = PC.Location;
        m_pov.Rotation = PC.Rotation;
    }
    UpdateRollAndFOV(DeltaTime);
}
// END MILAN CHANGE
