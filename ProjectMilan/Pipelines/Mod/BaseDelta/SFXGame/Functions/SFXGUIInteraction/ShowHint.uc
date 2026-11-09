// MIAN CHANGE
// Photo mode support can hide hints
public event function ShowHint(stringref srConsoleText, stringref srPCText, float fDisplayTime, optional int nIcon = 0, optional SFXHintPosition ePosition = 2, optional bool bCache = FALSE, optional bool bForceVisible = FALSE, optional PlayerController oPlayerController)
{
    local SFXGameModePhoto Photo;

    local int N;
    local bool bUsePreload;
    
    oPlayerController = ValidatePlayerController(oPlayerController);
    CancelHint(oPlayerController);
    if (BioPlayerController(oPlayerController).GameModeManager2.ShouldAllowMessageUI() == FALSE && bForceVisible == FALSE)
    {
        return;
    }
    if (m_aHintStack.Length == 0)
    {
        m_aHintStack[0] = None;
    }
    else if (m_aHintStack[0] != None)
    {
        m_aHintStack[0].HideMessageBox(m_aHintStack[0] != m_oPreloadedHint, TRUE);
        m_aHintStack[0] = None;
    }
    bUsePreload = TRUE;
    for (N = 0; N < m_aHintStack.Length; ++N)
    {
        if (m_aHintStack[N] == m_oPreloadedHint)
        {
            bUsePreload = FALSE;
            break;
        }
    }
    if (bUsePreload)
    {
        m_aHintStack[0] = m_oPreloadedHint;
    }
    if (m_aHintStack[0] == None)
    {
        m_aHintStack[0] = CastOpenMovie(Class'BioSFHandler_MessageBox', oPlayerController, MovieTag_HintBox, TRUE, FALSE, TRUE);
        if (m_oPreloadedHint == None)
        {
            m_oPreloadedHint = m_aHintStack[0];
        }
    }
    if (m_aHintStack[0] == None)
    {
        return;
    }
    // MILAN CHANGE - Mgamerz - 2026-10-28
    // Force a hint in the stack to be visible
    m_aHintStack[0].m_bForceVisible = bForceVisible;
    // END MILAN CHANGE
    if (fDisplayTime > 0.0)
    {
        m_aHintStack[0].m_fHintTimeRemaining = fDisplayTime;
        m_aHintStack[0].SetUpdateDelegate(UpdateHint);
    }
    m_aHintStack[0].SetVisible(TRUE);
    m_aHintStack[0].DisplayHintMessage(srConsoleText, srPCText, nIcon, ePosition);
    // MILAN CHANGE - Mgamerz - 2026-10-19
    // Apply hint visibility when in photo mode
    if (BioPlayerController(oPlayerController) != None && BioPlayerController(oPlayerController).GameModeManager2 != None)
    {
        Photo = BioPlayerController(oPlayerController).GameModeManager2.GetPhotoMode();
        if (Photo != None)
        {
            // MILAN CHANGE - Mgamerz - 2026-10-28
            // Connection loss is a priority event 
            if (bForceVisible) 
            {
                Photo.RevealMPPhotoOverlaysForAlert();
            }
            // END MILAN CHANGE
            Photo.ApplyMPPhotoHintVisibility();
        }
    }
    // END MILAN CHANGE
}
