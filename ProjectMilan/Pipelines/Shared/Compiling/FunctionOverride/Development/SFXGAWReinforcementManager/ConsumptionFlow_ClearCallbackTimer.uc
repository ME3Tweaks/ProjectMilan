// MILAN Change - 12/10/2023
// By Mgamerz
// Adds logging. This should not be necessary in the final version of this mod.
public final function bool ConsumptionFlow_ClearCallbackTimer()
{
    local SFXGRI GRI;
    
    GRI = SFXGRI(Class'WorldInfo'.static.GetWorldInfo().GRI);
    if (GRI == None)
    {
        ConsumptionFlowError("[ConsumptionFlow_ClearCallbackTimer] Failed to find world info", TRUE);
        return FALSE;
    }
    if (!GRI.ClearGenericTimer(ConsumptionFlow_Timer))
    {
        ConsumptionFlowError("[ConsumptionFlow_ClearCallbackTimer] Failed to clear timer", TRUE);
        return FALSE;
    }
    LogInternal("Cleared timer", );
    return TRUE;
}