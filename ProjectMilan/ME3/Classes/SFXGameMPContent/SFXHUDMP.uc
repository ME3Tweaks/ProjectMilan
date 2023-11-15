Class SFXHUDMP extends BioHUD
    transient
    config(UI);

// Functions
public function Message(PlayerReplicationInfo PRI, coerce string Msg, Name msgType, optional float Lifetime)
{
    if ((Class'SFXOnlineSubsystem'.static.GetOnlineSubsystem() != None && Class'SFXOnlineSubsystem'.static.GetOnlineSubsystem().GetComponentOrigin() != None) && Class'SFXOnlineSubsystem'.static.GetOnlineSubsystem().GetComponentOrigin().IsMuted(PRI.PlayerName))
    {
        return;
    }
    if (bMessageBeep)
    {
        PlayerOwner.PlayBeepSound();
    }
    if (msgType == 'Say' || msgType == 'TeamSay')
    {
        Msg = (PRI.PlayerName $ ": ") $ Msg;
        AddConsoleMessage(Msg, Class'SFXMessageMP', PRI, Lifetime);
    }
    else
    {
        AddConsoleMessage(Msg, Class'LocalMessage', PRI, Lifetime);
    }
}
public function PostRender()
{
    Super.PostRender();
    DisplayConsoleMessages();
}
public function DUI_ClearAll(bool bModal)
{
    local SFXPlayerControllerMP PC;
    
    foreach WorldInfo.AllControllers(Class'SFXPlayerControllerMP', PC)
    {
        PC.DUI_ClearAll(bModal);
    }
}
public function DUI_ClearElementPulse(BioDUIElements nElement)
{
    local SFXPlayerControllerMP PC;
    
    foreach WorldInfo.AllControllers(Class'SFXPlayerControllerMP', PC)
    {
        PC.DUI_ClearElementPulse(nElement);
    }
}
public function DUI_SetBarFillDirection(bool bModalBar, bool bLeftToRight)
{
    local SFXPlayerControllerMP PC;
    
    foreach WorldInfo.AllControllers(Class'SFXPlayerControllerMP', PC)
    {
        PC.DUI_SetBarFillDirection(bModalBar, bLeftToRight);
    }
}
public function DUI_SetBarFillPercent(bool bModalBar, int nPercent)
{
    local SFXPlayerControllerMP PC;
    
    foreach WorldInfo.AllControllers(Class'SFXPlayerControllerMP', PC)
    {
        PC.DUI_SetBarFillPercent(bModalBar, nPercent);
    }
}
public function DUI_SetBarMarkerPoints(bool bModalBar, int nMarker1, int nMarker2)
{
    local SFXPlayerControllerMP PC;
    
    foreach WorldInfo.AllControllers(Class'SFXPlayerControllerMP', PC)
    {
        PC.DUI_SetBarMarkerPoints(bModalBar, nMarker1, nMarker2);
    }
}
public function DUI_SetCounterValue(bool bModalCounter, int nValue)
{
    local SFXPlayerControllerMP PC;
    
    foreach WorldInfo.AllControllers(Class'SFXPlayerControllerMP', PC)
    {
        PC.DUI_SetCounterValue(bModalCounter, nValue);
    }
}
public function DUI_SetElementAlpha(BioDUIElements nElement, float fAlpha)
{
    local SFXPlayerControllerMP PC;
    
    foreach WorldInfo.AllControllers(Class'SFXPlayerControllerMP', PC)
    {
        PC.DUI_SetElementAlpha(nElement, fAlpha);
    }
}
public function DUI_SetElementColor(BioDUIElements nElement, Color stColor)
{
    local SFXPlayerControllerMP PC;
    
    foreach WorldInfo.AllControllers(Class'SFXPlayerControllerMP', PC)
    {
        PC.DUI_SetElementColor(nElement, stColor);
    }
}
public function DUI_SetElementText(BioDUIElements nElement, string sText)
{
    local SFXPlayerControllerMP PC;
    
    foreach WorldInfo.AllControllers(Class'SFXPlayerControllerMP', PC)
    {
        PC.DUI_SetElementText(nElement, sText);
    }
}
public function DUI_SetElementVisible(BioDUIElements nElement, bool bVisible, optional float fFadeTime = 0.0)
{
    local SFXPlayerControllerMP PC;
    
    foreach WorldInfo.AllControllers(Class'SFXPlayerControllerMP', PC)
    {
        PC.DUI_SetElementVisible(nElement, bVisible, fFadeTime);
    }
}
public function DUI_SetQuasarLayout(bool bShow)
{
    local SFXPlayerControllerMP PC;
    
    foreach WorldInfo.AllControllers(Class'SFXPlayerControllerMP', PC)
    {
        PC.DUI_SetQuasarLayout(bShow);
    }
}
public function DUI_SetTextStringRef(BioDUIElements nElement, stringref srText)
{
    local SFXPlayerControllerMP PC;
    
    foreach WorldInfo.AllControllers(Class'SFXPlayerControllerMP', PC)
    {
        PC.DUI_SetTextStringRef(nElement, srText);
    }
}
public function DUI_SetTimerDetails(bool bModalTimer, bool bVisible, float fStartTime, float fEndTime, float fInterval)
{
    local SFXPlayerControllerMP PC;
    
    foreach WorldInfo.AllControllers(Class'SFXPlayerControllerMP', PC)
    {
        PC.DUI_SetTimerDetails(bModalTimer, bVisible, fStartTime, fEndTime, fInterval);
    }
}
public function DUI_SetupElementPulse(BioDUIElements nElement, float fMinAlpha, float fCycleTime)
{
    local SFXPlayerControllerMP PC;
    
    foreach WorldInfo.AllControllers(Class'SFXPlayerControllerMP', PC)
    {
        PC.DUI_SetupElementPulse(nElement, fMinAlpha, fCycleTime);
    }
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    ConsoleColor = {B = 255, G = 204, R = 102, A = 255}
}