// MILAN CHANGE - Mgamerz - 2026-10-10
// Multiplayer Settings screen: profile name, matchmaking on/off, default/custom matchmaking server and
// server password. The movie (GUI_SF_MilanNetConfig.NetworkRegistration) is the ME3 EA registration UI
// with its login panel repurposed; see
// Pipelines/Shared/ActionScript/GUI_SF_MilanNetConfig.NetworkRegistration/CHANGES.md.
// Settings are read and saved through MilanNetConfigBridge, which MilanHost implements. They can only be
// changed from the multiplayer menu; opened from a lobby or a match the screen is read-only, so a name
// can't change while other players see it.
Class SFXGUI_MilanNetConfig extends SFXGUIMovieLegacyAdapter
    config(UI);

var transient SFXGUIHelper_ConsoleKeyboard m_oKeyboard;
// Temporarily store banned characters list
// We should store it in the wild encounter data table...
// mmm, maybe that's a bad idea
var transient string m_sBannedChars;
var transient bool m_bBannedCharsCleared;
// Values shown in the form; kept so the form can be restored after an error message
var transient string m_sPlayerName;
var transient bool m_bMatchmaking;
var transient bool m_bCustomServer;
var transient string m_sCustomServer;
var transient string m_sServerPassword;
var transient bool m_bShowingMessage;
var transient bool m_bReadOnly;
// Set once the first-run prompt has been considered this session
var transient bool m_bFirstRunHandled;
var config stringref srTitle;
var config stringref srMessage;
var config stringref srReadOnlyMessage;
var config stringref srProfileName;
var config stringref srMatchmaking;
var config stringref srMatchmakingServer;
var config stringref srServerAddress;
var config stringref srServerPassword;
var config stringref srOn;
var config stringref srOff;
var config stringref srDefault;
var config stringref srCustom;
var config stringref srAccept;
var config stringref srCancel;
var config stringref srOK;
var config stringref srErrorNoName;
var config stringref srErrorServerAddress;
var config stringref srErrorSaveFailed;
var config stringref srErrorServerPassword;
var config int nMaxNameLength;
var config int nMaxServerLength;
var config int nMaxPasswordLength;
// Not read at runtime: referencing the movie pulls the donor into BIOP_MP_COMMON so BioUI can load it
var GFxMovieInfo NetConfigMovie;

