// NEW to Milan - Mgamerz - 11/17/2026
// A message box with one line of text entry, within the custom Milan message box movie
// Compiled into MPLobby only, as that is the only place it is used. Open it with
// SFXGUI_MilanTextEntryBoxBase.ShowTextEntry, which BIOP_MP_COMMON classes can call
Class SFXGUI_MilanTextEntryBox extends SFXGUI_MilanTextEntryBoxBase
    config(UI);

var transient SFXGUIHelper_ConsoleKeyboard m_oKeyboard;
var transient string m_sMessage;
var transient string m_sAcceptText;
var transient string m_sCancelText;
var transient string m_sDefault;
var transient int m_nMaxChars;
var transient stringref m_srKeyboardTitle;
var transient SFXGUIHelper_ConsoleKeyboard.Keyboard_Options m_eKeyboardOptions;
var transient bool m_bPanelReady;
var transient bool m_bPending;
var transient bool m_bShown;
var transient bool m_bFinished;
var transient bool m_bKeyboardOpen;
// Set while this box holds GameMode_GUI
var transient bool m_bHoldingInput;
var transient bool m_bHaveResult;
var transient bool m_bResultAccepted;
var transient string m_sResultText;

// Called by SFXGUI_MilanTextEntryBoxBase.ShowTextEntry once the movie is open
public function bool BeginTextEntry(string sMessage, string sAcceptText, string sCancelText, delegate<OnTextEntryComplete> fnDone, string sDefault, int nMaxChars, stringref srKeyboardTitle, SFXGUIHelper_ConsoleKeyboard.Keyboard_Options eKeyboardOptions)
{
    if ((m_bShown || m_bPending) && !m_bFinished)
    {
        LogInternal("SFXGUI_MilanTextEntryBox: a text entry box is already open", );
        return FALSE;
    }
    OnTextEntryComplete = fnDone;
    OnFilterPastedText = None;
    m_sMessage = sMessage;
    m_sAcceptText = sAcceptText;
    m_sCancelText = sCancelText;
    m_sDefault = sDefault;
    m_nMaxChars = nMaxChars;
    m_srKeyboardTitle = srKeyboardTitle;
    m_eKeyboardOptions = eKeyboardOptions;
    m_bShown = FALSE;
    m_bFinished = FALSE;
    m_bKeyboardOpen = FALSE;
    m_bHaveResult = FALSE;
    m_bResultAccepted = FALSE;
    m_sResultText = "";
    m_bPending = TRUE;
    if (m_bPanelReady)
    {
        Present();
    }
    return TRUE;
}
public event function OnPanelAdded()
{
    Super.OnPanelAdded();
    oPanel.SetExternalInterface(Self);
    oPanel.UpdateAspectRatio(TRUE);
    if (!Class'WorldInfo'.static.IsConsoleBuild())
    {
        oPanel.SetVariableNumber("_root.ScreenLayout", 0.0);
    }
    oPanel.SetVariableBool("_root.bUsingGamepad", oPanel.bUsingGamepad);
    SetMouseShown(!oPanel.bUsingGamepad);
    SetFocus(TRUE);
    m_bPanelReady = TRUE;
    if (m_bPending)
    {
        Present();
    }
}

// Also reached when something else closes the box (e.g. when a level changes)
public event function OnPanelRemoved()
{
    ReleaseInput();
    Finish();
    m_oKeyboard = None;
    m_bPanelReady = FALSE;
}
public function HandleButtonHelpRefresh(bool usingGamepad)
{
    RefreshLayout(usingGamepad);
}
public event function HandleButtonRefresh(bool usingGamepad)
{
    RefreshLayout(usingGamepad);
}
public event function bool HandleInputEvent(BioGuiEvents Event, optional float fValue = 1.0)
{
    if (m_bShown && !m_bFinished && oPanel.bUsingGamepad)
    {
        // When using gamepad, look for A and B here
        switch (Event)
        {
            case BioGuiEvents.BIOGUI_EVENT_BUTTON_A_RELEASE:
                // Open keyboard on A
                OpenKeyboard();
                return TRUE;
            case BioGuiEvents.BIOGUI_EVENT_BUTTON_B_RELEASE:
                // Abort
                if (!m_bKeyboardOpen)
                {
                    oPanel.InvokeMethod("CancelTextEntry");
                }
                return TRUE;
            default:
                break;
        }
    }
    return Super(SFXGUIMovie).HandleInputEvent(Event, fValue);
}


public function OnTextEntryClosed(bool bAccepted, string sText)
{
    m_bHaveResult = TRUE;
    m_bResultAccepted = bAccepted;
    m_sResultText = sText;
    m_oKeyboard = None;
    ReleaseInput();
    Close(TRUE);
    Finish();
}

