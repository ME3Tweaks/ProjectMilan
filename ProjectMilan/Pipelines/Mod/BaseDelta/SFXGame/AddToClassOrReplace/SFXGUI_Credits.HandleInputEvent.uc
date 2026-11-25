// MILAN CHANGE - 11/24/2026 - Mgamerz
// PC movie only listens for Escape, intercept BIOGUI events for controller ones as well
public event function bool HandleInputEvent(BioDefine.BioGuiEvents nEventID, optional float fValue = 1.0)
{
    if (nEventID == BioGuiEvents.BIOGUI_EVENT_BUTTON_B || nEventID == BioGuiEvents.BIOGUI_EVENT_BUTTON_START)
    {
        TryExitCredits();
        return TRUE;
    }
    return Super.HandleInputEvent(nEventID, fValue);
}