// Opens the screen. OnClosed runs when it closes, whether the player accepted or cancelled.
public static function SFXGUI_MilanNetConfig ShowNetConfig(PlayerController PC, optional delegate<SFXGUIMovie.OnMovieClosedDelegate> OnClosed)
{
    local SFXGUI_MilanNetConfig Movie;

    Movie = SFXGUI_MilanNetConfig(Class'SFXGUIInteraction'.static.GetInstance().CastOpenMovie(Class'SFXGUI_MilanNetConfig', PC, 'MilanNetConfig', TRUE));
    if (Movie != None && OnClosed != None)
    {
        Movie.AddOnMovieClosedDelegate(OnClosed);
    }
    return Movie;
}
// Opens the screen once per session for a player who has not chosen a profile name yet
public static function ShowFirstRunIfNeeded(PlayerController PC)
{
    if (default.m_bFirstRunHandled)
    {
        return;
    }
    default.m_bFirstRunHandled = TRUE;
    if (!Class'MilanNetConfigBridge'.static.IsAvailable() || Class'MilanNetConfigBridge'.static.GetPlayerName() != "")
    {
        return;
    }
    ShowNetConfig(PC);
}
public event function OnPanelAdded()
{
    Super.OnPanelAdded();
    oPanel.SetExternalInterface(Self);
    SetMouseShown(!oPanel.bUsingGamepad);
    oPanel.InvokeMethod("Initialize");
    SetFocus(TRUE);
}
public event function OnPanelRemoved()
{
    RestoreKeyboardChars();
    m_oKeyboard = None;
}
public function HandleButtonHelpRefresh(bool usingGamepad)
{
    SetMouseShown(!usingGamepad);
    AS_SetPlatformLayout(GetPlatformLayout(usingGamepad));
}
public event function bool HandleInputEvent(BioGuiEvents Event, optional float fValue = 1.0)
{
    local ASParams stParam;
    local array<ASParams> lstParams;

    switch (Event)
    {
        case BioGuiEvents.BIOGUI_EVENT_AXIS_RSTICK_Y:
            stParam.Type = ASParamTypes.ASParam_Float;
            stParam.fVar = fValue;
            lstParams.AddItem(stParam);
            oPanel.InvokeMethodArgs("ScrollControl", lstParams);
            break;
        case BioGuiEvents.BIOGUI_EVENT_AXIS_LSTICK_X:
            if (fValue >= 0.25)
            {
                oPanel.InvokeMethod("OnInputRight");
            }
            else if (fValue <= -0.25)
            {
                oPanel.InvokeMethod("OnInputLeft");
            }
            break;
        case BioGuiEvents.BIOGUI_EVENT_BUTTON_A_RELEASE:
            oPanel.InvokeMethod("ExecuteControl");
            break;
        case BioGuiEvents.BIOGUI_EVENT_BUTTON_B_RELEASE:
            // Back out of an error message to the form; otherwise B is Cancel
            if (m_bShowingMessage)
            {
                ShowForm();
            }
            else
            {
                CloseScreen();
            }
            break;
        case BioGuiEvents.BIOGUI_EVENT_CONTROL_DOWN_RELEASE:
            oPanel.InvokeMethod("NextControl");
            break;
        case BioGuiEvents.BIOGUI_EVENT_CONTROL_LEFT_RELEASE:
            oPanel.InvokeMethod("OnInputLeft");
            break;
        case BioGuiEvents.BIOGUI_EVENT_CONTROL_RIGHT_RELEASE:
            oPanel.InvokeMethod("OnInputRight");
            break;
        case BioGuiEvents.BIOGUI_EVENT_CONTROL_UP_RELEASE:
            oPanel.InvokeMethod("PreviousControl");
            break;
        default:
            return Super(SFXGUIMovie).HandleInputEvent(Event, fValue);
    }
    return TRUE;
}

// --- Called by the movie ---

