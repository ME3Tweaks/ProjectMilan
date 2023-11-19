Class SFXTelemetryHooksMP extends SFXTelemetryHooks
    transient
    config(Game);

// This all has been stripped out. Only stubs remain so compilation works.

// Functions
public static final function SendConsumable(Class<Object> ConsumableClass, int CurrentCharges, int UsedCount)
{

}
public static final function SendMatchResults(int PlayerID)
{

}
public static final function SendMPHostNew(bool Success)
{

}
public static final function SendPurchaseComplete(int Result)
{

}
public static final function SendPurchaseOffer(int offerId)
{
}
public static final function SendReinforcementPackPurchase(SFXGAWReinforcementManager ReinforcementManager, int nPurchasedID, int nConsumableId, SFXSaveManagerMP Save, bool bInLobby)
{

}
public static final function SendStoreClosed()
{

}
public static final function SendStoreOpened(bool bInLobby, optional int PromotionalId = -1)
{

}
public static final function SendSupplyDropGranted(SFXGAWReinforcementManager ReinforcementManager, int nSupplyDrop, int nPoolID)
{

}
public static final function SendWaveComplete(int WaveNumber, string WaveTypeStr, bool WasObjectiveWave, int CreditsGranted, int SquadScore, int NumSupplyDropsRecd)
{

}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
}
