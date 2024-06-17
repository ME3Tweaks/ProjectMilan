// Source: ME3, Patch_SFXGUI_MPAppearance
// Modified 12/12/2023-12/16/2023 by DropTheSquid to account for switching input modes.
Class SFXGUI_MPAppearance extends SFXGUIMovieMP
    config(UI);

// Types
struct PatternData 
{
    var int PatternID;
    var stringref PatternName;
};
enum EAppearanceMenuItemState
{
    EAppearanceMenuItemState_Normal,
    EAppearanceMenuItemState_Disabled,
    EAppearanceMenuItemState_New,
};

// Variables
var string SelectedCharacterName;
var config array<TintSwatchData> Tint1SwatchMappings;
var config array<TintSwatchData> Tint2SwatchMappings;
var config array<PatternData> PatternMappings;
var config array<TintSwatchData> PatternColorSwatchMappings;
var config array<TintSwatchData> PhongSwatchMappings;
var config array<TintSwatchData> EmissiveSwatchMappings;
var config array<TintSwatchData> SkinToneSwatchMappings;
var BioWorldInfo WorldInfo;
var config stringref srNameTitle;
var config stringref srNameNotUniqueErrorMessage;
var config stringref srNameTooLongErrorMessage;
var config stringref srNameEmpty;
var config stringref srOK;
var config stringref srCharacterClassAndLevel;
var config stringref srDefaultPlaceholderName;
var config stringref srYes;
var config stringref srNo;
var config stringref srCancelConfirmationMessage;
var config int nMaxNameLength;
var int SelectedPawnTint1ID;
var int SelectedPawnTint2ID;
var int SelectedPawnPatternID;
var int SelectedPawnPatternColorID;
var int SelectedPawnPhongID;
var int SelectedPawnEmissiveID;
var int SelectedPawnSkinToneID;
var SFXGUIHelper_ConsoleKeyboard Keyboard;
var SFXMPCharacterRecord CurrModifiableCharacter;
var SFXSaveManagerMP MPSaveManager;
var SFXCustomizationInstance_PlayerMP CurrentSettings;
var int m_nRotating;
var config float RotationDegreesPerSecond;
var SFXPawn_Player SourcePlayer;
var config int RequiredTint1Level;
var config int RequiredTint2Level;
var config int RequiredPatternLevel;
var config int RequiredPatternColorLevel;
var config int RequiredPhongLevel;
var config int RequiredEmissiveLevel;
var config int RequiredSkinToneLevel;
var float m_fPreviousMipLevelFadingValue;
var bool m_bUpdatedInitialPawnTint;
var bool m_bPCRotationEnabled;

