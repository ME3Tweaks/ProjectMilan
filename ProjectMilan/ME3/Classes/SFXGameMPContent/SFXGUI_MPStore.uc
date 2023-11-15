Class SFXGUI_MPStore extends SFXGUIMovieMP
    config(UI);

// Types
struct StoreImage 
{
    var string ImagePath;
    var Texture2DDynamic ImageTexture;
    var bool bValid;
};

// Variables
var array<string> IgnoredImageReferences;
var string ExternalTextureIdentifier;
var string CurrRequestedRemoteImage;
var array<StoreImage> StoreImages;
var array<StoreGUIData> StoreItems;
var SFXGAWReinforcementManager GAWManager;
var SFXSaveManagerMP MPSaveManager;
var config stringref srPlatformText;
var config stringref srCreditsText;
var config stringref srExpiresText;
var config stringref srPurchase;
var config stringref srCancel;
var config stringref srBack;
var config stringref srPurchaseConfirmation;
var config stringref srPCPlatformConfirmation;
var config stringref srRedeemConfirmation;
var config stringref srOK;
var config stringref srPurchaseError;
var config stringref srPleaseWait;
var config stringref srRefreshing;
var config stringref srPurchaseChoiceMessage;
var config stringref srNotEnoughCredits;
var config stringref srFree;
var config stringref srRedeem;
var config stringref srOriginIgoDisabled;
var config float fDelayPostPurchase;
var BioSFHandler_MessageBox oMsgBox_Notification;
var BioSFHandler_MessageBox PurchaseChoiceMessageBox;
var int SelectedID;
var config int nMaxNumRemoteImages;
var int nNumRequestedRemoteImages;
var int nAvailablePCPoints;
var bool bProcessPurchases;
var bool m_bPurchaseCompleted;

