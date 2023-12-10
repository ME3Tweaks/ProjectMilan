// SFXGameMPContent.SFXPlayerControllerMP.CheckIfConnectedFailsafe - 12/10/2023
// By Mgamerz
// Patches out the online failsafe check which brings up 'you have lost connection to the server'
public function bool CheckIfConnectedFailsafe()
{
    local ISFXOnlineComponentLogin oLogin;
    local BioMessageBoxOptionalParams stParams;
    local BioSFHandler_MessageBox oMsgBox;
    local bool bIsSignedIn;
    
    return TRUE; // MILAN CHANGE
    oLogin = Class'SFXOnlineSubsystem'.static.GetOnlineSubsystem().GetComponentLogin();
    bIsSignedIn = oLogin != None && oLogin.IsSignedIn();
    if (!bIsSignedIn)
    {
        oMsgBox = Class'SFXGUIInteraction'.static.GetInstance().CreateMessageBox(Self);
        oMsgBox.SetInputDelegate(BackToMainMenu);
        stParams.srAText = srOK;
        stParams.bModal = TRUE;
        stParams.bNoFade = TRUE;
        oMsgBox.DisplayMessageBox($602982, stParams);
    }
    return bIsSignedIn;
}