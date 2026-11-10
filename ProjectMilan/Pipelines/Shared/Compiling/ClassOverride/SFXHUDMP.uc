Class SFXHUDMP extends BioHUD
    transient
    config(UI);

public function Message(PlayerReplicationInfo PRI, coerce string Msg, Name msgType, optional float Lifetime)
{
    if (Class'SFXOnlineSubsystem'.static.GetOnlineSubsystem() != None && Class'SFXOnlineSubsystem'.static.GetOnlineSubsystem().GetComponentOrigin() != None && Class'SFXOnlineSubsystem'.static.GetOnlineSubsystem().GetComponentOrigin().IsMuted(PRI.PlayerName))
    {
        return;
    }
    if (bMessageBeep)
    {
        PlayerOwner.PlayBeepSound();
    }
    if (msgType == 'Say' || msgType == 'TeamSay')
    {
        Msg = PRI.PlayerName $ ": " $ Msg;
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
public function DUI_ClearElementPulse(BioSFHandler_DesignerUI.BioDUIElements nElement)
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
public function DUI_SetElementAlpha(BioSFHandler_DesignerUI.BioDUIElements nElement, float fAlpha)
{
    local SFXPlayerControllerMP PC;
    
    foreach WorldInfo.AllControllers(Class'SFXPlayerControllerMP', PC)
    {
        PC.DUI_SetElementAlpha(nElement, fAlpha);
    }
}
public function DUI_SetElementColor(BioSFHandler_DesignerUI.BioDUIElements nElement, Object.Color stColor)
{
    local SFXPlayerControllerMP PC;
    
    foreach WorldInfo.AllControllers(Class'SFXPlayerControllerMP', PC)
    {
        PC.DUI_SetElementColor(nElement, stColor);
    }
}
public function DUI_SetElementText(BioSFHandler_DesignerUI.BioDUIElements nElement, string sText)
{
    local SFXPlayerControllerMP PC;
    
    foreach WorldInfo.AllControllers(Class'SFXPlayerControllerMP', PC)
    {
        PC.DUI_SetElementText(nElement, sText);
    }
}
public function DUI_SetElementVisible(BioSFHandler_DesignerUI.BioDUIElements nElement, bool bVisible, optional float fFadeTime = 0.0)
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
public function DUI_SetTextStringRef(BioSFHandler_DesignerUI.BioDUIElements nElement, stringref srText)
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
public function DUI_SetupElementPulse(BioSFHandler_DesignerUI.BioDUIElements nElement, float fMinAlpha, float fCycleTime)
{
    local SFXPlayerControllerMP PC;
    
    foreach WorldInfo.AllControllers(Class'SFXPlayerControllerMP', PC)
    {
        PC.DUI_SetupElementPulse(nElement, fMinAlpha, fCycleTime);
    }
}

// MILAN CHANGE
// 2026/11/10 - Stumpy - in-game "chat" improvements.
public function DisplayConsoleMessages()
{
    local int idx;
    local int XPos;
    local int YPos;
    local float XL;
    local float YL;
    local float CharXL;
    local float CharYL;
    local float TextScale;
    local int RealMaxMessageLength;
    
    if (ConsoleMessages.Length == 0)
    {
        return;
    }
    for (idx = 0; idx < ConsoleMessages.Length; idx++)
    {
        if (ConsoleMessages[idx].Text == "" || ConsoleMessages[idx].MessageLife < WorldInfo.TimeSeconds)
        {
            ConsoleMessages.Remove(idx--, 1);
        }
    }
    TextScale = float(Canvas.SizeY) / 720.0 / 2.0;
    XPos = int(ConsoleMessagePosX * HudCanvasScale * float(Canvas.SizeX) + (1.0 - HudCanvasScale) / 2.0 * float(Canvas.SizeX));
    YPos = int(ConsoleMessagePosY * HudCanvasScale * float(Canvas.SizeY) + (1.0 - HudCanvasScale) / 2.0 * float(Canvas.SizeY));
    Canvas.Font = Class'Engine'.static.GetLargeFont();
    Canvas.DrawColor = ConsoleColor;
    Canvas.TextSize("A", XL, YL);
    Canvas.TextSize("A", CharXL, CharYL);
    // Do not recenter messages
    // YPos -= int(YL * float(ConsoleMessages.Length));
    // YPos -= int(YL);
    for (idx = 0; idx < ConsoleMessages.Length; idx++)
    {
        if (ConsoleMessages[idx].Text == "")
        {
            continue;
        }
        // Max message length + 2 (to account for colon and space) + nickname length
        RealMaxMessageLength = MaxMessageLength + 2 + Len(ConsoleMessages[idx].PRI.PlayerName);
        // Sets max width of text before inserting a line break
        Canvas.SetClip(CharXL * float(MaxMessageCharactersPerLine), CharYL * 4.0);
        Canvas.StrLen(ConsoleMessages[idx].Text, XL, YL);
        // Drop shadow
        Canvas.SetPos(float(XPos) + 1.0 * TextScale, float(YPos) + 1.0 * TextScale);
        Canvas.DrawColor = ShadowColor;
        Canvas.DrawTextScaled(Left(ConsoleMessages[idx].Text, RealMaxMessageLength), TextScale, TextScale);
        // Draw message
        Canvas.SetPos(float(XPos), float(YPos));
        Canvas.DrawColor = ConsoleMessages[idx].TextColor;
        Canvas.DrawTextScaled(Left(ConsoleMessages[idx].Text, RealMaxMessageLength), TextScale, TextScale);
        // Offset for the next message
        YPos += int(YL * TextScale);
    }
}
// MILAN END

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    ConsoleColor = {B = 255, G = 204, R = 102, A = 255}
    // New chat options
    ShadowColor = {B = 0, G = 0, R = 0, A = 127}
    MaxMessageLength = 80
    MaxMessageCharactersPerLine = 45
    ConsoleMessagePosY = 0.219999999
}