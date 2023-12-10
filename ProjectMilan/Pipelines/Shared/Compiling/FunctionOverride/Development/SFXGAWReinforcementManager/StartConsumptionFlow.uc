// MILAN Change - 12/10/2023
// By Mgamerz
// Bypasses online commerce check for outstanding purchases
// Adds logging. This should not be necessary in the final version of this mod.
public final function StartConsumptionFlow(bool bRefreshSave)
{
    ConsumptionFlow_ClearCallbackTimer();
    if (bProcessConsumableCriticalError)
    {
        LogInternal("Critical error in StartConsumptionFlow!", );
        return;
    }
    if (bRefreshSave)
    {
        LogInternal("bRefreshSave", );
        if (ConsumptionFlow_SetCallbackTimer(float(fTimeoutRefreshMPSaves)))
        {
            LogInternal("Refreshing save data from server...", );
            // SaveManager.RefreshMPDataFromServer(ConsumptionFlow_Top); // Original code
            ConsumptionFlow_Top(0); // MILAN Change - this bypasses changing SFXGame
            LogInternal("Save data call done.", );
        }
    }
    else
    {
        LogInternal("Directly going to CF_TOP", );
        ConsumptionFlow_Top(0);
    }
}