// Read clipbaord and take the first line
public function string GetClipboardText()
{
    local string sText;
    local int nBreak;

    if (GetPC() == None)
    {
        return "";
    }
    sText = Repl(GetPC().PasteFromClipboard(), Chr(13), Chr(10));
    nBreak = InStr(sText, Chr(10));
    if (nBreak != -1)
    {
        sText = Left(sText, nBreak);
    }
    return OnFilterPastedText(TrimSpaces(Repl(sText, Chr(9), " ")));
}

public function GFxScreenVisibilityChange(bool bNewValue);


private final function Present()
{
    local array<ASParams> lstParams;

    m_bPending = FALSE;
    m_bShown = TRUE;
    TakeInput();
    AddStringParam(lstParams, m_sMessage);
    AddStringParam(lstParams, m_sMessage);
    AddStringParam(lstParams, m_sAcceptText);
    AddStringParam(lstParams, m_sCancelText);
    AddStringParam(lstParams, m_sDefault);
    AddFloatParam(lstParams, float(Max(m_nMaxChars, 0)));
    oPanel.InvokeMethodArgs("ShowTextEntryBox", lstParams);
    if (oPanel.bUsingGamepad)
    {
        OpenKeyboard();
    }
}

private final function TakeInput()
{
    if (!m_bHoldingInput)
    {
        // 9 = GameMode_GUI
        SetGameMode(TRUE, 9);
        m_bHoldingInput = TRUE;
    }
    SetInputDisabled(FALSE);
    SetFocus(TRUE);
    StartHandlingKeyPresses();
    SetMouseShown(!oPanel.bUsingGamepad);
}

// Gives input back to the screen below
private final function ReleaseInput()
{
    if (!m_bHoldingInput)
    {
        return;
    }
    m_bHoldingInput = FALSE;
    StopHandlingKeyPresses();
    SetGameMode(FALSE, 9);
}

private final function RefreshLayout(bool usingGamepad)
{
    SetMouseShown(!usingGamepad);
    oPanel.SetVariableBool("_root.bUsingGamepad", usingGamepad);
    AS_RefreshButtonHelp(usingGamepad);
}

private final function OpenKeyboard()
{
    local string sCurrent;
    local int nMaxLength;

    if (m_bKeyboardOpen || !m_bShown || m_bFinished)
    {
        return;
    }
    sCurrent = AS_GetTextEntryText();
    nMaxLength = m_nMaxChars > 0 ? m_nMaxChars : 255;
    if (m_oKeyboard == None)
    {
        m_oKeyboard = new (Self) Class'SFXGUIHelper_ConsoleKeyboard';
    }
    m_oKeyboard.OnKeyboardEntryComplete = KeyboardEntryComplete;
    m_bKeyboardOpen = TRUE;
    m_oKeyboard.DisplayKeyboard(m_srKeyboardTitle, $0, m_eKeyboardOptions, nMaxLength, sCurrent);
}

public final function KeyboardEntryComplete(bool bOK, string sText)
{
    local array<ASParams> lstParams;

    m_bKeyboardOpen = FALSE;
    if (!bOK || m_bFinished)
    {
        return;
    }
    AddStringParam(lstParams, sText);
    oPanel.InvokeMethodArgs("AcceptTextEntry", lstParams);
}

private final function Finish()
{
    local bool bAccepted;
    local string sText;

    if (m_bFinished || !(m_bShown || m_bPending))
    {
        return;
    }
    m_bFinished = TRUE;
    m_bPending = FALSE;
    bAccepted = m_bHaveResult && m_bResultAccepted;
    if (bAccepted)
    {
        sText = TrimSpaces(m_sResultText);
    }
    if (OnTextEntryComplete != None)
    {
        OnTextEntryComplete(bAccepted, sText);
    }
    OnTextEntryComplete = None;
}
private static final function string TrimSpaces(string sText)
{
    while (Left(sText, 1) == " ")
    {
        sText = Mid(sText, 1);
    }
    while (Right(sText, 1) == " ")
    {
        sText = Left(sText, Len(sText) - 1);
    }
    return sText;
}
public final function string AS_GetTextEntryText()
{
    return ActionScriptString("GetTextEntryText");
}
public final function AS_RefreshButtonHelp(bool usingGamepad)
{
    ActionScriptVoid("RefreshButtonHelp");
}
private static final function AddFloatParam(out array<ASParams> lstParams, float fValue)
{
    local ASParams stParam;

    stParam.Type = ASParamTypes.ASParam_Float;
    stParam.fVar = fValue;
    lstParams.AddItem(stParam);
}
private static final function AddStringParam(out array<ASParams> lstParams, string sValue)
{
    local ASParams stParam;

    stParam.Type = ASParamTypes.ASParam_String;
    stParam.sVar = sValue;
    lstParams.AddItem(stParam);
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    m_bFocusOnStart = TRUE
}
