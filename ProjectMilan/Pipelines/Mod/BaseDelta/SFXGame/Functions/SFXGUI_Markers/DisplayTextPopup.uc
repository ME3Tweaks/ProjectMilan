// MILAN CHANGE - Mgamerz - 2026-10-19
// Apply visibility when in photo mode
public final function DisplayTextPopup(string Text)
{
    local BioPlayerController PC;
    local SFXGameModePhoto Photo;

    PC = BioPlayerController(GetPC());
    if (PC != None && PC.GameModeManager2 != None)
    {
        Photo = PC.GameModeManager2.GetPhotoMode();
        if (Photo != None && Photo.bMPSpectatorPhoto && Photo.bIsActive && (Photo.bMPPhotoOverlaysHidden || Photo.bMPPhotoHintsHidden))
        {
            // Don't show
            return;
        }
    }
    ASPlayTextPopupAnimation(Text);
}