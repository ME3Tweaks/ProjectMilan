// MILAN Change - 12/11/2023
// By Mgamerz
// Purpose: Development - force MPSaveManager to think it has initialized, otherwise several UIs will stall
// Can probably be removed once we have server code
public function Tick(float TimeDelta)
{
    local SFXEngine Engine; // MILAN CHANGE
    
    Super.Tick(TimeDelta);

    // MILAN CHANGE - Force initialize MPSaveManager--
    Engine = SFXEngine(Class'SFXEngine'.static.GetEngine());
    if (Engine != None && Engine.MPSaveManager == None)
    {
        Engine.InitializePlayerStorage();
        Engine.MPSaveManager.bInitialized = true;
    }
    else if (Engine.MPSaveManager.OnlineSave == None)
    {
        Engine.MPSaveManager.Initialize();
        Engine.MPSaveManager.bInitialized = true;
    }
    // END MILAN CHANGE--------------------------------

    if (GetPRI() != None && GetPRI().bReplicationReady)
    {
        if (!bPlayerDataSent)
        {
            if (IsReadyToSendPlayerDataToServer())
            {
                SendPlayerDataToServer();
                bPlayerDataSent = TRUE;
            }
        }
        else if (!bMPFlowStarted)
        {
            if (IsReadyToStartMPFlow())
            {
                StartMPFlow();
                bMPFlowStarted = TRUE;
            }
        }
        else if (!bReadyToEnterLobby)
        {
            if (IsReadyToEnterLobby())
            {
                EnterLobby();
                bReadyToEnterLobby = TRUE;
            }
        }
    }
}