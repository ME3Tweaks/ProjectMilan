// MILAN Change - 12/10/2023
// By Mgamerz
// Bypasses online commerce check for outstanding purchases
// Adds logging. This should not be necessary in the final version of this mod.
public final function ProcessConsumables(delegate<OnProcessConsumablesDelegate> ConsumeCallback, optional bool bRetry = FALSE)
{
    bProcessConsumableCriticalError = FALSE;
    ConsumptionFlowResult = 0;
    __OnProcessConsumablesDelegate__Delegate = ConsumeCallback;
    SaveManager = Class'SFXEngine'.static.GetSFXEngine().MPSaveManager;
    if (SaveManager == None)
    {
        ConsumptionFlowError("Error: [ProcessConsumables] Aborting processing of consumables - unable to find save manager", TRUE);
        return;
    }
    bRetryProcessConsumables = bRetry;
    if (ConsumptionFlow_SetCallbackTimer(float(fTimeoutRefreshDigitalRights)))
    {
        LogInternal("OnlineCommerce - START", );
        // Class'SFXOnlineSubsystem'.static.GetOnlineSubsystem().GetComponentCommerce().RefreshDigitalRights(ConsumptionFlow_Setup); // Original code
        ConsumptionFlow_Setup(0); // MILAN Change - Change from online commerce delegate to just directly calling the result with code success
        LogInternal("OnlineCommerce - END", );
    }
}