// MILAN CHANGE - 12/14/2023
// By Mgamerz
// Purpose: Development - let store show pack contents even if online save failed (we currently have no 'online' component)
public function OnPurchaseCreditsCallback(int nResult)
{
    local BioMessageBoxOptionalParams stParams;
    
    ClearQueuedNotification('CreditWaiting');
    if (nResult == 0 || nResult == -1) // MILAN CHANGE - Writing save data returns -1. For now, just accept this valuen
    {
        GetLobbyFlow().SetLastSelectedOffer(GAWManager.GetOfferIDFromStoreID(SelectedID));
        ShowReinforcementsRevealScreen(FALSE);
    }
    else
    {
        stParams.bNoFade = TRUE;
        stParams.srAText = srOK;
        Class'SFXGUIInteraction'.static.GetInstance().QueueNamedMessageBox('PurchaseCreditsError', 2, srPurchaseError, stParams, OnPurchaseCreditsErrorDialogFinished);
    }
}