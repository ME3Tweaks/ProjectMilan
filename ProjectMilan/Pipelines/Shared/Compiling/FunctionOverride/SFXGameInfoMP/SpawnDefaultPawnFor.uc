// MILAN CHANGE
// Date: 07/02/2024
// Purpose: If playerarchetype fails to spawn, load the default one to prevent infinite loading. 
// - Mgamerz
public function Pawn SpawnDefaultPawnFor(Controller NewPlayer, NavigationPoint StartSpot, optional bool bNoCollisionFail = FALSE)
{
    local Rotator StartRotation;
    local SFXPawn_PlayerMP ResultPawn;
    local Actor PlayerArchetype;
    local SFXPlayerControllerMP PC;
    local SFXPRIMP oPRI;
    
    PC = SFXPlayerControllerMP(NewPlayer);
    if (PC == None)
    {
        return None;
    }
    oPRI = SFXPRIMP(PC.PlayerReplicationInfo);
    if (oPRI == None)
    {
        return None;
    }
    PlayerArchetype = SFXPawn_PlayerMP(Class'SFXEngine'.static.GetSeekFreeObject(oPRI.GetPawnArchetype(), Class'SFXPawn_PlayerMP'));
    // MILAN CHANGE 07/02/2024
    // Spawn default pawn if we could not spawn the archetype in case save references non-compiled kit
    if (PlayerArchetype == None)
    {
        // Spawn failed!
        LogInternal("Spawn failed for " $ oPRI.GetPawnArchetype() $ " - using default archetype", );
        PlayerArchetype = SFXPawn_PlayerMP(Class'SFXEngine'.static.GetSeekFreeObject(Class'SFXPRIMP'.default.DEFAULT_PLAYER_ARCHETYPE_PATH, Class'SFXPawn_PlayerMP'));
    }
    // END MILAN CHANGE
    StartRotation.Yaw = StartSpot.Rotation.Yaw;
    ResultPawn = Spawn(Class<SFXPawn_PlayerMP>(PlayerArchetype.Class), , , StartSpot.location, StartRotation, PlayerArchetype, bNoCollisionFail);
    if (ResultPawn == None)
    {
        return None;
    }
    ResultPawn.Kit = oPRI.GetCharacterKit();
    return ResultPawn;
}