Class SFXTelemetryHooks extends SFXTelemetry
    transient
    config(Game);

// Functions
public static final function SendServerMPSessionEnd(int CreditsGained, int XPGained, int LastWave, bool Success, int NumPlayers, int numExtracted, int NumSupplyDropsRecd)
{

}
public static final function SendServerMPSessionStart(int NumPlayers, bool bRandomMap, bool bRandomEnemy, bool bPrivateGame)
{

}
public static final function SendEndGameOptions(int FinalScore, int MilitaryScore, int ExternalScore, int SecurityLevel)
{

}
public static final function SendIncrementMPAsset(int AssetID, int IncValue)
{

}
public static final function SendLeaderboardClosed(float Duration)
{

}
public static final function SendLeaderboardOpened()
{

}
public static final function SendMPCredits(int Delta, int NewBalance, int SessionEarned, int SessionSpent, string Transaction)
{
   
}
public static final function SendMPLevelUp(int PrevLevel, int newLevel)
{
   
}
public static final function SendNewGameData(int NewGameType, bool bFemale, string firstName, bool bCustomShepard, string faceCode, int Origin, int Notoriety, Name BonusTalentClass, Class<Object> CharacterClass, Guid CharacterGUID, bool HasME1PlotData, bool HasME2PlotData, int PlotChoice)
{
   
}
public static final function SendPlayerKill(Pawn Killed, string KillingPlayer, Class<DamageType> dmgType, string KillSource)
{

}
public static final function SendPlayerRevive(Pawn Reviver, Pawn Revivee)
{
    
}
public static final function SendPlayersMuted()
{
 
}
public static final function SendReinforcementCardGranted(const string sPackName, const string sPoolName, int nDropType, string sCardID, int nVersionIdx, int nIncrementBonus, int nCategory)
{

}
public static final function SendUnlockGAWAsset(int AssetID, EGAWAssetType AssetType, EGAWAssetSubType SubType, int CurrentStrength)
{

}
public static final function SendUpdateSecurityRatings(int ZoneID, float Increase, float GlobalIncrease)
{
  
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
}
