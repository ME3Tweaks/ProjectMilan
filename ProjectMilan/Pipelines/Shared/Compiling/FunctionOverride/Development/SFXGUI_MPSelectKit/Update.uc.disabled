// MILAN Change - 12/11/2023
// By Mgamerz
// Purpose: Development - force MPSaveManager to think it has initialized, otherwise it will forever stay loading characters.
public event function Update(float fDeltaT)
{
    Super(SFXGUIMovie).Update(fDeltaT);
    if (bWaitingForCharacters)
    {
        if (m_bBeingUnitTested)
        {
            bWaitingForCharacters = FALSE;
        }
        else if (MPSaveManager.bInitialized == FALSE)
        {
            // MILAN CHANGE - Force SaveManager to be initialized if OnlineSave is populated
            if (MPSaveManager.OnlineSave != None)
            {
                MPSaveManager.bInitialized = TRUE;
            }
            GetSFXUIController().GetSaveLoadWidget().ShowNetworkMessage(FALSE);
            if (WaitMessageBox == None)
            {
                ShowWaitMessageBox(srLoadingCharacters);
            }
        }
        else
        {
            GetSFXUIController().GetSaveLoadWidget().HideNetworkMessage(FALSE);
            if (WaitMessageBox != None)
            {
                HideWaitMessageBox();
            }
            AS_InitializeScreen();
            bWaitingForCharacters = FALSE;
        }
    }
}