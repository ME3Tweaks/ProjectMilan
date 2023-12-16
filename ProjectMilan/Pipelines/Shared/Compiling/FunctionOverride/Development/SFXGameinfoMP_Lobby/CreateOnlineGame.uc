// MILAN Change - 12/15/2023
// By Mgamerz
// Devlopment - Skip registering game on server to allow lobby creation.
public function bool CreateOnlineGame(SFXOnlineGameSettings GameSettings)
{
    local bool bMatchRequestSent;
    
    if (GameSettings == None)
    {
        OnMPFatalError("Should have valid GameSettings when calling CreateOnlineGame.");
        return FALSE;
    }
    // MILAN CHANGE -- Skip creating game on server for dev
    if (TRUE)
    {
        OnCreateGameComplete('Game', TRUE);
        return TRUE;
    }
    // END MILAN CHANGE
    if (OnlineSub != None)
    {
        GameInterface = OnlineSub.GameInterface;
        if (GameInterface != None)
        {
            GameInterface.AddDestroyOnlineGameCompleteDelegate(OnMultiplayerGameDestroyed);
            GameInterface.AddCreateOnlineGameCompleteDelegate(OnCreateGameComplete);
            bMatchRequestSent = GameInterface.CreateOnlineGame(0, 'Game', GameSettings);
            if (!bMatchRequestSent)
            {
                GameInterface.ClearCreateOnlineGameCompleteDelegate(OnCreateGameComplete);
            }
        }
    }
    return bMatchRequestSent;
}