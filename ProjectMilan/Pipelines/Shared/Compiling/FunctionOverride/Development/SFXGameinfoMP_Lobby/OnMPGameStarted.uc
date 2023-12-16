// MILAN Change - 12/15/2023
// By Mgamerz
// Development(?) - Allows reloading MPLobby in lobby mode because GetResolvedConnectionString does not work in the online component.
public function OnMPGameStarted(bool bWasSuccessful)
{
    local string connectString;
    
    // MILAN CHANGE - Move connection string builder to always run.
    // The map is always set to lobby. You will not be able to join games with this
    // in a networked setup for now.
    connectString = "mplobby?listen";
    connectString $= "?origin=MultiplayerMenu";
    connectString $= "?privacy=" $ MatchMakingGameSettings.GetPrivacy();
    connectString $= "?map=" $ MatchMakingGameSettings.mME3MapName;
    connectString $= "?enemy=" $ MatchMakingGameSettings.EnemyType;
    connectString $= "?difficulty=" $ int(MatchMakingGameSettings.Difficulty);
    connectString = "open " $ connectString;

    // MILAN CHANGE - Remove original code.
    if (FALSE)
    {
        LogInternal("OnMPGameStarted: " $ bWasSuccessful, );
        if (OnlineSub != None)
        {
            GameInterface = OnlineSub.GameInterface;
            if (GameInterface != None)
            {
                if (bWasSuccessful)
                {
                    GameInterface.ClearCreateOnlineGameCompleteDelegate(OnCreateGameComplete);
                    GameInterface.ClearQuickMatchCompleteDelegate(OnQuickMatchComplete);
                    GameInterface.ClearDestroyOnlineGameCompleteDelegate(OnMultiplayerGameDestroyed);
                    if (GameInterface.GetResolvedConnectString('Game', connectString))
                    {
                        connectString $= "?origin=MultiplayerMenu";
                        connectString $= "?privacy=" $ MatchMakingGameSettings.GetPrivacy();
                        connectString $= "?map=" $ MatchMakingGameSettings.mME3MapName;
                        connectString $= "?enemy=" $ MatchMakingGameSettings.EnemyType;
                        connectString $= "?difficulty=" $ int(MatchMakingGameSettings.Difficulty);
                        connectString = "open " $ connectString;
                    }
                    else
                    {
                        OnMPFatalError("GetResolvedConnectString failed.");
                    }
                }
                else
                {
                    OnMPNetworkError("Starting MP match failed.");
                    CancelSearch();
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
    LogInternal("WorldInfoCC: " $ connectString, );
    // END MILAN
    WorldInfo.ConsoleCommand(connectString);
}