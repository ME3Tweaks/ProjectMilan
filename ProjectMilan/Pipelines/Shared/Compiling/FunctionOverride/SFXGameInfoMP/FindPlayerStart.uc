public function NavigationPoint FindPlayerStart(Controller Player, optional byte InTeam, optional string IncomingName)
{
    local BioStartLocationMP ChkBioStartLocation;
    local BioStartLocationMP BestStartLocation;
    local float ChkStartLocationRating;
    local float BestStartLocationRating;
    local SFXPlayerControllerMP PC;
    local bool bUsedSpot;
    
    BestStartLocationRating = -1000000.0;
    if (Player == None || SFXPlayerControllerMP(Player).BioStartSpot == None)
    {
        foreach WorldInfo.AllActors(Class'BioStartLocationMP', ChkBioStartLocation, )
        {
            bUsedSpot = FALSE;
            foreach WorldInfo.AllControllers(Class'SFXPlayerControllerMP', PC)
            {
                if (ChkBioStartLocation == PC.BioStartSpot)
                {
                    bUsedSpot = TRUE;
                    break;
                }
            }
            if (!bUsedSpot)
            {
                ChkStartLocationRating = RateBioPlayerStart(ChkBioStartLocation, InTeam, Player);
                if (ChkStartLocationRating > BestStartLocationRating)
                {
                    BestStartLocationRating = ChkStartLocationRating;
                    BestStartLocation = ChkBioStartLocation;
                }
            }
        }
    }
    else
    {
        BestStartLocation = SFXPlayerControllerMP(Player).BioStartSpot;
    }
    if (BestStartLocation != None)
    {
        SFXPlayerControllerMP(Player).BioStartSpot = BestStartLocation;
        return Spawn(Class'DynamicAnchor', , , BestStartLocation.location, BestStartLocation.Rotation);
    }
    return Super(GameInfo).FindPlayerStart(Player, InTeam, IncomingName);
}