public function onExternalInitialize()
{
    local array<ASParams> lstParams;

    AddFloatParam(lstParams, float(GetPlatformLayout(oPanel.bUsingGamepad)));
    AddFloatParam(lstParams, float(nMaxNameLength));
    AddFloatParam(lstParams, float(nMaxServerLength));
    AddFloatParam(lstParams, float(nMaxPasswordLength));
    oPanel.InvokeMethodArgs("onGameSideInit", lstParams);
    m_bReadOnly = !CanEditSettings();
    lstParams.Length = 0;
    AddStringParam(lstParams, GetUIString(srTitle));
    if (m_bReadOnly)
    {
        AddStringParam(lstParams, GetUIString(srReadOnlyMessage));
    }
    else
    {
        AddStringParam(lstParams, GetUIString(srMessage));
    }
    AddStringParam(lstParams, GetUIString(srProfileName));
    AddStringParam(lstParams, GetUIString(srMatchmaking));
    AddStringParam(lstParams, GetUIString(srMatchmakingServer));
    AddStringParam(lstParams, GetUIString(srServerAddress));
    AddStringParam(lstParams, GetUIString(srServerPassword));
    AddStringParam(lstParams, GetUIString(srOn));
    AddStringParam(lstParams, GetUIString(srOff));
    AddStringParam(lstParams, GetUIString(srDefault));
    AddStringParam(lstParams, GetUIString(srCustom));
    AddStringParam(lstParams, GetUIString(srAccept));
    AddStringParam(lstParams, GetUIString(srCancel));
    oPanel.InvokeMethodArgs("SetLabels", lstParams);
    LoadSettings();
    ShowForm();
}
public function SubmitNetConfig(string sPlayerName, bool bMatchmaking, bool bCustomServer, string sCustomServer, string sServerPassword, bool bAccept)
{
    local int nResult;
    
    m_sPlayerName = sPlayerName;
    m_bMatchmaking = bMatchmaking;
    m_bCustomServer = bCustomServer;
    m_sCustomServer = sCustomServer;
    m_sServerPassword = sServerPassword;
    if (!bAccept || m_bReadOnly)
    {
        CloseScreen();
        return;
    }
    if (Repl(sPlayerName, " ", "") == "")
    {
        ShowError(srErrorNoName);
        return;
    }
    if (bMatchmaking && bCustomServer && !IsValidServerAddress(sCustomServer))
    {
        ShowError(srErrorServerAddress);
        return;
    }
    nResult = Class'MilanNetConfigBridge'.static.ApplySettings(sPlayerName, int(bMatchmaking), int(bCustomServer), sCustomServer, sServerPassword);
    if (nResult == Class'MilanNetConfigBridge'.const.APPLY_OK)
    {
        RefreshLocalPlayerName(Class'MilanNetConfigBridge'.static.GetPlayerName());
        CloseScreen();
    }
    else if (nResult == Class'MilanNetConfigBridge'.const.APPLY_INVALID_NAME)
    {
        ShowError(srErrorNoName);
    }
    else if (nResult == Class'MilanNetConfigBridge'.const.APPLY_INVALID_SERVER)
    {
        ShowError(srErrorServerAddress);
    }
    else if (nResult == Class'MilanNetConfigBridge'.const.APPLY_INVALID_PASSWORD)
    {
        ShowError(srErrorServerPassword);
    }
    else
    {
        ShowError(srErrorSaveFailed);
    }
}
public function SubmitMessageBox(int nButton)
{
    ShowForm();
}
public function EnterPlayerName(string sDefault)
{
    RestoreKeyboardChars();
    GetKeyboard().DisplayKeyboard(srProfileName, $0, 0, nMaxNameLength, sDefault);
}
public function EnterServer(string sDefault)
{
    AllowAllKeyboardChars();
    GetKeyboard().DisplayKeyboard(srServerAddress, $0, 0, nMaxServerLength, sDefault);
}
public function EnterServerPassword(string sDefault)
{
    AllowAllKeyboardChars();
    GetKeyboard().DisplayKeyboard(srServerPassword, $0, 2, nMaxPasswordLength, sDefault);
}
// Paste support with only the first line used
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
    sText = Repl(sText, Chr(9), " ");
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
public function GFxScreenVisibilityChange(bool bNewValue);

// --- Helpers ---

