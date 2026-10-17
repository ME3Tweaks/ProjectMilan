// Decompiled 1/4/2024 11:43:53 AM
// modified by DropTheSquid
Class SFXGUI_MPSelectKit extends SFXGUIMovieMP
    config(UI);

// Types
struct KitDisplayData 
{
    var string KitName;
    var string KitDisplayName;
    var string CharacterName;
    var string TextureReference;
    var string LockedTextureReference;
    var string PowerIconResource;
    var string PowerDescription1;
    var string PowerDescription2;
    var string PowerDescription3;
    var int PowerIcon1;
    var int PowerIcon2;
    var int PowerIcon3;
    var bool bLocked;
    var bool bDeployed;
    var bool bNeedsLevelUp;
};
struct ClassDisplayData 
{
    var string Name;
    var string DisplayName;
    var string CurrentLevelText;
    var string CurrentXPString;
    var string NextLevelXPString;
    var int CurrentLevel;
    var int XPPercentage;
    var int NumPromotions;
    var bool bCanPromote;
    var bool bCanLevelKit;
    var bool bHasNewKit;
    
    structdefaultproperties
    {
        NumPromotions = 0
    }
};

// Variables
var Name ClassNameToPromote;
var config stringref srPromote;
var config stringref srCancel;
// MILAN CHANGE DropSquid 1/4/2024
// added so we can use this when backing out of character info. It makes more sense than cancel
// it is already populated by the config and used in the UI
var config stringref srback;
// END MILAN
var config stringref srLoadingCharacter;
var config stringref srClassLevel;
var config stringref srPromoteConfirm;
var config stringref srPromoteClassWarning;
var config stringref srLoadingCharacters;
var config stringref srSwitchingCharacter;
var config stringref srXPTextFormat;
var config stringref srFormattedXP;
var config stringref srFormattedPlus;
var config stringref srFormattedClassPromotion;
var SFXSaveManagerMP MPSaveManager;
var BioSFHandler_MessageBox LoadingCharacterMsgBox;
var BioSFHandler_MessageBox WaitMessageBox;
var config int m_nPromoteEventPauseTime;
var bool bAdvanceToNextScreen;
var bool bWaitingForCharacters;
var bool bStartDeploy;
var config bool bForceOnlineConnection;

