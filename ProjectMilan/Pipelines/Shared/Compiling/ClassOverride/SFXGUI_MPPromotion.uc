Class SFXGUI_MPPromotion extends SFXGUIMovieMP
    config(UI);

// Variables
var string TextureSymbolPath;
var int PromotionalOfferID;
var Texture2D PromoTexture;

// Functions
// MILAN CHANGE DropTheSquid 12/12/2023

// added so that we can react to input changes to update the UI
public event function HandleButtonRefresh(bool usingGamepad)
{
    Super(SFXGUIMovie).HandleButtonRefresh(usingGamepad);
    SetMouseVisible(!usingGamepad);
    ActionScriptVoid("screen.RefreshButtonHelp");
}
// END MILAN
public event function OnStart()
{
    local SFXOnlineMOTDInfo PromoData;
    local SFXSaveManagerMP MPSaveManager;
    
    Super(SFXGUIMovie).OnStart();
    SetRequiresUIWorld(TRUE);
    SetGameMode(TRUE, 9);
    // MILAN CHANGE DropTheSquid 12/17/2023
    // make sure we actually can control the mouse visibility
	BioPlayerController(GetPC()).GameModeManager2.GameModes[int(EGameModes.GameMode_Lobby)].bHasMouseAuthority = false;
	// make sure the mouse is initially shown/hidden based on the input mode
	SetMouseVisible(!bUsingGamepad);
	// END MILAN
    MPSaveManager = Class'SFXEngine'.static.GetSFXEngine().MPSaveManager;
    PromoData = MPSaveManager.GetPromotionalMessageData();
    PromotionalOfferID = PromoData.offerId;
    AS_SetImageVisible(FALSE);
    AS_SetLoadingClipVisible(FALSE);
    AS_SetPromotionalText(PromoData.Title, PromoData.message);
    if (PromoData.Image != "")
    {
        RequestImage(PromoData.Image);
        AS_SetLoadingClipVisible(TRUE);
    }
    MPSaveManager.SetPlayerVariable('LastPromoIDShown', PromoData.TrackingID);
    MPSaveManager.SaveRecords();
}
public event function OnClose()
{
    Super(SFXGUIMovie).OnClose();
    SetMouseVisible(FALSE);
    SetGameMode(FALSE, 9);
    PromoTexture = None;
}
private final function RequestImage(string ImageURL)
{
    Class'SFXOnlineSubsystem'.static.GetOnlineSubsystem().GetComponentImageManager().RequestImage(ImageURL, OnRequestComplete);
}
public final function OnContinue()
{
    Close();
}
public final function OnReinforcements()
{
    Class'SFXTelemetryHooksMP'.static.SendStoreOpened(FALSE, PromotionalOfferID);
    Close();
    GetLobbyFlow().ShowStoreScreenFromPromotion(PromotionalOfferID);
}
private final function OnRequestComplete(SFXOnlineImageRequest Image)
{
    AS_SetLoadingClipVisible(FALSE);
    PromoTexture = Image.mDynamicImage;
    Class'SFXOnlineSubsystem'.static.GetOnlineSubsystem().GetComponentImageManager().ClearReferences();
    if (Image.mJob.mRequest.mResultSuccess)
    {
        SetExternalTexture(TextureSymbolPath, PromoTexture);
        AS_SetImageVisible(TRUE);
    }
}
public function AS_SetImageVisible(bool bVisible)
{
    ActionScriptVoid("screen.SetImageVisible");
}
public function AS_SetLoadingClipVisible(bool bVisible)
{
    ActionScriptVoid("screen.SetLoadingClipVisible");
}
public function AS_SetPromotionalText(string PromotTitle, string PromoText)
{
    ActionScriptVoid("screen.SetPromotionalText");
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    TextureSymbolPath = "PromoTexture"
    m_bFocusOnStart = TRUE
}