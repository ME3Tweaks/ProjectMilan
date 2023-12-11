// MILAN Change - 12/11/2023
// By Mgamerz
// Purpose: Prevent game crash if SuperCard.CardList array is empty, as game cannot handle sorting an empty array
public final function SFXGAWReinforcementMatchConsumable GetUniqueMatchConsumables()
{
    local int idx;
    local int Idx2;
    local SFXGAWReinforcementMatchConsumable SuperCard;
    local bool bAlreadyInList;
    local int CardID;
    local int CardVersion;
    local CardInfoData CardInfo;
    
    SuperCard = new (Self) Class'SFXGAWReinforcementMatchConsumable';
    for (idx = 0; idx < MatchConsumables.Length; idx++)
    {
        if (MatchConsumables[idx].CardList.Length > 0 && MatchConsumables[idx].CardList[0].UniqueId == 0)
        {
            MatchConsumables[idx].Initialize();
        }
        for (Idx2 = 0; Idx2 < MatchConsumables[idx].CardList.Length; Idx2++)
        {
            CardID = MatchConsumables[idx].GetCardUniqueID(Idx2);
            CardVersion = MatchConsumables[idx].CardList[Idx2].VersionIdx;
            if (CardID == 0)
            {
                continue;
            }
            bAlreadyInList = SuperCard.ContainsCard(CardID, float(CardVersion));
            if (!bAlreadyInList)
            {
                CardInfo = MatchConsumables[idx].CardList[Idx2];
                PopulateCardData(CardInfo);
                CardInfo.CardOwner = MatchConsumables[idx];
                SuperCard.CardList.AddItem(CardInfo);
                SuperCard.GenerateCardUniqueID(SuperCard.CardList.Length - 1);
            }
        }
    }
    // MILAN Change - game crashes if you attempt to sort a list without at least 2 items
    if (SuperCard.CardList.Length > 1)
    {
        SuperCard.CardList.Sort(MatchConsumableSort);
    }
    return SuperCard;
}