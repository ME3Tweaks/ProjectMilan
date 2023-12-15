Class SFXGUI_MPReinforcementsReveal_DLC extends SFXGUI_MPReinforcementsReveal
    config(UI);

// Functions
public event function HandleButtonRefresh(bool usingGamepad)
{
    Super(SFXGUIMovie).HandleButtonRefresh(usingGamepad);
    ActionScriptVoid("screen.RefreshButtonHelp");
}
public function SFXGAWReinforcementMatchConsumable FindReinforcement(CardInfoData CardData)
{
    local SFXGAWReinforcementManager Manager;
    local SFXGAWReinforcementMatchConsumable MatchConsumableIter;
    local CardInfoData CardInfoIter;
    local int idx;
    local int CardIdx;
    
    Manager = SFXGAWReinforcementManager(SFXLocalPlayer(GetPC().Player).GAWReinforcementManager);
    for (idx = 0; idx < Manager.MatchConsumables.Length; ++idx)
    {
        MatchConsumableIter = Manager.MatchConsumables[idx];
        if (MatchConsumableIter.PoolName == CardData.PoolName)
        {
            for (CardIdx = 0; CardIdx < MatchConsumableIter.CardList.Length; CardIdx++)
            {
                CardInfoIter = MatchConsumableIter.CardList[CardIdx];
                if (CardInfoIter.UniqueName == CardData.UniqueName)
                {
                    return MatchConsumableIter;
                }
            }
        }
    }
    return None;
}
public function array<CardDisplayData> GetCardData_DLC(array<CardInfoData> CardsToDisplay)
{
    local array<CardDisplayData> CardData;
    local CardDisplayData NewCard;
    local array<CardInfoData> AwardedCardData;
    local int idx;
    
    if (CardsToDisplay.Length == 0)
    {
        AwardedCardData = SFXGAWReinforcementManager(SFXLocalPlayer(GetLP()).GAWReinforcementManager).LastAwardedCards;
    }
    else
    {
        AwardedCardData = CardsToDisplay;
    }
    for (idx = 0; idx < AwardedCardData.Length; ++idx)
    {
        NewCard = GetCardDisplayData_DLC(AwardedCardData[idx]);
        CardData.AddItem(NewCard);
    }
    return CardData;
}
public function CardDisplayData GetCardDisplayData_DLC(const out CardInfoData CardData)
{
    local CardDisplayData NewCard;
    local int CardTypeIdx;
    local string TitleCustomToken0;
    local string TitleCustomToken1;
    local SFXGAWReinforcementMatchConsumable_Gear GearPool;
    
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
    if (CardData.GUIType == "gearUpgrade")
    {
        GearPool = SFXGAWReinforcementMatchConsumable_Gear(FindReinforcement(CardData));
        GearPool.PrepareCustomTokensForGearDescription(CardData.UniqueName, CardData.LevelAwarded);
    }
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

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
}