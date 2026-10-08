// MILAN CHANGE - 10/07/2026
// By Mgamerz
// Purpose: Prevent focus stalls when in replication
// Notably, this fixes returning to the lobby after a match ends stalling out if someone is alt tabbed out of the game
public simulated function Tick(float fDeltaT)
{
    local BioPlayerController PC;
    
    PC = GetLocalPlayerController();
    // MILAN CHANGE - Add NetMode check
    if (NetMode == ENetMode.NM_Standalone && !bPlayersOnly && m_bAllowBrowserWheel && !HasFocus() && PC != None && PC.GameModeManager2 != None && PC.GameModeManager2.CanPause())
    {
    // END MILAN CHANGE
        PC.GameModeManager2.TurnOffStormForPause();
        m_bPausedByFocusLoss = TRUE;
        PauseGame(TRUE);
    }
    else if (HasFocus() && m_bPausedByFocusLoss)
    {
        m_bPausedByFocusLoss = FALSE;
        PauseGame(FALSE);
    }
    if (TimerList != None)
    {
        TimerList.Tick(fDeltaT);
    }
    TickLocal(fDeltaT);
}