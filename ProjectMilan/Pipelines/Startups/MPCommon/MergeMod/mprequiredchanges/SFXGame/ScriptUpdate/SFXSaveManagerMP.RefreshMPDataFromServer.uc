// MILAN CHANGE - 12/11/2023
// By Mgamerz
// Purpose: Dev (maybe?) - Skip online server data refresh since it will never return without server component
public final function RefreshMPDataFromServer(optional delegate<OnRefreshMPDataDelegate> RefreshDelegate)
{
    local PendingLoadOperation PendingLoad;
    
    if (m_bSaveInProgress || m_bLoadInProgress)
    {
        // PendingLoad.LoadDelegate = RefreshDelegate; // Do not wait for delegate that will never fire.
        // PendingLoadOperations.AddItem(PendingLoad);
        RefreshDelegate(0); // Just call the delegate. There is no server component currently 
    }
    else
    {
        RefreshMPDataFromServerImpl(RefreshDelegate);
    }
}