// Functions
public final function Exit()
{
    SetInputEnabled(FALSE);
    if (PurchaseChoiceMessageBox != None)
    {
        PurchaseChoiceMessageBox.HideMessageBox(TRUE, TRUE);
        PurchaseChoiceMessageBox = None;
    }
    Close();
    GetLobbyFlow().FinishStoreScreen();
}
public event function bool HandleInputEvent(BioGuiEvents Event, optional float fValue = 1.0)
{
    switch (Event)
    {
        case BioGuiEvents.BIOGUI_EVENT_AXIS_RSTICK_Y:
            AS_ScrollDetails(fValue);
            break;
        default:
            return Super(SFXGUIMovie).HandleInputEvent(Event, fValue);
    }
    return TRUE;
}
public event function OnStart()
{
    local SFXGUIInteraction oGuiMgr;
    
    oGuiMgr = Class'SFXGUIInteraction'.static.GetInstance();
    Super(SFXGUIMovie).OnStart();
    SetRequiresUIWorld(TRUE);
    SetGameMode(TRUE, 23);
    SetMouseVisible(TRUE);
    GAWManager = SFXGAWReinforcementManager(SFXLocalPlayer(GetPC().Player).GAWReinforcementManager);
    MPSaveManager = SFXEngine(Class'Engine'.static.GetEngine()).MPSaveManager;
    GAWManager.LastAwardedCards.Length = 0;
    GAWManager.LastAwardedPackName = "";
    StoreItems.Length = 0;
    AS_ClearScreen();
    AS_SetImageLoadingClipVisible(FALSE);
    AS_SetListLoadingClipVisible(FALSE);
    AS_InitializeScreen();
    AS_SetInputEnabled(FALSE);
    if (GAWManager != None && bProcessPurchases)
    {
        ShowQueuedNotification('RefreshingPurchases', srRefreshing);
        oGuiMgr.GetSaveLoadWidget().ShowNetworkMessage(FALSE);
        GAWManager.ProcessConsumables(FinishInitialization, TRUE);
    }
    else
    {
        FinishInitialization(0);
    }
    if (!Class'WorldInfo'.static.IsConsoleBuild())
    {
        Class'SFXOnlineSubsystem'.static.GetOnlineSubsystem().GetComponentOrigin().AddWalletBalanceAvailableDelegate(OnWalletBalanceRequestFinished);
        Class'SFXOnlineSubsystem'.static.GetOnlineSubsystem().GetComponentOrigin().RequestWalletBalance();
    }
}
public final function ShowNotification(stringref srText)
{
    local BioMessageBoxOptionalParams stParams;
    
    if (oMsgBox_Notification != None)
    {
        oMsgBox_Notification.HideMessageBox();
    }
    oMsgBox_Notification = None;
    if (srText != 0)
    {
        if (oMsgBox_Notification == None)
        {
            oMsgBox_Notification = Class'SFXGUIInteraction'.static.GetInstance().CreateMessageBox(GetPC());
        }
        stParams.bModal = TRUE;
        stParams.bNoFade = TRUE;
        oMsgBox_Notification.DisplayMessageBox(srText, stParams);
    }
}
public event function OnClose()
{
    Class'SFXOnlineSubsystem'.static.GetOnlineSubsystem().GetComponentImageManager().ClearReferences();
    Class'SFXOnlineSubsystem'.static.GetOnlineSubsystem().GetComponentOrigin().ClearWalletBalanceAvailableDelegate(OnWalletBalanceRequestFinished);
    StoreImages.Length = 0;
    StoreItems.Length = 0;
    nNumRequestedRemoteImages = 0;
    IgnoredImageReferences.Length = 0;
    ShowNotification($0);
    SetMouseVisible(FALSE);
    SetGameMode(FALSE, 23);
    Super(SFXGUIMovie).OnClose();
}
public function AS_InitializeScreen()
{
    ActionScriptVoid("screen.InitializeScreen");
}
public function AS_ScrollDetails(float fValue)
{
    ActionScriptVoid("screen.ScrollDetails");
}
public final function OnImageRequestComplete(SFXOnlineImageRequest request)
{
    local StoreImage NewImage;
    
    NewImage.ImagePath = request.mImageName;
    NewImage.bValid = request.mJob.mRequest.mResultSuccess;
    NewImage.ImageTexture = request.mDynamicImage;
    StoreImages.AddItem(NewImage);
    if (NewImage.ImagePath == CurrRequestedRemoteImage)
    {
        CurrRequestedRemoteImage = "";
        AS_SetImageLoadingClipVisible(FALSE);
        if (NewImage.bValid)
        {
            SetExternalTexture(ExternalTextureIdentifier, NewImage.ImageTexture);
            AS_ShowRemoteStoreImage();
        }
    }
}
public function AS_ClearScreen()
{
    ActionScriptVoid("screen.ClearScreen");
}
public function AS_RefreshCredits()
{
    ActionScriptVoid("screen.RefreshCredits");
}
public function AS_RefreshPCPoints()
{
    ActionScriptVoid("screen.RefreshPCPoints");
}
public function AS_SetImageLoadingClipVisible(bool bVisible)
{
    ActionScriptVoid("screen.SetImageLoadingClipVisible");
}
public function AS_SetInputEnabled(bool bEnabled)
{
    ActionScriptVoid("screen.SetInputEnabled");
}
public function AS_SetListLoadingClipVisible(bool bVisible)
{
    ActionScriptVoid("screen.SetListLoadingClipVisible");
}
public function AS_ShowDefaultStoreImage()
{
    ActionScriptVoid("screen.ShowDefaultStoreImage");
}
public function AS_ShowRemoteStoreImage()
{
    ActionScriptVoid("screen.ShowRemoteStoreImage");
}
public final function bool CanPurchaseItem(int ItemId)
{
    local int nStoreItemIndex;
    local bool bCanPurchaseWithCredits;
    local bool bCanPurchaseFromPlatform;
    
    if (GetPRIMP().IsReadyInLobby())
    {
        return FALSE;
    }
    if (MPSaveManager.bDisableSaving)
    {
        return FALSE;
    }
    nStoreItemIndex = StoreItems.Find('nID', ItemId);
    if (nStoreItemIndex >= 0)
    {
        bCanPurchaseWithCredits = GAWManager.CanPurchaseItemWithCredits(ItemId);
        bCanPurchaseFromPlatform = MPSaveManager.GetNextPackToConsume() == -1;
        if (StoreItems[nStoreItemIndex].EPurchaseType == EPurchaseType.EPurchaseType_CreditsOnly)
        {
            return bCanPurchaseWithCredits;
        }
        else if (StoreItems[nStoreItemIndex].EPurchaseType == EPurchaseType.EPurchaseType_PlatformAndCredits)
        {
            return bCanPurchaseWithCredits || bCanPurchaseFromPlatform;
        }
        else if (StoreItems[nStoreItemIndex].EPurchaseType == EPurchaseType.EPurchaseType_PlatformOnly)
        {
            return bCanPurchaseFromPlatform;
        }
        else if (StoreItems[nStoreItemIndex].EPurchaseType == EPurchaseType.EPurchaseType_Free)
        {
            return TRUE;
        }
    }
    return FALSE;
}
public final function bool CanPurchaseItemWithCredits(int ItemId)
{
    return GAWManager.CanPurchaseItemWithCredits(ItemId);
}
public final function bool CanSetReady()
{
    return FALSE;
}
private final function bool CheckIfSignedInFailSafe()
{
    local SFXPlayerControllerMP oPCMP;
    
    oPCMP = SFXPlayerControllerMP(GetPC());
    return oPCMP != None && oPCMP.CheckIfConnectedFailsafe();
}
public final function ClearQueuedNotification(Name MessageBoxName)
{
    Class'SFXGUIInteraction'.static.GetInstance().RemoveNamedMessageBox(MessageBoxName, GetPC());
}
public final function ConfirmPCPlatformPurchase(int ItemId)
{
    local BioSFHandler_MessageBox messageBox;
    local BioMessageBoxOptionalParams PCConfirmationParams;
    local string PCConfirmationMessage;
    local int nStoreItemIndex;
    
    nStoreItemIndex = GAWManager.StoreInfoArray.Find('nID', ItemId);
    messageBox = GetSFXUIController().CreateMessageBox(GetPC());
    if (messageBox != None)
    {
        SelectedID = ItemId;
        PCConfirmationParams.srAText = srPurchase;
        PCConfirmationParams.srBText = srCancel;
        SetCustomToken(0, GetUIString(GAWManager.StoreInfoArray[nStoreItemIndex].Title));
        PCConfirmationMessage = GetUIString(srPCPlatformConfirmation, TRUE);
        ClearCustomTokens();
        messageBox.SetInputDelegate(PCPurchaseConfirmationCallback);
        messageBox.DisplayMessageBoxEx(PCConfirmationMessage, PCConfirmationParams);
    }
}
public function DoCreditPurchase(int ItemId)
{
    GetPRIMP().SetReadyInLobby(FALSE);
    ShowQueuedNotification('CreditWaiting', srPleaseWait);
    GAWManager.PurchaseItemWithCredits(SelectedID, OnPurchaseCreditsCallback);
}
private final function ErrorDialogCallback(bool bAPressed, int nContext)
{
    Close();
    GetLobbyFlow().FinishStoreScreen();
}
public final function FinishInitialization(int nResult)
{
    local SFXGUIInteraction oGuiMgr;
    local BioMessageBoxOptionalParams stParams;
    
    if (GAWManager.IsFetchingProductDetails())
    {
        if (GetLobbyFlow().GetLobbyGRI().SetGenericTimer(0.5, RetryFinishInitialization))
        {
            return;
        }
    }
    AS_InitializeScreen();
    if (bProcessPurchases)
    {
        oGuiMgr = Class'SFXGUIInteraction'.static.GetInstance();
        oGuiMgr.GetSaveLoadWidget().HideNetworkMessage(FALSE);
    }
    ClearQueuedNotification('RefreshingPurchases');
    if (GAWManager != None && GAWManager.LastAwardedCards.Length != 0)
    {
        GetLobbyFlow().SetLastSelectedOffer(GAWManager.GetOfferIDFromStoreID(SelectedID));
        Close();
        GetLobbyFlow().ShowReinforcementsRevealScreeen();
        return;
    }
    AS_SetInputEnabled(TRUE);
    if (GAWManager.OutstandingConsumableIDs.Length > 0 || MPSaveManager.GetNextPackToConsume() >= 0)
    {
        stParams.bModal = TRUE;
        stParams.bNoFade = TRUE;
        stParams.srAText = srOK;
        Class'SFXGUIInteraction'.static.GetInstance().QueueNamedMessageBox('PurchaseError', 2, srPurchaseError, stParams, PurchaseErrorCallback);
    }
    if (MPSaveManager.bDisableSaving)
    {
        MPSaveManager.ShowDataTooNewError();
    }
}
private final function FinishPurchase()
{
    local BioSFHandler_MessageBox oBox;
    local SFXGUIInteraction GUIInteraction;
    
    GetLobbyFlow().SetLastSelectedOffer(GAWManager.GetOfferIDFromStoreID(SelectedID));
    GUIInteraction = Class'SFXGUIInteraction'.static.GetInstance();
    if (GUIInteraction != None)
    {
        oBox = GUIInteraction.CastGetMovie(Class'BioSFHandler_MessageBox', GetPC(), GUIInteraction.MovieTag_MessageBox);
    }
    if ((oBox == None || !oBox.m_bCurrentlyActive) || !oBox.m_bIsModal)
    {
        Close();
        GetLobbyFlow().ShowStoreScreen(TRUE, FALSE);
    }
}
public function string GetAvailablePCPoints()
{
    return string(nAvailablePCPoints);
}
public final function string GetCreditCostString(int ItemId)
{
    local string ReturnString;
    local int nCreditCost;
    
    nCreditCost = GAWManager.GetCreditCost(ItemId);
    if (nCreditCost == 0)
    {
        return GetUIString(srFree);
    }
    SetCustomToken(0, string(nCreditCost));
    ReturnString = GetUIString(srCreditsText, TRUE);
    ClearCustomTokens();
    if (!CanPurchaseItemWithCredits(ItemId))
    {
        ReturnString $= " " $ srNotEnoughCredits;
    }
    return ReturnString;
}
public final function string GetExpirationTimeString(int ItemId)
{
    local int CurrentTime;
    local int TimeDelta;
    local int ItemIndex;
    local int HoursRemaining;
    local int MinutesRemaining;
    local string ExpirationString;
    
    CurrentTime = Class'SFXOnlineSubsystem'.static.GetOnlineSubsystem().GetComponentAPI().GetCurrentTime();
    ItemIndex = GAWManager.StoreInfoArray.Find('nID', ItemId);
    if (ItemIndex >= 0)
    {
        TimeDelta = int(GAWManager.StoreInfoArray[ItemIndex].ExpirationTime - float(CurrentTime));
        if (TimeDelta <= 0)
        {
            return "";
        }
        HoursRemaining = TimeDelta / 3600;
        TimeDelta -= HoursRemaining * 3600;
        MinutesRemaining = TimeDelta / 60;
        SetCustomToken(0, string(HoursRemaining));
        SetCustomToken(1, string(MinutesRemaining));
        ExpirationString = GetUIString(srExpiresText, TRUE);
        ClearCustomTokens();
        return ExpirationString;
    }
    return "";
}
public final function int GetInitialSelectedID()
{
    return SelectedID;
}
public final function string GetPlatformCostString(int ItemId)
{
    local string PlatformCostString;
    
    PlatformCostString = GAWManager.GetPlatformCost(ItemId);
    if (PlatformCostString == "")
    {
        return "";
    }
    SetCustomToken(0, PlatformCostString);
    PlatformCostString = GetUIString(srPlatformText, TRUE);
    ClearCustomTokens();
    return PlatformCostString;
}
public final function array<StoreGUIData> GetStoreItems()
{
    local int idx;
    local SFXOnlineComponentImageManager imageManager;
    
    imageManager = Class'SFXOnlineSubsystem'.static.GetOnlineSubsystem().GetComponentImageManager();
    StoreItems = GAWManager.GetStoreItems();
    nNumRequestedRemoteImages = 0;
    for (idx = 0; idx < StoreItems.Length; ++idx)
    {
        if (!Class'WorldInfo'.static.IsConsoleBuild() || nNumRequestedRemoteImages < nMaxNumRemoteImages)
        {
            if (StoreItems[idx].ImageData.ImageLocation == EStoreImageLocation.EStoreImageLocation_Remote)
            {
                imageManager.RequestImage(StoreItems[idx].ImageData.ImageReference, OnImageRequestComplete);
                nNumRequestedRemoteImages++;
            }
            continue;
        }
        IgnoredImageReferences.AddItem(StoreItems[idx].ImageData.ImageReference);
    }
    return StoreItems;
}
public final function string GetTotalCreditString()
{
    return string(MPSaveManager.GetCredits());
}
public final function bool IsItemFree(int ItemId)
{
    return GAWManager.GetCreditCost(ItemId) == 0;
}
public final function OnPurchaseChoiceCallback(BioSFHandler_MessageBox oMsgBox, int nChoiceID, bool bCancelled)
{
    PurchaseChoiceMessageBox = None;
    if (!bCancelled)
    {
        if (nChoiceID == 0)
        {
            DoCreditPurchase(SelectedID);
        }
        else if (nChoiceID == 1)
        {
            PurchaseItemFromPlatform(SelectedID);
        }
    }
}
public function OnPurchaseCreditsCallback(int nResult)
{
    local BioMessageBoxOptionalParams stParams;
    
    ClearQueuedNotification('CreditWaiting');
    if (nResult == 0)
    {
        GetLobbyFlow().SetLastSelectedOffer(GAWManager.GetOfferIDFromStoreID(SelectedID));
        Close();
        GetLobbyFlow().ShowReinforcementsRevealScreeen();
    }
    else
    {
        stParams.bNoFade = TRUE;
        stParams.srAText = srOK;
        Class'SFXGUIInteraction'.static.GetInstance().QueueNamedMessageBox('PurchaseCreditsError', 2, srPurchaseError, stParams, OnPurchaseCreditsErrorDialogFinished);
    }
}
public final function OnPurchaseCreditsErrorDialogFinished(bool bAPressed, int nContext)
{
    Class'SFXGUIInteraction'.static.GetInstance().RemoveNamedMessageBox('PurchaseCreditsError', GetPC());
    GAWManager.LastAwardedCards.Length = 0;
    FinishPurchase();
}
private final function OnPurchaseItemCallback(int nResult)
{
    local BioMessageBoxOptionalParams messageParams;
    
    m_bPurchaseCompleted = TRUE;
    Class'SFXTelemetryHooksMP'.static.SendPurchaseComplete(nResult);
    ClearQueuedNotification('WaitingOnPlatform');
    if (nResult == 0)
    {
        FinishPurchase();
    }
    else if (nResult == 1)
    {
        AS_SetInputEnabled(TRUE);
        return;
    }
    else
    {
        AS_SetInputEnabled(TRUE);
        messageParams.bModal = TRUE;
        messageParams.bNoFade = TRUE;
        messageParams.srAText = srOK;
        Class'SFXGUIInteraction'.static.GetInstance().QueueNamedMessageBox('PurchaseError', 2, srPurchaseError, messageParams, None);
    }
}
public final function OnWalletBalanceRequestFinished(bool Success, int walletBalance)
{
    if (Success)
    {
        nAvailablePCPoints = walletBalance;
    }
    else
    {
        nAvailablePCPoints = 0;
    }
    AS_RefreshPCPoints();
}
public final function PCPurchaseConfirmationCallback(bool bAPressed, int nContext)
{
    if (bAPressed)
    {
        PurchaseItemFromPlatform(SelectedID);
    }
}
public function PurchaseCreditsCallback(bool bAPressed, int nContext)
{
    if (bAPressed)
    {
        PlayGuiSound('MPStorePurchaseConfirm');
        DoCreditPurchase(SelectedID);
    }
    else
    {
        AS_SetInputEnabled(TRUE);
    }
}
public final function PurchaseErrorCallback(bool bAPressed, int nIndex);

