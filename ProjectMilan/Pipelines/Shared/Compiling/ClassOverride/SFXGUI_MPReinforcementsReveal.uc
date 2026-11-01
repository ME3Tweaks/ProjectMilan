// Source: ME3, Patch_SFXGUI_MPReinforcementsReveal
// Decompiled 10/06/2026 9:38:27 PM
Class SFXGUI_MPReinforcementsReveal extends SFXGUIMovieMP
    config(UI);

struct CardDisplayData 
{
    var string DisplayName;
    var string DisplayDescription;
    var string TextureReference;
    var string CardTypeText;
    var int CardType;
    var bool IsNew;
    // MILAN CHANGE - Mgamerz - 2026-10-24
    var bool IsBanner;
    // END MILAN CHANGE
};
struct CardTypeText 
{
    var string CardType;
    var stringref GUIDescription;
    var stringref GUIDupeDescription;
    var stringref GUIType;
    var stringref GUIDupeType;
};

var config array<SFXGUI_MPReinforcementsReveal.CardTypeText> CardTypeTextData;
var int nPackIndex;
var SFXGAWReinforcementManager GAWManager;
var bool bManualReveal;

public final function Exit()
{
    Close();
    if (OnCloseCallback != None)
    {
        OnCloseCallback();
    }
    OnCloseCallback = None;
}
public delegate function OnCloseCallback();

public event function OnStart()
{
    local Name PackRevealSound;
    local string AwardedPackName;
    
    bManualReveal = GetLobbyFlow().bManuallyRevealingReinforcements;
    GAWManager = SFXGAWReinforcementManager(SFXLocalPlayer(GetPC().Player).GAWReinforcementManager);
    AwardedPackName = GetAwardedPackName();
    nPackIndex = GAWManager.StoreInfoArray.Find('PackName', AwardedPackName);
    SetRequiresUIWorld(TRUE);
    SetGameMode(TRUE, 24); // MILAN Patched: GameMode Enum Index
    // MILAN Change DropTheSquid 10/31/2026
	// make sure the mouse is initially shown/hidden based on the input mode, updated to prevent the mouse briefly flickering
	SetMouseVisible(!IsUsingGamepad());
    // END MILAN
    if (!bManualReveal)
    {
        PackRevealSound = GetPackRevealSound();
        if (PackRevealSound == 'None')
        {
            PlayGuiSound('MPReinforcementsRevealStart');
        }
        else
        {
            PlayGuiSound(PackRevealSound);
        }
    }
    AS_InitializeScreen(bManualReveal);
}
public event function OnClose()
{
    // SetMouseVisible(FALSE);
    SetGameMode(FALSE, 24); // MILAN Patched: GameMode Enum Index
    Super(SFXGUIMovie).OnClose();
    if (GAWManager != None)
    {
        GAWManager.LastAwardedCards.Length = 0;
    }
}
public final function AS_InitializeScreen(bool SkipIntro)
{
    ActionScriptVoid("screen.InitializeScreen");
}
public function SetOnCloseCallback(delegate<SFXGUI_MPReinforcementsReveal.OnCloseCallback> fn_OnCloseDelegate)
{
    OnCloseCallback = fn_OnCloseDelegate;
}
public final function string GetAwardedPackName()
{
    local string ToRet;
    
    if (bManualReveal)
    {
        ToRet = GAWManager.ManualAwardedPackName;
    }
    else
    {
        ToRet = GAWManager.LastAwardedPackName;
    }
    return ToRet;
}
private final function array<SFXGUI_MPReinforcementsReveal.CardDisplayData> GetCardData()
{
    local array<SFXGUI_MPReinforcementsReveal.CardDisplayData> CardData;
    local SFXGUI_MPReinforcementsReveal.CardDisplayData NewCard;
    local array<SFXGAWReinforcementBase.CardInfoData> AwardedCardData;
    local int idx;
    
    AwardedCardData = GetCardsToDisplay();
    for (idx = 0; idx < AwardedCardData.Length; ++idx)
    {
        NewCard = GetCardDisplayData(AwardedCardData[idx]);
        CardData.AddItem(NewCard);
    }
    return CardData;
}
public static final function SFXGUI_MPReinforcementsReveal.CardDisplayData GetCardDisplayData(const out SFXGAWReinforcementBase.CardInfoData CardData)
{
    local SFXGUI_MPReinforcementsReveal.CardDisplayData NewCard;
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
    // MILAN CHANGE - Mgamerz - 2026-10-24
    NewCard.IsBanner = CardData.GUIType == "banner";
    // END MILAN CHANGE
    NewCard.TextureReference = CardData.GUITextureRef;
    NewCard.CardType = int(CardData.Rarity);
    return NewCard;
}
private final function array<SFXGAWReinforcementBase.CardInfoData> GetCardsToDisplay()
{
    local array<SFXGAWReinforcementBase.CardInfoData> AwardedCardData;
    
    if (bManualReveal)
    {
        AwardedCardData = GAWManager.ManualAwardedCards;
    }
    else
    {
        AwardedCardData = GAWManager.LastAwardedCards;
    }
    return AwardedCardData;
}
public final function string GetPackIntroHoloTextureRef()
{
    if (nPackIndex >= 0)
    {
        return GAWManager.StoreInfoArray[nPackIndex].RevealIntroHoloTextureRef;
    }
    return "";
}
public final function string GetPackIntroTextureRef()
{
    if (nPackIndex >= 0)
    {
        return GAWManager.StoreInfoArray[nPackIndex].RevealIntroTextureRef;
    }
    return "";
}
public final function string GetPackName()
{
    if (nPackIndex >= 0)
    {
        return GetUIString(GAWManager.StoreInfoArray[nPackIndex].Title);
    }
    return "";
}
public final function Name GetPackRevealSound()
{
    if (nPackIndex >= 0)
    {
        return GAWManager.StoreInfoArray[nPackIndex].RevealIntroSound;
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