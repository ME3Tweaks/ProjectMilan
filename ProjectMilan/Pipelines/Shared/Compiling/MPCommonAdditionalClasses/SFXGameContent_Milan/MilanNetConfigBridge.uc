// MILAN CHANGE - Mgamerz - 2026-10-10
// Multiplayer settings bridge for SFXGUI_MilanNetConfig. MilanHost intercepts every function here:
// the getters return the saved settings, and ApplySettings saves them (profile name to MP_Profile,
// matchmaking to MilanHost.toml) and applies them to the running game. The default matchmaker URL is
// never returned; GetCustomServer only reports a server the player entered. Without the matching ASI
// nothing is available and nothing is saved.
class MilanNetConfigBridge extends Object;

const APPLY_OK = 0;
const APPLY_INVALID_NAME = 1;
const APPLY_INVALID_SERVER = 2;
const APPLY_SAVE_FAILED = 3;
const APPLY_INVALID_PASSWORD = 4;

const JOIN_QUEUED = 0;
const JOIN_INVALID_CODE = 1;
const JOIN_UNAVAILABLE = 2;
// Same limit as MilanHost's matchmaker requests
const MAX_JOIN_CODE_LENGTH = 64;

public static function bool IsAvailable()
{
    return FALSE;
}
// False while connected to other players or joining a lobby, so a name can't change while others see it
public static function bool CanApplySettings()
{
    return FALSE;
}
// Empty when the player has not chosen a profile name yet
public static function string GetPlayerName()
{
    return "";
}
// Suggested name for a player who has not chosen one (the Windows account name)
public static function string GetDefaultPlayerName()
{
    return "";
}
public static function bool IsMatchmakingEnabled()
{
    return TRUE;
}
public static function bool IsCustomServer()
{
    return FALSE;
}
public static function string GetCustomServer()
{
    return "";
}
public static function string GetServerPassword()
{
    return "";
}
// Flags are ints (0/1) rather than bools so MilanHost reads plain 4-byte parameters
public static function int ApplySettings(string PlayerName, int Matchmaking, int UseCustomServer, string CustomServer, string ServerPassword)
{
    LogInternal("Multiplayer settings bridge requires the matching MilanHost ASI", );
    return APPLY_SAVE_FAILED;
}
// MILAN CHANGE - Mgamerz - 11/17/2026
// Native bridge to C++ join queuing
public static function int JoinByCode(string Code)
{
    LogInternal("Joining by code requires the matching MilanHost ASI", );
    return JOIN_UNAVAILABLE;
}
// END MILAN CHANGE
// MILAN CHANGE - 11/23/2026 - Mgamerz
// Expanded lobby preference setter
public static function SetQuickMatchExpandedLobbies(int IncludeExpanded)
{
}
// END MILAN CHANGE
public static function string GetModVersion()
{
    return "";
}
public static function int RequestGalaxyStats()
{
    return 0;
}
public static function int GetGalaxyPlayers()
{
    return -1;
}
public static function int GetGalaxyMapLobbies(int MapId)
{
    return -1;
}
public static function int GetGalaxyMapPlayers(int MapId)
{
    return -1;
}
public static function int GetGalaxyFullPopulation()
{
    return 0;
}
public static function float GetGalaxyMaxBaseTint()
{
    return 0.0;
}
