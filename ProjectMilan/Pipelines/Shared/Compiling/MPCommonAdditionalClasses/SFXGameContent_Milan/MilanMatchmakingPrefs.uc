// NEW to Milan - 11/23/2026 - Mgamerz
// Matchmaking preferences, packed into profile setting 19 (Setting_MilanMatchmaking)
class MilanMatchmakingPrefs extends Object;

const SETTING_ID = 19;
// Matchmaking bits
const BIT_EXPANDED_LOBBIES = 0;

// Expanded lobbies preference - defaults to FALSE
public static function bool GetExpandedLobbies()
{
    return Class'MilanProfileBits'.static.Get(SETTING_ID, BIT_EXPANDED_LOBBIES, 1) == 1;
}

public static function bool SetExpandedLobbies(bool bInclude)
{
    return Class'MilanProfileBits'.static.Set(SETTING_ID, BIT_EXPANDED_LOBBIES, 1, bInclude ? 1 : 0);
}

defaultproperties {

}