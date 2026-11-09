// MILAN CHANGE - Mgamerz - 2026-10-28
// On connection loss, force overlays on in photo mode so user can actually see them
public function OnGameConnectionLost()
{
    LogInternal("OnGameConnectionLost");
    if (GameModeManager2 != None && GameModeManager2.GetPhotoMode() != None) {
        GameModeManager2.GetPhotoMode().RevealMPPhotoOverlaysForAlert();
    }
    ForceOnlineSubCleanUp();
    if (IsSignedIn())
    {
        ShowNetworkErrorMessage();
    }
}