public final function PurchaseItem(int ItemId)
{
    local BioSFHandler_MessageBox messageBox;
    local string CreditsCostString;
    local string PlatformCostString;
    local bool bCanAffordWithCredits;
    local bool bCanPurchaseFromPlatform;
    local int nStoreItemIndex;
    
    if (!CheckIfSignedInFailSafe())
    {
        return;
    }
    nStoreItemIndex = StoreItems.Find('nID', ItemId);
    if (nStoreItemIndex >= 0)
    {
        if (StoreItems[nStoreItemIndex].EPurchaseType == EPurchaseType.EPurchaseType_CreditsOnly || StoreItems[nStoreItemIndex].EPurchaseType == EPurchaseType.EPurchaseType_Free)
        {
            PurchaseItemWithCredits(ItemId);
        }
        else if (StoreItems[nStoreItemIndex].EPurchaseType == EPurchaseType.EPurchaseType_PlatformOnly)
        {
            if (Class'WorldInfo'.static.IsConsoleBuild())
            {
                PurchaseItemFromPlatform(ItemId);
            }
            else
            {
                ConfirmPCPlatformPurchase(ItemId);
            }
        }
        else
        {
            messageBox = GetSFXUIController().CreateMessageBox(GetPC());
            if (messageBox != None)
            {
                PlayGuiSound('MPStorePurchase');
                SelectedID = ItemId;
                messageBox.SetChoiceResultCallback(OnPurchaseChoiceCallback);
                CreditsCostString = GetCreditCostString(ItemId);
                PlatformCostString = GetPlatformCostString(ItemId);
                bCanAffordWithCredits = GAWManager.CanPurchaseItemWithCredits(ItemId);
                bCanPurchaseFromPlatform = MPSaveManager.GetNextPackToConsume() == -1;
                messageBox.ShowChoiceDialogEx(GetUIString(srPurchaseChoiceMessage), GetUIString(srCancel), CreditsCostString, 0, bCanAffordWithCredits, PlatformCostString, 1, bCanPurchaseFromPlatform);
                PurchaseChoiceMessageBox = messageBox;
            }
        }
    }
}
public final function bool PurchaseItemFromPlatform(int ItemId)
{
    local SFXOnlineComponentOrigin oOrigin;
    local BioMessageBoxOptionalParams messageParams;
    
    if (Class'WorldInfo'.static.IsConsoleBuild() == FALSE)
    {
        oOrigin = Class'SFXOnlineSubsystem'.static.GetOnlineSubsystem().GetComponentOrigin();
        if (oOrigin != None && !oOrigin.mIsOriginDisabled)
        {
            if (!oOrigin.mIsOverlayEnabled)
            {
                messageParams.bModal = TRUE;
                messageParams.srAText = srOK;
                Class'SFXGUIInteraction'.static.GetInstance().QueueNamedMessageBox('OriginIgoClosedMessageBox', 2, srOriginIgoDisabled, messageParams, None);
                return FALSE;
            }
        }
    }
    PlayGuiSound('MPStorePurchase');
    if (GAWManager != None)
    {
        m_bPurchaseCompleted = FALSE;
        if (GAWManager.PurchaseItemFromPlatform(ItemId, OnPurchaseItemCallback) && !m_bPurchaseCompleted)
        {
            GetPRIMP().SetReadyInLobby(FALSE);
            SelectedID = ItemId;
            ShowQueuedNotification('WaitingOnPlatform', srPleaseWait);
            AS_SetInputEnabled(FALSE);
        }
    }
    return FALSE;
}
public final function PurchaseItemWithCredits(int ItemId)
{
    local BioSFHandler_MessageBox PurchaseConfirmationBox;
    local BioMessageBoxOptionalParams PurchaseParams;
    local string PurchaseConfirmationMessage;
    local int ItemIndex;
    local bool bIsItemFree;
    
    bIsItemFree = IsItemFree(ItemId);
    PurchaseParams.srAText = bIsItemFree ? srRedeem : srPurchase;
    PurchaseParams.srBText = srCancel;
    ItemIndex = GAWManager.StoreInfoArray.Find('nID', ItemId);
    if (ItemIndex >= 0)
    {
        SelectedID = ItemId;
        AS_SetInputEnabled(FALSE);
        PlayGuiSound('MPStorePurchase');
        SetCustomToken(0, GetUIString(GAWManager.StoreInfoArray[ItemIndex].Title));
        PurchaseConfirmationMessage = GetUIString(bIsItemFree ? srRedeemConfirmation : srPurchaseConfirmation, TRUE);
        ClearCustomTokens();
        PurchaseConfirmationBox = Class'SFXGUIInteraction'.static.GetInstance().CreateMessageBox(GetPC());
        PurchaseConfirmationBox.SetInputDelegate(PurchaseCreditsCallback);
        PurchaseConfirmationBox.DisplayMessageBoxEx(PurchaseConfirmationMessage, PurchaseParams);
    }
}
public final function QueuedNotificationCallback(bool bAPressed, int nIndex);

