// NEW to Milan - 10/09/2026 - Mgamerz
// Console: "lobbysize <players>" sets the lobby size. Host only, in the lobby. For testing until the
// lobby has a size control; see SFXGameInfoMP_Lobby.SetLobbySize for the rules.
public exec function LobbySize(int NewSize)
{
    local SFXGameInfoMP_Lobby GameInfo;

    GameInfo = SFXGameInfoMP_Lobby(WorldInfo.Game);
    if (GameInfo == None)
    {
        ClientMessage("lobbysize: only the host can change the lobby size, in the lobby.");
        return;
    }
    ClientMessage("lobbysize: the lobby now admits" @ GameInfo.SetLobbySize(NewSize) @ "players (largest allowed:" @ GameInfo.MaxPlayersAllowed $ ").");
}