// Functions
// MILAN CHANGE DropTheSquid 12/12/2023
// added so that we can react to input changes to update the UI and show/hide the mouse cursor
public event function HandleButtonRefresh(bool usingGamepad)
{
    Super(SFXGUIMovie).HandleButtonRefresh(usingGamepad);
    SetMouseVisible(!usingGamepad);
    ActionScriptVoid("screen.RefreshButtonHelp");
}
// END MILAN
public event function bool HandleInputEvent(BioGuiEvents Event, optional float fValue = 1.0)
{
    switch (Event)
    {
        case BioGuiEvents.BIOGUI_EVENT_AXIS_RSTICK_X:
            if (fValue < -0.0000999999975)
            {
                m_nRotating = 1;
            }
            else if (fValue > 0.0000999999975)
            {
                m_nRotating = -1;
            }
            else
            {
                m_nRotating = 0;
            }
            break;
        case BioGuiEvents.BIOGUI_EVENT_MOUSE_BUTTON_RIGHT:
            m_bPCRotationEnabled = TRUE;
            SetMouseVisible(FALSE);
            // MILAN CHANGE DropTheSquid 1/2/2024
			// adding a call so we can keep track of the state of the mouse in Actionscript
            ActionScriptVoid("StartRightClick");
			// END MILAN
            break;
        case BioGuiEvents.BIOGUI_EVENT_MOUSE_BUTTON_RIGHT_RELEASE:
            m_bPCRotationEnabled = FALSE;
            SetMouseVisible(TRUE);
            m_nRotating = 0;
            // MILAN CHANGE DropTheSquid 1/2/2024
			// adding a call so we can keep track of the state of the mouse in Actionscript
            ActionScriptVoid("EndRightClick");
			// END MILAN
            break;
        case BioGuiEvents.BIOGUI_EVENT_AXIS_MOUSE_X:
            if (m_bPCRotationEnabled)
            {
                if (fValue < -0.0000999999975)
                {
                    m_nRotating = 1;
                }
                else if (fValue > 0.0000999999975)
                {
                    m_nRotating = -1;
                }
                else
                {
                    m_nRotating = 0;
                }
            }
            break;
		// MILAN CHANGE DropTheSquid 6/17/2024
		// adding unrealscript side handling of controller face buttons because the ACtionscript side
		// cannot reliably distinguish between keyboard a/b/x/y and controller a/b/x/y
		case BioGuiEvents.BIOGUI_EVENT_BUTTON_A:
			AS_ControllerFaceButton("A");
            break;
		case BioGuiEvents.BIOGUI_EVENT_BUTTON_B:
			AS_ControllerFaceButton("B");
            break;
		case BioGuiEvents.BIOGUI_EVENT_BUTTON_X:
			AS_ControllerFaceButton("X");
            break;
		case BioGuiEvents.BIOGUI_EVENT_BUTTON_Y:
			AS_ControllerFaceButton("Y");
            break;
		// END MILAN
        default:
            return Super(SFXGUIMovie).HandleInputEvent(Event, fValue);
    }
    return TRUE;
}
public event function OnStart()
{
    WorldInfo = BioWorldInfo(Class'Engine'.static.GetCurrentWorldInfo());
    MPSaveManager = SFXEngine(Class'Engine'.static.GetEngine()).MPSaveManager;
    CurrModifiableCharacter = MPSaveManager.GetCurrentModifiableCharacter();
    Super(SFXGUIMovie).OnStart();
    SetGameMode(TRUE, 24); // MILAN Patched: GameMode Enum Index
    // MILAN Change DropTheSquid 12/16/2023
    // make sure we actually can control the mouse visibility
	BioPlayerController(GetPC()).GameModeManager2.GameModes[int(EGameModes.GameMode_Lobby)].bHasMouseAuthority = false;
	// make sure the mouse is initially shown/hidden based on the input mode
	SetMouseVisible(!bUsingGamepad);
    // END MILAN
    SetRequiresUIWorld(TRUE);
    PlayGuiSound('MPAppearanceStart');
    SourcePlayer = GetLobbyFlow().DummyPawn;
    WorldInfo.m_UIWorld.TriggerEvent('SetupMPAppearance', SourcePlayer);
    WorldInfo.m_UIWorld.SpawnPawn(SourcePlayer, 'CharRecSpawnPoint', 'CharRecPawn', None, 'None', 4);
    WorldInfo.m_UIWorld.AddDeferredOperation(SetInitialPawnPosition, None);
    m_fPreviousMipLevelFadingValue = Class'SFXGame'.static.GetMipFadingValue();
    Class'SFXGame'.static.SetMipFadingValue(-1.0);
    SelectedCharacterName = GetOriginalCharacterName();
    CurrentSettings = new Class'SFXCustomizationInstance_PlayerMP';
    SelectedPawnTint1ID = CurrModifiableCharacter.Tint1ID;
    SelectedPawnTint2ID = CurrModifiableCharacter.Tint2ID;
    SelectedPawnPatternID = CurrModifiableCharacter.PatternID;
    SelectedPawnPatternColorID = CurrModifiableCharacter.PatternColorID;
    SelectedPawnPhongID = CurrModifiableCharacter.PhongID;
    SelectedPawnEmissiveID = CurrModifiableCharacter.EmissiveID;
    SelectedPawnSkinToneID = CurrModifiableCharacter.SkinToneID;
    ChangePawnTint1(SelectedPawnTint1ID);
    ChangePawnTint2(SelectedPawnTint2ID);
    ChangePawnPattern(SelectedPawnPatternID);
    ChangePawnPatternColor(SelectedPawnPatternColorID);
    ChangePawnPhong(SelectedPawnPhongID);
    ChangePawnEmissive(SelectedPawnEmissiveID);
    ChangePawnSkinTone(SelectedPawnSkinToneID);
    AS_InitializeScreen();
}
public event function Update(float fDeltaT)
{
    local Rotator rotCurrentPreviewRotation;
    local Actor TargetActor;
    
    Super(SFXGUIMovie).Update(fDeltaT);
    TargetActor = WorldInfo.m_UIWorld.GetSpawnedActor(SourcePlayer);
    if (TargetActor != None)
    {
        if (m_nRotating != 0)
        {
            rotCurrentPreviewRotation = TargetActor.Rotation;
            rotCurrentPreviewRotation.Yaw += int(float(m_nRotating) * ((fDeltaT * 182.044449) * RotationDegreesPerSecond));
            rotCurrentPreviewRotation = Normalize(rotCurrentPreviewRotation);
            WorldInfo.m_UIWorld.RotatePawn(SourcePlayer, rotCurrentPreviewRotation);
        }
    }
}
public event function OnClose()
{
    Class'SFXGame'.static.SetMipFadingValue(m_fPreviousMipLevelFadingValue);
    ChangePawnTint1(CurrModifiableCharacter.Tint1ID);
    ChangePawnTint2(CurrModifiableCharacter.Tint2ID);
    ChangePawnPattern(CurrModifiableCharacter.PatternID);
    ChangePawnPatternColor(CurrModifiableCharacter.PatternColorID);
    ChangePawnPhong(CurrModifiableCharacter.PhongID);
    ChangePawnEmissive(CurrModifiableCharacter.EmissiveID);
    ChangePawnSkinTone(CurrModifiableCharacter.SkinToneID);
    WorldInfo.m_UIWorld.FlushPendingCommands();
    CurrentSettings = None;
    if (WorldInfo != None && WorldInfo.m_UIWorld != None)
    {
        WorldInfo.m_UIWorld.CleanupPawn(SourcePlayer);
    }
    SetGameMode(FALSE, 24); // MILAN Patched: GameMode Enum Index
    Super(SFXGUIMovie).OnClose();
}
public function AS_InitializeScreen()
{
    ActionScriptVoid("screen.InitializeScreen");
}
// MILAN CHANGE DropTheSquid 6/17/2024
// adding function to call into Actionscript to handle controller face buttons
private function AS_ControllerFaceButton(string button)
{
    ActionScriptVoid("screen.ControllerButton");
}
// END MILAN
public final function ConfirmButtonPressed()
{
    local ECharacterNameResult eResult;
    
    if (SelectedCharacterName == GetUIString(srDefaultPlaceholderName))
    {
        eResult = ECharacterNameResult.ECharacterNameResult_NotUnique;
    }
    else
    {
        eResult = MPSaveManager.VerifyNameIsValid(SelectedCharacterName, CurrModifiableCharacter);
    }
    if (eResult == ECharacterNameResult.ECharacterNameResult_AllGood)
    {
        CurrModifiableCharacter.CharacterName = SelectedCharacterName;
        CurrModifiableCharacter.Tint1ID = SelectedPawnTint1ID;
        CurrModifiableCharacter.Tint2ID = SelectedPawnTint2ID;
        CurrModifiableCharacter.PatternID = SelectedPawnPatternID;
        CurrModifiableCharacter.PatternColorID = SelectedPawnPatternColorID;
        CurrModifiableCharacter.PhongID = SelectedPawnPhongID;
        CurrModifiableCharacter.EmissiveID = SelectedPawnEmissiveID;
        CurrModifiableCharacter.SkinToneID = SelectedPawnSkinToneID;
        SFXPawn_PlayerMP(SourcePlayer).SetMPAppearanceVariables(SelectedPawnTint1ID, SelectedPawnTint2ID, SelectedPawnPatternID, SelectedPawnPatternColorID, SelectedPawnPhongID, SelectedPawnEmissiveID, SelectedPawnSkinToneID);
        Close(TRUE);
        PlayGuiSound('MPAppearanceConfirm');
        ResetPawn();
        MPSaveManager.ClearNewReinforcement(13, string(CurrModifiableCharacter.KitName));
        GetLobbyFlow().FinishMPAppearanceScreen(TRUE, CurrModifiableCharacter);
    }
    else
    {
        DisplayCharacterNameErrorBox(eResult);
    }
}
public final function int GetIdxByAppearanceID(int Id, out array<CustomizableElement> AppearanceData)
{
    local int idx;
    local int i;
    local int J;
    
    J = AppearanceData.Find('Id', Id);
    idx = 0;
    if (J != -1)
    {
        for (i = 0; i < J; ++i)
        {
            idx++;
        }
        return idx;
    }
    return 0;
}
public final function KeyboardNameEntryComplete(bool bOK, const string sName)
{
    local string CharacterName;
    
    if (bOK)
    {
        if (sName == "")
        {
            Keyboard.DisplayKeyboard(srNameTitle, $0, 0, nMaxNameLength, SelectedCharacterName);
        }
        else
        {
            CharacterName = Repl(sName, ";", "", FALSE);
            SetCharacterName(CharacterName);
            AS_RefreshCharacterName(CharacterName);
            Keyboard = None;
        }
    }
}
public function bool IsInDeployFlow()
{
    return GetLobbyFlow().IsInDeployFlow();
}
public function NameErrorCallback(bool bAPressed, int nContext)
{
    AS_SetFocusToNameField();
}
public final function ResetPawn()
{
    ChangePawnTint1(CurrModifiableCharacter.Tint1ID);
    ChangePawnTint2(CurrModifiableCharacter.Tint2ID);
    ChangePawnPattern(CurrModifiableCharacter.PatternID);
    ChangePawnPatternColor(CurrModifiableCharacter.PatternColorID);
    ChangePawnPhong(CurrModifiableCharacter.PhongID);
    ChangePawnEmissive(CurrModifiableCharacter.EmissiveID);
    ChangePawnSkinTone(CurrModifiableCharacter.SkinToneID);
}
public final function ResetPawnToLastSelection()
{
    ChangePawnTint1(SelectedPawnTint1ID);
    ChangePawnTint2(SelectedPawnTint2ID);
    ChangePawnPattern(SelectedPawnPatternID);
    ChangePawnPatternColor(SelectedPawnPatternColorID);
    ChangePawnPhong(SelectedPawnPhongID);
    ChangePawnEmissive(SelectedPawnEmissiveID);
    ChangePawnSkinTone(SelectedPawnSkinToneID);
}
public final function ResetScreenInfo()
{
    SelectedCharacterName = GetOriginalCharacterName();
    SelectedPawnTint1ID = CurrModifiableCharacter.Tint1ID;
    SelectedPawnTint2ID = CurrModifiableCharacter.Tint2ID;
    SelectedPawnPatternID = CurrModifiableCharacter.PatternID;
    SelectedPawnPatternColorID = CurrModifiableCharacter.PatternColorID;
    SelectedPawnPhongID = CurrModifiableCharacter.PhongID;
    SelectedPawnEmissiveID = CurrModifiableCharacter.EmissiveID;
    SelectedPawnSkinToneID = CurrModifiableCharacter.SkinToneID;
    ResetPawn();
    AS_RefreshCharacterName(SelectedCharacterName);
    AS_RefreshCurrentMenuItem();
    PlayGuiSound('MPAppearanceReset');
}
public function SetCharacterName(string CharacterName)
{
    SelectedCharacterName = CharacterName;
    PlayGuiSound('MPAppearanceNameConfirm');
}
public function SetInitialPawnPosition(Object Data)
{
    local Actor TargetActor;
    
    if (SourcePlayer != None)
    {
        TargetActor = oWorldInfo.m_UIWorld.GetSpawnedActor(SourcePlayer);
        if (TargetActor != None)
        {
            TargetActor.SetLocation(m_UIWorldMPPawnInitialLocation, );
            TargetActor.SetRotation(m_UIWorldMPPawnInitialRotation);
        }
    }
}
public final function ShowKeyboard()
{
    Keyboard = new (Self) Class'SFXGUIHelper_ConsoleKeyboard';
    Keyboard.__OnKeyboardEntryComplete__Delegate = KeyboardNameEntryComplete;
    Keyboard.DisplayKeyboard(srNameTitle, $0, 0, nMaxNameLength, SelectedCharacterName);
}
public function ApplyTinting(Object InSettings)
{
    local Actor TargetActor;
    local SFXCustomizationInstance_PlayerMP LocalSettings;
    
    LocalSettings = SFXCustomizationInstance_PlayerMP(InSettings);
    if (SourcePlayer != None)
    {
        TargetActor = WorldInfo.m_UIWorld.GetSpawnedActor(SourcePlayer);
        if (TargetActor != None)
        {
            SourcePlayer.ApplyCustomizationToActor(TargetActor, LocalSettings);
        }
    }
}
public function AS_AddTintSwatch(int nID, float fR, float fX, float fB)
{
    ActionScriptVoid("screen.AddTintSwatch");
}
public function AS_RefreshCharacterName(string NewName)
{
    ActionScriptVoid("screen.RefreshCharacterName");
}
public function AS_RefreshCurrentMenuItem()
{
    ActionScriptVoid("screen.RefreshCurrentMenuItem");
}
public function AS_SetFocusToNameField()
{
    ActionScriptVoid("screen.SetFocusToNameField");
}
public final function BackButtonPressed()
{
    if (GetLobbyFlow().IsInDeployFlow())
    {
        CancelScreen();
    }
    else
    {
        ConfirmButtonPressed();
    }
}
public function CancelConfirmCallback(bool bAPressed, int nContext)
{
    if (bAPressed)
    {
        Close(TRUE);
        PlayGuiSound('MPAppearanceBack');
        ResetPawn();
        GetLobbyFlow().FinishMPAppearanceScreen(FALSE, None);
    }
}
public function CancelScreen()
{
    local BioSFHandler_MessageBox messageBox;
    local BioMessageBoxOptionalParams Params;
    
    messageBox = GetSFXUIController().CreateMessageBox(GetPC());
    Params.srAText = srYes;
    Params.srBText = srNo;
    messageBox.SetInputDelegate(CancelConfirmCallback);
    messageBox.DisplayMessageBox(srCancelConfirmationMessage, Params);
}
public function bool CanShowEmissive()
{
    return MPSaveManager.GetKitData(CurrModifiableCharacter.KitName).bUseEmissive;
}
public function bool CanShowPattern()
{
    return MPSaveManager.GetKitData(CurrModifiableCharacter.KitName).bUsePattern;
}
public function bool CanShowPatternColor()
{
    return MPSaveManager.GetKitData(CurrModifiableCharacter.KitName).bUsePatternColor;
}
public function bool CanShowPhong()
{
    return MPSaveManager.GetKitData(CurrModifiableCharacter.KitName).bUsePhong;
}
public function bool CanShowPrimaryColor()
{
    return MPSaveManager.GetKitData(CurrModifiableCharacter.KitName).bUsePrimaryColor;
}
public function bool CanShowSecondaryColor()
{
    return MPSaveManager.GetKitData(CurrModifiableCharacter.KitName).bUseSecondaryColor;
}
public function bool CanShowSkinTone()
{
    return MPSaveManager.GetKitData(CurrModifiableCharacter.KitName).bUseSkinTone;
}
public function ChangeEmissiveSelection(int nID)
{
    SelectedPawnEmissiveID = nID;
}
public function ChangePatternColorSelection(int nID)
{
    SelectedPawnPatternColorID = nID;
}
public function ChangePatternSelection(int nID)
{
    SelectedPawnPatternID = nID;
}
public function ChangePawnEmissive(int nID)
{
    CurrentSettings.EmissiveID = nID;
    WorldInfo.m_UIWorld.AddDeferredOperation(ApplyTinting, CurrentSettings);
}
public function ChangePawnPattern(int nID)
{
    CurrentSettings.PatternID = nID;
    WorldInfo.m_UIWorld.AddDeferredOperation(ApplyTinting, CurrentSettings);
}
public function ChangePawnPatternColor(int nID)
{
    CurrentSettings.PatternColorID = nID;
    WorldInfo.m_UIWorld.AddDeferredOperation(ApplyTinting, CurrentSettings);
}
public function ChangePawnPhong(int nID)
{
    CurrentSettings.PhongID = nID;
    WorldInfo.m_UIWorld.AddDeferredOperation(ApplyTinting, CurrentSettings);
}
public function ChangePawnSkinTone(int nID)
{
    CurrentSettings.SkinToneID = nID;
    WorldInfo.m_UIWorld.AddDeferredOperation(ApplyTinting, CurrentSettings);
}
public function ChangePawnTint1(int nID)
{
    CurrentSettings.Tint1ID = nID;
    WorldInfo.m_UIWorld.AddDeferredOperation(ApplyTinting, CurrentSettings);
}
public function ChangePawnTint2(int nID)
{
    CurrentSettings.Tint2ID = nID;
    WorldInfo.m_UIWorld.AddDeferredOperation(ApplyTinting, CurrentSettings);
}
public function ChangePhongSelection(int nID)
{
    SelectedPawnPhongID = nID;
}
public function ChangeSkinToneSelection(int nID)
{
    SelectedPawnSkinToneID = nID;
}
public function ChangeTint1Selection(int nID)
{
    SelectedPawnTint1ID = nID;
}
public function ChangeTint2Selection(int nID)
{
    SelectedPawnTint2ID = nID;
}
private final function DisplayCharacterNameErrorBox(ECharacterNameResult eResult)
{
    local BioSFHandler_MessageBox messageBox;
    local BioMessageBoxOptionalParams Params;
    local stringref srErrorMessage;
    
    switch (eResult)
    {
        case ECharacterNameResult.ECharacterNameResult_NotUnique:
            srErrorMessage = srNameNotUniqueErrorMessage;
            break;
        case ECharacterNameResult.ECharacterNameResult_NameTooLong:
            srErrorMessage = srNameTooLongErrorMessage;
            break;
        case ECharacterNameResult.ECharacterNameResult_Empty:
            srErrorMessage = srNameEmpty;
            break;
        default:
            break;
    }
    messageBox = GetSFXUIController().CreateMessageBox(GetPC());
    Params.srAText = srOK;
    messageBox.SetInputDelegate(NameErrorCallback);
    messageBox.DisplayMessageBox(srErrorMessage, Params);
}
public function EAppearanceMenuItemState GetEmissiveState()
{
    return GetMenuItemState(RequiredEmissiveLevel);
}
public function array<TintSwatchData> GetEmissiveSwatchData()
{
    return EmissiveSwatchMappings;
}
public final function int GetMaxCharacterNameLength()
{
    return nMaxNameLength;
}
public function EAppearanceMenuItemState GetMenuItemState(int RequiredLevel)
{
    if (MPSaveManager.GetPlayerVariable(CurrModifiableCharacter.KitName) < RequiredLevel)
    {
        return EAppearanceMenuItemState.EAppearanceMenuItemState_Disabled;
    }
    else if (MPSaveManager.HasNewReinforcement(13, string(CurrModifiableCharacter.KitName)) && MPSaveManager.GetPlayerVariable(CurrModifiableCharacter.KitName) == RequiredLevel)
    {
        return EAppearanceMenuItemState.EAppearanceMenuItemState_New;
    }
    return EAppearanceMenuItemState.EAppearanceMenuItemState_Normal;
}
public function string GetOriginalCharacterName()
{
    if (CurrModifiableCharacter == None || IsInDeployFlow() && !CurrModifiableCharacter.IsDeployed())
    {
        return GetUIString(srDefaultPlaceholderName);
    }
    else
    {
        return CurrModifiableCharacter.CharacterName;
    }
}
public function EAppearanceMenuItemState GetPatternColorState()
{
    return GetMenuItemState(RequiredPatternColorLevel);
}
public function array<TintSwatchData> GetPatternColorSwatchData()
{
    return PatternColorSwatchMappings;
}
public function array<PatternData> GetPatternData()
{
    return PatternMappings;
}
public function EAppearanceMenuItemState GetPatternState()
{
    return GetMenuItemState(RequiredPatternLevel);
}
public function EAppearanceMenuItemState GetPhongState()
{
    return GetMenuItemState(RequiredPhongLevel);
}
public function array<TintSwatchData> GetPhongSwatchData()
{
    return PhongSwatchMappings;
}
public final function string GetSelectedCharacterClassAndLevel()
{
    local string ReturnString;
    
    SetCustomToken(0, string(MPSaveManager.GetClassLevel(CurrModifiableCharacter.className)));
    SetCustomToken(1, GetUIString(MPSaveManager.GetKitBaseClassPrettyName(CurrModifiableCharacter.KitName)));
    ReturnString = GetUIString(srCharacterClassAndLevel, TRUE);
    ClearCustomTokens();
    return ReturnString;
}
public final function string GetSelectedCharacterName()
{
    return SelectedCharacterName;
}
public function int GetSelectedEmissiveID()
{
    return SelectedPawnEmissiveID;
}
public final function string GetSelectedKitName()
{
    return GetUIString(MPSaveManager.GetKitData(CurrModifiableCharacter.KitName).srDisplayName);
}
public function int GetSelectedPatternColorID()
{
    return SelectedPawnPatternColorID;
}
public function int GetSelectedPatternID()
{
    return SelectedPawnPatternID;
}
public function int GetSelectedPhongID()
{
    return SelectedPawnPhongID;
}
public function int GetSelectedSkinToneID()
{
    return SelectedPawnSkinToneID;
}
public function int GetSelectedTint1ID()
{
    return SelectedPawnTint1ID;
}
public function int GetSelectedTint2ID()
{
    return SelectedPawnTint2ID;
}
public function EAppearanceMenuItemState GetSkinToneState()
{
    return GetMenuItemState(RequiredSkinToneLevel);
}
public function array<TintSwatchData> GetSkinToneSwatchData()
{
    return SkinToneSwatchMappings;
}
public function EAppearanceMenuItemState GetTint1State()
{
    return GetMenuItemState(RequiredTint1Level);
}
public function array<TintSwatchData> GetTint1SwatchData()
{
    return Tint1SwatchMappings;
}
public function EAppearanceMenuItemState GetTint2State()
{
    return GetMenuItemState(RequiredTint2Level);
}
public function array<TintSwatchData> GetTint2SwatchData()
{
    return Tint2SwatchMappings;
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    Tint1SwatchMappings = ({
                            SwatchID = 0, 
                            SwatchColor = {R = 0.478430986, G = 0.0, B = 0.00392200006, A = 1.0}
                           }, 
                           {
                            SwatchID = 1, 
                            SwatchColor = {R = 0.929412007, G = 0.105881996, B = 0.141176, A = 1.0}
                           }, 
                           {
                            SwatchID = 2, 
                            SwatchColor = {R = 0.964706004, G = 0.592157006, B = 0.474510014, A = 1.0}
                           }, 
                           {
                            SwatchID = 3, 
                            SwatchColor = {R = 0.482353002, G = 0.180391997, B = 0.0, A = 1.0}
                           }, 
                           {
                            SwatchID = 4, 
                            SwatchColor = {R = 0.952941, G = 0.396077991, B = 0.137254998, A = 1.0}
                           }, 
                           {
                            SwatchID = 5, 
                            SwatchColor = {R = 0.980391979, G = 0.678430974, B = 0.505882025, A = 1.0}
                           }, 
                           {
                            SwatchID = 6, 
                            SwatchColor = {R = 0.49019599, G = 0.286274999, B = 0.0, A = 1.0}
                           }, 
                           {
                            SwatchID = 7, 
                            SwatchColor = {R = 0.968626976, G = 0.580392003, B = 0.113724999, A = 1.0}
                           }, 
                           {
                            SwatchID = 8, 
                            SwatchColor = {R = 0.992156982, G = 0.780391991, B = 0.545098007, A = 1.0}
                           }, 
                           {
                            SwatchID = 9, 
                            SwatchColor = {R = 0.513724983, G = 0.482353002, B = 0.0, A = 1.0}
                           }, 
                           {
                            SwatchID = 10, 
                            SwatchColor = {R = 0.996078014, G = 0.949020028, B = 0.0, A = 1.0}
                           }, 
                           {
                            SwatchID = 11, 
                            SwatchColor = {R = 1.0, G = 0.968626976, B = 0.603922009, A = 1.0}
                           }, 
                           {
                            SwatchID = 12, 
                            SwatchColor = {R = 0.25097999, G = 0.403921992, B = 0.0941179991, A = 1.0}
                           }, 
                           {
                            SwatchID = 13, 
                            SwatchColor = {R = 0.552941024, G = 0.780391991, B = 0.247059003, A = 1.0}
                           }, 
                           {
                            SwatchID = 14, 
                            SwatchColor = {R = 0.768626988, G = 0.87450999, B = 0.611765027, A = 1.0}
                           }, 
                           {
                            SwatchID = 15, 
                            SwatchColor = {R = 0.0, G = 0.368627012, B = 0.125489995, A = 1.0}
                           }, 
                           {
                            SwatchID = 16, 
                            SwatchColor = {R = 0.227450997, G = 0.709803998, B = 0.290196002, A = 1.0}
                           }, 
                           {
                            SwatchID = 17, 
                            SwatchColor = {R = 0.63529402, G = 0.827450991, B = 0.611765027, A = 1.0}
                           }, 
                           {
                            SwatchID = 18, 
                            SwatchColor = {R = 0.0, G = 0.349020004, B = 0.325489998, A = 1.0}
                           }, 
                           {
                            SwatchID = 19, 
                            SwatchColor = {R = 0.00392200006, G = 0.658824027, B = 0.619607985, A = 1.0}
                           }, 
                           {
                            SwatchID = 20, 
                            SwatchColor = {R = 0.482353002, G = 0.803921998, B = 0.780391991, A = 1.0}
                           }, 
                           {
                            SwatchID = 21, 
                            SwatchColor = {R = 0.0, G = 1.0, B = 0.0, A = 1.0}
                           }, 
                           {
                            SwatchID = 22, 
                            SwatchColor = {R = 0.0, G = 0.650979996, B = 0.321568996, A = 1.0}
                           }, 
                           {
                            SwatchID = 23, 
                            SwatchColor = {R = 0.0, G = 1.0, B = 1.0, A = 1.0}
                           }, 
                           {
                            SwatchID = 24, 
                            SwatchColor = {R = 0.0, G = 0.0, B = 1.0, A = 1.0}
                           }, 
                           {
                            SwatchID = 25, 
                            SwatchColor = {R = 1.0, G = 0.0, B = 0.0, A = 1.0}
                           }, 
                           {
                            SwatchID = 26, 
                            SwatchColor = {R = 1.0, G = 0.0, B = 1.0, A = 1.0}
                           }, 
                           {
                            SwatchID = 27, 
                            SwatchColor = {R = 0.00392200006, G = 0.356862992, B = 0.494118005, A = 1.0}
                           }, 
                           {
                            SwatchID = 28, 
                            SwatchColor = {R = 0.0, G = 0.678430974, B = 0.937255025, A = 1.0}
                           }, 
                           {
                            SwatchID = 29, 
                            SwatchColor = {R = 0.431373, G = 0.815685987, B = 0.968626976, A = 1.0}
                           }, 
                           {
                            SwatchID = 30, 
                            SwatchColor = {R = 0.0, G = 0.211765006, B = 0.392156988, A = 1.0}
                           }, 
                           {
                            SwatchID = 31, 
                            SwatchColor = {R = 0.0, G = 0.447059005, B = 0.733332992, A = 1.0}
                           }, 
                           {
                            SwatchID = 32, 
                            SwatchColor = {R = 0.494118005, G = 0.650979996, B = 0.843137026, A = 1.0}
                           }, 
                           {
                            SwatchID = 33, 
                            SwatchColor = {R = 0.0509800017, G = 0.00392200006, B = 0.301961005, A = 1.0}
                           }, 
                           {
                            SwatchID = 34, 
                            SwatchColor = {R = 0.180391997, G = 0.192157, B = 0.572548985, A = 1.0}
                           }, 
                           {
                            SwatchID = 35, 
                            SwatchColor = {R = 0.533333004, G = 0.50980401, B = 0.745097995, A = 1.0}
                           }, 
                           {
                            SwatchID = 36, 
                            SwatchColor = {R = 0.200000003, G = 0.0, B = 0.294117987, A = 1.0}
                           }, 
                           {
                            SwatchID = 37, 
                            SwatchColor = {R = 0.400000006, G = 0.180391997, B = 0.568627, A = 1.0}
                           }, 
                           {
                            SwatchID = 38, 
                            SwatchColor = {R = 0.63529402, G = 0.529411972, B = 0.745097995, A = 1.0}
                           }, 
                           {
                            SwatchID = 39, 
                            SwatchColor = {R = 0.298038989, G = 0.0, B = 0.290196002, A = 1.0}
                           }, 
                           {
                            SwatchID = 40, 
                            SwatchColor = {R = 0.572548985, G = 0.152941003, B = 0.560783982, A = 1.0}
                           }, 
                           {
                            SwatchID = 41, 
                            SwatchColor = {R = 0.737254977, G = 0.55686301, B = 0.74901998, A = 1.0}
                           }, 
                           {
                            SwatchID = 42, 
                            SwatchColor = {R = 0.478430986, G = 0.0, B = 0.145098001, A = 1.0}
                           }, 
                           {
                            SwatchID = 43, 
                            SwatchColor = {R = 0.929412007, G = 0.0784310028, B = 0.356862992, A = 1.0}
                           }, 
                           {
                            SwatchID = 44, 
                            SwatchColor = {R = 0.968626976, G = 0.596077979, B = 0.619607985, A = 1.0}
                           }, 
                           {
                            SwatchID = 45, 
                            SwatchColor = {R = 0.0, G = 0.0, B = 0.0, A = 1.0}
                           }, 
                           {
                            SwatchID = 46, 
                            SwatchColor = {R = 0.384314001, G = 0.384314001, B = 0.384314001, A = 1.0}
                           }, 
                           {
                            SwatchID = 47, 
                            SwatchColor = {R = 1.0, G = 1.0, B = 1.0, A = 1.0}
                           }, 
                           {
                            SwatchID = 48, 
                            SwatchColor = {R = 0.219607994, G = 0.188235, B = 0.176470995, A = 1.0}
                           }, 
                           {
                            SwatchID = 49, 
                            SwatchColor = {R = 0.450980008, G = 0.388235003, B = 0.337255001, A = 1.0}
                           }, 
                           {
                            SwatchID = 50, 
                            SwatchColor = {R = 0.780391991, G = 0.694118023, B = 0.600000024, A = 1.0}
                           }, 
                           {
                            SwatchID = 51, 
                            SwatchColor = {R = 0.376471013, G = 0.223528996, B = 0.0705880001, A = 1.0}
                           }, 
                           {
                            SwatchID = 52, 
                            SwatchColor = {R = 0.549019992, G = 0.384314001, B = 0.219607994, A = 1.0}
                           }, 
                           {
                            SwatchID = 53, 
                            SwatchColor = {R = 0.776471019, G = 0.607842982, B = 0.431373, A = 1.0}
                           }
                          )
    Tint2SwatchMappings = ({
                            SwatchID = 0, 
                            SwatchColor = {R = 0.478430986, G = 0.0, B = 0.00392200006, A = 1.0}
                           }, 
                           {
                            SwatchID = 1, 
                            SwatchColor = {R = 0.929412007, G = 0.105881996, B = 0.141176, A = 1.0}
                           }, 
                           {
                            SwatchID = 2, 
                            SwatchColor = {R = 0.964706004, G = 0.592157006, B = 0.474510014, A = 1.0}
                           }, 
                           {
                            SwatchID = 3, 
                            SwatchColor = {R = 0.482353002, G = 0.180391997, B = 0.0, A = 1.0}
                           }, 
                           {
                            SwatchID = 4, 
                            SwatchColor = {R = 0.952941, G = 0.396077991, B = 0.137254998, A = 1.0}
                           }, 
                           {
                            SwatchID = 5, 
                            SwatchColor = {R = 0.980391979, G = 0.678430974, B = 0.505882025, A = 1.0}
                           }, 
                           {
                            SwatchID = 6, 
                            SwatchColor = {R = 0.49019599, G = 0.286274999, B = 0.0, A = 1.0}
                           }, 
                           {
                            SwatchID = 7, 
                            SwatchColor = {R = 0.968626976, G = 0.580392003, B = 0.113724999, A = 1.0}
                           }, 
                           {
                            SwatchID = 8, 
                            SwatchColor = {R = 0.992156982, G = 0.780391991, B = 0.545098007, A = 1.0}
                           }, 
                           {
                            SwatchID = 9, 
                            SwatchColor = {R = 0.513724983, G = 0.482353002, B = 0.0, A = 1.0}
                           }, 
                           {
                            SwatchID = 10, 
                            SwatchColor = {R = 0.996078014, G = 0.949020028, B = 0.0, A = 1.0}
                           }, 
                           {
                            SwatchID = 11, 
                            SwatchColor = {R = 1.0, G = 0.968626976, B = 0.603922009, A = 1.0}
                           }, 
                           {
                            SwatchID = 12, 
                            SwatchColor = {R = 0.25097999, G = 0.403921992, B = 0.0941179991, A = 1.0}
                           }, 
                           {
                            SwatchID = 13, 
                            SwatchColor = {R = 0.552941024, G = 0.780391991, B = 0.247059003, A = 1.0}
                           }, 
                           {
                            SwatchID = 14, 
                            SwatchColor = {R = 0.768626988, G = 0.87450999, B = 0.611765027, A = 1.0}
                           }, 
                           {
                            SwatchID = 15, 
                            SwatchColor = {R = 0.0, G = 0.368627012, B = 0.125489995, A = 1.0}
                           }, 
                           {
                            SwatchID = 16, 
                            SwatchColor = {R = 0.227450997, G = 0.709803998, B = 0.290196002, A = 1.0}
                           }, 
                           {
                            SwatchID = 17, 
                            SwatchColor = {R = 0.63529402, G = 0.827450991, B = 0.611765027, A = 1.0}
                           }, 
                           {
                            SwatchID = 18, 
                            SwatchColor = {R = 0.0, G = 0.349020004, B = 0.325489998, A = 1.0}
                           }, 
                           {
                            SwatchID = 19, 
                            SwatchColor = {R = 0.00392200006, G = 0.658824027, B = 0.619607985, A = 1.0}
                           }, 
                           {
                            SwatchID = 20, 
                            SwatchColor = {R = 0.482353002, G = 0.803921998, B = 0.780391991, A = 1.0}
                           }, 
                           {
                            SwatchID = 21, 
                            SwatchColor = {R = 0.0, G = 1.0, B = 0.0, A = 1.0}
                           }, 
                           {
                            SwatchID = 22, 
                            SwatchColor = {R = 0.0, G = 0.650979996, B = 0.321568996, A = 1.0}
                           }, 
                           {
                            SwatchID = 23, 
                            SwatchColor = {R = 0.0, G = 1.0, B = 1.0, A = 1.0}
                           }, 
                           {
                            SwatchID = 24, 
                            SwatchColor = {R = 0.0, G = 0.0, B = 1.0, A = 1.0}
                           }, 
                           {
                            SwatchID = 25, 
                            SwatchColor = {R = 1.0, G = 0.0, B = 0.0, A = 1.0}
                           }, 
                           {
                            SwatchID = 26, 
                            SwatchColor = {R = 1.0, G = 0.0, B = 1.0, A = 1.0}
                           }, 
                           {
                            SwatchID = 27, 
                            SwatchColor = {R = 0.00392200006, G = 0.356862992, B = 0.494118005, A = 1.0}
                           }, 
                           {
                            SwatchID = 28, 
                            SwatchColor = {R = 0.0, G = 0.678430974, B = 0.937255025, A = 1.0}
                           }, 
                           {
                            SwatchID = 29, 
                            SwatchColor = {R = 0.431373, G = 0.815685987, B = 0.968626976, A = 1.0}
                           }, 
                           {
                            SwatchID = 30, 
                            SwatchColor = {R = 0.0, G = 0.211765006, B = 0.392156988, A = 1.0}
                           }, 
                           {
                            SwatchID = 31, 
                            SwatchColor = {R = 0.0, G = 0.447059005, B = 0.733332992, A = 1.0}
                           }, 
                           {
                            SwatchID = 32, 
                            SwatchColor = {R = 0.494118005, G = 0.650979996, B = 0.843137026, A = 1.0}
                           }, 
                           {
                            SwatchID = 33, 
                            SwatchColor = {R = 0.0509800017, G = 0.00392200006, B = 0.301961005, A = 1.0}
                           }, 
                           {
                            SwatchID = 34, 
                            SwatchColor = {R = 0.180391997, G = 0.192157, B = 0.572548985, A = 1.0}
                           }, 
                           {
                            SwatchID = 35, 
                            SwatchColor = {R = 0.533333004, G = 0.50980401, B = 0.745097995, A = 1.0}
                           }, 
                           {
                            SwatchID = 36, 
                            SwatchColor = {R = 0.200000003, G = 0.0, B = 0.294117987, A = 1.0}
                           }, 
                           {
                            SwatchID = 37, 
                            SwatchColor = {R = 0.400000006, G = 0.180391997, B = 0.568627, A = 1.0}
                           }, 
                           {
                            SwatchID = 38, 
                            SwatchColor = {R = 0.63529402, G = 0.529411972, B = 0.745097995, A = 1.0}
                           }, 
                           {
                            SwatchID = 39, 
                            SwatchColor = {R = 0.298038989, G = 0.0, B = 0.290196002, A = 1.0}
                           }, 
                           {
                            SwatchID = 40, 
                            SwatchColor = {R = 0.572548985, G = 0.152941003, B = 0.560783982, A = 1.0}
                           }, 
                           {
                            SwatchID = 41, 
                            SwatchColor = {R = 0.737254977, G = 0.55686301, B = 0.74901998, A = 1.0}
                           }, 
                           {
                            SwatchID = 42, 
                            SwatchColor = {R = 0.478430986, G = 0.0, B = 0.145098001, A = 1.0}
                           }, 
                           {
                            SwatchID = 43, 
                            SwatchColor = {R = 0.929412007, G = 0.0784310028, B = 0.356862992, A = 1.0}
                           }, 
                           {
                            SwatchID = 44, 
                            SwatchColor = {R = 0.968626976, G = 0.596077979, B = 0.619607985, A = 1.0}
                           }, 
                           {
                            SwatchID = 45, 
                            SwatchColor = {R = 0.0, G = 0.0, B = 0.0, A = 1.0}
                           }, 
                           {
                            SwatchID = 46, 
                            SwatchColor = {R = 0.384314001, G = 0.384314001, B = 0.384314001, A = 1.0}
                           }, 
                           {
                            SwatchID = 47, 
                            SwatchColor = {R = 1.0, G = 1.0, B = 1.0, A = 1.0}
                           }, 
                           {
                            SwatchID = 48, 
                            SwatchColor = {R = 0.219607994, G = 0.188235, B = 0.176470995, A = 1.0}
                           }, 
                           {
                            SwatchID = 49, 
                            SwatchColor = {R = 0.450980008, G = 0.388235003, B = 0.337255001, A = 1.0}
                           }, 
                           {
                            SwatchID = 50, 
                            SwatchColor = {R = 0.780391991, G = 0.694118023, B = 0.600000024, A = 1.0}
                           }, 
                           {
                            SwatchID = 51, 
                            SwatchColor = {R = 0.376471013, G = 0.223528996, B = 0.0705880001, A = 1.0}
                           }, 
                           {
                            SwatchID = 52, 
                            SwatchColor = {R = 0.549019992, G = 0.384314001, B = 0.219607994, A = 1.0}
                           }, 
                           {
                            SwatchID = 53, 
                            SwatchColor = {R = 0.776471019, G = 0.607842982, B = 0.431373, A = 1.0}
                           }
                          )
    PatternMappings = ({PatternID = 0, PatternName = $706892}, 
                       {PatternID = 1, PatternName = $706889}, 
                       {PatternID = 2, PatternName = $706890}, 
                       {PatternID = 3, PatternName = $706891}
                      )
    PatternColorSwatchMappings = ({
                                   SwatchID = 0, 
                                   SwatchColor = {R = 0.478430986, G = 0.0, B = 0.00392200006, A = 1.0}
                                  }, 
                                  {
                                   SwatchID = 1, 
                                   SwatchColor = {R = 0.929412007, G = 0.105881996, B = 0.141176, A = 1.0}
                                  }, 
                                  {
                                   SwatchID = 2, 
                                   SwatchColor = {R = 0.964706004, G = 0.592157006, B = 0.474510014, A = 1.0}
                                  }, 
                                  {
                                   SwatchID = 3, 
                                   SwatchColor = {R = 0.482353002, G = 0.180391997, B = 0.0, A = 1.0}
                                  }, 
                                  {
                                   SwatchID = 4, 
                                   SwatchColor = {R = 0.952941, G = 0.396077991, B = 0.137254998, A = 1.0}
                                  }, 
                                  {
                                   SwatchID = 5, 
                                   SwatchColor = {R = 0.980391979, G = 0.678430974, B = 0.505882025, A = 1.0}
                                  }, 
                                  {
                                   SwatchID = 6, 
                                   SwatchColor = {R = 0.49019599, G = 0.286274999, B = 0.0, A = 1.0}
                                  }, 
                                  {
                                   SwatchID = 7, 
                                   SwatchColor = {R = 0.968626976, G = 0.580392003, B = 0.113724999, A = 1.0}
                                  }, 
                                  {
                                   SwatchID = 8, 
                                   SwatchColor = {R = 0.992156982, G = 0.780391991, B = 0.545098007, A = 1.0}
                                  }, 
                                  {
                                   SwatchID = 9, 
                                   SwatchColor = {R = 0.513724983, G = 0.482353002, B = 0.0, A = 1.0}
                                  }, 
                                  {
                                   SwatchID = 10, 
                                   SwatchColor = {R = 0.996078014, G = 0.949020028, B = 0.0, A = 1.0}
                                  }, 
                                  {
                                   SwatchID = 11, 
                                   SwatchColor = {R = 1.0, G = 0.968626976, B = 0.603922009, A = 1.0}
                                  }, 
                                  {
                                   SwatchID = 12, 
                                   SwatchColor = {R = 0.25097999, G = 0.403921992, B = 0.0941179991, A = 1.0}
                                  }, 
                                  {
                                   SwatchID = 13, 
                                   SwatchColor = {R = 0.552941024, G = 0.780391991, B = 0.247059003, A = 1.0}
                                  }, 
                                  {
                                   SwatchID = 14, 
                                   SwatchColor = {R = 0.768626988, G = 0.87450999, B = 0.611765027, A = 1.0}
                                  }, 
                                  {
                                   SwatchID = 15, 
                                   SwatchColor = {R = 0.0, G = 0.368627012, B = 0.125489995, A = 1.0}
                                  }, 
                                  {
                                   SwatchID = 16, 
                                   SwatchColor = {R = 0.227450997, G = 0.709803998, B = 0.290196002, A = 1.0}
                                  }, 
                                  {
                                   SwatchID = 17, 
                                   SwatchColor = {R = 0.63529402, G = 0.827450991, B = 0.611765027, A = 1.0}
                                  }, 
                                  {
                                   SwatchID = 18, 
                                   SwatchColor = {R = 0.0, G = 0.349020004, B = 0.325489998, A = 1.0}
                                  }, 
                                  {
                                   SwatchID = 19, 
                                   SwatchColor = {R = 0.00392200006, G = 0.658824027, B = 0.619607985, A = 1.0}
                                  }, 
                                  {
                                   SwatchID = 20, 
                                   SwatchColor = {R = 0.482353002, G = 0.803921998, B = 0.780391991, A = 1.0}
                                  }, 
                                  {
                                   SwatchID = 21, 
                                   SwatchColor = {R = 0.0, G = 1.0, B = 0.0, A = 1.0}
                                  }, 
                                  {
                                   SwatchID = 22, 
                                   SwatchColor = {R = 0.0, G = 0.650979996, B = 0.321568996, A = 1.0}
                                  }, 
                                  {
                                   SwatchID = 23, 
                                   SwatchColor = {R = 0.0, G = 1.0, B = 1.0, A = 1.0}
                                  }, 
                                  {
                                   SwatchID = 24, 
                                   SwatchColor = {R = 0.0, G = 0.0, B = 1.0, A = 1.0}
                                  }, 
                                  {
                                   SwatchID = 25, 
                                   SwatchColor = {R = 1.0, G = 0.0, B = 0.0, A = 1.0}
                                  }, 
                                  {
                                   SwatchID = 26, 
                                   SwatchColor = {R = 1.0, G = 0.0, B = 1.0, A = 1.0}
                                  }, 
                                  {
                                   SwatchID = 27, 
                                   SwatchColor = {R = 0.00392200006, G = 0.356862992, B = 0.494118005, A = 1.0}
                                  }, 
                                  {
                                   SwatchID = 28, 
                                   SwatchColor = {R = 0.0, G = 0.678430974, B = 0.937255025, A = 1.0}
                                  }, 
                                  {
                                   SwatchID = 29, 
                                   SwatchColor = {R = 0.431373, G = 0.815685987, B = 0.968626976, A = 1.0}
                                  }, 
                                  {
                                   SwatchID = 30, 
                                   SwatchColor = {R = 0.0, G = 0.211765006, B = 0.392156988, A = 1.0}
                                  }, 
                                  {
                                   SwatchID = 31, 
                                   SwatchColor = {R = 0.0, G = 0.447059005, B = 0.733332992, A = 1.0}
                                  }, 
                                  {
                                   SwatchID = 32, 
                                   SwatchColor = {R = 0.494118005, G = 0.650979996, B = 0.843137026, A = 1.0}
                                  }, 
                                  {
                                   SwatchID = 33, 
                                   SwatchColor = {R = 0.0509800017, G = 0.00392200006, B = 0.301961005, A = 1.0}
                                  }, 
                                  {
                                   SwatchID = 34, 
                                   SwatchColor = {R = 0.180391997, G = 0.192157, B = 0.572548985, A = 1.0}
                                  }, 
                                  {
                                   SwatchID = 35, 
                                   SwatchColor = {R = 0.533333004, G = 0.50980401, B = 0.745097995, A = 1.0}
                                  }, 
                                  {
                                   SwatchID = 36, 
                                   SwatchColor = {R = 0.200000003, G = 0.0, B = 0.294117987, A = 1.0}
                                  }, 
                                  {
                                   SwatchID = 37, 
                                   SwatchColor = {R = 0.400000006, G = 0.180391997, B = 0.568627, A = 1.0}
                                  }, 
                                  {
                                   SwatchID = 38, 
                                   SwatchColor = {R = 0.63529402, G = 0.529411972, B = 0.745097995, A = 1.0}
                                  }, 
                                  {
                                   SwatchID = 39, 
                                   SwatchColor = {R = 0.298038989, G = 0.0, B = 0.290196002, A = 1.0}
                                  }, 
                                  {
                                   SwatchID = 40, 
                                   SwatchColor = {R = 0.572548985, G = 0.152941003, B = 0.560783982, A = 1.0}
                                  }, 
                                  {
                                   SwatchID = 41, 
                                   SwatchColor = {R = 0.737254977, G = 0.55686301, B = 0.74901998, A = 1.0}
                                  }, 
                                  {
                                   SwatchID = 42, 
                                   SwatchColor = {R = 0.478430986, G = 0.0, B = 0.145098001, A = 1.0}
                                  }, 
                                  {
                                   SwatchID = 43, 
                                   SwatchColor = {R = 0.929412007, G = 0.0784310028, B = 0.356862992, A = 1.0}
                                  }, 
                                  {
                                   SwatchID = 44, 
                                   SwatchColor = {R = 0.968626976, G = 0.596077979, B = 0.619607985, A = 1.0}
                                  }, 
                                  {
                                   SwatchID = 45, 
                                   SwatchColor = {R = 0.0, G = 0.0, B = 0.0, A = 1.0}
                                  }, 
                                  {
                                   SwatchID = 46, 
                                   SwatchColor = {R = 0.384314001, G = 0.384314001, B = 0.384314001, A = 1.0}
                                  }, 
                                  {
                                   SwatchID = 47, 
                                   SwatchColor = {R = 1.0, G = 1.0, B = 1.0, A = 1.0}
                                  }, 
                                  {
                                   SwatchID = 48, 
                                   SwatchColor = {R = 0.219607994, G = 0.188235, B = 0.176470995, A = 1.0}
                                  }, 
                                  {
                                   SwatchID = 49, 
                                   SwatchColor = {R = 0.450980008, G = 0.388235003, B = 0.337255001, A = 1.0}
                                  }, 
                                  {
                                   SwatchID = 50, 
                                   SwatchColor = {R = 0.780391991, G = 0.694118023, B = 0.600000024, A = 1.0}
                                  }, 
                                  {
                                   SwatchID = 51, 
                                   SwatchColor = {R = 0.376471013, G = 0.223528996, B = 0.0705880001, A = 1.0}
                                  }, 
                                  {
                                   SwatchID = 52, 
                                   SwatchColor = {R = 0.549019992, G = 0.384314001, B = 0.219607994, A = 1.0}
                                  }, 
                                  {
                                   SwatchID = 53, 
                                   SwatchColor = {R = 0.776471019, G = 0.607842982, B = 0.431373, A = 1.0}
                                  }
                                 )
    PhongSwatchMappings = ({
                            SwatchID = 0, 
                            SwatchColor = {R = 0.478430986, G = 0.0, B = 0.00392200006, A = 1.0}
                           }, 
                           {
                            SwatchID = 1, 
                            SwatchColor = {R = 0.929412007, G = 0.105881996, B = 0.141176, A = 1.0}
                           }, 
                           {
                            SwatchID = 2, 
                            SwatchColor = {R = 0.964706004, G = 0.592157006, B = 0.474510014, A = 1.0}
                           }, 
                           {
                            SwatchID = 3, 
                            SwatchColor = {R = 0.482353002, G = 0.180391997, B = 0.0, A = 1.0}
                           }, 
                           {
                            SwatchID = 4, 
                            SwatchColor = {R = 0.952941, G = 0.396077991, B = 0.137254998, A = 1.0}
                           }, 
                           {
                            SwatchID = 5, 
                            SwatchColor = {R = 0.980391979, G = 0.678430974, B = 0.505882025, A = 1.0}
                           }, 
                           {
                            SwatchID = 6, 
                            SwatchColor = {R = 0.49019599, G = 0.286274999, B = 0.0, A = 1.0}
                           }, 
                           {
                            SwatchID = 7, 
                            SwatchColor = {R = 0.968626976, G = 0.580392003, B = 0.113724999, A = 1.0}
                           }, 
                           {
                            SwatchID = 8, 
                            SwatchColor = {R = 0.992156982, G = 0.780391991, B = 0.545098007, A = 1.0}
                           }, 
                           {
                            SwatchID = 9, 
                            SwatchColor = {R = 0.513724983, G = 0.482353002, B = 0.0, A = 1.0}
                           }, 
                           {
                            SwatchID = 10, 
                            SwatchColor = {R = 0.996078014, G = 0.949020028, B = 0.0, A = 1.0}
                           }, 
                           {
                            SwatchID = 11, 
                            SwatchColor = {R = 1.0, G = 0.968626976, B = 0.603922009, A = 1.0}
                           }, 
                           {
                            SwatchID = 12, 
                            SwatchColor = {R = 0.25097999, G = 0.403921992, B = 0.0941179991, A = 1.0}
                           }, 
                           {
                            SwatchID = 13, 
                            SwatchColor = {R = 0.552941024, G = 0.780391991, B = 0.247059003, A = 1.0}
                           }, 
                           {
                            SwatchID = 14, 
                            SwatchColor = {R = 0.768626988, G = 0.87450999, B = 0.611765027, A = 1.0}
                           }, 
                           {
                            SwatchID = 15, 
                            SwatchColor = {R = 0.0, G = 0.368627012, B = 0.125489995, A = 1.0}
                           }, 
                           {
                            SwatchID = 16, 
                            SwatchColor = {R = 0.227450997, G = 0.709803998, B = 0.290196002, A = 1.0}
                           }, 
                           {
                            SwatchID = 17, 
                            SwatchColor = {R = 0.63529402, G = 0.827450991, B = 0.611765027, A = 1.0}
                           }, 
                           {
                            SwatchID = 18, 
                            SwatchColor = {R = 0.0, G = 0.349020004, B = 0.325489998, A = 1.0}
                           }, 
                           {
                            SwatchID = 19, 
                            SwatchColor = {R = 0.00392200006, G = 0.658824027, B = 0.619607985, A = 1.0}
                           }, 
                           {
                            SwatchID = 20, 
                            SwatchColor = {R = 0.482353002, G = 0.803921998, B = 0.780391991, A = 1.0}
                           }, 
                           {
                            SwatchID = 21, 
                            SwatchColor = {R = 0.0, G = 1.0, B = 0.0, A = 1.0}
                           }, 
                           {
                            SwatchID = 22, 
                            SwatchColor = {R = 0.0, G = 0.650979996, B = 0.321568996, A = 1.0}
                           }, 
                           {
                            SwatchID = 23, 
                            SwatchColor = {R = 0.0, G = 1.0, B = 1.0, A = 1.0}
                           }, 
                           {
                            SwatchID = 24, 
                            SwatchColor = {R = 0.0, G = 0.0, B = 1.0, A = 1.0}
                           }, 
                           {
                            SwatchID = 25, 
                            SwatchColor = {R = 1.0, G = 0.0, B = 0.0, A = 1.0}
                           }, 
                           {
                            SwatchID = 26, 
                            SwatchColor = {R = 1.0, G = 0.0, B = 1.0, A = 1.0}
                           }, 
                           {
                            SwatchID = 27, 
                            SwatchColor = {R = 0.00392200006, G = 0.356862992, B = 0.494118005, A = 1.0}
                           }, 
                           {
                            SwatchID = 28, 
                            SwatchColor = {R = 0.0, G = 0.678430974, B = 0.937255025, A = 1.0}
                           }, 
                           {
                            SwatchID = 29, 
                            SwatchColor = {R = 0.431373, G = 0.815685987, B = 0.968626976, A = 1.0}
                           }, 
                           {
                            SwatchID = 30, 
                            SwatchColor = {R = 0.0, G = 0.211765006, B = 0.392156988, A = 1.0}
                           }, 
                           {
                            SwatchID = 31, 
                            SwatchColor = {R = 0.0, G = 0.447059005, B = 0.733332992, A = 1.0}
                           }, 
                           {
                            SwatchID = 32, 
                            SwatchColor = {R = 0.494118005, G = 0.650979996, B = 0.843137026, A = 1.0}
                           }, 
                           {
                            SwatchID = 33, 
                            SwatchColor = {R = 0.0509800017, G = 0.00392200006, B = 0.301961005, A = 1.0}
                           }, 
                           {
                            SwatchID = 34, 
                            SwatchColor = {R = 0.180391997, G = 0.192157, B = 0.572548985, A = 1.0}
                           }, 
                           {
                            SwatchID = 35, 
                            SwatchColor = {R = 0.533333004, G = 0.50980401, B = 0.745097995, A = 1.0}
                           }, 
                           {
                            SwatchID = 36, 
                            SwatchColor = {R = 0.200000003, G = 0.0, B = 0.294117987, A = 1.0}
                           }, 
                           {
                            SwatchID = 37, 
                            SwatchColor = {R = 0.400000006, G = 0.180391997, B = 0.568627, A = 1.0}
                           }, 
                           {
                            SwatchID = 38, 
                            SwatchColor = {R = 0.63529402, G = 0.529411972, B = 0.745097995, A = 1.0}
                           }, 
                           {
                            SwatchID = 39, 
                            SwatchColor = {R = 0.298038989, G = 0.0, B = 0.290196002, A = 1.0}
                           }, 
                           {
                            SwatchID = 40, 
                            SwatchColor = {R = 0.572548985, G = 0.152941003, B = 0.560783982, A = 1.0}
                           }, 
                           {
                            SwatchID = 41, 
                            SwatchColor = {R = 0.737254977, G = 0.55686301, B = 0.74901998, A = 1.0}
                           }, 
                           {
                            SwatchID = 42, 
                            SwatchColor = {R = 0.478430986, G = 0.0, B = 0.145098001, A = 1.0}
                           }, 
                           {
                            SwatchID = 43, 
                            SwatchColor = {R = 0.929412007, G = 0.0784310028, B = 0.356862992, A = 1.0}
                           }, 
                           {
                            SwatchID = 44, 
                            SwatchColor = {R = 0.968626976, G = 0.596077979, B = 0.619607985, A = 1.0}
                           }, 
                           {
                            SwatchID = 45, 
                            SwatchColor = {R = 0.0, G = 0.0, B = 0.0, A = 1.0}
                           }, 
                           {
                            SwatchID = 46, 
                            SwatchColor = {R = 0.384314001, G = 0.384314001, B = 0.384314001, A = 1.0}
                           }, 
                           {
                            SwatchID = 47, 
                            SwatchColor = {R = 1.0, G = 1.0, B = 1.0, A = 1.0}
                           }, 
                           {
                            SwatchID = 48, 
                            SwatchColor = {R = 0.219607994, G = 0.188235, B = 0.176470995, A = 1.0}
                           }, 
                           {
                            SwatchID = 49, 
                            SwatchColor = {R = 0.450980008, G = 0.388235003, B = 0.337255001, A = 1.0}
                           }, 
                           {
                            SwatchID = 50, 
                            SwatchColor = {R = 0.780391991, G = 0.694118023, B = 0.600000024, A = 1.0}
                           }, 
                           {
                            SwatchID = 51, 
                            SwatchColor = {R = 0.376471013, G = 0.223528996, B = 0.0705880001, A = 1.0}
                           }, 
                           {
                            SwatchID = 52, 
                            SwatchColor = {R = 0.549019992, G = 0.384314001, B = 0.219607994, A = 1.0}
                           }, 
                           {
                            SwatchID = 53, 
                            SwatchColor = {R = 0.776471019, G = 0.607842982, B = 0.431373, A = 1.0}
                           }
                          )
    EmissiveSwatchMappings = ({
                               SwatchID = 0, 
                               SwatchColor = {R = 0.0, G = 1.0, B = 0.0, A = 1.0}
                              }, 
                              {
                               SwatchID = 1, 
                               SwatchColor = {R = 1.0, G = 0.0, B = 0.0, A = 1.0}
                              }, 
                              {
                               SwatchID = 2, 
                               SwatchColor = {R = 0.952941, G = 0.396077991, B = 0.137254998, A = 1.0}
                              }, 
                              {
                               SwatchID = 3, 
                               SwatchColor = {R = 0.0, G = 0.650979996, B = 0.321568996, A = 1.0}
                              }, 
                              {
                               SwatchID = 4, 
                               SwatchColor = {R = 0.572548985, G = 0.152941003, B = 0.560783982, A = 1.0}
                              }, 
                              {
                               SwatchID = 5, 
                               SwatchColor = {R = 1.0, G = 0.0, B = 1.0, A = 1.0}
                              }, 
                              {
                               SwatchID = 6, 
                               SwatchColor = {R = 0.996078014, G = 0.949020028, B = 0.0, A = 1.0}
                              }, 
                              {
                               SwatchID = 7, 
                               SwatchColor = {R = 0.0, G = 0.678430974, B = 0.937255025, A = 1.0}
                              }, 
                              {
                               SwatchID = 8, 
                               SwatchColor = {R = 0.0, G = 1.0, B = 1.0, A = 1.0}
                              }, 
                              {
                               SwatchID = 9, 
                               SwatchColor = {R = 1.0, G = 1.0, B = 1.0, A = 1.0}
                              }, 
                              {
                               SwatchID = 10, 
                               SwatchColor = {R = 0.0, G = 0.0, B = 0.0, A = 1.0}
                              }, 
                              {
                               SwatchID = 11, 
                               SwatchColor = {R = 0.0, G = 0.0, B = 1.0, A = 1.0}
                              }
                             )
    SkinToneSwatchMappings = ({
                               SwatchID = 0, 
                               SwatchColor = {R = 0.631372988, G = 0.858824015, B = 0.945097983, A = 1.0}
                              }, 
                              {
                               SwatchID = 1, 
                               SwatchColor = {R = 0.658824027, G = 0.627451003, B = 0.850979984, A = 1.0}
                              }, 
                              {
                               SwatchID = 2, 
                               SwatchColor = {R = 0.870588005, G = 0.729412019, B = 0.870588005, A = 1.0}
                              }, 
                              {
                               SwatchID = 3, 
                               SwatchColor = {R = 0.600000024, G = 0.737254977, B = 0.901961029, A = 1.0}
                              }, 
                              {
                               SwatchID = 4, 
                               SwatchColor = {R = 0.63529402, G = 0.827450991, B = 0.611765027, A = 1.0}
                              }, 
                              {
                               SwatchID = 5, 
                               SwatchColor = {R = 0.729412019, G = 0.901961029, B = 0.709803998, A = 1.0}
                              }, 
                              {
                               SwatchID = 6, 
                               SwatchColor = {R = 0.839215994, G = 0.93333298, B = 0.690195978, A = 1.0}
                              }, 
                              {
                               SwatchID = 7, 
                               SwatchColor = {R = 0.780391991, G = 0.694118023, B = 0.600000024, A = 1.0}
                              }, 
                              {
                               SwatchID = 8, 
                               SwatchColor = {R = 0.941175997, G = 0.815685987, B = 0.592157006, A = 1.0}
                              }, 
                              {
                               SwatchID = 9, 
                               SwatchColor = {R = 1.0, G = 1.0, B = 1.0, A = 1.0}
                              }
                             )
    srNameTitle = $593563
    srNameNotUniqueErrorMessage = $589174
    srNameTooLongErrorMessage = $589175
    srNameEmpty = $589176
    srOK = $152938
    srCharacterClassAndLevel = $611705
    srDefaultPlaceholderName = $721070
    srYes = $721071
    srNo = $721072
    srCancelConfirmationMessage = $721073
    nMaxNameLength = 15
    RotationDegreesPerSecond = 180.0
    RequiredTint1Level = 1
    RequiredTint2Level = 2
    RequiredPatternLevel = 3
    RequiredPatternColorLevel = 3
    RequiredPhongLevel = 1
    RequiredEmissiveLevel = 4
    RequiredSkinToneLevel = 5
    m_bFocusOnStart = TRUE
}
