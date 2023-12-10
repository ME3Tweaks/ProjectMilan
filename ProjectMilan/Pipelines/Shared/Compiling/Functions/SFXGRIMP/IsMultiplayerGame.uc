// MILAN change DropTheSquid 12/10/2023
// adding this override so that it correctly identifies itself as being in a multiplayer game
// this fixes the pause screen using the wrong version
// and correctly disables power/weapon wheels
// might not be needed when we get the NetMode variable set correctly. 
public simulated function bool IsMultiplayerGame()
{
    return true;
}