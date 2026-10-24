// MIAN CHANGE
// Photo mode support can hide hints
public event function RestoreHint(optional PlayerController oPlayerController)
{
    local SFXGameModePhoto Photo;

    oPlayerController = ValidatePlayerController(oPlayerController);
    if (m_aHintStack.Length > 0)
    {
        if (m_aHintStack[0] != None)
        {
            CancelHint(oPlayerController);
            m_aHintStack[0].HideMessageBox(m_aHintStack[0] != m_oPreloadedHint, TRUE);
            m_aHintStack[0] = None;
        }
        m_aHintStack.Remove(0, 1);
    }
    if (m_aHintStack[0] != None)
    {
        m_aHintStack[0].SetVisible(TRUE);
    }
    // MILAN CHANGE - Mgamerz - 2026-10-19
    // Apply hint visibility when in photo mode
    if (BioPlayerController(oPlayerController) != None && BioPlayerController(oPlayerController).GameModeManager2 != None)
    {
        Photo = BioPlayerController(oPlayerController).GameModeManager2.GetPhotoMode();
        if (Photo != None) {
            Photo.ApplyMPPhotoHintVisibility();
        }
    }
    // END MILAN CHANGE
}