public final function RetryFinishInitialization()
{
    FinishInitialization(0);
}
public final function SetInitialSelectedStoreID(int StoreID)
{
    SelectedID = StoreID;
}
public final function SetRemoteImage(string ImagePath)
{
    local int nImageIndex;
    
    if (IgnoredImageReferences.Find(ImagePath) >= 0)
    {
        AS_ShowDefaultStoreImage();
        return;
    }
    nImageIndex = StoreImages.Find('ImagePath', ImagePath);
    if (nImageIndex >= 0)
    {
        if (StoreImages[nImageIndex].bValid)
        {
            SetExternalTexture(ExternalTextureIdentifier, StoreImages[nImageIndex].ImageTexture);
            AS_ShowRemoteStoreImage();
        }
        else
        {
            AS_ShowDefaultStoreImage();
        }
    }
    else
    {
        CurrRequestedRemoteImage = ImagePath;
        AS_ShowDefaultStoreImage();
        AS_SetImageLoadingClipVisible(TRUE);
    }
}
private final function ShowFatalErrorDialog(string ErrorMessage)
{
    local BioSFHandler_MessageBox ErrorBox;
    local BioMessageBoxOptionalParams ErrorParams;
    
    ErrorParams.srAText = srOK;
    ErrorBox = Class'SFXGUIInteraction'.static.GetInstance().CreateMessageBox(GetPC());
    ErrorBox.SetInputDelegate(ErrorDialogCallback);
    ErrorBox.DisplayMessageBoxEx(ErrorMessage, ErrorParams);
}
public final function ShowQueuedNotification(Name MessageBoxName, stringref srText)
{
    local BioMessageBoxOptionalParams stParams;
    
    if (srText != 0)
    {
        stParams.bModal = TRUE;
        stParams.bNoFade = TRUE;
        Class'SFXGUIInteraction'.static.GetInstance().QueueNamedMessageBox(MessageBoxName, 2, srText, stParams, QueuedNotificationCallback, 0);
    }
}
public final function bool IsReady()
{
    return GetPRIMP().ReadyInLobby;
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    ExternalTextureIdentifier = "StoreReplacementTexture"
    srPlatformText = $665453
    srCreditsText = $665454
    srExpiresText = $665457
    srPurchase = $664930
    srCancel = $665537
    srBack = $664931
    srPurchaseConfirmation = $665536
    srPCPlatformConfirmation = $722347
    srRedeemConfirmation = $719623
    srOK = $152938
    srPurchaseError = $715826
    srPleaseWait = $345713
    srRefreshing = $715863
    srPurchaseChoiceMessage = $718189
    srNotEnoughCredits = $718556
    srFree = $719621
    srRedeem = $719622
    srOriginIgoDisabled = $722913
    fDelayPostPurchase = 3.0
    SelectedID = -1
    nMaxNumRemoteImages = 10
    m_bFocusOnStart = TRUE
}