// MILAN CHANGE - Mgamerz - 2026-10-16
// Reuse the photo UI through its multiplayer lifecycle, keeping spectator mode underneath it
public exec function EnterSpectatorPhotoMode()
{
    local SFXGUIInteraction UI;
    local SFXGameModePhoto Photo;

    if (LocalPlayer(Outer.Player) == None || Outer.PlayerCamera == None || !Outer.GameModeManager2.IsActive(20) || Outer.GameModeManager2.IsActive(14))
    {
        return;
    }
    UI = Class'SFXGUIInteraction'.static.GetInstance();
    Photo = Outer.GameModeManager2.GetPhotoMode();
    if (UI != None && Photo != None)
    {
        Photo.bMPSpectatorPhoto = TRUE;
        LogInternal("MilanPhoto: spectator requested photo mode");
        UI.ShowPhotoMode(Outer);
    }
}
// END MILAN CHANGE