// Only from the multiplayer menu, which is a standalone world; any lobby or match, even a 1-player
// one, is a listen server or a client. MilanHost also refuses while a join is in progress.
private final function bool CanEditSettings()
{
    local PlayerController PC;

    if (!Class'MilanNetConfigBridge'.static.IsAvailable() || !Class'MilanNetConfigBridge'.static.CanApplySettings())
    {
        return FALSE;
    }
    PC = GetPC();
    return PC != None && PC.WorldInfo.NetMode == ENetMode.NM_Standalone;
}
private final function LoadSettings()
{
    m_sPlayerName = Class'MilanNetConfigBridge'.static.GetPlayerName();
    if (m_sPlayerName == "")
    {
        m_sPlayerName = Class'MilanNetConfigBridge'.static.GetDefaultPlayerName();
    }
    m_bMatchmaking = Class'MilanNetConfigBridge'.static.IsMatchmakingEnabled();
    m_bCustomServer = Class'MilanNetConfigBridge'.static.IsCustomServer();
    m_sCustomServer = Class'MilanNetConfigBridge'.static.GetCustomServer();
    m_sServerPassword = Class'MilanNetConfigBridge'.static.GetServerPassword();
}
private final function ShowForm()
{
    local array<ASParams> lstParams;

    m_bShowingMessage = FALSE;
    AddStringParam(lstParams, m_sPlayerName);
    AddBoolParam(lstParams, m_bMatchmaking);
    AddBoolParam(lstParams, m_bCustomServer);
    AddStringParam(lstParams, m_sCustomServer);
    AddStringParam(lstParams, m_sServerPassword);
    AddBoolParam(lstParams, m_bReadOnly);
    oPanel.InvokeMethodArgs("ShowSubscreen_NetConfig", lstParams);
}
private final function ShowError(stringref srError)
{
    local array<ASParams> lstParams;

    m_bShowingMessage = TRUE;
    AddStringParam(lstParams, GetUIString(srTitle));
    AddStringParam(lstParams, GetUIString(srError));
    AddStringParam(lstParams, GetUIString(srOK));
    oPanel.InvokeMethodArgs("ShowSubscreen_MessageBox", lstParams);
}
// The menu's player already has its name; update it so a lobby hosted or joined next shows the new one
private final function RefreshLocalPlayerName(string sPlayerName)
{
    local SFXPRIMP PRI;
    
    if (sPlayerName != "" && GetPC() != None)
    {
        PRI = SFXPRIMP(GetPC().PlayerReplicationInfo);
        if (PRI != None)
        {
            PRI.SetComputerName(sPlayerName);
        }
    }
}
private final function CloseScreen()
{
    RestoreKeyboardChars();
    m_oKeyboard = None;
    Close(TRUE);
}
// Temporarily allow all keyboard characters in input fields
private final function AllowAllKeyboardChars()
{
    if (!m_bBannedCharsCleared)
    {
        m_sBannedChars = Class'SFXGUIInputHandler'.default.BannedChars;
        m_bBannedCharsCleared = TRUE;
    }
    Class'SFXGUIInputHandler'.default.BannedChars = "";
}
private final function RestoreKeyboardChars()
{
    if (m_bBannedCharsCleared)
    {
        Class'SFXGUIInputHandler'.default.BannedChars = m_sBannedChars;
        m_bBannedCharsCleared = FALSE;
    }
}
private final function bool IsValidServerAddress(string sAddress)
{
    local string sLower;

    sLower = Locs(sAddress);
    return (Left(sLower, 7) == "http://" && Len(sLower) > 7) || (Left(sLower, 8) == "https://" && Len(sLower) > 8);
}
// The movie's com.XPlatform layout codes: PC = 0, XBox = 1
private final function int GetPlatformLayout(bool usingGamepad)
{
    if (usingGamepad)
    {
        return 1;
    }
    return 0;
}
private final function SFXGUIHelper_ConsoleKeyboard GetKeyboard()
{
    if (m_oKeyboard == None)
    {
        m_oKeyboard = new (Self) Class'SFXGUIHelper_ConsoleKeyboard';
    }
    m_oKeyboard.OnKeyboardEntryComplete = KeyboardEntryComplete;
    return m_oKeyboard;
}
public final function KeyboardEntryComplete(bool bOK, string sText)
{
    RestoreKeyboardChars();
    if (bOK)
    {
        AS_SetActiveInputField(sText);
    }
}
public final function AS_SetActiveInputField(string sText)
{
    ActionScriptVoid("SetActiveInputField");
}
public final function AS_SetPlatformLayout(int nPlatformID)
{
    ActionScriptVoid("SetPlatformLayout");
}
private static final function AddFloatParam(out array<ASParams> lstParams, float fValue)
{
    local ASParams stParam;

    stParam.Type = ASParamTypes.ASParam_Float;
    stParam.fVar = fValue;
    lstParams.AddItem(stParam);
}
private static final function AddBoolParam(out array<ASParams> lstParams, bool bValue)
{
    local ASParams stParam;

    stParam.Type = ASParamTypes.ASParam_Boolean;
    stParam.bVar = bValue;
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
    srTitle = $49875740
    srMessage = $49875741
    srReadOnlyMessage = $49875754
    srProfileName = $49875742
    srMatchmaking = $723770
    srMatchmakingServer = $49875750
    srServerAddress = $49875744
    srServerPassword = $49875745
    srOn = $653225
    srOff = $653223
    srDefault = $163476
    srCustom = $49875752
    srAccept = $315178
    srCancel = $315182
    srOK = $152938
    srErrorNoName = $49875746
    srErrorServerAddress = $49875747
    srErrorSaveFailed = $49875748
    srErrorServerPassword = $49875753
    nMaxNameLength = 32
    nMaxServerLength = 256
    nMaxPasswordLength = 64
    NetConfigMovie = GFxMovieInfo'GUI_SF_MilanNetConfig.NetworkRegistration'
}
// END MILAN CHANGE
