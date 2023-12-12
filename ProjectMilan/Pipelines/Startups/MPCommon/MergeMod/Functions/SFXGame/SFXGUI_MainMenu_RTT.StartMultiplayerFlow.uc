// MILAN CHANGE - 12/11/2023
// By Mgamerz
// Purpose: Completely bypasses the online component and just transitions to MPLobby. Maybe someday we will have to use 
// our server code but right now it's not really useful.
public event function StartMultiplayerFlow()
{
    local BioWorldInfo World;
    
    World = BioWorldInfo(Class'WorldInfo'.static.GetWorldInfo());
    SFXPlayerController(World.GetALocalPlayerController()).ClientTravel(Class'GameEngine'.static.GetDefaultLobbyMap() $ "?origin=MainMenu", 0);
}