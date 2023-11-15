Class SFXGUI_MPReinforcementsReveal extends SFXGUIMovieMP
    config(UI);

// Types
struct CardDisplayData 
{
    var string DisplayName;
    var string DisplayDescription;
    var string TextureReference;
    var string CardTypeText;
    var int CardType;
    var bool IsNew;
};
struct CardTypeText 
{
    var string CardType;
    var stringref GUIDescription;
    var stringref GUIDupeDescription;
    var stringref GUIType;
    var stringref GUIDupeType;
};

// Variables
var config array<CardTypeText> CardTypeTextData;
var delegate<OnCloseCallback> __OnCloseCallback__Delegate;

// Functions
public final function Exit()
{
    Close();
    if (__OnCloseCallback__Delegate != None)
    {
        __OnCloseCallback__Delegate();
    }
    __OnCloseCallback__Delegate = None;
}
public delegate function OnCloseCallback();

public event function OnStart()
{
    local Name PackRevealSound;
    
    SetRequiresUIWorld(TRUE);
    SetGameMode(TRUE, 23);
    SetMouseVisible(TRUE);
    PackRevealSound = GetPackRevealSound();
    if (PackRevealSound == 'None')
    {
        PlayGuiSound('MPReinforcementsRevealStart');
    }
    else
    {
        PlayGuiSound(PackRevealSound);
    }
    AS_InitializeScreen();
}
public event function OnClose()
{
    local SFXGAWReinforcementManager GAWManager;
    
    GAWManager = SFXGAWReinforcementManager(SFXLocalPlayer(GetPC().Player).GAWReinforcementManager);
    SetMouseVisible(FALSE);
    SetGameMode(FALSE, 23);
    Super(SFXGUIMovie).OnClose();
    if (GAWManager != None)
    {
        GAWManager.LastAwardedCards.Length = 0;
    }
}
public final function AS_InitializeScreen()
{
    ActionScriptVoid("screen.InitializeScreen");
}
public function SetOnCloseCallback(delegate<OnCloseCallback> fn_OnCloseDelegate)
{
    __OnCloseCallback__Delegate = fn_OnCloseDelegate;
}
public final function array<CardDisplayData> GetCardData()
{
    local array<CardDisplayData> CardData;
    local CardDisplayData NewCard;
    local array<CardInfoData> AwardedCardData;
    local int idx;
    
    AwardedCardData = SFXGAWReinforcementManager(SFXLocalPlayer(Class'Engine'.static.GetCurrentWorldInfo().GetALocalPlayerController().Player).GAWReinforcementManager).LastAwardedCards;
    for (idx = 0; idx < AwardedCardData.Length; ++idx)
    {
        NewCard = GetCardDisplayData(AwardedCardData[idx]);
        CardData.AddItem(NewCard);
    }
    return CardData;
}
public static final function CardDisplayData GetCardDisplayData(const out CardInfoData CardData)
{
    local CardDisplayData NewCard;
    local int CardTypeIdx;
    local string TitleCustomToken0;
    local string TitleCustomToken1;
    
    if (CardData.bUseVersionIdx)
    {
        TitleCustomToken0 = Class'SFXWeaponUIDataManager'.static.GetRomanNumeral(CardData.VersionIdx + 1);
        TitleCustomToken1 = string(CardData.VersionIdx + 1);
    }
    else
    {
        TitleCustomToken0 = Class'SFXWeaponUIDataManager'.static.GetRomanNumeral(CardData.LevelAwarded);
        TitleCustomToken1 = string(CardData.LevelAwarded);
        NewCard.IsNew = CardData.LevelAwarded == 1;
    }
    SetCustomToken(0, TitleCustomToken0);
    SetCustomToken(1, TitleCustomToken1);
    SetCustomToken(2, string(CardData.PVIncrementBonus + 1));
    SetCustomToken(3, string(CardData.StringToken));
    NewCard.DisplayName = GetTokenisedString(CardData.GUIName);
    CardTypeIdx = default.CardTypeTextData.Find('CardType', CardData.GUIType);
    if (CardData.GUIDescription != 0)
    {
        NewCard.DisplayDescription = GetTokenisedString(CardData.GUIDescription);
    }
    if (CardTypeIdx >= 0)
    {
        if (CardData.GUIDescription == 0)
        {
            if (CardData.LevelAwarded - CardData.PVIncrementBonus <= 1 || default.CardTypeTextData[CardTypeIdx].GUIDupeDescription == 0)
            {
                NewCard.DisplayDescription = GetTokenisedString(default.CardTypeTextData[CardTypeIdx].GUIDescription);
            }
            else
            {
                NewCard.DisplayDescription = GetTokenisedString(default.CardTypeTextData[CardTypeIdx].GUIDupeDescription);
            }
        }
        if (CardData.LevelAwarded - CardData.PVIncrementBonus <= 1 || default.CardTypeTextData[CardTypeIdx].GUIDupeType == 0)
        {
            NewCard.CardTypeText = GetTokenisedString(default.CardTypeTextData[CardTypeIdx].GUIType);
        }
        else
        {
            NewCard.CardTypeText = GetTokenisedString(default.CardTypeTextData[CardTypeIdx].GUIDupeType);
        }
    }
    ClearCustomTokens();
    NewCard.TextureReference = CardData.GUITextureRef;
    NewCard.CardType = int(CardData.Rarity);
    return NewCard;
}
public final function string GetPackIntroHoloTextureRef()
{
    local string LastAwardedPackName;
    local SFXGAWReinforcementManager GAWReinforcementManager;
    local int nPackIndex;
    
    GAWReinforcementManager = SFXGAWReinforcementManager(SFXLocalPlayer(Class'Engine'.static.GetCurrentWorldInfo().GetALocalPlayerController().Player).GAWReinforcementManager);
    LastAwardedPackName = GAWReinforcementManager.LastAwardedPackName;
    nPackIndex = GAWReinforcementManager.StoreInfoArray.Find('PackName', LastAwardedPackName);
    if (nPackIndex >= 0)
    {
        return GAWReinforcementManager.StoreInfoArray[nPackIndex].RevealIntroHoloTextureRef;
    }
    return "";
}
public final function string GetPackIntroTextureRef()
{
    local string LastAwardedPackName;
    local SFXGAWReinforcementManager GAWReinforcementManager;
    local int nPackIndex;
    
    GAWReinforcementManager = SFXGAWReinforcementManager(SFXLocalPlayer(Class'Engine'.static.GetCurrentWorldInfo().GetALocalPlayerController().Player).GAWReinforcementManager);
    LastAwardedPackName = GAWReinforcementManager.LastAwardedPackName;
    nPackIndex = GAWReinforcementManager.StoreInfoArray.Find('PackName', LastAwardedPackName);
    if (nPackIndex >= 0)
    {
        return GAWReinforcementManager.StoreInfoArray[nPackIndex].RevealIntroTextureRef;
    }
    return "";
}
public final function string GetPackName()
{
    local string LastAwardedPackName;
    local SFXGAWReinforcementManager GAWReinforcementManager;
    local int nPackIndex;
    
    GAWReinforcementManager = SFXGAWReinforcementManager(SFXLocalPlayer(Class'Engine'.static.GetCurrentWorldInfo().GetALocalPlayerController().Player).GAWReinforcementManager);
    LastAwardedPackName = GAWReinforcementManager.LastAwardedPackName;
    nPackIndex = GAWReinforcementManager.StoreInfoArray.Find('PackName', LastAwardedPackName);
    if (nPackIndex >= 0)
    {
        return GetUIString(GAWReinforcementManager.StoreInfoArray[nPackIndex].Title);
    }
    return "";
}
public final function Name GetPackRevealSound()
{
    local string LastAwardedPackName;
    local SFXGAWReinforcementManager GAWReinforcementManager;
    local int nPackIndex;
    
    GAWReinforcementManager = SFXGAWReinforcementManager(SFXLocalPlayer(Class'Engine'.static.GetCurrentWorldInfo().GetALocalPlayerController().Player).GAWReinforcementManager);
    LastAwardedPackName = GAWReinforcementManager.LastAwardedPackName;
    nPackIndex = GAWReinforcementManager.StoreInfoArray.Find('PackName', LastAwardedPackName);
    if (nPackIndex >= 0)
    {
        return GAWReinforcementManager.StoreInfoArray[nPackIndex].RevealIntroSound;
    }
    return 'None';
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    CardTypeTextData = ({CardType = "assault", GUIDescription = $676604, GUIDupeDescription = $701612, GUIType = $701608, GUIDupeType = $701609}, 
                        {CardType = "sniper", GUIDescription = $676604, GUIDupeDescription = $701612, GUIType = $701610, GUIDupeType = $701611}, 
                        {CardType = "pistol", GUIDescription = $676604, GUIDupeDescription = $701612, GUIType = $701604, GUIDupeType = $701605}, 
                        {CardType = "smg", GUIDescription = $676604, GUIDupeDescription = $701612, GUIType = $701602, GUIDupeType = $701603}, 
                        {CardType = "shotgun", GUIDescription = $676604, GUIDupeDescription = $701612, GUIType = $701606, GUIDupeType = $701607}, 
                        {CardType = "assaultmod", GUIDescription = $676603, GUIDupeDescription = $0, GUIType = $723376, GUIDupeType = $701614}, 
                        {CardType = "snipermod", GUIDescription = $676603, GUIDupeDescription = $0, GUIType = $723377, GUIDupeType = $701614}, 
                        {CardType = "pistolmod", GUIDescription = $676603, GUIDupeDescription = $0, GUIType = $723374, GUIDupeType = $701614}, 
                        {CardType = "smgmod", GUIDescription = $676603, GUIDupeDescription = $0, GUIType = $723373, GUIDupeType = $701614}, 
                        {CardType = "shotgunmod", GUIDescription = $676603, GUIDupeDescription = $0, GUIType = $723375, GUIDupeType = $701614}, 
                        {CardType = "respec", GUIDescription = $708849, GUIDupeDescription = $0, GUIType = $720017, GUIDupeType = $0}, 
                        {CardType = "capacity", GUIDescription = $707607, GUIDupeDescription = $0, GUIType = $707609, GUIDupeType = $0}, 
                        {CardType = "ammoUpgrade", GUIDescription = $676661, GUIDupeDescription = $0, GUIType = $701622, GUIDupeType = $0}, 
                        {CardType = "armorUpgrade", GUIDescription = $676661, GUIDupeDescription = $0, GUIType = $701624, GUIDupeType = $0}, 
                        {CardType = "weaponUpgrade", GUIDescription = $676661, GUIDupeDescription = $0, GUIType = $701623, GUIDupeType = $0}, 
                        {CardType = "consumable", GUIDescription = $0, GUIDupeDescription = $0, GUIType = $702188, GUIDupeType = $0}, 
                        {CardType = "bonus", GUIDescription = $0, GUIDupeDescription = $0, GUIType = $720017, GUIDupeType = $0}, 
                        {CardType = "char", GUIDescription = $701621, GUIDupeDescription = $0, GUIType = $701615, GUIDupeType = $702969}
                       )
    m_bFocusOnStart = TRUE
}