// MILAN Change - 12/10/2023
// By Mgamerz
// Purpose: Patch out CanPlayOnline() as server component does not exist and always returns 0.
// Do we want to support server bans? I guess that should be handled at the server by rejecting login?
public function StartMPMatch(optional SFXOnlineGameSettings GameSettings)
{
    local SFXGUIInteraction oGuiMgr;
    local BioSFHandler_MessageBox oMsgBox;
    local BioMessageBoxOptionalParams stParams;
    local bool bMatchRequestSent;
    
    if (OnlineSub != None)
    {
        GameInterface = OnlineSub.GameInterface;

        // MILAN CHANGE - Remove this code
        //if (int(SFXOnlineSubsystem(OnlineSub).GetComponentLogin().CanPlayOnline()) == 0)
        //{
        //    CancelSearch();
        //    ShowNetworkErrorPrompt(srOnlinePrivilegeError);
        //}
        //else 
        if (GameInterface != None)
        {
            if (GameSettings == None)
            {
                bMatchRequestSent = QuickMatch();
            }
            else
            {
                MatchMakingGameSettings = GameSettings.Copy();
                if (MatchMakingGameSettings.mCreateNewMatch)
                {
                    bMatchRequestSent = CreateOnlineGame(MatchMakingGameSettings);
                }
                else
                {
                    bMatchRequestSent = QuickMatch(MatchMakingGameSettings);
                }
            }
            if (bMatchRequestSent)
            {
                oGuiMgr = GetPC().GetSFXUIController();
                oMsgBox = oGuiMgr.CreateMessageBox(GetPC());
                stParams.bModal = TRUE;
                oMsgBox.SetInputDelegate(CancelSearchInput);
                stParams.srBText = srCancel;
                oMsgBox.DisplayMessageBox(MatchMakingGameSettings.mCreateNewMatch ? srCreatingGame : srSearchingForGames, stParams);
            }
            else
            {
                GameInterface.ClearDestroyOnlineGameCompleteDelegate(OnMultiplayerGameDestroyed);
                OnMPFatalError(Self @ GetFuncName());
            }
        }
        else
        {
            OnMPFatalError(Self @ GetFuncName());
        }
    }
    else
    {
        OnMPFatalError(Self @ GetFuncName());
    }
}