// Functions
public final function bool IsSignedIn()
{
    local SFXOnlineSubsystem OnlineSub;
    
    OnlineSub = SFXOnlineSubsystem(Class'GameEngine'.static.GetOnlineSubsystem());
    return OnlineSub.GetComponentLogin().IsSignedIn();
}
public event function OnStart()
{
    Super(SFXGUIMovie).OnStart();
    SetRequiresUIWorld(TRUE);
    SetGameMode(TRUE, 24); // MILAN Patched: GameMode Enum Index
	// MILAN CHANGE DropTheSquid 1/4/2024
	// removing this; it is now handled better in the superclass anyway
    // SetMouseVisible(TRUE);
	// END MILAN
    PlayGuiSound('MPSelectKitStart');
    MPSaveManager = SFXEngine(Class'Engine'.static.GetEngine()).MPSaveManager;
    bAdvanceToNextScreen = FALSE;
    bWaitingForCharacters = TRUE;
    if (!HasValidLastHighlightedCharacter())
    {
        SetLastHighlightedCharacter(MPSaveManager.GetCurrentSelectedCharacterRecord().KitName);
    }
}
public event function Update(float fDeltaT)
{
    Super(SFXGUIMovie).Update(fDeltaT);
    if (bWaitingForCharacters)
    {
        if (m_bBeingUnitTested)
        {
            bWaitingForCharacters = FALSE;
        }
        else if (MPSaveManager.bInitialized == FALSE)
        {
            GetSFXUIController().GetSaveLoadWidget().ShowNetworkMessage(FALSE);
            if (WaitMessageBox == None)
            {
                ShowWaitMessageBox(srLoadingCharacters);
            }
        }
        else
        {
            GetSFXUIController().GetSaveLoadWidget().HideNetworkMessage(FALSE);
            if (WaitMessageBox != None)
            {
                HideWaitMessageBox();
            }
            AS_InitializeScreen();
            bWaitingForCharacters = FALSE;
        }
    }
}
public event function OnClose()
{
    MPSaveManager.ClearNewReinforcementCategory(7);
    SetMouseVisible(FALSE);
    SetGameMode(FALSE, 24); // MILAN Patched: GameMode Enum Index
    Super(SFXGUIMovie).OnClose();
}
public function AS_InitializeScreen()
{
    ActionScriptVoid("screen.InitializeScreen");
}
public final function array<KitDisplayData> GetKitData(string className)
{
    local array<KitDisplayData> KitData;
    local KitDisplayData CurrUIKitData;
    local MPKitData CurrKitData;
    local array<SFXMPCharacterRecord> CharacterRecords;
    local int idx;
    
    CharacterRecords = MPSaveManager.GetAllCharacterRecords();
    for (idx = 0; idx < CharacterRecords.Length; ++idx)
    {
        if (CharacterRecords[idx].className == Name(className))
        {
            CurrKitData = MPSaveManager.GetKitData(CharacterRecords[idx].KitName);
            if ((!CurrKitData.bHideIfLocked || MPSaveManager.GetPlayerVariable(CurrKitData.KitName) > 0) && Class'SFXEngine'.static.HasRequiredDLC(CurrKitData.RequiredDLCModuleIDs))
            {
                CurrUIKitData.KitName = string(CharacterRecords[idx].KitName);
                CurrUIKitData.CharacterName = CharacterRecords[idx].CharacterName;
                CurrUIKitData.bLocked = !MPSaveManager.IsKitUnlocked(CharacterRecords[idx].KitName);
                CurrUIKitData.bDeployed = !CurrUIKitData.bLocked && CharacterRecords[idx].Deployed;
                CurrUIKitData.KitDisplayName = GetUIString(CurrKitData.srDisplayName);
                CurrUIKitData.TextureReference = CurrKitData.KitTextureRef;
                CurrUIKitData.LockedTextureReference = CurrKitData.LockedKitTextureRef;
                RetainResource(CurrKitData.PowerIconResource);
                CurrUIKitData.PowerIconResource = CurrKitData.PowerIconResource;
                CurrUIKitData.PowerDescription1 = GetUIString(CurrKitData.srPowerName1);
                CurrUIKitData.PowerDescription2 = GetUIString(CurrKitData.srPowerName2);
                CurrUIKitData.PowerDescription3 = GetUIString(CurrKitData.srPowerName3);
                CurrUIKitData.PowerIcon1 = CurrKitData.PowerIconIndex1;
                CurrUIKitData.PowerIcon2 = CurrKitData.PowerIconIndex2;
                CurrUIKitData.PowerIcon3 = CurrKitData.PowerIconIndex3;
                CurrUIKitData.bNeedsLevelUp = !CurrUIKitData.bLocked && CharacterRecords[idx].HasLeveledUp();
                KitData.AddItem(CurrUIKitData);
            }
        }
    }
    return KitData;
}
public function GoBack()
{
    PlayGuiSound('MPSelectKitBack');
    GetLobbyFlow().FinishSelectCharacterFlow(FALSE);
}
public final function PromoteClass(string className)
{
    local SFXMPClassRecord ClassToPromote;
    local BioMessageBoxOptionalParams stParams;
    
    ClassToPromote = MPSaveManager.GetClassRecord(Name(className));
    if (ClassToPromote.CanPromoteClass())
    {
        PlayGuiSound('MPSelectKitPromote');
        ClassNameToPromote = Name(className);
        stParams.bModal = TRUE;
        stParams.srAText = srPromote;
        stParams.srBText = srCancel;
        SetCustomToken(0, GetUIString(MPSaveManager.GetClassPrettyName(ClassNameToPromote)));
        AS_SetInputDisabled(TRUE);
        GetSFXUIController().QueueNamedMessageBoxEx('PromoteClassWarning', 3, GetUIString(srPromoteClassWarning, TRUE), stParams, PromoteClassWarningCallback, 0, GetPC());
        ClearCustomTokens();
    }
}
public final function PromoteClassWarningCallback(bool bAPressed, int nContext)
{
    local SFXMPClassRecord ClassToPromote;
    local BioMessageBoxOptionalParams stParams;
    
    ClassToPromote = MPSaveManager.GetClassRecord(ClassNameToPromote);
    if (bAPressed && ClassToPromote.CanPromoteClass())
    {
        stParams.bModal = TRUE;
        stParams.srAText = srPromote;
        stParams.srBText = srCancel;
        SetCustomToken(0, GetUIString(MPSaveManager.GetClassPrettyName(ClassNameToPromote)));
        AS_SetInputDisabled(TRUE);
        GetSFXUIController().QueueNamedMessageBoxEx('PromoteConfirm', 3, GetUIString(srPromoteConfirm, TRUE), stParams, PromoteConfirmCallback, 0, GetPC());
        ClearCustomTokens();
    }
    else
    {
        AS_SetInputDisabled(FALSE);
    }
}
public final function PromoteConfirmCallback(bool bAPressed, int nContext)
{
    if (bAPressed)
    {
        PlayGuiSound('MPSelectKitPromoteConfirm');
        MPSaveManager.PromoteClass(ClassNameToPromote);
        MPSaveManager.SaveRecords();
        AS_RefreshScreen();
        AS_StartPromotionEvent();
    }
	// MILAN CHANGE DropTheSquid 1/4/2024
	// this was unconditional, which caused input to be handled during the promotion event, which can cause some very bad behavior
	// made it only if you say no
	else
	{
		AS_SetInputDisabled(FALSE);
	}
	// END MILAN
}
public final function SelectKitAndProceed(string KitName)
{
    MPSaveManager.SetCurrentSelectedCharacterRecord(Name(KitName));
    Close();
    SetLastHighlightedCharacter(Name(KitName));
    GetLobbyFlow().FinishSelectCharacterFlow(TRUE);
}
private final function SetLastHighlightedCharacter(Name KitName)
{
    local array<SFXMPCharacterRecord> MPCharacters;
    local int nCharacterIndex;
    local int idx;
    
    MPCharacters = MPSaveManager.GetAllCharacterRecords();
    nCharacterIndex = 0;
    for (idx = 0; idx < MPCharacters.Length; ++idx)
    {
        if (MPCharacters[idx].KitName == KitName)
        {
            nCharacterIndex = idx;
            break;
        }
    }
    GetLobbyFlow().PreviouslySelectedItems[1] = nCharacterIndex;
}
public final function ShowLoadingCharacterMessageBox()
{
    local BioMessageBoxOptionalParams stParams;
    
    if (LoadingCharacterMsgBox == None)
    {
        LoadingCharacterMsgBox = GetSFXUIController().CreateMessageBox(GetPC());
        stParams.bModal = TRUE;
        LoadingCharacterMsgBox.DisplayMessageBox(srLoadingCharacter, stParams);
    }
}
public final function ShowWaitMessageBox(stringref srMessage)
{
    local BioMessageBoxOptionalParams stParams;
    
    if (WaitMessageBox == None)
    {
        WaitMessageBox = GetSFXUIController().CreateMessageBox(GetPC());
        stParams.bModal = TRUE;
        WaitMessageBox.DisplayMessageBox(srMessage, stParams);
    }
}
public function AS_RefreshScreen()
{
    ActionScriptVoid("screen.RefreshScreen");
}
public function AS_SetInputDisabled(bool B)
{
    ActionScriptVoid("screen.SetInputDisabled");
}
public function AS_StartPromotionEvent()
{
    ActionScriptVoid("screen.StartPromotionEvent");
}
public final function bool BackWillExitMultiplayer()
{
    return GetLobbyFlow().bAlwaysAllowGoBackFromKitSelect;
}
public function bool CanGoBack()
{
    if (GetLobbyFlow().bAlwaysAllowGoBackFromKitSelect)
    {
        return TRUE;
    }
    else
    {
        return MPSaveManager.IsCurrentSelectedCharacterRecordValid();
    }
}
public final function DeployKit(string KitName)
{
    MPSaveManager.SetCurrentModifiableCharacter(Name(KitName));
    Close();
    SetLastHighlightedCharacter(Name(KitName));
    GetLobbyFlow().StartDeployFlow();
}
public final function array<ClassDisplayData> GetClassData()
{
    local array<ClassDisplayData> ClassData;
    local ClassDisplayData CurrClassData;
    local array<SFXMPClassRecord> ClassRecords;
    local int idx;
    local int CurrLevelXP;
    local int NextLevelXP;
    local int PrevLevelXP;
    local int CurrentXP;
    
    ClassRecords = MPSaveManager.GetAllClassRecords();
    for (idx = 0; idx < ClassRecords.Length; ++idx)
    {
        CurrClassData.Name = string(ClassRecords[idx].className);
        CurrClassData.DisplayName = GetUIString(MPSaveManager.GetClassPrettyName(ClassRecords[idx].className));
        CurrClassData.CurrentLevel = MPSaveManager.GetClassLevel(ClassRecords[idx].className);
        SetCustomToken(0, string(CurrClassData.CurrentLevel));
        CurrClassData.CurrentLevelText = GetUIString(srClassLevel, TRUE);
        Class'BioLevelUpSystem'.static.GetXPNeededForLevel(CurrClassData.CurrentLevel, CurrLevelXP);
        CurrentXP = int(ClassRecords[idx].GetTotalXP() - float(CurrLevelXP));
        if (!Class'BioLevelUpSystem'.static.GetXPNeededForLevel(CurrClassData.CurrentLevel + 1, NextLevelXP))
        {
            Class'BioLevelUpSystem'.static.GetXPNeededForLevel(CurrClassData.CurrentLevel - 1, PrevLevelXP);
            NextLevelXP = CurrLevelXP - PrevLevelXP;
            CurrentXP = NextLevelXP;
        }
        else
        {
            NextLevelXP = NextLevelXP - CurrLevelXP;
        }
        ClearCustomTokens();
        SetCustomToken(0, string(CurrentXP));
        CurrClassData.CurrentXPString = GetUIString(srFormattedXP, TRUE);
        ClearCustomTokens();
        SetCustomToken(0, string(NextLevelXP));
        CurrClassData.NextLevelXPString = GetUIString(srFormattedXP, TRUE);
        ClearCustomTokens();
        CurrClassData.XPPercentage = int((float(CurrentXP) / float(NextLevelXP)) * float(100));
        CurrClassData.bCanPromote = MPSaveManager.CanPromoteClass(ClassRecords[idx].className);
        CurrClassData.bCanLevelKit = ClassRecords[idx].HaveKitsLeveledUp();
        CurrClassData.bHasNewKit = MPSaveManager.HasNewReinforcementWithSubstringInName(7, string(ClassRecords[idx].className));
        CurrClassData.NumPromotions = ClassRecords[idx].NumPromotions;
        ClassData.AddItem(CurrClassData);
        ClearCustomTokens();
    }
    return ClassData;
}
private final function string GetClassPromotionString()
{
    local string ToRet;
    
    SetCustomToken(0, UIStrRef(MPSaveManager.GetClassPrettyName(ClassNameToPromote)));
    SetCustomToken(1, string(MPSaveManager.GetClassRecord(ClassNameToPromote).NumPromotions));
	// TODO it would be nice if there was a singular version of this
	// Currently the first time it says "Promoted 1 Times" and it would be better if it said "Promoted 1 Time"
	// this would require checking if the number is equal to 1 here and using an alternate stringref if so
	// we could do a localized version of this, or we could just copy the original in other languages
    ToRet = GetUIString(srFormattedClassPromotion, TRUE);
    ClearCustomTokens();
    return ToRet;
}
private final function SFXMPCharacterRecord GetLastHighlightedCharacter()
{
    local array<SFXMPCharacterRecord> MPCharacters;
    
    MPCharacters = MPSaveManager.GetAllCharacterRecords();
    return MPCharacters[GetLobbyFlow().PreviouslySelectedItems[1]];
}
private final function int GetPromoteEventPauseTime()
{
    return m_nPromoteEventPauseTime;
}
private final function string GetPromotionN7RatingsBoost()
{
    local string ReturnString;
    
    SetCustomToken(0, string(Class'SFXSaveManagerMP'.default.MaxMPLevelBonus));
    ReturnString = GetUIString(srFormattedPlus, TRUE);
    ClearCustomTokens();
    return ReturnString;
}
public final function string GetSelectedCharacterClass()
{
    return string(GetLastHighlightedCharacter().className);
}
public final function string GetSelectedCharacterKit()
{
    return string(GetLastHighlightedCharacter().KitName);
}
private final function bool HasValidLastHighlightedCharacter()
{
    return GetLobbyFlow().PreviouslySelectedItems[1] != -1;
}
public final function HideLoadingCharacterMessageBox()
{
    if (LoadingCharacterMsgBox != None)
    {
        LoadingCharacterMsgBox.HideMessageBox(TRUE);
        LoadingCharacterMsgBox = None;
    }
}
public final function HideWaitMessageBox()
{
    if (WaitMessageBox != None)
    {
        WaitMessageBox.HideMessageBox(TRUE);
        WaitMessageBox = None;
    }
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    srPromote = $663430
    srCancel = $663432
    srClassLevel = $662313
    srPromoteConfirm = $663431
    srPromoteClassWarning = $722182
    srLoadingCharacters = $599552
    srSwitchingCharacter = $627004
    srXPTextFormat = $663144
    srFormattedXP = $677972
    srFormattedPlus = $677976
    m_nPromoteEventPauseTime = 2
    m_bFocusOnStart = TRUE
}
